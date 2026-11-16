from pyspark.sql import functions as F

# 1. Read raw EDI 837 text file (assuming segments are separated by '~')
raw_df = spark.read.text("/mnt/landing/edi_837p_batch.txt")

# 2. Split the raw string into individual segments and explode into rows
segments_df = (
    raw_df.withColumn("segment", F.explode(F.split(F.col("value"), "~")))
    .withColumn("segment", F.trim(F.col("segment")))
    .filter(F.col("segment") != "")
    .withColumn("segment_id", F.split(F.col("segment"), "\*").getItem(0))
)

# 3. Extract Claim-level details from the CLM segment
# Example CLM segment: CLM*123456789*250.00***11:B:1*Y*A*Y*Y~
clm_df = (
    segments_df.filter(F.col("segment_id") == "CLM")
    .withColumn("elements", F.split(F.col("segment"), "\*"))
    .select(
        F.col("elements").getItem(1).alias("claim_id"),
        F.col("elements").getItem(2).cast("decimal(10,2)").alias("total_claim_charge"),
        F.split(F.col("elements").getItem(5), ":").getItem(0).alias("place_of_service"),
        F.col("elements").getItem(6).alias("provider_signature_ind")
    )
)

clm_df.show(truncate=False)
