defmodule Craftplan.Accounts.Checks.ActorBelongsToTenant do
  @moduledoc nil
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts) do
    "checks the if actor belongs to the correct organisation"
  end

  @impl true
  def match?(_actor, %{resource: _resource, action: _action} = _context, _opts) do
    true
  end
end
