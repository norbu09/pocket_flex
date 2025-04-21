# PocketFlex Implementation Specification

## 1. Overview

PocketFlex is an Elixir implementation of the PocketFlow agent framework. It provides a flexible system for creating flows of connected nodes, where each node performs a specific task and passes data to the next node. This implementation leverages Elixir's strengths in functional programming, pattern matching, and concurrency.

## 2. Core Concepts

### 2.1 Nodes

Nodes are the basic building blocks of PocketFlex. Each node:
- Takes input data
- Processes that data
- Outputs results
- Determines the next node to execute

### 2.2 Flows

Flows manage the execution of connected nodes. A flow:
- Maintains a graph of node connections
- Executes nodes in sequence
- Passes data between nodes
- Handles flow control based on node outputs

### 2.3 Shared State

Data is passed between nodes using a shared state map. Each node can:
- Read data from the shared state
- Process that data
- Update the shared state with new data

### 2.4 Execution Model

PocketFlex supports multiple execution models:
- **Synchronous**: Nodes execute sequentially in a single process
- **Asynchronous**: Nodes execute asynchronously using Elixir processes
- **Batch**: Process lists of items, either sequentially or in parallel

## 3. Module Specifications

### 3.1 `PocketFlex.Node`

```elixir
defmodule PocketFlex.Node do
  @moduledoc """
  Behavior module defining the interface for PocketFlex nodes.
  
  A node is a processing unit that can:
  - Prepare data from the shared state (prep)
  - Execute some logic on that data (exec)
  - Post-process the results and update the shared state (post)
  
  Nodes can be connected to form a flow, with each node determining
  which node should execute next based on its output.
  """
  
  @doc """
  Prepares data from the shared state for execution.
  
  ## Parameters
    - shared: A map containing the shared state
    
  ## Returns
    Any data needed for the exec function
  """
  @callback prep(shared :: map()) :: any()
  
  @doc """
  Executes the node's main logic.
  
  ## Parameters
    - prep_result: The result from the prep function
    
  ## Returns
    The result of the execution
  """
  @callback exec(prep_result :: any()) :: any()
  
  @doc """
  Post-processes the execution result and updates the shared state.
  
  ## Parameters
    - shared: The shared state map
    - prep_result: The result from the prep function
    - exec_result: The result from the exec function
    
  ## Returns
    A tuple containing:
    - The action key for the next node (or nil to end the flow)
    - The updated shared state map
  """
  @callback post(shared :: map(), prep_result :: any(), exec_result :: any()) :: {String.t() | nil, map()}
  
  @doc """
  Handles exceptions during execution.
  
  ## Parameters
    - prep_result: The result from the prep function
    - exception: The exception that was raised
    
  ## Returns
    A fallback result to use instead of the failed execution
  """
  @callback exec_fallback(prep_result :: any(), exception :: Exception.t()) :: any()
  
  @doc """
  Returns the maximum number of retry attempts for the exec function.
  
  ## Returns
    A non-negative integer
  """
  @callback max_retries() :: non_neg_integer()
  
  @doc """
  Returns the wait time in milliseconds between retry attempts.
  
  ## Returns
    A non-negative integer
  """
  @callback wait_time() :: non_neg_integer()
  
  @optional_callbacks [exec_fallback: 2, max_retries: 0, wait_time: 0]
end
```

### 3.2 `PocketFlex.NodeMacros`

```elixir
defmodule PocketFlex.NodeMacros do
  @moduledoc """
  Provides macros for simplifying node implementation.
  
  This module allows developers to create nodes with minimal boilerplate
  by providing default implementations for optional callbacks.
  """
  
  defmacro __using__(opts) do
    quote do
      @behaviour PocketFlex.Node
      
      # Default implementations
      @impl true
      def prep(_shared), do: nil
      
      @impl true
      def post(shared, _prep_res, exec_res), do: {"default", shared}
      
      @impl true
      def exec_fallback(_prep_res, exception), do: raise(exception)
      
      @impl true
      def max_retries(), do: unquote(Keyword.get(opts, :max_retries, 1))
      
      @impl true
      def wait_time(), do: unquote(Keyword.get(opts, :wait_time, 0))
      
      # Allow overriding any of these defaults
      defoverridable prep: 1, post: 3, exec_fallback: 2, max_retries: 0, wait_time: 0
    end
  end
end
```

### 3.3 `PocketFlex.Flow`

```elixir
defmodule PocketFlex.Flow do
  @moduledoc """
  Manages the execution of connected nodes.
  
  A flow maintains a graph of connected nodes and handles the execution
  of those nodes in sequence, passing data between them using a shared state.
  """
  
  defstruct [:start_node, :nodes, :connections, :params]
  
  @type t :: %__MODULE__{
    start_node: module(),
    nodes: %{optional(module()) => struct()},
    connections: %{optional(module()) => %{optional(String.t()) => module()}},
    params: map()
  }
  
  @doc """
  Creates a new flow.
  
  ## Returns
    A new flow struct
  """
  @spec new() :: t()
  
  @doc """
  Adds a node to the flow.
  
  ## Parameters
    - flow: The flow to add the node to
    - node: The node module to add
    
  ## Returns
    The updated flow
  """
  @spec add_node(t(), module()) :: t()
  
  @doc """
  Connects two nodes in the flow.
  
  ## Parameters
    - flow: The flow to update
    - from: The source node module
    - to: The target node module
    - action: The action key for this connection (default: "default")
    
  ## Returns
    The updated flow
  """
  @spec connect(t(), module(), module(), String.t()) :: t()
  
  @doc """
  Sets the starting node for the flow.
  
  ## Parameters
    - flow: The flow to update
    - node: The node module to set as the start node
    
  ## Returns
    The updated flow
  """
  @spec start(t(), module()) :: t()
  
  @doc """
  Runs the flow with the given shared state.
  
  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok or :error
    - The final shared state or an error reason
  """
  @spec run(t(), map()) :: {:ok, map()} | {:error, term()}
end
```

### 3.4 `PocketFlex.AsyncNode`

```elixir
defmodule PocketFlex.AsyncNode do
  @moduledoc """
  Behavior module for asynchronous nodes.
  
  Extends the basic Node behavior with asynchronous versions of
  the callbacks for concurrent execution.
  """
  
  @behaviour PocketFlex.Node
  
  @doc """
  Asynchronously prepares data from the shared state.
  
  ## Parameters
    - shared: A map containing the shared state
    
  ## Returns
    A tuple containing:
    - :ok and the prepared data, or
    - :error and an error reason
  """
  @callback prep_async(shared :: map()) :: {:ok, any()} | {:error, term()}
  
  @doc """
  Asynchronously executes the node's main logic.
  
  ## Parameters
    - prep_result: The result from the prep_async function
    
  ## Returns
    A tuple containing:
    - :ok and the execution result, or
    - :error and an error reason
  """
  @callback exec_async(prep_result :: any()) :: {:ok, any()} | {:error, term()}
  
  @doc """
  Asynchronously post-processes the execution result.
  
  ## Parameters
    - shared: The shared state map
    - prep_result: The result from the prep_async function
    - exec_result: The result from the exec_async function
    
  ## Returns
    A tuple containing:
    - :ok and a tuple with the action key and updated shared state, or
    - :error and an error reason
  """
  @callback post_async(shared :: map(), prep_result :: any(), exec_result :: any()) :: 
    {:ok, {String.t() | nil, map()}} | {:error, term()}
end
```

### 3.5 `PocketFlex.AsyncFlow`

```elixir
defmodule PocketFlex.AsyncFlow do
  @moduledoc """
  Manages the asynchronous execution of connected nodes.
  
  Extends the basic Flow module with support for asynchronous
  execution using Elixir processes.
  """
  
  @doc """
  Runs the flow asynchronously with the given shared state.
  
  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run_async(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
end
```

### 3.6 `PocketFlex.BatchNode`

```elixir
defmodule PocketFlex.BatchNode do
  @moduledoc """
  Behavior module for batch processing nodes.
  
  Extends the basic Node behavior with support for processing
  lists of items.
  """
  
  @behaviour PocketFlex.Node
  
  # Implementation details for batch processing
end
```

### 3.7 `PocketFlex.BatchFlow`

```elixir
defmodule PocketFlex.BatchFlow do
  @moduledoc """
  Manages the execution of batch processing flows.
  
  Extends the basic Flow module with support for batch
  processing of multiple items.
  """
  
  @doc """
  Runs the batch flow with the given shared state.
  
  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run_batch(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
end
```

### 3.8 `PocketFlex.DSL`

```elixir
defmodule PocketFlex.DSL do
  @moduledoc """
  Provides a domain-specific language for connecting nodes.
  
  This module defines operators and functions that make it
  easier to create and connect nodes in a flow.
  """
  
  @doc """
  Connects two nodes with a default action.
  
  ## Parameters
    - a: The source node module
    - b: The target node module
    
  ## Returns
    A tuple representing the connection
  """
  def a >>> b when is_atom(a) and is_atom(b)
  
  @doc """
  Connects two nodes with a specific action.
  
  ## Parameters
    - a: The source node module
    - action: The action key for this connection
    - b: The target node module
    
  ## Returns
    A tuple representing the connection
  """
  def {a, action} >>> b when is_atom(a) and is_binary(action) and is_atom(b)
end
```

## 4. Implementation Details

### 4.1 Node Implementation

```elixir
defmodule PocketFlex.Node do
  # Behavior definition as specified above
end

defmodule PocketFlex.NodeMacros do
  # Implementation as specified above
end

defmodule PocketFlex.NodeRunner do
  @moduledoc false
  
  def run_node(node, shared) do
    try do
      # Prepare data
      prep_result = node.prep(shared)
      
      # Execute with retry logic
      exec_result = execute_with_retries(node, prep_result, 0)
      
      # Post-process
      {action, updated_shared} = node.post(shared, prep_result, exec_result)
      
      {:ok, action, updated_shared}
    rescue
      e -> {:error, e}
    end
  end
  
  defp execute_with_retries(node, prep_result, retry_count) do
    try do
      node.exec(prep_result)
    rescue
      e ->
        max_retries = if function_exported?(node, :max_retries, 0), do: node.max_retries(), else: 1
        wait_time = if function_exported?(node, :wait_time, 0), do: node.wait_time(), else: 0
        
        if retry_count < max_retries - 1 do
          if wait_time > 0, do: Process.sleep(wait_time)
          execute_with_retries(node, prep_result, retry_count + 1)
        else
          if function_exported?(node, :exec_fallback, 2) do
            node.exec_fallback(prep_result, e)
          else
            raise e
          end
        end
    end
  end
end
```

### 4.2 Flow Implementation

```elixir
defmodule PocketFlex.Flow do
  defstruct [:start_node, nodes: %{}, connections: %{}, params: %{}]
  
  def new do
    %__MODULE__{}
  end
  
  def add_node(flow, node) do
    %{flow | nodes: Map.put(flow.nodes, node, %{})}
  end
  
  def connect(flow, from, to, action \\ "default") do
    connections = Map.update(
      flow.connections,
      from,
      %{action => to},
      &Map.put(&1, action, to)
    )
    
    %{flow | connections: connections}
  end
  
  def start(flow, node) do
    %{flow | start_node: node}
  end
  
  def run(flow, shared) do
    run_flow(flow, flow.start_node, shared, flow.params)
  end
  
  defp run_flow(_flow, nil, shared, _params), do: {:ok, shared}
  
  defp run_flow(flow, current_node, shared, params) do
    # Set node params if the node supports it
    current_node = if function_exported?(current_node, :set_params, 1) do
      current_node.set_params(params)
      current_node
    else
      current_node
    end
    
    case PocketFlex.NodeRunner.run_node(current_node, shared) do
      {:ok, action, updated_shared} ->
        # Find next node
        next_node = get_next_node(flow, current_node, action)
        
        # Continue flow
        run_flow(flow, next_node, updated_shared, params)
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp get_next_node(flow, current_node, action) do
    action = action || "default"
    
    case get_in(flow.connections, [current_node, action]) do
      nil ->
        if map_size(get_in(flow.connections, [current_node]) || %{}) > 0 do
          require Logger
          Logger.warning("Flow ends: '#{action}' not found in #{inspect(Map.keys(get_in(flow.connections, [current_node])))}")
        end
        nil
        
      next_node -> next_node
    end
  end
end
```

### 4.3 Async Implementation

```elixir
defmodule PocketFlex.AsyncNode do
  @behaviour PocketFlex.Node
  
  # Default implementations that delegate to async versions
  @impl true
  def prep(shared) do
    case prep_async(shared) do
      {:ok, result} -> result
      {:error, reason} -> raise "Async prep failed: #{inspect(reason)}"
    end
  end
  
  @impl true
  def exec(prep_result) do
    case exec_async(prep_result) do
      {:ok, result} -> result
      {:error, reason} -> raise "Async exec failed: #{inspect(reason)}"
    end
  end
  
  @impl true
  def post(shared, prep_result, exec_result) do
    case post_async(shared, prep_result, exec_result) do
      {:ok, result} -> result
      {:error, reason} -> raise "Async post failed: #{inspect(reason)}"
    end
  end
  
  # Async callbacks to be implemented by concrete nodes
  @callback prep_async(shared :: map()) :: {:ok, any()} | {:error, term()}
  @callback exec_async(prep_result :: any()) :: {:ok, any()} | {:error, term()}
  @callback post_async(shared :: map(), prep_result :: any(), exec_result :: any()) :: 
    {:ok, {String.t() | nil, map()}} | {:error, term()}
end

defmodule PocketFlex.AsyncFlow do
  def run_async(flow, shared) do
    Task.async(fn -> PocketFlex.Flow.run(flow, shared) end)
    |> Task.await(:infinity)
  end
end
```

### 4.4 Batch Implementation

```elixir
defmodule PocketFlex.BatchNode do
  @behaviour PocketFlex.Node
  
  @impl true
  def exec(items) when is_list(items) do
    Enum.map(items, fn item ->
      exec_item(item)
    end)
  end
  
  # To be implemented by concrete batch nodes
  @callback exec_item(item :: any()) :: any()
end

defmodule PocketFlex.ParallelBatchNode do
  @behaviour PocketFlex.Node
  
  @impl true
  def exec(items) when is_list(items) do
    Task.async_stream(items, fn item ->
      exec_item(item)
    end, ordered: true)
    |> Enum.map(fn {:ok, result} -> result end)
  end
  
  # To be implemented by concrete parallel batch nodes
  @callback exec_item(item :: any()) :: any()
end

defmodule PocketFlex.BatchFlow do
  def run_batch(flow, shared) do
    # Get batch items from prep
    case flow.start_node.prep(shared) do
      nil -> {:ok, shared}
      [] -> {:ok, shared}
      items when is_list(items) ->
        # Process each item
        Enum.reduce_while(items, {:ok, shared}, fn item, {:ok, acc_shared} ->
          params = Map.merge(flow.params, item)
          
          case PocketFlex.Flow.run(flow, acc_shared, params) do
            {:ok, updated_shared} -> {:cont, {:ok, updated_shared}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
        
      _ -> {:error, "Batch prep must return a list"}
    end
  end
end
```

### 4.5 DSL Implementation

```elixir
defmodule PocketFlex.DSL do
  defmacro __using__(_opts) do
    quote do
      import PocketFlex.DSL
      alias PocketFlex.{Flow, Node}
    end
  end
  
  # Node >>> Node (default transition)
  def left >>> right when is_atom(left) and is_atom(right) do
    {left, right, "default"}
  end
  
  # {Node, "action"} >>> Node (conditional transition)
  def {left, action} >>> right when is_atom(left) and is_binary(action) and is_atom(right) do
    {left, right, action}
  end
  
  # Helper to apply connections to a flow
  def apply_connections(flow, connections) when is_list(connections) do
    Enum.reduce(connections, flow, fn {from, to, action}, acc ->
      PocketFlex.Flow.connect(acc, from, to, action)
    end)
  end
end
```

## 5. Example Usage

```elixir
# Basic node
defmodule MyApp.BasicNode do
  use PocketFlex.NodeMacros
  
  @impl true
  def exec(prep_result) do
    # Process data
    transformed_data = process_data(prep_result)
    transformed_data
  end
  
  defp process_data(data) do
    # Implementation
  end
end

# Creating a flow
defmodule MyApp.BasicFlow do
  use PocketFlex.DSL
  
  def create do
    # Create nodes
    node1 = MyApp.Node1
    node2 = MyApp.Node2
    node3 = MyApp.Node3
    
    # Create connections
    connections = [
      node1 >>> node2,
      {node2, "success"} >>> node3
    ]
    
    # Create flow
    Flow.new()
    |> Flow.add_node(node1)
    |> Flow.add_node(node2)
    |> Flow.add_node(node3)
    |> apply_connections(connections)
    |> Flow.start(node1)
  end
end

# Running a flow
flow = MyApp.BasicFlow.create()
{:ok, result} = PocketFlex.Flow.run(flow, %{})
```

## 6. Testing Strategy

```elixir
defmodule PocketFlex.NodeTest do
  use ExUnit.Case
  
  # Test node implementation
  defmodule TestNode do
    use PocketFlex.NodeMacros
    
    @impl true
    def prep(shared), do: Map.get(shared, "input")
    
    @impl true
    def exec(input), do: String.upcase(input)
    
    @impl true
    def post(shared, _prep_res, exec_res) do
      {"default", Map.put(shared, "output", exec_res)}
    end
  end
  
  test "node processes data correctly" do
    shared = %{"input" => "hello"}
    {:ok, action, updated_shared} = PocketFlex.NodeRunner.run_node(TestNode, shared)
    
    assert action == "default"
    assert updated_shared["output"] == "HELLO"
  end
end
```

## 7. Implementation Plan

1. Core Modules: Start with the basic Node behavior and Flow implementation
2. DSL: Develop a clean syntax for connecting nodes
3. Async Support: Add support for asynchronous execution using Elixir processes
4. Batch Processing: Implement batch and parallel processing capabilities
5. Testing: Create comprehensive tests for all components
6. Documentation: Write detailed documentation with examples
