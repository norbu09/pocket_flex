defmodule PocketFlex do
  @moduledoc """
  PocketFlex is an Elixir implementation of a flexible, node-based processing framework.

  It provides a system for creating flows of connected nodes, where each node 
  performs a specific task and passes data to the next node.

  ## Features

  - **Simple Node API**: Define nodes with prep, exec, and post lifecycle methods
  - **Flexible Flow Control**: Connect nodes with conditional branching
  - **Concurrency Support**: Run flows asynchronously using Elixir processes
  - **Batch Processing**: Process lists of items sequentially or in parallel
  - **Clean DSL**: Create flows with an intuitive syntax
  - **Retry Logic**: Built-in support for retrying failed operations
  - **Efficient State Management**: Simplified state storage using a single ETS table

  ## State Management

  PocketFlex uses a shared state storage system to maintain flow state across nodes:

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

  For more details, see the [State Storage Guide](state_storage.html).

  ## Basic Usage

  ### Defining Nodes

  ```elixir
  defmodule MyApp.Nodes.GetQuestionNode do
    use PocketFlex.NodeMacros
    
    @impl true
    def exec(_) do
      IO.gets("Enter your question: ")
      |> String.trim()
    end
    
    @impl true
    def post(shared, _prep_res, exec_res) do
      {:default, Map.put(shared, "question", exec_res)}
    end
  end

  defmodule MyApp.Nodes.AnswerNode do
    use PocketFlex.NodeMacros
    
    @impl true
    def prep(shared) do
      Map.get(shared, "question")
    end
    
    @impl true
    def exec(question) do
      # Process the question and generate an answer
      "The answer to '\#{question}' is 42."
    end
    
    @impl true
    def post(shared, _prep_res, exec_res) do
      {:default, Map.put(shared, "answer", exec_res)}
    end
  end
  ```

  ### Creating and Running a Flow

  ```elixir
  # Create a new flow
  flow =
    PocketFlex.Flow.new()
    |> PocketFlex.Flow.add_node(MyApp.Nodes.GetQuestionNode)
    |> PocketFlex.Flow.add_node(MyApp.Nodes.AnswerNode)
    |> PocketFlex.Flow.connect(MyApp.Nodes.GetQuestionNode, MyApp.Nodes.AnswerNode)
    |> PocketFlex.Flow.start(MyApp.Nodes.GetQuestionNode)

  # Run the flow
  {:ok, final_state} = PocketFlex.Flow.run(flow, %{})

  # Access the result
  IO.puts(final_state["answer"])
  ```

  ### Using the DSL

  ```elixir
  import PocketFlex.DSL

  flow =
    flow do
      node GetQuestionNode
      node AnswerNode
      
      GetQuestionNode -> AnswerNode
      
      start_with GetQuestionNode
    end

  {:ok, final_state} = PocketFlex.Flow.run(flow, %{})
  ```

  ### Async Batch Processing

  ```elixir
  # Create a flow with batch processing nodes
  flow =
    PocketFlex.Flow.new()
    |> PocketFlex.Flow.add_node(MyApp.Nodes.BatchProcessorNode)
    |> PocketFlex.Flow.add_node(MyApp.Nodes.ResultAggregatorNode)
    |> PocketFlex.Flow.connect(MyApp.Nodes.BatchProcessorNode, MyApp.Nodes.ResultAggregatorNode)
    |> PocketFlex.Flow.start(MyApp.Nodes.BatchProcessorNode)

  # Initial state with items to process
  initial_state = %{"items" => [1, 2, 3, 4, 5]}

  # Run the flow asynchronously
  task = PocketFlex.AsyncBatchFlow.run_async_batch(flow, initial_state)

  # Wait for the result
  {:ok, final_state} = Task.await(task)
  ```

  """

  @doc """
  Runs a flow with the given shared state.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate run(flow, shared), to: PocketFlex.Flow

  @doc """
  Runs a batch flow with the given shared state.

  The batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow sequentially.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run_batch(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate run_batch(flow, shared), to: PocketFlex.BatchFlow

  @doc """
  Runs a parallel batch flow with the given shared state.

  The parallel batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow in parallel.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run_parallel_batch(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate run_parallel_batch(flow, shared), to: PocketFlex.ParallelBatchFlow

  @doc """
  Runs a batch flow asynchronously with the given shared state.

  The batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow sequentially but asynchronously.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  defdelegate run_async_batch(flow, shared), to: PocketFlex.AsyncBatchFlow

  @doc """
  Runs a parallel batch flow asynchronously with the given shared state.

  The parallel batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow in parallel and asynchronously.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async_parallel_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  defdelegate run_async_parallel_batch(flow, shared), to: PocketFlex.AsyncParallelBatchFlow
  
  @doc """
  Runs a flow asynchronously with the given shared state.

  This function is for compatibility with AsyncNode modules.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async(flow, shared) do
    Task.async(fn -> PocketFlex.AsyncFlow.orchestrate_async(flow, shared) end)
  end
end
