defmodule DiscoveryApiWeb.VisualizationController do
  require Logger
  use DiscoveryApiWeb, :controller

  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations

  plug(:accepts, DiscoveryApiWeb.VisualizationView.accepted_formats())

  def show(conn, %{"id" => id}) do
    render_authorized_visualization(conn, Visualizations.get_visualization(id))
  end

  defp render_authorized_visualization(conn, {:error, _}), do: render_error(conn, 404, "Not Found")

  defp render_authorized_visualization(conn, {:ok, visualization}), do: render(conn, :visualization, %{visualization: visualization})

  def create(conn, %{"query" => query, "title" => title}) do
    with {:ok, user} <- Users.get_user(conn.assigns.current_user),
         {:ok, visualization} <- Visualizations.create(%{query: query, title: title, owner: user}) do
      conn
      |> put_status(:created)
      |> render(:visualization, %{visualization: visualization})
    else
      _ -> render_error(conn, 400, "Bad Request")
    end
  end

  def update(conn, attribute_changes) do
    case Visualizations.update(Map.get(conn.path_params, "id"), attribute_changes) do
      {:ok, visualization} ->
        conn
        |> put_status(:ok)
        |> render(:visualization, %{visualization: visualization})

      _ ->
        render_error(conn, 400, "Bad Request")
    end
  end
end
