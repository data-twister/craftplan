defmodule Craftplan.Catalog.BOMRollup do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "catalog_bom_rollups"
    repo Craftplan.Repo
  end

  oban do
    triggers do
      trigger :process do
        action :change_currency
        worker_read_action(:read)
      end
    end

    domain Craftplan.Catalog.BOMRollup
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :bom_id,
        :product_id,
        :material_cost,
        :labor_cost,
        :overhead_cost,
        :unit_cost,
        :components_map
      ]
    end

    update :update do
      accept [:material_cost, :labor_cost, :overhead_cost, :unit_cost, :components_map]
    end

    update :change_currency do
      accept []

      argument :currency, :string
      argument :material_cost, AshMoney.Types.Money
      argument :labor_cost, AshMoney.Types.Money
      argument :overhead_cost, AshMoney.Types.Money
      argument :unit_cost, AshMoney.Types.Money

      material_cost = Money.to_currency(arg(:material_cost), arg(:currency))
      change set_attribute(:material_cost, material_cost)

      labor_cost = Money.to_currency(arg(:labor_cost), arg(:currency))
      change set_attribute(:labor_cost, labor_cost)

      overhead_cost = Money.to_currency(arg(:overhead_cost), arg(:currency))
      change set_attribute(:overhead_cost, overhead_cost)

      unit_cost = Money.to_currency(arg(:overhead_cost), arg(:currency))
      change set_attribute(:unit_cost, unit_cost)
      change run_oban_trigger(:process)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :material_cost, AshMoney.Types.Money do
      allow_nil? false
      default Money.new!(0, :EUR)
    end

    attribute :labor_cost, AshMoney.Types.Money do
      allow_nil? false
      default Money.new!(0, :EUR)
    end

    attribute :overhead_cost, AshMoney.Types.Money do
      allow_nil? false
      default Money.new!(0, :EUR)
    end

    attribute :unit_cost, AshMoney.Types.Money do
      allow_nil? false
      default Money.new!(0, :EUR)
    end

    # Flattened materials used per unit (JSONB map: material_id => quantity as string)
    attribute :components_map, :map do
      allow_nil? false
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :bom, Craftplan.Catalog.BOM do
      allow_nil? false
    end

    belongs_to :product, Craftplan.Catalog.Product do
      allow_nil? false
    end
  end

  identities do
    identity :unique_bom, [:bom_id]
  end
end
