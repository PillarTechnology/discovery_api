defmodule DiscoveryApi.Auth.Guardian do
  @moduledoc false
  use Guardian, otp_app: :discovery_api
  require Logger

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    id = claims["sub"]
    user = Application.get_env(:discovery_api, :ldap_user)
    pass = Application.get_env(:discovery_api, :ldap_pass)
    Paddle.authenticate(user, pass)

    with {:ok, resources} <- Paddle.get(filter: [uid: id]) do
      {:ok, List.first(resources)}
    else
      error ->
        Logger.error(inspect(error))
        error
    end
  end
end
