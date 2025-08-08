import * as vscode from 'vscode';
import { DynamicInterpretationManager } from './dynamicInterpretationManager';
import { E2EPerformanceMonitor, TestReport } from './e2ePerformanceMonitor';

export class E2ETestController {
  private activeTests: Map<string, { manager: DynamicInterpretationManager; startTime: number }> = new Map();
  private outputChannel: vscode.OutputChannel;

  constructor() {
    this.outputChannel = vscode.window.createOutputChannel('ElixirLS E2E Tests');
  }

  /**
   * Register E2E test commands
   */
  registerCommands(context: vscode.ExtensionContext): void {
    const commands = [
      vscode.commands.registerCommand('elixirLS.runE2ETest', this.runE2ETest.bind(this)),
      vscode.commands.registerCommand('elixirLS.runAllE2ETests', this.runAllE2ETests.bind(this)),
      vscode.commands.registerCommand('elixirLS.showE2EReport', this.showE2EReport.bind(this)),
      vscode.commands.registerCommand('elixirLS.exportE2EData', this.exportE2EData.bind(this)),
      vscode.commands.registerCommand('elixirLS.resetE2EMonitoring', this.resetE2EMonitoring.bind(this))
    ];

    commands.forEach(cmd => context.subscriptions.push(cmd));
  }

  /**
   * Run a specific E2E test scenario
   */
  async runE2ETest(): Promise<void> {
    const scenarios = [
      'user_workflow_simple',
      'business_logic_complex', 
      'ecommerce_full_workflow',
      'stress_test_coordination'
    ];

    const selectedScenario = await vscode.window.showQuickPick(scenarios, {
      placeHolder: 'Select E2E test scenario to run'
    });

    if (!selectedScenario) {
      return;
    }

    this.outputChannel.show();
    this.outputChannel.appendLine(`🚀 Starting E2E test: ${selectedScenario}`);

    try {
      await this.executeE2ETest(selectedScenario);
    } catch (error) {
      this.outputChannel.appendLine(`❌ E2E test failed: ${error}`);
      vscode.window.showErrorMessage(`E2E test failed: ${error}`);
    }
  }

  /**
   * Run all E2E test scenarios sequentially
   */
  async runAllE2ETests(): Promise<void> {
    const scenarios = [
      'user_workflow_simple',
      'business_logic_complex', 
      'ecommerce_full_workflow',
      'stress_test_coordination'
    ];

    this.outputChannel.show();
    this.outputChannel.appendLine('🔥 Running all E2E test scenarios...');

    const results: { scenario: string; report: TestReport | null; error?: string }[] = [];

    for (const scenario of scenarios) {
      try {
        this.outputChannel.appendLine(`\n📋 Running scenario: ${scenario}`);
        const report = await this.executeE2ETest(scenario);
        results.push({ scenario, report });
        this.outputChannel.appendLine(`✅ ${scenario}: ${report?.summary || 'Completed'}`);
      } catch (error) {
        results.push({ scenario, report: null, error: error instanceof Error ? error.toString() : String(error) });
        this.outputChannel.appendLine(`❌ ${scenario}: ${error}`);
      }

      // Wait between tests
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    this.showBatchTestResults(results);
  }

  /**
   * Execute a single E2E test scenario
   */
  private async executeE2ETest(scenarioName: string): Promise<TestReport | null> {
    // Create a mock debug session for testing
    const mockDebugSession = this.createMockDebugSession(scenarioName);
    
    // Create dynamic interpretation manager
    const manager = new DynamicInterpretationManager(this.outputChannel);
    
    // Initialize with test configuration
    const testConfig = this.createE2ETestConfig(scenarioName);
    await manager.initialize(null as any, mockDebugSession, testConfig);

    // Store active test
    this.activeTests.set(mockDebugSession.id, { manager, startTime: performance.now() });

    try {
      // Simulate test workflow based on scenario
      await this.simulateTestWorkflow(manager, scenarioName);
      
      // Complete test and get report
      const report = await manager.completeE2ETest();
      
      return report;
    } finally {
      this.activeTests.delete(mockDebugSession.id);
    }
  }

  /**
   * Create mock debug session for testing
   */
  private createMockDebugSession(scenarioName: string): any {
    return {
      id: `e2e_test_${scenarioName}_${Date.now()}`,
      type: 'mix_task',
      name: `E2E Test: ${scenarioName}`,
      workspaceFolder: vscode.workspace.workspaceFolders?.[0],
      configuration: {
        coordination: {
          enabled: true,
          strategy: 'demand-driven',
          e2eTestScenario: scenarioName
        }
      }
    };
  }

  /**
   * Create E2E test configuration
   */
  private createE2ETestConfig(scenarioName: string): vscode.DebugConfiguration {
    return {
      type: 'mix_task',
      name: `E2E Test: ${scenarioName}`,
      request: 'launch',
      coordination: {
        enabled: true,
        strategy: 'demand-driven',
        e2eTestScenario: scenarioName,
        interpretationPatterns: ['LargePhoenixApp.*']
      }
    };
  }

  /**
   * Simulate test workflow for a scenario
   */
  private async simulateTestWorkflow(manager: DynamicInterpretationManager, scenarioName: string): Promise<void> {
    switch (scenarioName) {
      case 'user_workflow_simple':
        await this.simulateSimpleUserWorkflow(manager);
        break;
      case 'business_logic_complex':
        await this.simulateComplexBusinessLogic(manager);
        break;
      case 'ecommerce_full_workflow':
        await this.simulateFullEcommerceWorkflow(manager);
        break;
      case 'stress_test_coordination':
        await this.simulateStressTest(manager);
        break;
      default:
        throw new Error(`Unknown scenario: ${scenarioName}`);
    }
  }

  private async simulateSimpleUserWorkflow(manager: DynamicInterpretationManager): Promise<void> {
    // Simulate setting breakpoint in User module
    const mockBreakpoint = this.createMockBreakpoint('LargePhoenixApp.Accounts.User', 55);
    await manager.onBreakpointsChanged([mockBreakpoint]);

    // Simulate interpretation request
    await manager.executeInterpretation({
      modules: ['LargePhoenixApp.Accounts.User'],
      strategy: 'immediate',
      context: { reason: 'breakpoint', source: 'test' }
    });

    await manager.takePerformanceSnapshot('simple_workflow_complete');
  }

  private async simulateComplexBusinessLogic(manager: DynamicInterpretationManager): Promise<void> {
    // Simulate complex business logic breakpoint
    const breakpoints = [
      this.createMockBreakpoint('LargePhoenixApp.Accounts.User', 87),
      this.createMockBreakpoint('LargePhoenixApp.Orders.Order', 45),
      this.createMockBreakpoint('LargePhoenixApp.Payments.Payment', 67)
    ];

    for (const bp of breakpoints) {
      await manager.onBreakpointsChanged([bp]);
      await new Promise(resolve => setTimeout(resolve, 100)); // Simulate user interaction delay
    }

    // Simulate batch interpretation
    await manager.executeInterpretation({
      modules: [
        'LargePhoenixApp.Accounts.User',
        'LargePhoenixApp.Orders.Order', 
        'LargePhoenixApp.Payments.Payment',
        'LargePhoenixApp.Notifications.EmailService'
      ],
      strategy: 'queued',
      context: { reason: 'expansion', source: 'test' }
    });

    await manager.takePerformanceSnapshot('complex_logic_complete');
  }

  private async simulateFullEcommerceWorkflow(manager: DynamicInterpretationManager): Promise<void> {
    // Simulate full e-commerce order processing workflow
    const modules = [
      'LargePhoenixApp.Accounts.User',
      'LargePhoenixApp.Orders.Order',
      'LargePhoenixApp.Orders.OrderItem',
      'LargePhoenixApp.Payments.Payment',
      'LargePhoenixApp.Payments.PaymentMethod',
      'LargePhoenixApp.Inventory.Product',
      'LargePhoenixApp.Inventory.Stock',
      'LargePhoenixApp.Notifications.EmailService',
      'LargePhoenixApp.Notifications.NotificationTemplate'
    ];

    // Set breakpoints across the workflow
    for (let i = 0; i < modules.length; i++) {
      const bp = this.createMockBreakpoint(modules[i], 25 + i * 5);
      await manager.onBreakpointsChanged([bp]);
      
      if (i % 3 === 0) {
        // Simulate interpretation at key points
        await manager.executeInterpretation({
          modules: modules.slice(0, i + 1),
          strategy: 'background',
          context: { reason: 'expansion', source: 'test' }
        });
      }
      
      await new Promise(resolve => setTimeout(resolve, 50));
    }

    await manager.takePerformanceSnapshot('full_workflow_complete');
  }

  private async simulateStressTest(manager: DynamicInterpretationManager): Promise<void> {
    // Simulate rapid breakpoint changes and interpretation requests
    for (let i = 0; i < 10; i++) {
      const randomModule = `LargePhoenixApp.TestModule${i % 3}`;
      const bp = this.createMockBreakpoint(randomModule, 10 + i);
      
      await manager.onBreakpointsChanged([bp]);
      
      if (i % 2 === 0) {
        await manager.executeInterpretation({
          modules: [randomModule],
          strategy: 'immediate',
          context: { reason: 'breakpoint', source: 'stress_test' }
        });
      }
      
      // No delay for stress test
    }

    await manager.takePerformanceSnapshot('stress_test_complete');
  }

  private createMockBreakpoint(moduleFile: string, line: number): vscode.SourceBreakpoint {
    const uri = vscode.Uri.file(`/test/${moduleFile.toLowerCase().replace(/\./g, '/')}.ex`);
    return new vscode.SourceBreakpoint(
      new vscode.Location(uri, new vscode.Position(line, 0))
    );
  }

  /**
   * Show E2E test report
   */
  async showE2EReport(): Promise<void> {
    if (this.activeTests.size === 0) {
      vscode.window.showInformationMessage('No active E2E tests found.');
      return;
    }

    const testIds = Array.from(this.activeTests.keys());
    const selectedTest = await vscode.window.showQuickPick(testIds, {
      placeHolder: 'Select test to view report'
    });

    if (!selectedTest) {
      return;
    }

    const testInfo = this.activeTests.get(selectedTest);
    if (testInfo) {
      const report = await testInfo.manager.completeE2ETest();
      if (report) {
        this.displayReport(report);
      }
    }
  }

  /**
   * Export E2E performance data
   */
  async exportE2EData(): Promise<void> {
    if (this.activeTests.size === 0) {
      vscode.window.showInformationMessage('No active E2E tests found.');
      return;
    }

    const uri = await vscode.window.showSaveDialog({
      defaultUri: vscode.Uri.file('e2e_performance_data.json'),
      filters: { 'JSON': ['json'] }
    });

    if (!uri) {
      return;
    }

    try {
      const allData = Array.from(this.activeTests.values()).map(test => test.manager.exportPerformanceData());
      const jsonData = JSON.stringify(allData, null, 2);
      
      await vscode.workspace.fs.writeFile(uri, Buffer.from(jsonData));
      vscode.window.showInformationMessage(`E2E performance data exported to ${uri.fsPath}`);
    } catch (error) {
      vscode.window.showErrorMessage(`Failed to export data: ${error}`);
    }
  }

  /**
   * Reset E2E monitoring
   */
  async resetE2EMonitoring(): Promise<void> {
    this.activeTests.forEach(test => {
      test.manager.getE2EMonitor().reset();
    });
    this.activeTests.clear();
    
    this.outputChannel.clear();
    this.outputChannel.appendLine('🔄 E2E monitoring reset');
    vscode.window.showInformationMessage('E2E monitoring has been reset.');
  }

  private showBatchTestResults(results: { scenario: string; report: TestReport | null; error?: string }[]): void {
    this.outputChannel.appendLine('\n📊 === E2E TEST BATCH RESULTS ===');
    
    let passedCount = 0;
    let totalCount = results.length;

    results.forEach(result => {
      if (result.report?.passed) {
        passedCount++;
        this.outputChannel.appendLine(`✅ ${result.scenario}: PASSED`);
      } else if (result.error) {
        this.outputChannel.appendLine(`❌ ${result.scenario}: ERROR - ${result.error}`);
      } else {
        this.outputChannel.appendLine(`❌ ${result.scenario}: FAILED`);
      }
    });

    this.outputChannel.appendLine(`\n📈 Overall: ${passedCount}/${totalCount} tests passed`);
    
    const message = `E2E tests completed: ${passedCount}/${totalCount} passed`;
    if (passedCount === totalCount) {
      vscode.window.showInformationMessage(message);
    } else {
      vscode.window.showWarningMessage(message);
    }
  }

  private displayReport(report: TestReport): void {
    const panel = vscode.window.createWebviewPanel(
      'e2eReport',
      `E2E Test Report: ${report.scenarioName}`,
      vscode.ViewColumn.One,
      {}
    );

    panel.webview.html = this.generateReportHTML(report);
  }

  private generateReportHTML(report: TestReport): string {
    const status = report.passed ? '✅ PASSED' : '❌ FAILED';
    const statusColor = report.passed ? '#4CAF50' : '#F44336';

    return `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; margin: 20px; }
          .status { color: ${statusColor}; font-weight: bold; font-size: 24px; }
          .metric { margin: 10px 0; padding: 10px; background: #f5f5f5; border-radius: 5px; }
          .benchmark { color: #666; font-size: 0.9em; }
        </style>
      </head>
      <body>
        <h1>E2E Test Report: ${report.scenarioName}</h1>
        <div class="status">${status}</div>
        <div class="metric">
          <strong>Total Duration:</strong> ${report.totalDuration.toFixed(2)}ms
        </div>
        <div class="metric">
          <strong>Max Coordination Time:</strong> ${report.metrics.maxCoordinationTime}ms
          <div class="benchmark">Benchmark: ${report.expected.maxCoordinationTime}ms</div>
        </div>
        <div class="metric">
          <strong>Max Interpretation Time:</strong> ${report.metrics.maxInterpretationTime}ms
          <div class="benchmark">Benchmark: ${report.expected.maxInterpretationTime}ms</div>
        </div>
        <div class="metric">
          <strong>Memory Overhead:</strong> ${(report.metrics.memoryOverhead / 1024 / 1024).toFixed(2)}MB
          <div class="benchmark">Benchmark: ${(report.expected.maxMemoryOverhead / 1024 / 1024).toFixed(2)}MB</div>
        </div>
        <div class="metric">
          <strong>Total Operations:</strong> ${report.metrics.totalOperations}
        </div>
        <div class="metric">
          <strong>Summary:</strong> ${report.summary}
        </div>
      </body>
      </html>
    `;
  }

  dispose(): void {
    this.outputChannel.dispose();
  }
}
