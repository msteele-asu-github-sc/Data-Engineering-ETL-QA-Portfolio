Feature: 4-Day Risk-Based Data Warehouse Test Plan
  As a Technology Consultant / Data QA Engineer
  I want to execute a prioritized 4-day validation suite across Bronze, Silver, Gold, and Mart layers
  So that critical schema, data quality, incremental load, and reporting risks are verified before release.

  Background:
    Given an active Apache Spark session connected to the Data Warehouse environment
    And a target batch identifier "BATCH_20261116" has completed execution

  # -------------------------------------------------------------------------
  # DAY 1: Ingestion & Schema Validation (DS -> DSA / Bronze Layer)
  # -------------------------------------------------------------------------
  Scenario: Day 1 - Bronze schema contract, completeness, and reject threshold validation
    Given the expected Bronze claims schema contract is defined
    And the raw source extract contains 1000 records for "BATCH_20261116"
    When the Day 1 Bronze ingestion validation suite runs
    Then all column names, data types, and nullability constraints match the mapping contract
    And the sum of Bronze loaded rows plus quarantined reject rows equals 1000
    And the rejected record rate does not exceed 1.0 percent

  # -------------------------------------------------------------------------
  # DAY 2: Cleansing, Business Rules & Key Integrity (DSA -> ODS / Silver Layer)
  # -------------------------------------------------------------------------
  Scenario: Day 2 - Silver deduplication, domain integrity, and surrogate key checks
    Given the Silver cleansed claims table is populated for "BATCH_20261116"
    And an approved reference table of valid CPT procedure codes is loaded
    When the Day 2 Silver data quality validation suite runs
    Then zero duplicate natural business keys (claim_id, line_number) exist
    And all procedure codes match approved domain values in the reference table
    And all assigned surrogate keys are non-null and positive integers

  # -------------------------------------------------------------------------
  # DAY 3: Warehouse Modeling & Incremental Loads (ODS -> DW / Gold Layer)
  # -------------------------------------------------------------------------
  Scenario: Day 3 - Gold Star Schema referential integrity and incremental load idempotency
    Given the Gold Fact_Claims and Dim_Member tables are loaded for "BATCH_20261116"
    When the Day 3 Gold warehouse validation suite runs
    Then zero orphan foreign keys (member_sk) exist in Fact_Claims
    And zero null records exist in mandatory Fact measure columns
    And re-running the incremental batch job produces zero duplicate Fact records

  # -------------------------------------------------------------------------
  # DAY 4: Data Mart Aggregations, Freshness & Security (DW -> DM & BI Layer)
  # -------------------------------------------------------------------------
  Scenario: Day 4 - Data Mart financial balancing, SLA freshness, and PHI security validation
    Given the Gold Data Mart summary table is refreshed for "BATCH_20261116"
    When the Day 4 Mart and security validation suite runs
    Then total paid claim amounts in the Data Mart equal the cleansed Silver source totals
    And the latest etl_loaded_at timestamp is within the 24-hour freshness SLA
    And non-privileged QA views mask raw SSN/Medicaid ID columns using SHA-256 hashing
