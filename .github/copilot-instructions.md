# Copilot Instructions for ElixirLS VS Code Extension

## Architecture Overview

This is a **dual-language project**: TypeScript VS Code extension + Elixir language server. The extension (`src/`) spawns and manages ElixirLS processes (`elixir-ls/`) which implement LSP/DAP over stdio.

### Key Components
- **Extension Entry**: `src/extension.ts` - Activates clients, tools, and providers
- **Language Client Manager**: `src/languageClientManager.ts` - Manages per-workspace ElixirLS processes
- **Workspace Tracker**: `src/project.ts` - Handles multi-root workspace detection and project dir resolution
- **ElixirLS Umbrella**: `elixir-ls/` - Git submodule with language_server, debug_adapter, and utils apps

### Communication Architecture
- VS Code extension ↔ ElixirLS: JSON-RPC over stdio (no TCP/IP)
- Launch scripts: `elixir-ls/scripts/{language_server,debug_adapter}.{sh,bat}` handle environment setup
- Process spawning: `src/executable.ts` builds platform-specific commands with override support

## Critical Workflows

### Building & Development
```bash
# Full development setup
npm install && cd elixir-ls && mix deps.get

# TypeScript watch mode (essential for extension dev)
npm run watch

# ElixirLS compilation (production mode recommended)
cd elixir-ls && MIX_ENV=prod mix compile

# Launch development host with local ElixirLS
export ELS_LOCAL=1
code --extensionDevelopmentPath=. # or F5 in VS Code
```

### Local ElixirLS Development Workflow
```bash
# 1. Make changes to ElixirLS code in elixir-ls/apps/
# 2. Compile changes
cd elixir-ls && MIX_ENV=prod mix compile

# 3. Test with local development
export ELS_LOCAL=1
code --extensionDevelopmentPath=. /path/to/test/project

# Or test scripts directly
ELS_LOCAL=1 ./elixir-ls/scripts/language_server.sh
```

### Testing Patterns
- **Extension tests**: `npm test` (requires xvfb on Linux: `xvfb-run -a npm test`)
- **ElixirLS tests**: `cd elixir-ls && mix test`
- **Integration**: VS Code Test Explorer integrates via `src/testController.ts`

## Project-Specific Conventions

### TypeScript Patterns
- **Language Model Tools**: `src/*-tool.ts` files implement VS Code's Language Model Tool API for AI integration
- **Multi-workspace support**: All components must handle `undefined` workspace folders
- **Document selectors**: Use `languageIds` array from `languageClientManager.ts` (elixir, eex, html-eex, phoenix-heex)

### Configuration Hierarchies
1. **Workspace-scoped**: `elixirLS.*` settings can be workspace-specific
2. **Project dir override**: `elixirLS.projectDir` setting allows non-root mix projects
3. **Language server override**: `elixirLS.languageServerOverridePath` for custom ElixirLS builds

### Critical Environment Variables
- `ELS_LOCAL=1`: **Development mode**
  - Use local `./elixir-ls/scripts/` instead of bundled release
  - Essential for ElixirLS development and testing changes
  - Set before launching: `export ELS_LOCAL=1 && code --extensionDevelopmentPath=.`
  - Makes ElixirLS changes immediately available without packaging
  - Used in CI and when modifying language server/debug adapter code
- `ELS_INSTALL_PREFIX`: Override ElixirLS installation path
- `ELS_MODE`: Set by launch scripts (language_server|debug_adapter)

## Integration Points

### ElixirLS Submodule Management
```bash
# Initialize/update submodule (required for development)
git submodule update --init --recursive

# Update to latest ElixirLS
git submodule update --remote elixir-ls
```

### VS Code Language Client Lifecycle
1. **Activation**: Document open/workspace detection triggers client start
2. **Per-workspace**: Each workspace folder gets its own ElixirLS process
3. **Cleanup**: `LanguageClientManager` handles process disposal on workspace changes

### Test Controller Integration
- **Test discovery**: Uses ElixirLS commands to parse ExUnit test files
- **Test execution**: Builds dynamic launch configs for `mix test` with precise targeting
- **Custom launch config**: Projects can override default test runner via `mix test` launch configuration

## Development Gotchas

### Process Management
- ElixirLS processes are long-running - ensure proper cleanup in `languageClientManager.ts`
- Launch scripts set up Elixir/Erlang environment - don't bypass them
- Debug adapter is separate process from language server

### Multi-root Workspace Complexity
- `WorkspaceTracker.getOuterMostWorkspaceFolder()` resolves nested workspace conflicts
- Each workspace can have different Elixir versions/project structures
- Settings are workspace-scoped, not global

### Build System Integration
- Use `npm run esbuild` (available as VS Code task) for TypeScript compilation
- ElixirLS must be compiled separately - extension bundles pre-built release
- Development mode (`ELS_LOCAL=1`) uses source ElixirLS, production uses bundled

### Language Model Tools
- Tools like `DefinitionTool` require active language client
- Check `client.initializeResult?.capabilities` for available commands
- Pattern: `llmDefinition:*` commands are dynamically registered by ElixirLS

## Common File Patterns

When adding features:
- **Commands**: Add to `src/commands/` + register in `src/commands.ts`
- **Language tools**: Follow `src/*-tool.ts` pattern for AI integration
- **Client extensions**: Extend `languageClientManager.ts` for new LSP features
- **Test fixtures**: Add to `src/test-fixtures/` with realistic project structures
