defmodule Renker.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :titre, :string

      timestamps()
    end
  end
end
