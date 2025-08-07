# IDE Coordinator Dynamic Interpretation - Implementation Plan

## Overview
This worktree implements the IDE Coordinator approach for dynamic debug interpretation as specified in `feature-debugger-dynamic-interpretation/02 - ide-coordinator-spec.md`.

## Branch Information
- **Branch**: `feature/ide-coordinator-dynamic-interpretation`
- **Parent**: `update-dev-instructions` 
- **Worktree Location**: `/home/juan/code/forks/GitHub/03juan/vscode-elixir-ls-ide-coordinator`

## Implementation Strategy
We're implementing the IDE Extension Coordination approach where:
1. **Language Server**: Provides dependency analysis via enhanced LLM tools
2. **Debug Adapter**: Focuses on interpretation execution
3. **VS Code Extension**: Orchestrates intelligent coordination

## Phase 1: Foundation (Current)
- [ ] Extend existing LLM dependency command for debug analysis
- [ ] Create DynamicInterpretationManager in VS Code extension  
- [ ] Implement demand-driven interpretation strategy
- [ ] Basic integration between language server and debug adapter

## Key Files to Modify/Create

### Language Server (elixir-ls/apps/language_server/)
- [ ] `lib/language_server/providers/execute_command/debug_dependency_analysis.ex` (new)
- [ ] Enhance existing `llm_module_dependencies.ex` if needed

### Debug Adapter (elixir-ls/apps/debug_adapter/)  
- [ ] `lib/debug_adapter/coordinated_interpreter.ex` (new)
- [ ] Enhance `lib/debug_adapter/server.ex` for coordination protocol

### VS Code Extension (src/)
- [ ] `dynamicInterpretationManager.ts` (new)
- [ ] Enhance `debugAdapter.ts` for coordination
- [ ] Enhance `languageClientManager.ts` for debug LSP commands

### Tests
- [ ] Unit tests for new language server commands
- [ ] Unit tests for debug adapter coordination
- [ ] Integration tests for VS Code extension coordination
- [ ] End-to-end debugging workflow tests

## Development Workflow
1. Develop and test in this isolated worktree
2. Use existing shared utilities from `elixir_ls_utils` 
3. Leverage refactored dependency analysis we've already implemented
4. Test with sample Phoenix/Elixir projects
5. When stable, merge back to main development branch

## Testing Strategy
- Unit test each component independently
- Integration test the coordination protocol
- Performance test interpretation timing
- End-to-end test with real debugging scenarios

## Success Criteria
- Debug session startup < 2 seconds (vs. 3-8 seconds with pre-interpretation)
- Seamless breakpoint setting with < 500ms interpretation delay
- 50-70% reduction in interpreted module count for typical sessions
- No regression in existing debugging functionality

## Important Note: Dependency Analysis Utilities
The current elixir-ls submodule in this worktree does NOT contain our refactored dependency analysis utilities (`ModuleDependencyAnalyzer`, `ModuleDependencyFormatter`, etc.) that we implemented in the main workspace.

### Options for proceeding:
1. **Port the utilities**: Copy the refactored utilities from the main workspace to this worktree
2. **Update submodule**: Point the elixir-ls submodule to a version that includes our utilities
3. **Implement fresh**: Start with a clean implementation based on our specifications

### Recommended Approach:
We'll **implement fresh** based on our specifications, treating this as a clean implementation that demonstrates the IDE coordinator approach. This allows us to:
- Validate our architectural decisions
- Create a reference implementation  
- Ensure the coordination approach works independently
- Avoid dependency conflicts during development

## Current Worktree Status
✅ Worktree created: `/home/juan/code/forks/GitHub/03juan/vscode-elixir-ls-ide-coordinator`
✅ Branch: `feature/ide-coordinator-dynamic-interpretation` 
✅ Feature specifications available
✅ ElixirLS submodule initialized
⚠️  Need to implement dependency analysis utilities (fresh implementation)

## Next Steps
1. Implement core dependency analysis utilities in `elixir_ls_utils`
2. Create debug-focused dependency analysis command in language server
3. Implement coordination manager in VS Code extension
4. Test the full coordination workflow
