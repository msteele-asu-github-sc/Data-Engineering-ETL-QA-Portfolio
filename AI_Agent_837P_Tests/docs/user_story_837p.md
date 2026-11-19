# User Story: Professional Claim Submission (ANSI X12 837P 5010)

**Story ID:** `US-837P-001`  
**Transaction Set:** ANSI X12 837P (`005010X222A1`)  
**Domain:** Healthcare / Medicaid Outpatient Claims  

---

## Story Statement
**As a** Medicaid billing specialist,  
**I want to** generate and transmit an ANSI X12 837P (`5010`) batch file for outpatient physician visits,  
**So that** our clinic receives timely reimbursement from the state Medicaid agency.

---

## Acceptance Criteria

* **AC-1 | File Format & SNIP Validation:**  
  The system generates a valid X12 837P (`005010X222A1`) batch file that passes basic **SNIP Level 1** (X12 syntax and delimiter) and **SNIP Level 2** (HIPAA implementation guide) validation prior to transmission.

* **AC-2 | Subscriber & Patient Data (`Loop 2010BA`):**  
  `Loop 2010BA` accurately maps the patient's **9-to-12-digit numeric Medicaid Member ID** into element `NM109`.

* **AC-3 | Provider Identifiers (`Loop 2010AA`):**  
  `Loop 2010AA` includes the billing provider’s active **10-digit National Provider Identifier (NPI)** in element `NM109` (with qualifier `XX` in `NM108`) and a valid **NUCC Taxonomy Code** in segment `PRV03`.

* **AC-4 | Clinical Coding Accuracy (`Loop 2300` & `Loop 2400`):**  
  `Loop 2300` contains valid **ICD-10-CM** diagnosis codes in segment `HI`, and `Loop 2400` contains valid **CPT/HCPCS** procedure codes in segment `SV101` (with qualifier `HC`).

* **AC-5 | Secure Transmission & Audit Logging:**  
  The validated batch file is securely uploaded to the state Medicaid EDI gateway via **SFTP** (`/outbound/medicaid/837p/`) and logs a confirmation **UTC timestamp** in the `edi_transmission_logs` database table.
