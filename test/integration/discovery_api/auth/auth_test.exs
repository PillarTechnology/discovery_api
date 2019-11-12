defmodule DiscoveryApi.Auth.AuthTest do
  use ExUnit.Case
  use Divo, services: [:"ecto-postgres", :ldap, :redis, :presto, :zookeeper, :kafka]
  use DiscoveryApi.DataCase

  import ExUnit.CaptureLog

  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Test.AuthHelper
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Repo

  @inactive_token "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJkaXNjb3ZlcnlfYXBpIiwiZXhwIjoxNTU3NzczNTMzLCJpYXQiOjE1NTUzNTQzMzMsImlzcyI6ImRpc2NvdmVyeV9hcGkiLCJqdGkiOiIxYmJkMmUzMy01ZDc1LTRjNTYtYjQ4OS1mOGMxNzViZDg1NDEiLCJuYmYiOjE1NTUzNTQzMzIsInN1YiI6IkJhZFVzZXIiLCJ0eXAiOiJhY2Nlc3MifQ.TzTIVFiSJaPOioTiFYgvfg15BPzFCHx6qj1W1_vQeKPvo_Q4xuY_uA3-h1nobKq35fYu73TQdp_DYwwPQC5PDQ"
  @organization_1_name "organization_one"
  @organization_2_name "organization_two"
  @organization_1_user "FirstUser"
  @organization_2_user "SecondUser"

  setup_all do
    Helper.wait_for_brook_to_be_ready()

    membership = %{
      @organization_1_name => [
        @organization_1_user
      ],
      @organization_2_name => [
        @organization_2_user
      ]
    }

    %{
      @organization_1_name => organization_1,
      @organization_2_name => organization_2
    } = Helper.setup_ldap(membership)

    private_model_that_belongs_to_org_1 =
      Helper.sample_model(%{
        private: true,
        organization: @organization_1_name,
        organizationDetails: organization_1,
        keywords: ["dataset", "facet1"]
      })

    private_model_that_belongs_to_org_2 =
      Helper.sample_model(%{
        private: true,
        organization: @organization_2_name,
        organizationDetails: organization_2,
        keywords: ["dataset", "facet2"]
      })

    public_model_that_belongs_to_org_1 =
      Helper.sample_model(%{
        private: false,
        organization: @organization_1_name,
        organizationDetails: organization_1,
        keywords: ["dataset", "public_facet"]
      })

    Model.save(private_model_that_belongs_to_org_1)
    Model.save(private_model_that_belongs_to_org_2)
    Model.save(public_model_that_belongs_to_org_1)

    %{status_code: 200, body: "#{@organization_1_user} logged in.", headers: headers} =
      "http://localhost:4000/api/v1/login"
      |> HTTPoison.get!([], hackney: [basic_auth: {@organization_1_user, "admin"}])
      |> Map.from_struct()

    {"token", token} = Enum.find(headers, fn {header, _value} -> header == "token" end)

    {:ok,
     %{
       authenticated_token_for_org_1: token,
       private_model_that_belongs_to_org_1: private_model_that_belongs_to_org_1,
       private_model_that_belongs_to_org_2: private_model_that_belongs_to_org_2,
       public_model_that_belongs_to_org_1: public_model_that_belongs_to_org_1
     }}
  end

  @moduletag capture_log: true
  test "Successfully login via the login url with valid password" do
    %{status_code: status_code, body: body} =
      "http://localhost:4000/api/v1/login"
      |> HTTPoison.get!([], hackney: [basic_auth: {@organization_1_user, "admin"}])
      |> Map.from_struct()

    assert "#{@organization_1_user} logged in." == body
    assert status_code == 200
  end

  @moduletag capture_log: true
  test "Fails attempting to login via the login url with invalid password" do
    %{status_code: status_code, body: body} =
      "http://localhost:4000/api/v1/login"
      |> HTTPoison.get!([], hackney: [basic_auth: {@organization_1_user, "badpassword"}])
      |> Map.from_struct()

    result = Jason.decode!(body, keys: :atoms)
    assert result.message == "Not Authorized"
    assert status_code == 401
  end

  @moduletag capture_log: true
  test "Is able to access a restricted dataset with a cookie generated by login", setup_map do
    %{status_code: 200, body: "FirstUser logged in.", headers: headers} =
      "http://localhost:4000/api/v1/login"
      |> HTTPoison.get!([], hackney: [basic_auth: {@organization_1_user, "admin"}])
      |> Map.from_struct()

    {"set-cookie", cookie_string} = Enum.find(headers, fn {header, _value} -> header == "set-cookie" end)
    token = Helper.extract_token(cookie_string)

    %{status_code: status_code, body: body} =
      "http://localhost:4000/api/v1/dataset/#{setup_map[:private_model_that_belongs_to_org_1].id}/"
      |> HTTPoison.get!(Cookie: "#{Helper.default_guardian_token_key()}=#{token}")

    result = Jason.decode!(body, keys: :atoms)

    assert setup_map[:private_model_that_belongs_to_org_1].id == result.id
    assert status_code == 200
  end

  @moduletag capture_log: true
  test "Is able to access a restricted dataset with a token generated by login", setup_map do
    %{status_code: status_code, body: body} =
      "http://localhost:4000/api/v1/dataset/#{setup_map[:private_model_that_belongs_to_org_1].id}/"
      |> HTTPoison.get!(Authorization: "Bearer #{setup_map[:authenticated_token_for_org_1]}")

    result = Jason.decode!(body, keys: :atoms)

    assert result.id == setup_map[:private_model_that_belongs_to_org_1].id
    assert 200 == status_code
  end

  @moduletag capture_log: true
  test "Is not able to access a restricted dataset with a bad cookie token", setup_map do
    %{status_code: status_code, body: body} =
      "http://localhost:4000/api/v1/dataset/#{setup_map[:private_model_that_belongs_to_org_1].id}/"
      |> HTTPoison.get!(Cookie: "#{Helper.default_guardian_token_key()}=wedidthebadthing")

    result = Jason.decode!(body, keys: :atoms)

    assert result.message == "Not Found"
    assert status_code == 404
  end

  @moduletag capture_log: true
  test "Is not able to access a restricted dataset with a bad token", setup_map do
    %{status_code: status_code, body: body} =
      "http://localhost:4000/api/v1/dataset/#{setup_map[:private_model_that_belongs_to_org_1].id}/"
      |> HTTPoison.get!(Authorization: "Bearer sdfsadfasdasdfas")

    result = Jason.decode!(body, keys: :atoms)

    assert result.message == "Not Found"
    assert status_code == 404
  end

  @moduletag capture_log: true
  test "Is not able to access a dataset where group membership does not exist", setup_map do
    %{status_code: status_code, body: body} =
      "http://localhost:4000/api/v1/dataset/#{setup_map[:private_model_that_belongs_to_org_2].id}/"
      |> HTTPoison.get!(Authorization: "Bearer #{setup_map[:authenticated_token_for_org_1]}")

    result = Jason.decode!(body, keys: :atoms)

    assert result.message == "Not Found"
    assert status_code == 404
  end

  describe "/api/v1/search" do
    test "filters all private datasets when no auth token provided", setup_map do
      %{status_code: _status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!()

      %{results: results} = Jason.decode!(body, keys: :atoms)
      result_ids = Enum.map(results, fn result -> result[:id] end)

      assert setup_map[:public_model_that_belongs_to_org_1].id in result_ids
      assert setup_map[:private_model_that_belongs_to_org_1].id not in result_ids
      assert setup_map[:private_model_that_belongs_to_org_2].id not in result_ids
    end

    test "only returns facets for authorized datasets", setup_map do
      %{status_code: _status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!(Authorization: "Bearer #{setup_map[:authenticated_token_for_org_1]}")

      %{metadata: %{facets: facets}} = Jason.decode!(body, keys: :atoms)

      assert Enum.find(facets[:keywords], fn facet -> facet[:name] == "facet1" end)[:count] == 1
      assert Enum.find(facets[:keywords], fn facet -> facet[:name] == "public_facet" end)[:count] == 1
      assert Enum.find(facets[:keywords], fn facet -> facet[:name] == "facet2" end) == nil
      assert Enum.find(facets[:keywords], fn facet -> facet[:name] == "dataset" end)[:count] == 2
      assert %{count: 2, name: setup_map.private_model_that_belongs_to_org_1.organization} in facets[:organization]
      assert %{count: 1, name: setup_map.private_model_that_belongs_to_org_2.organization} not in facets[:organization]
    end

    test "when the token is expired the response is a 404" do
      %{status_code: status_code} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!(Authorization: "Bearer #{@inactive_token}")

      assert status_code == 404
    end

    test "Allows access to private datasets when auth token provided and is permitted", setup_map do
      %{status_code: _status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!(Authorization: "Bearer #{setup_map[:authenticated_token_for_org_1]}")

      %{results: results} = Jason.decode!(body, keys: :atoms)

      result_ids = Enum.map(results, fn result -> result[:id] end)
      assert setup_map[:private_model_that_belongs_to_org_1].id in result_ids
      assert setup_map[:public_model_that_belongs_to_org_1].id in result_ids
      assert setup_map[:private_model_that_belongs_to_org_2].id not in result_ids
    end
  end

  describe "CookieMonster" do
    test "eats cookies when not from the appropriate origin (ajax)" do
      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("username", %{}, token_type: "refresh")

      %{status_code: status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!(
          Cookie: "something=true,#{Helper.default_guardian_token_key()}=#{token},somethingelse=false",
          Origin: "jessies.house.example.com"
        )

      response = Jason.decode!(body, keys: :atoms)
      assert response.message == "Not Found"
      assert status_code == 404
    end

    test "eats cookies when from a similar but different origin (ajax)" do
      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("username", %{}, token_type: "refresh")

      %{status_code: status_code} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!(
          Cookie: "something=true,#{Helper.default_guardian_token_key()}=#{token},somethingelse=false",
          Origin: "jessies-integrationtests.example.com"
        )

      assert status_code == 404
    end

    test "does not eat cookies when origin not included (non-ajax or local file)" do
      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("username", %{}, token_type: "refresh")

      %{status_code: status_code} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!(Cookie: "something=true,#{Helper.default_guardian_token_key()}=#{token},somethingelse=false")

      assert status_code == 200
    end

    test "does not eat cookies when origin=null (non-ajax or local file)" do
      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("username", %{}, token_type: "refresh")

      %{status_code: status_code} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!(
          Cookie: "something=true,#{Helper.default_guardian_token_key()}=#{token},somethingelse=false",
          Origin: "null"
        )

      assert status_code == 200
    end

    test "does not eat cookies when from the appropriate sub origin (ajax)" do
      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("username", %{}, token_type: "refresh")

      %{status_code: status_code} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!(
          Cookie: "something=true,#{Helper.default_guardian_token_key()}=#{token},somethingelse=false",
          Origin: "discovery.integrationtests.example.com"
        )

      assert status_code == 200
    end

    test "does not eat cookies when from the appropriate origin (ajax)" do
      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("username", %{}, token_type: "refresh")

      %{status_code: status_code} =
        "http://localhost:4000/api/v1/dataset/search/"
        |> HTTPoison.get!(
          Cookie: "something=true,#{Helper.default_guardian_token_key()}=#{token},somethingelse=false",
          Origin: "integrationtests.example.com"
        )

      assert status_code == 200
    end
  end

  describe "auth0 pipeline" do
    setup do
      jwks = AuthHelper.valid_jwks()

      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/jwks", fn conn ->
        Plug.Conn.resp(conn, :ok, Jason.encode!(jwks))
      end)

      Bypass.stub(bypass, "GET", "/userinfo", fn conn ->
        Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => "x@y.z"}))
      end)

      really_far_in_the_future = 3_000_000_000_000
      AuthHelper.set_allowed_guardian_drift(really_far_in_the_future)

      original_jwks_endpoint = Application.get_env(:discovery_api, :jwks_endpoint)
      original_user_info_endpoint = Application.get_env(:discovery_api, :user_info_endpoint)
      Application.put_env(:discovery_api, :jwks_endpoint, "http://localhost:#{bypass.port}/jwks")
      Application.put_env(:discovery_api, :user_info_endpoint, "http://localhost:#{bypass.port}/userinfo")

      on_exit(fn ->
        AuthHelper.set_allowed_guardian_drift(0)
        Application.put_env(:discovery_api, :jwks_endpoint, original_jwks_endpoint)
        Application.put_env(:discovery_api, :user_info_endpoint, original_user_info_endpoint)
      end)
    end

    test "/logged-in returns 'OK' when token is valid" do
      %{status_code: status_code} =
        "localhost:4000/api/v1/logged-in"
        |> HTTPoison.post!("",
          Authorization: "Bearer #{AuthHelper.valid_jwt()}"
        )

      assert status_code == 200
    end

    test "/logged-in saves logged in user" do
      subject_id = AuthHelper.valid_jwt_sub()
      HTTPoison.post!("localhost:4000/api/v1/logged-in", "", Authorization: "Bearer #{AuthHelper.valid_jwt()}")

      assert {:ok, actual} = Users.get_user(subject_id, :subject_id)

      assert subject_id == actual.subject_id
      assert "x@y.z" == actual.email
      assert actual.id != nil
    end

    test "/logged-in returns 'bad request' when token is invalid" do
      %{status_code: status_code} =
        "localhost:4000/api/v1/logged-in"
        |> HTTPoison.post!("",
          Authorization: "Bearer !NOPE!"
        )

      assert status_code == 400
    end

    test "POST /visualization adds owner data to the newly created visualization" do
      subject_id = log_valid_user_in()

      %{status_code: status_code, body: body} =
        post_with_authentication(
          "localhost:4000/api/v1/visualization",
          ~s({"query": "select * from tarps", "title": "My favorite title"}),
          AuthHelper.valid_jwt()
        )

      assert status_code == 201
      visualization = Visualizations.get_visualization_by_id(body.id) |> elem(1) |> Repo.preload(:owner)
      assert visualization.owner.subject_id == subject_id
    end

    test "POST /visualization returns 'bad request' when token is invalid" do
      %{status_code: status_code, body: body} =
        post_with_authentication(
          "localhost:4000/api/v1/visualization",
          ~s({"query": "select * from tarps", "title": "My favorite title"}),
          "!WRONG!"
        )

      assert status_code == 400
      assert body.message == "Bad Request"
    end

    test "GET /visualization/:id returns visualization for public table when user is anonymous", %{public_model_that_belongs_to_org_1: model} do
      # log_valid_user_in()
      capture_log(fn ->
        ~s|create table if not exists "#{model.systemName}" (id integer, name varchar)|
        |> Prestige.execute()
        |> Prestige.prefetch()
      end)
      visualization = create_visualization(model.systemName)

      %{status_code: status_code} =
      HTTPoison.get!(
          "localhost:4000/api/v1/visualization/#{visualization.public_id}",
          "Content-Type": "application/json"
        )

      assert status_code == 200
    end
  end

  defp log_valid_user_in() do
    HTTPoison.post!("localhost:4000/api/v1/logged-in", "", Authorization: "Bearer #{AuthHelper.valid_jwt()}")
    AuthHelper.valid_jwt_sub()
  end

  defp create_visualization(table_name \\ "table_name") do
    {:ok, owner} = Users.create_or_update("me|you", %{email: "bob@example.com"})

    {:ok, visualization} =
      Visualizations.create_visualization(%{query: "select * from #{table_name}", title: "My first visualization", owner: owner})

    visualization
  end

  defp post_with_authentication(url, body, bearer_token) do
    %{
      status_code: status_code,
      body: body_json
    } =
      HTTPoison.post!(
        url,
        body,
        Authorization: "Bearer #{bearer_token}",
        "Content-Type": "application/json"
      )

    %{status_code: status_code, body: Jason.decode!(body_json, keys: :atoms)}
  end

  defp get_with_authentication(url, bearer_token) do
    %{
      status_code: status_code,
      body: body_json
    } =
      HTTPoison.get!(
        url,
        Authorization: "Bearer #{bearer_token}",
        "Content-Type": "application/json"
      )

    %{status_code: status_code, body: Jason.decode!(body_json, keys: :atoms)}
  end
end
