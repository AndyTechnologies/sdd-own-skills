# Design Patterns — Condensed Decision Guide

Condensation of "Más Allá de la Receta: Un Manual Crítico para Seleccionar y Aplicar Patrones de Diseño de Software". Use as the detail layer behind `design-patterns` skill. Every entry: problem solved · narrative implementation complexity · risks and lightweight alternatives.

## Foundations

- A design pattern is a reusable solution to a recurring problem — a template/guide adapted to context, NOT finished design or copy-paste code. Provides a common language: express complex design ideas concisely [[27,30]]. Encapsulates decades of community best practice [[59,154]]. Canon: GoF "Elements of Reusable Object-Oriented Software" (Gamma, Helm, Johnson, Vlissides) [[109,170]].
- An **anti-pattern** is a common, well-intentioned solution that works short-term but is ineffective and counterproductive long-term [[2,174]]. It is often a pattern misapplied [[43]]. Learning both is required: patterns show effective paths, anti-patterns mark dead-end roads [[7]].
- **Pattern choice is tradeoff management, not binary**. Every pattern adds abstraction, classes, interfaces, indirection [[69,71]]: Abstract Factory/Builder multiply classes [[69,70]]; Proxy/Decorator add indirection that can hurt performance [[78]].
- **Pattern spamming / Golden Hammer**: applying one familiar pattern everywhere → over-designed, hard to understand/test/maintain [[3,37,46,95]]. Patterns apply only when their driving forces are present [[37,47]].
- **Missing patterns hurt too**: tight coupling, fragility, hard extension. God Object/Blob (SRP violation) [[3,6]], Spaghetti Code [[6]]. Mastery = right tool, right problem, right time; neither over-engineering nor improvised anarchy.

## Creational — abstract instantiation so systems are independent of how objects are created/composed [[62]]

| Pattern | Problem | Complexity | Risks · Lightweight alternative |
| --- | --- | --- | --- |
| Factory Method | Interface for creation, subclasses decide the class; decouples client from concrete classes [[62,140]] | Low-Med | Class proliferation; unnecessary when creation is trivial. *Static factory or parametrized constructor* if simple and no polymorphism needed [[75]] |
| Abstract Factory | Family of related/dependent objects without concrete classes (UI themes: Windows vs Mac) [[62]] | Med-High | New product types force changes to factory interface + all implementations (breaks OCP). *Factory Method per product type* [[62]] |
| Builder | Separates complex-object construction from representation; solves telescoping constructor [[62]] | Med | Overkill for simple objects. *Optional/named parameters, literal/dict initializers* [[62,70]] |
| Prototype | Copy existing objects without depending on classes; costly creation [[26,62]] | Low-Med | Needs source for clone interface; deep-clone is error-prone. *Factory Method / Builder* if creation simpler than cloning |
| Singleton | Single global instance for shared resources (config, connection pools) [[62,110]] | Low | **Anti-pattern**: global state, hidden dependencies, hard unit tests, coupling, multithread sync bottleneck [[76,111,117]]. *Dependency injection (InversifyJS, tsyringe)* — container manages creation/lifetime, explicit scoped single instance [[115,151]] |

## Structural — assemble classes/objects into larger flexible structures [[62]]

| Pattern | Problem | Complexity | Risks · Lightweight alternative |
| --- | --- | --- | --- |
| Adapter | Convert an interface into the one clients expect; make incompatible interfaces interoperate [[62]] | Low | Indirection can obscure data flow. *Modify one class to adopt the interface directly* if you own it |
| Decorator | Add behavior dynamically and transparently; flexible alternative to inheritance [[97]] | Low | Class explosion; complex debug chains (java.io BufferedInputStream). *Plain inheritance* if extensibility is static/known [[62]] |
| Proxy | Substitute/placeholder controlling access: virtual (lazy), protection (auth), remote (RPC) [[62,78]] | Med | Latency, memory; must implement same interface; can hide real-object defects. *Implement functionality in the original class* when no intermediary needed |
| Facade | Unified simplified interface over a complex subsystem; single entry point [[29]] | Low | Can become a god class / single point of coupling & failure as the subsystem evolves [[71]] |
| Bridge | Decouple abstraction from implementation; both vary independently (JDBC: Connection/Statement vs drivers) [[79]] | High | Overuse for simple systems. *Plain inheritance* when abstraction/implementation are inherently tied |
| Composite | Trees of parts/wholes; treat individual and composition uniformly (file system) [[62]] | Med | Hard common interface; can violate ISP if base component is too large. *Handle leaf and collections separately* |
| Flyweight | Share intrinsic state to minimize memory for many small objects (text editor chars) [[62]] | Med | Must split intrinsic/extrinsic state; pool management complexity. *Plain objects* if memory is not critical |

## Behavioral — responsibility assignment and interaction patterns [[62]]

| Pattern | Problem | Complexity | Risks · Lightweight alternative |
| --- | --- | --- | --- |
| Strategy | Encapsulate interchangeable algorithms; vary independently of clients [[74]] | Low | Strategy class explosion. *First-class functions/closures* (comparators) [[62]] |
| State | Object behavior changes with internal state; looks like class changed (Order: Pending/Shipped/Delivered) [[93]] | Med | State-class explosion. *Enum + switch/FSM* for simple cases |
| Observer | One-to-many change notification; core of reactive systems [[82]] | Med | Memory leaks if observers never unsubscribe; event spam; invisible control flow. *Direct method calls* when few dependents / low coupling |
| Command | Request as independent object: parametrize, queue, log, undo/redo (editor actions) [[142]] | Low | Command-class proliferation. *Direct function invocation* if no queue/history needed |
| Template Method | Algorithm skeleton, subclasses redefine steps [[92]] | Low | Rigid structure limits flexibility. *Composition with callbacks/functions* |
| Iterator | Sequential access without exposing representation [[94]] | Low | Unneeded complexity on simple collections. *Language-native iterators* (for-each) |
| Mediator | Encapsulate inter-object interaction; reduce direct coupling (chat room) [[62]] | Low-Med | Can become a god object / single point of failure. *Direct communication* when few objects / low coupling |
| Visitor | New operations without modifying element classes (AST evaluation/codegen) [[73,62] | High | **Breaks encapsulation** (visitor needs internals); any element change ripples into all visitors; hard to maintain [[73,121,124]]. *Virtual methods per element* |

## System Architecture — distributed / cloud-native scale [[18,89]]

| Pattern | Problem | Complexity | Risks · Lightweight alternative |
| --- | --- | --- | --- |
| Microservices | Small autonomous domain-aligned services, independent deploy/scale [[18,88,91]] | Very High | Operational overhead (Kubernetes, service mesh); distributed-data consistency, observability, inter-service deps [[10,56,165]]. *Start Modular Monolith*; extract only on proven need/team growth [[21,56]] |
| Saga | Data integrity across multi-service business transactions: local transactions + compensating operations [[11,135]] | Med-High | Orchestration: central coordinator = easy to understand/debug but a point of failure; Choreography: event-driven, resilient but hard to visualize/test/debug, no single source of truth [[58]] |
| CQRS | Separate write (command) from read (query) models; optimized denormalized read views [[8,107]] | High | Added complexity: duplicated business logic, eventual-consistency lag [[55,107]]. *NOT for simple CRUD*; justify with query performance / domain complexity [[148]] |
| EDA | Components communicate via event production/consumption; async → decoupling, scale, resilience [[158,159]] | Med-High | Foundation for Saga/CQRS [[157,163]] |
| Circuit Breaker | Prevent failure cascades: after N consecutive failures, trip and reject while service recovers [[13,17]] | Med | — |
| Bulkhead | Isolate resources by compartment; one failure affects only its container [[17]] | Med | — |

### Distributed anti-patterns (avoid)

- **Distributed Monolith**: independent deploys but strong sync coupling + **Shared Database** — nullifies every microservice benefit; coordinated updates, no independent scaling [[4,10,56]].
- **API Gateway Becomes God Gateway**: gateway accumulates business logic (validations, transformations) → new monolith + bottleneck [[4]].
- **Chatty Communication**: front-end makes too many synchronous calls per user request → accumulated latency, many failure points [[10,56]].