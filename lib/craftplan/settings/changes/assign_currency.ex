defmodule Craftplan.Settings.Settings.AssignCurrency do
  @moduledoc """
  Change the currency type in the following schemas due to using the sum procedure (we cant sum 2 different currency types)
  [catalog_bom_rollups, catalog_labor_steps, catalog_products, inventory_materials, inventory_purchase_order_items, orders_items, orders_orders, settings]
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Ash.NotLoaded
  alias Ash.Query

  @modules [Craftplan.Orders.Order,Craftplan.Catalog.Product,Craftplan.Catalog.BOMRollup,Craftplan.Catalog.LaborStep,Craftplan.Inventory.Material,Craftplan.Inventory.PurchaseOrderItem,Craftplan.Orders.OrderItem]

  @impl true
  def change(changeset, opts, _context) do

    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      currency = opts[:currency]
      Enum.map(@modules, fn(m) ->
        AshOban.run_trigger(m, :process)
      end)
      {:ok, record}
    end)

    changeset
  end

end
