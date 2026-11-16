from pyspark.sql import functions as F

# Example: Exploding nested service lines to validate CPT/HCPCS procedure codes against a reference table
exploded_lines_df = (
    nested_837_df.select(
        "claim_id",
        "subscriber_id",
        F.explode("service_lines").alias("line")
    )
    .select(
        "claim_id",
        "subscriber_id",
        F.col("line.line_num").alias("line_num"),
        F.col("line.procedure_code").alias("cpt_code"),
        F.col("line.charge_amount").alias("charge_amount")
    )
)

# Referential Integrity Check: Find any CPT codes not present in the active CMS/CPT Dimension table
invalid_cpt_df = (
    exploded_lines_df.alias("s")
    .join(dim_cpt_codes.alias("d"), F.col("s.cpt_code") == F.col("d.cpt_code"), how="left_anti")
)

invalid_cpt_df.show()
