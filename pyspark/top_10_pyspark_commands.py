
#1. join() with left_anti (Source-to-Target & Referential Integrity)
# Find claims in Fact table whose provider_id is missing from Dim_Provider
orphans = fact_df.join(dim_provider_df, on="provider_id", how="left_anti")

#2. sha2() + concat_ws() (Fast Row-by-Row Data Reconciliation)
from pyspark.sql import functions as F
# Create a single hash fingerprint of the entire row (handling nulls safely with concat_ws)
df_hashed = df.withColumn("row_hash", F.sha2(F.concat_ws("||", *df.columns), 256))

#3. Window with row_number() and lag() (SCD Type 2 & Deduplication)
from pyspark.sql.window import Window
win = Window.partitionBy("customer_id").orderBy(F.col("updated_at").desc())
dups = df.withColumn("rn", F.row_number().over(win)).filter(F.col("rn") > 1)

#4. when() and otherwise() (Business Logic & Data Quality Tagging)
df_checked = df.withColumn(
    "dq_status",
    F.when(F.col("charge_amount") <= 0, "FAIL_NEGATIVE_AMOUNT")
     .when(F.col("claim_id").isNull(), "FAIL_NULL_ID")
     .otherwise("PASS")
)

#5. groupBy() and agg() (Completeness & Financial Balancing)
summary = df.groupBy("region").agg(
    F.count("*").alias("row_count"),
    F.sum("amount").alias("total_amount")
)

#6. coalesce() (Null Handling & Default Values)
# Safely compare two nullable columns
mismatches = df.filter(F.coalesce(F.col("src_code"), F.lit("NA")) != F.coalesce(F.col("tgt_code"), F.lit("NA")))

#7. explode() (Flattening Nested JSON, Arrays, and Structs)
# Turn an array of service lines into one row per service line
flat_df = nested_df.select("claim_id", F.explode("service_lines").alias("line"))

#8. rlike() (Regex Pattern & Format Validation)
invalid_npi = df.filter(~F.col("npi").rlike("^[0-9]{10}$"))

#9. trim() and upper() / lower() (String Standardization)
clean_df = df.withColumn("state_code", F.upper(F.trim(F.col("state_code"))))

#10. to_date() / to_timestamp() (Date Parsing & Timezone Alignment)
df_dates = df.withColumn("service_dt", F.to_date(F.col("raw_date_str"), "yyyyMMdd"))

#

