defmodule DiscoveryApi.Data.DictionaryTest do
  use ExUnit.Case
  use Divo, services: [:redis, :"ecto-postgres", :kafka, :zookeeper]
  use DiscoveryApi.DataCase

  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.TestDataGenerator, as: TDG
  alias SmartCity.Registry.Dataset

  setup do
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  describe "/api/v1/dataset/dictionary" do
    test "returns not found when dataset does not exist" do
      %{status_code: status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/non_existant_id/dictionary"
        |> HTTPoison.get!()

      result = Jason.decode!(body, keys: :atoms)
      assert status_code == 404
      assert result.message == "Not Found"
    end

    test "returns schema for provided dataset id" do
      organization = Helper.save_org()
      schema = [%{name: "column_name", description: "column description", type: "string"}]

      dataset =
        TDG.create_dataset(%{
          business: %{description: "Bob had a horse and this is its data"},
          technical: %{orgId: organization.org_id, schema: schema}
        })

      Dataset.write(dataset)
      DiscoveryApi.Data.DatasetEventListener.handle_dataset(dataset)

      %{status_code: status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/#{dataset.id}/dictionary"
        |> HTTPoison.get!()

      assert status_code == 200
      assert Jason.decode!(body, keys: :atoms) == schema
    end
  end
end
