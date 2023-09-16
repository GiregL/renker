defmodule Renker.Repo.Migrations.CreateUtilisateursAuthTables do
  use Ecto.Migration

  def change do
    create table(:utilisateurs) do
      add :email, :string, null: false, collate: :nocase
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:utilisateurs, [:email])

    create table(:utilisateurs_tokens) do
      add :utilisateur_id, references(:utilisateurs, on_delete: :delete_all), null: false
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:utilisateurs_tokens, [:utilisateur_id])
    create unique_index(:utilisateurs_tokens, [:context, :token])
  end
end
