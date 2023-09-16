defmodule RenkerWeb.UtilisateurSettingsLiveTest do
  use RenkerWeb.ConnCase

  alias Renker.Authent
  import Phoenix.LiveViewTest
  import Renker.AuthentFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_utilisateur(utilisateur_fixture())
        |> live(~p"/utilisateurs/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if utilisateur is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/utilisateurs/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/utilisateurs/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_utilisateur_password()
      utilisateur = utilisateur_fixture(%{password: password})
      %{conn: log_in_utilisateur(conn, utilisateur), utilisateur: utilisateur, password: password}
    end

    test "updates the utilisateur email", %{conn: conn, password: password, utilisateur: utilisateur} do
      new_email = unique_utilisateur_email()

      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "utilisateur" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Authent.get_utilisateur_by_email(utilisateur.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "utilisateur" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, utilisateur: utilisateur} do
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "utilisateur" => %{"email" => utilisateur.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_utilisateur_password()
      utilisateur = utilisateur_fixture(%{password: password})
      %{conn: log_in_utilisateur(conn, utilisateur), utilisateur: utilisateur, password: password}
    end

    test "updates the utilisateur password", %{conn: conn, utilisateur: utilisateur, password: password} do
      new_password = valid_utilisateur_password()

      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "utilisateur" => %{
            "email" => utilisateur.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/utilisateurs/settings"

      assert get_session(new_password_conn, :utilisateur_token) != get_session(conn, :utilisateur_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Authent.get_utilisateur_by_email_and_password(utilisateur.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "utilisateur" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/utilisateurs/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "utilisateur" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      utilisateur = utilisateur_fixture()
      email = unique_utilisateur_email()

      token =
        extract_utilisateur_token(fn url ->
          Authent.deliver_utilisateur_update_email_instructions(%{utilisateur | email: email}, utilisateur.email, url)
        end)

      %{conn: log_in_utilisateur(conn, utilisateur), token: token, email: email, utilisateur: utilisateur}
    end

    test "updates the utilisateur email once", %{conn: conn, utilisateur: utilisateur, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/utilisateurs/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/utilisateurs/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Authent.get_utilisateur_by_email(utilisateur.email)
      assert Authent.get_utilisateur_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/utilisateurs/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/utilisateurs/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, utilisateur: utilisateur} do
      {:error, redirect} = live(conn, ~p"/utilisateurs/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/utilisateurs/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Authent.get_utilisateur_by_email(utilisateur.email)
    end

    test "redirects if utilisateur is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/utilisateurs/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/utilisateurs/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
