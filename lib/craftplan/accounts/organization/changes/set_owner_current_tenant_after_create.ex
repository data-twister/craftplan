defmodule Craftplan.Accounts.Organization.Changes.SetOwnerCurrentOrganizationAfterCreate do
  @moduledoc false
  use Ash.Resource.Change

  def change(changeset, _organization, _context) do
    Ash.Changeset.after_action(changeset, &set_owner_current_organization/2)
  end

  defp set_owner_current_organization(_changeset, organization) do
    opts = [authorize?: false]

    {:ok, _user} =
      Craftplan.Accounts.User
      |> Ash.get!(organization.owner_id, opts)
      |> Ash.Changeset.for_update(:set_current_organization, %{organization: organization.prefix})
      |> Ash.update(opts)

    {:ok, organization}
  end
end
