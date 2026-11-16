# Data Engineering & ETL Quality Assurance Portfolio

A practical, multi-platform **Data Engineering and ETL Test Automation portfolio** built using **PySpark, Python (`pytest`), Gherkin BDD, and SQL**. This repository demonstrates end-to-end data warehouse validation, healthcare claims processing (EDI 837), Slowly Changing Dimension (SCD Type 2) testing, and cloud data platform reconciliation across **Databricks/Apache Spark, Snowflake, GCP BigQuery, Hadoop, Hive, and Kafka**.

---

## Theoretical Foundation & Academic Citation

The testing methodology and risk-based test plans in this repository are grounded in the architecture-oriented Data Warehouse testing framework proposed by **El-Gamal et al.**:

> **Citation:**  
> El-Gamal, N., El-Bastawissy, A., & Galal-Edeen, G. (2016). *An Architecture-Oriented Data Warehouse Testing Approach*. Proceedings of the 21st International Conference on Management of Data (COMAD), Pune, India, Computer Society of India (CSI).

### How This Framework Is Applied Here
* **Layered Medallion & Kim-mon Alignment:** Test routines are organized systematically across data architectural stages—mapping **Data Sources (DS) → Staging (DSA/Bronze) → Operational Data Store (ODS/Silver) → Data Warehouse & Data Marts (DW/DM/Gold)**.
* **Three-Dimensional Validation Matrix:** Every pipeline layer is evaluated across three core dimensions defined by El-Gamal et al.:
  1. **Schema Level:** Field mapping, data type enforcement, nullability contracts, and granularity.
  2. **Data Level:** Source-to-target reconciliation, duplicate detection, surrogate key integrity, referential integrity, domain validity, and historical SCD Type 2 timeline continuity.
  3. **Operation Level:** Incremental (delta) load idempotency, rejected/quarantined record thresholds, data freshness SLAs, and HIPAA/PHI security masking.

---

## Repository Structure

```text
PythonJobPortfolio/
├── Apache_Hive_Tests/
│   └── hive_tests.sql                  # Partition completeness & metastore validation queries
├── Apache_Kafka_Tests/
│   └── kafka_tests.sql                 # Streaming offset, schema & dead-letter validation scripts
├── EDI_837/
│   ├── claim_to_service_etl_validation.py  # SNIP Level 2/3 financial balancing (CLM vs. SV1/SV2)
│   ├── handle_nests_837_hierarchy.py       # Exploding nested ARRAY<STRUCT> claim hierarchies
│   ├── parsing_837_text.py                 # Raw X12 segment parsing into Bronze/Silver DataFrames
│   └── validate_837_submission.py          # Pre-submission NPI, ICD-10, and date-range rules
├── four-day-test-plan/
│   ├── dw_4day_risk_based_plan.feature     # Gherkin BDD specification for a 4-day QA sprint
│   └── test_dw_4day_plan.py                # Automated PySpark + pytest suite across all 4 days
├── GCP_ETL_Tests/
│   └── gcp_tests.sql                   # BigQuery UNNEST, EXCEPT DISTINCT & Time Travel checks
├── Hadoop_Tests/
│   └── hadoop_tests.sql                # HDFS landing layer file & completeness checks
├── pyspark/
│   ├── scenario_a.py                   # Source-to-Target data reconciliation (.subtract / hashing)
│   ├── scenario_b.py                   # Primary key uniqueness & mandatory non-null checks
│   ├── scenario_c.py                   # SCD Type 2 historical continuity & active flag validation
│   ├── scenario_d.py                   # Delta Lake Time Travel regression testing (versionAsOf)
│   └── top_10_pyspark_commands.py      # Reference guide of essential PySpark ETL/QA functions
├── Snowflake_ETL_Tests/
│   └── snowflake_tests.sql             # QUALIFY deduplication, HASH(*) diffs & Time Travel
└── SQL_Queries_ETL_Tests/
    └── tests.sql                       # Star Schema Fact-to-Dimension & SCD2 SQL assertions
```

---

## Module Summaries

### 1. PySpark Core ETL & Delta Lake Validation (`pyspark/`)
* **`scenario_a.py` — Source-to-Target Reconciliation:** Compares transformed target DataFrames against expected source mappings using row counts, set differences, and SHA-256 row hashing.
* **`scenario_b.py` — Automated Data Quality Checks:** Validates primary key uniqueness and enforces non-null / non-whitespace rules on mandatory columns.
* **`scenario_c.py` — SCD Type 2 Validation:** Uses PySpark `Window` functions (`lag`, `row_number`) to verify single active records (`is_current = True`) and gapless, non-overlapping effective date ranges.
* **`scenario_d.py` — Delta Lake Time Travel:** Queries historical table snapshots (`versionAsOf`) to isolate incremental batch changes and perform regression testing.
* **`top_10_pyspark_commands.py` — ETL QA Cheat Sheet:** Practical examples of `left_anti` joins, `sha2(concat_ws(...))`, `Window`, `when().otherwise()`, `coalesce()`, `explode()`, and `rlike()`.

### 2. Healthcare & Medicaid EDI 837 Claims Pipeline (`EDI_837/`)
* **`parsing_837_text.py`:** Parses raw tilde-delimited (`~`) and asterisk-delimited (`*`) X12 837 claim files into structured Spark DataFrames.
* **`claim_to_service_etl_validation.py`:** Enforces financial balancing by verifying that Claim Header totals (`CLM02`) equal the sum of all child Service Line charges (`SV102`/`SV203`).
* **`validate_837_submission.py`:** Validates 10-digit Billing Provider NPIs, service date logic, and primary ICD-10 diagnosis presence, routing failures to a quarantine table.
* **`handle_nests_837_hierarchy.py`:** Flattens nested claim service lines using `F.explode` and performs `left_anti` referential integrity checks against active CPT code dimensions.

### 3. Risk-Based 4-Day DW Test Plan (`four-day-test-plan/`)
* **`dw_4day_risk_based_plan.feature` & `test_dw_4day_plan.py`:** Translates the El-Gamal et al. test matrix into an executable `pytest` suite structured across four sprint days:
  * **Day 1 (Bronze / DSA):** Schema contract enforcement, record completeness, and reject threshold checks.
  * **Day 2 (Silver / ODS):** Business key deduplication, CPT domain integrity, and surrogate key checks.
  * **Day 3 (Gold / DW):** Star Schema referential integrity (`Fact` → `Dim`) and incremental load idempotency.
  * **Day 4 (Data Mart / Security):** Source-to-Mart financial balancing, 24-hour freshness SLAs, and HIPAA SHA-256 PHI masking verification.

### 4. Multi-Platform SQL & Big Data Validation (`Snowflake_ETL_Tests/`, `GCP_ETL_Tests/`, `SQL_Queries_ETL_Tests/`, `Apache_Hive_Tests/`, `Apache_Kafka_Tests/`, `Hadoop_Tests/`)
* **Snowflake:** Demonstrates `QUALIFY ROW_NUMBER()`, `HASH(*)` with `MINUS` for row diffs, and `AT(OFFSET => ...)` Time Travel queries.
* **GCP BigQuery:** Covers `UNNEST()` for repeated fields, `EXCEPT DISTINCT` with `TO_JSON_STRING()`, and `FOR SYSTEM_TIME AS OF` snapshot queries.
* **Star Schema & Big Data Stack:** Validates Hive partition completeness, Kafka event schema/lag checks, HDFS landing integrity, and relational Fact/Dimension foreign keys.

---

## How to Run the Automated Tests Locally

### Prerequisites
* Python 3.9+
* Java 8 or 11 (required for local Apache Spark execution)
* PySpark and `pytest`

### Installation & Execution
```bash
# 1. Activate your virtual environment
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# 2. Install dependencies
pip install pyspark pytest

# 3. Run the 4-Day Risk-Based DW Test Suite
pytest four-day-test-plan/test_dw_4day_plan.py -v
```
