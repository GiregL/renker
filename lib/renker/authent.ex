defmodule Renker.Authent do
  @moduledoc """
  The Authent context.
  """

  import Ecto.Query, warn: false
  alias Renker.Repo

  alias Renker.Authent.{Utilisateur, UtilisateurToken, UtilisateurNotifier}

  ## Database getters

  @doc """
  Gets a utilisateur by email.

  ## Examples

      iex> get_utilisateur_by_email("foo@example.com")
      %Utilisateur{}

      iex> get_utilisateur_by_email("unknown@example.com")
      nil

  """
  def get_utilisateur_by_email(email) when is_binary(email) do
    Repo.get_by(Utilisateur, email: email)
  end

  @doc """
  Gets a utilisateur by email and password.

  ## Examples

      iex> get_utilisateur_by_email_and_password("foo@example.com", "correct_password")
      %Utilisateur{}

      iex> get_utilisateur_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_utilisateur_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    utilisateur = Repo.get_by(Utilisateur, email: email)
    if Utilisateur.valid_password?(utilisateur, password), do: utilisateur
  end

  @doc """
  Gets a single utilisateur.

  Raises `Ecto.NoResultsError` if the Utilisateur does not exist.

  ## Examples

      iex> get_utilisateur!(123)
      %Utilisateur{}

      iex> get_utilisateur!(456)
      ** (Ecto.NoResultsError)

  """
  def get_utilisateur!(id), do: Repo.get!(Utilisateur, id)

  ## Utilisateur registration

  @doc """
  Registers a utilisateur.

  ## Examples

      iex> register_utilisateur(%{field: value})
      {:ok, %Utilisateur{}}

      iex> register_utilisateur(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_utilisateur(attrs) do
    %Utilisateur{}
    |> Utilisateur.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking utilisateur changes.

  ## Examples

      iex> change_utilisateur_registration(utilisateur)
      %Ecto.Changeset{data: %Utilisateur{}}

  """
  def change_utilisateur_registration(%Utilisateur{} = utilisateur, attrs \\ %{}) do
    Utilisateur.registration_changeset(utilisateur, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the utilisateur email.

  ## Examples

      iex> change_utilisateur_email(utilisateur)
      %Ecto.Changeset{data: %Utilisateur{}}

  """
  def change_utilisateur_email(utilisateur, attrs \\ %{}) do
    Utilisateur.email_changeset(utilisateur, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_utilisateur_email(utilisateur, "valid password", %{email: ...})
      {:ok, %Utilisateur{}}

      iex> apply_utilisateur_email(utilisateur, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_utilisateur_email(utilisateur, password, attrs) do
    utilisateur
    |> Utilisateur.email_changeset(attrs)
    |> Utilisateur.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the utilisateur email using the given token.

  If the token matches, the utilisateur email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_utilisateur_email(utilisateur, token) do
    context = "change:#{utilisateur.email}"

    with {:ok, query} <- UtilisateurToken.verify_change_email_token_query(token, context),
         %UtilisateurToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(utilisateur_email_multi(utilisateur, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp utilisateur_email_multi(utilisateur, email, context) do
    changeset =
      utilisateur
      |> Utilisateur.email_changeset(%{email: email})
      |> Utilisateur.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:utilisateur, changeset)
    |> Ecto.Multi.delete_all(:tokens, UtilisateurToken.utilisateur_and_contexts_query(utilisateur, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given utilisateur.

  ## Examples

      iex> deliver_utilisateur_update_email_instructions(utilisateur, current_email, &url(~p"/utilisateurs/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_utilisateur_update_email_instructions(%Utilisateur{} = utilisateur, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, utilisateur_token} = UtilisateurToken.build_email_token(utilisateur, "change:#{current_email}")

    Repo.insert!(utilisateur_token)
    UtilisateurNotifier.deliver_update_email_instructions(utilisateur, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the utilisateur password.

  ## Examples

      iex> change_utilisateur_password(utilisateur)
      %Ecto.Changeset{data: %Utilisateur{}}

  """
  def change_utilisateur_password(utilisateur, attrs \\ %{}) do
    Utilisateur.password_changeset(utilisateur, attrs, hash_password: false)
  end

  @doc """
  Updates the utilisateur password.

  ## Examples

      iex> update_utilisateur_password(utilisateur, "valid password", %{password: ...})
      {:ok, %Utilisateur{}}

      iex> update_utilisateur_password(utilisateur, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_utilisateur_password(utilisateur, password, attrs) do
    changeset =
      utilisateur
      |> Utilisateur.password_changeset(attrs)
      |> Utilisateur.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:utilisateur, changeset)
    |> Ecto.Multi.delete_all(:tokens, UtilisateurToken.utilisateur_and_contexts_query(utilisateur, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{utilisateur: utilisateur}} -> {:ok, utilisateur}
      {:error, :utilisateur, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_utilisateur_session_token(utilisateur) do
    {token, utilisateur_token} = UtilisateurToken.build_session_token(utilisateur)
    Repo.insert!(utilisateur_token)
    token
  end

  @doc """
  Gets the utilisateur with the given signed token.
  """
  def get_utilisateur_by_session_token(token) do
    {:ok, query} = UtilisateurToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_utilisateur_session_token(token) do
    Repo.delete_all(UtilisateurToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given utilisateur.

  ## Examples

      iex> deliver_utilisateur_confirmation_instructions(utilisateur, &url(~p"/utilisateurs/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_utilisateur_confirmation_instructions(confirmed_utilisateur, &url(~p"/utilisateurs/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_utilisateur_confirmation_instructions(%Utilisateur{} = utilisateur, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if utilisateur.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, utilisateur_token} = UtilisateurToken.build_email_token(utilisateur, "confirm")
      Repo.insert!(utilisateur_token)
      UtilisateurNotifier.deliver_confirmation_instructions(utilisateur, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a utilisateur by the given token.

  If the token matches, the utilisateur account is marked as confirmed
  and the token is deleted.
  """
  def confirm_utilisateur(token) do
    with {:ok, query} <- UtilisateurToken.verify_email_token_query(token, "confirm"),
         %Utilisateur{} = utilisateur <- Repo.one(query),
         {:ok, %{utilisateur: utilisateur}} <- Repo.transaction(confirm_utilisateur_multi(utilisateur)) do
      {:ok, utilisateur}
    else
      _ -> :error
    end
  end

  defp confirm_utilisateur_multi(utilisateur) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:utilisateur, Utilisateur.confirm_changeset(utilisateur))
    |> Ecto.Multi.delete_all(:tokens, UtilisateurToken.utilisateur_and_contexts_query(utilisateur, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given utilisateur.

  ## Examples

      iex> deliver_utilisateur_reset_password_instructions(utilisateur, &url(~p"/utilisateurs/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_utilisateur_reset_password_instructions(%Utilisateur{} = utilisateur, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, utilisateur_token} = UtilisateurToken.build_email_token(utilisateur, "reset_password")
    Repo.insert!(utilisateur_token)
    UtilisateurNotifier.deliver_reset_password_instructions(utilisateur, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the utilisateur by reset password token.

  ## Examples

      iex> get_utilisateur_by_reset_password_token("validtoken")
      %Utilisateur{}

      iex> get_utilisateur_by_reset_password_token("invalidtoken")
      nil

  """
  def get_utilisateur_by_reset_password_token(token) do
    with {:ok, query} <- UtilisateurToken.verify_email_token_query(token, "reset_password"),
         %Utilisateur{} = utilisateur <- Repo.one(query) do
      utilisateur
    else
      _ -> nil
    end
  end

  @doc """
  Resets the utilisateur password.

  ## Examples

      iex> reset_utilisateur_password(utilisateur, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Utilisateur{}}

      iex> reset_utilisateur_password(utilisateur, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_utilisateur_password(utilisateur, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:utilisateur, Utilisateur.password_changeset(utilisateur, attrs))
    |> Ecto.Multi.delete_all(:tokens, UtilisateurToken.utilisateur_and_contexts_query(utilisateur, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{utilisateur: utilisateur}} -> {:ok, utilisateur}
      {:error, :utilisateur, changeset, _} -> {:error, changeset}
    end
  end
end
