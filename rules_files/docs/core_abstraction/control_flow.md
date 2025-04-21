---
layout: default
title: "Control Flow"
parent: "Core Abstraction"
nav_order: 3
---

# Control Flow

PocketFlex manages the sequence of execution between [Nodes](./node.md) based on the flow definition and the runtime results returned by each node's `post/3` callback.

## Transition Logic

- **Flow Definition**: The overall structure (which nodes connect to which) is typically defined when the flow is created. This definition maps `next_action_atom` results from a source node to a destination node (or a special `:end` state).
- **`post/3` Return Value**: The `post/3` function of a node determines the *immediate next step* by returning `{:ok, {next_action_atom, updated_state}}`.
- **`next_action_atom`**: This atom (e.g., `:default`, `:success`, `:error`, `:user_input_required`, `:condition_met`) dictates which transition path to take from the current node.

## Example Flow Definition (Conceptual)

```elixir
# Hypothetical flow definition using PocketFlex API
PocketFlex.define(
  start_node: MyProject.Nodes.StartNode,
  nodes: [
    # StartNode transitions
    %{module: MyProject.Nodes.StartNode, 
      transitions: %{
        default: MyProject.Nodes.ProcessDataNode, # Default path
        needs_auth: MyProject.Nodes.AuthNode      # Conditional path
      }
    },
    
    # ProcessDataNode transitions
    %{module: MyProject.Nodes.ProcessDataNode, 
      transitions: %{
        default: MyProject.Nodes.EndNode,       # Successful processing
        error: MyProject.Nodes.ErrorHandlingNode # Error during processing
      }
    },

    # AuthNode transitions
    %{module: MyProject.Nodes.AuthNode, 
      transitions: %{
        success: MyProject.Nodes.ProcessDataNode, # If auth succeeds, go process
        failure: MyProject.Nodes.EndNode          # If auth fails, end
      }
    },

    # ErrorHandlingNode transitions
    %{module: MyProject.Nodes.ErrorHandlingNode, 
      transitions: %{
        default: MyProject.Nodes.EndNode         # Always end after logging error
      }
    },

    # EndNode is a terminal state (no transitions out)
    %{module: MyProject.Nodes.EndNode, transitions: %{}}
  ]
)
```

## How it Works (Simplified)

1. The flow starts at the `start_node` (`StartNode` in the example).
2. `StartNode.prep/1` runs.
3. `StartNode.exec/1` runs.
4. `StartNode.post/3` runs and returns, say, `{:ok, {:default, updated_state}}`.
5. PocketFlex looks up the `:default` transition for `StartNode` in the flow definition, finding `ProcessDataNode`.
6. The `updated_state` is passed to `ProcessDataNode.prep/1`.
7. `ProcessDataNode.exec/1` runs. Let's say it returns `{:error, :db_timeout}`.
8. `ProcessDataNode.post/3` receives the error and returns `{:ok, {:error, state_with_error_info}}`.
9. PocketFlex looks up the `:error` transition for `ProcessDataNode`, finding `ErrorHandlingNode`.
10. The `state_with_error_info` is passed to `ErrorHandlingNode.prep/1`.
11. ... and so on, until a node transitions to a defined end state or has no further transitions defined.

## Key Concepts

- **Atom-Based Transitions**: Using atoms (`:default`, `:error`, etc.) for transition keys is conventional and efficient in Elixir.
- **Explicit Paths**: Define all expected transitions clearly in the flow definition.
- **Error Handling**: Design dedicated error paths or nodes, triggered by specific error atoms returned from `post/3`. 