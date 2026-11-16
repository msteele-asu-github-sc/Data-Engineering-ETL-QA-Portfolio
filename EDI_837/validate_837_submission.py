from pyspark.sql import functions as F

# Run automated pre-submission data quality checks on the Gold/Staging 837 dataset
validation_df = (
    gold_837_claims
    .withColumn(
        "is_valid_npi",
        F.col("billing_provider_npi").rlike("^[0-9]{10}$")
    )
    .withColumn(
        "is_valid_service_dates",
        (F.col("service_start_date") <= F.col("service_end_date")) &
        (F.col("service_end_date") <= F.current_date())
    )
    .withColumn(
        "has_primary_dx",
        F.col("primary_diagnosis_code").isNotNull() & (F.trim(F.col("primary_diagnosis_code")) != "")
    )
)

# Filter out failed claims into an Error / Quarantine table for triage
failed_claims_df = validation_df.filter(
    ~F.col("is_valid_npi") | ~F.col("is_valid_service_dates") | ~F.col("has_primary_dx")
)

print(f"Total claims quarantined due to 837 rule failures: {failed_claims_df.count()}")
