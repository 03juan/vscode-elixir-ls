# IDE Coordinator Dynamic Interpretation Implementation

## Quick Start

This worktree implements the **IDE Extension Coordination** approach for dynamic debug interpretation.

### Key Specifications
- 📋 **Primary Spec**: `feature-debugger-dynamic-interpretation/02 - ide-coordinator-spec.md`
- 🔍 **Technical Context**: `feature-debugger-dynamic-interpretation/01 - technical spec.md`
- 🌐 **Alternative Approach**: `feature-debugger-dynamic-interpretation/03 - beam-rpc-spec.md`

### Architecture Overview
```
VS Code Extension (Coordinator)
    ↓ LSP commands
Language Server (Dependency Analysis)
    ↓ DAP requests  
Debug Adapter (Interpretation Execution)
```

### Development Environment
```bash
# Working directory
cd /home/juan/code/forks/GitHub/03juan/vscode-elixir-ls-ide-coordinator

# Install dependencies
npm install
cd elixir-ls && mix deps.get

# Run tests
npm test
cd elixir-ls && mix test
```

### Implementation Status
- [x] Worktree setup
- [x] Specifications documented  
- [ ] Core dependency analysis utilities
- [ ] Debug-focused LSP commands
- [ ] VS Code coordination manager
- [ ] Enhanced debug adapter protocol
- [ ] Integration tests

### Key Components to Implement

1. **Language Server**: `elixir-ls/apps/language_server/lib/language_server/providers/execute_command/debug_dependency_analysis.ex`
2. **Debug Adapter**: `elixir-ls/apps/debug_adapter/lib/debug_adapter/coordinated_interpreter.ex` 
3. **VS Code Extension**: `src/dynamicInterpretationManager.ts`

See `IMPLEMENTATION_PLAN.md` for detailed development roadmap.
