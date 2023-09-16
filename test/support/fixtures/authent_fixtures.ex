defmodule Renker.AuthentFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Renker.Authent` context.
  """

  def unique_utilisateur_email, do: "utilisateur#{System.unique_integer()}@example.com"
  def valid_utilisateur_password, do: "hello world!"

  def valid_utilisateur_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_utilisateur_email(),
      password: valid_utilisateur_password()
    })
  end

  def utilisateur_fixture(attrs \\ %{}) do
    {:ok, utilisateur} =
      attrs
      |> valid_utilisateur_attributes()
      |> Renker.Authent.register_utilisateur()

    utilisateur
  end

  def extract_utilisateur_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
