defmodule PocketFlex.Examples.AsyncBatchExample do
  @moduledoc """
  Example implementation of async batch processing with PocketFlex.

  This example demonstrates how to use AsyncBatchNode and AsyncBatchFlow
  to process a list of URLs asynchronously.
  """

  require Logger

  defmodule UrlFetcherNode do
    @moduledoc """
    A node that fetches content from a list of URLs asynchronously.
    """
    use PocketFlex.AsyncBatchNode

    @impl true
    def prep(shared) do
      # Return a list of URLs to process
      shared["urls"] || []
    end

    @impl true
    def exec_item_async(url) do
      # Create a task that fetches the URL content
      task =
        Task.async(fn ->
          Logger.info("Fetching URL: #{url}")

          # Simulate HTTP request with random delay
          Process.sleep(Enum.random(100..300))

          # Return a simulated response
          %{
            url: url,
            status: 200,
            body: "Content from #{url}",
            timestamp: DateTime.utc_now()
          }
        end)

      # Always return {:ok, task} - we handle errors inside the task
      {:ok, task}
    end

    @impl true
    def post(shared, _prep_res, results) do
      # Store the results in the shared state
      updated_shared = Map.put(shared, "fetch_results", results)
      {:default, updated_shared}
    end
  end

  defmodule ContentProcessorNode do
    @moduledoc """
    A node that processes the fetched content.
    """
    use PocketFlex.NodeMacros

    @impl true
    def prep(shared) do
      # Get the fetch results from the shared state
      shared["fetch_results"] || []
    end

    @impl true
    def exec(results) do
      # Process each result
      Enum.map(results, fn result ->
        Logger.info("Processing content from: #{result.url}")

        # Simulate processing with random delay
        Process.sleep(Enum.random(50..100))

        # Add some processed data
        Map.put(result, :word_count, String.length(result.body))
      end)
    end

    @impl true
    def post(shared, _prep_res, processed_results) do
      # Store the processed results in the shared state
      updated_shared = Map.put(shared, "processed_results", processed_results)
      {:default, updated_shared}
    end
  end

  defmodule ResultAggregatorNode do
    @moduledoc """
    A node that aggregates the processed results.
    """
    use PocketFlex.NodeMacros

    @impl true
    def prep(shared) do
      # Get the processed results from the shared state
      shared["processed_results"] || []
    end

    @impl true
    def exec(processed_results) do
      # Aggregate the results
      total_word_count =
        Enum.reduce(processed_results, 0, fn result, acc ->
          acc + result.word_count
        end)

      # Return the aggregated data
      %{
        total_urls: length(processed_results),
        total_word_count: total_word_count,
        average_word_count: total_word_count / max(length(processed_results), 1),
        timestamp: DateTime.utc_now()
      }
    end

    @impl true
    def post(shared, _prep_res, aggregated_results) do
      # Store the aggregated results in the shared state
      updated_shared = Map.put(shared, "aggregated_results", aggregated_results)
      {:default, updated_shared}
    end
  end

  @doc """
  Runs the async batch example with the given URLs.

  ## Parameters
    - urls: A list of URLs to process
    
  ## Returns
    A tuple containing:
    - :ok and the final results, or
    - :error and an error reason
  """
  def run(urls) do
    # Create a flow
    flow =
      PocketFlex.Flow.new()
      |> PocketFlex.Flow.add_node(UrlFetcherNode)
      |> PocketFlex.Flow.add_node(ContentProcessorNode)
      |> PocketFlex.Flow.add_node(ResultAggregatorNode)
      |> PocketFlex.Flow.connect(UrlFetcherNode, ContentProcessorNode)
      |> PocketFlex.Flow.connect(ContentProcessorNode, ResultAggregatorNode)
      |> PocketFlex.Flow.start(UrlFetcherNode)

    # Initial shared state
    shared = %{"urls" => urls}

    # Generate a unique flow ID for this execution
    flow_id = "async_batch_example_#{:erlang.unique_integer([:positive])}"

    # Initialize state storage with the initial shared state
    PocketFlex.StateStorage.update_state(flow_id, shared)

    # Run the flow using async batch
    task = PocketFlex.AsyncBatchFlow.run_async_batch(flow, shared)

    # Wait for the task to complete
    case Task.await(task, :infinity) do
      {:ok, final_shared} ->
        # Clean up the state
        PocketFlex.StateStorage.cleanup(flow_id)
        
        # Return the aggregated results
        aggregated_results = final_shared["aggregated_results"] || %{
          total_urls: length(urls),
          total_word_count: 0,
          average_word_count: 0.0,
          timestamp: DateTime.utc_now()
        }
        
        {:ok, aggregated_results}

      {:error, reason} ->
        # Clean up the state
        PocketFlex.StateStorage.cleanup(flow_id)
        {:error, reason}
    end
  end

  @doc """
  Runs the async parallel batch example with the given URLs.

  ## Parameters
    - urls: A list of URLs to process
    
  ## Returns
    A tuple containing:
    - :ok and the final results, or
    - :error and an error reason
  """
  def run_parallel(urls) do
    # Create a flow
    flow =
      PocketFlex.Flow.new()
      |> PocketFlex.Flow.add_node(UrlFetcherNode)
      |> PocketFlex.Flow.add_node(ContentProcessorNode)
      |> PocketFlex.Flow.add_node(ResultAggregatorNode)
      |> PocketFlex.Flow.connect(UrlFetcherNode, ContentProcessorNode)
      |> PocketFlex.Flow.connect(ContentProcessorNode, ResultAggregatorNode)
      |> PocketFlex.Flow.start(UrlFetcherNode)

    # Initial shared state
    shared = %{"urls" => urls}

    # Generate a unique flow ID for this execution
    flow_id = "async_parallel_batch_example_#{:erlang.unique_integer([:positive])}"

    # Initialize state storage with the initial shared state
    PocketFlex.StateStorage.update_state(flow_id, shared)

    # Run the flow using async parallel batch
    task = PocketFlex.AsyncParallelBatchFlow.run_async_parallel_batch(flow, shared)

    # Wait for the task to complete
    case Task.await(task, :infinity) do
      {:ok, final_shared} ->
        # Clean up the state
        PocketFlex.StateStorage.cleanup(flow_id)
        
        # Return the aggregated results
        aggregated_results = final_shared["aggregated_results"] || %{
          total_urls: length(urls),
          total_word_count: 0,
          average_word_count: 0.0,
          timestamp: DateTime.utc_now()
        }
        
        {:ok, aggregated_results}

      {:error, reason} ->
        # Clean up the state
        PocketFlex.StateStorage.cleanup(flow_id)
        {:error, reason}
    end
  end
end
