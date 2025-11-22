Universal Schema — Message Format (v0.1 Draft)

This document defines the required JSON structure for all Universal Schema messages.
Every agent must follow this format to ensure interoperability, predictable parsing, and reliable communication across different agent ecosystems.

⸻

1. Overview

A Universal Schema message is a single JSON object that contains:
	•	Envelope metadata
	•	Sender & receiver identifiers
	•	Capability requirements
	•	A flexible payload area

All fields are mandatory unless marked as optional.

⸻

2. Full JSON Structure

A valid message MUST follow this structure:

{
  "id": "UUIDv4",
  "protocol_version": "0.1",
  "timestamp": "ISO8601 string",
  "agent_id": "string",
  "target_agent": "string",
  "message_type": "string",
  "capabilities": ["string", "string"],
  "payload": { ... }
}

3. Field Definitions

id
	•	Unique identifier for the message
	•	MUST be a UUID v4 string
	•	Used for logging, retry logic, and traceability

protocol_version
	•	Universal Schema version used
	•	MUST be a string (example: "0.1")
	•	Ensures backward compatibility when the schema updates

timestamp
	•	ISO 8601 UTC timestamp
	•	Represents when the message was generated

agent_id
	•	Identifier of the sending agent
	•	Can be a name, slug, or unique internal ID

target_agent
	•	Name or ID of the receiving agent
	•	If sending to a broadcast router, use "broadcast"

message_type
	•	The category of message
	•	Examples:
	•	"inventory_query"
	•	"health_check"
	•	"sync_request"
	•	"policy_update"

capabilities
	•	A list of required capabilities the sender expects the receiver to have
	•	Example: ["inventory.read"]

payload
	•	Flexible data container
	•	MUST be an object
	•	Content varies depending on message_type
	•	Should only include structured, predictable keys

⸻

4. Example Messages

Basic Query

{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "protocol_version": "0.1",
  "timestamp": "2025-11-21T20:45:00Z",
  "agent_id": "diana",
  "target_agent": "hairvault",
  "message_type": "inventory_query",
  "capabilities": ["inventory.read"],
  "payload": {
    "product": "olaplex"
  }
}

Response Example

{
  "id": "fc9c0b81-a0af-4f20-96cf-d1e3a00bb1df",
  "protocol_version": "0.1",
  "timestamp": "2025-11-21T20:45:01Z",
  "agent_id": "hairvault",
  "target_agent": "diana",
  "message_type": "inventory_response",
  "capabilities": ["inventory.read"],
  "payload": {
    "product": "olaplex",
    "stock": 14,
    "low_stock": false
  }
}

5. Validation Rules

Required:
	•	All 8 fields must exist
	•	payload must be an object
	•	capabilities must be an array of strings (can be empty for acknowledgments/errors)

Recommended:
	•	Use snake_case for keys inside payload
	•	Ensure timestamps are always UTC
	•	Avoid nested objects more than 2 levels deep

⸻

6. Versioning Rules
	•	Breaking changes trigger a new major version
	•	Non-breaking additions go in minor versions
	•	Draft versions are appendable but must not break compatibility

⸻

7. Purpose

The message format exists so every AI agent—no matter what company, platform, or ecosystem built it—can speak the same language and interoperate cleanly.

This is the foundation of true multi-agent communication.
