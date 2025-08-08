import * as vscode from 'vscode';
import { LanguageClient } from 'vscode-languageclient/node';

export interface PerformanceMetrics {
  operation: string;
  module?: string;
  timing: {
    startTime: number;
    endTime: number;
    duration: number;
  };
  metadata: Record<string, any>;
  context?: {
    sessionId?: string;
    strategy?: string;
    moduleCount?: number;
  };
}

export interface PerformanceSnapshot {
  timestamp: string;
  memoryUsage: {
    heapUsed: number;
    heapTotal: number;
    external: number;
    rss: number;
  };
  interpretedModules: number;
  coordinationRequests: number;
  averageResponseTime: number;
}

export interface E2ETestScenario {
  name: string;
  description: string;
  targetModules: string[];
  expectedBehavior: {
    maxCoordinationTime: number;
    maxInterpretationTime: number;
    maxMemoryOverhead: number;
  };
  testSteps: TestStep[];
}

export interface TestStep {
  action: 'breakpoint' | 'interpretation' | 'evaluation' | 'wait';
  target: string;
  parameters?: Record<string, any>;
  expectedDuration?: number;
}

/**
 * End-to-End Performance Monitor for IDE Coordinator testing.
 * Provides comprehensive monitoring and validation of performance
 * during real-world debugging scenarios with complex module dependencies.
 */
export class E2EPerformanceMonitor {
  private metrics: PerformanceMetrics[] = [];
  private snapshots: PerformanceSnapshot[] = [];
  private testScenarios: Map<string, E2ETestScenario> = new Map();
  private activeTests: Map<string, { scenario: E2ETestScenario; startTime: number; stepIndex: number }> = new Map();
  private benchmarks: Map<string, number> = new Map();

  constructor(
    private outputChannel: vscode.OutputChannel,
    private workspaceFolder?: vscode.WorkspaceFolder
  ) {
    this.initializeBenchmarks();
    this.registerTestScenarios();
  }

  private initializeBenchmarks(): void {
    // Phase 3 performance targets
    this.benchmarks.set('single_module_interpretation', 50); // ms
    this.benchmarks.set('dependency_chain_coordination', 250); // ms
    this.benchmarks.set('full_workflow_traversal', 500); // ms
    this.benchmarks.set('memory_overhead_limit', 10 * 1024 * 1024); // 10MB
  }

  private registerTestScenarios(): void {
    // Scenario 1: Simple User Workflow
    this.testScenarios.set('user_workflow_simple', {
      name: 'Simple User Workflow',
      description: 'Test basic user operations without complex dependencies',
      targetModules: ['LargePhoenixApp.Accounts.User'],
      expectedBehavior: {
        maxCoordinationTime: 50,
        maxInterpretationTime: 30,
        maxMemoryOverhead: 2 * 1024 * 1024
      },
      testSteps: [
        { action: 'breakpoint', target: 'LargePhoenixApp.Accounts.User:update_login_stats/1' },
        { action: 'interpretation', target: 'LargePhoenixApp.Accounts.User' },
        { action: 'evaluation', target: 'user.email', expectedDuration: 10 }
      ]
    });

    // Scenario 2: Complex Business Logic Chain
    this.testScenarios.set('business_logic_complex', {
      name: 'Complex Business Logic',
      description: 'Test User.complex_business_logic/2 with cross-module coordination',
      targetModules: [
        'LargePhoenixApp.Accounts.User',
        'LargePhoenixApp.Orders.Order',
        'LargePhoenixApp.Payments.Payment',
        'LargePhoenixApp.Notifications.EmailService'
      ],
      expectedBehavior: {
        maxCoordinationTime: 250,
        maxInterpretationTime: 150,
        maxMemoryOverhead: 5 * 1024 * 1024
      },
      testSteps: [
        { action: 'breakpoint', target: 'LargePhoenixApp.Accounts.User:complex_business_logic/2' },
        { action: 'interpretation', target: 'LargePhoenixApp.Accounts.User' },
        { action: 'interpretation', target: 'LargePhoenixApp.Orders.Order' },
        { action: 'interpretation', target: 'LargePhoenixApp.Payments.Payment' },
        { action: 'evaluation', target: 'user_analysis_result', expectedDuration: 20 }
      ]
    });

    // Scenario 3: Full E-commerce Order Processing
    this.testScenarios.set('ecommerce_full_workflow', {
      name: 'Full E-commerce Workflow',
      description: 'Complete order processing with all module dependencies',
      targetModules: [
        'LargePhoenixApp.Accounts.User',
        'LargePhoenixApp.Orders.Order',
        'LargePhoenixApp.Orders.OrderItem',
        'LargePhoenixApp.Payments.Payment',
        'LargePhoenixApp.Payments.PaymentMethod',
        'LargePhoenixApp.Inventory.Product',
        'LargePhoenixApp.Inventory.Stock',
        'LargePhoenixApp.Notifications.EmailService',
        'LargePhoenixApp.Notifications.NotificationTemplate'
      ],
      expectedBehavior: {
        maxCoordinationTime: 500,
        maxInterpretationTime: 300,
        maxMemoryOverhead: 10 * 1024 * 1024
      },
      testSteps: [
        { action: 'breakpoint', target: 'LargePhoenixApp.Orders.Order:process_order/1' },
        { action: 'interpretation', target: 'LargePhoenixApp.Orders.Order' },
        { action: 'interpretation', target: 'LargePhoenixApp.Inventory.Stock' },
        { action: 'interpretation', target: 'LargePhoenixApp.Payments.Payment' },
        { action: 'interpretation', target: 'LargePhoenixApp.Notifications.EmailService' },
        { action: 'wait', target: 'coordination_complete', parameters: { timeout: 1000 } },
        { action: 'evaluation', target: 'order_result', expectedDuration: 50 }
      ]
    });

    // Scenario 4: High-load Stress Test
    this.testScenarios.set('stress_test_coordination', {
      name: 'Coordination Stress Test',
      description: 'Test coordinator under high load with rapid breakpoint changes',
      targetModules: [
        'LargePhoenixApp.Accounts.User',
        'LargePhoenixApp.Accounts.Profile',
        'LargePhoenixApp.Accounts.Settings',
        'LargePhoenixApp.Orders.Order',
        'LargePhoenixApp.Payments.Payment',
        'LargePhoenixApp.Inventory.Product',
        'LargePhoenixApp.Notifications.EmailService'
      ],
      expectedBehavior: {
        maxCoordinationTime: 300,
        maxInterpretationTime: 200,
        maxMemoryOverhead: 8 * 1024 * 1024
      },
      testSteps: [
        { action: 'breakpoint', target: 'LargePhoenixApp.Accounts.User:complex_business_logic/2' },
        { action: 'breakpoint', target: 'LargePhoenixApp.Orders.Order:process_order/1' },
        { action: 'breakpoint', target: 'LargePhoenixApp.Payments.Payment:process_order_payment/1' },
        { action: 'interpretation', target: 'batch_coordination', parameters: { moduleCount: 7 } },
        { action: 'evaluation', target: 'stress_test_result', expectedDuration: 100 }
      ]
    });
  }

  /**
   * Get test scenario definition by name
   */
  getTestScenario(scenarioName: string): E2ETestScenario | undefined {
    return this.testScenarios.get(scenarioName);
  }

  /**
   * Start monitoring an E2E test scenario
   */
  async startE2ETest(scenarioName: string, sessionId: string): Promise<void> {
    const scenario = this.testScenarios.get(scenarioName);
    if (!scenario) {
      throw new Error(`Unknown test scenario: ${scenarioName}`);
    }

    this.outputChannel.appendLine(`🚀 Starting E2E test: ${scenario.name}`);
    this.outputChannel.appendLine(`📋 Description: ${scenario.description}`);
    this.outputChannel.appendLine(`🎯 Target modules: ${scenario.targetModules.join(', ')}`);

    const testRun = {
      scenario,
      startTime: performance.now(),
      stepIndex: 0
    };

    this.activeTests.set(sessionId, testRun);
    await this.takePerformanceSnapshot(`test_start_${scenarioName}`);
  }

  /**
   * Record a performance metric from the debug adapter
   */
  recordMetric(metric: PerformanceMetrics): void {
    this.metrics.push(metric);
    
    // Check against benchmarks
    this.validatePerformance(metric);
    
    // Log metric
    this.outputChannel.appendLine(
      `📊 Performance: ${metric.operation} ${metric.module ? `[${metric.module}]` : ''} - ${metric.timing.duration}ms`
    );
  }

  /**
   * Take a performance snapshot
   */
  async takePerformanceSnapshot(label: string): Promise<void> {
    const memUsage = process.memoryUsage();
    
    const snapshot: PerformanceSnapshot = {
      timestamp: new Date().toISOString(),
      memoryUsage: {
        heapUsed: memUsage.heapUsed,
        heapTotal: memUsage.heapTotal,
        external: memUsage.external,
        rss: memUsage.rss
      },
      interpretedModules: this.metrics.filter(m => m.operation === 'interpretation').length,
      coordinationRequests: this.metrics.filter(m => m.operation === 'coordination').length,
      averageResponseTime: this.calculateAverageResponseTime()
    };

    this.snapshots.push(snapshot);
    
    this.outputChannel.appendLine(`📸 Snapshot [${label}]: Memory ${(snapshot.memoryUsage.heapUsed / 1024 / 1024).toFixed(1)}MB, ${snapshot.interpretedModules} modules interpreted`);
  }

  /**
   * Complete an E2E test and generate report
   */
  async completeE2ETest(sessionId: string): Promise<TestReport> {
    const testRun = this.activeTests.get(sessionId);
    if (!testRun) {
      throw new Error(`No active test found for session: ${sessionId}`);
    }

    const totalDuration = performance.now() - testRun.startTime;
    await this.takePerformanceSnapshot(`test_end_${testRun.scenario.name}`);

    const report = this.generateTestReport(testRun.scenario, totalDuration);
    
    this.outputChannel.appendLine(`✅ E2E test completed: ${testRun.scenario.name}`);
    this.outputChannel.appendLine(`⏱️  Total duration: ${totalDuration.toFixed(2)}ms`);
    this.outputChannel.appendLine(`📈 Performance summary: ${report.summary}`);

    this.activeTests.delete(sessionId);
    return report;
  }

  /**
   * Validate performance against benchmarks
   */
  private validatePerformance(metric: PerformanceMetrics): void {
    const operation = metric.operation;
    let benchmarkKey = '';
    
    switch (operation) {
      case 'interpretation':
        benchmarkKey = 'single_module_interpretation';
        break;
      case 'coordination':
        const moduleCount = metric.context?.moduleCount || 1;
        benchmarkKey = moduleCount > 5 ? 'full_workflow_traversal' : 'dependency_chain_coordination';
        break;
    }

    if (benchmarkKey) {
      const benchmark = this.benchmarks.get(benchmarkKey);
      if (benchmark && metric.timing.duration > benchmark) {
        this.outputChannel.appendLine(
          `⚠️  Performance warning: ${operation} took ${metric.timing.duration}ms (benchmark: ${benchmark}ms)`
        );
      } else if (benchmark) {
        this.outputChannel.appendLine(
          `✅ Performance good: ${operation} took ${metric.timing.duration}ms (benchmark: ${benchmark}ms)`
        );
      }
    }
  }

  private calculateAverageResponseTime(): number {
    if (this.metrics.length === 0) return 0;
    const totalTime = this.metrics.reduce((sum, metric) => sum + metric.timing.duration, 0);
    return totalTime / this.metrics.length;
  }

  private generateTestReport(scenario: E2ETestScenario, totalDuration: number): TestReport {
    const coordinationMetrics = this.metrics.filter(m => m.operation === 'coordination');
    const interpretationMetrics = this.metrics.filter(m => m.operation === 'interpretation');
    
    const maxCoordinationTime = Math.max(...coordinationMetrics.map(m => m.timing.duration), 0);
    const maxInterpretationTime = Math.max(...interpretationMetrics.map(m => m.timing.duration), 0);
    
    const latestSnapshot = this.snapshots[this.snapshots.length - 1];
    const memoryOverhead = latestSnapshot?.memoryUsage.heapUsed || 0;

    const passed = 
      maxCoordinationTime <= scenario.expectedBehavior.maxCoordinationTime &&
      maxInterpretationTime <= scenario.expectedBehavior.maxInterpretationTime &&
      memoryOverhead <= scenario.expectedBehavior.maxMemoryOverhead;

    return {
      scenarioName: scenario.name,
      passed,
      totalDuration,
      metrics: {
        maxCoordinationTime,
        maxInterpretationTime,
        memoryOverhead,
        totalOperations: this.metrics.length
      },
      expected: scenario.expectedBehavior,
      summary: passed ? 'PASSED - All benchmarks met' : 'FAILED - Performance targets exceeded'
    };
  }

  /**
   * Export performance data for analysis
   */
  exportPerformanceData(): E2EPerformanceData {
    return {
      metrics: this.metrics,
      snapshots: this.snapshots,
      benchmarks: Object.fromEntries(this.benchmarks),
      testScenarios: Object.fromEntries(this.testScenarios)
    };
  }

  /**
   * Reset monitoring state
   */
  reset(): void {
    this.metrics = [];
    this.snapshots = [];
    this.activeTests.clear();
  }

  /**
   * Get current performance metrics
   */
  getMetrics(): PerformanceMetrics[] {
    return [...this.metrics];
  }

  /**
   * Get performance snapshots
   */
  getSnapshots(): PerformanceSnapshot[] {
    return [...this.snapshots];
  }
}

export interface TestReport {
  scenarioName: string;
  passed: boolean;
  totalDuration: number;
  metrics: {
    maxCoordinationTime: number;
    maxInterpretationTime: number;
    memoryOverhead: number;
    totalOperations: number;
  };
  expected: E2ETestScenario['expectedBehavior'];
  summary: string;
}

export interface E2EPerformanceData {
  metrics: PerformanceMetrics[];
  snapshots: PerformanceSnapshot[];
  benchmarks: Record<string, number>;
  testScenarios: Record<string, E2ETestScenario>;
}
