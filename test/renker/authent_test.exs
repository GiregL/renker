defmodule Renker.AuthentTest do
  use Renker.DataCase

  alias Renker.Authent

  import Renker.AuthentFixtures
  alias Renker.Authent.{Utilisateur, UtilisateurToken}

  describe "get_utilisateur_by_email/1" do
    test "does not return the utilisateur if the email does not exist" do
      refute Authent.get_utilisateur_by_email("unknown@example.com")
    end

    test "returns the utilisateur if the email exists" do
      %{id: id} = utilisateur = utilisateur_fixture()
      assert %Utilisateur{id: ^id} = Authent.get_utilisateur_by_email(utilisateur.email)
    end
  end

  describe "get_utilisateur_by_email_and_password/2" do
    test "does not return the utilisateur if the email does not exist" do
      refute Authent.get_utilisateur_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the utilisateur if the password is not valid" do
      utilisateur = utilisateur_fixture()
      refute Authent.get_utilisateur_by_email_and_password(utilisateur.email, "invalid")
    end

    test "returns the utilisateur if the email and password are valid" do
      %{id: id} = utilisateur = utilisateur_fixture()

      assert %Utilisateur{id: ^id} =
               Authent.get_utilisateur_by_email_and_password(utilisateur.email, valid_utilisateur_password())
    end
  end

  describe "get_utilisateur!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Authent.get_utilisateur!(-1)
      end
    end

    test "returns the utilisateur with the given id" do
      %{id: id} = utilisateur = utilisateur_fixture()
      assert %Utilisateur{id: ^id} = Authent.get_utilisateur!(utilisateur.id)
    end
  end

  describe "register_utilisateur/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Authent.register_utilisateur(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Authent.register_utilisateur(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Authent.register_utilisateur(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = utilisateur_fixture()
      {:error, changeset} = Authent.register_utilisateur(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Authent.register_utilisateur(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers utilisateurs with a hashed password" do
      email = unique_utilisateur_email()
      {:ok, utilisateur} = Authent.register_utilisateur(valid_utilisateur_attributes(email: email))
      assert utilisateur.email == email
      assert is_binary(utilisateur.hashed_password)
      assert is_nil(utilisateur.confirmed_at)
      assert is_nil(utilisateur.password)
    end
  end

  describe "change_utilisateur_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Authent.change_utilisateur_registration(%Utilisateur{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_utilisateur_email()
      password = valid_utilisateur_password()

      changeset =
        Authent.change_utilisateur_registration(
          %Utilisateur{},
          valid_utilisateur_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_utilisateur_email/2" do
    test "returns a utilisateur changeset" do
      assert %Ecto.Changeset{} = changeset = Authent.change_utilisateur_email(%Utilisateur{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_utilisateur_email/3" do
    setup do
      %{utilisateur: utilisateur_fixture()}
    end

    test "requires email to change", %{utilisateur: utilisateur} do
      {:error, changeset} = Authent.apply_utilisateur_email(utilisateur, valid_utilisateur_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{utilisateur: utilisateur} do
      {:error, changeset} =
        Authent.apply_utilisateur_email(utilisateur, valid_utilisateur_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{utilisateur: utilisateur} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Authent.apply_utilisateur_email(utilisateur, valid_utilisateur_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{utilisateur: utilisateur} do
      %{email: email} = utilisateur_fixture()
      password = valid_utilisateur_password()

      {:error, changeset} = Authent.apply_utilisateur_email(utilisateur, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{utilisateur: utilisateur} do
      {:error, changeset} =
        Authent.apply_utilisateur_email(utilisateur, "invalid", %{email: unique_utilisateur_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{utilisateur: utilisateur} do
      email = unique_utilisateur_email()
      {:ok, utilisateur} = Authent.apply_utilisateur_email(utilisateur, valid_utilisateur_password(), %{email: email})
      assert utilisateur.email == email
      assert Authent.get_utilisateur!(utilisateur.id).email != email
    end
  end

  describe "deliver_utilisateur_update_email_instructions/3" do
    setup do
      %{utilisateur: utilisateur_fixture()}
    end

    test "sends token through notification", %{utilisateur: utilisateur} do
      token =
        extract_utilisateur_token(fn url ->
          Authent.deliver_utilisateur_update_email_instructions(utilisateur, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert utilisateur_token = Repo.get_by(UtilisateurToken, token: :crypto.hash(:sha256, token))
      assert utilisateur_token.utilisateur_id == utilisateur.id
      assert utilisateur_token.sent_to == utilisateur.email
      assert utilisateur_token.context == "change:current@example.com"
    end
  end

  describe "update_utilisateur_email/2" do
    setup do
      utilisateur = utilisateur_fixture()
      email = unique_utilisateur_email()

      token =
        extract_utilisateur_token(fn url ->
          Authent.deliver_utilisateur_update_email_instructions(%{utilisateur | email: email}, utilisateur.email, url)
        end)

      %{utilisateur: utilisateur, token: token, email: email}
    end

    test "updates the email with a valid token", %{utilisateur: utilisateur, token: token, email: email} do
      assert Authent.update_utilisateur_email(utilisateur, token) == :ok
      changed_utilisateur = Repo.get!(Utilisateur, utilisateur.id)
      assert changed_utilisateur.email != utilisateur.email
      assert changed_utilisateur.email == email
      assert changed_utilisateur.confirmed_at
      assert changed_utilisateur.confirmed_at != utilisateur.confirmed_at
      refute Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end

    test "does not update email with invalid token", %{utilisateur: utilisateur} do
      assert Authent.update_utilisateur_email(utilisateur, "oops") == :error
      assert Repo.get!(Utilisateur, utilisateur.id).email == utilisateur.email
      assert Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end

    test "does not update email if utilisateur email changed", %{utilisateur: utilisateur, token: token} do
      assert Authent.update_utilisateur_email(%{utilisateur | email: "current@example.com"}, token) == :error
      assert Repo.get!(Utilisateur, utilisateur.id).email == utilisateur.email
      assert Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end

    test "does not update email if token expired", %{utilisateur: utilisateur, token: token} do
      {1, nil} = Repo.update_all(UtilisateurToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Authent.update_utilisateur_email(utilisateur, token) == :error
      assert Repo.get!(Utilisateur, utilisateur.id).email == utilisateur.email
      assert Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end
  end

  describe "change_utilisateur_password/2" do
    test "returns a utilisateur changeset" do
      assert %Ecto.Changeset{} = changeset = Authent.change_utilisateur_password(%Utilisateur{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Authent.change_utilisateur_password(%Utilisateur{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_utilisateur_password/3" do
    setup do
      %{utilisateur: utilisateur_fixture()}
    end

    test "validates password", %{utilisateur: utilisateur} do
      {:error, changeset} =
        Authent.update_utilisateur_password(utilisateur, valid_utilisateur_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{utilisateur: utilisateur} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Authent.update_utilisateur_password(utilisateur, valid_utilisateur_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{utilisateur: utilisateur} do
      {:error, changeset} =
        Authent.update_utilisateur_password(utilisateur, "invalid", %{password: valid_utilisateur_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{utilisateur: utilisateur} do
      {:ok, utilisateur} =
        Authent.update_utilisateur_password(utilisateur, valid_utilisateur_password(), %{
          password: "new valid password"
        })

      assert is_nil(utilisateur.password)
      assert Authent.get_utilisateur_by_email_and_password(utilisateur.email, "new valid password")
    end

    test "deletes all tokens for the given utilisateur", %{utilisateur: utilisateur} do
      _ = Authent.generate_utilisateur_session_token(utilisateur)

      {:ok, _} =
        Authent.update_utilisateur_password(utilisateur, valid_utilisateur_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end
  end

  describe "generate_utilisateur_session_token/1" do
    setup do
      %{utilisateur: utilisateur_fixture()}
    end

    test "generates a token", %{utilisateur: utilisateur} do
      token = Authent.generate_utilisateur_session_token(utilisateur)
      assert utilisateur_token = Repo.get_by(UtilisateurToken, token: token)
      assert utilisateur_token.context == "session"

      # Creating the same token for another utilisateur should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UtilisateurToken{
          token: utilisateur_token.token,
          utilisateur_id: utilisateur_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_utilisateur_by_session_token/1" do
    setup do
      utilisateur = utilisateur_fixture()
      token = Authent.generate_utilisateur_session_token(utilisateur)
      %{utilisateur: utilisateur, token: token}
    end

    test "returns utilisateur by token", %{utilisateur: utilisateur, token: token} do
      assert session_utilisateur = Authent.get_utilisateur_by_session_token(token)
      assert session_utilisateur.id == utilisateur.id
    end

    test "does not return utilisateur for invalid token" do
      refute Authent.get_utilisateur_by_session_token("oops")
    end

    test "does not return utilisateur for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UtilisateurToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Authent.get_utilisateur_by_session_token(token)
    end
  end

  describe "delete_utilisateur_session_token/1" do
    test "deletes the token" do
      utilisateur = utilisateur_fixture()
      token = Authent.generate_utilisateur_session_token(utilisateur)
      assert Authent.delete_utilisateur_session_token(token) == :ok
      refute Authent.get_utilisateur_by_session_token(token)
    end
  end

  describe "deliver_utilisateur_confirmation_instructions/2" do
    setup do
      %{utilisateur: utilisateur_fixture()}
    end

    test "sends token through notification", %{utilisateur: utilisateur} do
      token =
        extract_utilisateur_token(fn url ->
          Authent.deliver_utilisateur_confirmation_instructions(utilisateur, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert utilisateur_token = Repo.get_by(UtilisateurToken, token: :crypto.hash(:sha256, token))
      assert utilisateur_token.utilisateur_id == utilisateur.id
      assert utilisateur_token.sent_to == utilisateur.email
      assert utilisateur_token.context == "confirm"
    end
  end

  describe "confirm_utilisateur/1" do
    setup do
      utilisateur = utilisateur_fixture()

      token =
        extract_utilisateur_token(fn url ->
          Authent.deliver_utilisateur_confirmation_instructions(utilisateur, url)
        end)

      %{utilisateur: utilisateur, token: token}
    end

    test "confirms the email with a valid token", %{utilisateur: utilisateur, token: token} do
      assert {:ok, confirmed_utilisateur} = Authent.confirm_utilisateur(token)
      assert confirmed_utilisateur.confirmed_at
      assert confirmed_utilisateur.confirmed_at != utilisateur.confirmed_at
      assert Repo.get!(Utilisateur, utilisateur.id).confirmed_at
      refute Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end

    test "does not confirm with invalid token", %{utilisateur: utilisateur} do
      assert Authent.confirm_utilisateur("oops") == :error
      refute Repo.get!(Utilisateur, utilisateur.id).confirmed_at
      assert Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end

    test "does not confirm email if token expired", %{utilisateur: utilisateur, token: token} do
      {1, nil} = Repo.update_all(UtilisateurToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Authent.confirm_utilisateur(token) == :error
      refute Repo.get!(Utilisateur, utilisateur.id).confirmed_at
      assert Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end
  end

  describe "deliver_utilisateur_reset_password_instructions/2" do
    setup do
      %{utilisateur: utilisateur_fixture()}
    end

    test "sends token through notification", %{utilisateur: utilisateur} do
      token =
        extract_utilisateur_token(fn url ->
          Authent.deliver_utilisateur_reset_password_instructions(utilisateur, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert utilisateur_token = Repo.get_by(UtilisateurToken, token: :crypto.hash(:sha256, token))
      assert utilisateur_token.utilisateur_id == utilisateur.id
      assert utilisateur_token.sent_to == utilisateur.email
      assert utilisateur_token.context == "reset_password"
    end
  end

  describe "get_utilisateur_by_reset_password_token/1" do
    setup do
      utilisateur = utilisateur_fixture()

      token =
        extract_utilisateur_token(fn url ->
          Authent.deliver_utilisateur_reset_password_instructions(utilisateur, url)
        end)

      %{utilisateur: utilisateur, token: token}
    end

    test "returns the utilisateur with valid token", %{utilisateur: %{id: id}, token: token} do
      assert %Utilisateur{id: ^id} = Authent.get_utilisateur_by_reset_password_token(token)
      assert Repo.get_by(UtilisateurToken, utilisateur_id: id)
    end

    test "does not return the utilisateur with invalid token", %{utilisateur: utilisateur} do
      refute Authent.get_utilisateur_by_reset_password_token("oops")
      assert Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end

    test "does not return the utilisateur if token expired", %{utilisateur: utilisateur, token: token} do
      {1, nil} = Repo.update_all(UtilisateurToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Authent.get_utilisateur_by_reset_password_token(token)
      assert Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end
  end

  describe "reset_utilisateur_password/2" do
    setup do
      %{utilisateur: utilisateur_fixture()}
    end

    test "validates password", %{utilisateur: utilisateur} do
      {:error, changeset} =
        Authent.reset_utilisateur_password(utilisateur, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{utilisateur: utilisateur} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Authent.reset_utilisateur_password(utilisateur, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{utilisateur: utilisateur} do
      {:ok, updated_utilisateur} = Authent.reset_utilisateur_password(utilisateur, %{password: "new valid password"})
      assert is_nil(updated_utilisateur.password)
      assert Authent.get_utilisateur_by_email_and_password(utilisateur.email, "new valid password")
    end

    test "deletes all tokens for the given utilisateur", %{utilisateur: utilisateur} do
      _ = Authent.generate_utilisateur_session_token(utilisateur)
      {:ok, _} = Authent.reset_utilisateur_password(utilisateur, %{password: "new valid password"})
      refute Repo.get_by(UtilisateurToken, utilisateur_id: utilisateur.id)
    end
  end

  describe "inspect/2 for the Utilisateur module" do
    test "does not include password" do
      refute inspect(%Utilisateur{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
