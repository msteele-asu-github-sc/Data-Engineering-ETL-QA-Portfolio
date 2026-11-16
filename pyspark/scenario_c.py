'''
Test Requirement: Validating SCD Type 2 (Slowly Changing Dimensions)
Interview Question: "Your job description mentions SCD validations. How do you validate an
SCD Type 2 table in Databricks?"
'''

from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Check 1: Ensure no business key has more than one active record
multiple_active = (
    dim_customer_df.filter(F.col("is_current") == True)
    .groupBy("customer_id")
    .count()
    .filter(F.col("count") > 1)
)
assert multiple_active.count() == 0, "SCD2 Error: Multiple active records found for a single customer!"

# Check 2: Ensure effective_start_date of new record equals effective_end_date of previous record
window_spec = Window.partitionBy("customer_id").orderBy("effective_start_date")

scd_continuity = dim_customer_df.withColumn(
    "prev_end_date", F.lag("effective_end_date").over(window_spec)
).filter(
    F.col("prev_end_date").isNotNull() & (F.col("effective_start_date") != F.col("prev_end_date"))
)
assert scd_continuity.count() == 0, "SCD2 Error: Date gap or overlap detected!"
