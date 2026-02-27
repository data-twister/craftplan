# lib/helpcenter/accounts/permission.ex
defmodule Craftplan.Accounts.Permission do
  @moduledoc false
  @doc """
  Get a list of maps of resources and their actions
  Example:
    iex> Craftplan.Accounts.Permission.get_permissions()
    iex> [%{resource: Craftplan.Accounts.GroupPermission, action: :create}]
  """

  def permissions do
    get_all_domain_resources()
    |> Enum.map(&map_resource_actions/1)
    |> Enum.flat_map(& &1)
  end

  defp map_resource_action(action, resource) do
    %{action: action.name, resource: resource}
  end

  defp map_resource_actions(resource) do
    resource
    |> Ash.Resource.Info.actions()
    |> Enum.map(&map_resource_action(&1, resource))
  end

  defp get_all_domain_resources do
    :helpcenter
    |> Application.get_env(:ash_domains)
    |> Enum.map(&Ash.Domain.Info.resources(&1))
    |> Enum.flat_map(& &1)
  end
end
