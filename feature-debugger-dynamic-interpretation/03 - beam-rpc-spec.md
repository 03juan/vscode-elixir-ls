# Exploratory Spec: BEAM Inter-Node RPC for Debug Dependency Coordination

## Overview

This specification explores leveraging BEAM's distributed computing capabilities to establish direct RPC communication between the language server and debug adapter nodes. This approach would enable real-time dependency data sharing without requiring VS Code extension coordination.

## Architectural Concept

Instead of routing dependency analysis requests through the VS Code extension, we establish a direct BEAM-to-BEAM communication channel:

1. **Language Server Node**: Maintains tracer data and provides dependency analysis services
2. **Debug Adapter Node**: Connects to language server node and requests dependency analysis via RPC
3. **VS Code Extension**: Manages node lifecycle but delegates dependency coordination to BEAM

## BEAM Distributed Computing Foundation

### Node Architecture

```elixir
# Language Server Node
Node.start(:"elixir_ls_language_server@127.0.0.1", :shortnames)

# Debug Adapter Node  
Node.start(:"elixir_ls_debug_adapter@127.0.0.1", :shortnames)

# Establish connection
Node.connect(:"elixir_ls_language_server@127.0.0.1")
```

### Inter-Node Service Discovery

```elixir
defmodule ElixirLS.DistributedServices do
  @moduledoc """
  Service registry for inter-node RPC communication between ElixirLS components.
  """
  
  @language_server_services [
    :dependency_analysis,
    :tracer_data_access,
    :module_information,
    :workspace_analysis
  ]
  
  @debug_adapter_services [
    :interpretation_management,
    :breakpoint_coordination,
    :process_monitoring
  ]
  
  def register_language_server_services(node_name) do
    Enum.each(@language_server_services, fn service ->
      :global.register_name({:elixir_ls, service}, self())
    end)
  end
  
  def register_debug_adapter_services(node_name) do
    Enum.each(@debug_adapter_services, fn service ->
      :global.register_name({:elixir_ls, service}, self())
    end)
  end
  
  def find_service(service_name) do
    case :global.whereis_name({:elixir_ls, service_name}) do
      :undefined -> {:error, :service_not_found}
      pid -> {:ok, pid}
    end
  end
end
```

## Language Server RPC Service Provider

### Dependency Analysis Service

```elixir
defmodule ElixirLS.LanguageServer.DistributedDependencyService do
  @moduledoc """
  Provides dependency analysis services to remote debug adapter nodes via RPC.
  """
  
  use GenServer
  alias ElixirLS.Utils.{ModuleDependencyAnalyzer, ModuleDependencyFormatter}
  alias ElixirLS.LanguageServer.Tracer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Register as dependency analysis service
    :global.register_name({:elixir_ls, :dependency_analysis}, self())
    {:ok, %{cache: %{}, tracer_state: nil}}
  end
  
  # Public RPC API - called from debug adapter
  def get_module_dependencies(module_name, opts \\ []) do
    GenServer.call({:global, {:elixir_ls, :dependency_analysis}}, 
                   {:get_module_dependencies, module_name, opts})
  end
  
  def get_breakpoint_dependencies(file_path, line, opts \\ []) do
    GenServer.call({:global, {:elixir_ls, :dependency_analysis}}, 
                   {:get_breakpoint_dependencies, file_path, line, opts})
  end
  
  def get_cached_dependency_graph() do
    GenServer.call({:global, {:elixir_ls, :dependency_analysis}}, 
                   :get_cached_dependency_graph)
  end
  
  # GenServer callbacks
  def handle_call({:get_module_dependencies, module_name, opts}, _from, state) do
    strategy = Keyword.get(opts, :strategy, :minimal)
    
    result = case get_cached_result(module_name, strategy, state) do
      {:hit, cached_result} -> 
        cached_result
      :miss -> 
        trace_data = get_current_trace_data()
        analyze_and_cache_dependencies(module_name, strategy, trace_data, state)
    end
    
    {:reply, result, state}
  end
  
  def handle_call({:get_breakpoint_dependencies, file_path, line, opts}, _from, state) do
    # Convert file path to module name
    module_name = file_path_to_module(file_path)
    
    # Get dependencies for the specific module
    deps = get_module_dependencies(module_name, opts)
    
    # Filter to minimal set needed for breakpoint
    breakpoint_deps = filter_for_breakpoint_context(deps, file_path, line)
    
    {:reply, breakpoint_deps, state}
  end
  
  def handle_call(:get_cached_dependency_graph, _from, state) do
    graph = build_complete_dependency_graph(state.cache)
    {:reply, graph, state}
  end
  
  defp get_current_trace_data() do
    # Access current tracer state from language server
    Tracer.get_trace()
  end
  
  defp analyze_and_cache_dependencies(module_name, strategy, trace_data, state) do
    case strategy do
      :minimal -> 
        ModuleDependencyAnalyzer.get_direct_dependencies(module_name, trace_data)
      :conservative -> 
        get_conservative_dependencies(module_name, trace_data)
      :transitive -> 
        ModuleDependencyAnalyzer.get_transitive_dependencies(module_name, trace_data, 2)
    end
  end
  
  defp get_conservative_dependencies(module_name, trace_data) do
    direct = ModuleDependencyAnalyzer.get_direct_dependencies(module_name, trace_data)
    reverse = ModuleDependencyAnalyzer.get_reverse_dependencies(module_name, trace_data)
    
    %{
      target_module: module_name,
      direct_dependencies: direct,
      reverse_dependencies: reverse,
      interpretation_candidates: direct ++ reverse |> Enum.uniq()
    }
  end
end
```

### Tracer Data Streaming Service

```elixir
defmodule ElixirLS.LanguageServer.TracerStreamService do
  @moduledoc """
  Streams incremental tracer updates to debug adapter for real-time dependency tracking.
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    :global.register_name({:elixir_ls, :tracer_data_access}, self())
    {:ok, %{subscribers: [], last_trace_version: 0}}
  end
  
  # Subscribe to tracer updates
  def subscribe_to_tracer_updates(subscriber_pid) do
    GenServer.call({:global, {:elixir_ls, :tracer_data_access}}, 
                   {:subscribe, subscriber_pid})
  end
  
  def handle_call({:subscribe, subscriber_pid}, _from, state) do
    # Monitor subscriber to clean up on disconnect
    Process.monitor(subscriber_pid)
    updated_state = %{state | subscribers: [subscriber_pid | state.subscribers]}
    
    # Send initial trace data
    initial_trace = get_current_trace_data()
    send(subscriber_pid, {:tracer_update, :initial, initial_trace})
    
    {:reply, :ok, updated_state}
  end
  
  def handle_info({:tracer_updated, new_trace_data}, state) do
    # Broadcast tracer updates to all subscribers
    Enum.each(state.subscribers, fn subscriber ->
      send(subscriber, {:tracer_update, :incremental, new_trace_data})
    end)
    
    {:noreply, %{state | last_trace_version: state.last_trace_version + 1}}
  end
  
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Clean up disconnected subscribers
    updated_subscribers = List.delete(state.subscribers, pid)
    {:noreply, %{state | subscribers: updated_subscribers}}
  end
end
```

## Debug Adapter RPC Client

### Distributed Interpretation Manager

```elixir
defmodule ElixirLS.DebugAdapter.DistributedJitInterpreter do
  @moduledoc """
  JIT interpreter that coordinates with language server via BEAM RPC for dependency analysis.
  """
  
  use GenServer
  alias ElixirLS.LanguageServer.DistributedDependencyService
  
  defstruct [
    :interpreted_modules,
    :pending_interpretations,
    :dependency_cache,
    :language_server_node,
    :tracer_subscription
  ]
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    language_server_node = Keyword.get(opts, :language_server_node)
    
    # Connect to language server node
    case Node.connect(language_server_node) do
      true -> 
        # Subscribe to tracer updates
        :ok = ElixirLS.LanguageServer.TracerStreamService.subscribe_to_tracer_updates(self())
        
        {:ok, %__MODULE__{
          interpreted_modules: MapSet.new(),
          pending_interpretations: [],
          dependency_cache: %{},
          language_server_node: language_server_node,
          tracer_subscription: true
        }}
      
      false -> 
        {:stop, {:connection_failed, language_server_node}}
    end
  end
  
  # Public API for breakpoint-driven interpretation
  def interpret_for_breakpoint(file_path, line, interpretation_patterns) do
    GenServer.call(__MODULE__, 
                   {:interpret_for_breakpoint, file_path, line, interpretation_patterns})
  end
  
  def get_interpretation_status() do
    GenServer.call(__MODULE__, :get_interpretation_status)
  end
  
  # GenServer callbacks
  def handle_call({:interpret_for_breakpoint, file_path, line, patterns}, _from, state) do
    # Request dependency analysis from language server via RPC
    case DistributedDependencyService.get_breakpoint_dependencies(file_path, line, 
                                                                  strategy: :conservative) do
      {:ok, dependencies} ->
        # Filter dependencies by interpretation patterns
        filtered_deps = filter_dependencies_by_patterns(dependencies, patterns)
        
        # Interpret only new modules
        new_modules = filtered_deps -- MapSet.to_list(state.interpreted_modules)
        interpretation_results = interpret_modules(new_modules)
        
        # Update state
        updated_interpreted = MapSet.union(state.interpreted_modules, 
                                          MapSet.new(new_modules))
        updated_state = %{state | interpreted_modules: updated_interpreted}
        
        {:reply, {:ok, interpretation_results}, updated_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call(:get_interpretation_status, _from, state) do
    status = %{
      interpreted_count: MapSet.size(state.interpreted_modules),
      interpreted_modules: MapSet.to_list(state.interpreted_modules),
      language_server_connected: Node.ping(state.language_server_node) == :pong,
      cache_size: map_size(state.dependency_cache)
    }
    
    {:reply, status, state}
  end
  
  # Handle tracer updates from language server
  def handle_info({:tracer_update, :initial, trace_data}, state) do
    # Cache initial trace data for offline analysis
    updated_cache = cache_trace_data(trace_data, state.dependency_cache)
    {:noreply, %{state | dependency_cache: updated_cache}}
  end
  
  def handle_info({:tracer_update, :incremental, trace_diff}, state) do
    # Apply incremental tracer changes to cache
    updated_cache = apply_trace_diff(trace_diff, state.dependency_cache)
    
    # Invalidate affected dependency analysis cache entries
    invalidated_cache = invalidate_affected_dependencies(trace_diff, updated_cache)
    
    {:noreply, %{state | dependency_cache: invalidated_cache}}
  end
  
  defp interpret_modules(modules) do
    Enum.map(modules, fn module ->
      case :int.i(module) do
        {:module, ^module} -> {:ok, module}
        error -> {:error, module, error}
      end
    end)
  end
  
  defp filter_dependencies_by_patterns(dependencies, patterns) do
    regex_patterns = Enum.map(patterns, &Regex.compile!/1)
    
    dependencies.interpretation_candidates
    |> Enum.filter(fn module ->
      module_string = to_string(module)
      Enum.any?(regex_patterns, &Regex.match?(&1, module_string))
    end)
  end
end
```

### RPC-Based Breakpoint Coordinator

```elixir
defmodule ElixirLS.DebugAdapter.DistributedBreakpointCoordinator do
  @moduledoc """
  Coordinates breakpoint setting with dependency analysis via RPC to language server.
  """
  
  use GenServer
  alias ElixirLS.DebugAdapter.DistributedJitInterpreter
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    :global.register_name({:elixir_ls, :breakpoint_coordination}, self())
    {:ok, %{active_breakpoints: %{}, interpretation_queue: []}}
  end
  
  # DAP protocol handler - enhanced with RPC coordination
  def handle_set_breakpoints_request(source, breakpoints, interpretation_patterns) do
    GenServer.call(__MODULE__, 
                   {:set_breakpoints, source, breakpoints, interpretation_patterns})
  end
  
  def handle_call({:set_breakpoints, source, breakpoints, patterns}, _from, state) do
    file_path = source["path"]
    
    # For each breakpoint, coordinate interpretation via RPC
    coordination_results = 
      Enum.map(breakpoints, fn bp ->
        line = bp["line"]
        
        # Request interpretation via distributed JIT interpreter
        case DistributedJitInterpreter.interpret_for_breakpoint(file_path, line, patterns) do
          {:ok, interpretation_result} ->
            # Set breakpoint after interpretation
            module = file_path_to_module(file_path)
            case :int.break(module, line) do
              :ok -> {:ok, bp, interpretation_result}
              error -> {:error, bp, error}
            end
          
          {:error, reason} ->
            {:error, bp, reason}
        end
      end)
    
    # Update breakpoint registry
    updated_breakpoints = Map.put(state.active_breakpoints, file_path, breakpoints)
    updated_state = %{state | active_breakpoints: updated_breakpoints}
    
    {:reply, {:ok, coordination_results}, updated_state}
  end
  
  defp file_path_to_module(file_path) do
    # Convert file path to Elixir module name
    # This would need proper implementation based on project structure
    file_path
    |> Path.basename(".ex")
    |> Macro.camelize()
    |> String.to_atom()
  end
end
```

## Node Lifecycle Management

### VS Code Extension Node Coordinator

```typescript
// Enhanced debug adapter manager with BEAM node coordination
class DistributedElixirDebugAdapter {
  private languageServerNode: string;
  private debugAdapterNode: string;
  private nodeConnectionStatus: Map<string, boolean> = new Map();
  
  async initializeDistributedDebugging(config: DebugConfiguration) {
    // Generate unique node names for this debug session
    const sessionId = generateSessionId();
    this.languageServerNode = `elixir_ls_language_server_${sessionId}@127.0.0.1`;
    this.debugAdapterNode = `elixir_ls_debug_adapter_${sessionId}@127.0.0.1`;
    
    // Start language server with distributed node
    await this.startLanguageServerNode(config);
    
    // Start debug adapter with distributed node
    await this.startDebugAdapterNode(config);
    
    // Verify inter-node connectivity
    await this.verifyNodeConnectivity();
  }
  
  private async startLanguageServerNode(config: DebugConfiguration) {
    const env = {
      ...process.env,
      ELIXIR_LS_NODE_NAME: this.languageServerNode,
      ELIXIR_LS_DISTRIBUTED_MODE: 'true',
      ELIXIR_LS_COOKIE: generateErlangCookie()
    };
    
    // Launch language server with node configuration
    await this.spawnLanguageServerProcess(env);
  }
  
  private async startDebugAdapterNode(config: DebugConfiguration) {
    const env = {
      ...process.env,
      ELIXIR_LS_NODE_NAME: this.debugAdapterNode,
      ELIXIR_LS_LANGUAGE_SERVER_NODE: this.languageServerNode,
      ELIXIR_LS_DISTRIBUTED_MODE: 'true',
      ELIXIR_LS_COOKIE: generateErlangCookie()
    };
    
    // Launch debug adapter with node configuration
    await this.spawnDebugAdapterProcess(env);
  }
  
  private async verifyNodeConnectivity(): Promise<boolean> {
    // Send RPC test message to verify connectivity
    try {
      const result = await this.sendTestRPC();
      return result.success;
    } catch (error) {
      console.error('BEAM node connectivity failed:', error);
      return false;
    }
  }
  
  async cleanupDistributedSession() {
    // Gracefully disconnect nodes
    await this.disconnectNodes();
    
    // Cleanup node processes
    await this.terminateNodeProcesses();
  }
}
```

### Elixir Launch Script Enhancement

```bash
#!/bin/bash
# Enhanced language_server.sh with distributed node support

if [ "$ELIXIR_LS_DISTRIBUTED_MODE" = "true" ]; then
  # Start with distributed node name
  exec elixir \
    --name "$ELIXIR_LS_NODE_NAME" \
    --cookie "$ELIXIR_LS_COOKIE" \
    --no-halt \
    -S mix run --no-compile --no-deps-check --no-archives-check \
    -e "ElixirLS.LanguageServer.CLI.main()"
else
  # Standard single-node mode
  exec elixir \
    --no-halt \
    -S mix run --no-compile --no-deps-check --no-archives-check \
    -e "ElixirLS.LanguageServer.CLI.main()"
fi
```

## Benefits of BEAM RPC Approach

### 1. Native Distributed Computing

- **Built-in reliability**: BEAM provides robust node connectivity and fault tolerance
- **Efficient serialization**: Erlang term format optimized for inter-node communication
- **Transparent location**: RPC calls appear as local function calls

### 2. Real-Time Data Sharing

- **Live tracer updates**: Debug adapter receives incremental tracer changes
- **Reduced latency**: Direct node-to-node communication eliminates VS Code routing
- **Bidirectional communication**: Both nodes can initiate RPC calls as needed

### 3. Advanced Coordination Patterns

- **Service discovery**: Global process registry enables dynamic service location
- **Load balancing**: Multiple debug adapters could connect to single language server
- **Fault tolerance**: Node monitoring and automatic reconnection

### 4. Performance Optimization

- **Caching at both ends**: Each node can cache relevant data locally
- **Streaming updates**: Incremental tracer updates rather than full dumps
- **Parallel processing**: Multiple RPC calls can execute concurrently

## Technical Challenges & Solutions

### Challenge 1: Node Security and Isolation

**Problem:** BEAM nodes share full access - security implications
**Solution:**

- Use unique, temporary cookies per debug session
- Restrict RPC to specific registered services
- Network isolation (localhost-only connections)

### Challenge 2: Node Lifecycle Management

**Problem:** Coordinating node startup, connectivity, and cleanup
**Solution:**

- VS Code extension manages node lifecycle
- Health checking and automatic reconnection
- Graceful shutdown procedures

### Challenge 3: Debugging the Debugger

**Problem:** RPC issues could break debugging functionality
**Solution:**

- Fallback to VS Code coordination mode
- Extensive logging and monitoring
- RPC timeout handling and retries

### Challenge 4: Version Compatibility

**Problem:** Language server and debug adapter may have different ElixirLS versions
**Solution:**

- Version negotiation during initial RPC handshake
- Backwards-compatible RPC protocol design
- Clear error messages for version mismatches

## Configuration and Setup

### Debug Configuration Enhancement

```json
{
  "type": "mix_task",
  "name": "debug with BEAM RPC",
  "request": "launch",
  "task": "phx.server",
  "debugAutoInterpretAllModules": false,
  "coordinationMode": "beam-rpc",
  "distributedDebugging": {
    "enabled": true,
    "nodeNaming": "shortnames",
    "rpcTimeout": 5000,
    "enableTracerStreaming": true,
    "dependencyCacheSize": 1000,
    "fallbackToExtensionCoordination": true
  },
  "interpretationPatterns": ["MyApp.*", "MyAppWeb.*"]
}
```

### Elixir Application Configuration

```elixir
# config/config.exs
config :elixir_ls_utils,
  distributed_mode: System.get_env("ELIXIR_LS_DISTRIBUTED_MODE") == "true",
  node_name: System.get_env("ELIXIR_LS_NODE_NAME"),
  language_server_node: System.get_env("ELIXIR_LS_LANGUAGE_SERVER_NODE")

config :kernel,
  distributed: [
    {:"elixir_ls_cluster", [:"elixir_ls_language_server@127.0.0.1", 
                           :"elixir_ls_debug_adapter@127.0.0.1"]}
  ]
```

## Implementation Phases

### Phase 1: Basic RPC Infrastructure (3-4 weeks)

- Node connectivity and service registration
- Basic dependency analysis RPC service
- Simple debug adapter RPC client
- Node lifecycle management in VS Code extension

### Phase 2: Advanced Coordination (3-4 weeks)

- Tracer data streaming service
- Distributed JIT interpretation manager
- RPC-based breakpoint coordination
- Caching and performance optimization

### Phase 3: Production Hardening (2-3 weeks)

- Error handling and fallback mechanisms
- Security enhancements and isolation
- Comprehensive testing across node failure scenarios
- Performance monitoring and tuning

### Phase 4: Feature Enhancement (2-3 weeks)

- Advanced debugging features leveraging RPC
- Integration with existing ElixirLS capabilities
- Documentation and user guides
- Migration tools from existing coordination approaches

## Success Metrics

- **RPC Latency**: < 50ms for dependency analysis requests
- **Node Connectivity**: 99.9% uptime during debugging sessions
- **Memory Efficiency**: < 10MB overhead per additional node
- **Developer Experience**: Transparent operation - users unaware of RPC complexity

## Comparison with Other Approaches

| Aspect | BEAM RPC | IDE Coordination | Direct Integration |
|--------|----------|------------------|-------------------|
| **Complexity** | High (distributed systems) | Medium (protocol coordination) | Low (monolithic) |
| **Performance** | Excellent (native RPC) | Good (JSON-RPC overhead) | Excellent (direct calls) |
| **Scalability** | Excellent (multiple nodes) | Limited (single coordinator) | Poor (tight coupling) |
| **Fault Tolerance** | Excellent (BEAM supervision) | Good (process isolation) | Poor (single point failure) |
| **Development Overhead** | High (distributed debugging) | Medium (protocol design) | Low (single codebase) |

The BEAM RPC approach represents the most sophisticated and scalable solution, though it comes with the highest implementation complexity. It leverages BEAM's native distributed computing strengths while providing a foundation for advanced debugging features that would be difficult to achieve with other coordination approaches.
