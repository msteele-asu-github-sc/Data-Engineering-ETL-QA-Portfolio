--1. Apache Hive (Batch SQL Warehousing & Partition Testing)
-- Verify partitions exist and check for unexpected row count drops across load dates
SHOW PARTITIONS claims_db.fact_claims;

SELECT load_date, COUNT(*) AS row_count, SUM(charge_amount) AS total_charges
FROM claims_db.fact_claims
WHERE load_date >= '2026-11-01'
GROUP BY load_date
ORDER BY load_date DESC;

