# ADR-002: Agent Identity Format

## Status
Accepted - 2025-12-09

## Context

Universal Schema requires globally unique agent identifiers that:

- Scale to millions of agents
- Support 100,000+ organizations
- Enable industry-based discovery
- Remain human-readable

Traditional approaches using short org codes (3-4 letters) create collision risk at scale. With 3-letter codes, only 17,576 combinations exist—insufficient for a global protocol.

## Decision

Agent identifier format:

```
industry.role.org_code.instance_id
```

**Components:**

| Component | Description | Example |
|-----------|-------------|---------|
| industry | Primary industry classification | `beauty-salon` |
| role | Agent function | `herald` |
| org_code | Organization identifier (3-8 chars) | `acme` |
| instance_id | Unique instance identifier (6 chars) | `a3f9b2` |

**Example:** `beauty-salon.herald.acme.a3f9b2`

## Rationale

### Uniqueness Guarantee

The `instance_id` component ensures global uniqueness. Organizations can use short, memorable codes without collision risk.

```
beauty-salon.herald.acme.a3f9b2   ← Acme Salon
beauty-salon.herald.acme.b7e2c4   ← Another Acme location
```

Both use "acme" but are unique due to instance_id.

### Industry-First Discovery

Placing industry first enables efficient discovery patterns:

```sql
-- Find all agents in an industry
WHERE industry_primary = 'beauty-salon'

-- Find all heralds across industries
WHERE role = 'herald'

-- Cross-industry pattern matching
WHERE role = 'inventory' AND industry_primary IN ('beauty-salon', 'restaurant')
```

### Human-Readable

Unlike UUIDs, agent_ids are readable in logs and debugging:

```
[10:23:45] beauty-salon.herald.acme.a3f9b2 → Booking confirmed
[10:23:46] beauty-salon.inventory.acme.b7e2c4 → Stock updated
```

### Performance

Extracted components stored as indexed columns enable fast queries:

| Query Type | Performance |
|------------|-------------|
| Industry filtering | <10ms |
| Organization filtering | <10ms |
| Role filtering | <10ms |
| Composite queries | <5ms |

## Consequences

### Positive

- Scales to millions of agents
- Short, memorable org codes
- Industry-first discovery
- Grep-friendly logs
- Fast query performance

### Negative

- Longer identifiers (4 components)
- Industry is immutable after creation

### Neutral

- Display names should be used for UI (agent_id is technical)

## Implementation

### Database Schema

```sql
CREATE TABLE agents (
  agent_uid UUID PRIMARY KEY,
  agent_id VARCHAR(255) UNIQUE NOT NULL,
  
  -- Extracted for fast queries
  industry_primary VARCHAR(100) NOT NULL,
  role VARCHAR(50) NOT NULL,
  org_code VARCHAR(20) NOT NULL,
  instance_id VARCHAR(8) NOT NULL,
  
  display_name VARCHAR(255)
);

-- Performance indexes
CREATE INDEX idx_industry ON agents(industry_primary);
CREATE INDEX idx_org_code ON agents(org_code);
CREATE INDEX idx_role ON agents(role);
```

### Parsing

```python
def parse_agent_id(agent_id: str) -> dict:
    """Parse agent_id into components."""
    parts = agent_id.split('.')
    return {
        'industry': parts[0],
        'role': parts[1],
        'org_code': parts[2],
        'instance_id': parts[3]
    }
```

## References

- [ADR-001: Industry Classification](./ADR-001-industry-classification.md)
- [Agent Identity Specification](../AGENT-IDENTITY.md)
