class ActivityController < ApplicationController
  include NavModuleRequired
  require_nav_module :activity
  # First column: most recent qualifying activity per account; cap prevents an enormous list.
  RECENT_ACTIVITY_FEED_LIMIT = 100

  # Latest activity note per customer from: (1) users with role manager or superadmin,
  # or (2) the customer’s assigned account manager (notes.user_id = customers.user_id) so “book owner”
  # notes count even when their User role is not manager. Excludes other roles on someone else’s book.
  def self.manager_latest_notes_subquery
    <<~SQL.squish
      (SELECT DISTINCT ON (n.customer_id)
          n.customer_id,
          n.created_at AS am_last_note_at,
          n.text AS am_last_note_text,
          u.name AS am_last_note_author_name
        FROM notes n
        INNER JOIN users u ON u.id = n.user_id
        INNER JOIN customers c ON c.id = n.customer_id
        WHERE n.account_note = false
          AND (
            u.role IN ('manager', 'superadmin')
            OR (c.user_id IS NOT NULL AND n.user_id = c.user_id)
          )
        ORDER BY n.customer_id, n.created_at DESC) AS manager_latest_notes
    SQL
  end

  def index
    # Prevent Turbo from caching this page so filters work correctly
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"

    assign_account_manager_select_collections

    user_scope = params[:user_id].present? ? { user_id: params[:user_id] } : {}

    # All three columns read qualifying notes from the notes table (manager_latest_notes subquery).
    # customers.last_note / last_note_text are not used here. NotesController still syncs them for legacy UI.
    # To remove that denormalized pair (audit other references first): notes_controller.rb lines 35-36 & 48
    # (create), lines 103-106 & 108-110 (destroy sync only); customers_controller.rb line 477 (drop from permit);
    # new migration to remove customers.last_note / last_note_text (see db/schema.rb on customers). Line numbers drift.
    mgr_sub = self.class.manager_latest_notes_subquery
    mgr_join = "INNER JOIN #{mgr_sub} ON manager_latest_notes.customer_id = customers.id"
    mgr_left_join = "LEFT JOIN #{mgr_sub} ON manager_latest_notes.customer_id = customers.id"
    mgr_note_select = "customers.*, manager_latest_notes.am_last_note_at AS am_last_note_at, manager_latest_notes.am_last_note_text AS am_last_note_text, manager_latest_notes.am_last_note_author_name AS am_last_note_author_name"

    @last_note_of_each_customer = Customer.where(archived: false)
                                           .where(onBoard: ["Current on Board", "Current Not on Board"])
                                           .where(user_scope)
                                           .joins(mgr_join)
                                           .select(mgr_note_select)
                                           .includes(:user)
                                           .order("manager_latest_notes.am_last_note_at DESC")
                                           .limit(RECENT_ACTIVITY_FEED_LIMIT)

    @all_customers_with_0_notes = Customer.where(archived: false)
                                           .where(onBoard: ["Current on Board", "Current Not on Board"])
                                           .where(user_scope)
                                           .joins(mgr_left_join)
                                           .where("manager_latest_notes.customer_id IS NULL")
                                           .includes(:user)

    cadence = Customer::FOLLOWUP_CADENCE_KEYS
    aging_parts = ["manager_latest_notes.am_last_note_at IS NULL"]
    aging_binds = []
    cadence.each do |key|
      aging_parts << "(followup = ? AND manager_latest_notes.am_last_note_at < ?)"
      aging_binds << key
      aging_binds << key.to_i.days.ago
    end
    aging_sql = aging_parts.join(" OR ")

    @total_aging_count = Customer.where(archived: false)
                                 .where(onBoard: ["Current on Board", "Current Not on Board"])
                                 .where(followup: cadence)
                                 .where(user_scope)
                                 .joins(mgr_left_join)
                                 .where(aging_sql, *aging_binds)
                                 .distinct
                                 .count(:id)

    past_due_parts = []
    past_due_binds = []
    cadence.each do |key|
      past_due_parts << "(followup = ? AND manager_latest_notes.am_last_note_at < ?)"
      past_due_binds << key
      past_due_binds << key.to_i.days.ago
    end
    past_due_condition = past_due_parts.join(" OR ")

    # preload (not includes) avoids Rails losing rows when combining custom select + join + association
    base_query = Customer.where(archived: false)
                         .where(onBoard: ["Current on Board", "Current Not on Board"])
                         .where(user_scope)
                         .joins(mgr_join)
                         .select(mgr_note_select)

    followup_param = params[:followup].to_s.strip

    followup_scope = case followup_param
                     when "30"
                       base_query.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 60.days.ago, 30.days.ago)
                     when "60"
                       base_query.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 90.days.ago, 60.days.ago)
                     when "90"
                       base_query.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 120.days.ago, 90.days.ago)
                     when "120"
                       base_query.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 150.days.ago, 120.days.ago)
                     when "150"
                       base_query.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 180.days.ago, 150.days.ago)
                     when "180"
                       base_query.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 365.days.ago, 180.days.ago)
                     when "365"
                       # Must match @past_due_counts["365"]: (very old qualifying note ∧ past-due) ∨ (no qualifying note).
                       # Inner join alone omitted the “no note” group that Total Aging already counts.
                       base_left = Customer.where(archived: false)
                                           .where(onBoard: ["Current on Board", "Current Not on Board"])
                                           .where(followup: cadence)
                                           .where(user_scope)
                                           .joins(mgr_left_join)
                                           .select(mgr_note_select)
                       base_left.where(
                         "manager_latest_notes.customer_id IS NULL OR (manager_latest_notes.am_last_note_at < ? AND (#{past_due_condition}))",
                         365.days.ago,
                         *past_due_binds
                       )
                     else
                       base_query.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 120.days.ago, 90.days.ago)
                     end
    @followup_customers = followup_scope.order(Arel.sql("manager_latest_notes.am_last_note_at ASC NULLS FIRST")).preload(:user)
    base_with_mgr_notes = Customer.where(archived: false).where(onBoard: ["Current on Board", "Current Not on Board"]).where(user_scope).joins(mgr_join)
    @past_due_counts = {
      "30"  => base_with_mgr_notes.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 60.days.ago, 30.days.ago).where(past_due_condition, *past_due_binds).count,
      "60"  => base_with_mgr_notes.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 90.days.ago, 60.days.ago).where(past_due_condition, *past_due_binds).count,
      "90"  => base_with_mgr_notes.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 120.days.ago, 90.days.ago).where(past_due_condition, *past_due_binds).count,
      "120" => base_with_mgr_notes.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 150.days.ago, 120.days.ago).where(past_due_condition, *past_due_binds).count,
      "150" => base_with_mgr_notes.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 180.days.ago, 150.days.ago).where(past_due_condition, *past_due_binds).count,
      "180" => base_with_mgr_notes.where("manager_latest_notes.am_last_note_at >= ? AND manager_latest_notes.am_last_note_at < ?", 365.days.ago, 180.days.ago).where(past_due_condition, *past_due_binds).count,
      "365" => base_with_mgr_notes.where("manager_latest_notes.am_last_note_at < ?", 365.days.ago).where(past_due_condition, *past_due_binds).count
    }
    # Total aging includes customers with no qualifying note (LEFT JOIN); dropdown inner-join counts
    # skip them. Fold that set into "12 months" so at least one option reflects Total Aging overlap.
    no_qualifying_scope = Customer.where(archived: false).where(onBoard: ["Current on Board", "Current Not on Board"]).where(followup: cadence).where(user_scope).joins(mgr_left_join).where("manager_latest_notes.customer_id IS NULL")
    @past_due_counts["365"] += no_qualifying_scope.count



  end

end
