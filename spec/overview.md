# Universal Schema — Overview (v0.1 Draft)

Universal Schema is a lightweight, implementation-agnostic protocol designed to make AI agents interoperable across different systems, companies, and ecosystems.  
It provides a shared message format that every agent can rely on, regardless of internal architecture, programming language, or industry.

---

## 1. Purpose

Modern AI agents often communicate using custom formats, hidden assumptions, and incompatible data structures.  
Universal Schema eliminates this fragmentation by defining a predictable, minimal JSON structure for all agent-to-agent communication.

The goals are simple:

- Create a shared language for agents  
- Make systems plug-and-play across industries  
- Reduce ambiguity and parsing errors  
- Enable secure, capability-based communication  
- Provide a foundation for future certification and tooling  

---

## 2. Design Principles

Universal Schema follows four core principles:

### **Simplicity**
The protocol avoids unnecessary complexity.  
Only 8 required fields.  
Only JSON.  
Only predictable keys.

### **Stability**
The message format is versioned and backward-compatible whenever possible.  
Breaking changes are reserved for major versions.

### **Interoperability**
Any agent—from any ecosystem—can send and receive messages using the same format.  
This allows multi-vendor systems, multi-industry integrations, and custom agents to interact cleanly.

### **Extensibility**
The `payload` field supports any structured data relevant to the message_type.  
This lets industries extend the schema without altering the core protocol.

---

## 3. Components of the Protocol

Universal Schema consists of three core documents:

### **1. message-format.md**
Defines the required JSON structure, field rules, and examples.

### **2. capabilities.md**
Defines capability naming and standards for permissions, validation, and compatibility.

### **3. examples/**
Concrete message examples showing how the schema is used in real scenarios.

---

## 4. Versioning Model

Universal Schema follows a simple versioning strategy:

- **Major versions:** Breaking changes  
- **Minor versions:** Additive, non-breaking improvements  
- **Draft versions:** Iterative, but must not break existing structure  

Current version: **0.1 (Draft)**

---

## 5. Philosophy

Universal Schema is intentionally minimal.  
Its purpose is not to replace full agent protocols, networking layers, or workflow engines.  
Instead, it provides a stable “lowest common denominator” message contract that every system can trust.

A small, clean foundation leaves room for:

- Innovation  
- Custom behavior  
- Industry-specific standards  
- Future certification systems  

Universal Schema aims to be the glue—not the system.

---

## 6. Future Work (Optional)

The following areas may be added in later versions:

- Extended capability libraries  
- Standardized error codes  
- Recommended security practices  
- Transport-level guidelines  
- Industry-specific extensions  

These additions must never break the core message structure.

---

## 7. Summary

Universal Schema gives AI agents a shared language that is:

- Easy to implement  
- Predictable to parse  
- Safe to validate  
- Flexible enough for real-world usage  

It is the simplest possible foundation that still enables powerful multi-agent ecosystems.
