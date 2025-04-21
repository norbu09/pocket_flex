defmodule PocketFlexTest do
  use ExUnit.Case
  doctest PocketFlex

  describe "basic node functionality" do
    defmodule BasicNode do
      use PocketFlex.NodeMacros

      @impl true
      def exec(input) when is_binary(input) do
        String.upcase(input)
      end

      def exec(_) do
        "DEFAULT"
      end
    end

    test "node processes data correctly" do
      # Create a simple node instance
      node = BasicNode

      # Run the node directly
      result = PocketFlex.NodeRunner.run_node(node, %{"input" => "hello"})

      # Check the result
      assert {:ok, "default", %{"input" => "hello"}} = result
    end
  end

  describe "flow execution" do
    defmodule FlowTestNode1 do
      use PocketFlex.NodeMacros

      @impl true
      def prep(shared) do
        Map.get(shared, "input", "default input")
      end

      @impl true
      def exec(input) when is_binary(input) do
        String.upcase(input)
      end

      def exec(_) do
        "DEFAULT"
      end

      @impl true
      def post(shared, _prep_res, exec_res) do
        {"default", Map.put(shared, "output1", exec_res)}
      end
    end

    defmodule FlowTestNode2 do
      use PocketFlex.NodeMacros

      @impl true
      def prep(shared) do
        Map.get(shared, "output1")
      end

      @impl true
      def exec(input) when is_binary(input) do
        "#{input} processed"
      end

      def exec(_) do
        "DEFAULT processed"
      end

      @impl true
      def post(shared, _prep_res, exec_res) do
        {nil, Map.put(shared, "output2", exec_res)}
      end
    end

    test "flow executes nodes in sequence" do
      # Create a flow with two nodes
      flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(FlowTestNode1)
        |> PocketFlex.Flow.add_node(FlowTestNode2)
        |> PocketFlex.Flow.connect(FlowTestNode1, FlowTestNode2)
        |> PocketFlex.Flow.start(FlowTestNode1)

      # Run the flow
      {:ok, result} = PocketFlex.run(flow, %{"input" => "hello"})

      # Check the result
      assert result["output1"] == "HELLO"
      assert result["output2"] == "HELLO processed"
    end
  end

  describe "DSL for connecting nodes" do
    import PocketFlex.DSL

    defmodule DSLNode1 do
      use PocketFlex.NodeMacros

      @impl true
      def exec(_) do
        "node1"
      end

      @impl true
      def post(shared, _prep_res, exec_res) do
        {"default", Map.put(shared, "node1", exec_res)}
      end
    end

    defmodule DSLNode2 do
      use PocketFlex.NodeMacros

      @impl true
      def exec(_) do
        "node2"
      end

      @impl true
      def post(shared, _prep_res, exec_res) do
        {"default", Map.put(shared, "node2", exec_res)}
      end
    end

    test "DSL creates correct connections" do
      # Create connections using the DSL
      connections = [
        DSLNode1 >>> DSLNode2
      ]

      # Create a flow and apply the connections
      flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(DSLNode1)
        |> PocketFlex.Flow.add_node(DSLNode2)
        |> apply_connections(connections)
        |> PocketFlex.Flow.start(DSLNode1)

      # Run the flow
      {:ok, result} = PocketFlex.run(flow, %{})

      # Check the result
      assert result["node1"] == "node1"
      assert result["node2"] == "node2"
    end
  end
end
