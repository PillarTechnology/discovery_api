defmodule DiscoveryApi.EventHandler do
  @moduledoc "Event Handler for event stream"

  use Brook.Event.Handler
  import SmartCity.Event, only: [organization_update: 0, user_organization_associate: 0]
  alias SmartCity.Organization
  alias SmartCity.UserOrganizationAssociate
  alias DiscoveryApi.Schemas.Organizations
  alias DiscoveryApi.Schemas.Users

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data}) do
    Organizations.create_or_update(data)
    :discard
  end

  def handle_event(%Brook.Event{type: user_organization_associate(), data: %UserOrganizationAssociate{} = association}) do
    #TODO: log failures
    Users.associate_with_organization(association.user_id, association.org_id)
    :discard
  end
end
