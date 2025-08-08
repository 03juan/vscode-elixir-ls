const { defineConfig } = require('@vscode/test-cli');

module.exports = defineConfig([
  {
    label: 'unitTests',
    files: 'out/test/suite/**/*.test.js',
    version: 'stable',
    workspaceFolder: './src/test-fixtures/large_phoenix_app',
    mocha: {
      ui: 'tdd',
      timeout: 20000,
      color: true
    },
    launchArgs: [
      '--disable-extensions', // Disable other extensions for clean test environment
      '--new-window' // Open in new window to avoid conflicts
    ]
  },
  {
    label: 'e2eTests',
    files: 'out/test/e2e/**/*.test.js',
    version: 'stable',
    workspaceFolder: './src/test-fixtures/large_phoenix_app',
    mocha: {
      ui: 'tdd',
      timeout: 60000, // Longer timeout for E2E tests
      color: true,
      slow: 5000
    },
    launchArgs: [
      '--disable-extensions',
      '--new-window'
    ]
  },
  {
    label: 'integrationTests',
    files: 'out/test/integration/**/*.test.js',
    version: 'stable',
    workspaceFolder: './src/test-fixtures/large_phoenix_app',
    mocha: {
      ui: 'tdd',
      timeout: 30000,
      color: true
    },
    launchArgs: [
      '--disable-extensions',
      '--new-window'
    ]
  }
]);
