---
layout: default
title: "Node"
parent: "Core Abstraction"
nav_order: 1
---

# Node

The fundamental unit of computation in PocketFlex. Each Node encapsulates a specific piece of logic within the overall flow.

## Node Behaviour

A PocketFlex Node is an Elixir module implementing the `PocketFlex.Node` behaviour. This behaviour defines three required callbacks:

- `prep/1`: 
  - **Input**: The current `shared_state` (map).
  - **Output**: `{:ok, prep_data}` or `{:error, reason}`.
  - **Purpose**: Extracts and validates necessary data from the shared state for the `exec` step. Avoids complex computation.
- `exec/1`: 
  - **Input**: `{:ok, prep_data}` from `prep/1` (or `{:error, reason}` if prep failed).
  - **Output**: `{:ok, exec_result}` or `{:error, reason}`.
  - **Purpose**: Performs the core logic of the node. This is where computations happen, utilities are called (including LLMs via wrappers), etc. Should be idempotent if possible.
- `post/3`: 
  - **Input**: Original `shared_state`, `prep_data` (from `prep/1`), `exec_result` (from `exec/1`).
  - **Output**: `{:ok, {next_action_atom, updated_state}}` (or `{:error, reason}` for critical errors).
  - **Purpose**: Updates the `shared_state` based on the execution result and determines the next step in the flow via the `next_action_atom` (e.g., `:default`, `:success`, `:error`). Must handle both success and error cases from `exec/1`.

## Example Node

```elixir
# lib/my_project/nodes/add_value_node.ex
defmodule MyProject.Nodes.AddValueNode do
  @moduledoc "A simple node that adds a value from config to the state."
  @behaviour PocketFlex.Node
  require Logger

  def prep(shared_state) do
    value_to_add = Application.get_env(:my_app, :value_to_add, 10)
    current_total = Map.get(shared_state, :total, 0)
    Logger.debug("Prep AddValueNode: Current total=#{current_total}, Value to add=#{value_to_add}")
    {:ok, %{current_total: current_total, value_to_add: value_to_add}}
  end

  def exec({:ok, %{current_total: total, value_to_add: value}}) do
    new_total = total + value
    Logger.debug("Exec AddValueNode: New total=#{new_total}")
    {:ok, new_total}
  end
  def exec({:error, reason}) do
    Logger.error("AddValueNode skipped due to prep error: #{inspect(reason)}")
    {:error, reason}
  end

  def post(shared_state, _prep_data, {:ok, new_total}) do
    updated_state = Map.put(shared_state, :total, new_total)
    {:ok, {:default, updated_state}}
  end
  def post(shared_state, _prep_data, {:error, reason}) do
    Logger.error("AddValueNode failed: #{inspect(reason)}")
    updated_state = Map.put(shared_state, :error_info, {__MODULE__, reason})
    {:ok, {:error, updated_state}}
  end
end
```

## Best Practices

- Always use the `@behaviour PocketFlex.Node` annotation for clarity and compile-time checks.
- Use pattern matching in function heads for error handling and data extraction.
- Keep `prep/1` simple—only extract and validate data, no side effects.
- Keep `exec/1` idempotent and pure if possible.
- Use atoms for all transition actions in `post/3`.
- Always handle both success and error cases in `post/3`.
- Add `@moduledoc` and `@doc` to all node modules and public functions.

## References
- See [Communication](./communication.md) for state design.
- See [Control Flow](./control_flow.md) for node transitions.