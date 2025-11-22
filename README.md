# Universal Schema

Open standard for AI agent communication.

## What It Is

A simple, predictable JSON message format that lets AI agents talk to each other reliably, across any system, stack, or domain.

## Example Message
```json
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
```

## The 8 Required Fields

**id** – Unique message ID (UUID)  
**protocol_version** – Schema version used by the sender  
**timestamp** – When the message was sent (ISO 8601)  
**agent_id** – Sender agent identifier  
**target_agent** – Intended receiving agent  
**message_type** – Classification of the message  
**capabilities** – Capabilities required to process the message  
**payload** – Core message data

## Why Universal Schema Exists

Every AI agent platform uses its own message format.  
None of them can talk to each other without a custom integration.

Universal Schema gives agents a shared language so systems can:

* communicate without adapters
* validate messages safely
* interoperate across industries
* enable certification and tooling

It's the foundation for multi-agent ecosystems that don't break.

## Documentation

- [Message Format Specification](./spec/message-format.md)
- [Capabilities System](./spec/capabilities.md)
- [Examples](./examples/)

## Status

**Version:** 0.1 (Draft)  
**Status:** Actively evolving — feedback and proposals are welcome.

## License

CC BY 4.0  
Free to implement, extend, and build on.
