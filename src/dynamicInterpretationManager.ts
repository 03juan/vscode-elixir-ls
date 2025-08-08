import * as vscode from 'vscode';
import { LanguageClient } from 'vscode-languageclient/node';
import { E2EPerformanceMonitor, PerformanceMetrics } from './e2ePerformanceMonitor';

export interface DependencyAnalysisRequest {
  module: string;
  function?: string;
  arity?: number;
  scope: 'minimal' | 'conservative' | 'complete';
  includeTransitive?: boolean;
  interpretationPatterns?: string[];
}

export interface DependencyAnalysisResponse {
  targetModule: string;
  scopeStrategy: string;
  interpretationScope: string[];
  dependencies: {
    direct: string[];
    transitive: Record<string, string[]>;
  };
  metadata: {
    analysisTimestamp: string;
    tracerDataSize: number;
    complexityAssessment: 'low' | 'medium' | 'high' | 'very_high';
    estimatedInterpretationTime: number;
  };
}

export interface InterpretationRequest {
  modules: string[];
  strategy: 'immediate' | 'queued' | 'background';
  context: {
    reason: 'breakpoint' | 'reload' | 'expansion' | 'prediction';
    source: string;
    priority?: number;
  };
}

export interface CoordinationStrategy {
  name: string;
  onBreakpointSet(breakpoint: vscode.Breakpoint): Promise<void>;
  onBreakpointsChanged(breakpoints: vscode.Breakpoint[]): Promise<void>;
  shouldReinterpret(changedFiles: string[]): Promise<boolean>;
}

/**
 * Manages dynamic interpretation coordination between language server and debug adapter.
 * Acts as the intelligent coordinator that determines what modules need interpretation
 * and orchestrates the process between ElixirLS components.
 */
export class DynamicInterpretationManager {
  private languageClient: LanguageClient | undefined;
  private debugAdapter: any; // TODO: Type this properly
  private interpretedModules: Set<string> = new Set();
  private interpretationPatterns: string[] = [];
  private currentStrategy: CoordinationStrategy | null;
  private coordinationEnabled: boolean = false;
  private e2eMonitor: E2EPerformanceMonitor;
  private sessionId: string = '';

  constructor(
    private outputChannel: vscode.OutputChannel,
    private workspaceFolder?: vscode.WorkspaceFolder
  ) {
    // Default to demand-driven strategy
    this.currentStrategy = new DemandDrivenCoordinator(this);
    // Initialize E2E performance monitor
    this.e2eMonitor = new E2EPerformanceMonitor(outputChannel, workspaceFolder);
  }

  /**
   * Initialize coordination with language client and debug adapter
   */
  async initialize(
    languageClient: LanguageClient, 
    debugAdapter: any,
    config: vscode.DebugConfiguration
  ): Promise<void> {
    this.languageClient = languageClient;
    this.debugAdapter = debugAdapter;
    this.coordinationEnabled = config.coordination?.enabled ?? false;
    
    // Set interpretation patterns from config
    this.interpretationPatterns = config.coordination?.interpretationPatterns ?? ['*'];
    this.outputChannel.appendLine(`Interpretation patterns: ${this.interpretationPatterns.join(', ')}`);
    
    // Generate session ID
    this.sessionId = debugAdapter.id || Math.random().toString(36).substr(2, 9);

    if (this.coordinationEnabled) {
      this.outputChannel.appendLine('Dynamic interpretation coordination enabled');
      
      // Set coordination strategy
      const strategyName = config.coordination?.strategy ?? 'demand-driven';
      this.setCoordinationStrategy(strategyName);

      // Enable coordination mode in debug adapter
      await this.enableDebugAdapterCoordination();

      // Start E2E monitoring if configured
      const e2eTestScenario = config.coordination?.e2eTestScenario;
      if (e2eTestScenario) {
        await this.startE2ETest(e2eTestScenario);
      }
    } else {
      this.outputChannel.appendLine('Dynamic interpretation coordination disabled');
    }
  }

  /**
   * Start E2E performance test scenario
   */
  async startE2ETest(scenarioName: string): Promise<void> {
    try {
      await this.e2eMonitor.startE2ETest(scenarioName, this.sessionId);
      this.outputChannel.appendLine(`🧪 E2E test started: ${scenarioName}`);
    } catch (error) {
      this.outputChannel.appendLine(`Failed to start E2E test: ${error}`);
    }
  }

  /**
   * Record performance metric from debug adapter
   */
  recordPerformanceMetric(operation: string, module: string | undefined, duration: number, metadata: Record<string, any> = {}): void {
    const metric: PerformanceMetrics = {
      operation,
      module,
      timing: {
        startTime: performance.now() - duration,
        endTime: performance.now(),
        duration
      },
      metadata,
      context: {
        sessionId: this.sessionId,
        strategy: this.currentStrategy?.name || 'none',
        moduleCount: metadata.moduleCount
      }
    };

    this.e2eMonitor.recordMetric(metric);
  }

  /**
   * Take performance snapshot
   */
  async takePerformanceSnapshot(label: string): Promise<void> {
    await this.e2eMonitor.takePerformanceSnapshot(label);
  }

  /**
   * Complete E2E test and get report
   */
  async completeE2ETest(): Promise<any> {
    try {
      const report = await this.e2eMonitor.completeE2ETest(this.sessionId);
      this.outputChannel.appendLine(`📊 E2E test completed with result: ${report.summary}`);
      return report;
    } catch (error) {
      this.outputChannel.appendLine(`Failed to complete E2E test: ${error}`);
      return null;
    }
  }

  /**
   * Export performance data
   */
  exportPerformanceData(): any {
    return {
      metrics: this.e2eMonitor ? this.e2eMonitor.getMetrics() : [],
      snapshots: this.e2eMonitor ? this.e2eMonitor.getSnapshots() : [],
      summary: {
        coordinationEnabled: this.coordinationEnabled,
        currentStrategy: this.currentStrategy?.name || 'none',
        sessionId: this.sessionId
      }
    };
  }

  /**
   * Check if coordination is enabled
   */
  isCoordinationEnabled(): boolean {
    return this.coordinationEnabled;
  }

  /**
   * Get current coordination strategy
   */
  getCurrentStrategy(): CoordinationStrategy | null {
    return this.currentStrategy;
  }

  /**
   * Get E2E monitor instance for external access
   */
  getE2EMonitor(): E2EPerformanceMonitor {
    return this.e2eMonitor;
  }

  dispose(): void {
    // Clean up resources - delegate to performance monitor reset
    if (this.e2eMonitor) {
      this.e2eMonitor.reset();
    }
    this.currentStrategy = null as any; // Allow null assignment
    this.coordinationEnabled = false;
    
    this.outputChannel.appendLine('Dynamic interpretation manager disposed');
  }

  /**
   * Handle breakpoint changes - main coordination entry point
   */
  async onBreakpointsChanged(breakpoints: vscode.Breakpoint[]): Promise<void> {
    if (!this.coordinationEnabled || !this.currentStrategy) {
      return;
    }

    const startTime = performance.now();
    try {
      await this.currentStrategy.onBreakpointsChanged(breakpoints);
      const duration = performance.now() - startTime;
      this.recordPerformanceMetric('coordination', undefined, duration, { 
        breakpointCount: breakpoints.length,
        strategy: this.currentStrategy.name 
      });
    } catch (error) {
      this.outputChannel.appendLine(`Error in breakpoint coordination: ${error}`);
      const duration = performance.now() - startTime;
      this.recordPerformanceMetric('coordination_error', undefined, duration, { 
        error: error instanceof Error ? error.toString() : String(error),
        breakpointCount: breakpoints.length 
      });
    }
  }

  /**
   * Request dependency analysis from language server
   */
  async requestDependencyAnalysis(
    module: string, 
    context: Partial<DependencyAnalysisRequest> = {}
  ): Promise<DependencyAnalysisResponse> {
    if (!this.languageClient) {
      throw new Error('Language client not initialized');
    }

    const request: DependencyAnalysisRequest = {
      module,
      scope: context.scope ?? 'minimal',
      includeTransitive: context.includeTransitive ?? false,
      interpretationPatterns: context.interpretationPatterns ?? this.interpretationPatterns,
      ...context
    };

    this.outputChannel.appendLine(`Requesting dependency analysis for ${module} (scope: ${request.scope})`);

    const startTime = performance.now();
    try {
      const response = await this.languageClient.sendRequest('workspace/executeCommand', {
        command: `debugDependencyAnalysis:${this.getServerInstanceId()}`,
        arguments: [request]
      }) as DependencyAnalysisResponse;

      if ('error' in response) {
        throw new Error(`Dependency analysis failed: ${(response as any).error}`);
      }

      const duration = performance.now() - startTime;
      this.recordPerformanceMetric('dependency_analysis', module, duration, {
        scope: request.scope,
        moduleCount: response.interpretationScope.length,
        complexity: response.metadata.complexityAssessment
      });

      this.outputChannel.appendLine(
        `Analysis complete: ${response.interpretationScope.length} modules, ` +
        `complexity: ${response.metadata.complexityAssessment}, ` +
        `estimated time: ${response.metadata.estimatedInterpretationTime}ms`
      );

      return response;
    } catch (error) {
      const duration = performance.now() - startTime;
      this.recordPerformanceMetric('dependency_analysis_error', module, duration, {
        error: error instanceof Error ? error.toString() : String(error),
        scope: request.scope
      });
      this.outputChannel.appendLine(`Dependency analysis request failed: ${error}`);
      throw error;
    }
  }

  /**
   * Execute interpretation request on debug adapter
   */
  async executeInterpretation(request: InterpretationRequest): Promise<any> {
    if (!this.debugAdapter) {
      throw new Error('Debug adapter not initialized');
    }

    this.outputChannel.appendLine(
      `Executing interpretation: ${request.modules.length} modules, strategy: ${request.strategy}`
    );

    const startTime = performance.now();
    try {
      const response = await this.debugAdapter.sendRequest('coordinatedInterpret', {
        modules: request.modules,
        strategy: request.strategy,
        context: request.context
      });

      // Update our tracking
      if (response.interpreted) {
        response.interpreted.forEach((module: string) => {
          this.interpretedModules.add(module);
        });
      }

      const duration = performance.now() - startTime;
      this.recordPerformanceMetric('interpretation', undefined, duration, {
        moduleCount: request.modules.length,
        strategy: request.strategy,
        successCount: response.interpreted?.length || 0,
        failureCount: response.failed?.length || 0,
        totalTime: response.totalTime
      });

      this.outputChannel.appendLine(
        `Interpretation result: ${response.interpreted?.length || 0} successful, ` +
        `${response.failed?.length || 0} failed, ${response.totalTime}ms`
      );

      return response;
    } catch (error) {
      const duration = performance.now() - startTime;
      this.recordPerformanceMetric('interpretation_error', undefined, duration, {
        moduleCount: request.modules.length,
        strategy: request.strategy,
        error: error instanceof Error ? error.toString() : String(error)
      });
      this.outputChannel.appendLine(`Interpretation request failed: ${error}`);
      throw error;
    }
  }

  /**
   * Plan interpretation scope for multiple breakpoints
   */
  async planInterpretationScope(breakpoints: vscode.Breakpoint[]): Promise<{
    targetModules: string[];
    analysisRequests: DependencyAnalysisRequest[];
    context: any;
  }> {
    const targetModules = new Set<string>();
    const analysisRequests: DependencyAnalysisRequest[] = [];

    for (const breakpoint of breakpoints) {
      if (breakpoint instanceof vscode.SourceBreakpoint) {
        const module = this.extractModuleFromUri(breakpoint.location.uri);
        if (module) {
          targetModules.add(module);
          analysisRequests.push({
            module,
            scope: 'conservative',
            interpretationPatterns: this.interpretationPatterns
          });
        }
      }
    }

    return {
      targetModules: Array.from(targetModules),
      analysisRequests,
      context: {
        workspaceFolder: this.workspaceFolder?.uri.fsPath,
        interpretationPatterns: this.interpretationPatterns
      }
    };
  }

  /**
   * Merge multiple dependency analysis results
   */
  mergeDependencies(analyses: DependencyAnalysisResponse[]): string[] {
    const allModules = new Set<string>();
    
    analyses.forEach(analysis => {
      analysis.interpretationScope.forEach(module => allModules.add(module));
    });

    // Remove already interpreted modules
    const newModules = Array.from(allModules).filter(
      module => !this.interpretedModules.has(module)
    );

    return newModules;
  }

  /**
   * Check if modules should be reinterpreted based on file changes
   */
  async shouldReinterpret(changedFiles: string[]): Promise<boolean> {
    if (!this.currentStrategy) {
      return false;
    }

    return await this.currentStrategy.shouldReinterpret(changedFiles);
  }

  /**
   * Set coordination strategy
   */
  setCoordinationStrategy(strategyName: string): void {
    switch (strategyName) {
      case 'demand-driven':
        this.currentStrategy = new DemandDrivenCoordinator(this);
        break;
      case 'predictive':
        this.currentStrategy = new PredictiveCoordinator(this);
        break;
      case 'learning':
        this.currentStrategy = new LearningCoordinator(this);
        break;
      default:
        this.outputChannel.appendLine(`Unknown strategy: ${strategyName}, using demand-driven`);
        this.currentStrategy = new DemandDrivenCoordinator(this);
    }

    this.outputChannel.appendLine(`Coordination strategy set to: ${strategyName}`);
  }

  /**
   * Get current interpretation status
   */
  getInterpretationStatus(): {
    interpretedCount: number;
    interpretedModules: string[];
    coordinationEnabled: boolean;
    currentStrategy: string;
  } {
    return {
      interpretedCount: this.interpretedModules.size,
      interpretedModules: Array.from(this.interpretedModules),
      coordinationEnabled: this.coordinationEnabled,
      currentStrategy: this.currentStrategy?.name || 'none'
    };
  }

  // Private helper methods

  private async enableDebugAdapterCoordination(): Promise<void> {
    try {
      await this.debugAdapter?.sendRequest('setCoordinationMode', { enabled: true });
    } catch (error) {
      this.outputChannel.appendLine(`Failed to enable debug adapter coordination: ${error}`);
    }
  }

  private extractModuleFromUri(uri: vscode.Uri): string | undefined {
    const fileName = uri.path.split('/').pop();
    if (!fileName || !fileName.endsWith('.ex')) {
      return undefined;
    }

    const baseName = fileName.replace('.ex', '');
    // Convert snake_case to PascalCase
    const moduleName = baseName.split('_')
      .map(part => part.charAt(0).toUpperCase() + part.slice(1))
      .join('');

    return moduleName;
  }

  private getServerInstanceId(): string {
    // TODO: Get actual server instance ID
    return '1';
  }
}

/**
 * Demand-driven coordination strategy - interpret only when breakpoints are set
 */
class DemandDrivenCoordinator implements CoordinationStrategy {
  name = 'demand-driven';

  constructor(private manager: DynamicInterpretationManager) {}

  async onBreakpointSet(breakpoint: vscode.Breakpoint): Promise<void> {
    if (!(breakpoint instanceof vscode.SourceBreakpoint)) {
      return;
    }

    const module = this.extractModuleFromBreakpoint(breakpoint);
    if (!module) {
      return;
    }

    // Only analyze if not already interpreted
    if (!this.manager.getInterpretationStatus().interpretedModules.includes(module)) {
      const analysis = await this.manager.requestDependencyAnalysis(module, {
        scope: 'minimal'
      });

      if (analysis.interpretationScope.length > 0) {
        await this.manager.executeInterpretation({
          modules: analysis.interpretationScope,
          strategy: 'immediate',
          context: {
            reason: 'breakpoint',
            source: module
          }
        });
      }
    }
  }

  async onBreakpointsChanged(breakpoints: vscode.Breakpoint[]): Promise<void> {
    // Process each breakpoint individually for demand-driven approach
    for (const breakpoint of breakpoints) {
      await this.onBreakpointSet(breakpoint);
    }
  }

  async shouldReinterpret(changedFiles: string[]): Promise<boolean> {
    // Simple heuristic: reinterpret if any changed file affects interpreted modules
    const interpretedModules = this.manager.getInterpretationStatus().interpretedModules;
    
    return changedFiles.some(file => {
      const module = this.extractModuleFromFile(file);
      return module && interpretedModules.includes(module);
    });
  }

  private extractModuleFromBreakpoint(breakpoint: vscode.SourceBreakpoint): string | undefined {
    return this.extractModuleFromFile(breakpoint.location.uri.fsPath);
  }

  private extractModuleFromFile(filePath: string): string | undefined {
    const fileName = filePath.split('/').pop();
    if (!fileName || !fileName.endsWith('.ex')) {
      return undefined;
    }

    const baseName = fileName.replace('.ex', '');
    return baseName.split('_')
      .map(part => part.charAt(0).toUpperCase() + part.slice(1))
      .join('');
  }
}

/**
 * Predictive coordination strategy - anticipate likely debugging paths
 */
class PredictiveCoordinator implements CoordinationStrategy {
  name = 'predictive';

  constructor(private manager: DynamicInterpretationManager) {}

  async onBreakpointSet(breakpoint: vscode.Breakpoint): Promise<void> {
    if (!(breakpoint instanceof vscode.SourceBreakpoint)) {
      return;
    }

    const module = this.extractModuleFromBreakpoint(breakpoint);
    if (!module) {
      return;
    }

    // Analyze with conservative strategy to predict future needs
    const analysis = await this.manager.requestDependencyAnalysis(module, {
      scope: 'conservative',
      includeTransitive: true
    });

    // Interpret immediate dependencies right away
    if (analysis.interpretationScope.length > 0) {
      await this.manager.executeInterpretation({
        modules: analysis.interpretationScope,
        strategy: 'immediate',
        context: {
          reason: 'breakpoint',
          source: module
        }
      });
    }

    // Queue likely dependencies for background interpretation
    const predictions = this.predictLikelyDependencies(analysis);
    if (predictions.length > 0) {
      await this.manager.executeInterpretation({
        modules: predictions,
        strategy: 'background',
        context: {
          reason: 'prediction',
          source: module,
          priority: 1
        }
      });
    }
  }

  async onBreakpointsChanged(breakpoints: vscode.Breakpoint[]): Promise<void> {
    // Batch process for predictive approach
    const plan = await this.manager.planInterpretationScope(breakpoints);
    
    const analyses = await Promise.all(
      plan.analysisRequests.map(req => 
        this.manager.requestDependencyAnalysis(req.module, req)
      )
    );

    const allRequiredModules = this.manager.mergeDependencies(analyses);
    
    if (allRequiredModules.length > 0) {
      await this.manager.executeInterpretation({
        modules: allRequiredModules,
        strategy: 'immediate',
        context: {
          reason: 'breakpoint',
          source: 'batch_analysis'
        }
      });
    }
  }

  async shouldReinterpret(changedFiles: string[]): Promise<boolean> {
    // More aggressive reinterpretation for predictive mode
    return changedFiles.length > 0;
  }

  private predictLikelyDependencies(analysis: DependencyAnalysisResponse): string[] {
    // Use transitive dependencies as predictions
    const transitive = analysis.dependencies.transitive;
    const predictions: string[] = [];
    
    // Include first level of transitive dependencies
    if (transitive['1']) {
      predictions.push(...transitive['1']);
    }

    return predictions.slice(0, 5); // Limit predictions
  }

  private extractModuleFromBreakpoint(breakpoint: vscode.SourceBreakpoint): string | undefined {
    const fileName = breakpoint.location.uri.path.split('/').pop();
    if (!fileName || !fileName.endsWith('.ex')) {
      return undefined;
    }

    const baseName = fileName.replace('.ex', '');
    return baseName.split('_')
      .map(part => part.charAt(0).toUpperCase() + part.slice(1))
      .join('');
  }
}

/**
 * Learning coordination strategy - adapt to user debugging patterns
 */
class LearningCoordinator implements CoordinationStrategy {
  name = 'learning';
  private debuggingPatterns: Map<string, string[]> = new Map();

  constructor(private manager: DynamicInterpretationManager) {}

  async onBreakpointSet(breakpoint: vscode.Breakpoint): Promise<void> {
    // TODO: Implement learning-based coordination
    // For now, fall back to demand-driven behavior
    const demandDriven = new DemandDrivenCoordinator(this.manager);
    await demandDriven.onBreakpointSet(breakpoint);
  }

  async onBreakpointsChanged(breakpoints: vscode.Breakpoint[]): Promise<void> {
    // TODO: Implement pattern learning
    const demandDriven = new DemandDrivenCoordinator(this.manager);
    await demandDriven.onBreakpointsChanged(breakpoints);
  }

  async shouldReinterpret(changedFiles: string[]): Promise<boolean> {
    return false; // Conservative approach for learning mode
  }
}
