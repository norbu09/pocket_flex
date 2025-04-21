defmodule PocketFlex.Examples.EnhancedDSLExample do
  @moduledoc """
  Example demonstrating the enhanced DSL capabilities of PocketFlex.

  This example shows how to create complex flows using the expressive DSL
  operators and helper functions.
  """

  use PocketFlex.DSL
  require Logger

  # Define some example nodes

  defmodule InputValidationNode do
    @moduledoc "Validates input data"
    use PocketFlex.NodeMacros

    def prep(shared) do
      Logger.info("Validating input data")
      shared
    end

    def exec(shared) do
      case validate_input(shared) do
        :ok -> :valid
        {:error, _reason} -> :invalid
      end
    end

    defp validate_input(shared) do
      input = Map.get(shared, "input", nil)

      cond do
        is_nil(input) -> {:error, "Input is missing"}
        input == "" -> {:error, "Input is empty"}
        true -> :ok
      end
    end

    def post(shared, _prep_result, exec_result) do
      if exec_result == :invalid do
        Logger.warning("Input validation failed")
      end

      {exec_result, shared}
    end
  end

  defmodule DataProcessingNode do
    @moduledoc "Processes valid data"
    use PocketFlex.NodeMacros

    def prep(shared) do
      Logger.info("Preparing to process data")
      shared
    end

    def exec(shared) do
      input = Map.get(shared, "input", "")
      processed = String.upcase(input)

      Map.put(shared, "processed_data", processed)
    end

    def post(_shared, _prep_result, exec_result) do
      Logger.info("Data processing completed")
      {:success, exec_result}
    end
  end

  defmodule DataStorageNode do
    @moduledoc "Stores processed data"
    use PocketFlex.NodeMacros

    def prep(shared) do
      Logger.info("Preparing to store data")
      shared
    end

    def exec(shared) do
      processed_data = Map.get(shared, "processed_data", nil)

      if is_nil(processed_data) do
        :error
      else
        # Simulate storing data
        Logger.info("Storing data: #{processed_data}")
        :stored
      end
    end

    def post(shared, _prep_result, exec_result) do
      {exec_result, shared}
    end
  end

  defmodule NotificationNode do
    @moduledoc "Sends notification about processed data"
    use PocketFlex.NodeMacros

    def prep(shared) do
      Logger.info("Preparing notification")
      shared
    end

    def exec(shared) do
      processed_data = Map.get(shared, "processed_data", nil)

      if is_nil(processed_data) do
        :error
      else
        # Simulate sending notification
        Logger.info("Sending notification about: #{processed_data}")
        :sent
      end
    end

    def post(shared, _prep_result, exec_result) do
      {exec_result, shared}
    end
  end

  defmodule ErrorHandlingNode do
    @moduledoc "Handles errors in the flow"
    use PocketFlex.NodeMacros

    def prep(shared) do
      Logger.warning("Error occurred in the flow")
      shared
    end

    def exec(shared) do
      # Log the error
      Logger.error("Error in flow processing: #{inspect(shared)}")
      :handled
    end

    def post(shared, _prep_result, exec_result) do
      {exec_result, Map.put(shared, "error_handled", true)}
    end
  end

  defmodule CompletionNode do
    @moduledoc "Finalizes the flow execution"
    use PocketFlex.NodeMacros

    def prep(shared) do
      Logger.info("Finalizing flow execution")
      shared
    end

    def exec(shared) do
      # Mark as completed
      Map.put(shared, "completed", true)
    end

    def post(_shared, _prep_result, exec_result) do
      {:completed, exec_result}
    end
  end

  @doc """
  Creates a basic linear flow using the >>> operator.

  ## Returns
    A configured flow
  """
  def create_basic_flow do
    Flow.new()
    |> Flow.start(InputValidationNode)
    |> apply_connections([
      InputValidationNode >>> DataProcessingNode,
      DataProcessingNode >>> DataStorageNode,
      DataStorageNode >>> CompletionNode
    ])
  end

  @doc """
  Creates a flow with conditional branches using the ~> operator.

  ## Returns
    A configured flow
  """
  def create_conditional_flow do
    Flow.new()
    |> Flow.start(InputValidationNode)
    |> apply_connections([
      InputValidationNode ~> :valid ~> DataProcessingNode,
      InputValidationNode ~> :invalid ~> ErrorHandlingNode,
      DataProcessingNode ~> :success ~> DataStorageNode,
      DataStorageNode ~> :stored ~> NotificationNode,
      DataStorageNode ~> :error ~> ErrorHandlingNode,
      NotificationNode ~> :sent ~> CompletionNode,
      NotificationNode ~> :error ~> ErrorHandlingNode,
      ErrorHandlingNode ~> :handled ~> CompletionNode
    ])
  end

  @doc """
  Creates a flow using the on function for clearer conditional connections.

  ## Returns
    A configured flow
  """
  def create_flow_with_on do
    connections = [
      on(InputValidationNode, :valid, DataProcessingNode),
      on(InputValidationNode, :invalid, ErrorHandlingNode),
      on(DataProcessingNode, :success, DataStorageNode),
      on(DataStorageNode, :stored, NotificationNode),
      on(DataStorageNode, :error, ErrorHandlingNode),
      on(NotificationNode, :sent, CompletionNode),
      on(NotificationNode, :error, ErrorHandlingNode),
      on(ErrorHandlingNode, :handled, CompletionNode)
    ]

    Flow.new()
    |> Flow.start(InputValidationNode)
    |> apply_connections(connections)
  end

  @doc """
  Creates a flow using the branch function for dynamic branching.

  ## Returns
    A configured flow
  """
  def create_flow_with_branch do
    Flow.new()
    |> Flow.start(InputValidationNode)
    |> Flow.connect(InputValidationNode, DataProcessingNode, :valid)
    |> branch(:invalid, ErrorHandlingNode)
    |> Flow.connect(DataProcessingNode, DataStorageNode, :success)
    |> Flow.connect(DataStorageNode, NotificationNode, :stored)
    |> branch(:error, ErrorHandlingNode)
    |> Flow.connect(NotificationNode, CompletionNode, :sent)
    |> branch(:error, ErrorHandlingNode)
    |> Flow.connect(ErrorHandlingNode, CompletionNode, :handled)
  end

  @doc """
  Creates a flow using the helper functions for common patterns.

  ## Returns
    A configured flow
  """
  def create_flow_with_helpers do
    # Create a linear main flow
    main_path = [
      InputValidationNode,
      DataProcessingNode,
      DataStorageNode,
      NotificationNode,
      CompletionNode
    ]

    # Add error handling to all nodes
    connections = with_error_handling(main_path, ErrorHandlingNode)

    # Add specific conditional connections
    additional_connections = [
      on(InputValidationNode, :invalid, ErrorHandlingNode),
      on(ErrorHandlingNode, :handled, CompletionNode)
    ]

    Flow.new()
    |> Flow.start(InputValidationNode)
    |> apply_connections(connections ++ additional_connections)
  end

  @doc """
  Runs a flow with the given input.

  ## Parameters
    - flow: The flow to run
    - input: The input data to process
    
  ## Returns
    The result of the flow execution
  """
  def run_example(flow, input) do
    shared = %{"input" => input}
    Flow.run(flow, shared)
  end

  @doc """
  Demonstrates all the different ways to create and run flows.

  ## Parameters
    - input: The input data to process
    
  ## Returns
    A map of results from each flow type
  """
  def run_all_examples(input) do
    basic_flow = create_basic_flow()
    conditional_flow = create_conditional_flow()
    on_flow = create_flow_with_on()
    branch_flow = create_flow_with_branch()
    helper_flow = create_flow_with_helpers()

    %{
      basic: run_example(basic_flow, input),
      conditional: run_example(conditional_flow, input),
      on: run_example(on_flow, input),
      branch: run_example(branch_flow, input),
      helper: run_example(helper_flow, input)
    }
  end
end
