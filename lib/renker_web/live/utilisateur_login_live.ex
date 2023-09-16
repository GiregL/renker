defmodule RenkerWeb.UtilisateurLoginLive do
  use RenkerWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>
      <.header class="text-center">
        Connexion
        <:subtitle>
          Vous n'avez pas de compte utilisateur?
          <.link navigate={~p"/utilisateurs/register"} class="font-semibold text-brand hover:underline">
            Enregistrez vous
          </.link>
          sur notre application.
        </:subtitle>
      </.header>

      <div class="">

      </div>
      <.simple_form for={@form} id="login_form" action={~p"/utilisateurs/log_in"} phx-update="ignore">
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Mot de passe" required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Se souvenir de moi" />
          <.link href={~p"/utilisateurs/reset_password"}>
            Mot de passe oublié ?
          </.link>
        </:actions>
        <:actions>
          <.button class="uk-button-primary" phx-disable-with="Signing in...">
            Se connecter <.icon name="sign-in" />
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = live_flash(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "utilisateur")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
