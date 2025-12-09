# Agent Identity Specification

> Universal Schema v0.2

## Overview

Every agent in the Universal Schema network has a unique, verifiable identity. This specification defines the identity system, including identifier formats, certification, and verification.

## Agent Identifier Format

```
industry.role.org_code.cert_suffix
```

### Components

| Component | Format | Length | Example |
|-----------|--------|--------|---------|
| industry | lowercase-kebab | 3-50 chars | `beauty-salon` |
| role | lowercase | 3-30 chars | `herald` |
| org_code | lowercase-alphanumeric | 3-8 chars | `acme` |
| cert_suffix | alphanumeric | 6 chars | `a3f9b2` |

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
│        (industry.role.org_code.cert_suffix)          │
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

## Certification

Every agent must be certified before participating in the network. Certification binds the agent's identity to cryptographic credentials.

### Certification ID Format

```
cert_{org_code}_{role}_{timestamp}_{hash}
```

**Example:** `cert_acme_herald_20251209_a3f9b2e1c4d5`

### Certification Process

```
1. Agent Registration
   └── Owner submits agent details
   
2. Validation
   └── Doorkeeper validates capabilities and owner
   
3. Certification
   └── cert_id generated with unique hash
   
4. Identity Assignment
   └── agent_id created using cert_suffix
   
5. Network Admission
   └── Agent can now send/receive messages
```

### Certificate Fields

| Field | Description |
|-------|-------------|
| cert_id | Unique certification identifier |
| issued_to | agent_uid of certified agent |
| issued_by | Authority that issued cert |
| issued_at | Timestamp of issuance |
| expires_at | Expiration timestamp |
| capabilities | List of granted capabilities |
| status | active, suspended, revoked |

## Verification

### Verify Agent Identity

To verify an agent's identity, confirm the cert_suffix matches:

```python
def verify_agent_identity(agent_id: str, cert_id: str) -> bool:
    """Verify agent_id matches its certification."""
    cert_suffix = agent_id.split('.')[-1]
    return cert_id.endswith(cert_suffix)
```

### Verify in Database

```sql
SELECT * FROM agents a
JOIN certificates c ON a.cert_id = c.cert_id
WHERE a.agent_id = 'beauty-salon.herald.acme.a3f9b2'
  AND c.cert_id LIKE '%a3f9b2'
  AND c.status = 'active'
  AND c.expires_at > NOW();
```

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
| cert_suffix | No | Part of agent_id |
| display_name | Yes | Can be updated |
| capabilities | Yes | Can be modified via re-certification |

## Best Practices

### Org Code Selection

- Keep it short: 3-4 characters preferred
- Make it memorable: abbreviation of org name
- Lowercase only: `acme` not `ACME`
- Alphanumeric: no special characters

### Display Names

- Use for all UI elements
- Include role context: "Acme Herald" not just "Herald"
- Keep under 50 characters

### Logging

Always log the full `agent_id` for traceability:

```
[2025-12-09 10:23:45] beauty-salon.herald.acme.a3f9b2 → Booking confirmed
[2025-12-09 10:23:46] beauty-salon.chancellor.acme.b7e2c4 → Policy retrieved
```

## References

- [ADR-002: Cert-Based Agent Identity](./adr/ADR-002-cert-based-identity.md)
- [Protocol Specification](./PROTOCOL.md)
