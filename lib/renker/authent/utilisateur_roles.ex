defmodule Renker.Authent.UtilisateurRoles do
  @moduledoc """
  Module de gestion des rôles d'un utilisateur.
  """

  @roles [:user, :admin]
  @doc """
  Liste des rôles disponibles sur la plateforme.
  """
  @spec roles() :: [atom()]
  def roles, do: @roles

  @hierarchie [
    %{niveau: 1, role: :user},
    %{niveau: 10, role: :admin}
  ]
end
