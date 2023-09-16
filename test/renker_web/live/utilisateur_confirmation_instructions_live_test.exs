defmodule RenkerWeb.UtilisateurConfirmationInstructionsLiveTest do
  use RenkerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Renker.AuthentFixtures

  alias Renker.Authent
  alias Renker.Repo

  setup do
    %{utilisateur: utilisateur_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/utilisateurs/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, utilisateur: utilisateur} do
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", utilisateur: %{email: utilisateur.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Authent.UtilisateurToken, utilisateur_id: utilisateur.id).context == "confirm"
    end

    test "does not send confirmation token if utilisateur is confirmed", %{conn: conn, utilisateur: utilisateur} do
      Repo.update!(Authent.Utilisateur.confirm_changeset(utilisateur))

      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", utilisateur: %{email: utilisateur.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Authent.UtilisateurToken, utilisateur_id: utilisateur.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", utilisateur: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Authent.UtilisateurToken) == []
    end
  end
end
