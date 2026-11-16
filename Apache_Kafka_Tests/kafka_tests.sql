--3. Apache Kafka (Real-Time Streaming & Event Validation)
import json
from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'claim_submission_events',
    bootstrap_servers=['broker1:9092'],
    auto_offset_reset='earliest',
    enable_auto_commit=False,
    consumer_timeout_ms=5000,
    value_deserializer=lambda m: json.loads(m.decode('utf-8'))
)

required_fields = {"claim_id", "member_id", "event_timestamp", "charge_amount"}
invalid_messages = []

for msg in consumer:
    payload = msg.value
    # Check schema completeness and business rule (positive charge)
    if not required_fields.issubset(payload.keys()) or payload["charge_amount"] <= 0:
        invalid_messages.append((msg.offset, payload))

assert len(invalid_messages) == 0, f"Found {len(invalid_messages)} invalid Kafka messages!"
