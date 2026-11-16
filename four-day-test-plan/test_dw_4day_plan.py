from datetime import datetime, timedelta
from decimal import Decimal
import pytest
from pyspark.sql import SparkSession, functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DecimalType, TimestampType
)


@pytest.fixture(scope="session")
def spark():
    session = (
        SparkSession.builder
        .appName("DW-4Day-RiskBased-TestSuite")
        .master("local[2]")
        .getOrCreate()
    )
    session.sparkContext.setLogLevel("WARN")
    yield session
    session.stop()


# =============================================================================
# DAY 1: Ingestion & Schema Validation (DS -> DSA / Bronze Layer)
# =============================================================================
def test_day1_bronze_schema_and_completeness(spark):
    expected_schema = StructType([
        StructField("claim_id", StringType(), False),
        StructField("line_number", IntegerType(), False),
        StructField("cpt_code", StringType(), False),
        StructField("paid_amount", DecimalType(10, 2), False),
    ])

    bronze_df = spark.createDataFrame(
        [
            ("CLM-01", 1, "99213", Decimal("120.00")),
            ("CLM-02", 1, "99214", Decimal("185.50")),
        ],
        schema=expected_schema
    )

    quarantine_df = spark.createDataFrame(
        [("BAD_ROW_RAW_TEXT", "INVALID_AMOUNT")],
        ["raw_payload", "reject_reason"]
    )

    source_extract_count = 3

    # 1. Schema Contract Check
    actual_fields = {f.name: (f.dataType, f.nullable) for f in bronze_df.schema.fields}
    for field in expected_schema.fields:
        assert field.name in actual_fields, f"Missing column: {field.name}"
        assert actual_fields[field.name] == (field.dataType, field.nullable), (
            f"Schema mismatch on {field.name}: got {actual_fields[field.name]}"
        )

    # 2. Record Completeness & Reject Threshold Check
    loaded_count = bronze_df.count()
    rejected_count = quarantine_df.count()
    assert loaded_count + rejected_count == source_extract_count, "Row count reconciliation mismatch!"


# =============================================================================
# DAY 2: Cleansing, Business Rules & Key Integrity (DSA -> ODS / Silver Layer)
# =============================================================================
def test_day2_silver_duplicates_domain_and_surrogate_keys(spark):
    silver_df = spark.createDataFrame(
        [
            (1001, "CLM-01", 1, "99213", Decimal("120.00")),
            (1002, "CLM-02", 1, "99214", Decimal("185.50")),
        ],
        ["claim_sk", "claim_id", "line_number", "cpt_code", "paid_amount"]
    )

    valid_cpt_ref_df = spark.createDataFrame([("99213",), ("99214",), ("99391",)], ["cpt_code"])

    # 1. Duplicate Detection on Business Key
    dup_count = (
        silver_df.groupBy("claim_id", "line_number")
        .count()
        .filter(F.col("count") > 1)
        .count()
    )
    assert dup_count == 0, f"Found {dup_count} duplicate business keys in Silver!"

    # 2. Domain Integrity Check (CPT code exists in approved reference table)
    invalid_domain_count = silver_df.join(valid_cpt_ref_df, on="cpt_code", how="left_anti").count()
    assert invalid_domain_count == 0, f"Found {invalid_domain_count} invalid CPT domain codes!"

    # 3. Surrogate Key Integrity (Non-null & positive)
    bad_sk_count = silver_df.filter(F.col("claim_sk").isNull() | (F.col("claim_sk") <= 0)).count()
    assert bad_sk_count == 0, f"Found {bad_sk_count} invalid surrogate keys!"


# =============================================================================
# DAY 3: Warehouse Modeling & Incremental Loads (ODS -> DW / Gold Layer)
# =============================================================================
def test_day3_gold_referential_integrity_and_idempotency(spark):
    dim_member_df = spark.createDataFrame(
        [(501, "MCD-1001", True), (502, "MCD-1002", True)],
        ["member_sk", "medicaid_id", "is_current"]
    )

    fact_claims_df = spark.createDataFrame(
        [
            (1001, 501, "CLM-01", 1, Decimal("120.00")),
            (1002, 502, "CLM-02", 1, Decimal("185.50")),
        ],
        ["claim_sk", "member_sk", "claim_id", "line_number", "paid_amount"]
    )

    # 1. Referential Integrity (No orphan Fact foreign keys)
    orphan_count = fact_claims_df.join(dim_member_df, on="member_sk", how="left_anti").count()
    assert orphan_count == 0, f"Found {orphan_count} orphan Fact records!"

    # 2. Incremental Load Idempotency Simulation (Re-merging same batch produces no duplicates)
    rerun_fact_df = fact_claims_df.unionByName(fact_claims_df).dropDuplicates(["claim_id", "line_number"])
    assert rerun_fact_df.count() == fact_claims_df.count(), "Incremental reload introduced duplicate rows!"


# =============================================================================
# DAY 4: Data Mart Aggregations, Freshness & Security (DW -> DM & BI Layer)
# =============================================================================
def test_day4_mart_balancing_freshness_and_phi_security(spark):
    now_ts = datetime.now()

    silver_df = spark.createDataFrame(
        [
            ("CLM-01", Decimal("120.00")),
            ("CLM-02", Decimal("185.50")),
        ],
        ["claim_id", "paid_amount"]
    )

    mart_summary_df = spark.createDataFrame(
        [("ALL_REGIONS", Decimal("305.50"), now_ts)],
        ["region", "total_paid_amount", "etl_loaded_at"]
    )

    # Simulated SHA-256 masked QA member view
    qa_member_view_df = spark.createDataFrame(
        [("a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3", None)],
        ["ssn_hash", "raw_ssn"]
    )

    # 1. Financial Measure Aggregation Check
    silver_total = silver_df.agg(F.sum("paid_amount")).collect()[0][0]
    mart_total = mart_summary_df.agg(F.sum("total_paid_amount")).collect()[0][0]
    assert silver_total == mart_total, f"Financial mismatch: Silver={silver_total}, Mart={mart_total}"

    # 2. Data Freshness SLA Check (Loaded within last 24 hours)
    latest_load = mart_summary_df.agg(F.max("etl_loaded_at")).collect()[0][0]
    assert latest_load >= now_ts - timedelta(hours=24), "Data Mart failed 24-hour freshness SLA!"

    # 3. PHI Masking / Security Check
    unmasked_count = qa_member_view_df.filter(
        ~F.col("ssn_hash").rlike("^[a-fA-F0-9]{64}$") | F.col("raw_ssn").isNotNull()
    ).count()
    assert unmasked_count == 0, f"Security failure: Found {unmasked_count} unmasked PHI rows!"
