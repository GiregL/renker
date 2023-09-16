defmodule RenkerWeb.UtilisateurConfirmationInstructionsLive do
  use RenkerWeb, :live_view

  alias Renker.Authent

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Vous n'avez pas reçu d'instruction de confirmation?
        <:subtitle>Nous allons envoyer de nouvelles instructions dans votre boite e-mail.</:subtitle>
      </.header>

      <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Renvoyer les instructions
          </.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/utilisateurs/register"}>S'enregistrer</.link>
        | <.link href={~p"/utilisateurs/log_in"}>Se connecter</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "utilisateur"))}
  end

  def handle_event("send_instructions", %{"utilisateur" => %{"email" => email}}, socket) do
    if utilisateur = Authent.get_utilisateur_by_email(email) do
      Authent.deliver_utilisateur_confirmation_instructions(
        utilisateur,
        &url(~p"/utilisateurs/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
