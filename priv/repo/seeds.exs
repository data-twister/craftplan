# seeds.exs
alias AshAuthentication.Strategy.Password
alias Craftplan.Accounts
alias Craftplan.Catalog
alias Craftplan.CRM
alias Craftplan.Inventory
alias Craftplan.Orders
alias Craftplan.Repo
alias Craftplan.Settings

require Ash.Query

# ------------------------------------------------------------------------------
# 1. Define helper functions for readability and code organization
# ------------------------------------------------------------------------------

seed_allergens = fn ->
  seed_single_allergen = fn name ->
    [allergen] =
      Ash.Seed.seed!(
        Inventory.Allergen,
        [%{name: name}],
        identity: :name
      )

    allergen
  end

  %{
    gluten: seed_single_allergen.("Gluten"),
    fish: seed_single_allergen.("Fish"),
    milk: seed_single_allergen.("Milk"),
    mustard: seed_single_allergen.("Mustard"),
    lupin: seed_single_allergen.("Lupin"),
    crustaceans: seed_single_allergen.("Crustaceans"),
    peanuts: seed_single_allergen.("Peanuts"),
    nuts: seed_single_allergen.("Tree Nuts"),
    sesame: seed_single_allergen.("Sesame"),
    mollusks: seed_single_allergen.("Mollusks"),
    eggs: seed_single_allergen.("Eggs"),
    soy: seed_single_allergen.("Soy"),
    celery: seed_single_allergen.("Celery"),
    sulphur: seed_single_allergen.("Sulphur Dioxide")
  }
end

# Add a function to seed nutritional facts
seed_nutritional_facts = fn ->
  seed_single_nutritional_fact = fn name ->
    [nutritional_fact] =
      Ash.Seed.seed!(
        Inventory.NutritionalFact,
        [%{name: name}],
        identity: :name
      )

    nutritional_fact
  end

  %{
    calories: seed_single_nutritional_fact.("Calories"),
    fat: seed_single_nutritional_fact.("Fat"),
    saturated_fat: seed_single_nutritional_fact.("Saturated Fat"),
    carbohydrates: seed_single_nutritional_fact.("Carbohydrates"),
    sugar: seed_single_nutritional_fact.("Sugar"),
    fiber: seed_single_nutritional_fact.("Fiber"),
    protein: seed_single_nutritional_fact.("Protein"),
    salt: seed_single_nutritional_fact.("Salt"),
    sodium: seed_single_nutritional_fact.("Sodium"),
    calcium: seed_single_nutritional_fact.("Calcium"),
    iron: seed_single_nutritional_fact.("Iron"),
    vitamin_a: seed_single_nutritional_fact.("Vitamin A"),
    vitamin_c: seed_single_nutritional_fact.("Vitamin C"),
    vitamin_d: seed_single_nutritional_fact.("Vitamin D")
  }
end

if System.get_env("SEED_DATA") == "true" or (Code.ensure_loaded?(Mix) and Mix.env() == :dev) do
  # ------------------------------------------------------------------------------
  # 2. Clear existing data (cleanup for repeated seeds in dev)
  # ------------------------------------------------------------------------------
#  Repo.delete_all(Orders.ProductionBatchLot)
#  Repo.delete_all(Orders.OrderItemBatchAllocation)
#  Repo.delete_all(Orders.OrderItemLot)
#  Repo.delete_all(Orders.OrderItem)
#  Repo.delete_all(Orders.Order)
#  # Legacy Recipe resources removed; no cleanup required
#  # Clear BOMs and related rollups/components before products to avoid FKs
#  Repo.delete_all(Catalog.BOMRollup)
#  Repo.delete_all(Catalog.BOMComponent)
#  Repo.delete_all(Catalog.LaborStep)
#  Repo.delete_all(Catalog.BOM)
#
#  # Clear products (after BOM cleanup)
#  Repo.delete_all(Catalog.Product)
#  Repo.delete_all(Inventory.Movement)
#  Repo.delete_all(Inventory.Lot)
#  Repo.delete_all(Inventory.MaterialNutritionalFact)
#  Repo.delete_all(Inventory.NutritionalFact)
#  Repo.delete_all(Inventory.MaterialAllergen)
#  # Purchasing domain must be cleared before materials (FK on material_id)
#  Repo.delete_all(Inventory.PurchaseOrderItem)
#  Repo.delete_all(Inventory.PurchaseOrder)
#  Repo.delete_all(Inventory.Supplier)
#  Repo.delete_all(Orders.ProductionBatch)
#  Repo.delete_all(Inventory.Material)
#  Repo.delete_all(Inventory.Allergen)
#  Repo.delete_all(CRM.Customer)
#  Repo.delete_all(Accounts.User)
#  Repo.delete_all(Settings.Settings)

  # ------------------------------------------------------------------------------
  # 3. Seed necessary data
  # ------------------------------------------------------------------------------

  seed_org = fn email, role ->
    {:ok, user} =
      Accounts.User
      |> Ash.Changeset.for_create(:register_with_organization, %{
        email: email,
        password: "Aa123123123123",
        password_confirmation: "Aa123123123123",
        role: role
      })
      |> Ash.create(
        context: %{
          strategy: Password,
          private: %{ash_authentication?: true}
        }
      )

    user
  end

  seed_user = fn email, role, organization ->
    {:ok, user} =
      Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "Aa123123123123",
        password_confirmation: "Aa123123123123",
        role: role,
        organization_id: organization.id
      })
      |> Ash.create(
        context: %{
          strategy: Password,
          private: %{ash_authentication?: true}
        }
      )

    user
  end

  seed_material = fn name, sku, unit, price, min, max, tenant ->
    Ash.Seed.seed!(
      Inventory.Material,
      %{
        name: name,
        sku: sku,
        unit: unit,
        price: Decimal.new(price),
        minimum_stock: Decimal.new(min),
        maximum_stock: Decimal.new(max)
      },
      tenant: tenant
    )
  end

  link_material_allergen = fn material, allergen, tenant ->
    Ash.Seed.seed!(
      Inventory.MaterialAllergen,
      %{
        material_id: material.id,
        allergen_id: allergen.id
      },
      tenant: tenant
    )
  end

  # Add a function to link materials to nutritional facts with amounts and units
  link_material_nutritional_fact = fn material, nutritional_fact, amount, unit, tenant ->
    Ash.Seed.seed!(
      Inventory.MaterialNutritionalFact,
      %{
        material_id: material.id,
        nutritional_fact_id: nutritional_fact.id,
        amount: Decimal.new(amount),
        unit: unit
      },
      tenant: tenant
    )
  end

  add_initial_stock = fn material, quantity, organization ->
    Ash.Seed.seed!(
      Inventory.Movement,
      %{
        material_id: material.id,
        occurred_at: DateTime.utc_now(),
        quantity: Decimal.new(quantity),
        reason: "Initial stock"
      },
      tenant: organization.prefix
    )
  end

  # Seed a lot for a material and receive quantity into that lot
  seed_lot_for = fn material, supplier, lot_code, quantity, expiry_in_days, organization ->
    lot =
      Ash.Seed.seed!(
        Inventory.Lot,
        %{
          lot_code: lot_code,
          material_id: material.id,
          supplier_id: supplier && supplier.id,
          received_at: DateTime.utc_now(),
          expiry_date: Date.add(Date.utc_today(), expiry_in_days)
        },
        tenant: organization.prefix
      )

    Ash.Seed.seed!(
      Inventory.Movement,
      %{
        material_id: material.id,
        lot_id: lot.id,
        occurred_at: DateTime.utc_now(),
        quantity: Decimal.new(quantity),
        reason: "Received lot #{lot_code}"
      },
      tenant: organization.prefix
    )

    lot
  end

  seed_product = fn name, sku, price, organization ->
    Ash.Seed.seed!(
      Catalog.Product,
      %{
        name: name,
        sku: sku,
        status: :active,
        price: Decimal.new(price)
      },
      tenant: organization.prefix
    )
  end

  # No recipe helpers (BOM-only seeding)

  seed_bom = fn product, component_defs, labor_defs, opts ->
    opts = opts || []

    status = Keyword.get(opts, :status, :draft)
    tenant = Keyword.get(opts, :tenant, nil)

    published_at =
      case Keyword.get(opts, :published_at) do
        nil ->
          if status == :active do
            DateTime.utc_now()
          end

        value ->
          value
      end

    components =
      component_defs
      |> Enum.with_index(1)
      |> Enum.map(fn {attrs, position} ->
        Map.put(attrs, :position, position)
      end)

    labor_steps =
      labor_defs
      |> Enum.with_index(1)
      |> Enum.map(fn {attrs, sequence} ->
        attrs
        |> Map.put(:sequence, sequence)
        |> Map.put_new(:units_per_run, Decimal.new("1"))
      end)

    Catalog.BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: product.id,
      name: Keyword.get(opts, :name, "#{product.name} BOM"),
      status: status,
      published_at: published_at,
      components: components,
      labor_steps: labor_steps
    })
    |> Ash.create!(authorize?: false, tenant: tenant)
  end

  # Purchasing helpers
  seed_supplier = fn name, email, organization ->
    Ash.Seed.seed!(
      Inventory.Supplier,
      %{
        name: name,
        contact_email: email
      },
      tenant: organization.prefix
    )
  end

  # Note: PurchaseOrder.create defaults status to :draft in the resource. For seeds we
  # still accept a `status` argument for readability, then update the PO accordingly so
  # the final state matches the scenario we want to illustrate (e.g. :ordered).
  seed_purchase_order = fn supplier, status, organization ->
    po =
      Ash.Seed.seed!(
        Inventory.PurchaseOrder,
        %{
          supplier_id: supplier.id,
          ordered_at: DateTime.utc_now()
        },
        tenant: organization.prefix
      )

    case status do
      s when s in [:ordered, :received, :cancelled] and po.status != s ->
        Ash.update!(po, %{status: s},
          action: :update,
          authorize?: false,
          tenant: organization.prefix
        )

      _ ->
        po
    end
  end

  seed_purchase_order_item = fn po, material, quantity, unit_price, organization ->
    Ash.Seed.seed!(
      Inventory.PurchaseOrderItem,
      %{
        purchase_order_id: po.id,
        material_id: material.id,
        quantity: Decimal.new(quantity),
        unit_price: Decimal.new(unit_price)
      },
      tenant: organization.prefix
    )
  end

  seed_customer = fn first_name, last_name, email, phone, address_map, organization ->
    Ash.Seed.seed!(
      CRM.Customer,
      %{
        type: :individual,
        first_name: first_name,
        last_name: last_name,
        email: email,
        phone: phone,
        billing_address: address_map,
        shipping_address: address_map,
        organization_id: organization.id
      },
      tenant: organization.prefix
    )
  end

  seed_order = fn customer, delivery_in_days, status, payment_status, organization ->
    Ash.Seed.seed!(
      Orders.Order,
      %{
        customer_id: customer.id,
        delivery_date: DateTime.add(DateTime.utc_now(), delivery_in_days, :day),
        status: status,
        payment_status: payment_status
      },
      tenant: organization.prefix
    )
  end

  seed_order_item = fn order, product, quantity, status, organization ->
    Ash.Seed.seed!(
      Orders.OrderItem,
      %{
        order_id: order.id,
        product_id: product.id,
        quantity: Decimal.new(quantity),
        unit_price: product.price,
        status: status
      },
      tenant: organization.prefix
    )
  end

  # -- 3.1 Create users
  org_owner = seed_org.("test@test.com", :owner)

  {:ok, user} =
    Craftplan.Accounts.User
    |> Ash.get!(org_owner.id, authorize?: false)
    |> Ash.load(:organization, authorize?: false)

  tenant = user.organization
  _admin_user = seed_user.("admin@test.com", :admin, tenant)
  _staff_user = seed_user.("staff@staff.com", :staff, tenant)
  _customer_user = seed_user.("customer@customer.com", :customer, tenant)

  # -- 3.2 Set up global bakery settings
  Ash.Seed.seed!(
    Settings.Settings,
    %{
      currency: :USD,
      tax_mode: :exclusive,
      tax_rate: Decimal.new("0.10"),
      offers_pickup: true,
      offers_delivery: true,
      lead_time_days: 1,
      daily_capacity: 25,
      shipping_flat: Decimal.new("5.00"),
      labor_hourly_rate: Decimal.new("18.50"),
      labor_overhead_percent: Decimal.new("0.15"),
      retail_markup_mode: :percent,
      retail_markup_value: Decimal.new("35"),
      wholesale_markup_mode: :percent,
      wholesale_markup_value: Decimal.new("20")
    },
    tenant: tenant
  )

  # -- 3.3 Allergen data
  allergens = seed_allergens.()

  # -- 3.4 Nutritional facts data
  nutritional_facts = seed_nutritional_facts.()

  # -- 3.5 Materials
  materials = %{
    flour: seed_material.("All Purpose Flour", "FLOUR-001", :gram, "0.002", "5000", "20000", tenant),
    whole_wheat: seed_material.("Whole Wheat Flour", "FLOUR-002", :gram, "0.003", "3000", "15000", tenant),
    rye_flour: seed_material.("Rye Flour", "FLOUR-003", :gram, "0.004", "2000", "8000", tenant),
    gluten_free_mix: seed_material.("Gluten-Free Flour Mix", "GF-001", :gram, "0.005", "1000", "7000", tenant),
    oats: seed_material.("Rolled Oats", "OATS-001", :gram, "0.0025", "2000", "10000", tenant),
    almonds: seed_material.("Whole Almonds", "NUTS-001", :gram, "0.02", "2000", "10000", tenant),
    walnuts: seed_material.("Walnuts", "NUTS-002", :gram, "0.025", "1500", "8000", tenant),
    eggs: seed_material.("Fresh Eggs", "EGG-001", :piece, "0.15", "100", "500", tenant),
    milk: seed_material.("Whole Milk", "MILK-001", :milliliter, "0.003", "2000", "10000", tenant),
    butter: seed_material.("Butter", "DAIRY-001", :gram, "0.01", "1000", "5000", tenant),
    cream_cheese: seed_material.("Cream Cheese", "DAIRY-002", :gram, "0.015", "500", "3000", tenant),
    sugar: seed_material.("White Sugar", "SUGAR-001", :gram, "0.003", "3000", "15000", tenant),
    brown_sugar: seed_material.("Brown Sugar", "SUGAR-002", :gram, "0.004", "2000", "10000", tenant),
    chocolate: seed_material.("Dark Chocolate", "CHOC-001", :gram, "0.02", "2000", "8000", tenant),
    vanilla: seed_material.("Vanilla Extract", "FLAV-001", :milliliter, "0.15", "500", "2000", tenant),
    cinnamon: seed_material.("Ground Cinnamon", "SPICE-001", :gram, "0.006", "300", "1500", tenant),
    yeast: seed_material.("Active Dry Yeast", "YEAST-001", :gram, "0.05", "500", "2000", tenant),
    salt: seed_material.("Sea Salt", "SALT-001", :gram, "0.001", "1000", "5000", tenant)
  }

  # -- 3.6 Link materials to relevant allergens
  link_material_allergen.(materials.flour, allergens.gluten, tenant)
  link_material_allergen.(materials.whole_wheat, allergens.gluten, tenant)
  link_material_allergen.(materials.rye_flour, allergens.gluten, tenant)
  link_material_allergen.(materials.gluten_free_mix, allergens.nuts, tenant)
  link_material_allergen.(materials.almonds, allergens.nuts, tenant)
  link_material_allergen.(materials.walnuts, allergens.nuts, tenant)
  link_material_allergen.(materials.eggs, allergens.eggs, tenant)
  link_material_allergen.(materials.milk, allergens.milk, tenant)
  link_material_allergen.(materials.butter, allergens.milk, tenant)
  link_material_allergen.(materials.cream_cheese, allergens.milk, tenant)

  # -- 3.7 Link materials to nutritional facts
  # Flour
  link_material_nutritional_fact.(
    materials.flour,
    nutritional_facts.calories,
    "350",
    :kcal,
    tenant
  )

  link_material_nutritional_fact.(
    materials.flour,
    nutritional_facts.carbohydrates,
    "73",
    :gram,
    tenant
  )

  link_material_nutritional_fact.(materials.flour, nutritional_facts.protein, "10", :gram, tenant)
  link_material_nutritional_fact.(materials.flour, nutritional_facts.fat, "1", :gram, tenant)

  # Whole Wheat Flour
  link_material_nutritional_fact.(
    materials.whole_wheat,
    nutritional_facts.calories,
    "340",
    :kcal,
    tenant
  )

  link_material_nutritional_fact.(
    materials.whole_wheat,
    nutritional_facts.carbohydrates,
    "72",
    :gram,
    tenant
  )

  link_material_nutritional_fact.(
    materials.whole_wheat,
    nutritional_facts.protein,
    "13",
    :gram,
    tenant
  )

  link_material_nutritional_fact.(
    materials.whole_wheat,
    nutritional_facts.fiber,
    "11",
    :gram,
    tenant
  )

  # Almonds
  link_material_nutritional_fact.(
    materials.almonds,
    nutritional_facts.calories,
    "580",
    :kcal,
    tenant
  )

  link_material_nutritional_fact.(materials.almonds, nutritional_facts.fat, "50", :gram, tenant)

  link_material_nutritional_fact.(
    materials.almonds,
    nutritional_facts.protein,
    "21",
    :gram,
    tenant
  )

  # Eggs
  link_material_nutritional_fact.(
    materials.eggs,
    nutritional_facts.calories,
    "155",
    :kcal,
    tenant
  )

  link_material_nutritional_fact.(materials.eggs, nutritional_facts.protein, "13", :gram, tenant)
  link_material_nutritional_fact.(materials.eggs, nutritional_facts.fat, "11", :gram, tenant)

  # Milk
  link_material_nutritional_fact.(materials.milk, nutritional_facts.calories, "42", :kcal, tenant)
  link_material_nutritional_fact.(materials.milk, nutritional_facts.protein, "3.4", :gram, tenant)

  link_material_nutritional_fact.(
    materials.milk,
    nutritional_facts.calcium,
    "125",
    :milligram,
    tenant
  )

  # Butter
  link_material_nutritional_fact.(
    materials.butter,
    nutritional_facts.calories,
    "717",
    :kcal,
    tenant
  )

  link_material_nutritional_fact.(materials.butter, nutritional_facts.fat, "81", :gram, tenant)

  link_material_nutritional_fact.(
    materials.butter,
    nutritional_facts.saturated_fat,
    "51",
    :gram,
    tenant
  )

  # Chocolate
  link_material_nutritional_fact.(
    materials.chocolate,
    nutritional_facts.calories,
    "546",
    :kcal,
    tenant
  )

  link_material_nutritional_fact.(materials.chocolate, nutritional_facts.fat, "31", :gram, tenant)

  link_material_nutritional_fact.(
    materials.chocolate,
    nutritional_facts.carbohydrates,
    "61",
    :gram,
    tenant
  )

  link_material_nutritional_fact.(
    materials.chocolate,
    nutritional_facts.iron,
    "8",
    :milligram,
    tenant
  )

  # -- 3.8 Add some initial stock
  Enum.each(materials, fn {_key, material} ->
    add_initial_stock.(material, "5000", tenant)
  end)

  # -- 3.8.1 Suppliers and Purchase Orders
  suppliers = %{
    miller: seed_supplier.("Miller & Co.", "hello@miller.test", tenant),
    dairy: seed_supplier.("Fresh Dairy Ltd.", "sales@dairy.test", tenant)
  }

  po1 = seed_purchase_order.(suppliers.miller, :ordered, tenant)
  seed_purchase_order_item.(po1, materials.flour, "10000", "0.0018", tenant)
  seed_purchase_order_item.(po1, materials.whole_wheat, "5000", "0.0027", tenant)

  po2 = seed_purchase_order.(suppliers.dairy, :ordered, tenant)
  seed_purchase_order_item.(po2, materials.butter, "2000", "0.009", tenant)
  seed_purchase_order_item.(po2, materials.milk, "5000", "0.0025", tenant)

  # -- 3.8.2 Seed example lots for FIFO/traceability testing
  # Dairy lots (perishables)
  _milk_lot1 =
    seed_lot_for.(
      materials.milk,
      suppliers.dairy,
      "LOT-MILK-#{Date.to_string(Date.utc_today())}-001",
      "1500",
      7,
      tenant
    )

  _milk_lot2 =
    seed_lot_for.(
      materials.milk,
      suppliers.dairy,
      "LOT-MILK-#{Date.to_string(Date.utc_today())}-002",
      "1200",
      14,
      tenant
    )

  _butter_lot =
    seed_lot_for.(
      materials.butter,
      suppliers.dairy,
      "LOT-BUTTER-#{Date.to_string(Date.utc_today())}-001",
      "800",
      60,
      tenant
    )

  # Flour lot (non-perishable)
  _flour_lot =
    seed_lot_for.(
      materials.flour,
      suppliers.miller,
      "LOT-FLOUR-#{Date.to_string(Date.utc_today())}-A",
      "2000",
      365,
      tenant
    )

  # -- 3.9 Seed products
  products = %{
    almond_cookies: seed_product.("Almond Cookies", "COOK-001", "3.99", tenant),
    choc_cake: seed_product.("Chocolate Cake", "CAKE-001", "15.99", tenant),
    bread: seed_product.("Artisan Bread", "BREAD-001", "4.99", tenant),
    muffins: seed_product.("Blueberry Muffins", "MUF-001", "2.99", tenant),
    croissants: seed_product.("Butter Croissants", "PAST-001", "2.50", tenant),
    gf_cupcakes: seed_product.("Gluten-Free Cupcakes", "CUP-001", "3.49", tenant),
    rye_loaf: seed_product.("Rye Loaf Bread", "BREAD-002", "5.49", tenant),
    carrot_cake: seed_product.("Carrot Cake", "CAKE-002", "12.99", tenant),
    oatmeal_cookies: seed_product.("Oatmeal Cookies", "COOK-002", "3.49", tenant),
    cheese_danish: seed_product.("Cheese Danish", "PAST-002", "2.99", tenant)
  }

  # Set product availability and per-day capacity to try the feature
  update_product = fn product, attrs ->
    product |> Ash.Changeset.for_update(:update, attrs) |> Ash.update!(authorize?: false)
  end

  products = %{
    almond_cookies: update_product.(products.almond_cookies, %{max_daily_quantity: 200}),
    choc_cake: update_product.(products.choc_cake, %{max_daily_quantity: 20}),
    bread: update_product.(products.bread, %{max_daily_quantity: 150}),
    muffins: update_product.(products.muffins, %{max_daily_quantity: 120}),
    croissants:
      update_product.(products.croissants, %{
        max_daily_quantity: 80,
        selling_availability: :preorder
      }),
    gf_cupcakes: update_product.(products.gf_cupcakes, %{max_daily_quantity: 60}),
    rye_loaf: update_product.(products.rye_loaf, %{max_daily_quantity: 50}),
    carrot_cake: update_product.(products.carrot_cake, %{selling_availability: :off, max_daily_quantity: 0}),
    oatmeal_cookies: update_product.(products.oatmeal_cookies, %{max_daily_quantity: 200}),
    cheese_danish: update_product.(products.cheese_danish, %{max_daily_quantity: 100})
  }

  # -- 3.12 Seed customers
  customers = %{
    john:
      seed_customer.(
        "John",
        "Doe",
        "john@example.com",
        "1234567890",
        %{
          street: "123 Main St",
          city: "Springfield",
          state: "IL",
          zip: "12345",
          country: "USA"
        },
        tenant
      ),
    jane:
      seed_customer.(
        "Jane",
        "Smith",
        "jane@example.com",
        "9876543210",
        %{
          street: "456 Oak Ave",
          city: "Portland",
          state: "OR",
          zip: "97201",
          country: "USA"
        },
        tenant
      ),
    bob:
      seed_customer.(
        "Bob",
        "Johnson",
        "bob@example.com",
        "5551234567",
        %{
          street: "789 Pine St",
          city: "Seattle",
          state: "WA",
          zip: "98101",
          country: "USA"
        },
        tenant
      ),
    alice:
      seed_customer.(
        "Alice",
        "Anderson",
        "alice@example.com",
        "2225557777",
        %{
          street: "101 Apple Rd",
          city: "Denver",
          state: "CO",
          zip: "80203",
          country: "USA"
        },
        tenant
      ),
    michael:
      seed_customer.(
        "Michael",
        "Brown",
        "michael@example.com",
        "1112223333",
        %{
          street: "202 Banana Blvd",
          city: "Phoenix",
          state: "AZ",
          zip: "85001",
          country: "USA"
        },
        tenant
      ),
    grace:
      seed_customer.(
        "Grace",
        "Thomas",
        "grace@example.com",
        "4445556666",
        %{
          street: "350 Elm St",
          city: "Austin",
          state: "TX",
          zip: "73301",
          country: "USA"
        },
        tenant
      ),
    taylor:
      seed_customer.(
        "Taylor",
        "Evans",
        "taylor@example.com",
        "7778889999",
        %{
          street: "999 Maple Ave",
          city: "Boston",
          state: "MA",
          zip: "02215",
          country: "USA"
        },
        tenant
      ),
    emily:
      seed_customer.(
        "Emily",
        "Clark",
        "emily@example.com",
        "6667778888",
        %{
          street: "202 Cedar St",
          city: "Chicago",
          state: "IL",
          zip: "60601",
          country: "USA"
        },
        tenant
      )
  }

  # -- 3.13 Seed demo orders for Bread (today) and create an open batch with allocations
  bread_order1 =
    Ash.Seed.seed!(
      Orders.Order,
      %{
        customer_id: customers.john.id,
        delivery_date: DateTime.utc_now(),
        status: :confirmed,
        payment_status: :pending
      },
      tenant: tenant.prefix
    )

  bread_item1 =
    Ash.Seed.seed!(
      Orders.OrderItem,
      %{
        order_id: bread_order1.id,
        product_id: products.bread.id,
        quantity: Decimal.new("10"),
        unit_price: products.bread.price,
        status: :todo
      },
      tenant: tenant.prefix
    )

  bread_order2 =
    Ash.Seed.seed!(
      Orders.Order,
      %{
        customer_id: customers.jane.id,
        delivery_date: DateTime.utc_now(),
        status: :confirmed,
        payment_status: :pending
      },
      tenant: tenant.prefix
    )

  bread_item2 =
    Ash.Seed.seed!(
      Orders.OrderItem,
      %{
        order_id: bread_order2.id,
        product_id: products.bread.id,
        quantity: Decimal.new("5"),
        unit_price: products.bread.price,
        status: :todo
      },
      tenant: tenant.prefix
    )

  demo_batch_code =
    "B-" <> Calendar.strftime(Date.utc_today(), "%Y%m%d") <> "-" <> products.bread.sku <> "-DEV"

  bread_batch =
    Ash.Seed.seed!(
      Orders.ProductionBatch,
      %{
        batch_code: demo_batch_code,
        product_id: products.bread.id,
        planned_qty: Decimal.new("15"),
        produced_qty: Decimal.new("0"),
        scrap_qty: Decimal.new("0"),
        status: :open,
        components_map: %{}
      },
      tenant: tenant.prefix
    )

  _ =
    Ash.Seed.seed!(
      Orders.OrderItemBatchAllocation,
      %{
        production_batch_id: bread_batch.id,
        order_item_id: bread_item1.id,
        planned_qty: Decimal.new("10"),
        completed_qty: Decimal.new("0")
      },
      tenant: tenant.prefix
    )

  _ =
    Ash.Seed.seed!(
      Orders.OrderItemBatchAllocation,
      %{
        production_batch_id: bread_batch.id,
        order_item_id: bread_item2.id,
        planned_qty: Decimal.new("5"),
        completed_qty: Decimal.new("0")
      },
      tenant: tenant.prefix
    )

  # ------------------------------------------------------------------------------
  # ✨ Add-on: richer scenarios and edge cases
  # ------------------------------------------------------------------------------

  # Helper for non-initial stock movements
  adjust_stock = fn material, quantity, reason, days_from_now ->
    Ash.Seed.seed!(
      Inventory.Movement,
      %{
        material_id: material.id,
        occurred_at: DateTime.add(DateTime.utc_now(), days_from_now, :day),
        quantity: Decimal.new(quantity),
        reason: reason
      },
      tenant: tenant.prefix
    )
  end

  # A) New materials to unlock more recipes
  new_materials = %{
    blueberries: seed_material.("Blueberries", "FRUIT-001", :gram, "0.010", "500", "3000", tenant),
    sesame_seeds: seed_material.("Sesame Seeds", "SEED-001", :gram, "0.012", "500", "3000", tenant),
    peanut_butter: seed_material.("Peanut Butter", "PB-001", :gram, "0.015", "500", "3000", tenant)
  }

  materials = Map.merge(materials, new_materials)

  # Link new materials to allergens
  link_material_allergen.(materials.sesame_seeds, allergens.sesame, tenant)
  link_material_allergen.(materials.peanut_butter, allergens.peanuts, tenant)

  # Nutritional facts for the new materials
  link_material_nutritional_fact.(
    materials.blueberries,
    nutritional_facts.calories,
    "57",
    :kcal,
    tenant
  )

  link_material_nutritional_fact.(
    materials.blueberries,
    nutritional_facts.fiber,
    "2.4",
    :gram,
    tenant
  )

  link_material_nutritional_fact.(
    materials.sesame_seeds,
    nutritional_facts.calories,
    "573",
    :kcal,
    tenant
  )

  link_material_nutritional_fact.(
    materials.sesame_seeds,
    nutritional_facts.fat,
    "50",
    :gram,
    tenant
  )

  link_material_nutritional_fact.(
    materials.peanut_butter,
    nutritional_facts.calories,
    "588",
    :kcal,
    tenant
  )

  link_material_nutritional_fact.(
    materials.peanut_butter,
    nutritional_facts.fat,
    "50",
    :gram,
    tenant
  )

  link_material_nutritional_fact.(
    materials.peanut_butter,
    nutritional_facts.protein,
    "25",
    :gram,
    tenant
  )

  # Stock for new materials
  Enum.each(new_materials, fn {_k, m} -> add_initial_stock.(m, "3000", tenant) end)

  # C) New products
  new_products = %{
    sesame_bagel: seed_product.("Sesame Bagel", "BAGEL-001", "2.25", tenant),
    pb_cookies: seed_product.("Peanut Butter Cookies", "COOK-003", "3.79", tenant)
  }

  products = Map.merge(products, new_products)

  # Availability and caps for new products
  products =
    products
    |> Map.put(:sesame_bagel, update_product.(products.sesame_bagel, %{max_daily_quantity: 120}))
    |> Map.put(:pb_cookies, update_product.(products.pb_cookies, %{max_daily_quantity: 180}))

  # -- 3.11 Seed BOMs (80%+ active coverage, no drafts)
  _almond_cookies_bom =
    seed_bom.(
      products.almond_cookies,
      [
        %{
          component_type: :material,
          material_id: materials.flour.id,
          quantity: Decimal.new("50")
        },
        %{
          component_type: :material,
          material_id: materials.almonds.id,
          quantity: Decimal.new("25")
        },
        %{
          component_type: :material,
          material_id: materials.sugar.id,
          quantity: Decimal.new("30")
        },
        %{
          component_type: :material,
          material_id: materials.butter.id,
          quantity: Decimal.new("25"),
          waste_percent: Decimal.new("0.03")
        },
        %{component_type: :material, material_id: materials.eggs.id, quantity: Decimal.new("1")}
      ],
      [
        %{
          name: "Prep dough",
          duration_minutes: Decimal.new("10"),
          units_per_run: Decimal.new("48")
        },
        %{
          name: "Sheet & cut",
          duration_minutes: Decimal.new("8"),
          units_per_run: Decimal.new("48")
        },
        %{
          name: "Bake trays",
          duration_minutes: Decimal.new("12"),
          rate_override: Decimal.new("25"),
          units_per_run: Decimal.new("48")
        }
      ],
      status: :active,
      name: "Almond Cookies BOM v1",
      tenant: tenant.prefix
    )

  _almond_cookies_archived =
    seed_bom.(
      products.almond_cookies,
      [
        %{
          component_type: :material,
          material_id: materials.flour.id,
          quantity: Decimal.new("48")
        },
        %{
          component_type: :material,
          material_id: materials.almonds.id,
          quantity: Decimal.new("27")
        },
        %{
          component_type: :material,
          material_id: materials.brown_sugar.id,
          quantity: Decimal.new("28")
        },
        %{
          component_type: :material,
          material_id: materials.butter.id,
          quantity: Decimal.new("26"),
          waste_percent: Decimal.new("0.05")
        },
        %{component_type: :material, material_id: materials.eggs.id, quantity: Decimal.new("1")}
      ],
      [
        %{
          name: "Prep dough",
          duration_minutes: Decimal.new("11"),
          units_per_run: Decimal.new("48")
        },
        %{
          name: "Bake tests",
          duration_minutes: Decimal.new("14"),
          units_per_run: Decimal.new("48")
        }
      ],
      status: :archived,
      name: "Almond Cookies BOM R&D",
      tenant: tenant.prefix
    )

  _choc_cake_bom =
    seed_bom.(
      products.choc_cake,
      [
        %{
          component_type: :material,
          material_id: materials.flour.id,
          quantity: Decimal.new("220")
        },
        %{
          component_type: :material,
          material_id: materials.sugar.id,
          quantity: Decimal.new("180")
        },
        %{component_type: :material, material_id: materials.eggs.id, quantity: Decimal.new("4")},
        %{
          component_type: :material,
          material_id: materials.butter.id,
          quantity: Decimal.new("90")
        },
        %{
          component_type: :material,
          material_id: materials.chocolate.id,
          quantity: Decimal.new("120")
        },
        %{component_type: :material, material_id: materials.milk.id, quantity: Decimal.new("140")}
      ],
      [
        %{name: "Mix batter", duration_minutes: Decimal.new("15")},
        %{name: "Bake layers", duration_minutes: Decimal.new("40")},
        %{name: "Frost & finish", duration_minutes: Decimal.new("12")}
      ],
      status: :active,
      name: "Chocolate Cake BOM v1",
      tenant: tenant.prefix
    )

  _bread_bom =
    seed_bom.(
      products.bread,
      [
        %{
          component_type: :material,
          material_id: materials.flour.id,
          quantity: Decimal.new("500"),
          waste_percent: Decimal.new("0.05")
        },
        %{component_type: :material, material_id: materials.yeast.id, quantity: Decimal.new("7")},
        %{component_type: :material, material_id: materials.salt.id, quantity: Decimal.new("10")}
      ],
      [
        %{
          name: "Mix & knead",
          duration_minutes: Decimal.new("15"),
          units_per_run: Decimal.new("12")
        },
        %{
          name: "Bulk proof",
          duration_minutes: Decimal.new("60"),
          rate_override: Decimal.new("18")
        },
        %{
          name: "Bake loaves",
          duration_minutes: Decimal.new("35"),
          units_per_run: Decimal.new("12")
        }
      ],
      status: :active,
      name: "Artisan Bread BOM v1",
      tenant: tenant.prefix
    )

  _muffins_bom =
    seed_bom.(
      products.muffins,
      [
        %{
          component_type: :material,
          material_id: materials.flour.id,
          quantity: Decimal.new("120")
        },
        %{
          component_type: :material,
          material_id: materials.sugar.id,
          quantity: Decimal.new("80")
        },
        %{
          component_type: :material,
          material_id: materials.butter.id,
          quantity: Decimal.new("60")
        },
        %{component_type: :material, material_id: materials.eggs.id, quantity: Decimal.new("2")},
        %{
          component_type: :material,
          material_id: materials.milk.id,
          quantity: Decimal.new("100")
        },
        %{
          component_type: :material,
          material_id: materials.blueberries.id,
          quantity: Decimal.new("90")
        }
      ],
      [
        %{
          name: "Mix batter",
          duration_minutes: Decimal.new("8"),
          units_per_run: Decimal.new("24")
        },
        %{
          name: "Fill tins",
          duration_minutes: Decimal.new("4"),
          units_per_run: Decimal.new("24")
        },
        %{name: "Bake", duration_minutes: Decimal.new("18"), units_per_run: Decimal.new("24")}
      ],
      status: :active,
      name: "Blueberry Muffins BOM v1",
      tenant: tenant.prefix
    )

  _croissants_bom =
    seed_bom.(
      products.croissants,
      [
        %{
          component_type: :material,
          material_id: materials.flour.id,
          quantity: Decimal.new("300")
        },
        %{
          component_type: :material,
          material_id: materials.butter.id,
          quantity: Decimal.new("200"),
          waste_percent: Decimal.new("0.08")
        },
        %{component_type: :material, material_id: materials.yeast.id, quantity: Decimal.new("5")},
        %{component_type: :material, material_id: materials.milk.id, quantity: Decimal.new("100")}
      ],
      [
        %{
          name: "Laminate butter",
          duration_minutes: Decimal.new("45"),
          units_per_run: Decimal.new("20")
        },
        %{name: "Proof", duration_minutes: Decimal.new("90"), units_per_run: Decimal.new("20")},
        %{name: "Bake", duration_minutes: Decimal.new("20"), units_per_run: Decimal.new("12")}
      ],
      status: :active,
      name: "Croissant BOM v1",
      tenant: tenant.prefix
    )

  _gf_cupcakes_bom =
    seed_bom.(
      products.gf_cupcakes,
      [
        %{
          component_type: :material,
          material_id: materials.gluten_free_mix.id,
          quantity: Decimal.new("140")
        },
        %{
          component_type: :material,
          material_id: materials.sugar.id,
          quantity: Decimal.new("90")
        },
        %{component_type: :material, material_id: materials.eggs.id, quantity: Decimal.new("2")},
        %{
          component_type: :material,
          material_id: materials.butter.id,
          quantity: Decimal.new("60")
        },
        %{
          component_type: :material,
          material_id: materials.vanilla.id,
          quantity: Decimal.new("8")
        }
      ],
      [
        %{
          name: "Mix batter",
          duration_minutes: Decimal.new("9"),
          units_per_run: Decimal.new("12")
        },
        %{name: "Pipe", duration_minutes: Decimal.new("5"), units_per_run: Decimal.new("12")},
        %{name: "Bake", duration_minutes: Decimal.new("20"), units_per_run: Decimal.new("20")}
      ],
      status: :active,
      name: "Gluten-Free Cupcakes BOM v1",
      tenant: tenant.prefix
    )

  _rye_loaf_bom =
    seed_bom.(
      products.rye_loaf,
      [
        %{
          component_type: :material,
          material_id: materials.rye_flour.id,
          quantity: Decimal.new("350")
        },
        %{
          component_type: :material,
          material_id: materials.whole_wheat.id,
          quantity: Decimal.new("150")
        },
        %{component_type: :material, material_id: materials.yeast.id, quantity: Decimal.new("6")},
        %{component_type: :material, material_id: materials.salt.id, quantity: Decimal.new("9")}
      ],
      [
        %{
          name: "Mix dough",
          duration_minutes: Decimal.new("14"),
          units_per_run: Decimal.new("8")
        },
        %{name: "Proof", duration_minutes: Decimal.new("55"), units_per_run: Decimal.new("8")},
        %{name: "Bake", duration_minutes: Decimal.new("38"), units_per_run: Decimal.new("8")}
      ],
      status: :active,
      name: "Rye Loaf BOM v1",
      tenant: tenant.prefix
    )

  _carrot_cake_bom =
    seed_bom.(
      products.carrot_cake,
      [
        %{
          component_type: :material,
          material_id: materials.flour.id,
          quantity: Decimal.new("200")
        },
        %{
          component_type: :material,
          material_id: materials.sugar.id,
          quantity: Decimal.new("150")
        },
        %{component_type: :material, material_id: materials.eggs.id, quantity: Decimal.new("3")},
        %{
          component_type: :material,
          material_id: materials.butter.id,
          quantity: Decimal.new("75")
        },
        %{
          component_type: :material,
          material_id: materials.cinnamon.id,
          quantity: Decimal.new("5")
        },
        %{
          component_type: :product,
          product_id: products.almond_cookies.id,
          quantity: Decimal.new("0.2")
        }
      ],
      [
        %{
          name: "Mix batter",
          duration_minutes: Decimal.new("12"),
          units_per_run: Decimal.new("1")
        },
        %{
          name: "Bake layers",
          duration_minutes: Decimal.new("45"),
          units_per_run: Decimal.new("1")
        },
        %{
          name: "Frost & decorate",
          duration_minutes: Decimal.new("10"),
          rate_override: Decimal.new("22"),
          units_per_run: Decimal.new("1")
        }
      ],
      status: :active,
      name: "Carrot Cake BOM v1",
      tenant: tenant.prefix
    )

  _oatmeal_cookies_bom =
    seed_bom.(
      products.oatmeal_cookies,
      [
        %{
          component_type: :material,
          material_id: materials.oats.id,
          quantity: Decimal.new("120")
        },
        %{
          component_type: :material,
          material_id: materials.flour.id,
          quantity: Decimal.new("80")
        },
        %{
          component_type: :material,
          material_id: materials.brown_sugar.id,
          quantity: Decimal.new("70")
        },
        %{
          component_type: :material,
          material_id: materials.butter.id,
          quantity: Decimal.new("60")
        },
        %{component_type: :material, material_id: materials.eggs.id, quantity: Decimal.new("1")},
        %{
          component_type: :material,
          material_id: materials.cinnamon.id,
          quantity: Decimal.new("4")
        }
      ],
      [
        %{
          name: "Cream butter & sugar",
          duration_minutes: Decimal.new("6"),
          units_per_run: Decimal.new("48")
        },
        %{
          name: "Fold dry ingredients",
          duration_minutes: Decimal.new("5"),
          units_per_run: Decimal.new("48")
        },
        %{name: "Bake", duration_minutes: Decimal.new("16"), units_per_run: Decimal.new("48")}
      ],
      status: :active,
      name: "Oatmeal Cookies BOM v1",
      tenant: tenant.prefix
    )

  _cheese_danish_bom =
    seed_bom.(
      products.cheese_danish,
      [
        %{
          component_type: :material,
          material_id: materials.flour.id,
          quantity: Decimal.new("220")
        },
        %{
          component_type: :material,
          material_id: materials.butter.id,
          quantity: Decimal.new("160")
        },
        %{
          component_type: :material,
          material_id: materials.cream_cheese.id,
          quantity: Decimal.new("100")
        },
        %{
          component_type: :material,
          material_id: materials.sugar.id,
          quantity: Decimal.new("60")
        },
        %{component_type: :material, material_id: materials.eggs.id, quantity: Decimal.new("1")}
      ],
      [
        %{
          name: "Laminate dough",
          duration_minutes: Decimal.new("35"),
          units_per_run: Decimal.new("24")
        },
        %{
          name: "Prepare filling",
          duration_minutes: Decimal.new("8"),
          units_per_run: Decimal.new("24")
        },
        %{name: "Bake", duration_minutes: Decimal.new("18"), units_per_run: Decimal.new("24")}
      ],
      status: :active,
      name: "Cheese Danish BOM v1",
      tenant: tenant.prefix
    )

  # Leave some products without a BOM to represent newly onboarded catalog items
  _products_without_boms = [:sesame_bagel, :pb_cookies]

  # D) Inventory edge cases: spoilage, breakage, low stock and receipts
  adjust_stock.(materials.milk, "-1000", "Spoilage – fridge failure", -1, tenant)
  adjust_stock.(materials.eggs, "-12", "Breakage – dropped tray", 0, tenant)
  adjust_stock.(materials.yeast, "-400", "Use in production surge", -2, tenant)
  adjust_stock.(materials.yeast, "-300", "Use in production surge", -1, tenant)

  supplier_baker = seed_supplier.("Baker Supplies", "orders@bakersup.test", tenant)
  po3 = seed_purchase_order.(supplier_baker, :ordered, tenant)
  seed_purchase_order_item.(po3, materials.butter, "1500", "0.0095", tenant)
  seed_purchase_order_item.(po3, materials.yeast, "1200", "0.048", tenant)

  # Receive stock today
  adjust_stock.(materials.butter, "1500", "PO #{po3.id} receipt", 0, tenant)
  adjust_stock.(materials.yeast, "1200", "PO #{po3.id} receipt", 0, tenant)

  # E) Capacity stress test for tomorrow
  cap1 = seed_order.(customers.john, 1, :confirmed, :pending, tenant)
  seed_order_item.(cap1, products.croissants, "60", :todo, tenant)
  seed_order_item.(cap1, products.muffins, "40", :todo, tenant)

  cap2 = seed_order.(customers.jane, 1, :confirmed, :pending, tenant)
  seed_order_item.(cap2, products.sesame_bagel, "50", :todo, tenant)
  seed_order_item.(cap2, products.pb_cookies, "30", :todo, tenant)

  # F) Availability off edge case
  off_case = seed_order.(customers.michael, 9, :unconfirmed, :pending, tenant)
  seed_order_item.(off_case, products.carrot_cake, "1", :todo, tenant)

  # G) Long-range history
  old_q = seed_order.(customers.alice, -90, :delivered, :paid, tenant)
  seed_order_item.(old_q, products.bread, "2", :done, tenant)
  seed_order_item.(old_q, products.oatmeal_cookies, "18", :done, tenant)

  old_h = seed_order.(customers.bob, -180, :delivered, :paid, tenant)
  seed_order_item.(old_h, products.rye_loaf, "3", :done, tenant)
  seed_order_item.(old_h, products.choc_cake, "1", :done, tenant)

  # H) Allergen-heavy event order
  allergen_party = seed_order.(customers.grace, 6, :unconfirmed, :pending, tenant)
  # tree nuts
  seed_order_item.(allergen_party, products.almond_cookies, "24", :todo, tenant)
  # peanuts
  seed_order_item.(allergen_party, products.pb_cookies, "24", :todo, tenant)
  # sesame
  seed_order_item.(allergen_party, products.sesame_bagel, "24", :todo, tenant)

  # ------------------------------------------------------------------------------
  # 4. Create orders for these customers (simulate real bakery operations)
  # ------------------------------------------------------------------------------
  # -----------------------------
  # PAST WEEK (Days -7 to -1)
  # -----------------------------

  # Last Week - Monday (Day -7)
  order1 = seed_order.(customers.john, -7, :delivered, :paid, tenant)
  seed_order_item.(order1, products.bread, "2", :done, tenant)
  seed_order_item.(order1, products.muffins, "6", :done, tenant)
  seed_order_item.(order1, products.croissants, "4", :done, tenant)

  order2 = seed_order.(customers.jane, -7, :delivered, :paid, tenant)
  seed_order_item.(order2, products.choc_cake, "1", :done, tenant)
  seed_order_item.(order2, products.gf_cupcakes, "8", :done, tenant)

  order3 = seed_order.(customers.michael, -7, :delivered, :paid, tenant)
  seed_order_item.(order3, products.oatmeal_cookies, "12", :done, tenant)
  seed_order_item.(order3, products.bread, "1", :done, tenant)
  seed_order_item.(order3, products.rye_loaf, "1", :done, tenant)

  # Last Week - Tuesday (Day -6)
  order4 = seed_order.(customers.alice, -6, :delivered, :paid, tenant)
  seed_order_item.(order4, products.bread, "3", :done, tenant)
  seed_order_item.(order4, products.carrot_cake, "1", :done, tenant)

  order5 = seed_order.(customers.grace, -6, :delivered, :paid, tenant)
  seed_order_item.(order5, products.cheese_danish, "5", :done, tenant)
  seed_order_item.(order5, products.croissants, "6", :done, tenant)
  seed_order_item.(order5, products.almond_cookies, "10", :done, tenant)

  order6 = seed_order.(customers.bob, -6, :cancelled, :refunded, tenant)
  seed_order_item.(order6, products.choc_cake, "1", :done, tenant)

  # Last Week - Thursday (Day -4)
  order7 = seed_order.(customers.taylor, -4, :delivered, :paid, tenant)
  seed_order_item.(order7, products.choc_cake, "2", :done, tenant)
  seed_order_item.(order7, products.bread, "2", :done, tenant)

  order8 = seed_order.(customers.emily, -4, :delivered, :paid, tenant)
  seed_order_item.(order8, products.rye_loaf, "1", :done, tenant)
  seed_order_item.(order8, products.croissants, "12", :done, tenant)
  seed_order_item.(order8, products.muffins, "4", :done, tenant)

  # Last Weekend - Saturday (Day -2)
  order9 = seed_order.(customers.john, -2, :delivered, :paid, tenant)
  seed_order_item.(order9, products.choc_cake, "1", :done, tenant)
  seed_order_item.(order9, products.muffins, "12", :done, tenant)
  seed_order_item.(order9, products.bread, "2", :done, tenant)
  seed_order_item.(order9, products.croissants, "8", :done, tenant)

  order10 = seed_order.(customers.michael, -2, :delivered, :paid, tenant)
  seed_order_item.(order10, products.choc_cake, "1", :done, tenant)
  seed_order_item.(order10, products.gf_cupcakes, "12", :done, tenant)

  order11 = seed_order.(customers.grace, -2, :delivered, :paid, tenant)
  seed_order_item.(order11, products.carrot_cake, "1", :done, tenant)
  seed_order_item.(order11, products.oatmeal_cookies, "24", :done, tenant)

  order12 = seed_order.(customers.jane, -2, :delivered, :paid, tenant)
  seed_order_item.(order12, products.choc_cake, "1", :done, tenant)
  seed_order_item.(order12, products.almond_cookies, "15", :done, tenant)

  # -----------------------------
  # CURRENT WEEK (Days 0 to 7)
  # -----------------------------

  # Today (Day 0)
  order13 = seed_order.(customers.alice, 0, :completed, :paid, tenant)
  seed_order_item.(order13, products.bread, "2", :done, tenant)
  seed_order_item.(order13, products.croissants, "6", :done, tenant)

  order14 = seed_order.(customers.bob, 0, :completed, :paid, tenant)
  seed_order_item.(order14, products.carrot_cake, "1", :done, tenant)
  seed_order_item.(order14, products.gf_cupcakes, "6", :done, tenant)
  seed_order_item.(order14, products.rye_loaf, "1", :done, tenant)

  order15 = seed_order.(customers.taylor, 0, :ready, :pending, tenant)
  seed_order_item.(order15, products.bread, "3", :done, tenant)
  seed_order_item.(order15, products.muffins, "8", :in_progress, tenant)

  order16 = seed_order.(customers.emily, 0, :ready, :pending, tenant)
  seed_order_item.(order16, products.choc_cake, "1", :done, tenant)
  seed_order_item.(order16, products.cheese_danish, "8", :in_progress, tenant)

  # Tomorrow (Day 1)
  order17 = seed_order.(customers.john, 1, :confirmed, :pending, tenant)
  seed_order_item.(order17, products.bread, "2", :in_progress, tenant)
  seed_order_item.(order17, products.croissants, "4", :todo, tenant)

  order18 = seed_order.(customers.jane, 1, :confirmed, :pending, tenant)
  seed_order_item.(order18, products.bread, "1", :done, tenant)
  seed_order_item.(order18, products.almond_cookies, "10", :todo, tenant)

  order19 = seed_order.(customers.michael, 1, :confirmed, :pending, tenant)
  seed_order_item.(order19, products.bread, "2", :in_progress, tenant)
  seed_order_item.(order19, products.oatmeal_cookies, "15", :done, tenant)
  seed_order_item.(order19, products.muffins, "6", :todo, tenant)

  # This Week - Wednesday (Day 3)
  order20 = seed_order.(customers.bob, 3, :confirmed, :pending, tenant)
  seed_order_item.(order20, products.choc_cake, "1", :in_progress, tenant)
  seed_order_item.(order20, products.rye_loaf, "2", :todo, tenant)

  order21 = seed_order.(customers.grace, 3, :confirmed, :pending, tenant)
  seed_order_item.(order21, products.choc_cake, "1", :done, tenant)
  seed_order_item.(order21, products.croissants, "8", :in_progress, tenant)
  seed_order_item.(order21, products.almond_cookies, "12", :todo, tenant)

  order22 = seed_order.(customers.alice, 3, :confirmed, :pending, tenant)
  seed_order_item.(order22, products.choc_cake, "1", :done, tenant)
  seed_order_item.(order22, products.muffins, "4", :in_progress, tenant)

  # This Week - Friday (Day 5)
  order23 = seed_order.(customers.taylor, 5, :unconfirmed, :pending, tenant)
  seed_order_item.(order23, products.carrot_cake, "2", :done, tenant)
  seed_order_item.(order23, products.bread, "3", :in_progress, tenant)
  seed_order_item.(order23, products.croissants, "6", :todo, tenant)

  order24 = seed_order.(customers.emily, 5, :unconfirmed, :pending, tenant)
  seed_order_item.(order24, products.carrot_cake, "1", :in_progress, tenant)
  seed_order_item.(order24, products.gf_cupcakes, "12", :todo, tenant)

  # Weekend Event Orders (Day 6-7)
  order25 = seed_order.(customers.john, 6, :unconfirmed, :pending, tenant)
  seed_order_item.(order25, products.carrot_cake, "1", :done, tenant)
  seed_order_item.(order25, products.cheese_danish, "12", :in_progress, tenant)
  seed_order_item.(order25, products.bread, "5", :in_progress, tenant)
  seed_order_item.(order25, products.croissants, "12", :todo, tenant)
  seed_order_item.(order25, products.muffins, "24", :todo, tenant)

  order26 = seed_order.(customers.jane, 6, :unconfirmed, :pending, tenant)
  seed_order_item.(order26, products.carrot_cake, "1", :done, tenant)
  seed_order_item.(order26, products.oatmeal_cookies, "20", :in_progress, tenant)

  order27 = seed_order.(customers.michael, 7, :unconfirmed, :pending, tenant)
  seed_order_item.(order27, products.choc_cake, "2", :done, tenant)
  seed_order_item.(order27, products.gf_cupcakes, "15", :in_progress, tenant)
  seed_order_item.(order27, products.rye_loaf, "3", :todo, tenant)

  # -----------------------------
  # NEXT WEEK (Days 8 to 14)
  # -----------------------------

  # Next Week - Monday (Day 8)
  order28 = seed_order.(customers.alice, 8, :unconfirmed, :pending, tenant)
  seed_order_item.(order28, products.bread, "2", :todo, tenant)
  seed_order_item.(order28, products.croissants, "6", :todo, tenant)

  order29 = seed_order.(customers.bob, 8, :unconfirmed, :pending, tenant)
  seed_order_item.(order29, products.choc_cake, "1", :todo, tenant)
  seed_order_item.(order29, products.muffins, "6", :todo, tenant)

  # Next Week - Tuesday (Day 9)
  order30 = seed_order.(customers.grace, 9, :unconfirmed, :pending, tenant)
  seed_order_item.(order30, products.cheese_danish, "10", :todo, tenant)
  seed_order_item.(order30, products.rye_loaf, "2", :todo, tenant)

  order31 = seed_order.(customers.taylor, 9, :unconfirmed, :pending, tenant)
  seed_order_item.(order31, products.bread, "3", :todo, tenant)
  seed_order_item.(order31, products.almond_cookies, "15", :todo, tenant)
  seed_order_item.(order31, products.croissants, "8", :todo, tenant)

  # Office Party Orders (Day 10)
  order32 = seed_order.(customers.emily, 10, :unconfirmed, :pending, tenant)
  seed_order_item.(order32, products.oatmeal_cookies, "30", :todo, tenant)
  seed_order_item.(order32, products.croissants, "24", :todo, tenant)
  seed_order_item.(order32, products.muffins, "18", :todo, tenant)

  order33 = seed_order.(customers.john, 10, :unconfirmed, :pending, tenant)
  seed_order_item.(order33, products.gf_cupcakes, "12", :todo, tenant)
  seed_order_item.(order33, products.cheese_danish, "15", :todo, tenant)

  # Next Week - Friday (Day 12)
  order34 = seed_order.(customers.jane, 12, :unconfirmed, :pending, tenant)
  seed_order_item.(order34, products.carrot_cake, "1", :todo, tenant)
  seed_order_item.(order34, products.bread, "2", :todo, tenant)

  order35 = seed_order.(customers.michael, 12, :unconfirmed, :pending, tenant)
  seed_order_item.(order35, products.choc_cake, "1", :todo, tenant)
  seed_order_item.(order35, products.almond_cookies, "12", :todo, tenant)
  seed_order_item.(order35, products.rye_loaf, "1", :todo, tenant)

  # Weekend Event (Day 13-14)
  order36 = seed_order.(customers.bob, 13, :unconfirmed, :pending, tenant)
  seed_order_item.(order36, products.choc_cake, "2", :todo, tenant)
  seed_order_item.(order36, products.carrot_cake, "1", :todo, tenant)
  seed_order_item.(order36, products.bread, "4", :todo, tenant)
  seed_order_item.(order36, products.muffins, "12", :todo, tenant)

  order37 = seed_order.(customers.alice, 14, :unconfirmed, :pending, tenant)
  seed_order_item.(order37, products.croissants, "18", :todo, tenant)
  seed_order_item.(order37, products.oatmeal_cookies, "24", :todo, tenant)

  order38 = seed_order.(customers.grace, 14, :unconfirmed, :pending, tenant)
  seed_order_item.(order38, products.gf_cupcakes, "12", :todo, tenant)
  seed_order_item.(order38, products.cheese_danish, "10", :todo, tenant)

  # -- 5. Recalculate persisted order totals now that all items exist
  for order <- Orders.list_orders!(%{}, load: [:items]) do
    order
    |> Ash.Changeset.for_update(:update, %{})
    |> Ash.update!()
  end

  # -- 6. Backfill: ensure completed items have batch_code/costs
  # Some completed items may have been created without triggering the status transition
  # hook. Toggle status to re-run costing & batch assignment.
  missing_batch_items =
    Craftplan.Orders.OrderItem
    |> Ash.Query.new()
    |> Ash.Query.filter(status == :done and is_nil(batch_code))
    |> Ash.read!(authorize?: false)

  Enum.each(missing_batch_items, fn item ->
    # Toggle to in_progress then back to done to drive AssignBatchCodeAndCost
    _ = Orders.update_item(item, %{status: :in_progress}, actor: nil)
    _ = Orders.update_item(item, %{status: :done}, actor: nil)
  end)

  IO.puts("Done!")
else
  IO.puts("Seeds are only allowed in the dev environment.")
end
