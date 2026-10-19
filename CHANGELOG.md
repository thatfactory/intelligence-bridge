# Changelog

All notable changes to IntelligenceBridge are documented here.

## Unreleased

## 0.3.0 — 2026-10-19

### Added

- Add an iOS native presentation adapter with confirmed opening, completed dismissal, and typed unavailable or opening-timeout outcomes. Its configurable 12-second opening deadline never limits active editing or generation.
- Serialize terminal callbacks and cleanup, reject stale callbacks, and preserve synchronous temporary-image consumption before dismissal.
- Add deterministic lifecycle tests and privacy-safe presentation diagnostics.

### Changed

- Adopt AgentGuidelines `0.0.38`. The existing cross-platform SwiftUI sheet API remains source compatible.

## 0.2.0 — 2026-09-20

### Added

- Add a Foundation Models availability value that maps Apple's on-device model state to stable reasons and reports unsupported platforms explicitly.
- Re-export Apple's Foundation Models APIs on supported platforms so consumers can use `SystemLanguageModel`, `LanguageModelSession`, `@Generable`, and `@Guide` directly.

### Changed

- Rename the package, product, module, documentation, repository-facing links, logging subsystem, and canonical emoji to IntelligenceBridge 🧠 while preserving the Image Playground-specific public API.

## 0.1.1 — 2026-09-19

### Changed

- Adopted Agent Guidelines `0.0.33` and the Swift package compiler-settings baseline.
- Declared Swift 6, warnings as errors, and the required upcoming language features for every package target.
- Made imports and existential types explicit where required by the stricter compiler policy without intentionally changing runtime behavior.

## 0.1.0 — 2026-09-19

### Changed

- Rename the package, product, module, public API, documentation, and repository-facing links to ImagePlaygroundBridge.

### Added

- Bootstrapped the Swift package, DocC catalog, CI/CD workflows, shared AgentGuidelines integration, and repository policy.
- Add a portable request and result model for interactive Image Playground generation.
- Add a SwiftUI presentation helper with availability and cancellation handling.
- Keep shared application targets buildable on tvOS while reporting generation as unavailable.
