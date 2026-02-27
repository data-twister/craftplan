defmodule Craftplan.Accounts.Group do
  @moduledoc false
  use Ash.Resource,
    domain: Craftplan.Accounts,
    data_layer: AshPostgres.DataLayer,
    notifiers: Ash.Notifier.PubSub

  postgres do
    table "groups"
    repo Craftplan.Repo
  end

  code_interface do
    define :list_groups, action: :read
  end

  actions do
    default_accept [:name, :description]
    defaults [:create, :read, :update, :destroy]
  end

  pub_sub do
    module CraftplanWeb.Endpoint

    prefix "groups"

    publish_all :update, [[:id, nil]]
    publish_all :create, [[:id, nil]]
    publish_all :destroy, [[:id, nil]]
  end

  preparations do
    prepare Craftplan.Preparations.SetTenant
  end

  changes do
    change Craftplan.Changes.SetTenant
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      description "Group name unique name"
      allow_nil? false
    end

    attribute :description, :string do
      description "Describes the intention of the group"
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    many_to_many :users, Craftplan.Accounts.User do
      through Craftplan.Accounts.UserGroup
      source_attribute_on_join_resource :group_id
      destination_attribute_on_join_resource :user_id
    end

    # lib/Craftplan/accounts/group.ex
    has_many :permissions, Craftplan.Accounts.GroupPermission do
      description "List of permission assigned to this group"
      destination_attribute :group_id
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
