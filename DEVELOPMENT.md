# VS Code Extension Development

This guide covers development of the VS Code extension itself (TypeScript code, UI integration, commands). For ElixirLS language server development, see the [ElixirLS DEVELOPMENT.md](elixir-ls/DEVELOPMENT.md).

## Extension Development Setup

```shell
# Clone with submodules
git clone --recursive https://github.com/elixir-lsp/vscode-elixir-ls.git
cd vscode-elixir-ls

# Install extension dependencies
npm install

# Install ElixirLS dependencies (required for testing)
cd elixir-ls && mix deps.get && MIX_ENV=prod mix compile && cd ..
```

## Development Workflow

### TypeScript Development

```shell
# Watch mode for TypeScript compilation (recommended)
npm run watch

# Single compilation
npm run compile

# Production build
npm run esbuild
```

### Testing Extension Changes

```shell
# Launch development extension host
code --extensionDevelopmentPath=.
# Or press F5 in VS Code

# Run extension tests
npm test

# On Linux (requires display server)
xvfb-run -a npm test
```

### Testing with Local ElixirLS

When developing both extension and language server features:

```shell
# Enable local ElixirLS development mode
export ELS_LOCAL=1

# Launch extension with local language server
code --extensionDevelopmentPath=. /path/to/test/elixir/project
```

## Key Extension Components

- `src/extension.ts` - Extension entry point and activation
- `src/languageClientManager.ts` - Manages ElixirLS processes per workspace
- `src/project.ts` - Workspace detection and project directory resolution
- `src/commands/` - VS Code command implementations
- `src/*-tool.ts` - Language Model Tool API integrations
- `src/testController.ts` - Test Explorer integration

## Debugging

### Extension Debugging

- Use VS Code's built-in debugger when running with F5
- Add breakpoints in TypeScript files
- Console output appears in Debug Console
- Check ElixirLS output: View → Output → ElixirLS

### Grammar Debugging

Run "Developer: Inspect Editor Tokens and Scopes" to debug TextMate grammar issues.

## Code Quality

```shell
# Linting and formatting (uses Biome)
npm run lint
npm run fix-formatting

# Type checking
npx tsc --noEmit
```

## Packaging and Release

### Extension Packaging

1. Update the elixir-ls submodule `git submodule foreach git pull origin master` to desired tag
2. Update version in `package.json` (to e.g. `0.15.0`)
3. Update [CHANGELOG.md](CHANGELOG.md)
4. Test the new vscode-elixir-ls version with:

    ```shell
    npm install
    npm install -g @vscode/vsce@latest
    vsce package
    code --install-extension ./elixir-ls-*.vsix --force
    ```

5. Push and verify the build is green.
6. Tag and push tags. Tag needs to be version prefixed with `v` (e.g. `v0.15.0`). Github action will create and publish the release to Visual Studio Marketplace and Open VSX Registry. Semver prerelease tags (e.g. `v0.1.0-rc.0`) will dry run publish.
7. Update forum announcement post: [ElixirLS announcement](https://elixirforum.com/t/introducing-elixirls-the-elixir-language-server/5857)

### Updating Dialyzer Options

The list in `package.json` needs to be updated to accommodate for changes in OTP based on the [Dialyzer options list](https://github.com/erlang/otp/blob/412bff5196fc0ab88a61fe37ca30e5226fc7872d/lib/dialyzer/src/dialyzer_options.erl#L495).

## References

- [VS Code Extension Publishing](https://code.visualstudio.com/api/working-with-extensions/publishing-extension)
- [Personal Access Token (PAT)](https://dev.azure.com/elixir-lsp/_usersSettings/tokens)
- [Embedded Languages](https://code.visualstudio.com/api/language-extensions/embedded-languages)
