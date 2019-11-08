defmodule DiscoveryApiWeb.VisualizationController do
  require Logger
  use DiscoveryApiWeb, :controller

  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApiWeb.Utilities.AuthUtils

  plug(:accepts, DiscoveryApiWeb.VisualizationView.accepted_formats())

  def show(conn, %{"id" => id}) do
<<<<<<< HEAD
    case Visualizations.get_visualization_by_id(id) do
      {:error, _} -> render_error(conn, 404, "Not Found")
      {:ok, visualization} -> render(conn, :visualization, %{visualization: visualization})
    end
  end

=======
    with {:ok, %{query: query} = visualization} <- Visualizations.get_visualization(id),
    user <- Map.get(conn.assigns, :current_user, :anonymous_user) |> IO.inspect(),
         true <- AuthUtils.authorized_to_query?(query, user) do

      render(conn, :visualization, %{visualization: visualization})
    else
      {:error, _} -> render_error(conn, 404, "Not Found")
      false -> render_error(conn, 404, "Not Found")
    end
  end

  # defp render_authorized_visualization(conn, {:error, _}), do: render_error(conn, 404, "Not Found")

  # defp render_authorized_visualization(conn, {:ok, visualization}), do: render(conn, :visualization, %{visualization: visualization})

>>>>>>> Router, ldap auth, and tests
  def create(conn, %{"query" => query, "title" => title}) do
    with {:ok, user} <- Users.get_user(conn.assigns.current_user, :subject_id),
         {:ok, visualization} <- Visualizations.create(%{query: query, title: title, owner: user}) do
      conn
      |> put_status(:created)
      |> render(:visualization, %{visualization: visualization})
    else
      _ -> render_error(conn, 400, "Bad Request")
    end
  end

  def update(conn, %{"id" => public_id} = attribute_changes) do
    with {:ok, user} <- Users.get_user(conn.assigns.current_user, :subject_id),
         {:ok, visualization} <- Visualizations.update_visualization_by_id(public_id, attribute_changes, user) do
      render(conn, :visualization, %{visualization: visualization})
    else
      _ ->
        render_error(conn, 400, "Bad Request")
    end
  end
end
