defmodule Renker.Tache do
  use Ecto.Schema
  import Ecto.Changeset

  schema "taches" do
    field :date_limite, :date
    field :description, :string
    field :titre, :string
    field :etat, Ecto.Enum, values: [:a_faire, :en_cours, :terminee]
    belongs_to :utilisateur, Renker.Authent.Utilisateur
    many_to_many :tags, Renker.Tag, join_through: "tache_tag"
    timestamps()
  end

  @doc false
  def changeset(tache, attrs) do
    tache
    |> cast(attrs, [:titre, :description, :date_limite])
    |> validate_required([:titre, :description, :date_limite])
  end
end
