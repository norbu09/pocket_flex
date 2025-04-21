---
layout: default
title: "Web Search Integration"
parent: "Tutorials"
nav_order: 4
---

# Tutorial: Web Search Integration

This tutorial demonstrates integrating an external tool, like a web search API, into a PocketFlex flow.

## 1. Define Utility

First, create a utility module to handle the web search API call. (We use a simplified example here; a real implementation would use `Req` and handle authentication/errors more robustly).

```elixir
# lib/my_search_app/utils/search_client.ex
defmodule MySearchApp.Utils.SearchClient do
  @moduledoc """Handles calls to an external web search API."""
  require Logger

  @api_key System.get_env("SEARCH_PROVIDER_API_KEY")
  @endpoint "https://api.searchprovider.com/search"

  @spec search(String.t(), keyword()) :: {:ok, list(map())} | {:error, any()}
  def search(query, opts \ []) do
    num_results = Keyword.get(opts, :num_results, 3)
    Logger.info("Searching web for '#{query}' (max #{num_results} results)...")
    
    # In a real scenario, use Req to make the HTTP call:
    # headers = [authorization: "Bearer #{@api_key}"]
    # params = [q: query, count: num_results]
    # case Req.get(@endpoint, headers: headers, params: params) do
    #   {:ok, %{status: 200, body: %{"results" => results}}} -> {:ok, results}
    #   ... error handling ...
    # end
    
    # Placeholder for example:
    {:ok, [
      %{title: "Result 1 for #{query}", snippet: "Snippet 1...", url: "http://example.com/1"},
      %{title: "Result 2 for #{query}", snippet: "Snippet 2...", url: "http://example.com/2"},
      %{title: "Result 3 for #{query}", snippet: "Snippet 3...", url: "http://example.com/3"}
    ] |> Enum.take(num_results)}
  end
end
```

## 2. Define Nodes

**Node: GetSearchQuery**
- `prep`: None.
- `exec`: Prompts user for a search query.
- `post`: Adds query to state as `:search_query`.

**Node: PerformSearch**
- `prep`: Reads `:search_query` from state.
- `exec`: Calls `MySearchApp.Utils.SearchClient.search/2` with the query. Returns `{:ok, results_list}` or `{:error, reason}`.
- `post`: Adds results to state as `:search_results`. Handles errors.

**Node: SummarizeResults (Optional LLM Step)**
- `prep`: Reads `:search_query` and `:search_results`.
- `exec`: Formats the search results into a context string. Creates a prompt asking an LLM to summarize the results for the original query. Calls `LLMCaller.invoke_llm/1`.
- `post`: Adds summary to state as `:search_summary`. Handles LLM errors.

**Node: DisplayResults**
- `prep`: Reads `:search_results` and optionally `:search_summary`.
- `exec`: Prints the results (and summary, if available) nicely formatted.
- `post`: Signals completion.

**Node: HandleSearchError**
- Standard error handling node.

## 3. Define Flow

```elixir
# lib/my_search_app/flow.ex
defmodule MySearchApp.Flow do
  alias MySearchApp.Nodes
  # alias PocketFlex

  def define_search_flow do
    PocketFlex.define(
      start_node: Nodes.GetSearchQuery,
      nodes: [
        %{module: Nodes.GetSearchQuery, transitions: %{default: Nodes.PerformSearch}},
        
        %{module: Nodes.PerformSearch, 
          transitions: %{
            default: Nodes.SummarizeResults, # Go to summarize
            error: Nodes.HandleSearchError
          }
        },

        %{module: Nodes.SummarizeResults, 
          transitions: %{
            default: Nodes.DisplayResults, 
            error: Nodes.DisplayResults # If LLM fails, still display raw results
          }
        },

        %{module: Nodes.DisplayResults, transitions: %{default: :end}},

        %{module: Nodes.HandleSearchError, transitions: %{default: :end}}
      ]
    )
  end
end
```

## 4. Run the Flow

```elixir
# lib/my_search_app.ex
defmodule MySearchApp do
  require Logger
  alias MySearchApp.Flow
  # alias PocketFlex

  def run_search do
    initial_state = %{}
    flow_definition = Flow.define_search_flow()

    Logger.info("Starting Web Search flow...")
    case PocketFlex.run(flow_definition, initial_state) do
      {:ok, final_state} ->
        Logger.info("Web Search flow completed.")
        IO.inspect(final_state, label: "Final State")
      {:error, reason, final_state} ->
        Logger.error("Web Search flow failed: #{inspect(reason)}")
        IO.inspect(final_state, label: "Final State on Error")
    end
  end
end

# To run:
# mix run -e "MySearchApp.run_search()"
```

This tutorial shows how external tools are wrapped in utility modules and invoked by dedicated PocketFlex nodes within a larger flow. 