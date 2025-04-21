# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

config :pocket_flex, PocketFlex.StateStorage.ETS, table_name: :pocket_flex_shared_state
