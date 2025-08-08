---
title: "Feature Development: Incremental Code Reload During Debug Sessions"
description: "Technical specification and implementation guide for adding incremental code reload functionality to ElixirLS debug sessions"
feature: "debugger-dynamic-interpretation"
status: "in-development"
version: "1.0"
applyTo: "elixir-ls/**/*.ex,src/**/*.ts"
keywords: ["debugging", "code-reload", "incremental", "DAP", "ElixirLS", "module-interpretation"]
---

# Incremental Code Reload for ElixirLS Debug Sessions

This document guides the development of incremental code reload functionality for ElixirLS debug sessions. The goal is to allow developers to reload modified code during active debug sessions, preserving debugging context and application state.

## Motivation & User Scenario

**Current pain points:**
- Restarting debug sessions to reload code loses all application and debugging state.
- Re-interpretation of modules is slow for large projects.

**Typical workflow:**
- Debug with `debugInterpretModulesPatterns` (e.g. `["MyApp.*", "MyAppWeb.*"]`).
- Set breakpoints, hit them, explore state.
- Modify code, want to reload without restarting session.

## Architecture & Key Components

- [debugAdapter.ts](../src/debugAdapter.ts): Spawns debug adapter, passes static config.
- [server.ex](../elixir-ls/apps/debug_adapter/lib/debug_adapter/server.ex): Handles module interpretation, DAP requests.
- [llm_module_dependencies.ex](../elixir-ls/apps/language_server/lib/language_server/providers/execute_command/llm_module_dependencies.ex): Provides dependency analysis for smart reloads.
- `:int` (Erlang interpreter): Manages interpreted modules and breakpoints.

## Proposed Solution

- Add a `CodeReloadManager` to track interpreted modules, dependencies, and pending reloads.
- Use dependency analysis to minimize reinterpretation.
- Preserve breakpoints and critical process state across reloads.
- Extend DAP protocol with a `reloadCode` request for manual or automatic reloads.

## Implementation Phases

1. **Foundation:**
   - Add `CodeReloadManager`.
   - Basic file change detection.
   - Manual reload DAP command.
2. **Smart Reloading:**
   - Selective reinterpretation.
   - Breakpoint preservation.
   - Safe reload windows.
3. **Automatic Reloading:**
   - File system monitoring.
   - State preservation for critical processes.
   - Error handling and rollback.

## Testing & Performance

- Unit: pattern matching, dependency analysis, selective reload logic.
- Integration: DAP message handling, breakpoint preservation, project types.
- Manual: Phoenix/GenServer workflows, complex dependency changes.
- Performance: Expect reloads of 2-5 modules in ~100-300ms, saving minutes per session.

## Documentation & Maintenance

**Always update all related files** listed in frontmatter when changing specs or implementation. Use semantic versioning in frontmatter. Each markdown spec should include frontmatter for context inclusion.

**Quality checklist:**
- [ ] Related files reviewed
- [ ] Version numbers consistent
- [ ] Code references accurate
- [ ] Implementation matches spec
- [ ] DAP extensions documented
- [ ] Metadata/keywords present

## Synchronize Specs

**Instruction:**
Whenever you update this feature or its implementation, ensure that all related specification and documentation files are kept in sync. This includes:
- Updating technical specs, architecture diagrams, and implementation details
- Synchronizing version numbers and metadata in frontmatter
- Cross-referencing codebase changes and documentation
- Reviewing and updating all related markdown files before finalizing changes

## Related files for this feature:
- [Technical Spec](../feature-debugger-dynamic-interpretation/01 - technical spec.md)
- [IDE Integrations](../feature-debugger-dynamic-interpretation/xx - IDE integrations.md)
- [Debug Adapter Server](../elixir-ls/apps/debug_adapter/lib/debug_adapter/server.ex)
- [Module Dependency Analysis](../elixir-ls/apps/language_server/lib/language_server/providers/execute_command/llm_module_dependencies.ex)
- [VS Code Extension Adapter](../src/debugAdapter.ts)
