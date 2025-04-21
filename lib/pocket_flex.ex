defmodule PocketFlex do
  @moduledoc """
  PocketFlex is an Elixir implementation of the PocketFlow agent framework.

  It provides a flexible system for creating flows of connected nodes, where each node 
  performs a specific task and passes data to the next node.

  ## Features

  - **Simple Node API**: Define nodes with prep, exec, and post lifecycle methods
  - **Flexible Flow Control**: Connect nodes with conditional branching
  - **Concurrency Support**: Run flows asynchronously using Elixir processes
  - **Batch Processing**: Process lists of items sequentially or in parallel
  - **Clean DSL**: Create flows with an intuitive syntax
  - **Retry Logic**: Built-in support for retrying failed operations

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
      {nil, Map.put(shared, "answer", exec_res)}
    end
  end
  ```

  ### Creating a Flow

  ```elixir
  defmodule MyApp.Flows.QAFlow do
    use PocketFlex.DSL
    
    def create do
      # Create node references
      get_question = MyApp.Nodes.GetQuestionNode
      answer = MyApp.Nodes.AnswerNode
      
      # Define connections
      connections = [
        get_question >>> answer
      ]
      
      # Create and configure the flow
      Flow.new()
      |> Flow.start(get_question)
      |> apply_connections(connections)
    end
  end
  ```

  ### Running a Flow

  ```elixir
  # Create the flow
  flow = MyApp.Flows.QAFlow.create()

  # Run the flow with an initial shared state
  {:ok, result} = PocketFlex.run(flow, %{})

  # Access the results
  IO.puts("Question: \#{result["question"]}")
  IO.puts("Answer: \#{result["answer"]}")
  ```

  ## Advanced Features

  For more advanced features, see the documentation for:

  - `PocketFlex.AsyncNode` - For asynchronous node execution
  - `PocketFlex.BatchNode` - For batch processing
  - `PocketFlex.AsyncBatchNode` - For asynchronous batch processing
  - `PocketFlex.DSL` - For the domain-specific language for connecting nodes
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
    
  ## Examples

  ```elixir
  {:ok, result} = PocketFlex.run(flow, %{"input" => "Hello"})
  ```
  """
  @spec run(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate run(flow, shared), to: PocketFlex.Flow

  @doc """
  Runs a flow asynchronously with the given shared state.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to:
    - {:ok, final_shared_state}
    - {:error, reason}
  """
  @spec run_async(PocketFlex.Flow.t(), map()) :: Task.t()
  defdelegate run_async(flow, shared), to: PocketFlex.AsyncFlow

  @doc """
  Orchestrates the asynchronous execution of a flow with async nodes.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec orchestrate_async(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate orchestrate_async(flow, shared), to: PocketFlex.AsyncFlow

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
  Runs a batch flow with the given shared state, processing items in parallel.

  The batch flow expects the start node's prep function to return a list of items.
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
    A Task that will resolve to:
    - {:ok, final_shared_state}
    - {:error, reason}
  """
  @spec run_async_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  defdelegate run_async_batch(flow, shared), to: PocketFlex.AsyncBatchFlow

  @doc """
  Runs a batch flow asynchronously with the given shared state, processing items in parallel.

  The batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow in parallel and asynchronously.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to:
    - {:ok, final_shared_state}
    - {:error, reason}
  """
  @spec run_async_parallel_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  defdelegate run_async_parallel_batch(flow, shared), to: PocketFlex.AsyncParallelBatchFlow
end
