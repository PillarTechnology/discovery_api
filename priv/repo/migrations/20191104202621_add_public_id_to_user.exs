defmodule DiscoveryApi.Repo.Migrations.AddPublicIdToUser do
  use Ecto.Migration

  def change do
    execute ~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp";|

    alter table(:users) do
      add(:public_id, :uuid, default: fragment("uuid_generate_v4()"))
    end

    create unique_index(:users, [:public_id])
  end
end
