'''
Test Requirement:  Source-to-Target Data Reconciliation (Finding Mismatches)
Interview Question: "How would you write a PySpark script to validate that a transformed Target table matches
the Source data after applying business logic?"
'''

from pyspark.sql import functions as F

# Assume source_df (after applying expected mapping rules) and target_df have the same schema
# 1. Row Count Check
source_count = source_df.count()
target_count = target_df.count()
assert source_count == target_count, f"Row count mismatch: Source={source_count}, Target={target_count}"

# 2. Data Content Reconciliation (Find rows in Source not in Target, and vice versa)
missing_in_target = source_df.subtract(target_df)
extra_in_target = target_df.subtract(source_df)

if missing_in_target.count() > 0 or extra_in_target.count() > 0:
    print("Data mismatch detected!")
    missing_in_target.show(10)
    extra_in_target.show(10)
else:
    print("Source and Target match 100%.")
