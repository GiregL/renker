defmodule Renker.Services.TacheServices do
  @moduledoc """
  Module de services métiers de la gestion des taches.
  """

  import Ecto.Query

  alias Renker.Authent.Utilisateur
  alias Renker.Repo
  alias Renker.Tache
  alias Renker.Tag

  @doc """
  Récupère toutes les taches de la plateforme.
  """
  @spec get_all() :: Tache.__schema__()
  def get_all do
    query = from tache in Tache,
              select: tache
    Repo.all(query)
  end

  @doc """
  Récupère toutes les taches d'un utilisateur de la plateforme.
  """
  def get_all_of_user(%Utilisateur{} = utilisateur) do
    query = from tache in Tache,
              where: tache.utilisateur == ^utilisateur,
              select: tache
    Repo.all(query)
  end

end
