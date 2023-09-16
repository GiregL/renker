defmodule RenkerWeb.NavbarComponents do
  @moduledoc """
  Composants de la barre de navigation.
  """
alias RenkerWeb.NavbarComponents
alias Renker.Authent.Utilisateur

  use Phoenix.Component

  @doc """
  Prédicat indiquant si une route est libre ou non pour tous les utilisateurs.
  """
  @spec acces_libre(Utilisateur.__struct__) :: boolean()
  def acces_libre(_) do
    true
  end

  @doc """
  Prédicat indiquant si une route requiert que l'utilisateur soit connecté.
  """
  @spec requiert_utilisateur_connecte(Utilisateur.__struct__ | nil) :: boolean()
  def requiert_utilisateur_connecte(nil), do: false
  def requiert_utilisateur_connecte(%Utilisateur{} = utilisateur) do
    utilisateur != nil
  end

  def liens do
    [
      %{name: "Accueil", url: "/", predicat: &(NavbarComponents.acces_libre/1)},
      %{name: "A propos", url: "/about", predicat: &(NavbarComponents.acces_libre/1)},

      # Gestion des taches
      %{name: "Mes taches", url: "/taches", predicat: fn user -> NavbarComponents.requiert_utilisateur_connecte(user) end},

      # Gestion de l'utilisateur
      %{name: "Connexion", url: "/utilisateurs/log_in", predicat: fn user -> !NavbarComponents.requiert_utilisateur_connecte(user) end},
      %{name: "Inscription", url: "/utilisateurs/register", predicat: fn user -> !NavbarComponents.requiert_utilisateur_connecte(user) end},
      %{name: "Deconnexion", url: "/utilisateurs/log_out", predicat: fn user -> NavbarComponents.requiert_utilisateur_connecte(user) end},
    ]
  end

  @doc """
  Retourne la liste des liens disponibles à la navigation pour un utilisateur.
  """
  @spec links(Utilisateur.__struct__()) :: [%{name: String.t(), url: String.t()}]
  def links(user) do
    liens()
    |> Enum.map(fn %{predicat: predicat} = route -> %{route | predicat: predicat.(user)} end)
    |> Enum.filter(fn %{predicat: predicat} -> predicat end)
  end

  attr :current_utilisateur, Utilisateur, default: nil
  @doc """
  Construction de la liste des liens accessibles pour un utilisateur.
  """
  def navbar_links(assigns) do
    ~H"""
      <%= for link <- links(@current_utilisateur) do %>
      <li><a href={link.url}><%= link.name %></a></li>
      <% end %>
    """
  end

end
