use Mix.Config

config :discovery_api,
  data_lake_url: System.get_env("DATA_LAKE_URL")