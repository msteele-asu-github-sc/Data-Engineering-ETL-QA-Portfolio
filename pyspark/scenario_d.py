'''
Test Requirement:  Using Delta Time Travel for Regression/Migration Testing
Interview Question: "How do you query a previous version of a Delta table to verify what changed
after an ETL job ran?"
'''
from pyspark.shell import spark

# Compare current table state against version 10 (before the batch job ran)
prev_df = spark.read.format("delta").option("versionAsOf", 10).table("gold.fact_transactions")
curr_df = spark.table("gold.fact_transactions")

# Find newly inserted or updated records
delta_records = curr_df.subtract(prev_df)
print(f"Total records modified or added in latest run: {delta_records.count()}")
