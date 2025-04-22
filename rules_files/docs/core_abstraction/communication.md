---
layout: default
title: "Communication (Shared State)"
parent: "Core Abstraction"
nav_order: 2
---

# Communication: Shared State

PocketFlex nodes communicate and share data exclusively through an immutable **Shared State** map. This map is passed from node to node throughout the execution of a flow.

## Concept

- **Immutable Map**: The shared state is always an Elixir map (`%{key => value}`). Elixir data structures are immutable, so each node receives the state map and returns a *new*, updated state map in its `post/3` function. This prevents side effects and makes flows easier to reason about and test.
- **Centralized Data**: All data required by downstream nodes or produced by upstream nodes resides in the shared state map. This includes user input, intermediate results, error info, and configuration.
- **Node Responsibility**:
    - The `prep/1` function reads necessary data *from* the state.
    - The `post/3` function writes results *to* a new version of the state map.
    - Nodes should never mutate state in-place or use process state for flow data.

## Example

```elixir
# Initial state provided to the flow
def initial_state do
  %{
    user_id: "user123",
    input_text: "Some text to process.",
    results: %{},
    config: %{mode: :fast}
  }
end

# --- Node A runs ---
# Prep reads :input_text
# Exec processes the text
# Post updates the state
state_after_node_a = %{
  user_id: "user123",
  input_text: "Some text to process.",
  results: %{
    processed_text: "SOME TEXT TO PROCESS."
  },
  config: %{mode: :fast}
}

# --- Node B runs ---
# Prep reads results.processed_text
# Exec analyzes the processed text
# Post updates the state
state_after_node_b = %{
  user_id: "user123",
  input_text: "Some text to process.",
  results: %{
    processed_text: "SOME TEXT TO PROCESS.",
    analysis: %{word_count: 4, sentiment: :neutral}
  },
  config: %{mode: :fast}
}

# And so on...
```

## Best Practices

- Always treat the shared state as immutable. Never mutate it in-place.
- Use descriptive keys for all data stored in state.
- Store all intermediate results, errors, and configuration in the state map.
- Avoid storing large binaries or sensitive data in state unless necessary.
- Design state shape up front for clarity and extensibility.
- Use pattern matching in node functions to safely extract needed data from state.

## References
- See [Node](./node.md) for how nodes interact with state.
- See [Control Flow](./control_flow.md) for how state transitions between nodes.

## ETS-Backed Shared State

PocketFlex uses a single ETS table for fast, concurrent state storage across all flows. You can configure the ETS table name in your config:

```elixir
config :pocket_flex, :state_table, :my_custom_state_table
```

- **Keep state serializable**: Only store data that can be easily serialized (no PIDs, functions, or complex references).
- **Never overwrite shared state with a raw value**: Always update the state map, never replace it with a non-map value. The default node macros enforce this.
- **Clean up state**: Always call `cleanup/1` after flow completion.

## Error Handling

All node and flow operations should return `{:ok, ...}` or `{:error, ...}` tuples. This ensures robust error propagation and makes flows easier to reason about and debug.

## Best Practices

- Use atoms for action keys (e.g., `:default`, `:success`, `:error`).
- Prefer pattern matching in function heads for clarity.
- Use the provided macros for node behaviors and override only when necessary.

## Migration Note

If upgrading from older versions:
- Ensure all state operations use the tuple-based conventions
- Review your flows for state overwrite issues