defmodule DiscoveryApi.Data.PrestoIngrationTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.{Dataset, Organization}
  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  @moduletag capture_log: true
  test "returns empty list when dataset id doesn't exist" do
    dataset_id = "does not exist"

    assert [] == get_dataset_preview(dataset_id)
  end

  @moduletag capture_log: true
  test "returns empty list when dataset has no data saved" do
    dataset_id = "123"
    system_name = "not_saved"

    "create table if not exists #{system_name} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    organization = TDG.create_organization(%{})
    Organization.write(organization)

    dataset = TDG.create_dataset(%{technical: %{systemName: system_name, orgId: organization.id}})
    Dataset.write(dataset)

    assert [] == get_dataset_preview(dataset_id)
  end

  @moduletag capture_log: true
  test "returns results for datasets stored in presto" do
    dataset_id = "1234-4567-89101"
    system_name = "foobar__company_data"

    "create table if not exists #{system_name} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    ~s|insert into "#{system_name}" values (1, 'bob'), (2, 'mike')|
    |> Prestige.execute()
    |> Prestige.prefetch()

    organization = TDG.create_organization(%{})
    Organization.write(organization)

    dataset = TDG.create_dataset(%{id: dataset_id, technical: %{systemName: system_name, orgId: organization.id}})
    Dataset.write(dataset)

    expected = [[1, "bob"], [2, "mike"]]

    Patiently.wait_for!(
      fn -> get_dataset_preview(dataset_id) == expected end,
      dwell: 1000,
      max_tries: 20
    )
  end

  defp get_dataset_preview(dataset_id) do
    %{"data" => data} =
      "http://localhost:4000/api/v1/dataset/#{dataset_id}/preview"
      |> HTTPoison.get!()
      |> Map.get(:body)
      |> Jason.decode!()

    data
  end
end