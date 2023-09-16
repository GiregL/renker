defmodule RenkerWeb.UtilisateurRegistrationLive do
  use RenkerWeb, :live_view

  alias Renker.Authent
  alias Renker.Authent.Utilisateur

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Créer un compte
        <:subtitle>
          Déjà enregistré ?
          <.link navigate={~p"/utilisateurs/log_in"} class="font-semibold text-brand hover:underline">
            Se connecter
          </.link>
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/utilisateurs/log_in?_action=registered"}
        method="post"
      >
        <.error :if={@check_errors}>
          Oops, une erreur est survenue! Merci de vérifier les erreurs ci-dessous.
        </.error>

        <.input field={@form[:email]} type="email" label="Adresse e-mail" required />
        <.input field={@form[:password]} type="password" label="Mot de passe" required />

        <:actions>
          <.button class="uk-button-primary" phx-disable-with="Création du compte...">Créer son compte</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Authent.change_utilisateur_registration(%Utilisateur{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"utilisateur" => utilisateur_params}, socket) do
    case Authent.register_utilisateur(utilisateur_params) do
      {:ok, utilisateur} ->
        {:ok, _} =
          Authent.deliver_utilisateur_confirmation_instructions(
            utilisateur,
            &url(~p"/utilisateurs/confirm/#{&1}")
          )

        changeset = Authent.change_utilisateur_registration(utilisateur)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"utilisateur" => utilisateur_params}, socket) do
    changeset = Authent.change_utilisateur_registration(%Utilisateur{}, utilisateur_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "utilisateur")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
