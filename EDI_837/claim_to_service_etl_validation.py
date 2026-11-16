from pyspark.sql import functions as F

# Assume silver_claims (CLM level) and silver_claim_lines (SV1/SV2 level) are already parsed
# 1. Aggregate service line charges per claim
line_totals_df = (
    silver_claim_lines.groupBy("claim_id")
    .agg(
        F.sum("line_charge_amount").cast("decimal(10,2)").alias("sum_line_charges"),
        F.count("line_number").alias("line_count")
    )
)

# 2. Join back to the Claim Header table and detect financial imbalances
imbalanced_claims_df = (
    silver_claims.alias("c")
    .join(line_totals_df.alias("l"), on="claim_id", how="left")
    .withColumn("sum_line_charges", F.coalesce(F.col("sum_line_charges"), F.lit(0.00)))
    .filter(
        (F.col("c.total_claim_charge") != F.col("sum_line_charges")) |
        (F.col("l.line_count").isNull())
    )
    .select(
        "claim_id",
        "total_claim_charge",
        "sum_line_charges",
        (F.col("total_claim_charge") - F.col("sum_line_charges")).alias("variance")
    )
)

# Assert zero imbalanced claims before loading to Gold / Outbound 837 generator
assert imbalanced_claims_df.count() == 0, "837 Validation Error: Claim header charges do not match line sums!"
