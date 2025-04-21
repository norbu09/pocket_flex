defmodule PocketFlex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @table_name :pocket_flex_shared_state

  @impl true
  def start(_type, _args) do
    children = [
      # Initialize the shared ETS table for state storage
      {PocketFlex.StateStorage.ETS, []}
    ]

    if :ets.info(@table_name) == :undefined do
      :ets.new(@table_name, [:set, :public, :named_table])
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PocketFlex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
