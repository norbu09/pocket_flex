# PocketFlex

PocketFlex is an Elixir implementation of the PocketFlow agent framework. It provides a flexible system for creating flows of connected nodes, where each node performs a specific task and passes data to the next node.

## Features

- **Simple Node API**: Define nodes with prep, exec, and post lifecycle methods
- **Flexible Flow Control**: Connect nodes with conditional branching
- **Concurrency Support**: Run flows asynchronously using Elixir processes
- **Batch Processing**: Process lists of items sequentially or in parallel
- **Clean DSL**: Create flows with an intuitive syntax
- **Retry Logic**: Built-in support for retrying failed operations

## Installation

Add `pocket_flex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pocket_flex, ">= 0.1.0"}
  ]
end
```

## Basic Usage

### Defining Nodes

```elixir
defmodule MyApp.Nodes.GetQuestionNode do
  use PocketFlex.NodeMacros
  
  @impl true
  def exec(_) do
    IO.gets("Enter your question: ")
    |> String.trim()
  end
  
  @impl true
  def post(shared, _prep_res, exec_res) do
    {"default", Map.put(shared, "question", exec_res)}
  end
end

defmodule MyApp.Nodes.AnswerNode do
  use PocketFlex.NodeMacros
  
  @impl true
  def prep(shared) do
    Map.get(shared, "question")
  end
  
  @impl true
  def exec(question) do
    # Process the question and generate an answer
    "The answer to '#{question}' is 42."
  end
  
  @impl true
  def post(shared, _prep_res, exec_res) do
    {nil, Map.put(shared, "answer", exec_res)}
  end
end
```

### Creating a Flow

```elixir
defmodule MyApp.Flows.QAFlow do
  import PocketFlex.DSL
  
  def create do
    # Create node references
    get_question = MyApp.Nodes.GetQuestionNode
    answer = MyApp.Nodes.AnswerNode
    
    # Define connections
    connections = [
      get_question >>> answer
    ]
    
    # Create and configure the flow
    PocketFlex.Flow.new()
    |> PocketFlex.Flow.add_node(get_question)
    |> PocketFlex.Flow.add_node(answer)
    |> apply_connections(connections)
    |> PocketFlex.Flow.start(get_question)
  end
end
```

### Running a Flow

```elixir
# Create the flow
flow = MyApp.Flows.QAFlow.create()

# Run the flow with an initial shared state
{:ok, result} = PocketFlex.run(flow, %{})

# Access the results
IO.puts("Question: #{result["question"]}")
IO.puts("Answer: #{result["answer"]}")
```

## Advanced Features

### Asynchronous Execution

```elixir
defmodule MyApp.Nodes.AsyncNode do
  use PocketFlex.AsyncNode
  
  @impl PocketFlex.AsyncNode
  def exec_async(input) do
    # Perform async operation
    {:ok, String.upcase(input)}
  end
end

# Run a flow asynchronously
{:ok, result} = PocketFlex.run_async(flow, %{})
```

### Batch Processing

```elixir
defmodule MyApp.Nodes.BatchNode do
  use PocketFlex.BatchNode
  
  @impl PocketFlex.BatchNode
  def exec_item(item) do
    # Process a single item
    String.upcase(item)
  end
end

# Run a flow with batch processing
{:ok, result} = PocketFlex.run_batch(flow, %{})

# Run a flow with parallel batch processing
{:ok, result} = PocketFlex.run_parallel_batch(flow, %{})
```

### Conditional Branching

```elixir
defmodule MyApp.Nodes.BranchingNode do
  use PocketFlex.NodeMacros
  
  @impl true
  def exec(input) do
    # Some logic
    result = process(input)
    
    # Return the result
    result
  end
  
  @impl true
  def post(shared, _prep_res, exec_res) do
    # Determine the next action based on the result
    action = if exec_res.valid?, do: "success", else: "error"
    
    # Return the action and updated shared state
    {action, Map.put(shared, "result", exec_res)}
  end
  
  defp process(input) do
    # Implementation
  end
end

# Connect nodes with conditional branching
connections = [
  node1 >>> node2,
  {node2, "success"} >>> success_node,
  {node2, "error"} >>> error_node
]
```

## Implementation Details

PocketFlex is an Elixir implementation of the PocketFlow agent framework, focusing on creating a flexible system for building flows of connected nodes.

### Current Implementation

- **Node System**
  - `PocketFlex.Node`: Behavior module for defining nodes with lifecycle methods (prep, exec, post)
  - `PocketFlex.NodeMacros`: Macros for simplifying node implementation with default implementations
  - Internal node execution system with retry logic and error handling

- **Flow Management**
  - `PocketFlex.Flow`: Manages node connections and flow execution
  - `PocketFlex.DSL`: Provides a clean syntax for connecting nodes

- **Batch Processing**
  - `PocketFlex.BatchNode`: For processing lists of items
  - `PocketFlex.ParallelBatchNode`: For parallel processing of lists
  - `PocketFlex.BatchFlow`: For batch processing in flows
  - `PocketFlex.ParallelBatchFlow`: For parallel batch processing in flows

- **Async Execution**
  - `PocketFlex.AsyncNode`: For asynchronous node execution

### Planned Enhancements

- **AsyncBatchNode Implementation**
  - Create `PocketFlex.AsyncBatchNode` that combines AsyncNode and BatchNode functionality
  - Create `PocketFlex.AsyncParallelBatchNode` for parallel asynchronous batch processing

- **AsyncFlow Enhancement**
  - Improve `PocketFlex.AsyncFlow` for better handling of asynchronous execution
  - Add support for async orchestration of flows

- **DSL Refinement**
  - Make the DSL more expressive and intuitive for connecting nodes
  - Add operators for conditional transitions

- **Examples**
  - Create example implementations to demonstrate different use cases
  - Add examples for async and batch processing

- **Documentation**
  - Add comprehensive documentation for all modules and functions
  - Include usage examples and best practices

## Documentation

Complete documentation is available at [https://hexdocs.pm/pocket_flex](https://hexdocs.pm/pocket_flex).

## License

PocketFlex is released under the MIT License. See the LICENSE file for details.
