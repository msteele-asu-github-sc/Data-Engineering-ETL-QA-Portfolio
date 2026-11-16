--Example A: Flattening Nested Arrays with UNNEST()
-- Validate that total claim charge equals the sum of nested service line charges
SELECT
    c.claim_id,
    c.total_claim_charge,
    SUM(line.charge_amount) AS sum_line_charges
FROM `project.gold.fact_claims` c,
UNNEST(c.service_lines) AS line
GROUP BY c.claim_id, c.total_claim_charge
HAVING c.total_claim_charge != SUM(line.charge_amount);

--Example B: Full-Row Comparison using EXCEPT DISTINCT and TO_JSON_STRING()
-- Find any rows in Staging that do not match Production 100%
SELECT claim_id, TO_JSON_STRING(t) AS row_payload
FROM `project.staging.expected_claims` AS t
EXCEPT DISTINCT
SELECT claim_id, TO_JSON_STRING(t) AS row_payload
FROM `project.gold.fact_claims` AS t;

--Example C: BigQuery Time Travel (FOR SYSTEM_TIME AS OF)
-- Query records inserted in the last 30 minutes
SELECT *
FROM `project.gold.fact_claims`
EXCEPT DISTINCT
SELECT *
FROM `project.gold.fact_claims`
FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 MINUTE);


