defmodule Renker.Repo.Migrations.CreateTaches do
  use Ecto.Migration

  def change do
    create table(:taches) do
      add :titre, :string
      add :description, :string
      add :date_limite, :date
      add :etat, :string
      timestamps()
    end
  end
end
