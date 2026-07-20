# frozen_string_literal: true

# Generic Foundation modal — use anywhere instead of Bootstrap .modal
#
# Quick start:
#
#   <%= foundation_modal_wrapper controllers: "my-page" do %>
#     <%= foundation_modal_open_button "exampleModal", "Open settings" %>
#
#     <%= foundation_modal modal_id: "exampleModal", title: "Settings" do %>
#       <p>Body content</p>
#       <%= foundation_modal_footer do %>
#         <%= foundation_modal_close_button %>
#       <% end %>
#     <% end %>
#   <% end %>
#
# Open/close: foundation_modal_open_button, foundation_modal_close_button,
#   data-action="click->foundation-modal#open|close|toggle"
# Events: foundation-modal:opened, foundation-modal:closed (bubble from wrapper)
#
module FoundationModalHelper
  CONTROLLER = "foundation-modal"

  # Wrapper div with foundation-modal Stimulus controller (+ optional others).
  def foundation_modal_wrapper(controllers: nil, tag: :div, **html_options, &block)
    html_options[:data] ||= {}
    html_options[:data][:controller] = merge_controllers(
      html_options[:data][:controller],
      controllers
    )

    content_tag(tag, capture(&block), **html_options)
  end

  # Backdrop + dialog. Pass body via block; optional footer via `footer:` or foundation_modal_footer.
  def foundation_modal(modal_id:, title: nil, size: :md, footer: nil, hide_close: false,
                       aria_label: nil, dialog_class: nil, &block)
    render(
      layout: "shared/foundation_modal",
      locals: {
        modal_id: modal_id.to_s,
        title: title,
        size: size,
        footer: footer,
        hide_close: hide_close,
        aria_label: aria_label,
        dialog_class: dialog_class
      },
      &block
    )
  end

  # Button (or icon via block) that opens the modal. Chain extra actions in data: { action: "..." }.
  def foundation_modal_open_button(modal_id, label = nil, **options, &block)
    options[:type] = "button"
    options[:class] = token_list("btn btn-default", options[:class])
    options[:data] ||= {}
    options[:data][:action] = merge_stimulus_actions(
      options[:data][:action],
      "click->#{CONTROLLER}#open"
    )
    options[:aria] = (options[:aria] || {}).merge(controls: modal_id.to_s, expanded: false)

    if block_given?
      button_tag(**options, &block)
    else
      button_tag(label || "Open", **options)
    end
  end

  def foundation_modal_close_button(label = "Cancel", **options)
    options[:type] = "button"
    options[:class] = token_list("btn btn-dark", options[:class])
    options[:data] ||= {}
    options[:data][:action] = merge_stimulus_actions(
      options[:data][:action],
      "click->#{CONTROLLER}#close"
    )
    button_tag(label, **options)
  end

  def foundation_modal_footer(**html_options, &block)
    content_tag(
      :div,
      capture(&block),
      class: token_list("foundation-modal-footer", html_options.delete(:class)),
      **html_options
    )
  end

  private

  def merge_controllers(existing, additional)
    list = [existing, CONTROLLER, additional].flatten.compact
    list.flat_map { |entry| entry.to_s.split(/\s+/) }.uniq.join(" ")
  end

  def merge_stimulus_actions(existing, new_action)
    [existing, new_action].compact.join(" ")
  end
end
