defmodule Craftplan.Accounts.Organization.Changes.AssociateOwnerToOrganization do
  @moduledoc """
  Link user to the organization via user_organizations relationship so that when
  we are listing owners organizations, this organization will be listed as well
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &associate_owner_to_organization/2)
  end

  defp associate_owner_to_organization(_changeset, organization) do
    params = %{user_id: organization.owner_id, organization_id: organization.id}

    {:ok, _user_organization} =
      Craftplan.Accounts.UserOrganization
      |> Ash.Changeset.for_create(:create, params)
      |> Ash.create()

    {:ok, organization}
  end
end
