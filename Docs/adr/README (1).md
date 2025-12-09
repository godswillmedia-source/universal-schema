# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for Universal Schema protocol decisions.

## What is an ADR?

An ADR is a document that captures an important architectural decision made along with its context and consequences.

## ADR Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](./ADR-001-industry-classification.md) | Industry Classification | Accepted | 2025-12-08 |
| [ADR-002](./ADR-002-agent-identity-format.md) | Agent Identity Format | Accepted | 2025-12-09 |

## ADR Status Definitions

- **Proposed** - Under discussion
- **Accepted** - Decision made, ready for implementation
- **Deprecated** - No longer applies
- **Superseded** - Replaced by another ADR

## Creating a New ADR

Use the format: `ADR-{number}-{short-description}.md`

Template:

```markdown
# ADR-XXX: Title

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
What is the issue that we're seeing that is motivating this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult to do because of this change?
```
