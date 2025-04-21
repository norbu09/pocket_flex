---
layout: default
title: "Node"
parent: "Core Abstraction"
nav_order: 1
---

# Node

The fundamental unit of computation in PocketFlex. Each Node encapsulates a specific piece of logic within the overall flow.

## Node Behaviour (Conceptual)

While the exact implementation might vary, a PocketFlex Node is conceptually an Elixir module implementing a specific behaviour (e.g., `PocketFlex.Node`). This behaviour likely defines callback functions:

- `prep/1`: 
  - **Input**: The current `shared_state` (Map).
  - **Output**: `{:ok, prep_data}` or `{:error, reason}`.
  - **Purpose**: Extracts necessary data from the shared state for the `exec` step. Avoids complex computation.
- `exec/1`: 
  - **Input**: `{:ok, prep_data}` from `prep/1`.
  - **Output**: `{:ok, exec_result}` or `{:error, reason}`.
  - **Purpose**: Performs the core logic of the node. This is where computations happen, utilities are called (including LLMs via wrappers), etc. Should be idempotent if possible.
- `post/3`: 
  - **Input**: Original `shared_state`, `prep_data` (from `prep/1`), `exec_result` (from `exec/1`, which could be `{:ok, _}` or `{:error, _}`).
  - **Output**: `{:ok, {next_action_atom, updated_state}}` or potentially `{:error, reason}` for critical post-processing errors.
  - **Purpose**: Updates the `shared_state` based on the execution result and determines the next step in the flow via the `next_action_atom` (e.g., `:default`, `:success`, `:error`, `:custom_path`). Must handle both success and error cases from `exec/1`.

## Example Node

```elixir
# Example Node: lib/my_project/nodes/add_value_node.ex
# (Assumes a PocketFlex.Node behaviour exists)
defmodule MyProject.Nodes.AddValueNode do
  @moduledoc "A simple node that adds a value from config to the state."
  # @behaviour PocketFlex.Node 
  require Logger

  # 1. Prepare: Get the value to add (e.g., from config or initial state)
  def prep(shared_state) do
    # Example: Get value from application config or a default
    value_to_add = Application.get_env(:my_app, :value_to_add, 10)
    current_total = Map.get(shared_state, :total, 0)
    Logger.debug("Prep AddValueNode: Current total=#{current_total}, Value to add=#{value_to_add}")
    {:ok, %{current_total: current_total, value_to_add: value_to_add}}
  end

  # 2. Execute: Perform the addition
  def exec({:ok, %{current_total: total, value_to_add: value}}) do
    new_total = total + value
    Logger.debug("Exec AddValueNode: New total=#{new_total}")
    {:ok, new_total}
  end
  def exec({:error, reason}) do
     # Propagate prep error
     Logger.error("AddValueNode skipped due to prep error: #{inspect(reason)}")
    {:error, reason}
  end

  # 3. Post-process: Update the shared state and determine next step
  def post(shared_state, _prep_data, {:ok, new_total}) do
    updated_state = Map.put(shared_state, :total, new_total)
    Logger.debug("Post AddValueNode: Updated state: #{inspect(updated_state)}")
    # Transition to the default next node
    {:ok, {:default, updated_state}} 
  end
  def post(shared_state, _prep_data, {:error, reason}) do
     # If exec failed, log it and maybe transition differently
     Logger.error("AddValueNode failed in exec: #{inspect(reason)}")
     updated_state = Map.put(shared_state, :error_info, {__MODULE__, :exec_failed, reason})
     # Transition via an :error path
     {:ok, {:error, updated_state}}
  end
end
```

## Best Practices & Conventions

- **Always use atoms** for actions in `post/3` (e.g., `:default`, `:success`, `:error`).
- **Always return `{action_atom, updated_state}`** from `post/3` (never overwrite the shared state with a raw value).
- **All node and flow operations should return `{:ok, ...}` or `{:error, ...}` tuples** for robust error handling.
- **Use the provided macros** for default node behaviors; override only when necessary.
- **Prefer pattern matching in function heads** for clarity and safety.
- **Update custom `post/3` implementations** to avoid state overwrite and ensure action is always an atom.

## Migration Note

If upgrading from older versions:
- Use atoms for actions (not strings)
- Ensure all node and flow results use tuple-based conventions
- Review and update any custom `post/3` implementations

## Node Types

PocketFlex might define different node types or allow customization:

- **Regular Node**: Executes sequentially.
- **Async Node**: Executes potentially in a separate process (`Task.async`?).
- **Batch Node**: Processes multiple items (perhaps using `Task.async_stream`).
- **Router Node**: Primarily determines control flow based on state, with minimal `exec` logic.
- **Agent Node**: Uses an LLM in `exec` to decide the `next_action_atom` in `post`.

Refer to the specific PocketFlex implementation for available node types and behaviours. 