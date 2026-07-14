module OfferingSlotActions
  extend ActiveSupport::Concern

  private

  def ensure_main_offering!
    current_organization.offerings.find_or_create_by!(main: true)
  end

  def load_main_offering_template
    @cs = current_organization.offerings.find_by(main: true)
  end

  def apply_offering_slot_toggles!(offering_record)
    return unless offering_record

    Offering.slot_numbers.each do |n|
      active_key = :"offering_#{n}_active"
      false_key = :"offering_#{n}_active_false"

      if params[active_key].present?
        offering_record.update!("offering_#{n}_active" => true)
      elsif params[false_key].present?
        offering_record.update!("offering_#{n}_active" => false)
      end
    end
  end

  def offering_filter_param
    params[:sort_by_offering].presence || params[:sort_by_service]
  end

  def apply_offering_list_filter(customers_scope)
    filter = offering_filter_param
    return customers_scope if filter.blank?

    if filter =~ /\A(?:offering|service)_(\d+)_active\z/
      number = Regexp.last_match(1)
      column = "offering_#{number}_active"
      @chosen_filter = offering_filter_label(number)
      customers_scope.joins(:offerings).where(offerings: { column => true })
    else
      customers_scope
    end
  end

  def offering_filter_label(number)
    template = current_organization.offerings.find_by(main: true)
    return unless template

    template.slot_label(number.to_i)
  end

  def assign_customer_offering_from_template!(customer)
    template = current_organization.offerings.find_by(main: true)
    return unless template

    template.copy_for_customer!(customer)
  end
end
