CREATE TABLE patients (
    patient_id INT PRIMARY KEY,
    medicaid_member_id VARCHAR(12) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    dob DATE NOT NULL
);

CREATE TABLE providers (
    provider_id INT PRIMARY KEY,
    billing_npi CHAR(10) NOT NULL,
    taxonomy_code VARCHAR(10) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE claims (
    claim_id INT PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    provider_id INT REFERENCES providers(provider_id),
    icd10_primary VARCHAR(10) NOT NULL,
    cpt_code VARCHAR(5) NOT NULL,
    service_date DATE NOT NULL,
    claim_status VARCHAR(20)
);

CREATE TABLE edi_transmission_logs (
    log_id INT PRIMARY KEY,
    batch_filename VARCHAR(100) NOT NULL,
    snip_validation_status VARCHAR(20) NOT NULL,
    sftp_remote_path VARCHAR(255),
    transmitted_at_utc TIMESTAMP,
    error_message TEXT
);
