defmodule Craftplan.Accounts.Organization do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias Ash.Resource.Info
  alias Craftplan.Accounts.Membership
  alias Craftplan.Accounts.User

  @doc """
  Tell Ash to use the domain as the tenant database prefix when using PostgreSQL as the database; otherwise, use the ID.
  """
  defimpl Ash.ToTenant do
    def to_tenant(resource, %{:slug => slug, :id => id}) do
      if Info.data_layer(resource) == AshPostgres.DataLayer &&
           Info.multitenancy_strategy(resource) == :context do
        slug
      else
        id
      end
    end
  end

  postgres do
    table "organizations"
    repo Craftplan.Repo

    # Automatic tenant schema creation
    manage_tenant do
      template ["org_", :slug]
      create? true
      update? false
    end
  end

  # Resource definition...
  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      default_accept [:slug, :name, :plan, :owner_id]

      change Craftplan.Accounts.Changes.Slugify
    end

    create :register_with_password do
      default_accept [:slug, :name]

      argument :owner, :map do
        allow_nil? false
      end

      change Craftplan.Accounts.Changes.Register
    end

    update :update do
      primary? true
      accept [:slug, :name, :plan, :owner_id]
      # require_atomic(false)
    end
  end

  policies do
    bypass action :register do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :active, :boolean, default: false, public?: true
    attribute :plan, :atom, default: :free, public?: true
    attribute :owner_id, :uuid, allow_nil?: true, public?: true
    attribute :slug, :string, allow_nil?: false, public?: true
  end

  relationships do
    belongs_to :owner, User do
      source_attribute :owner_id
      primary_key? true
      allow_nil? true
    end

    has_many :memberships, Membership do
      public? true
    end

    many_to_many :users, User do
      through Membership
      source_attribute_on_join_resource :organization_id
      destination_attribute_on_join_resource :user_id
      public? true
    end
  end
end
