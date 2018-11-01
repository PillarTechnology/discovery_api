require Logger

defmodule DiscoveryApiWeb.DatasetSearchController do
  use DiscoveryApiWeb, :controller


  def search(conn, params) do
    sort_by = Map.get(params, "sort", "name_asc")
    limit = Map.get(params, "limit", "10") |> String.to_integer
    offset = Map.get(params, "offset", "0") |> String.to_integer
    query = Map.get(params, "query", "")

    result =  Data.DatasetSearchinator.search(query: query)

    put_view(conn, DiscoveryApiWeb.DatasetListView)
    |> render(:fetch_dataset_summaries, datasets: result, sort: sort_by, offset: offset, limit: limit)
  end

end