# Feature Spec: IDE Extension Coordination for Dynamic Debug Interpretation

## Overview

This specification describes an alternative architecture where the VS Code extension acts as the coordination point between the language server and debug adapter for dynamic module interpretation during debugging sessions.

## Architecture Concept

Instead of the debug adapter directly analyzing dependencies and managing interpretation, the VS Code extension orchestrates the workflow:

1. **Language Server**: Provides dependency analysis capabilities via LLM tools
2. **Debug Adapter**: Focuses purely on interpretation and breakpoint management
3. **VS Code Extension**: Coordinates between both, making intelligent decisions about what to interpret

## User Workflow

### Enhanced Debug Session with IDE Coordination

```json
{
  "type": "mix_task",
  "name": "debug phoenix with coordination",
  "request": "launch", 
  "task": "phx.server",
  "debugAutoInterpretAllModules": false,
  "debugInterpretModulesPatterns": ["MyApp.*", "MyAppWeb.*"],
  "enableDynamicInterpretation": true,
  "interpretationStrategy": "ide-coordinated"
}
```

**Coordinated User Journey:**

1. Start debug session → VS Code extension stores patterns, debug adapter starts app with **no interpretation**
2. User sets breakpoint in `MyAppWeb.UserController.show/2`
3. **VS Code extension** detects breakpoint, requests dependency analysis from **language server**
4. Language server analyzes `MyAppWeb.UserController` dependencies using existing LLM tools
5. **VS Code extension** sends focused interpretation request to **debug adapter**
6. Debug adapter interprets only the minimal required modules
7. Navigate to `/users/123` → hits breakpoint with optimal performance

## Component Architecture

### VS Code Extension Enhancements (`src/debugAdapter.ts`)

```typescript
interface DynamicInterpretationManager {
  // Coordinate between language server and debug adapter
  requestDependencyAnalysis(module: string, context: AnalysisContext): Promise<DependencyResult>;
  planInterpretationScope(breakpoints: Breakpoint[]): Promise<InterpretationPlan>;
  executeInterpretation(plan: InterpretationPlan): Promise<void>;
  
  // State management
  trackInterpretedModules(modules: string[]): void;
  shouldReinterpret(changedFiles: string[]): Promise<boolean>;
}

class ElixirDebugAdapterManager {
  private languageClient: LanguageClient;
  private debugAdapter: DebugAdapterProcess;
  private interpretationManager: DynamicInterpretationManager;
  
  async onBreakpointsChanged(breakpoints: Breakpoint[]) {
    // 1. Analyze what modules need interpretation
    const plan = await this.interpretationManager.planInterpretationScope(breakpoints);
    
    // 2. Request language server analysis for each module
    const dependencies = await Promise.all(
      plan.targetModules.map(module => 
        this.interpretationManager.requestDependencyAnalysis(module, plan.context)
      )
    );
    
    // 3. Build minimal interpretation set
    const allRequiredModules = this.mergeDependencies(dependencies);
    
    // 4. Request debug adapter to interpret only necessary modules
    await this.debugAdapter.interpretModules(allRequiredModules);
    
    // 5. Set breakpoints after interpretation
    await this.debugAdapter.setBreakpoints(breakpoints);
  }
  
  private mergeDependencies(dependencies: DependencyResult[]): string[] {
    // Intelligent merging - avoid duplicate interpretations
    // Consider transitive dependencies
    // Apply exclusion patterns
  }
}
```

### Language Server Integration

Extend existing LLM module dependencies command to support debug-focused analysis:

```elixir
defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.DebugDependencyAnalysis do
  @moduledoc """
  Specialized dependency analysis for debug session coordination.
  Extends LlmModuleDependencies with debug-specific filtering and optimization.
  """
  
  alias ElixirLS.Utils.ModuleDependencyAnalyzer
  alias ElixirLS.Utils.ModuleDependencyFormatter
  
  def execute([module_name, opts], state) do
    context = Map.get(opts, "context", %{})
    strategy = Map.get(opts, "strategy", "minimal")
    
    trace = get_trace_data(state)
    
    case strategy do
      "minimal" -> 
        get_minimal_debug_scope(module_name, trace, context)
      "conservative" -> 
        get_conservative_debug_scope(module_name, trace, context)
      "transitive" -> 
        get_transitive_debug_scope(module_name, trace, context)
    end
  end
  
  defp get_minimal_debug_scope(module_name, trace, context) do
    # Direct dependencies only
    direct_deps = ModuleDependencyAnalyzer.get_direct_dependencies(module_name, trace)
    
    # Filter by interpretation patterns from debug config
    patterns = Map.get(context, "interpretationPatterns", [])
    filtered_deps = filter_by_patterns(direct_deps, patterns)
    
    format_debug_response(module_name, filtered_deps, "minimal")
  end
  
  defp get_conservative_debug_scope(module_name, trace, context) do
    # Include modules that might be called during debugging
    direct_deps = ModuleDependencyAnalyzer.get_direct_dependencies(module_name, trace)
    reverse_deps = ModuleDependencyAnalyzer.get_reverse_dependencies(module_name, trace)
    
    # Combine and filter
    all_deps = (direct_deps ++ reverse_deps) |> Enum.uniq()
    patterns = Map.get(context, "interpretationPatterns", [])
    filtered_deps = filter_by_patterns(all_deps, patterns)
    
    format_debug_response(module_name, filtered_deps, "conservative")
  end
  
  defp format_debug_response(target_module, dependencies, strategy) do
    %{
      "targetModule" => target_module,
      "strategy" => strategy,
      "requiredModules" => dependencies,
      "estimatedInterpretationTime" => estimate_interpretation_time(dependencies),
      "debugOptimizations" => generate_debug_optimizations(dependencies)
    }
  end
end
```

### Debug Adapter Enhancements

Simplify debug adapter to focus on interpretation execution rather than dependency analysis:

```elixir
defmodule DebugAdapter.CoordinatedInterpreter do
  @moduledoc """
  Handles interpretation requests from VS Code extension coordinator.
  Focuses on efficient execution rather than dependency analysis.
  """
  
  defstruct [
    :interpreted_modules,
    :interpretation_queue,
    :breakpoint_registry
  ]
  
  def interpret_modules(modules, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :immediate)
    
    case strategy do
      :immediate -> interpret_immediately(modules)
      :queued -> queue_for_interpretation(modules)
      :background -> interpret_in_background(modules)
    end
  end
  
  defp interpret_immediately(modules) do
    results = 
      modules
      |> Enum.reject(&already_interpreted?/1)
      |> Enum.map(&interpret_single_module/1)
    
    success_modules = 
      results
      |> Enum.filter(fn {status, _} -> status == :ok end)
      |> Enum.map(fn {_, module} -> module end)
    
    update_interpreted_modules(success_modules)
    
    {:ok, %{
      interpreted: success_modules,
      failed: extract_failures(results),
      total_time: calculate_interpretation_time(results)
    }}
  end
  
  def set_coordinated_breakpoints(breakpoints_with_modules) do
    # Breakpoints are pre-validated by coordinator
    # Modules are already interpreted
    # Just set the breakpoints efficiently
    
    results = 
      Enum.map(breakpoints_with_modules, fn {breakpoint, modules} ->
        case ensure_modules_interpreted(modules) do
          :ok -> set_breakpoint(breakpoint)
          error -> error
        end
      end)
    
    {:ok, summarize_breakpoint_results(results)}
  end
end
```

## Coordination Protocol

### Extension ↔ Language Server Communication

```typescript
// New LSP commands for debug coordination
interface DebugDependencyAnalysisRequest {
  command: "elixirLS.debugDependencyAnalysis";
  arguments: [
    string,  // module name
    {
      context: {
        interpretationPatterns: string[];
        excludePatterns: string[];
        currentBreakpoints: Breakpoint[];
      };
      strategy: "minimal" | "conservative" | "transitive";
    }
  ];
}

interface DebugDependencyAnalysisResponse {
  targetModule: string;
  strategy: string;
  requiredModules: string[];
  estimatedInterpretationTime: number;
  debugOptimizations: {
    canSkip: string[];
    mustInclude: string[];
    suggestions: string[];
  };
}
```

### Extension ↔ Debug Adapter Communication

```typescript
// Enhanced DAP protocol for coordinated interpretation
interface CoordinatedInterpretRequest extends DAP.Request {
  command: "coordinatedInterpret";
  arguments: {
    modules: string[];
    strategy: "immediate" | "queued" | "background";
    context: {
      reason: "breakpoint" | "reload" | "expansion";
      source: string;  // which component requested this
    };
  };
}

interface CoordinatedInterpretResponse extends DAP.Response {
  body: {
    interpreted: string[];
    failed: Array<{module: string; error: string}>;
    totalTime: number;
    nextRecommendations: string[];
  };
}
```

## Smart Coordination Strategies

### Strategy 1: Demand-Driven Interpretation

```typescript
class DemandDrivenCoordinator {
  async onBreakpointSet(breakpoint: Breakpoint) {
    const module = this.getModuleFromBreakpoint(breakpoint);
    
    // Only analyze if not already interpreted
    if (!this.isModuleInterpreted(module)) {
      const analysis = await this.requestMinimalDependencyAnalysis(module);
      await this.interpretModulesIfNeeded(analysis.requiredModules);
    }
    
    await this.setBreakpoint(breakpoint);
  }
  
  private async interpretModulesIfNeeded(modules: string[]) {
    const uninterpreted = modules.filter(m => !this.isModuleInterpreted(m));
    
    if (uninterpreted.length > 0) {
      await this.debugAdapter.interpretModules(uninterpreted, {strategy: "immediate"});
      this.trackInterpretedModules(uninterpreted);
    }
  }
}
```

### Strategy 2: Predictive Interpretation

```typescript
class PredictiveCoordinator {
  async onBreakpointSet(breakpoint: Breakpoint) {
    const module = this.getModuleFromBreakpoint(breakpoint);
    
    // Analyze with conservative strategy to predict future needs
    const analysis = await this.requestDependencyAnalysis(module, "conservative");
    
    // Interpret immediate dependencies right away
    await this.interpretModulesIfNeeded(analysis.requiredModules);
    
    // Queue likely dependencies for background interpretation
    const predictions = this.predictLikelyDependencies(analysis);
    this.queueBackgroundInterpretation(predictions);
    
    await this.setBreakpoint(breakpoint);
  }
  
  private predictLikelyDependencies(analysis: DependencyAnalysisResponse): string[] {
    // Use heuristics to predict what user might debug next
    // Consider reverse dependencies, common patterns, etc.
  }
}
```

### Strategy 3: Session Learning

```typescript
class LearningCoordinator {
  private debuggingPatterns: Map<string, DebugPattern> = new Map();
  
  async onBreakpointSet(breakpoint: Breakpoint) {
    const module = this.getModuleFromBreakpoint(breakpoint);
    
    // Learn from previous debugging sessions
    const pattern = this.debuggingPatterns.get(module);
    
    if (pattern) {
      // Use learned patterns to interpret likely dependencies
      await this.interpretBasedOnPattern(module, pattern);
    } else {
      // Fall back to minimal strategy and start learning
      await this.interpretMinimalAndLearn(module, breakpoint);
    }
  }
  
  onDebuggingPathTraversed(path: string[]) {
    // Learn which modules are commonly debugged together
    this.updateDebuggingPatterns(path);
  }
}
```

## Configuration Options

### VS Code Settings

```json
{
  "elixirLS.debugCoordination.enabled": true,
  "elixirLS.debugCoordination.strategy": "demand-driven",
  "elixirLS.debugCoordination.interpretationStrategy": "minimal",
  "elixirLS.debugCoordination.enableLearning": true,
  "elixirLS.debugCoordination.backgroundInterpretation": true,
  "elixirLS.debugCoordination.maxConcurrentAnalysis": 3,
  "elixirLS.debugCoordination.cacheAnalysisResults": true
}
```

### Launch Configuration

```json
{
  "type": "mix_task",
  "name": "debug with coordination",
  "request": "launch",
  "task": "phx.server",
  "debugAutoInterpretAllModules": false,
  "coordination": {
    "enabled": true,
    "strategy": "predictive",
    "interpretationPatterns": ["MyApp.*", "MyAppWeb.*"],
    "excludePatterns": [":cowboy.*", ":ecto.*"],
    "learningEnabled": true,
    "backgroundInterpretation": {
      "enabled": true,
      "maxConcurrent": 2,
      "timeLimit": 5000
    }
  }
}
```

## Benefits of IDE Coordination Approach

### 1. Separation of Concerns

- **Language Server**: Focus on code analysis and language intelligence
- **Debug Adapter**: Focus on interpretation execution and process management  
- **VS Code Extension**: Focus on user experience and coordination logic

### 2. Leveraging Existing Infrastructure

- Reuses existing LLM module dependency tools
- Builds on established LSP/DAP protocols
- Maintains compatibility with current debugging features

### 3. Enhanced User Experience

- Intelligent interpretation decisions based on user behavior
- Learning from debugging patterns over time
- Configurable strategies for different development styles

### 4. Performance Optimization

- Minimal interpretation overhead at startup
- JIT interpretation based on actual debugging needs
- Background interpretation of predicted dependencies

### 5. Extensibility

- Easy to add new coordination strategies
- Can integrate with other VS Code debugging features
- Framework for future debugging enhancements

## Implementation Phases

### Phase 1: Foundation (2-3 weeks)

- Extend existing LLM dependency command for debug analysis
- Create basic coordination manager in VS Code extension
- Implement demand-driven interpretation strategy
- Basic integration tests

### Phase 2: Enhanced Strategies (2-3 weeks)  

- Implement predictive coordination strategy
- Add background interpretation capabilities
- Enhanced configuration options
- Performance monitoring and metrics

### Phase 3: Learning & Optimization (3-4 weeks)

- Session learning and pattern recognition
- Advanced debugging optimizations
- Integration with VS Code debugging UI enhancements
- Comprehensive testing across different project types

### Phase 4: Polish & Documentation (1-2 weeks)

- User documentation and tutorials
- Performance benchmarking
- Integration with existing ElixirLS features
- Migration guide for existing debug configurations

## Success Metrics

- **Startup Performance**: Debug session startup time < 2 seconds (vs. 3-8 seconds with pre-interpretation)
- **Memory Efficiency**: 50-70% reduction in interpreted module count for typical debugging sessions
- **User Experience**: Seamless breakpoint setting with < 500ms interpretation delay
- **Learning Effectiveness**: 80% accuracy in predicting next debugging targets after 5 debugging sessions

This IDE coordination approach provides a clean architectural separation while leveraging the existing ElixirLS infrastructure to deliver optimal debugging performance and user experience.
