---
layout: default
title: "Hello World"
parent: "Tutorials"
nav_order: 1
---

# Tutorial: Hello World

This tutorial demonstrates the most basic PocketFlex flow: two nodes passing a simple message.

## 1. Define Nodes

First, we define two simple nodes.

**Node A: Initiator**

This node starts the flow and puts the initial message into the shared state.

```elixir
# lib/my_hello_app/nodes/initiator_node.ex
defmodule MyHelloApp.Nodes.InitiatorNode do
  # @behaviour PocketFlex.Node
  require Logger

  def prep(_shared_state), do: {:ok, nil} # No input needed from state

  def exec(_prep_data) do
    message = "Hello from InitiatorNode!"
    Logger.info("InitiatorNode: Generating message.")
    {:ok, message}
  end

  def post(shared_state, _prep_data, {:ok, message}) do
    updated_state = Map.put(shared_state, :greeting, message)
    {:ok, {:default, updated_state}}
  end
end
```

**Node B: Receiver**

This node reads the message from the shared state and logs it.

```elixir
# lib/my_hello_app/nodes/receiver_node.ex
defmodule MyHelloApp.Nodes.ReceiverNode do
  # @behaviour PocketFlex.Node
  require Logger

  def prep(shared_state) do
    case Map.fetch(shared_state, :greeting) do
      {:ok, greeting} -> {:ok, greeting}
      :error -> 
        Logger.error("ReceiverNode: Greeting not found in state!")
        {:error, :greeting_missing}
    end
  end

  def exec({:ok, greeting}) do
    Logger.info("ReceiverNode: Received message - '#{greeting}'")
    # No modification, just pass the greeting through
    {:ok, greeting} 
  end
  def exec({:error, reason}), do: {:error, reason} # Pass prep error through

  def post(shared_state, _prep_data, {:ok, _greeting}) do
    # No state change needed, just signal completion
    {:ok, {:default, shared_state}} 
  end
  def post(shared_state, _prep_data, {:error, reason}) do
    Logger.error("ReceiverNode: Failed - #{inspect(reason)}")
    updated_state = Map.put(shared_state, :error_info, {__MODULE__, reason})
    {:ok, {:error, updated_state}} # Use error transition
  end
end
```

## 2. Define Flow

Next, we define the flow connecting these two nodes.

```elixir
# lib/my_hello_app/flow.ex
defmodule MyHelloApp.Flow do
  alias MyHelloApp.Nodes
  # alias PocketFlex # Assuming PocketFlex API

  def define_hello_flow do
    # Hypothetical PocketFlex flow definition
    PocketFlex.define(
      start_node: Nodes.InitiatorNode,
      nodes: [
        %{module: Nodes.InitiatorNode, 
          transitions: %{default: Nodes.ReceiverNode}
        },
        %{module: Nodes.ReceiverNode, 
          transitions: %{default: :end, error: :end} # End on default or error
        }
      ]
    )
  end
end
```

## 3. Run the Flow

Finally, we create an entry point to run the flow.

```elixir
# lib/my_hello_app.ex (or a script)
defmodule MyHelloApp do
  require Logger
  alias MyHelloApp.Flow
  # alias PocketFlex

  def run_hello_world do
    initial_state = %{} # Start with empty state
    flow_definition = Flow.define_hello_flow()

    Logger.info("Starting Hello World flow...")
    case PocketFlex.run(flow_definition, initial_state) do
      {:ok, final_state} ->
        Logger.info("Hello World flow completed successfully.")
        IO.inspect(final_state, label: "Final State")
      {:error, reason, final_state} ->
        Logger.error("Hello World flow failed: #{inspect(reason)}")
        IO.inspect(final_state, label: "Final State on Error")
    end
  end
end

# To run (example):
# mix run -e "MyHelloApp.run_hello_world()"
```

This simple example illustrates the basic mechanics: defining nodes with `prep`, `exec`, `post`, connecting them in a flow definition, and running the flow with an initial state. 