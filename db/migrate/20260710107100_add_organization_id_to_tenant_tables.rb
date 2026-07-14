class AddOrganizationIdToTenantTables < ActiveRecord::Migration[7.0]
  TENANT_TABLES = %w[
    customers
    contacts
    notes
    lists
    leads
    offerings
    qb_invoices
    quickbooks_tokens
    stats
    site_settings
  ].freeze

  def up
    TENANT_TABLES.each do |table|
      add_reference table.to_sym, :organization, foreign_key: true, index: true
    end

    say_with_time "Backfilling organization_id for existing rows" do
      default_org = Organization.create!(
        name: "Default Organization",
        slug: "default",
        sales_pipeline_enabled: true
      )

      TENANT_TABLES.each do |table|
        execute <<~SQL.squish
          UPDATE #{table}
          SET organization_id = #{default_org.id}
          WHERE organization_id IS NULL
        SQL
      end

      User.find_each do |user|
        OrganizationMembership.find_or_create_by!(user: user, organization: default_org) do |membership|
          membership.role = if user.role.in?(%w[admin manager user])
                              user.role
                            elsif user.role == "superadmin"
                              "admin"
                            else
                              "user"
                            end
        end
      end
    end

    TENANT_TABLES.each do |table|
      change_column_null table.to_sym, :organization_id, false
    end
  end

  def down
    TENANT_TABLES.each do |table|
      remove_reference table.to_sym, :organization, foreign_key: true
    end
  end
end
