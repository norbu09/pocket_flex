# PocketFlex

PocketFlex is an Elixir implementation of the [PocketFlow](https://github.com/The-Pocket/PocketFlow) agent framework. It provides a flexible system for creating flows of connected nodes, where each node performs a specific task and passes data to the next node.

## What's New (2025-04)

- **Robust Error Handling:** All node and flow operations now use `{:ok, result}`/`{:error, reason}` tuples and atoms for control flow (e.g., `:default`, `:success`, `:error`).
- **Improved Node Post-processing:** The default `post/3` now ensures the shared state is never overwritten by a raw value. Always return `{action_atom, updated_state}`.
- **ETS-backed State Storage:** All flow state is managed in a single ETS table for performance and concurrency. Configurable via `config :pocket_flex, :state_table, ...`.
- **Test and Documentation Conventions:** All new code is tested with ExUnit, uses property-based tests for complex structures (via StreamData), and includes doctests and module docs.

## Features

- **Simple Node API**: Define nodes with `prep`, `exec`, and `post` lifecycle methods
- **Flexible Flow Control**: Connect nodes with conditional branching using atoms for actions
- **Concurrency Support**: Run flows asynchronously using Elixir processes
- **Batch Processing**: Process lists of items sequentially or in parallel
- **Clean DSL**: Create flows with an intuitive syntax
- **Retry Logic**: Built-in support for retrying failed operations
- **Robust Error Handling**: Standardized error tuples and action atoms
- **Configurable State Storage**: ETS-backed with custom table name

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
# Always use atoms for actions and ok/error tuples for results

defmodule MyApp.Nodes.GetQuestionNode do
  use PocketFlex.NodeMacros
  @moduledoc """Gets a question from the user and puts it in the shared state."""

  @impl true
  def exec(_shared) do
    IO.gets("Enter your question: ") |> String.trim()
  end

  @impl true
  def post(shared, _prep_res, exec_res) do
    {:default, Map.put(shared, :question, exec_res)}
  end
end

defmodule MyApp.Nodes.AnswerNode do
  use PocketFlex.NodeMacros
  @moduledoc """Answers the user's question."""

  @impl true
  def prep(shared) do
    Map.get(shared, :question)
  end

  @impl true
  def exec(question) do
    # Process the question and generate an answer
    "The answer to '#{question}' is 42."
  end

  @impl true
  def post(shared, _prep_res, exec_res) do
    {:default, Map.put(shared, :answer, exec_res)}
  end
end
```

### Creating a Flow

```elixir
defmodule MyApp.Flows.QAFlow do
  import PocketFlex.DSL

  def create do
    get_question = MyApp.Nodes.GetQuestionNode
    answer = MyApp.Nodes.AnswerNode
    connections = [get_question >>> answer]

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
flow = MyApp.Flows.QAFlow.create()
{:ok, result} = PocketFlex.run(flow, %{})
IO.puts("Question: #{result[:question]}")
IO.puts("Answer: #{result[:answer]}")
```

## Advanced Features

### Asynchronous Execution

```elixir
defmodule MyApp.Nodes.AsyncNode do
  use PocketFlex.AsyncNode
  @moduledoc """An example async node."""

  @impl true
  def exec_async(input) do
    Task.async(fn -> String.upcase(input) end)
  end

  @impl true
  def post_async(shared, _prep_res, exec_res) do
    {:default, Map.put(shared, :async_result, exec_res)}
  end
end

# Run a flow asynchronously
{:ok, result} = PocketFlex.run_async(flow, %{})
```

### Batch Processing

```elixir
defmodule MyApp.Nodes.BatchNode do
  use PocketFlex.BatchNode
  @moduledoc """Processes a batch of items."""

  @impl true
  def exec_item(item) do
    String.upcase(item)
  end
end

# Run a flow with batch processing
{:ok, result} = PocketFlex.run_batch(flow, %{})
# Or parallel batch processing
{:ok, result} = PocketFlex.run_parallel_batch(flow, %{})
```

### Conditional Branching

```elixir
defmodule MyApp.Nodes.BranchingNode do
  use PocketFlex.NodeMacros
  @moduledoc """Branches based on exec result validity."""

  @impl true
  def exec(input) do
    %{valid?: input == "ok", value: input}
  end

  @impl true
  def post(shared, _prep_res, exec_res) do
    action = if exec_res.valid?, do: :success, else: :error
    {action, Map.put(shared, :result, exec_res)}
  end
end

# Connect nodes with conditional branching
connections = [
  node1 >>> node2,
  {node2, :success} >>> success_node,
  {node2, :error} >>> error_node
]
```

## Error Handling and Best Practices

- Always use atoms for actions in `post/3` (e.g., `:default`, `:success`, `:error`).
- Always return `{:ok, ...}` or `{:error, ...}` from node and flow operations.
- Never overwrite the shared state with a raw value in `post/3`.
- Use the provided macros for default behaviors, override only when needed.
- Use property-based tests (StreamData) for complex data.
- Use ExUnit's `setup` for common test setup.
- Use Mox for mocking dependencies in tests.
- See the guides for advanced DSL, execution models, and state storage configuration.

## Configuration

You can configure the ETS table name for state storage in your config:

```elixir
config :pocket_flex, :state_table, :my_custom_state_table
```

## Documentation

- Full API docs: <https://hexdocs.pm/pocket_flex/>
- Guides: `guides/` directory for DSL, execution, and state storage

## License

PocketFlex is released under the MIT License. See the LICENSE file for details.
