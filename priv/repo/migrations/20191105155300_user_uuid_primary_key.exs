defmodule DiscoveryApi.Repo.Migrations.UserUuidPrimaryKey do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.Visualizations.Visualization

  def up do
    # create the new id column in users
    execute ~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp";|

    alter table(:users) do
      add(:new_id, :uuid, default: fragment("uuid_generate_v4()"))
    end

    # create unique_index(:users, [:new_id])

    # Add that column as new column to vizualization
    # create a new foreign key constraint from visuzlizations
    alter table(:visualizations) do
      add :new_owner_id, :uuid
    end

    flush()

    from(visualization in Visualization, update: [set: [new_owner_id: fragment("select users.new_id from users where users.id = ?", visualization.owner_id)]])
    |> Repo.update_all([])

    # make new columns non-nullable
    alter table(:visualizations) do
      modify :new_owner_id, :uuid, null: false
    end

    # drop the old foreign key constraint from visuzlizations
    alter table(:visualizations) do
      remove :owner_id
    end

    # Delete old id column
    # Change the primary key in users
    alter table(:users) do
      remove :id
      modify :new_id, :uuid, primary_key: true
    end

    # rename the new id column
    rename(table(:users), :new_id, to: :id)

    # rename new column in Vizualization
    rename(table(:visualizations), :new_owner_id, to: :owner_id)

    alter table(:visualizations) do
      modify :owner_id, references(:users, type: :uuid)
    end
  end

  def down do
    # alter table(:users) do
    #   add :id, :integer
    # end

    # alter table(:visualizations) do
    #   add :owner_id, references(:users, type: :integer, column: :id)
    # end

    # alter table(:visualizations) do
    #   remove :new_owner_id
    # end

    # alter table(:users) do
    #   remove :new_id
    # end
  end
end
