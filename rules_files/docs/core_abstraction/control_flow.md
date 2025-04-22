---
layout: default
title: "Control Flow"
parent: "Core Abstraction"
nav_order: 3
---

# Control Flow

PocketFlex manages the sequence of execution between [Nodes](./node.md) based on the flow definition and the runtime results returned by each node's `post/3` callback.

## Transition Logic

- **Flow Definition**: The overall structure (which nodes connect to which) is defined using the PocketFlex DSL. Each node specifies transitions from `next_action_atom` results to destination nodes (or a special `:end` state).
- **`post/3` Return Value**: The `post/3` function of a node determines the *immediate next step* by returning `{:ok, {next_action_atom, updated_state}}`.
- **`next_action_atom`**: This atom (e.g., `:default`, `:success`, `:error`, `:user_input_required`, `:condition_met`) dictates which transition path to take from the current node.

## Example Flow Definition

```elixir
alias MyProject.Nodes
alias PocketFlex.DSL

def define_flow do
  DSL.define(
    start_node: Nodes.StartNode,
    nodes: [
      %{module: Nodes.StartNode, transitions: %{
        default: Nodes.ProcessDataNode,
        needs_auth: Nodes.AuthNode
      }},
      %{module: Nodes.ProcessDataNode, transitions: %{
        default: Nodes.EndNode,
        error: Nodes.ErrorHandlingNode
      }},
      %{module: Nodes.AuthNode, transitions: %{
        success: Nodes.ProcessDataNode,
        failure: Nodes.EndNode
      }},
      %{module: Nodes.ErrorHandlingNode, transitions: %{
        default: Nodes.EndNode
      }},
      %{module: Nodes.EndNode, transitions: %{}}
    ]
  )
end
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

## Best Practices

- Use atoms for all flow actions (`:default`, `:error`, etc.), never strings.
- Always handle all possible outcomes in the transitions map.
- Keep node transitions explicit for clarity and maintainability.
- Use dedicated router nodes for complex branching logic.
- Prefer pattern matching in `post/3` to select the transition atom.
- Use error transitions (`:error`) for robust error handling and recovery.

## Key Concepts

- **Atom-Based Transitions**: Using atoms (`:default`, `:error`, etc.) for transition keys is conventional and efficient in Elixir.
- **Explicit Paths**: Define all expected transitions clearly in the flow definition.
- **Error Handling**: Design dedicated error paths or nodes, triggered by specific error atoms returned from `post/3`. 

## Migration Note

If upgrading from older versions:
- Update all transition keys to atoms
- Ensure all results are tuple-based
- Reference the DSL guide for modern flow patterns

## References
- See [Node](./node.md) for node lifecycle.
- See [Communication](./communication.md) for state handling.