# Agent Identity Specification

> Universal Schema v0.2

## Overview

Every agent in the Universal Schema network has a unique identity. This specification defines the identity system, including identifier formats and discovery patterns.

## Agent Identifier Format

```
industry.role.org_code.instance_id
```

### Components

| Component | Format | Length | Example |
|-----------|--------|--------|---------|
| industry | lowercase-kebab | 3-50 chars | `beauty-salon` |
| role | lowercase | 3-30 chars | `herald` |
| org_code | lowercase-alphanumeric | 3-8 chars | `acme` |
| instance_id | alphanumeric | 6 chars | `a3f9b2` |

### Examples

```
beauty-salon.herald.acme.a3f9b2
healthcare.receptionist.vitalcare.x9k3m7
finance.analyst.clearbank.z8a1b2
restaurant.host.bistro.r7s9t1
```

### Validation Regex

```regex
^[a-z][a-z0-9-]{2,49}\.[a-z][a-z0-9]{2,29}\.[a-z0-9]{3,8}\.[a-z0-9]{6}$
```

## Identity Hierarchy

```
┌─────────────────────────────────────────────────────┐
│                    agent_uid                         │
│                 (UUID - Internal)                    │
│         Used for: Database joins, FK refs            │
├─────────────────────────────────────────────────────┤
│                    agent_id                          │
│       (industry.role.org_code.instance_id)           │
│    Used for: Network routing, API calls, logs        │
├─────────────────────────────────────────────────────┤
│                  display_name                        │
│              (Human-friendly name)                   │
│         Used for: UI, notifications, reports         │
└─────────────────────────────────────────────────────┘
```

### When to Use Each

| Identifier | Use Case |
|------------|----------|
| `agent_uid` | Database operations, internal references |
| `agent_id` | Network messages, API endpoints, logging |
| `display_name` | User interfaces, human-readable output |

## Discovery

The industry-first identifier format enables powerful discovery patterns.

### By Industry

```sql
-- All beauty salon agents
SELECT agent_id, display_name, role 
FROM agents 
WHERE industry_primary = 'beauty-salon';
```

### By Role

```sql
-- All herald agents across industries
SELECT agent_id, display_name, industry_primary 
FROM agents 
WHERE role = 'herald';
```

### By Organization

```sql
-- All agents for an organization
SELECT agent_id, display_name, role 
FROM agents 
WHERE org_code = 'acme';
```

### Cross-Industry Patterns

```sql
-- Inventory agents in retail-adjacent industries
SELECT agent_id, industry_primary 
FROM agents 
WHERE role = 'inventory'
  AND industry_primary IN ('beauty-salon', 'restaurant', 'retail');
```

## Immutability Rules

| Component | Mutable? | Notes |
|-----------|----------|-------|
| agent_uid | No | Never changes |
| agent_id | No | Set at creation |
| industry | No | Part of agent_id |
| role | No | Part of agent_id |
| org_code | No | Part of agent_id |
| instance_id | No | Part of agent_id |
| display_name | Yes | Can be updated |

## Best Practices

### Org Code Selection

- Keep it short (3-4 characters preferred)
- Make it memorable (abbreviation of org name)
- Lowercase only (`acme` not `ACME`)
- Alphanumeric (no special characters)

### Display Names

- Use for all UI elements
- Include role context: "Acme Herald" not just "Herald"
- Keep under 50 characters

### Logging

Always log the full `agent_id` for traceability:

```
[2025-12-09 10:23:45] beauty-salon.herald.acme.a3f9b2 → Booking confirmed
[2025-12-09 10:23:46] beauty-salon.inventory.acme.b7e2c4 → Stock updated
```

## References

- [ADR-002: Agent Identity Format](./adr/ADR-002-agent-identity-format.md)
- [Protocol Specification](./PROTOCOL.md)
