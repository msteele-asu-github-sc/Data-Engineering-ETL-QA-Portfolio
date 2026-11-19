import os
import boto3

REGION = os.getenv("AWS_REGION", "us-east-1")
BUCKET = os.getenv("QA_RAG_BUCKET", "your-s3-rag-bucket-name")
MODEL_ID = "us.anthropic.claude-sonnet-4-6"

bedrock = boto3.client("bedrock-runtime", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION)


def read_s3_doc(key: str) -> str:
    return s3.get_object(Bucket=BUCKET, Key=key)["Body"].read().decode("utf-8")


def validate_npi_luhn(npi: str) -> dict:
    if len(npi) != 10 or not npi.isdigit():
        return {"valid": False, "reason": "NPI must be 10 digits."}
    prefixed = "80840" + npi[:-1]
    total = sum(
        (int(d) * 2 - 9 if int(d) * 2 > 9 else int(d) * 2) if i % 2 == 0 else int(d)
        for i, d in enumerate(reversed(prefixed))
    )
    check_digit = (10 - (total % 10)) % 10
    is_valid = check_digit == int(npi[-1])
    return {
        "valid": is_valid,
        "reason": "Valid Luhn" if is_valid else f"Expected check digit {check_digit}",
    }


TOOLS = {
    "tools": [
        {
            "toolSpec": {
                "name": "fetch_rag_context",
                "description": "Fetch Medicaid companion guide or SQL ER schema from S3.",
                "inputSchema": {
                    "json": {
                        "type": "object",
                        "properties": {
                            "doc_key": {
                                "type": "string",
                                "enum": [
                                    "medicaid_837p_companion_guide.md",
                                    "er_schema.sql",
                                ],
                            }
                        },
                        "required": ["doc_key"],
                    }
                },
            }
        },
        {
            "toolSpec": {
                "name": "validate_npi_luhn",
                "description": "Validate 10-digit NPI Luhn check digit.",
                "inputSchema": {
                    "json": {
                        "type": "object",
                        "properties": {"npi": {"type": "string"}},
                        "required": ["npi"],
                    }
                },
            }
        },
    ]
}


def generate_feature_file(user_story: str, output_filename: str):
    # Load the human-readable KT/Design spec directly from S3 as the agent's brain
    kt_design_spec = read_s3_doc("agent_design_kt.md")
    messages = [{"role": "user", "content": [{"text": user_story}]}]

    while True:
        res = bedrock.converse(
            modelId=MODEL_ID,
            messages=messages,
            system=[{"text": kt_design_spec}],
            toolConfig=TOOLS,
        )
        msg = res["output"]["message"]
        messages.append(msg)

        if res["stopReason"] != "tool_use":
            feature_text = "".join(
                b["text"] for b in msg["content"] if "text" in b
            )
            with open(output_filename, "w") as f:
                f.write(feature_text)
            print(f"\n[Success] Generated traceable Gherkin suite -> {output_filename}\n")
            print(feature_text)
            break

        tool_results = []
        for b in msg["content"]:
            if "toolUse" in b:
                name = b["toolUse"]["name"]
                inp = b["toolUse"]["input"]
                tid = b["toolUse"]["toolUseId"]
                print(f"[Agent Step] {name} -> {inp}")
                out = (
                    {"content": read_s3_doc(inp["doc_key"])}
                    if name == "fetch_rag_context"
                    else validate_npi_luhn(inp["npi"])
                )
                tool_results.append(
                    {"toolResult": {"toolUseId": tid, "content": [{"json": out}]}}
                )
        messages.append({"role": "user", "content": tool_results})


if __name__ == "__main__":
    story = """User Story: Professional Claim Submission (837P)
Generate and transmit an ANSI X12 837P (5010) batch file for outpatient physician visits.
Acceptance Criteria:
- Valid X12 837P (005010X222A1) passing SNIP Level 1 & 2 syntax validation.
- Loop 2010BA maps 9-to-12-digit Medicaid Member ID in NM109.
- Loop 2010AA includes active 10-digit NPI in NM109 and Taxonomy Code in PRV03.
- Loop 2300 contains valid ICD-10-CM in HI; Loop 2400 contains valid CPT/HCPCS in SV101.
- Uploaded via SFTP and logs confirmation timestamp in database."""

    generate_feature_file(story, "generated_837p.feature")
