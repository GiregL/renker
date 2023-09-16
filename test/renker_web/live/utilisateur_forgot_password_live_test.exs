defmodule RenkerWeb.UtilisateurForgotPasswordLiveTest do
  use RenkerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Renker.AuthentFixtures

  alias Renker.Authent
  alias Renker.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/utilisateurs/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/utilisateurs/register"}"]|, "Register")
      assert has_element?(lv, ~s|a[href="#{~p"/utilisateurs/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_utilisateur(utilisateur_fixture())
        |> live(~p"/utilisateurs/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{utilisateur: utilisateur_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, utilisateur: utilisateur} do
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", utilisateur: %{"email" => utilisateur.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(Authent.UtilisateurToken, utilisateur_id: utilisateur.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", utilisateur: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Authent.UtilisateurToken) == []
    end
  end
end
