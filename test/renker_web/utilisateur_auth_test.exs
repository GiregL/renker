defmodule RenkerWeb.UtilisateurAuthTest do
  use RenkerWeb.ConnCase

  alias Phoenix.LiveView
  alias Renker.Authent
  alias RenkerWeb.UtilisateurAuth
  import Renker.AuthentFixtures

  @remember_me_cookie "_renker_web_utilisateur_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, RenkerWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{utilisateur: utilisateur_fixture(), conn: conn}
  end

  describe "log_in_utilisateur/3" do
    test "stores the utilisateur token in the session", %{conn: conn, utilisateur: utilisateur} do
      conn = UtilisateurAuth.log_in_utilisateur(conn, utilisateur)
      assert token = get_session(conn, :utilisateur_token)
      assert get_session(conn, :live_socket_id) == "utilisateurs_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Authent.get_utilisateur_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, utilisateur: utilisateur} do
      conn = conn |> put_session(:to_be_removed, "value") |> UtilisateurAuth.log_in_utilisateur(utilisateur)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, utilisateur: utilisateur} do
      conn = conn |> put_session(:utilisateur_return_to, "/hello") |> UtilisateurAuth.log_in_utilisateur(utilisateur)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, utilisateur: utilisateur} do
      conn = conn |> fetch_cookies() |> UtilisateurAuth.log_in_utilisateur(utilisateur, %{"remember_me" => "true"})
      assert get_session(conn, :utilisateur_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :utilisateur_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_utilisateur/1" do
    test "erases session and cookies", %{conn: conn, utilisateur: utilisateur} do
      utilisateur_token = Authent.generate_utilisateur_session_token(utilisateur)

      conn =
        conn
        |> put_session(:utilisateur_token, utilisateur_token)
        |> put_req_cookie(@remember_me_cookie, utilisateur_token)
        |> fetch_cookies()
        |> UtilisateurAuth.log_out_utilisateur()

      refute get_session(conn, :utilisateur_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Authent.get_utilisateur_by_session_token(utilisateur_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "utilisateurs_sessions:abcdef-token"
      RenkerWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> UtilisateurAuth.log_out_utilisateur()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if utilisateur is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> UtilisateurAuth.log_out_utilisateur()
      refute get_session(conn, :utilisateur_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_utilisateur/2" do
    test "authenticates utilisateur from session", %{conn: conn, utilisateur: utilisateur} do
      utilisateur_token = Authent.generate_utilisateur_session_token(utilisateur)
      conn = conn |> put_session(:utilisateur_token, utilisateur_token) |> UtilisateurAuth.fetch_current_utilisateur([])
      assert conn.assigns.current_utilisateur.id == utilisateur.id
    end

    test "authenticates utilisateur from cookies", %{conn: conn, utilisateur: utilisateur} do
      logged_in_conn =
        conn |> fetch_cookies() |> UtilisateurAuth.log_in_utilisateur(utilisateur, %{"remember_me" => "true"})

      utilisateur_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> UtilisateurAuth.fetch_current_utilisateur([])

      assert conn.assigns.current_utilisateur.id == utilisateur.id
      assert get_session(conn, :utilisateur_token) == utilisateur_token

      assert get_session(conn, :live_socket_id) ==
               "utilisateurs_sessions:#{Base.url_encode64(utilisateur_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, utilisateur: utilisateur} do
      _ = Authent.generate_utilisateur_session_token(utilisateur)
      conn = UtilisateurAuth.fetch_current_utilisateur(conn, [])
      refute get_session(conn, :utilisateur_token)
      refute conn.assigns.current_utilisateur
    end
  end

  describe "on_mount: mount_current_utilisateur" do
    test "assigns current_utilisateur based on a valid utilisateur_token", %{conn: conn, utilisateur: utilisateur} do
      utilisateur_token = Authent.generate_utilisateur_session_token(utilisateur)
      session = conn |> put_session(:utilisateur_token, utilisateur_token) |> get_session()

      {:cont, updated_socket} =
        UtilisateurAuth.on_mount(:mount_current_utilisateur, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_utilisateur.id == utilisateur.id
    end

    test "assigns nil to current_utilisateur assign if there isn't a valid utilisateur_token", %{conn: conn} do
      utilisateur_token = "invalid_token"
      session = conn |> put_session(:utilisateur_token, utilisateur_token) |> get_session()

      {:cont, updated_socket} =
        UtilisateurAuth.on_mount(:mount_current_utilisateur, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_utilisateur == nil
    end

    test "assigns nil to current_utilisateur assign if there isn't a utilisateur_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        UtilisateurAuth.on_mount(:mount_current_utilisateur, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_utilisateur == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_utilisateur based on a valid utilisateur_token", %{conn: conn, utilisateur: utilisateur} do
      utilisateur_token = Authent.generate_utilisateur_session_token(utilisateur)
      session = conn |> put_session(:utilisateur_token, utilisateur_token) |> get_session()

      {:cont, updated_socket} =
        UtilisateurAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_utilisateur.id == utilisateur.id
    end

    test "redirects to login page if there isn't a valid utilisateur_token", %{conn: conn} do
      utilisateur_token = "invalid_token"
      session = conn |> put_session(:utilisateur_token, utilisateur_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: RenkerWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UtilisateurAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_utilisateur == nil
    end

    test "redirects to login page if there isn't a utilisateur_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: RenkerWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UtilisateurAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_utilisateur == nil
    end
  end

  describe "on_mount: :redirect_if_utilisateur_is_authenticated" do
    test "redirects if there is an authenticated  utilisateur ", %{conn: conn, utilisateur: utilisateur} do
      utilisateur_token = Authent.generate_utilisateur_session_token(utilisateur)
      session = conn |> put_session(:utilisateur_token, utilisateur_token) |> get_session()

      assert {:halt, _updated_socket} =
               UtilisateurAuth.on_mount(
                 :redirect_if_utilisateur_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated utilisateur", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               UtilisateurAuth.on_mount(
                 :redirect_if_utilisateur_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_utilisateur_is_authenticated/2" do
    test "redirects if utilisateur is authenticated", %{conn: conn, utilisateur: utilisateur} do
      conn = conn |> assign(:current_utilisateur, utilisateur) |> UtilisateurAuth.redirect_if_utilisateur_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if utilisateur is not authenticated", %{conn: conn} do
      conn = UtilisateurAuth.redirect_if_utilisateur_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_utilisateur/2" do
    test "redirects if utilisateur is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> UtilisateurAuth.require_authenticated_utilisateur([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/utilisateurs/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> UtilisateurAuth.require_authenticated_utilisateur([])

      assert halted_conn.halted
      assert get_session(halted_conn, :utilisateur_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> UtilisateurAuth.require_authenticated_utilisateur([])

      assert halted_conn.halted
      assert get_session(halted_conn, :utilisateur_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> UtilisateurAuth.require_authenticated_utilisateur([])

      assert halted_conn.halted
      refute get_session(halted_conn, :utilisateur_return_to)
    end

    test "does not redirect if utilisateur is authenticated", %{conn: conn, utilisateur: utilisateur} do
      conn = conn |> assign(:current_utilisateur, utilisateur) |> UtilisateurAuth.require_authenticated_utilisateur([])
      refute conn.halted
      refute conn.status
    end
  end
end
