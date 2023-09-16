defmodule RenkerWeb.UtilisateurConfirmationLiveTest do
  use RenkerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Renker.AuthentFixtures

  alias Renker.Authent
  alias Renker.Repo

  setup do
    %{utilisateur: utilisateur_fixture()}
  end

  describe "Confirm utilisateur" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/utilisateurs/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, utilisateur: utilisateur} do
      token =
        extract_utilisateur_token(fn url ->
          Authent.deliver_utilisateur_confirmation_instructions(utilisateur, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Utilisateur confirmed successfully"

      assert Authent.get_utilisateur!(utilisateur.id).confirmed_at
      refute get_session(conn, :utilisateur_token)
      assert Repo.all(Authent.UtilisateurToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Utilisateur confirmation link is invalid or it has expired"

      # when logged in
      {:ok, lv, _html} =
        build_conn()
        |> log_in_utilisateur(utilisateur)
        |> live(~p"/utilisateurs/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, utilisateur: utilisateur} do
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Utilisateur confirmation link is invalid or it has expired"

      refute Authent.get_utilisateur!(utilisateur.id).confirmed_at
    end
  end
end
