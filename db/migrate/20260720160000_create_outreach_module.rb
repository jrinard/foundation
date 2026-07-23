# frozen_string_literal: true

class CreateOutreachModule < ActiveRecord::Migration[7.0]
  def change
    add_column :organizations, :outreach_enabled, :boolean, null: false, default: false

    create_table :outreach_plans do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :service_tag
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    create_table :outreach_plan_steps do |t|
      t.references :outreach_plan, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :name, null: false
      t.string :step_type, null: false
      t.text :instructions
      t.integer :suggested_day_offset

      t.timestamps
    end

    add_index :outreach_plan_steps,
              [:outreach_plan_id, :position],
              unique: true,
              name: "index_outreach_plan_steps_on_plan_and_position"

    create_table :outreach_campaigns do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :outreach_plan, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: "active"
      t.integer :cohort_goal

      t.timestamps
    end

    create_table :outreach_enrollments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :outreach_campaign, null: false, foreign_key: true
      t.references :outreach_plan, null: false, foreign_key: true
      t.integer :current_step_position, null: false, default: 1
      t.string :status, null: false, default: "ready"
      t.jsonb :plan_snapshot, null: false, default: []
      t.datetime :enrolled_at, null: false
      t.datetime :paused_at

      t.timestamps
    end

    add_index :outreach_enrollments,
              [:outreach_campaign_id, :customer_id],
              unique: true,
              name: "index_outreach_enrollments_on_campaign_and_customer"

    create_table :outreach_activities do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :outreach_enrollment, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :activity_type, null: false
      t.text :summary
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
