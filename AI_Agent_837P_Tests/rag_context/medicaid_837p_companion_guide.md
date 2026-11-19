# State Medicaid 837P (005010X222A1) Companion Guide Rules

- **SNIP Validation:** All outbound batch files must pass SNIP Level 1 (X12 syntax and delimiters) and SNIP Level 2 (HIPAA implementation guide rules) prior to SFTP transmission.
- **Loop 2010BA (Subscriber/Patient):** Element `NM109` must contain a valid 9-to-12-digit numeric State Medicaid Member ID. Alphanumeric characters or lengths `< 9` or `> 12` must fail validation.
- **Loop 2010AA (Billing Provider):** Element `NM109` must contain an active 10-digit NPI passing Luhn check-digit validation. Segment `PRV03` must contain a valid 10-character NUCC Healthcare Provider Taxonomy Code (e.g., `207Q00000X` for Family Medicine).
- **Loop 2300 (Claim Diagnosis):** Segment `HI` must contain at least one active ICD-10-CM diagnosis code (e.g., `I10`, `E11.9`) valid for the Date of Service.
- **Loop 2400 (Service Line):** Segment `SV101` must contain a valid 5-character CPT/HCPCS procedure code (e.g., `99213`, `99214`) with qualifier `HC`.
- **SFTP Transmission:** Files must transmit over SFTP to `/outbound/medicaid/837p/` and record a UTC confirmation timestamp in `edi_transmission_logs`.
