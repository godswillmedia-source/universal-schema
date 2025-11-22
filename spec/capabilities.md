# Capabilities System

## Overview

Capabilities enable agents to advertise what they can do, enabling intelligent routing and interoperability.

## Format

Capabilities use dot-notation:
```
domain.action

Examples:
- inventory.read
- inventory.write
- booking.create
- payment.process
- policy.search
```

**Rules:**
- Lowercase only
- Alphanumeric + underscores
- Pattern: `^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$`

---

## Why Capabilities?

**Without capabilities:**
- Senders don't know who can handle what
- Manual routing required
- No discovery mechanism

**With capabilities:**
- Agents self-describe abilities
- Automatic routing possible
- Dynamic discovery enabled

---

## Standard Capabilities

### inventory
- `inventory.read` - Query product availability
- `inventory.write` - Update stock levels
- `inventory.alert` - Low stock notifications

### booking
- `booking.create` - Create appointments
- `booking.read` - Query booking status
- `booking.update` - Modify bookings
- `booking.cancel` - Cancel appointments

### payment
- `payment.process` - Process payments
- `payment.refund` - Issue refunds
- `payment.verify` - Check payment status

### communication
- `sms.send` - Send SMS
- `email.send` - Send emails
- `notification.push` - Push notifications

### policy
- `policy.read` - Retrieve policies
- `policy.search` - Search policy database

---

## Custom Capabilities

Define your own using namespacing:
```
company.domain.action

Examples:
- acme.shipping.track
- salon.stylist.schedule
```

---

## Usage in Messages

### Single Capability
```json
{
  "message_type": "inventory_query",
  "capabilities": ["inventory.read"],
  "payload": {
    "product": "item-123"
  }
}
```

### Multiple Capabilities
```json
{
  "message_type": "book_and_notify",
  "capabilities": [
    "booking.create",
    "email.send"
  ],
  "payload": {
    "booking": {...},
    "notification": {...}
  }
}
```

Agent must support ALL listed capabilities to handle the message.

---

## Agent Discovery

Agents can advertise capabilities to enable discovery:
```json
{
  "agent_id": "my-agent",
  "capabilities": [
    "inventory.read",
    "inventory.write",
    "inventory.forecast"
  ]
}
```

Other agents can discover who has which capabilities and route messages accordingly.

---

## Validation

Receiving agent should validate capabilities:
```javascript
function handleMessage(message) {
  const myCapabilities = [
    "inventory.read",
    "inventory.write"
  ];
  
  const requiredCap = message.capabilities[0];
  
  if (!myCapabilities.includes(requiredCap)) {
    return {
      error: "Capability not supported",
      requested: requiredCap,
      available: myCapabilities
    };
  }
  
  // Process message
  return processMessage(message);
}
```

---

## Best Practices

1. **Be specific:** Use `inventory.read` not `data`
2. **Use standard capabilities** when possible
3. **Document custom capabilities** in your agent docs
4. **Request minimum capabilities** needed
5. **Validate capabilities** before processing

---

## Examples

See [/examples](../examples/) for real-world capability usage.
