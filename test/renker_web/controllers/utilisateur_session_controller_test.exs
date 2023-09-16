defmodule RenkerWeb.UtilisateurSessionControllerTest do
  use RenkerWeb.ConnCase

  import Renker.AuthentFixtures

  setup do
    %{utilisateur: utilisateur_fixture()}
  end

  describe "POST /utilisateurs/log_in" do
    test "logs the utilisateur in", %{conn: conn, utilisateur: utilisateur} do
      conn =
        post(conn, ~p"/utilisateurs/log_in", %{
          "utilisateur" => %{"email" => utilisateur.email, "password" => valid_utilisateur_password()}
        })

      assert get_session(conn, :utilisateur_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ utilisateur.email
      assert response =~ ~p"/utilisateurs/settings"
      assert response =~ ~p"/utilisateurs/log_out"
    end

    test "logs the utilisateur in with remember me", %{conn: conn, utilisateur: utilisateur} do
      conn =
        post(conn, ~p"/utilisateurs/log_in", %{
          "utilisateur" => %{
            "email" => utilisateur.email,
            "password" => valid_utilisateur_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_renker_web_utilisateur_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the utilisateur in with return to", %{conn: conn, utilisateur: utilisateur} do
      conn =
        conn
        |> init_test_session(utilisateur_return_to: "/foo/bar")
        |> post(~p"/utilisateurs/log_in", %{
          "utilisateur" => %{
            "email" => utilisateur.email,
            "password" => valid_utilisateur_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, utilisateur: utilisateur} do
      conn =
        conn
        |> post(~p"/utilisateurs/log_in", %{
          "_action" => "registered",
          "utilisateur" => %{
            "email" => utilisateur.email,
            "password" => valid_utilisateur_password()
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "login following password update", %{conn: conn, utilisateur: utilisateur} do
      conn =
        conn
        |> post(~p"/utilisateurs/log_in", %{
          "_action" => "password_updated",
          "utilisateur" => %{
            "email" => utilisateur.email,
            "password" => valid_utilisateur_password()
          }
        })

      assert redirected_to(conn) == ~p"/utilisateurs/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/utilisateurs/log_in", %{
          "utilisateur" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/utilisateurs/log_in"
    end
  end

  describe "DELETE /utilisateurs/log_out" do
    test "logs the utilisateur out", %{conn: conn, utilisateur: utilisateur} do
      conn = conn |> log_in_utilisateur(utilisateur) |> delete(~p"/utilisateurs/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :utilisateur_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the utilisateur is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/utilisateurs/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :utilisateur_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
