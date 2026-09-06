---
name: design-patterns
description: "Trigger: design patterns, patrones de diseño, pattern selection, architecture, arquitectura, technical design, diseño técnico, GoF, factory, strategy, singleton, anti-pattern. Select GoF + system patterns when forces are present; avoid spamming."
license: MIT
metadata:
  author: andy
  version: "1.0"
---

## Activation Contract

Load when selecting, applying, or reviewing a design pattern — creational, structural, behavioral, or system architecture (microservices, saga, CQRS, EDA). Applies to design work, architecture review, and implementation that adds abstractions. Read `references/patterns-decision-guide.md` for the full condensed tables before deciding.

## Hard Rules

- **Forces first**: apply a pattern ONLY when the forces that motivate it are present. No pattern is correct for every problem.
- **No pattern spamming / Golden Hammer**: never apply a familiar pattern to everything. A "perfect, future-flexible" design you cannot justify today is over-design.
- **Lightest route first**: check the lightweight alternative (closures, optionals, direct calls, inheritance, plain functions) BEFORE adding indirection, extra classes, or a new abstraction layer.
- **Singleton is the last resort**: prefer dependency injection (container-scoped single instance). Global state breaks tests, hides dependencies, couples clients.
- **Visitor is high-risk**: it breaks encapsulation and every element-change ripples into all visitors. Use only for stable object structures (e.g. AST walks).
- **Never design an anti-pattern intentionally**: God Object, Spaghetti Code, Distributed Monolith, Shared Database, God Gateway, Chatty Communication are failure modes, not trade-offs.
- Every pattern adds complexity (classes, indirection, layers) — complexity is the cost you pay, so state the benefit explicitly in the artifact.

## Decision Gates

| Force present | Pattern to consider |
| --- | --- |
| Create objects, client decoupled from concrete class | Factory Method |
| Family of related products, platform variants | Abstract Factory |
| Object with many optional params / telescoping constructor | Builder (or named/optional params) |
| Expensive object creation, need copies | Prototype (or Factory Method) |
| One shared resource instance | DI container (NOT Singleton) |
| Incompatible interfaces must coexist | Adapter |
| Add behavior dynamically, transparently | Decorator (or plain inheritance if static) |
| Access control / lazy / remote to an object | Proxy |
| Simplify a complex subsystem's surface | Facade (keep it thin!) |
| Abstraction and implementation vary independently | Bridge (only for long-lived complex systems) |
| Trees of uniform parts/wholes | Composite |
| Many small objects, memory-critical | Flyweight |
| Family of interchangeable algorithms | Strategy (or closures/callbacks) |
| Behavior changes with internal state | State (or explicit FSM / switch for simple cases) |
| One-to-many change notification | Observer (unsubscribe or leak!) |
| Queue / undo / log operations | Command |
| Algorithm skeleton with overridable steps | Template Method (or callbacks/composition) |
| Many objects, centralize interaction | Mediator (watch the god-Mediator) |
| New operations on a stable object structure | Visitor (only stable structures) |
| Multi-service business transaction | Saga (orchestration simple / choreography resilient) |
| Read/write models differ, query-heavy | CQRS (only when justified; never for simple CRUD) |
| Propagating failure isolation | Circuit Breaker / Bulkhead |
| Small autonomous deployable units | Only after Modular Monolith proves the need |

## Execution Steps

1. State the concrete problem and the forces present (variation axis, coupling to break, shared state, performance, scale).
2. Check the lightweight alternative table column first; if it suffices, stop and use it.
3. When a pattern survives, choose the minimal one that covers the forces — not the most elaborate family.
4. State the costs explicitly in the design artifact: extra classes/indirection/complexity, and why they pay off.
5. Check the anti-pattern list in `references/patterns-decision-guide.md` — reject any candidate that degenerates into one.
6. If a second pattern would cover the same forces, prefer the one with lower total complexity.

## Output Contract

When a pattern is selected or rejected, record in the artifact: pattern name, forces present, lightweight alternative considered (and why rejected), costs added, and the anti-pattern(s) avoided. A rejection is a valid outcome — "no pattern" is a design decision.

## References

- `references/patterns-decision-guide.md` — condensed tables: full problems, risks, and lightweight alternatives for each GoF + system architecture pattern; explicit anti-pattern catalog.