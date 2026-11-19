# AI QA Test Architect Agent — Medicaid ANSI X12 837P (5010)

## 1. Overview
This project demonstrates a **design-first AI QA pipeline** built on **AWS Bedrock (Claude Sonnet 4.6)** and **Amazon S3**. It transforms a healthcare user story into a traceable, standardized Gherkin (`.feature`) test suite covering **Positive**, **Negative**, and **Special Value (Boundary)** scenarios.

### Why Design-First?
Instead of burying business logic inside opaque Python scripts, this architecture separates **Business Knowledge** (human-readable Markdown & SQL) from **Execution Plumbing** (Python). Every rule lives in plain-text artifacts that serve simultaneously as:
* **Living Knowledge Transfer (KT)** for QA analysts, business stakeholders, and developers.
* **Structured Context** that AI agents can retrieve, parse, and execute without hallucination.

---

## 2. Step 1: The Input — Original User Story
The pipeline begins with a standard Medicaid EDI user story and its acceptance criteria:

* **Feature:** Professional Claim Submission (ANSI X12 837P 5010)
* **User Story:** As a Medicaid billing specialist, I want to generate and transmit an ANSI X12 837P (5010) batch file for outpatient physician visits so that our clinic receives timely reimbursement from the state Medicaid agency.
* **Acceptance Criteria:**
  1. **File Format:** Generates a valid X12 837P (`005010X222A1`) file passing basic SNIP Level 1 and Level 2 syntax validation.
  2. **Subscriber & Patient Data:** Loop `2010BA` maps the patient's 9-to-12-digit Medicaid Member ID in element `NM109`.
  3. **Provider Identifiers:** Loop `2010AA` includes the billing provider's active 10-digit National Provider Identifier (NPI) in `NM109` and NUCC Taxonomy Code in `PRV03`.
  4. **Coding Accuracy:** Loop `2300` contains valid ICD-10-CM diagnosis codes in segment `HI`, and Loop `2400` contains valid CPT/HCPCS procedure codes in `SV101`.
  5. **Transmission:** Securely uploads the batch file to the state Medicaid EDI gateway via SFTP and logs a confirmation UTC timestamp in the database.

---

## 3. Step 2: Design & Domain Knowledge Artifacts
Before writing Python code, all domain rules, relational schemas, and behavioral guardrails are codified in clean, AI-readable files stored in Amazon S3:

| Artifact Path | Role in Pipeline | Description |
| :--- | :--- | :--- |
| `docs/agent_design_kt.md` | **Agent System Brain & KT Spec** | Defines the agent's QA architect role, mandatory Gherkin output format, and coverage rules (`@Positive`, `@Negative`, `@Boundary`). |
| `rag_context/medicaid_837p_companion_guide.md` | **Domain Business Rules (RAG)** | Plain-text Medicaid 837P loop mappings (`2010BA`, `2010AA`, `2300`, `2400`), SNIP Level 1 & 2 constraints, and SFTP directory rules. |
| `rag_context/er_schema.sql` | **Relational Data Schema (RAG)** | SQL `CREATE TABLE` definitions (`patients`, `providers`, `claims`, `edi_transmission_logs`) grounding test steps in exact database columns. |

---

## 4. Step 3: Two-Role Agentic Workflow
Rather than relying on a single static prompt, the orchestrator coordinates two specialized tool-driven capabilities inside a self-correcting loop:

```text
[User Story] 
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│               AWS Bedrock (Claude Sonnet 4.6)                   │
│             Guided by docs/agent_design_kt.md                   │
└───────┬─────────────────────────────────────────────────┬───────┘
        │                                                 │
        ▼ (1) Context Retrieval                           ▼ (2) Deterministic Validation
┌───────────────────────────┐             ┌───────────────────────────┐
│   RAG Knowledge Agent     │             │   Guardrail Critic Agent  │
│  fetch_rag_context()      │             │   validate_npi_luhn()     │
│                           │             │                           │
│ • Reads 837P Guide (S3)   │             │ • Runs CMS Luhn math      │
│ • Reads ER Schema (S3)    │             │ • Rejects invalid NPIs    │
└───────┬───────────────────┘             └───────┬───────────────────┘
        │                                                 │
        └────────────────────────┬────────────────────────┘
                                 ▼
              [features/generated_837p.feature]
         (@Positive  |  @Negative  |  @Boundary)
```

1. **Role 1 — RAG Context Retriever (`fetch_rag_context`):** Queries Amazon S3 to pull the state Medicaid companion guide and SQL ER schema so generated scenarios reference exact X12 segments and table columns.
2. **Role 2 — Deterministic Guardrail Critic (`validate_npi_luhn`):** Executes Python check-digit math (CMS Luhn algorithm with `80840` healthcare prefix) on every synthetic 10-digit NPI. If an NPI fails validation, the agent self-corrects before outputting the test suite.

---

## 5. Step 4: Implementation & Repository Layout

```text
AI_Agent_837P_Tests/
├── README.md                                   # End-to-end design-to-implementation guide
├── requirements.txt                            # Python dependencies (boto3)
├── docs/
│   └── agent_design_kt.md                      # Human & AI-readable KT and behavioral spec
├── rag_context/
│   ├── medicaid_837p_companion_guide.md        # State X12 837P rules
│   └── er_schema.sql                           # Relational SQL schema
├── features/
│   └── generated_837p.feature                  # Output BDD Gherkin test suite
└── src/
    └── run_qa_pipeline.py                      # AWS Bedrock Converse API orchestrator
```

---

## 6. Step 5: Generated Output (`features/generated_837p.feature`)
The pipeline outputs a clean, human-auditable Gherkin `.feature` file organized into three standardized tags:
* **`@Positive`:** End-to-end valid 837P batch generation, SNIP Level 1 & 2 pass, SFTP upload, and UTC timestamp logging in `edi_transmission_logs`.
* **`@Negative`:** Exception handling for inactive provider NPIs, missing `PRV03` taxonomy codes, invalid ICD-10 diagnosis codes, and SFTP timeout failures.
* **`@Boundary`:** Parameterized `Scenario Outline` testing Medicaid Member ID length boundaries (`8`, `9`, `12`, `13` digits) and non-numeric character rejection in Loop `2010BA` (`NM109`).

---

## 7. HIPAA & Security Controls
* **Zero PHI/PII:** All test data is 100% synthetic and de-identified.
* **US-Only Inference Routing:** Uses the `us.anthropic.claude-sonnet-4-6` cross-region inference profile so all data stays strictly inside US AWS regions (`us-east-1`, `us-east-2`, `us-west-2`).
* **12-Factor Configuration:** Cloud resource names are injected via environment variables (`QA_RAG_BUCKET`) with zero hardcoded infrastructure IDs in source control.

---

## 8. How to Run (AWS CloudShell or Local)

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```
2. **Upload KT and RAG artifacts to a private S3 bucket:**
   ```bash
   export QA_RAG_BUCKET="your-s3-rag-bucket-name"
   aws s3 cp docs/agent_design_kt.md s3://\$QA_RAG_BUCKET/
   aws s3 cp rag_context/medicaid_837p_companion_guide.md s3://\$QA_RAG_BUCKET/
   aws s3 cp rag_context/er_schema.sql s3://\$QA_RAG_BUCKET/
   ```
3. **Run the QA Agent pipeline:**
   ```bash
   export AWS_REGION="us-east-1"
   python3 src/run_qa_pipeline.py
   ```
