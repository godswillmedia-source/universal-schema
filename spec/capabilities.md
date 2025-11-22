Capabilities Specification (v0.1 Draft)

Capabilities describe what an agent is allowed or able to do. They help other agents understand what actions are permitted and allow Doorkeeper to verify behavior against declared permissions.

Capabilities are simple strings in the format:

group.action

Examples:
	•	inventory.read
	•	inventory.write
	•	calendar.book
	•	billing.charge
	•	agent.train

Required Rules
	1.	Capabilities must be lowercase.
	2.	Use a two-level namespace:
	•	group = category (e.g., inventory, calendar, billing)
	•	action = the allowed operation (e.g., read, write, cancel)
	3.	Capabilities must be explicit. No wildcards are allowed in v0.1.
	4.	Agents should only request capabilities they truly need.
	5.	Doorkeeper must reject any message containing capabilities not listed in the agent’s certificate.

Recommended Categories

inventory.*
	•	inventory.read – Agent may check stock levels or product lists.
	•	inventory.update – Agent may modify quantities.
	•	inventory.restock – Agent may create reorder requests.

calendar.*
	•	calendar.read – View available times.
	•	calendar.book – Create a booking or reservation.
	•	calendar.cancel – Cancel an existing booking.

billing.*
	•	billing.charge – Charge a customer.
	•	billing.refund – Process a refund.
	•	billing.invoice – Generate invoices.

agent.*
	•	agent.status – Query another agent’s health.
	•	agent.train – Modify internal datasets or memory (if allowed).
	•	agent.verify – Validate protocol version or capabilities.

Why Capabilities Matter

Capabilities serve as:
	•	A permission model
	•	A security layer for any validator or enforcement system
	•	A common vocabulary across industries
	•	A future foundation for certification and compliance

Capabilities keep Universal Schema predictable, auditable, and safe as agents get more complex.
