defmodule PocketFlex.DSLTest do
  use ExUnit.Case
  use PocketFlex.DSL

  alias PocketFlex.Flow

  defmodule StartNode do
    use PocketFlex.NodeMacros

    def exec(_) do
      :success
    end
  end

  defmodule SuccessNode do
    use PocketFlex.NodeMacros

    def exec(_) do
      :completed
    end
  end

  defmodule ErrorNode do
    use PocketFlex.NodeMacros

    def exec(_) do
      :error
    end
  end

  defmodule FallbackNode do
    use PocketFlex.NodeMacros

    def exec(_) do
      :fallback
    end
  end

  defmodule ConditionalNode do
    use PocketFlex.NodeMacros

    def exec(shared) do
      if Map.get(shared, "condition", false) do
        :success
      else
        :error
      end
    end

    # Add prep implementation to avoid BadMapError
    def prep(shared) do
      shared
    end
  end

  describe "basic operators" do
    test ">>> operator connects nodes with default action" do
      connection = StartNode >>> SuccessNode
      assert connection == {StartNode, SuccessNode, :default}
    end

    test "~> operator connects nodes with specific action" do
      connection = StartNode ~> :success ~> SuccessNode
      assert connection == {StartNode, SuccessNode, :success}
    end
  end

  describe "flow construction" do
    test "apply_connections builds a flow from connections" do
      connections = [
        StartNode >>> SuccessNode,
        StartNode ~> :error ~> ErrorNode
      ]

      flow =
        Flow.new()
        |> Flow.start(StartNode)
        |> apply_connections(connections)

      assert flow.start_node == StartNode
      assert get_in(flow.connections, [StartNode, :default]) == SuccessNode
      assert get_in(flow.connections, [StartNode, :error]) == ErrorNode
    end

    test "on function creates conditional connections" do
      connection = on(StartNode, :success, SuccessNode)
      assert connection == {StartNode, SuccessNode, :success}
    end

    test "branch function creates branching connections" do
      connection = branch(StartNode, :error, ErrorNode)
      assert connection == {StartNode, ErrorNode, :error}
    end

    test "branch function can update an existing flow" do
      flow =
        Flow.new()
        |> Flow.start(StartNode)
        |> Flow.connect(StartNode, SuccessNode, :success)
        |> branch(:error, ErrorNode)

      assert get_in(flow.connections, [StartNode, :success]) == SuccessNode
      assert get_in(flow.connections, [StartNode, :error]) == ErrorNode
    end
  end

  describe "helper functions" do
    test "linear_flow creates a linear flow" do
      connections = linear_flow([StartNode, SuccessNode, FallbackNode])

      assert length(connections) == 2
      assert Enum.at(connections, 0) == {StartNode, SuccessNode, :default}
      assert Enum.at(connections, 1) == {SuccessNode, FallbackNode, :default}
    end

    test "with_error_handling creates a flow with error handling" do
      connections = with_error_handling([StartNode, SuccessNode], ErrorNode)

      assert length(connections) == 3
      assert Enum.at(connections, 0) == {StartNode, SuccessNode, :default}
      assert Enum.at(connections, 1) == {StartNode, ErrorNode, :error}
      assert Enum.at(connections, 2) == {SuccessNode, ErrorNode, :error}
    end
  end

  describe "integration" do
    test "flow runs with enhanced DSL connections" do
      flow =
        Flow.new()
        |> Flow.start(StartNode)
        |> apply_connections([
          StartNode >>> SuccessNode,
          SuccessNode ~> :completed ~> FallbackNode
        ])

      {:ok, result} = Flow.run(flow, %{})
      assert result == %{}
    end

    test "conditional branching works with DSL" do
      flow =
        Flow.new()
        |> Flow.start(ConditionalNode)
        |> apply_connections([
          ConditionalNode ~> :success ~> SuccessNode,
          ConditionalNode ~> :error ~> ErrorNode,
          SuccessNode >>> FallbackNode,
          ErrorNode >>> FallbackNode
        ])

      # Test success path
      {:ok, _result} = Flow.run(flow, %{"condition" => true})

      # Test error path
      {:ok, _result} = Flow.run(flow, %{"condition" => false})
    end
  end
end
