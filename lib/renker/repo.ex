defmodule Renker.Repo do
  use Ecto.Repo,
    otp_app: :renker,
    adapter: Ecto.Adapters.SQLite3
end
