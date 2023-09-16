defmodule RenkerWeb.TachesController do
  use RenkerWeb, :controller

  @moduledoc """
  Controller des taches disponibles pour un utilisateur.
  """

  def home(socket, _params) do
    taches = Renker.Services.TacheServices.get_all()

    socket
    |> assign(:taches, taches)
    |> render(:home)
  end

end
