defmodule Renker.Repo.Migrations.UtilisateurRoles do
  alias Renker.Authent.Utilisateur
  use Ecto.Migration

  def change do
    alter table(:utilisateurs) do
      add :role, :string
    end
  end
end
