# Page Object Model (POM) Reverse-Engineering Agent — Design & KT Specification

## 1. Objective
Automate the reverse-engineering of web UI screens (such as State Medicaid Provider Portals)
into clean, maintainable **Playwright Page Object Model (POM)** classes using live DOM
snapshots, visual screenshots, and deterministic locator verification.

## 2. Why Design-First UI Automation?
Manual Page Object creation and maintenance is one of the biggest bottlenecks in QA. Rather
than relying on brittle recorded XPaths or black-box AI scripts, this agent enforces team
coding standards in plain Markdown and verifies every selector against the live DOM before
human PR review.

## 3. Architecture Flow (Inputs -> Guardrails -> Outputs)
1. **Inputs:**
   - **Target Staging URL:** e.g., `/provider-portal/claims/837p-entry`
   - **Live Browser Snapshot:** Simplified Accessibility Tree / stripped HTML DOM plus a
     UI screenshot captured via headless Playwright.
   - **Team POM Coding Standards:** Retrieved dynamically from S3 RAG context.

2. **Deterministic Guardrails (Validation Tools):**
   - **Locator Uniqueness Critic (`verify_locators`):** Executes a headless dry-run query
     against the DOM to confirm every generated selector resolves to **strictly 1 visible,
     interactive element**.
   - **Locator Priority Rule:** Prefer resilient user-facing attributes (`get_by_role`,
     `get_by_label`, `data-testid`) over fragile structural XPaths (`//div/span`).
   - **HIPAA / PHI Isolation:** Staging environments must use strictly synthetic patient and
     provider data during browser inspection.

3. **Output Artifact:**
   - A modular Python Page Object class (e.g., `ClaimSubmissionPage.py`) containing typed
     locators and business-readable action methods (`enter_member_id()`,
     `enter_billing_npi()`, `submit_claim()`).

## 4. Mapping to Existing Gherkin Step Definitions
Generated Page Object methods map directly to the Gherkin steps produced by the
`agent_design_kt.md` pipeline:
- `Given a patient with Medicaid Member ID "100200300"` -> `claim_page.enter_member_id("100200300")`
- `And a provider with billing NPI "1234567893"` -> `claim_page.enter_billing_npi("1234567893")`
- `When the 837P claim is submitted` -> `claim_page.submit_claim()`
