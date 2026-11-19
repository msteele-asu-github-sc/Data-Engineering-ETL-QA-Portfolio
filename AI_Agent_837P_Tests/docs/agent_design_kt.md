# QA Test Generation Agent — Design & Knowledge Transfer (KT) Specification

## 1. Objective
Automate the translation of Medicaid EDI User Stories into traceable, standardized Gherkin (`.feature`) test suites covering Positive, Negative, and Special Value (Boundary) scenarios without exposing PHI/PII.

## 2. Architecture Flow (Inputs -> Guardrails -> Outputs)
1. **Inputs:**
   - Jira User Story & Acceptance Criteria (e.g., 837P Claim Submission).
   - `medicaid_837p_companion_guide.md` (State X12 loop & segment rules).
   - `er_schema.sql` (Relational database tables and constraints).
2. **Deterministic Guardrails (Validation Tools):**
   - **NPI Luhn Check:** Every synthetic 10-digit NPI used in `@Positive` scenarios must pass the CMS Luhn check-digit algorithm before output.
   - **HIPAA PHI Isolation:** Only synthetic, de-identified test records may be generated.
3. **Output Artifact:**
   - A valid Gherkin `.feature` file tagged with `@Positive`, `@Negative`, and `@Boundary`, mapped explicitly to X12 loops (`2010BA`, `2010AA`, `2300`, `2400`) and SQL audit tables (`edi_transmission_logs`).

## 3. Mandatory Test Coverage Matrix
- **@Positive (Happy Path):** End-to-end valid claim generation, SNIP Level 1 & 2 pass, SFTP upload, and UTC timestamp logging.
- **@Negative (Exception Handling):** Inactive provider NPI, missing `PRV03` taxonomy, invalid/expired ICD-10 diagnosis, and SFTP timeout failure handling.
- **@Boundary (Special Values):** Member ID lengths at exact boundaries (`8`, `9`, `12`, `13` digits), non-numeric Member ID characters, and delimiter escaping.
