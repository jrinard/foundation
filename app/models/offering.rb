class Offering < ApplicationRecord
  include OrganizationScoped

  SLOT_COUNT = 30
  KINDS = %w[service product].freeze
  DEFAULT_KIND = "service"

  belongs_to :customer, optional: true

  validates :main, inclusion: { in: [true, false] }

  def self.slot_numbers
    (1..SLOT_COUNT).to_a
  end

  def self.template_slot_param_names
    slot_numbers.flat_map do |n|
      [
        :"offering_#{n}_name",
        :"offering_#{n}_category",
        :"offering_#{n}_kind"
      ]
    end
  end

  def self.template_sync_attribute_names
    slot_numbers.flat_map do |n|
      %W[offering_#{n}_name offering_#{n}_category offering_#{n}_kind]
    end
  end

  def self.kind_options_for_select
    KINDS.map { |kind| [kind.titleize, kind] }
  end

  def slot_name(number)
    public_send("offering_#{number}_name")
  end

  def slot_category(number)
    public_send("offering_#{number}_category")
  end

  def slot_kind(number)
    public_send("offering_#{number}_kind").presence || DEFAULT_KIND
  end

  def slot_active?(number)
    public_send("offering_#{number}_active")
  end

  def slot_configured?(number)
    slot_name(number).present?
  end

  def slot_label(number)
    parts = [slot_category(number), slot_name(number)].compact_blank
    parts.join(" ")
  end

  def sync_template_to_children!
    return unless main?

    attrs = self.class.template_sync_attribute_names.index_with { |name| public_send(name) }
    organization.offerings.where(main: false).update_all(attrs)
  end

  def copy_for_customer!(customer)
    copy = dup
    copy.main = false
    copy.customer = customer
    self.class.slot_numbers.each { |n| copy.public_send("offering_#{n}_active=", false) }
    copy.save!
    copy
  end
end
