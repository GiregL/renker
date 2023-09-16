defmodule RenkerWeb.TachesController do
  use RenkerWeb, :controller

  @moduledoc """
  Controller des taches disponibles pour un utilisateur.
  """

  def home(socket, _params) do
    socket
    |> render(:home)
  end

end
