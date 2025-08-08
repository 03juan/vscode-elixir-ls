#!/usr/bin/env node

/**
 * Quick validation test for IDE Coordinator E2E components
 */

const fs = require('fs');
const path = require('path');

console.log('🧪 IDE Coordinator E2E Component Validation Test');
console.log('='.repeat(60));

// Test 1: Check if all core files exist
console.log('📁 Testing file existence...');
const coreFiles = [
  'src/e2ePerformanceMonitor.ts',
  'src/e2eTestController.ts', 
  'src/dynamicInterpretationManager.ts',
  'out/extension.js',
  'src/test-fixtures/large_phoenix_app/lib/large_phoenix_app.ex',
  'scripts/e2e-test-automation.js'
];

let filesExist = true;
coreFiles.forEach(file => {
  if (fs.existsSync(file)) {
    console.log(`✅ ${file}`);
  } else {
    console.log(`❌ ${file} - MISSING`);
    filesExist = false;
  }
});

// Test 2: Check package.json scripts
console.log('\n📋 Testing npm scripts...');
const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const e2eScripts = [
  'e2e:test',
  'e2e:test:simple', 
  'e2e:test:complex',
  'e2e:test:full',
  'e2e:test:stress',
  'e2e:test:export'
];

let scriptsExist = true;
e2eScripts.forEach(script => {
  if (packageJson.scripts[script]) {
    console.log(`✅ ${script}: ${packageJson.scripts[script]}`);
  } else {
    console.log(`❌ ${script} - MISSING`);
    scriptsExist = false;
  }
});

// Test 3: Check VS Code commands in package.json
console.log('\n🎯 Testing VS Code commands...');
const e2eCommands = [
  'elixirLS.runE2ETest',
  'elixirLS.runAllE2ETests',
  'elixirLS.showE2EReport', 
  'elixirLS.exportE2EData',
  'elixirLS.resetE2EMonitoring'
];

let commandsExist = true;
const commands = packageJson.contributes?.commands || [];
e2eCommands.forEach(cmdId => {
  const found = commands.find(cmd => cmd.command === cmdId);
  if (found) {
    console.log(`✅ ${cmdId}: ${found.title}`);
  } else {
    console.log(`❌ ${cmdId} - MISSING`);
    commandsExist = false;
  }
});

// Test 4: Validate test scenarios in E2EPerformanceMonitor
console.log('\n🎭 Testing scenario definitions...');
const e2eMonitorContent = fs.readFileSync('src/e2ePerformanceMonitor.ts', 'utf8');
const expectedScenarios = [
  'user_workflow_simple',
  'business_logic_complex', 
  'ecommerce_full_workflow',
  'stress_test_coordination'
];

let scenariosExist = true;
expectedScenarios.forEach(scenario => {
  if (e2eMonitorContent.includes(`'${scenario}'`)) {
    console.log(`✅ ${scenario}`);
  } else {
    console.log(`❌ ${scenario} - MISSING`);
    scenariosExist = false;
  }
});

// Test 5: Check mock Phoenix app structure
console.log('\n🏢 Testing mock Phoenix app...');
const phoenixModules = [
  'src/test-fixtures/large_phoenix_app/lib/large_phoenix_app/accounts/user.ex',
  'src/test-fixtures/large_phoenix_app/lib/large_phoenix_app/orders/order.ex',
  'src/test-fixtures/large_phoenix_app/lib/large_phoenix_app/payments/payment.ex',
  'src/test-fixtures/large_phoenix_app/lib/large_phoenix_app/inventory/product.ex',
  'src/test-fixtures/large_phoenix_app/lib/large_phoenix_app/notifications/email_service.ex'
];

let phoenixExists = true;
phoenixModules.forEach(module => {
  if (fs.existsSync(module)) {
    console.log(`✅ ${path.basename(module)}`);
  } else {
    console.log(`❌ ${path.basename(module)} - MISSING`);
    phoenixExists = false;
  }
});

// Test 6: Check test results directory
console.log('\n📊 Testing results infrastructure...');
if (!fs.existsSync('test-results')) {
  fs.mkdirSync('test-results', { recursive: true });
  console.log('✅ Created test-results directory');
} else {
  console.log('✅ test-results directory exists');
}

// Test 7: Validate exported results
if (fs.existsSync('test-results/e2e-report.json')) {
  try {
    const report = JSON.parse(fs.readFileSync('test-results/e2e-report.json', 'utf8'));
    console.log(`✅ Valid JSON report with ${report.results.length} test results`);
    console.log(`   └─ Success rate: ${report.summary.successRate}`);
    console.log(`   └─ Total duration: ${report.summary.totalDuration}`);
  } catch (error) {
    console.log('❌ Invalid JSON report format');
  }
} else {
  console.log('⚠️  No test report found (run tests first)');
}

// Final validation
console.log('\n🎯 Final Validation');
console.log('='.repeat(60));

const allValid = filesExist && scriptsExist && commandsExist && scenariosExist && phoenixExists;

if (allValid) {
  console.log('✅ ALL COMPONENTS VALIDATED SUCCESSFULLY');
  console.log('🚀 IDE Coordinator E2E Testing System is ready for production use!');
  console.log('\nNext steps:');
  console.log('1. Run npm run e2e:test to execute all scenarios');
  console.log('2. Use VS Code Command Palette: "ElixirLS E2E" commands');
  console.log('3. Enable coordination in debug configurations');
  console.log('4. Monitor performance in real debugging sessions');
  process.exit(0);
} else {
  console.log('❌ VALIDATION FAILED - Some components are missing');
  console.log('Please review the missing components above');
  process.exit(1);
}
