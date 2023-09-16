defmodule RenkerWeb.TachesController do
  use RenkerWeb, :controller

  @moduledoc """
  Controller des taches disponibles pour un utilisateur.
  """

  @doc """
  Page d'accueil listant les taches d'un utilisateur.
  """
  def home(socket, _params) do
    taches = Renker.Services.TacheServices.get_all()

    socket
    |> assign(:taches, taches)
    |> render(:home)
  end

  @doc """
  Formulaire permettant à un utilisateur d'ajouter une tache.
  """
  def new(socket, _params) do
    socket
    |> render(:home)
  end

  @doc """
  Processus d'ajout de la tache saisie par l'utilisateur.
  Renvoi sur la page listant toutes les taches de l'utilisateur si c'est un succès.
  Renvoi sur la page de l'ajout si c'est une erreur.
  """
  def post_new(socket, _params) do
    socket
    |> render(:home)
  end

end
