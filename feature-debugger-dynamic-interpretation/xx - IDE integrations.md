
# IDE Integration Considerations for Incremental Code Reload

## Client-Agnostic Implementation Strategy

The incremental code reload feature will be implemented in the **ElixirLS debug adapter** (`elixir-ls/apps/debug_adapter/`) using the standardized Debug Adapter Protocol (DAP). This ensures the feature works consistently across all DAP-compatible IDE clients.

### Core Implementation Boundary

**ElixirLS/DAP Responsibilities (client-agnostic):**

- Module interpretation management and selective reloading
- Breakpoint preservation across reloads
- Process state handling and preservation
- File change detection and dependency analysis
- DAP protocol message handling for reload commands

**IDE Client Responsibilities (client-specific):**

- User interface for triggering reload operations
- File watching configuration and preferences
- User notifications and feedback
- Keybindings and command palette integration

## DAP Protocol Extensions

### New Custom DAP Request

```json
{
  "command": "reloadCode",
  "arguments": {
    "changedFiles": ["lib/my_app/accounts.ex"],
    "preserveState": true,
    "forceReinterpretation": false
  }
}
```

### Standard DAP Events for Feedback

```json
{
  "type": "event",
  "event": "output",
  "body": {
    "category": "console",
    "output": "Reloaded 3 modules, preserved debugging context\n"
  }
}
```

## IDE-Specific Integration Patterns

### VS Code Extension (`vscode-elixir-ls`)

**Command Registration:**

```typescript
// src/commands/reloadCode.ts
vscode.commands.registerCommand('elixirLS.reloadCode', async () => {
  const session = vscode.debug.activeDebugSession;
  if (session?.type === 'mix_task') {
    await session.customRequest('reloadCode', { 
      preserveState: true 
    });
  }
});
```

**File Watcher Integration:**

```typescript
// Leverage existing VS Code file watchers
const watcher = vscode.workspace.createFileSystemWatcher('**/*.ex');
watcher.onDidChange(uri => {
  // Optionally trigger automatic reload
  if (autoReloadEnabled) {
    triggerReload([uri.fsPath]);
  }
});
```

### Neovim (nvim-dap)

**Manual Reload Function:**

```lua
-- User configuration in init.lua
vim.keymap.set('n', '<leader>dr', function()
  local session = require('dap').session()
  if session then
    session:request('reloadCode', { preserveState = true })
  end
end, { desc = "Reload code during debugging" })
```

**Autocmd Integration:**

```lua
-- Optional automatic reload on file save
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.ex,*.exs",
  callback = function()
    local session = require('dap').session()
    if session and vim.g.elixir_auto_reload then
      session:request('reloadCode', { 
        changedFiles = { vim.fn.expand('%:p') }
      })
    end
  end
})
```

### Emacs (dap-mode)

**Interactive Command:**

```elisp
(defun dap-elixir-reload-code ()
  "Reload code during ElixirLS debugging session."
  (interactive)
  (when (dap--cur-session)
    (dap--send-message 
      (dap--make-request "reloadCode" 
                         `(:preserveState t)))))

(define-key dap-mode-map (kbd "C-c d r") #'dap-elixir-reload-code)
```

## IDE Support Matrix

| IDE Client | DAP Support | Incremental Reload Support | Implementation Notes |
|------------|-------------|---------------------------|---------------------|
| **VS Code** | ✅ Full | ✅ Yes | Custom commands + file watchers |
| **Neovim (nvim-dap)** | ✅ Full | ✅ Yes | Lua functions + autocmds |
| **Emacs (dap-mode)** | ✅ Full | ✅ Yes | Elisp commands + hooks |
| **Any DAP client** | ✅ Full | ✅ Yes | Basic DAP request support |

## Feature Availability Timeline

### Phase 1: Core DAP Implementation

- All DAP-compatible clients get basic reload functionality
- Manual trigger via custom DAP requests
- Console output for feedback

### Phase 2: Enhanced IDE Integration

- VS Code: Commands, keybindings, file watchers
- Neovim: Lua API integration, autocmds
- Emacs: Interactive commands, mode integration

### Phase 3: Advanced Features

- IDE-specific UI enhancements
- Configuration options per IDE
- Advanced file watching strategies

## User Experience Consistency

While IDE integrations will vary, the core experience remains consistent:

1. **Trigger**: User initiates reload (manual or automatic)
2. **Processing**: ElixirLS analyzes changes and reloads affected modules
3. **Feedback**: Console output confirms successful reload
4. **Continuation**: Debugging continues with updated code

## Development Testing Strategy

**Cross-IDE Testing:**

- Test core DAP functionality with multiple clients
- Verify consistent behavior across VS Code, Neovim, and Emacs
- Document any client-specific quirks or limitations

**Client-Specific Testing:**

- VS Code: Extension development workflow
- Neovim: Plugin integration testing
- Emacs: Package compatibility testing

This approach ensures the feature works reliably across the entire ElixirLS ecosystem while allowing each IDE to provide the best possible user experience within their respective paradigms.
