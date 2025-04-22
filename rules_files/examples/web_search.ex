# lib/my_project/utils/web_search.ex
# Example: Utility for performing web searches using Req

defmodule MyProject.Utils.WebSearch do
  @moduledoc """
  Utility for performing web searches using Req.

  Demonstrates best practices for tool node integration in PocketFlex flows.
  """
  require Logger

  @search_api_key System.get_env("SEARCH_API_KEY")
  @search_endpoint "https://api.example-search.com/search"

  @doc """
  Performs a web search using the configured API.

  ## Parameters
    - query: String. The search query.

  ## Returns
    - {:ok, list_of_results} on success
    - {:error, reason} on failure
  """
  @spec search(String.t()) :: {:ok, list(map())} | {:error, any()}
  def search(query) do
    Logger.info("Performing web search for: #{query}")
    # Use Req to call a search API
    case Req.get(@search_endpoint, params: [q: query], headers: [authorization: "Bearer #{@search_api_key}"]) do
      {:ok, %{status: 200, body: %{"results" => results}}} -> 
        Logger.debug("Search successful. Found #{length(results)} results.")
        {:ok, results}
      {:ok, resp} ->
        Logger.error("Web search failed with status #{resp.status}: #{inspect(resp.body)}")
        {:error, {:unexpected_response, resp.status}}
      {:error, reason} ->
        Logger.error("Web search HTTP request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end