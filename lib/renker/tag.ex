defmodule Renker.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Représentation d'un Tag de tâche en base.
  """

  schema "tags" do
    field :titre, :string
    many_to_many :taches, Renker.Tache, join_through: "tache_tag"
    timestamps()
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:titre])
    |> validate_required([:titre])
  end
end
