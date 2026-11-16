'''
Test Requirement:
Interview Question: "How do you automate data quality checks for primary key uniqueness and mandatory
non-null columns in PySpark?"
'''


from pyspark.sql import functions as F


def run_dq_checks(df, pk_cols, non_null_cols):
    # 1. Check for Duplicate Primary Keys
    duplicates = (
        df.groupBy(pk_cols)
        .count()
        .filter(F.col("count") > 1)
    )
    dup_count = duplicates.count()

    # 2. Check for Nulls in Mandatory Columns
    null_checks = {}
    for col_name in non_null_cols:
        null_count = df.filter(F.col(col_name).isNull() | (F.trim(F.col(col_name)) == "")).count()
        if null_count > 0:
            null_checks[col_name] = null_count

    return {"duplicate_keys": dup_count, "null_violations": null_checks}


# Example usage
results = run_dq_checks(target_df, pk_cols=["account_id", "transaction_date"], non_null_cols=["customer_id", "amount"])
print(results)
