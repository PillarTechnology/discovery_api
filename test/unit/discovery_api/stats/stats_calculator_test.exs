defmodule DiscoveryApi.Stats.StatsCalculatorTest do
  use ExUnit.Case
  use Placebo
  alias SmartCity.Dataset
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApi.Data.Persistence

  @dataset_id "eaad54e8-fcb6-4f0e-99ac-bf51887ed102"
  @completeness_key "discovery-api:completeness_calculated_date"

  describe "produce_completeness_stats/1 positive cases" do
    setup do
      dataset = mock_non_remote_dataset()

      allow(Dataset.get_all!(), return: [dataset], meck_options: [:passthrough])
      allow(Persistence.persist(any(), any()), return: :does_not_matter)

      allow(Prestige.execute(any(), any()),
        return: [
          %{"age" => 78, "name" => "Alex Trebek"},
          %{"age" => 72, "name" => "Pat Sajak"},
          %{"age" => nil, "name" => "Wayne Brady"}
        ]
      )

      keys = ["forklift:last_insert_date:#{dataset.id}", "#{@completeness_key}:#{dataset.id}"]

      stats = %{
        id: dataset.id,
        completeness: 0.8333333333333334,
        record_count: 3,
        fields: %{
          "name" => %{count: 3, required: false},
          "age" => %{count: 2, required: false}
        }
      }

      {:ok, %{dataset: dataset, keys: keys, stats: stats}}
    end

    test "Interacts with persistence in the way we expect", %{keys: keys} do
      allow(Persistence.get_many(any()), return: [nil, nil])

      StatsCalculator.produce_completeness_stats()

      assert_called(Persistence.get_many(keys))
    end

    test "Writes stats to redis for non-remote datasets", %{dataset: dataset, keys: keys, stats: stats} do
      allow(Persistence.get_many(keys), return: ["2019-06-05T14:01:36.466729Z", "2019-06-05T13:59:09.630290Z"])

      StatsCalculator.produce_completeness_stats()

      assert_called(Persistence.persist("discovery-api:stats:#{dataset.id}", stats))
      assert_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end

    test "Writes stats to redis when data has loaded, but no stats have been calculated", %{dataset: dataset, keys: keys, stats: stats} do
      allow(Persistence.get_many(keys), return: ["2019-06-05T13:59:09.630290Z", nil])

      StatsCalculator.produce_completeness_stats()

      assert_called(Persistence.persist("discovery-api:stats:#{dataset.id}", stats))
      assert_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end
  end

  describe "produce_completeness_stats/1 negative cases" do
    test "Does not calculate statistics for remote datasets" do
      dataset = mock_remote_dataset()

      allow(Dataset.get_all!(), return: [dataset], meck_options: [:passthrough])
      allow(Persistence.persist(any(), any()), return: :does_not_matter)

      allow(Prestige.execute(any(), any()),
        return: []
      )

      StatsCalculator.produce_completeness_stats()

      refute_called(Persistence.persist("discovery-api:stats:#{dataset.id}", any()))

      refute_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end

    test "Does not calculate statistics for datasets that have not been updated since last calculation date" do
      dataset = mock_non_remote_dataset()

      allow(Dataset.get_all!(), return: [dataset], meck_options: [:passthrough])
      allow(Persistence.persist(any(), any()), return: :does_not_matter)

      allow(Prestige.execute(any(), any()),
        return: [
          %{"age" => 78, "name" => "Alex Trebek"},
          %{"age" => 72, "name" => "Pat Sajak"},
          %{"age" => nil, "name" => "Wayne Brady"}
        ]
      )

      keys = ["forklift:last_insert_date:#{dataset.id}", "#{@completeness_key}:#{dataset.id}"]
      allow(Persistence.get_many(keys), return: ["2019-06-05T13:59:09.630290Z", "2019-06-05T14:01:36.466729Z"])

      StatsCalculator.produce_completeness_stats()

      refute_called(Persistence.persist("discovery-api:stats:#{dataset.id}", any()))

      refute_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end

    test "Does not calculate statistics when presto returns no data" do
      dataset = mock_non_remote_dataset()
      allow(Dataset.get_all!(), return: [dataset], meck_options: [:passthrough])

      allow(Persistence.persist(any(), any()), return: :does_not_matter)
      allow(Prestige.execute(any(), any()), return: [])

      keys = ["forklift:last_insert_date:#{dataset.id}", "#{@completeness_key}:#{dataset.id}"]
      allow(Persistence.get_many(keys), return: [nil, nil])

      StatsCalculator.produce_completeness_stats()

      refute_called(
        Persistence.persist(
          "discovery-api:stats:#{dataset.id}",
          %{id: dataset.id}
        )
      )

      refute_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end
  end

  defp mock_non_remote_dataset() do
    %SmartCity.Dataset{
      _metadata: %SmartCity.Dataset.Metadata{expectedBenefit: [], intendedUse: []},
      business: nil,
      id: @dataset_id,
      technical: %SmartCity.Dataset.Technical{
        cadence: 4654,
        dataName: "Tawny_Laranja",
        sourceHeaders: %{accepts: "application/json"},
        orgId: "orgId",
        orgName: "Rosa_Jasper",
        partitioner: %{query: nil, type: nil},
        private: true,
        sourceQueryParams: %{apiKey: "d3b0afb2-66bc-496f-8b0c-32c6872f1515"},
        schema: [
          %{name: "name", required: false, type: "string"},
          %{name: "age", required: false, type: "int"}
        ],
        sourceFormat: "gtfs",
        sourceType: "batch",
        sourceUrl: "schultz.org",
        systemName: "test_table",
        transformations: ["trim", "aggregate", "rename_field"],
        validations: ["matches_schema", "no_nulls"]
      },
      version: "0.2"
    }
  end

  defp mock_remote_dataset() do
    %SmartCity.Dataset{
      _metadata: %SmartCity.Dataset.Metadata{expectedBenefit: [], intendedUse: []},
      business: nil,
      id: @dataset_id,
      technical: %SmartCity.Dataset.Technical{
        private: true,
        sourceQueryParams: %{apiKey: "d3b0afb2-66bc-496f-8b0c-32c6872f1515"},
        schema: [
          %{name: "name", required: false, type: "string"},
          %{name: "age", required: false, type: "int"}
        ],
        sourceFormat: "gtfs",
        sourceType: "remote",
        sourceUrl: "schultz.org",
        systemName: "test_table"
      },
      version: "0.2"
    }
  end
end
