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

  @impl true
  def change(changeset, opts, _context) do
    currency = opts[:currency]

    %Craftplan.Orders.Order{}
    |> Changeset.for_update(:oban, %{
      currency: currency
    })
    |> Ash.update()

    %Craftplan.Catalog.Product{}
    |> Changeset.for_update(:oban, %{
      currency: currency
    })
    |> Ash.update()

    %Craftplan.Catalog.BOMRollup{}
    |> Changeset.for_update(:oban, %{
      currency: currency
    })
    |> Ash.update()

    %Craftplan.Catalog.LaborStep{}
    |> Changeset.for_update(:oban, %{
      currency: currency
    })
    |> Ash.update()

    %Craftplan.Inventory.Material{}
    |> Changeset.for_update(:oban, %{
      currency: currency
    })
    |> Ash.update()

    %Craftplan.Inventory.PurchaseOrderItem{}
    |> Changeset.for_update(:oban, %{
      currency: currency
    })
    |> Ash.update()

    %Craftplan.Orders.OrderItem{}
    |> Changeset.for_update(:oban, %{
      currency: currency
    })
    |> Ash.update()

    changeset
  end
end
