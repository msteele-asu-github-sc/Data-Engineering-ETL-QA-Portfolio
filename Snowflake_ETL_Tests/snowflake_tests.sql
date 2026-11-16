--Example A: Deduplication & SCD2 Check using QUALIFY
-- Find duplicate active records in an SCD Type 2 Dimension table
SELECT member_id, effective_start_date, is_current
FROM GOLD.DIM_MEMBER
WHERE is_current = 'Y'
QUALIFY ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY effective_start_date DESC) > 1;

--Example B: Source-to-Target Reconciliation using HASH(*) & MINUS
-- Compare Target vs. Source view using full-row hashing
SELECT claim_id, HASH(*) AS row_hash FROM GOLD.FACT_CLAIMS
MINUS
SELECT claim_id, HASH(*) AS row_hash FROM STAGING.VW_EXPECTED_CLAIMS;

--Example C: Snowflake Time Travel for Regression Testing
-- Compare current table count against 1 hour ago (before ETL load)
SELECT
    (SELECT COUNT(*) FROM GOLD.FACT_CLAIMS) AS current_count,
    (SELECT COUNT(*) FROM GOLD.FACT_CLAIMS AT(OFFSET => -3600)) AS prior_count;

--

--

