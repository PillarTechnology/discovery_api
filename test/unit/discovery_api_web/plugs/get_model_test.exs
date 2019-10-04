defmodule DiscoveryApiWeb.Plugs.GetModelTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApiWeb.Plugs.GetModel

  alias DiscoveryApi.TestDataGenerator, as: TDG

  describe "call/2" do
    setup do
      Cachex.clear(SystemNameCache.cache_name())
      :ok
    end

    test "replaces the org_name and dataset_name with the correct dataset_id" do
      dataset = TDG.create_dataset(id: "ds1", technical: %{dataName: "data1", orgName: "org1"})

      SystemNameCache.put(dataset)
      SystemNameCache.put(TDG.create_dataset(id: "ds2", technical: %{dataName: "data1", orgName: "org1"}))
      allow Model.get(any()), return: :model

      conn = build_conn(:get, "/doesnt/matter", %{"org_name" => "org1", "dataset_name" => "data1"})
      %{assigns: assigns} = GetModel.call(conn, [])

      assert :model == assigns.model
    end

    test "responds with a 404 when org_name and dataset_name combination is not known" do
      allow DiscoveryApiWeb.RenderError.render_error(any(), any(), any()), exec: fn conn, _, _ -> conn end
      conn = build_conn(:get, "/doesnt/matter", %{"org_name" => "org1", "dataset_name" => "data1"})
      result = GetModel.call(conn, [])

      assert_called DiscoveryApiWeb.RenderError.render_error(conn, 404, "Not Found")
      assert result.halted == true
    end
  end
end
