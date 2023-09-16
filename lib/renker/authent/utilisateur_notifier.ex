defmodule Renker.Authent.UtilisateurNotifier do
  import Swoosh.Email

  alias Renker.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Renker", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(utilisateur, url) do
    deliver(utilisateur.email, "Confirmation instructions", """

    ==============================

    Hi #{utilisateur.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a utilisateur password.
  """
  def deliver_reset_password_instructions(utilisateur, url) do
    deliver(utilisateur.email, "Reset password instructions", """

    ==============================

    Hi #{utilisateur.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a utilisateur email.
  """
  def deliver_update_email_instructions(utilisateur, url) do
    deliver(utilisateur.email, "Update email instructions", """

    ==============================

    Hi #{utilisateur.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
