# PocketFlex Execution Models

PocketFlex supports several execution models to handle different processing requirements. This guide explains each model and provides examples of when and how to use them.

## Synchronous Execution

The simplest execution model is synchronous execution, where nodes are executed one after another in a sequential manner.

### When to Use

- Simple workflows where nodes need to be executed in sequence
- When the result of one node is immediately needed by the next node
- For deterministic, step-by-step processing

### Implementation

```elixir
defmodule MyApp.Nodes.SimpleNode do
  use PocketFlex.NodeMacros
  
  def exec(input) do
    # Process input synchronously
    String.upcase(input)
  end
  
  def post(shared, _prep_result, exec_result) do
    {:default, Map.put(shared, "result", exec_result)}
  end
end

# Create and run a synchronous flow
flow = Flow.new()
       |> Flow.start(MyApp.Nodes.SimpleNode)
       |> Flow.connect(MyApp.Nodes.SimpleNode, MyApp.Nodes.NextNode)

{:ok, result} = PocketFlex.run(flow, %{"input" => "hello"})
```

## Asynchronous Execution

Asynchronous execution allows nodes to perform operations without blocking the flow, which is useful for I/O-bound operations like API calls or file operations.

### When to Use

- Operations that involve waiting for external resources
- Non-blocking operations that can run in the background
- When you need to perform concurrent operations

### Implementation

```elixir
defmodule MyApp.Nodes.AsyncNode do
  use PocketFlex.AsyncNode
  
  def prep(shared) do
    Map.get(shared, "input")
  end
  
  def exec_async(input) do
    # Simulate an async operation (e.g., API call)
    Task.async(fn ->
      Process.sleep(100) # Simulate delay
      {:ok, String.upcase(input)}
    end)
    |> Task.await()
  end
  
  def post(shared, _prep_result, {:ok, result}) do
    {:success, Map.put(shared, "async_result", result)}
  end
end

# Create and run an async flow
flow = Flow.new()
       |> Flow.start(MyApp.Nodes.AsyncNode)
       |> Flow.connect(MyApp.Nodes.AsyncNode, MyApp.Nodes.NextNode, :success)

{:ok, result} = PocketFlex.run_async(flow, %{"input" => "hello"})
```

## Batch Processing

Batch processing allows you to process a list of items sequentially, applying the same operation to each item.

### When to Use

- When you need to process a collection of items with the same operation
- For data transformation or enrichment of multiple items
- When maintaining the order of processing is important

### Implementation

```elixir
defmodule MyApp.Nodes.BatchNode do
  use PocketFlex.BatchNode
  
  def prep(shared) do
    Map.get(shared, "items", [])
  end
  
  def exec_item(item) do
    # Process a single item
    String.upcase(item)
  end
  
  def post(shared, _prep_result, exec_result) do
    {:success, Map.put(shared, "processed_items", exec_result)}
  end
end

# Create and run a batch flow
flow = Flow.new()
       |> Flow.start(MyApp.Nodes.BatchNode)
       |> Flow.connect(MyApp.Nodes.BatchNode, MyApp.Nodes.NextNode, :success)

{:ok, result} = PocketFlex.run_batch(flow, %{"items" => ["a", "b", "c"]})
```

## Parallel Batch Processing

Parallel batch processing allows you to process a list of items concurrently, which can significantly improve performance for CPU-bound operations.

### When to Use

- When processing items independently without order dependency
- For CPU-intensive operations that can benefit from parallelism
- When you need to process large datasets quickly

### Implementation

```elixir
defmodule MyApp.Nodes.ParallelBatchNode do
  use PocketFlex.BatchNode
  
  def prep(shared) do
    Map.get(shared, "items", [])
  end
  
  def exec_item(item) do
    # Process a single item (will be executed in parallel)
    String.upcase(item)
  end
  
  def post(shared, _prep_result, exec_result) do
    {:success, Map.put(shared, "processed_items", exec_result)}
  end
end

# Create and run a parallel batch flow
flow = Flow.new()
       |> Flow.start(MyApp.Nodes.ParallelBatchNode)
       |> Flow.connect(MyApp.Nodes.ParallelBatchNode, MyApp.Nodes.NextNode, :success)

{:ok, result} = PocketFlex.run_parallel_batch(flow, %{"items" => ["a", "b", "c"]})
```

## Asynchronous Batch Processing

Asynchronous batch processing combines the benefits of asynchronous execution and batch processing, allowing you to process batches of items without blocking.

### When to Use

- For I/O-bound operations on multiple items
- When you need to process batches in the background
- For operations that involve waiting for external resources for each item

### Implementation

```elixir
defmodule MyApp.Nodes.AsyncBatchNode do
  use PocketFlex.AsyncBatchNode
  
  def prep(shared) do
    Map.get(shared, "items", [])
  end
  
  def exec_item_async(item) do
    # Process a single item asynchronously
    Task.async(fn ->
      Process.sleep(50) # Simulate delay
      {:ok, String.upcase(item)}
    end)
    |> Task.await()
  end
  
  def post(shared, _prep_result, exec_result) do
    {:success, Map.put(shared, "processed_items", exec_result)}
  end
end

# Create and run an async batch flow
flow = Flow.new()
       |> Flow.start(MyApp.Nodes.AsyncBatchNode)
       |> Flow.connect(MyApp.Nodes.AsyncBatchNode, MyApp.Nodes.NextNode, :success)

{:ok, result} = PocketFlex.run_async_batch(flow, %{"items" => ["a", "b", "c"]})
```

## Asynchronous Parallel Batch Processing

This model combines asynchronous execution with parallel batch processing, providing the highest level of concurrency for processing large datasets with I/O-bound operations.

### When to Use

- For processing large datasets with I/O-bound operations
- When you need maximum throughput for independent operations
- For complex data processing pipelines with external dependencies

### Implementation

```elixir
defmodule MyApp.Nodes.AsyncParallelBatchNode do
  use PocketFlex.AsyncBatchNode
  
  def prep(shared) do
    Map.get(shared, "items", [])
  end
  
  def exec_item_async(item) do
    # Process a single item asynchronously (will be executed in parallel)
    Task.async(fn ->
      Process.sleep(50) # Simulate delay
      {:ok, String.upcase(item)}
    end)
    |> Task.await()
  end
  
  def post(shared, _prep_result, exec_result) do
    {:success, Map.put(shared, "processed_items", exec_result)}
  end
end

# Create and run an async parallel batch flow
flow = Flow.new()
       |> Flow.start(MyApp.Nodes.AsyncParallelBatchNode)
       |> Flow.connect(MyApp.Nodes.AsyncParallelBatchNode, MyApp.Nodes.NextNode, :success)

{:ok, result} = PocketFlex.run_async_parallel_batch(flow, %{"items" => ["a", "b", "c"]})
```

## Choosing the Right Execution Model

Here's a quick guide to help you choose the right execution model for your use case:

| Execution Model | Use When |
|-----------------|----------|
| Synchronous | Simple sequential operations, deterministic processing |
| Asynchronous | I/O-bound operations, external API calls, non-blocking operations |
| Batch | Processing collections sequentially, order-dependent operations |
| Parallel Batch | Independent item processing, CPU-bound operations, performance-critical |
| Async Batch | I/O-bound operations on collections, background processing |
| Async Parallel Batch | Maximum throughput for I/O-bound operations on large datasets |

## Best Practices

1. **Start Simple**: Begin with synchronous execution and move to more complex models as needed.

2. **Consider Dependencies**: If items depend on each other, use sequential batch processing.

3. **Resource Constraints**: Be mindful of system resources when using parallel processing.

4. **Error Handling**: Implement proper error handling for each execution model.

5. **Testing**: Test each execution model thoroughly to ensure correct behavior.

6. **Monitoring**: Monitor performance to determine if a different execution model would be more efficient.

7. **Idempotency**: Ensure operations are idempotent when using asynchronous processing to handle potential retries.

## Conclusion

PocketFlex provides a flexible set of execution models to handle a wide range of processing requirements. By choosing the right model for your use case, you can optimize performance while maintaining code clarity and maintainability.
