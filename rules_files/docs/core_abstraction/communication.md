---
layout: default
title: "Communication (Shared State)"
parent: "Core Abstraction"
nav_order: 2
---

# Communication: Shared State

PocketFlex nodes communicate and share data primarily through an immutable **Shared State** map. This map is passed from node to node throughout the execution of a flow.

## Concept

- **Immutable Map**: The shared state is typically an Elixir map (`%{:key => value}`). Because Elixir data structures are immutable, each node receives the state map, and the `post/3` function returns a *new*, updated state map. This prevents side effects and makes flows easier to reason about.
- **Centralized Data**: All data required by downstream nodes or produced by upstream nodes resides in this shared state map.
- **Node Responsibility**: 
    - The `prep/1` function reads necessary data *from* the state.
    - The `post/3` function writes results *to* a new version of the state map.

## Example

```elixir
# Initial state provided to the flow
initial_state = %{
  user_id: "user123",
  input_text: "Some text to process.",
  results: %{},
  config: %{mode: :fast}
}

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

- **Keep it Serializable**: If you need to persist the state or pass it between processes, ensure the values in the map are easily serializable (basic Elixir types, simple structs). Avoid storing PIDs, function references, or complex ETS tables directly in the state if persistence or distribution is needed.
- **Structured Keys**: Use descriptive atoms or nested maps for keys to keep the state organized (e.g., `%{results: %{analysis: ...}}` instead of `%{analysis_result: ...}`).
- **Minimize State**: Only store data in the shared state that is truly needed by subsequent nodes. Avoid cluttering it with temporary data used only within a single node.
- **Consider Alternatives for Large Data**: For very large data (e.g., large files, embeddings), consider storing them outside the main state map (e.g., in ETS, a database, or cloud storage) and passing only references (IDs, paths) in the state map.

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