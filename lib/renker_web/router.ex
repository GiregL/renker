defmodule RenkerWeb.Router do
  use RenkerWeb, :router

  import RenkerWeb.UtilisateurAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RenkerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_utilisateur
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  #
  # Routes principales
  #

  scope "/", RenkerWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  #
  # Taches et tags
  #

  scope "/taches", RenkerWeb do
    pipe_through [:browser, :require_authenticated_utilisateur]

    get "/", TachesController, :home
    get "/new", TachesController, :new
    post "/new", TachesController, :post_new
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:renker, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RenkerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  #
  # Routes liées à l'authentification et aux réglages utilisateurs.
  #

  scope "/", RenkerWeb do
    pipe_through [:browser, :redirect_if_utilisateur_is_authenticated]

    live_session :redirect_if_utilisateur_is_authenticated,
      on_mount: [{RenkerWeb.UtilisateurAuth, :redirect_if_utilisateur_is_authenticated}] do
      live "/utilisateurs/register", UtilisateurRegistrationLive, :new
      live "/utilisateurs/log_in", UtilisateurLoginLive, :new
      live "/utilisateurs/reset_password", UtilisateurForgotPasswordLive, :new
      live "/utilisateurs/reset_password/:token", UtilisateurResetPasswordLive, :edit
    end

    post "/utilisateurs/log_in", UtilisateurSessionController, :create
  end

  scope "/", RenkerWeb do
    pipe_through [:browser, :require_authenticated_utilisateur]

    live_session :require_authenticated_utilisateur,
      on_mount: [{RenkerWeb.UtilisateurAuth, :ensure_authenticated}] do
      live "/utilisateurs/settings", UtilisateurSettingsLive, :edit
      live "/utilisateurs/settings/confirm_email/:token", UtilisateurSettingsLive, :confirm_email
    end
  end

  scope "/", RenkerWeb do
    pipe_through [:browser]

    get "/utilisateurs/log_out", UtilisateurSessionController, :delete

    live_session :current_utilisateur,
      on_mount: [{RenkerWeb.UtilisateurAuth, :mount_current_utilisateur}] do
      live "/utilisateurs/confirm/:token", UtilisateurConfirmationLive, :edit
      live "/utilisateurs/confirm", UtilisateurConfirmationInstructionsLive, :new
    end
  end
end
