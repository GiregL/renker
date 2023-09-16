defmodule Renker.Repo.Migrations.TacheUtilisateurAssociation do
  use Ecto.Migration

  def change do
    # Une tache appartient a un utilisateur
    alter table(:taches) do
      add :auteur_id, references(:utilisateurs)
    end
  end
end
