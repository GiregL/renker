defmodule Renker.Repo.Migrations.TacheTag do
  use Ecto.Migration

  def change do
    create table(:tache_tag, primary_key: false) do
      add :tag_id, references(:tags)
      add :tache_id, references(:taches)
      timestamps()
    end
  end
end
