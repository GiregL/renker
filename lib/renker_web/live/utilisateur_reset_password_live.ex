defmodule RenkerWeb.UtilisateurResetPasswordLive do
  use RenkerWeb, :live_view

  alias Renker.Authent

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Réinitialiser son mot de passe</.header>

      <.simple_form
        for={@form}
        id="reset_password_form"
        phx-submit="reset_password"
        phx-change="validate"
      >
        <.error :if={@form.errors != []}>
          Oops, une erreur est survenue! Corrigez les erreurs ci-dessous.
        </.error>

        <.input field={@form[:password]} type="password" label="New password" required />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          required
        />
        <:actions>
          <.button phx-disable-with="Réinitialisation..." class="uk-button-primary">Réinitialiser le mot de passe</.button>
        </:actions>
      </.simple_form>

      <p class="text-center text-sm mt-4">
        <.link href={~p"/utilisateurs/register"}>S'enregistrer</.link>
        | <.link href={~p"/utilisateurs/log_in"}>Se connecter</.link>
      </p>
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_utilisateur_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{utilisateur: utilisateur} ->
          Authent.change_utilisateur_password(utilisateur)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  # Do not log in the utilisateur after reset password to avoid a
  # leaked token giving the utilisateur access to the account.
  def handle_event("reset_password", %{"utilisateur" => utilisateur_params}, socket) do
    case Authent.reset_utilisateur_password(socket.assigns.utilisateur, utilisateur_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/utilisateurs/log_in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"utilisateur" => utilisateur_params}, socket) do
    changeset = Authent.change_utilisateur_password(socket.assigns.utilisateur, utilisateur_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_utilisateur_and_token(socket, %{"token" => token}) do
    if utilisateur = Authent.get_utilisateur_by_reset_password_token(token) do
      assign(socket, utilisateur: utilisateur, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "utilisateur"))
  end
end
