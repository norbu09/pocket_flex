# State Storage Guide

This guide explains how PocketFlex manages state across flows and nodes using the simplified state storage system.

## Overview

PocketFlex uses a shared state storage system to maintain flow state across nodes. The state storage system is designed to be simple, efficient, and flexible, supporting multiple storage backends through a common interface.

## Key Features

- **Single Table Design**: All flow states are stored in a single ETS table
- **Shared State**: Nodes can read and update the shared state
- **Concurrent Access**: Optimized for concurrent reads with controlled writes
- **Simple API**: Just a few essential functions for state management
- **Pluggable Backend**: Support for custom storage implementations

## State Storage API

The core API for state storage consists of four main functions:

```elixir
# Get the current state for a flow
state = PocketFlex.StateStorage.get_state(flow_id)

# Update the state for a flow
PocketFlex.StateStorage.update_state(flow_id, new_state)

# Merge updates into the current state
PocketFlex.StateStorage.merge_state(flow_id, state_updates)

# Clean up the state when done
PocketFlex.StateStorage.cleanup(flow_id)
```

## Flow ID Generation

Each flow execution gets a unique `flow_id`, which is used to identify its state in the storage system. Flow IDs are typically generated using:

```elixir
flow_id = "prefix_#{:erlang.unique_integer([:positive])}"
```

This ensures unique identifiers for each flow execution.

## State Lifecycle

1. **Initialization**: When a flow starts, its initial state is stored in the state storage
2. **Updates**: As nodes process data, they update the flow's state
3. **Retrieval**: Nodes can retrieve the current state at any time
4. **Cleanup**: When the flow completes, its state is removed from storage

## Example: Basic State Management

```elixir
# Generate a unique flow ID
flow_id = "my_flow_#{:erlang.unique_integer([:positive])}"

# Initialize with initial state
initial_state = %{"key" => "value"}
PocketFlex.StateStorage.update_state(flow_id, initial_state)

# Retrieve the current state
current_state = PocketFlex.StateStorage.get_state(flow_id)

# Update with new state
new_state = %{"key" => "new_value"}
PocketFlex.StateStorage.update_state(flow_id, new_state)

# Merge updates into current state
updates = %{"another_key" => "another_value"}
PocketFlex.StateStorage.merge_state(flow_id, updates)

# Clean up when done
PocketFlex.StateStorage.cleanup(flow_id)
```

## Example: Async Batch Processing

In async batch processing, the state storage is used to maintain state across asynchronous operations:

```elixir
# Create a flow
flow =
  PocketFlex.Flow.new()
  |> PocketFlex.Flow.add_node(MyBatchNode)
  |> PocketFlex.Flow.add_node(ResultProcessorNode)
  |> PocketFlex.Flow.connect(MyBatchNode, ResultProcessorNode)
  |> PocketFlex.Flow.start(MyBatchNode)

# Initial state
initial_state = %{"items" => [1, 2, 3, 4, 5]}

# Run the flow asynchronously
task = PocketFlex.AsyncBatchFlow.run_async_batch(flow, initial_state)

# Wait for the result
{:ok, final_state} = Task.await(task)
```

The `AsyncBatchFlow` handles state management automatically:

1. Generates a unique flow ID
2. Initializes state storage with the initial state
3. Updates state as items are processed
4. Cleans up state when the flow completes

## Implementing a Custom State Storage Backend

You can implement a custom state storage backend by creating a module that implements the `PocketFlex.StateStorage` behavior:

```elixir
defmodule MyApp.CustomStateStorage do
  @behaviour PocketFlex.StateStorage

  @impl true
  def get_state(flow_id) do
    # Implementation
  end

  @impl true
  def update_state(flow_id, new_state) do
    # Implementation
  end

  @impl true
  def merge_state(flow_id, state_updates) do
    # Implementation
  end

  @impl true
  def cleanup(flow_id) do
    # Implementation
  end
end
```

Then configure PocketFlex to use your custom storage backend:

```elixir
# In your config/config.exs
config :pocket_flex, :state_storage, MyApp.CustomStateStorage
```

## Best Practices

1. **Always clean up state**: Use `cleanup/1` when a flow completes to prevent memory leaks
2. **Use merge for partial updates**: Use `merge_state/2` for partial updates to avoid overwriting other changes
3. **Handle concurrent access**: Be mindful of concurrent access patterns in your nodes
4. **Keep state small**: Avoid storing large data structures in the state
5. **Use unique flow IDs**: Ensure flow IDs are unique to prevent state collisions

## Conclusion

The simplified state storage system in PocketFlex provides an efficient and flexible way to manage state across flows and nodes. By using a single shared ETS table and a clean API, it reduces complexity while maintaining performance and flexibility.
