defmodule Renker.Repo.Migrations.TacheUtilisateurId do
  alias Renker.Authent.Utilisateur
  use Ecto.Migration

  def change do
    alter table(:taches) do
      add :utilisateur_id, references(Utilisateur)
    end
  end
end
