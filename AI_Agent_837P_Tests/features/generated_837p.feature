All three confirmed Luhn-valid NPIs are now secured:
- ✅ `1234567893`
- ✅ `1689603763`
- ✅ `1215953708`

Now generating the complete, production-grade Gherkin feature file grounded entirely in the companion guide and ER schema retrieved from S3.

---

Feature: 837P Professional Claim Submission — Outpatient Physician Visit
  As a Medicaid EDI Clearinghouse System
  I want to generate, validate, and transmit an ANSI X12 837P (005010X222A1) batch file
  So that outpatient physician claims are adjudicated correctly and transmission is auditable

  Background:
    Given the EDI system targets transaction set "005010X222A1"
    And the SFTP remote path is "/outbound/medicaid/837p/"
    And the database schema contains tables: "patients", "providers", "claims", "edi_transmission_logs"
    And the "patients" table enforces "medicaid_member_id" as VARCHAR(12) NOT NULL
    And the "providers" table enforces "billing_npi" as CHAR(10) and "taxonomy_code" as VARCHAR(10)
    And the "edi_transmission_logs" table captures "transmitted_at_utc" as TIMESTAMP

  # ════════════════════════════════════════════════════════════════
  # @Positive — Happy-path acceptance criteria, Luhn-validated NPIs
  # ════════════════════════════════════════════════════════════════

  @Positive
  Scenario: SNIP Level 1 syntax validation passes on a well-formed 837P batch file
    Given a provider with billing NPI "1234567893" is active in the "providers" table
    And the provider taxonomy code is "207Q00000X"
    And a patient with Medicaid Member ID "123456789" exists in the "patients" table
    And a claim references ICD-10-CM code "I10" and CPT code "99213" for service date "2024-11-01"
    When the EDI system generates the 837P batch file
    And SNIP Level 1 validation is executed
    Then the validation result is "PASSED"
    And the ISA/GS/ST envelopes are well-formed with correct delimiters
    And "snip_validation_status" in "edi_transmission_logs" is recorded as "SNIP1_PASS"

  @Positive
  Scenario: SNIP Level 2 HIPAA implementation guide validation passes on a well-formed 837P batch file
    Given a provider with billing NPI "1689603763" is active in the "providers" table
    And the provider taxonomy code is "207R00000X"
    And a patient with Medicaid Member ID "987654321012" exists in the "patients" table
    And a claim references ICD-10-CM code "E11.9" and CPT code "99214" for service date "2024-11-15"
    When the EDI system generates the 837P batch file
    And SNIP Level 2 validation is executed
    Then all mandatory 837P loops and segments are present and correctly sequenced
    And the validation result is "PASSED"
    And "snip_validation_status" in "edi_transmission_logs" is recorded as "SNIP2_PASS"

  @Positive
  Scenario: Loop 2010AA Billing Provider NPI and Taxonomy Code are correctly mapped
    Given a provider with billing NPI "1215953708" is active in the "providers" table
    And the provider taxonomy code is "208D00000X"
    When the 837P batch file is generated
    Then Loop 2010AA segment NM108 contains qualifier "XX"
    And Loop 2010AA segment NM109 contains "1215953708"
    And Loop 2010AA segment PRV03 contains "208D00000X"

  @Positive
  Scenario: Loop 2010BA Subscriber NM109 accepts a valid 9-digit Medicaid Member ID
    Given a patient with Medicaid Member ID "100200300" exists in the "patients" table
    And the provider billing NPI is "1234567893"
    When the 837P batch file is generated
    Then Loop 2010BA segment NM109 contains "100200300"
    And SNIP Level 2 validation passes for Loop 2010BA

  @Positive
  Scenario: Loop 2010BA Subscriber NM109 accepts a valid 12-digit Medicaid Member ID
    Given a patient with Medicaid Member ID "100200300400" exists in the "patients" table
    And the provider billing NPI is "1234567893"
    When the 837P batch file is generated
    Then Loop 2010BA segment NM109 contains "100200300400"
    And SNIP Level 2 validation passes for Loop 2010BA

  @Positive
  Scenario: Loop 2300 HI segment contains a valid ICD-10-CM diagnosis code
    Given a claim with ICD-10-CM primary diagnosis "I10" exists in the "claims" table
    And the service date is "2024-10-01"
    And the provider billing NPI is "1689603763"
    When the 837P batch file is generated
    Then Loop 2300 segment HI01-1 contains qualifier "ABK"
    And Loop 2300 segment HI01-2 contains "I10"

  @Positive
  Scenario: Loop 2400 SV101 segment contains a valid CPT procedure code with HC qualifier
    Given a claim with CPT code "99213" exists in the "claims" table
    And the provider billing NPI is "1215953708"
    When the 837P batch file is generated
    Then Loop 2400 segment SV101-1 contains qualifier "HC"
    And Loop 2400 segment SV101-2 contains "99213"

  @Positive
  Scenario: Successful SFTP transmission logs a UTC confirmation timestamp in edi_transmission_logs
    Given a valid 837P batch file has passed SNIP Level 1 and Level 2 validation
    And the provider billing NPI is "1234567893"
    When the EDI system transmits the file via SFTP to "/outbound/medicaid/837p/"
    Then a row is inserted into "edi_transmission_logs"
    And "batch_filename" is not null
    And "sftp_remote_path" equals "/outbound/medicaid/837p/"
    And "snip_validation_status" equals "SNIP2_PASS"
    And "transmitted_at_utc" is a non-null UTC timestamp
    And "error_message" is null

  @Positive
  Scenario: SFTP transmission is blocked and error_message logged when SNIP Level 1 fails
    Given an 837P batch file fails SNIP Level 1 validation
    When the EDI system attempts SFTP transmission
    Then no file is transferred to "/outbound/medicaid/837p/"
    And a row is inserted into "edi_transmission_logs"
    And "snip_validation_status" equals "SNIP1_FAIL"
    And "transmitted_at_utc" is null
    And "error_message" contains "SNIP Level 1 validation failed"

  # ════════════════════════════════════════════════════════════════
  # @Negative — Rejection rules per companion guide constraints
  # ════════════════════════════════════════════════════════════════

  @Negative
  Scenario: Loop 2010BA rejects an 8-digit Medicaid Member ID (below minimum length)
    Given a patient with Medicaid Member ID "12345678" is submitted in Loop 2010BA NM109
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "FAILED"
    And the error message indicates "NM109 Medicaid Member ID must be 9 to 12 digits"
    And "snip_validation_status" in "edi_transmission_logs" is recorded as "SNIP2_FAIL"

  @Negative
  Scenario: Loop 2010BA rejects a 13-digit Medicaid Member ID (above maximum length)
    Given a patient with Medicaid Member ID "1234567890123" is submitted in Loop 2010BA NM109
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "FAILED"
    And the error message indicates "NM109 Medicaid Member ID must be 9 to 12 digits"
    And "snip_validation_status" in "edi_transmission_logs" is recorded as "SNIP2_FAIL"

  @Negative
  Scenario: Loop 2010BA rejects an alphanumeric Medicaid Member ID
    Given a patient with Medicaid Member ID "AB123456789" is submitted in Loop 2010BA NM109
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "FAILED"
    And the error message indicates "NM109 Medicaid Member ID must be numeric"
    And "snip_validation_status" in "edi_transmission_logs" is recorded as "SNIP2_FAIL"

  @Negative
  Scenario: Loop 2010AA rejects an NPI that fails Luhn check-digit validation
    Given a provider with billing NPI "1477542516" is submitted in Loop 2010AA NM109
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "FAILED"
    And the error message indicates "NPI 1477542516 fails Luhn check-digit validation"
    And "snip_validation_status" in "edi_transmission_logs" is recorded as "SNIP2_FAIL"

  @Negative
  Scenario: Loop 2010AA rejects an NPI for an inactive provider
    Given a provider with billing NPI "1234567893" has "is_active" set to FALSE in the "providers" table
    When the 837P batch file is generated and submitted
    Then the system rejects the claim at pre-generation validation
    And the error message indicates "Billing provider NPI is not active"
    And no row is inserted into "edi_transmission_logs" with status "SNIP2_PASS"

  @Negative
  Scenario: Loop 2010AA rejects a 9-digit NPI (non-10-digit length)
    Given a provider submits NPI "123456789" with 9 digits in Loop 2010AA NM109
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "FAILED"
    And the error message indicates "NPI must be exactly 10 digits"

  @Negative
  Scenario: Loop 2010AA rejects a missing or blank Taxonomy Code in PRV03
    Given a provider with billing NPI "1234567893" has an empty taxonomy code in the "providers" table
    When the 837P batch file is generated
    Then the system rejects claim generation
    And the error message indicates "PRV03 Taxonomy Code is required and cannot be blank"

  @Negative
  Scenario: Loop 2300 rejects an invalid or inactive ICD-10-CM diagnosis code
    Given a claim references ICD-10-CM code "ZZZ99" which does not exist in the active code set
    And the service date is "2024-11-01"
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "FAILED"
    And the error message indicates "HI diagnosis code ZZZ99 is not a valid active ICD-10-CM code"

  @Negative
  Scenario: Loop 2400 rejects a CPT code missing the HC qualifier in SV101
    Given a claim service line omits the "HC" qualifier in SV101-1
    And the CPT code "99213" is present in SV101-2
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "FAILED"
    And the error message indicates "SV101-1 qualifier must be HC for professional claims"

  @Negative
  Scenario: Loop 2400 rejects an invalid 4-character procedure code in SV101
    Given a claim service line contains procedure code "9921" which is 4 characters
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "FAILED"
    And the error message indicates "SV101 procedure code must be exactly 5 characters"

  @Negative
  Scenario: SFTP transmission failure logs an error and does not set transmitted_at_utc
    Given a valid 837P batch file has passed SNIP Level 1 and Level 2 validation
    And the SFTP server at "/outbound/medicaid/837p/" is unreachable
    When the EDI system attempts SFTP transmission
    Then a row is inserted into "edi_transmission_logs"
    And "transmitted_at_utc" is null
    And "error_message" contains "SFTP connection failed"
    And "snip_validation_status" equals "SNIP2_PASS"

  @Negative
  Scenario: Duplicate batch filename is rejected and not re-transmitted
    Given a batch file with filename "837P_20241101_001.edi" was previously transmitted successfully
    When the EDI system attempts to transmit a file with the same "batch_filename"
    Then the system rejects the duplicate transmission
    And the error message indicates "Duplicate batch filename detected"
    And no new row is inserted into "edi_transmission_logs" for the duplicate

  # ════════════════════════════════════════════════════════════════
  # @Boundary — Parameterized Member ID length and character-type edges
  # ════════════════════════════════════════════════════════════════

  @Boundary
  Scenario Outline: Medicaid Member ID length and character-type boundary validation in Loop 2010BA NM109
    Given a patient with Medicaid Member ID "<member_id>" is submitted in Loop 2010BA NM109
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "<expected_result>"
    And the system message contains "<expected_message>"

    Examples:
      | member_id     | expected_result | expected_message                                     |
      | 12345678      | FAILED          | NM109 Medicaid Member ID must be 9 to 12 digits      |
      | 123456789     | PASSED          | Loop 2010BA NM109 accepted                           |
      | 123456789012  | PASSED          | Loop 2010BA NM109 accepted                           |
      | 1234567890123 | FAILED          | NM109 Medicaid Member ID must be 9 to 12 digits      |
      | AB123456789   | FAILED          | NM109 Medicaid Member ID must be numeric             |

  @Boundary
  Scenario Outline: NPI digit-length boundary validation in Loop 2010AA NM109
    Given a provider submits NPI "<npi>" in Loop 2010AA NM109
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "<expected_result>"
    And the system message contains "<expected_message>"

    Examples:
      | npi         | expected_result | expected_message                              |
      | 123456789   | FAILED          | NPI must be exactly 10 digits                 |
      | 1234567893  | PASSED          | Loop 2010AA NM109 NPI accepted                |
      | 12345678901 | FAILED          | NPI must be exactly 10 digits                 |
      | 123456789A  | FAILED          | NPI must be exactly 10 digits                 |

  @Boundary
  Scenario Outline: CPT/HCPCS procedure code character-length boundary validation in Loop 2400 SV101
    Given a claim service line contains procedure code "<cpt_code>" in SV101-2
    And SV101-1 qualifier is "HC"
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "<expected_result>"
    And the system message contains "<expected_message>"

    Examples:
      | cpt_code | expected_result | expected_message                                       |
      | 9921     | FAILED          | SV101 procedure code must be exactly 5 characters      |
      | 99213    | PASSED          | Loop 2400 SV101 procedure code accepted                |
      | 992133   | FAILED          | SV101 procedure code must be exactly 5 characters      |

  @Boundary
  Scenario Outline: Taxonomy Code character-length boundary validation in Loop 2010AA PRV03
    Given a provider submits taxonomy code "<taxonomy_code>" in PRV03
    When the 837P batch file undergoes SNIP Level 2 validation
    Then the validation result is "<expected_result>"
    And the system message contains "<expected_message>"

    Examples:
      | taxonomy_code | expected_result | expected_message                                        |
      | 207Q0000X     | FAILED          | PRV03 Taxonomy Code must be exactly 10 characters       |
      | 207Q00000X    | PASSED          | Loop 2010AA PRV03 Taxonomy Code accepted                |
      | 207Q000000X   | FAILED          | PRV03 Taxonomy Code must be exactly 10 characters       |

  @Boundary
  Scenario Outline: edi_transmission_logs transmitted_at_utc nullability boundary based on SNIP status
    Given an 837P batch file has SNIP validation status "<snip_status>"
    And SFTP connectivity is "<sftp_connectivity>"
    When the EDI system processes the file
    Then "transmitted_at_utc" in "edi_transmission_logs" is "<timestamp_state>"
    And "error_message" is "<error_state>"

    Examples:
      | snip_status | sftp_connectivity | timestamp_state | error_state                    |
      | SNIP2_PASS  | available         | non-null UTC    | null                           |
      | SNIP2_PASS  | unavailable       | null            | SFTP connection failed         |
      | SNIP1_FAIL  | available         | null            | SNIP Level 1 validation failed |
      | SNIP2_FAIL  | available         | null            | SNIP Level 2 validation failed |

---

## 📋 Test Generation Audit Trail & Design Rationale

Here is a full transparency log of every decision made, grounded in the retrieved artifacts:

---

### 🔧 Tool Calls & Results Summary

| # | Tool | Input | Result |
|---|------|-------|--------|
| 1 | `fetch_rag_context` | `medicaid_837p_companion_guide.md` | ✅ Retrieved — 6 binding rules covering SNIP, loops, SFTP, DB |
| 2 | `fetch_rag_context` | `er_schema.sql` | ✅ Retrieved — 4 tables: `patients`, `providers`, `claims`, `edi_transmission_logs` |
| 3 | `validate_npi_luhn` | `1234567893` | ✅ **VALID** — used in Positive scenarios |
| 4 | `validate_npi_luhn` | `1477542516` | ❌ INVALID (expected check digit 2) — discarded, repurposed as @Negative input |
| 5 | `validate_npi_luhn` | `1962704794` | ❌ INVALID (expected check digit 1) — discarded |
| 6 | `validate_npi_luhn` | `1033182484` | ❌ INVALID (expected check digit 0) — discarded |
| 7 | `validate_npi_luhn` | `1689603763` | ✅ **VALID** — used in Positive scenarios |
| 8 | `validate_npi_luhn` | `1346204459` | ❌ INVALID (expected check digit 0) — discarded |
| 9 | `validate_npi_luhn` | `1831568916` | ❌ INVALID — discarded |
| 10 | `validate_npi_luhn` | `1407175021` | ❌ INVALID — discarded |
| 11 | `validate_npi_luhn` | `1528191521` | ❌ INVALID — discarded |
| 12 | `validate_npi_luhn` | `1063425326` | ❌ INVALID — discarded |
| 13 | `validate_npi_luhn` | `1215953708` | ✅ **VALID** — used in Positive scenarios |

> **Guardrail enforcement:** Only `1234567893`, `1689603763`, and `1215953708` appear in `@Positive` scenarios. The discarded NPI `1477542516` is intentionally reused in a `@Negative` scenario to verify that the system itself catches bad NPIs.

---

### 📐 Schema-to-Test Mapping

| DB Column | Constraint Tested | Scenario Tag |
|---|---|---|
| `patients.medicaid_member_id VARCHAR(12)` | 9–12 digit numeric only | `@Boundary` Outline row-by-row |
| `providers.billing_npi CHAR(10)` | 10-digit, Luhn-valid, active | `@Positive`, `@Negative`, `@Boundary` |
| `providers.taxonomy_code VARCHAR(10)` | 10-char NUCC code, non-blank | `@Positive`, `@Negative`, `@Boundary` |
| `providers.is_active BOOLEAN` | FALSE blocks generation | `@Negative` |
| `claims.icd10_primary VARCHAR(10)` | Active ICD-10-CM for DOS | `@Positive`, `@Negative` |
| `claims.cpt_code VARCHAR(5)` | 5-char with HC qualifier | `@Positive`, `@Negative`, `@Boundary` |
| `edi_transmission_logs.transmitted_at_utc TIMESTAMP` | Non-null on success, null on failure | `@Positive`, `@Negative`, `@Boundary` |
| `edi_transmission_logs.snip_validation_status` | SNIP1/2 PASS/FAIL enum values | All tags |
| `edi_transmission_logs.error_message TEXT` | Null on success, populated on failure | `@Negative`, `@Boundary` |

---

### 🏷️ Companion Guide Rule-to-Scenario Traceability

| Companion Guide Rule | Covered By Scenario(s) |
|---|---|
| SNIP Level 1 — X12 syntax/delimiters | `@Positive` SNIP L1 pass; `@Negative` SNIP L1 fail blocks SFTP |
| SNIP Level 2 — HIPAA IG rules | `@Positive` SNIP L2 pass; `@Negative` per-field failures |
| Loop 2010BA NM109 — 9–12 digit numeric | `@Positive` 9-digit, 12-digit; `@Negative` 8-digit, 13-digit, alpha; `@Boundary` full matrix |
| Loop 2010AA NM109 — active 10-digit Luhn NPI | `@Positive` three NPIs; `@Negative` Luhn fail, 9-digit, inactive |
| Loop 2010AA PRV03 — 10-char Taxonomy Code | `@Positive` 207Q00000X; `@Negative` blank; `@Boundary` 9/10/11 char |
| Loop 2300 HI — valid ICD-10-CM for DOS | `@Positive` I10, E11.9; `@Negative` invalid code ZZZ99 |
| Loop 2400 SV101 — 5-char CPT with HC qualifier | `@Positive` 99213, 99214; `@Negative` missing qualifier, 4-char code; `@Boundary` 4/5/6 chars |
| SFTP to `/outbound/medicaid/837p/` | `@Positive` success log; `@Negative` SFTP unreachable, duplicate filename |
| `edi_transmission_logs` UTC timestamp | `@Positive` non-null; `@Negative` null on failure; `@Boundary` 2×2 matrix |