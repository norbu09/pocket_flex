# PocketFlex DSL Guide

This guide explains the Domain-Specific Language (DSL) provided by PocketFlex for connecting nodes in a flow. The DSL makes it easier to create and visualize node connections with a clean, expressive syntax.

## Basic Operators

### Default Connection (`>>>`)

The `>>>` operator connects two nodes with a default action:

```elixir
flow = NodeA >>> NodeB
```

This creates a connection from `NodeA` to `NodeB` using the `:default` action.

### Action-Specific Connection (`~>`)

The `~>` operator allows you to specify a custom action for the connection:

```elixir
flow = NodeA ~> :success ~> NodeB
```

This creates a connection from `NodeA` to `NodeB` using the `:success` action.

## Helper Functions

### Conditional Connections (`on`)

The `on` function creates a conditional connection between nodes:

```elixir
connections = [
  on(NodeA, :success, NodeB),
  on(NodeA, :error, ErrorHandlerNode)
]
```

### Branching Connections (`branch`)

The `branch` function allows you to create branching connections dynamically:

```elixir
flow = 
  Flow.new()
  |> Flow.start(NodeA)
  |> Flow.connect(NodeA, NodeB, :success)
  |> branch(:error, ErrorHandlerNode)
```

### Linear Flow (`linear_flow`)

The `linear_flow` function creates a linear sequence of nodes:

```elixir
connections = linear_flow([NodeA, NodeB, NodeC, NodeD])
```

This creates connections from NodeA to NodeB, NodeB to NodeC, and NodeC to NodeD, all with the `:default` action.

### Error Handling (`with_error_handling`)

The `with_error_handling` function creates a flow with error handling branches:

```elixir
connections = with_error_handling([NodeA, NodeB, NodeC], ErrorHandlerNode)
```

This creates a linear flow from NodeA to NodeB to NodeC, plus connections from each node to ErrorHandlerNode with the `:error` action.

## Applying Connections

To apply a list of connections to a flow, use the `apply_connections` function:

```elixir
flow = 
  Flow.new()
  |> Flow.start(StartNode)
  |> apply_connections([
    StartNode >>> ProcessingNode,
    ProcessingNode ~> :success ~> SuccessNode,
    ProcessingNode ~> :error ~> ErrorHandlerNode
  ])
```

## Complete Example

Here's a complete example that demonstrates the various DSL features:

```elixir
defmodule MyApp.Flow do
  use PocketFlex.DSL
  
  def create_flow do
    # Define the main flow path
    main_path = [
      MyApp.InputValidationNode,
      MyApp.DataProcessingNode,
      MyApp.OutputFormattingNode,
      MyApp.CompletionNode
    ]
    
    # Create a linear flow with error handling
    connections = with_error_handling(main_path, MyApp.ErrorHandlerNode)
    
    # Add additional conditional connections
    additional_connections = [
      MyApp.InputValidationNode ~> :invalid ~> MyApp.ValidationErrorNode,
      MyApp.ValidationErrorNode >>> MyApp.ErrorHandlerNode,
      MyApp.DataProcessingNode ~> :partial ~> MyApp.PartialResultNode,
      MyApp.PartialResultNode >>> MyApp.OutputFormattingNode
    ]
    
    # Create and configure the flow
    Flow.new()
    |> Flow.start(MyApp.InputValidationNode)
    |> apply_connections(connections ++ additional_connections)
  end
  
  def run_flow(input) do
    flow = create_flow()
    shared = %{"input" => input}
    Flow.run(flow, shared)
  end
end
```

## Best Practices

1. **Use Descriptive Action Atoms**: Choose action atoms that clearly describe the condition or reason for taking that path (e.g., `:success`, `:error`, `:invalid`).

2. **Group Related Connections**: When defining complex flows, group related connections together for better readability.

3. **Use Helper Functions for Common Patterns**: Leverage the helper functions like `linear_flow` and `with_error_handling` to avoid repetitive connection definitions.

4. **Visualize Your Flow**: Before implementing, sketch out your flow to better understand the node connections and transitions.

5. **Test Each Path**: Make sure to test all possible paths through your flow, especially conditional branches.

## Advanced Usage

For more complex scenarios, you can combine the DSL with direct Flow API calls:

```elixir
flow = 
  Flow.new()
  |> Flow.start(StartNode)
  |> apply_connections([
    StartNode >>> NodeB,
    NodeB ~> :success ~> SuccessNode
  ])
  |> Flow.connect(NodeB, SpecialNode, :special)
  |> Flow.connect(SpecialNode, CompletionNode, :done)
```

This flexibility allows you to build flows that meet your specific requirements while maintaining a clean, expressive syntax.
