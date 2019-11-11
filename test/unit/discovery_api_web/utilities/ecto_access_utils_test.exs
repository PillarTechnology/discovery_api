defmodule DiscoveryApiWeb.Utilities.EctoAccessUtilsTest do
  use ExUnit.Case
  use Placebo

  import Checkov

  alias DiscoveryApiWeb.Utilities.EctoAccessUtils
  alias DiscoveryApiWeb.Utilities.LdapAccessUtils
  alias DiscoveryApi.Services.{PrestoService, PaddleService}
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

  setup do
    pub_model = Helper.sample_model(%{private: false})
    priv_model = Helper.sample_model(%{private: true})

    allow(Users.get_user_with_organizations("bob", :subject_id),
      return: {:ok, %{organizations: [%{id: "notrealid"}]}}
    )

    allow(Users.get_user_with_organizations("steve", :subject_id),
      return: {:ok, %{organizations: [%{id: priv_model.organizationDetails.id}]}}
    )

    {:ok, {pub_model, priv_model}}
  end

  data_test "has_access?/2 with no user logged in", {pub_model, priv_model} do
    where([
      [:model, :user, :expected],
      [pub_model, nil, true],
      [priv_model, nil, false],
      [pub_model, "bob", true],
      [priv_model, "bob", false],
      [priv_model, "steve", true]
    ])
  end
end
