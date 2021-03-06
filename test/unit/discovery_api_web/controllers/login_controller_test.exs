defmodule DiscoveryApiWeb.LoginControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias Plug.Conn

  describe "GET /login" do
    setup do
      allow(PaddleWrapper.authenticate("bob", "12345"), return: :ok)
      allow(PaddleWrapper.authenticate(nil, nil), return: {:error, :invalidCredentials})

      conn =
        build_conn()
        |> Conn.put_req_header("authorization", "Basic " <> Base.encode64("bob:12345"))
        |> get("/api/v1/login")

      conn |> response(200)

      {:ok, %{response_conn: conn}}
    end

    test "returns cookie with httponly", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      assert Map.get(cookie, "HttpOnly") == true
    end

    test "returns cookie with secure", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      assert Map.get(cookie, "secure") == true
    end

    test "returns cookie token with type 'refresh'", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      {:ok, token} =
        cookie
        |> Map.get(Helper.default_guardian_token_key())
        |> DiscoveryApi.Auth.Guardian.decode_and_verify()

      assert Map.get(token, "typ") == "refresh"
    end

    test "returns token header with type 'access'", %{response_conn: conn} do
      {:ok, token} =
        conn
        |> Conn.get_resp_header("token")
        |> List.first()
        |> DiscoveryApi.Auth.Guardian.decode_and_verify()

      assert Map.get(token, "typ") == "access"
    end
  end

  test "GET /login fails", %{conn: conn} do
    allow(PaddleWrapper.authenticate(any(), any()), return: {:error, :invalidCredentials})

    conn
    |> Conn.put_req_header("authorization", "Basic " <> Base.encode64("bob:12345"))
    |> get("/api/v1/login")
    |> response(401)
  end

  describe "GET /logout" do
    setup do
      user = "bob"
      {:ok, token, claims} = Guardian.encode_and_sign(DiscoveryApi.Auth.Guardian, user)
      allow PaddleWrapper.authenticate(any(), any()), return: :does_not_matter
      allow PaddleWrapper.get(filter: any()), return: {:ok, [Helper.ldap_user()]}
      {:ok, %{user: user, jwt: token, claims: claims}}
    end

    test "GET /logout", %{conn: conn, jwt: jwt} do
      cookie =
        conn
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> put_req_cookie(Helper.default_guardian_token_key(), jwt)
        |> get("/api/v1/logout")
        |> Helper.extract_response_cookie_as_map()

      assert cookie["guardian_default_token"] == ""
    end
  end
end
