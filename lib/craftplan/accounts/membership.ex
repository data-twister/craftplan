defmodule Craftplan.Accounts.Membership do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "memberships"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:role, :user_id, :organization_id], update: []]
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      constraints one_of: [:owner, :admin, :member]
      default :member
      public? true
    end

    attribute :joined, :utc_datetime_usec do
      default &DateTime.utc_now/0
      public? true
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Craftplan.Accounts.Organization
    belongs_to :user, Craftplan.Accounts.User
  end

  identities do
    identity :unique_membership, [:user_id, :organization_id]
  end
end
