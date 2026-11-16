--1. Dimensions & Facts (Star Schema Validation)
-- Find any Fact records with an invalid or missing Provider Surrogate Key
SELECT f.claim_id, f.provider_sk
FROM gold.fact_claims f
LEFT JOIN gold.dim_provider d
  ON f.provider_sk = d.provider_sk
WHERE d.provider_sk IS NULL;
-- Expected Result: 0 rows

-- 2. Slowly Changing Dimensions (SCD) Validations
-- 1. Check for multiple active records per business key
SELECT member_id, COUNT(*) AS active_count
FROM gold.dim_member
WHERE is_current = 'Y'
GROUP BY member_id
HAVING COUNT(*) > 1;

-- 2. Check for date gaps or overlaps between historical versions
WITH scd_history AS (
    SELECT
        member_id,
        effective_start_date,
        effective_end_date,
        LAG(effective_end_date) OVER (PARTITION BY member_id ORDER BY effective_start_date) AS prev_end_date
    FROM gold.dim_member
)
SELECT *
FROM scd_history
WHERE prev_end_date IS NOT NULL
  AND effective_start_date != prev_end_date;
-- Expected Result for both queries: 0 rows


--3. End-to-End Star Schema Scenario (Interview Talking Point)

--

--

--

