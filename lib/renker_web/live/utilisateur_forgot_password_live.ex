defmodule RenkerWeb.UtilisateurForgotPasswordLive do
  use RenkerWeb, :live_view

  alias Renker.Authent

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Vous avez oublié votre mot de passe?
        <:subtitle>Nous allons vous renvoyer un lien de changement de mot de passe par e-mail</:subtitle>
      </.header>

      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button class="uk-button-warning" phx-disable-with="Sending...">
            Envoyer les instructions
          </.button>
        </:actions>
      </.simple_form>
      <p class="text-center">
        <.link href={~p"/utilisateurs/register"}>S'enregistrer</.link>
        | <.link href={~p"/utilisateurs/log_in"}>Se connecter</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "utilisateur"))}
  end

  def handle_event("send_email", %{"utilisateur" => %{"email" => email}}, socket) do
    if utilisateur = Authent.get_utilisateur_by_email(email) do
      Authent.deliver_utilisateur_reset_password_instructions(
        utilisateur,
        &url(~p"/utilisateurs/reset_password/#{&1}")
      )
    end

    info =
      "Si votre adresse est dans nos systèmes, vous recevrez le mail sous peu."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
