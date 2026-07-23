# frozen_string_literal: true

module OutreachHelper
  def outreach_step_marker(enrollment, step)
    position = step["position"].to_i
    current = enrollment.current_step_position

    if enrollment.plan_complete? || position < current
      "done"
    elsif position == current
      "current"
    else
      "upcoming"
    end
  end

  def outreach_step_marker_glyph(marker)
    case marker
    when "done" then "✔"
    when "current" then "▶"
    else "○"
    end
  end

  def outreach_step_channel_label(step_type)
    case step_type.to_s
    when Outreach::PlanStepTypes::SEND_SMS then "Text"
    when Outreach::PlanStepTypes::SEND_EMAIL then "Email"
    when Outreach::PlanStepTypes::PHONE_CALL then "Call"
    when Outreach::PlanStepTypes::VOICEMAIL then "Voicemail"
    when Outreach::PlanStepTypes::INTERNAL_TASK,
         Outreach::PlanStepTypes::RESEARCH,
         Outreach::PlanStepTypes::REVIEW_WEBSITE then "Research"
    when Outreach::PlanStepTypes::CLOSE then "Follow Up"
    when Outreach::PlanStepTypes::WAIT then "Wait"
    when Outreach::PlanStepTypes::DIRECT_MAIL then "Direct Mail"
    when Outreach::PlanStepTypes::FACEBOOK_MESSAGE then "Facebook"
    when Outreach::PlanStepTypes::LINKEDIN_MESSAGE then "LinkedIn"
    when Outreach::PlanStepTypes::SCHEDULE_APPOINTMENT then "Appointment"
    when Outreach::PlanStepTypes::SEND_PROPOSAL then "Proposal"
    else Outreach::PlanStepTypes.label_for(step_type)
    end
  end

  def outreach_status_badge_class(status)
    case status
    when OutreachEnrollment::STATUS_INTERESTED then "outreach-status-interested"
    when OutreachEnrollment::STATUS_COMPLETED then "outreach-status-completed"
    when OutreachEnrollment::STATUS_LOST then "outreach-status-lost"
    when OutreachEnrollment::STATUS_PAUSED, OutreachEnrollment::STATUS_FOLLOW_UP then "outreach-status-paused"
    else "outreach-status-default"
    end
  end

  def outreach_campaign_status_badge_class(campaign)
    case campaign.status
    when OutreachCampaign::STATUS_ACTIVE then "outreach-pill-active"
    when OutreachCampaign::STATUS_COMPLETED then "outreach-status-completed"
    else "outreach-pill-muted"
    end
  end

  def customer_crm_stage_label(customer)
    case customer.onBoard
    when "The List" then "Prospect"
    when "Lead on Board" then "Lead"
    when "Current on Board", "Current Not on Board" then "Current"
    when "Archive" then "Archived"
    else customer.onBoard.to_s
    end
  end

  def customer_crm_stage_badge_class(customer)
    case customer.onBoard
    when "The List" then "outreach-crm-prospect"
    when "Lead on Board" then "outreach-crm-lead"
    when "Current on Board", "Current Not on Board" then "outreach-crm-current"
    else "outreach-crm-muted"
    end
  end

  def outreach_customer_return_path(customer)
    if customer.onBoard == "The List"
      potentials_path(id: customer.id)
    else
      customers_path(id: customer.id)
    end
  end

  def outreach_customer_work_path(customer)
    outreach_customer_return_path(customer)
  end

  def outreach_plans_nav_class
    ["outreach-section-tab", ("is-active" if controller_name == "plans")].compact.join(" ")
  end

  def outreach_module_tab_class(section)
    active =
      (section == "outreach" && %w[campaigns enrollments].include?(controller_name)) ||
      (section == "plan" && controller_name == "plans")

    ["outreach-section-tab", ("is-active" if active)].compact.join(" ")
  end

  def outreach_campaign_tab_class(section)
    plan_tab = params[:tab] == "plan"
    active =
      (section == "plan" && plan_tab) ||
      (section == "outreach" && !plan_tab)

    ["outreach-section-tab", ("is-active" if active)].compact.join(" ")
  end

  def customer_promotable_to_lead?(customer)
    customer.onBoard == "The List"
  end

  def outreach_enrollment_groups(enrollments)
    Array(enrollments)
      .group_by(&:outreach_campaign_id)
      .map do |_campaign_id, rows|
        sorted = rows.sort_by(&:enrolled_at).reverse
        {
          campaign: sorted.first.outreach_campaign,
          active: sorted.find { |enrollment| !enrollment.closed? },
          prior: sorted.select(&:closed?)
        }
      end
      .sort_by { |group| group[:active]&.enrolled_at || group[:prior].first&.enrolled_at || Time.at(0) }
      .reverse
  end

  def outreach_activity_actor_label(activity)
    activity.user&.name.presence || "System"
  end
end
