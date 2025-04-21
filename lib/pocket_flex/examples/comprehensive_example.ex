defmodule PocketFlex.Examples.ComprehensiveExample do
  @moduledoc """
  A comprehensive example demonstrating the various features of PocketFlex.

  This example implements a simple data processing pipeline that:
  1. Validates input data
  2. Transforms the data
  3. Processes the data in batches
  4. Stores the results

  It demonstrates:
  - Basic node implementation
  - Flow creation with the enhanced DSL
  - Conditional branching
  - Batch processing
  - Asynchronous execution
  """

  use PocketFlex.DSL
  require Logger

  # Define some example nodes

  defmodule InputValidationNode do
    @moduledoc "Validates input data"
    use PocketFlex.NodeMacros

    @impl true
    def prep(shared) do
      Logger.info("Validating input data")
      shared
    end

    @impl true
    def exec(shared) do
      input = Map.get(shared, "input", nil)

      cond do
        is_nil(input) -> {:error, "Input is missing"}
        input == "" -> {:error, "Input is empty"}
        true -> {:ok, input}
      end
    end

    @impl true
    def post(shared, _prep_result, exec_result) do
      case exec_result do
        {:ok, input} ->
          Logger.info("Input validation successful")
          {:valid, Map.put(shared, "validated_input", input)}

        {:error, reason} ->
          Logger.warning("Input validation failed: #{reason}")
          {:invalid, Map.put(shared, "error", reason)}
      end
    end
  end

  defmodule DataTransformationNode do
    @moduledoc "Transforms input data"
    use PocketFlex.NodeMacros

    @impl true
    def prep(shared) do
      Logger.info("Preparing to transform data")
      Map.get(shared, "validated_input")
    end

    @impl true
    def exec(input) when is_binary(input) do
      # Simple transformation: uppercase and split into words
      input
      |> String.upcase()
      |> String.split(~r/\s+/)
    end

    @impl true
    def post(shared, _prep_result, exec_result) do
      Logger.info("Data transformation completed")
      {:success, Map.put(shared, "transformed_data", exec_result)}
    end
  end

  defmodule BatchProcessingNode do
    @moduledoc "Processes data in batches"
    use PocketFlex.BatchNode

    @impl true
    def prep(shared) do
      Logger.info("Preparing batch processing")
      Map.get(shared, "transformed_data", [])
    end

    @impl true
    def exec_item(item) do
      # Process each item: add a prefix
      "PROCESSED_#{item}"
    end

    @impl true
    def post(shared, _prep_result, exec_result) do
      Logger.info("Batch processing completed")
      {:success, Map.put(shared, "processed_data", exec_result)}
    end
  end

  defmodule AsyncProcessingNode do
    @moduledoc "Processes data asynchronously"
    use PocketFlex.AsyncNode

    @impl true
    def prep_async(shared) do
      Logger.info("Preparing async processing")
      {:ok, Map.get(shared, "processed_data", [])}
    end

    @impl true
    def exec_async(items) do
      # Create a task that will process the items
      task =
        Task.async(fn ->
          # Simulate async processing with a delay
          Process.sleep(100)

          # Further process each item
          Enum.map(items, fn item ->
            "ASYNC_#{item}"
          end)
        end)

      {:ok, task}
    end

    @impl true
    def post_async(shared, _prep_result, exec_result) do
      Logger.info("Async processing completed")
      {:ok, {:success, Map.put(shared, "async_processed_data", exec_result)}}
    end
  end

  defmodule DataStorageNode do
    @moduledoc "Stores processed data"
    use PocketFlex.NodeMacros

    @impl true
    def prep(shared) do
      Logger.info("Preparing to store data")
      Map.get(shared, "async_processed_data", [])
    end

    @impl true
    def exec(data) do
      # Simulate storing data
      Logger.info("Storing data: #{inspect(data)}")
      {:ok, length(data)}
    end

    @impl true
    def post(shared, _prep_result, {:ok, count}) do
      Logger.info("Data storage completed: #{count} items stored")
      {:stored, Map.put(shared, "storage_count", count)}
    end

    @impl true
    def post(shared, _prep_result, {:error, reason}) do
      Logger.error("Data storage failed: #{reason}")
      {:error, Map.put(shared, "error", reason)}
    end
  end

  defmodule ErrorHandlingNode do
    @moduledoc "Handles errors in the flow"
    use PocketFlex.NodeMacros

    @impl true
    def prep(shared) do
      Logger.warning("Error occurred in the flow")
      shared
    end

    @impl true
    def exec(shared) do
      error = Map.get(shared, "error", "Unknown error")
      Logger.error("Error in flow processing: #{error}")
      {:handled, error}
    end

    @impl true
    def post(shared, _prep_result, {:handled, _error}) do
      {:complete, Map.put(shared, "error_handled", true)}
    end
  end

  defmodule CompletionNode do
    @moduledoc "Finalizes the flow execution"
    use PocketFlex.NodeMacros

    @impl true
    def prep(shared) do
      Logger.info("Finalizing flow execution")
      shared
    end

    @impl true
    def exec(shared) do
      # Add completion timestamp
      Map.put(shared, "completed_at", DateTime.utc_now())
    end

    @impl true
    def post(_shared, _prep_result, exec_result) do
      Logger.info("Flow execution completed")
      {:complete, exec_result}
    end
  end

  @doc """
  Creates a basic flow using the >>> operator.

  ## Returns
    A configured flow
  """
  def create_basic_flow do
    Flow.new()
    |> Flow.start(InputValidationNode)
    |> apply_connections([
      InputValidationNode >>> DataTransformationNode,
      DataTransformationNode >>> BatchProcessingNode,
      BatchProcessingNode >>> AsyncProcessingNode,
      AsyncProcessingNode >>> DataStorageNode,
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
      InputValidationNode ~> :valid ~> DataTransformationNode,
      InputValidationNode ~> :invalid ~> ErrorHandlingNode,
      DataTransformationNode ~> :success ~> BatchProcessingNode,
      BatchProcessingNode ~> :success ~> AsyncProcessingNode,
      AsyncProcessingNode ~> :success ~> DataStorageNode,
      DataStorageNode ~> :stored ~> CompletionNode,
      DataStorageNode ~> :error ~> ErrorHandlingNode,
      ErrorHandlingNode ~> :complete ~> CompletionNode
    ])
  end

  @doc """
  Creates a flow using the on function for clearer conditional connections.

  ## Returns
    A configured flow
  """
  def create_flow_with_on do
    connections = [
      on(InputValidationNode, :valid, DataTransformationNode),
      on(InputValidationNode, :invalid, ErrorHandlingNode),
      on(DataTransformationNode, :success, BatchProcessingNode),
      on(BatchProcessingNode, :success, AsyncProcessingNode),
      on(AsyncProcessingNode, :success, DataStorageNode),
      on(DataStorageNode, :stored, CompletionNode),
      on(DataStorageNode, :error, ErrorHandlingNode),
      on(ErrorHandlingNode, :complete, CompletionNode)
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
    |> Flow.connect(InputValidationNode, DataTransformationNode, :valid)
    |> branch(:invalid, ErrorHandlingNode)
    |> Flow.connect(DataTransformationNode, BatchProcessingNode, :success)
    |> Flow.connect(BatchProcessingNode, AsyncProcessingNode, :success)
    |> Flow.connect(AsyncProcessingNode, DataStorageNode, :success)
    |> Flow.connect(DataStorageNode, CompletionNode, :stored)
    |> branch(:error, ErrorHandlingNode)
    |> Flow.connect(ErrorHandlingNode, CompletionNode, :complete)
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
      DataTransformationNode,
      BatchProcessingNode,
      AsyncProcessingNode,
      DataStorageNode,
      CompletionNode
    ]

    # Add error handling to all nodes
    connections = with_error_handling(main_path, ErrorHandlingNode)

    # Add specific conditional connections
    additional_connections = [
      on(InputValidationNode, :invalid, ErrorHandlingNode),
      on(ErrorHandlingNode, :complete, CompletionNode)
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
    PocketFlex.run(flow, shared)
  end

  @doc """
  Runs a flow with batch processing.

  ## Parameters
    - flow: The flow to run
    - input: The input data to process
    
  ## Returns
    The result of the flow execution
  """
  def run_batch_example(flow, input) do
    shared = %{"input" => input}
    PocketFlex.run_batch(flow, shared)
  end

  @doc """
  Runs a flow with parallel batch processing.

  ## Parameters
    - flow: The flow to run
    - input: The input data to process
    
  ## Returns
    The result of the flow execution
  """
  def run_parallel_batch_example(flow, input) do
    shared = %{"input" => input}
    PocketFlex.run_parallel_batch(flow, shared)
  end

  @doc """
  Runs a flow asynchronously.

  ## Parameters
    - flow: The flow to run
    - input: The input data to process
    
  ## Returns
    The result of the flow execution
  """
  def run_async_example(flow, input) do
    shared = %{"input" => input}
    PocketFlex.run_async(flow, shared)
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
