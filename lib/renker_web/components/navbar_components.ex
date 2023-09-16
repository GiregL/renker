defmodule RenkerWeb.NavbarComponents do
  @moduledoc """
  Composants de la barre de navigation.
  """

  use Phoenix.Component

  @links [
    %{name: "Accueil", url: "/"},
    %{name: "A propos", url: "/about"},
    %{name: "Connexion", url: "/utilisateurs/log_in"}
  ]
  def links(), do: @links

  @doc """
  Construction de la liste des liens accessibles pour un utilisateur.
  """
  def navbar_links(assigns) do
    ~H"""
      <%= for link <- links() do %>
      <li><a href={link.url}><%= link.name %></a></li>
      <% end %>
    """
  end

end
