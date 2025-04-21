---
layout: default
title: "MapReduce"
parent: "Design Patterns"
nav_order: 3
---

# Design Pattern: MapReduce

The MapReduce pattern involves splitting a large task into smaller, independent sub-tasks (Map), processing them concurrently, and then combining the results (Reduce).

## Concept in PocketFlex

PocketFlex itself might not have a dedicated "MapReduce Node" type, but this pattern can be implemented using standard Elixir concurrency features orchestrated by PocketFlex nodes:

1.  **Setup Node**: Prepares the data. Reads the large dataset or list of items to be processed from the [Shared State](../core_abstraction/communication.md) or an external source.
2.  **Map Node**: 
    *   Takes the list of items from the Setup Node.
    *   Uses `Task.async_stream/3` or `Task.async_stream/5` to concurrently apply a mapping function to each item. This mapping function might:
        *   Perform a simple transformation.
        *   Call an external utility (including LLMs via `LLMCaller`).
        *   Even run a sub-flow using PocketFlex (though this adds complexity).
    *   The `exec/1` function manages the `Task.async_stream` and collects all results (which could be `{:ok, result}` or `{:error, reason}` tuples).
    *   Adds the list of results (including any errors) to the shared state.
3.  **Reduce Node**: 
    *   Takes the list of results from the Map Node's output in the shared state.
    *   Processes the results:
        *   Filters out or handles errors.
        *   Aggregates, summarizes, or combines the successful results into a final output.
    *   Adds the final aggregated result to the shared state.

## Example Flow

```mermaid
graph TD
    A[Start: Input Data] --> B(Node: Setup Data Split);
    B --> C{Node: Map Tasks Concurrently};
    C --> D(Node: Reduce Results);
    D --> E[End: Final Result];
    C -- Error Handling --> F(Node: Handle Task Errors);
    F --> D; # Feed error summary to Reduce?
```

## Implementation Notes

- **Concurrency with `Task.async_stream`**: The core of the Map stage is leveraging Elixir's built-in task management. The Map Node's `exec/1` function would look something like this (simplified):
    ```elixir
    def exec({:ok, %{items: items_to_process}}) do
      results = 
        items_to_process
        |> Task.async_stream(&process_single_item/1, timeout: 60000, max_concurrency: 10) 
        |> Enum.map(fn {:ok, result} -> result end) # Task.async_stream returns {:ok, result} tuples
      
      # results will be a list of {:ok, item_result} or {:error, reason} tuples
      {:ok, results}
    end

    defp process_single_item(item) do
      # Logic to process one item
      # May call utilities, LLMs, etc.
      # Must return {:ok, result} or {:error, reason}
      # Example:
      case MyUtility.process(item) do
         {:ok, processed} -> {:ok, processed}
         {:error, err} -> {:error, {item, err}} # Include original item in error
      end
    end
    ```
- **Error Handling**: The `Task.async_stream` collects results including errors. The Reduce Node must explicitly handle potential `{:error, reason}` tuples in the results list.
- **Resource Management**: Be mindful of `max_concurrency` and `timeout` options in `Task.async_stream` to avoid overwhelming system resources or external APIs.
- **State**: The large list of items might be passed via the shared state, or the Setup Node might pass references (e.g., IDs to fetch from a DB) to keep the state map smaller, with the Map Node fetching details within `process_single_item/1`. 