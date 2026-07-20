class DiscoveryController < ApplicationController
  include NavModuleRequired
  require_nav_module :discovery

  before_action :load_wa_sos_source, except: [:show, :load_discovery_run]
  before_action :authorize_sos_defaults!, only: [:update_sos_defaults]
  before_action :set_discovery_business, only: [
    :show,
    :update_captured_business,
    :promote_to_potential,
    :archive,
    :unarchive,
    :destroy,
    :check_google_places,
    :select_google_place,
    :score,
    :score_card
  ]

  def index
    assign_captured_list_vars
    assign_stats_period_vars
    @discovery_businesses = load_captured_businesses
    @recent_discovery_runs = DiscoveryRun.recent_first.recent_window.limit(DiscoveryRun::RECENT_LIMIT)
    @discovery_stats = Discovery::StatsSummary.call(
      organization: current_organization,
      period: @stats_period
    )
  end

  def captured_list
    assign_captured_list_vars
    @discovery_businesses = load_captured_businesses

    render html: render_captured_businesses_html.html_safe
  end

  def show
    authorize! :read, @discovery_business
  end

  def score_card
    authorize! :read, @discovery_business

    render_score_card_response(ok: true)
  end

  def score
    authorize! :update, @discovery_business

    Discovery::PersistOpportunityScore.call(discovery_business: @discovery_business)
    @discovery_business.reload

    render_score_card_response(
      ok: true,
      message: "Opportunity score saved (#{@discovery_business.score}/#{@discovery_business.live_score_preview[:max_total]})."
    )
  rescue StandardError => e
    Rails.logger.error("[Discovery score] #{e.class}: #{e.message}")
    render_score_card_response(
      ok: false,
      message: "Score failed: #{e.message}",
      status: :internal_server_error
    )
  end

  def fetch_wa_sos
    fetch = Discovery::FetchWaSos.call(
      organization: current_organization,
      user: current_user,
      triggered_by: DiscoveryRun::TRIGGER_MANUAL,
      overrides: {
        business_type_id: params[:business_type_id],
        start_date: params[:start_date],
        end_date: params[:end_date],
        date_cadence: params[:date_cadence],
        search_entity_name: params[:search_entity_name]
      }
    )

    if fetch.disabled?
      return render_fetch_response(
        ok: false,
        status: 422,
        message: "WA Secretary of State source is disabled. Enable it under Settings → Discovery.",
        preview: nil
      )
    end

    result = fetch.fetch_result
    preview = result.body.byteslice(0, 2000)
    all_rows = fetch.rows
    Rails.logger.info(
      "[Discovery WA SOS] run=#{fetch.run.id} HTTP #{result.status} bytes=#{result.body.bytesize} rows=#{all_rows.size}"
    )

    render_fetch_response(
      ok: fetch.success?,
      status: result.status,
      bytes: result.body.bytesize,
      content_type: result.content_type,
      preview: preview,
      all_rows: all_rows,
      sos_query: fetch.sos_query,
      message: fetch_result_message(fetch.success?, all_rows.size, search_entity_name: fetch.sos_query[:search_entity_name])
    )
  rescue StandardError => e
    Rails.logger.error("[Discovery WA SOS] #{e.class}: #{e.message}")
    render_fetch_response(
      ok: false,
      status: 500,
      error: e.message,
      message: "SOS request error: #{e.message}",
      preview: nil
    )
  end

  def load_discovery_run
    run = DiscoveryRun.find(params[:run_id])

    unless run.reloadable?
      return render_load_run_response(
        ok: false,
        status: :unprocessable_entity,
        message: "This run has no saved CSV to load."
      )
    end

    result = Discovery::LoadWaSosRun.call(run: run)

    render_load_run_response(
      ok: true,
      status: :ok,
      message: load_run_message(result.run, result.rows.size),
      all_rows: result.rows,
      filter_city: result.run.settings_snapshot["filter_city"],
      run_id: result.run.id,
      sos_query: result.run.settings_snapshot.slice("business_type_id", "start_date", "end_date", "date_cadence")
    )
  rescue ActiveRecord::RecordNotFound
    render_load_run_response(
      ok: false,
      status: :not_found,
      message: "Run not found."
    )
  rescue ArgumentError => e
    render_load_run_response(
      ok: false,
      status: :unprocessable_entity,
      message: e.message
    )
  rescue StandardError => e
    Rails.logger.error("[Discovery load run] #{e.class}: #{e.message}")
    render_load_run_response(
      ok: false,
      status: :internal_server_error,
      message: "Load failed: #{e.message}"
    )
  end

  def save_businesses
    authorize! :create, DiscoveryBusiness

    rows = save_businesses_params[:rows]
    filter_city = save_businesses_params[:filter_city]

    if rows.blank?
      return render_save_response(
        ok: false,
        status: 422,
        message: "No businesses to capture — fetch and filter results first."
      )
    end

    result = Discovery::SaveWaSosBusinesses.call(
      organization: current_organization,
      rows: rows,
      filter_city: filter_city.presence || @wa_sos_source.wa_sos_settings.filter_city
    )

    assign_captured_list_vars
    @discovery_businesses = load_captured_businesses
    message = save_result_message(result)

    render_save_response(
      ok: true,
      status: :ok,
      created: result.created,
      skipped: result.skipped,
      skip_messages: result.skip_messages,
      created_external_ids: result.created_external_ids,
      message: message
    )
  rescue StandardError => e
    Rails.logger.error("[Discovery save businesses] #{e.class}: #{e.message}")
    render_save_response(
      ok: false,
      status: 500,
      message: "Capture failed: #{e.message}"
    )
  end

  def update_captured_business
    authorize! :update, @discovery_business

    if @discovery_business.update(captured_business_update_attrs)
      score_message = nil
      score_saved = false

      if persist_score_requested?
        begin
          Discovery::PersistOpportunityScore.call(discovery_business: @discovery_business)
          @discovery_business.reload
          score_saved = true
          score_message =
            "Place data and opportunity score saved " \
            "(#{@discovery_business.score}/#{@discovery_business.live_score_preview[:max_total]})."
        rescue StandardError => e
          Rails.logger.error("[Discovery auto score] #{e.class}: #{e.message}")
          score_message = "Place data saved, but score save failed: #{e.message}"
        end
      end

      assign_captured_list_vars
      @discovery_businesses = load_captured_businesses
      render_update_captured_response(
        ok: true,
        message: score_message.presence || "Captured business updated.",
        redirect_url: discovery_path(@discovery_business),
        persist_score: score_saved
      )
    else
      render_update_captured_response(
        ok: false,
        message: @discovery_business.errors.full_messages.to_sentence,
        status: :unprocessable_entity,
        redirect_url: discovery_path(@discovery_business)
      )
    end
  rescue StandardError => e
    Rails.logger.error("[Discovery update captured business] #{e.class}: #{e.message}")
    render_update_captured_response(
      ok: false,
      message: "Update failed: #{e.message}",
      status: :internal_server_error,
      redirect_url: (@discovery_business && discovery_path(@discovery_business))
    )
  end

  def promote_to_potential
    authorize! :update, @discovery_business

    unless current_organization.potentials_enabled?
      return render_promote_response(
        ok: false,
        message: "Potentials is disabled for this organization.",
        status: :unprocessable_entity,
        redirect_url: discovery_path(@discovery_business)
      )
    end

    result = Discovery::PromoteToPotential.call(discovery_business: @discovery_business)
    assign_captured_list_vars
    @discovery_businesses = load_captured_businesses

    message = promote_result_message(result)
    customer_url = potentials_path(id: result.customer.id) if result.customer

    render_promote_response(
      ok: true,
      message: message,
      customer_url: customer_url,
      already_promoted: result.already_promoted,
      redirect_url: discovery_path(@discovery_business)
    )
  rescue StandardError => e
    Rails.logger.error("[Discovery promote to potential] #{e.class}: #{e.message}")
    render_promote_response(
      ok: false,
      message: "Promote failed: #{e.message}",
      status: :internal_server_error,
      redirect_url: (@discovery_business && discovery_path(@discovery_business))
    )
  end

  def archive
    authorize! :update, @discovery_business

    @discovery_business.archive!
    assign_captured_list_vars
    @discovery_businesses = load_captured_businesses

    render_archive_response(
      ok: true,
      message: "Archived #{@discovery_business.business_name}."
    )
  rescue StandardError => e
    Rails.logger.error("[Discovery archive] #{e.class}: #{e.message}")
    render_archive_response(
      ok: false,
      message: "Archive failed: #{e.message}",
      status: :internal_server_error
    )
  end

  def unarchive
    authorize! :update, @discovery_business

    @discovery_business.unarchive!
    assign_captured_list_vars
    @discovery_businesses = load_captured_businesses

    render_archive_response(
      ok: true,
      message: "Unarchived #{@discovery_business.business_name}."
    )
  rescue StandardError => e
    Rails.logger.error("[Discovery unarchive] #{e.class}: #{e.message}")
    render_archive_response(
      ok: false,
      message: "Unarchive failed: #{e.message}",
      status: :internal_server_error
    )
  end

  def destroy
    authorize! :destroy, @discovery_business

    name = @discovery_business.business_name
    @discovery_business.destroy!

    respond_to do |format|
      format.html do
        flash[:notice] = "Deleted #{name}. You can capture it again from Discovery."
        redirect_to discovery_index_path
      end
      format.json do
        render json: {
          ok: true,
          message: "Deleted #{name}. You can capture it again from Discovery.",
          redirect_url: discovery_index_path
        }
      end
    end
  rescue StandardError => e
    Rails.logger.error("[Discovery destroy] #{e.class}: #{e.message}")
    respond_to do |format|
      format.html do
        flash[:alert] = "Delete failed: #{e.message}"
        redirect_to discovery_path(@discovery_business)
      end
      format.json do
        render json: { ok: false, message: "Delete failed: #{e.message}" }, status: :internal_server_error
      end
    end
  end

  def check_google_places
    authorize! :update, @discovery_business

    api = Discovery::GooglePlacesLookup.normalize_api(params[:api])
    result = Discovery::GooglePlacesLookup.search(discovery_business: @discovery_business, api: api)

    Rails.logger.info(
      "[Discovery Google Places search] business=#{@discovery_business.id} api=#{result.api} ok=#{result.ok} " \
      "query=#{result.query.inspect} matches=#{result.places.size}"
    )

    render json: {
      ok: result.ok,
      message: result.message,
      api: result.api,
      api_label: Discovery::GooglePlacesLookup.api_label(result.api),
      query: result.query,
      places: result.places,
      raw_search: result.raw_search
    }, status: result.ok ? :ok : :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[Discovery Google Places search] #{e.class}: #{e.message}")
    render json: {
      ok: false,
      message: "Google Places search failed: #{e.message}"
    }, status: :internal_server_error
  end

  def select_google_place
    authorize! :update, @discovery_business

    api = Discovery::GooglePlacesLookup.normalize_api(params[:api])
    place_id = params[:place_id].to_s.strip
    result = Discovery::GooglePlacesLookup.details(
      discovery_business: @discovery_business,
      place_id: place_id,
      api: api
    )

    Rails.logger.info(
      "[Discovery Google Places details] business=#{@discovery_business.id} api=#{result.api} " \
      "ok=#{result.ok} place_id=#{result.place_id.inspect}"
    )

    render json: {
      ok: result.ok,
      message: result.message,
      api: result.api,
      api_label: Discovery::GooglePlacesLookup.api_label(result.api),
      place_id: result.place_id,
      details: result.details,
      raw_details: result.raw_details
    }, status: result.ok ? :ok : :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[Discovery Google Places details] #{e.class}: #{e.message}")
    render json: {
      ok: false,
      message: "Google Places details failed: #{e.message}"
    }, status: :internal_server_error
  end

  def update_sos_defaults
    attrs = wa_sos_settings_attrs_from_params
    cadence = attrs[:date_cadence]
    unless cadence.blank? || Discovery::WaSosDateCadence.valid?(cadence)
      flash[:alert] = "Invalid date range default."
      redirect_to discovery_index_path and return
    end

    city = attrs[:filter_city]
    unless city.blank? || Discovery::Sources::WaSos::Cities.valid?(city)
      flash[:alert] = "Invalid city default."
      redirect_to discovery_index_path and return
    end

    if @wa_sos_source.update_wa_sos_settings!(attrs)
      flash[:notice] = defaults_saved_message(attrs)
    else
      flash[:alert] = @wa_sos_source.errors.full_messages.to_sentence
    end
    redirect_to discovery_index_path
  end

  private

  def render_fetch_response(ok:, status:, message:, preview: nil, bytes: nil, content_type: nil, error: nil, all_rows: [], sos_query: {})
    payload = {
      ok: ok,
      status: status,
      bytes: bytes,
      content_type: content_type,
      preview: preview,
      error: error,
      message: message,
      sos_query: sos_query,
      search_entity_name: sos_query[:search_entity_name],
      business_name_search: sos_query[:search_entity_name].present?,
      all_rows: all_rows,
      display_columns: Discovery::Sources::WaSos::CsvParser::UI_DISPLAY_COLUMNS,
      runs_html: render_runs_html
    }

    respond_to do |format|
      format.json { render json: payload, status: ok ? :ok : :unprocessable_entity }
      format.html do
        flash[ok ? :notice : :alert] = message
        render :index, status: ok ? :ok : :unprocessable_entity
      end
    end
  end

  def render_load_run_response(ok:, status:, message:, all_rows: [], filter_city: nil, run_id: nil, sos_query: {})
    payload = {
      ok: ok,
      message: message,
      all_rows: all_rows,
      filter_city: filter_city,
      run_id: run_id,
      sos_query: sos_query,
      display_columns: Discovery::Sources::WaSos::CsvParser::UI_DISPLAY_COLUMNS
    }

    respond_to do |format|
      format.json { render json: payload, status: status }
      format.html do
        flash[ok ? :notice : :alert] = message
        redirect_to discovery_index_path
      end
    end
  end

  def render_save_response(ok:, status:, message:, created: 0, skipped: 0, skip_messages: [], created_external_ids: [])
    payload = {
      ok: ok,
      message: message,
      created: created,
      skipped: skipped,
      skip_messages: skip_messages,
      created_external_ids: created_external_ids,
      captured_html: render_captured_businesses_html
    }

    respond_to do |format|
      format.json { render json: payload, status: ok ? :ok : :unprocessable_entity }
      format.html do
        flash[ok ? :notice : :alert] = message
        redirect_to discovery_index_path
      end
    end
  end

  def render_update_captured_response(ok:, message:, status: nil, redirect_url: nil, persist_score: false)
    payload = {
      ok: ok,
      message: message,
      redirect_url: redirect_url,
      captured_html: render_captured_businesses_html
    }

    if persist_score && ok && @discovery_business
      score_preview = @discovery_business.live_score_preview
      payload[:score] = @discovery_business.score
      payload[:scored_at] = @discovery_business.scored_at&.iso8601
      payload[:score_card_html] = render_score_card_html(score_preview: score_preview)
      payload[:capture_summary_html] = render_capture_summary_html(score_preview: score_preview)
    end

    if ok && @discovery_business
      payload[:business_snapshot] = @discovery_business.captured_business_snapshot
    end

    http_status = status || (ok ? :ok : :unprocessable_entity)

    respond_to do |format|
      format.json { render json: payload, status: http_status }
      format.html do
        flash[ok ? :notice : :alert] = message
        redirect_to redirect_url.presence || discovery_index_path
      end
    end
  end

  def render_promote_response(ok:, message:, status: nil, customer_url: nil, already_promoted: false, redirect_url: nil)
    payload = {
      ok: ok,
      message: message,
      customer_url: customer_url,
      already_promoted: already_promoted,
      redirect_url: redirect_url,
      captured_html: render_captured_businesses_html
    }

    http_status = status || (ok ? :ok : :unprocessable_entity)

    respond_to do |format|
      format.json { render json: payload, status: http_status }
      format.html do
        flash[ok ? :notice : :alert] = message
        redirect_to redirect_url.presence || customer_url.presence || discovery_index_path
      end
    end
  end

  def promote_result_message(result)
    if result.already_promoted
      "Already in Potentials."
    elsif result.created
      "Added to Potentials."
    else
      "Linked to existing potential."
    end
  end

  def set_discovery_business
    @discovery_business = DiscoveryBusiness.find(params[:id])
  end

  def captured_business_params
    permitted = params.require(:discovery_business).permit(
      :business_name,
      :business_type,
      :office_address,
      :city,
      :registered_agent_name,
      :sos_business_id,
      :phone,
      :email,
      :google_place_id,
      :google_rating,
      :google_rating_count,
      :website,
      :vertical_classification,
      :facebook_url,
      :instagram_url,
      :linkedin_url,
      :places_check_status,
      :website_check_status,
      :facebook_check_status,
      :instagram_check_status,
      :brand_check_status,
      :hosting_check_status,
      :linkedin_check_status
    )

    permitted[:business_type] = permitted[:business_type].presence
    permitted[:office_address] = permitted[:office_address].presence
    permitted[:city] = permitted[:city].presence
    permitted[:registered_agent_name] = permitted[:registered_agent_name].presence
    permitted[:sos_business_id] = nil if permitted[:sos_business_id].blank?
    permitted[:phone] = permitted[:phone].presence
    permitted[:email] = permitted[:email].presence
    permitted[:google_place_id] = permitted[:google_place_id].presence
    permitted[:google_rating] = permitted[:google_rating].presence
    permitted[:google_rating_count] = permitted[:google_rating_count].presence
    permitted[:website] = permitted[:website].presence
    permitted[:vertical_classification] = permitted[:vertical_classification].presence
    permitted[:facebook_url] = permitted[:facebook_url].presence
    permitted[:instagram_url] = permitted[:instagram_url].presence
    permitted[:linkedin_url] = permitted[:linkedin_url].presence

    %i[places_check_status website_check_status facebook_check_status instagram_check_status linkedin_check_status brand_check_status hosting_check_status].each do |key|
      next unless permitted.key?(key)

      value = permitted[key].to_s
      permitted[key] = DiscoveryBusiness::CHECK_STATUSES.include?(value) ? value : DiscoveryBusiness::CHECK_UNCHECKED
    end

    permitted
  end

  ENRICHMENT_PRESERVE_ATTRS = %i[
    phone email website google_place_id google_rating google_rating_count
    places_check_status website_check_status
    facebook_url instagram_url linkedin_url
    facebook_check_status instagram_check_status linkedin_check_status
  ].freeze

  def captured_business_update_attrs
    submitted_keys = params.require(:discovery_business).keys.map(&:to_sym)
    attrs = captured_business_params.slice(*submitted_keys)

    # Inline saves merge the edited field into the full client snapshot — apply all submitted attrs.
    return attrs if inline_field_update?

    preserve_present_enrichment!(attrs, submitted_keys)
    attrs
  end

  def inline_field_update?
    ActiveModel::Type::Boolean.new.cast(params[:inline])
  end

  def preserve_present_enrichment!(attrs, submitted_keys)
    ENRICHMENT_PRESERVE_ATTRS.each do |key|
      next unless submitted_keys.include?(key)
      next unless attrs.key?(key)
      next if attrs[key].present?

      current = @discovery_business.public_send(key)
      next if current.blank?

      attrs.delete(key)
    end
  end

  def persist_score_requested?
    ActiveModel::Type::Boolean.new.cast(params[:persist_score])
  end

  def render_captured_businesses_html
    assign_captured_list_vars if @captured_view.blank?

    render_to_string(
      partial: "discovery/captured_businesses",
      locals: {
        discovery_businesses: @discovery_businesses || load_captured_businesses,
        captured_view: @captured_view,
        archive_filter: @archive_filter,
        hide_archived: @hide_archived
      },
      formats: [:html]
    )
  end

  def render_score_card_response(ok:, message: nil, status: nil)
    modal = ActiveModel::Type::Boolean.new.cast(params[:modal])
    score_preview = @discovery_business.live_score_preview
    score_card_html = render_score_card_html(score_preview: score_preview, modal: modal)

    payload = {
      ok: ok,
      message: message,
      score: @discovery_business.score,
      scored_at: @discovery_business.scored_at&.iso8601,
      score_card_html: score_card_html
    }
    payload[:capture_summary_html] = render_capture_summary_html(score_preview: score_preview) unless modal

    http_status = status || (ok ? :ok : :unprocessable_entity)

    respond_to do |format|
      format.json { render json: payload, status: http_status }
      format.html do
        flash[ok ? :notice : :alert] = message if message.present?
        redirect_to discovery_path(@discovery_business)
      end
    end
  end

  def render_score_card_html(score_preview:, modal: false)
    render_to_string(
      partial: "discovery/score_card",
      locals: {
        business: @discovery_business,
        score_preview: score_preview,
        show_actions: !modal,
        modal: modal
      },
      formats: [:html]
    )
  end

  def render_capture_summary_html(score_preview:)
    render_to_string(
      partial: "discovery/capture_summary",
      locals: { capture_summary: score_preview[:capture_summary] },
      formats: [:html]
    )
  end

  def render_archive_response(ok:, message:, status: nil)
    payload = {
      ok: ok,
      message: message,
      captured_html: render_captured_businesses_html
    }

    http_status = status || (ok ? :ok : :unprocessable_entity)

    respond_to do |format|
      format.json { render json: payload, status: http_status }
      format.html do
        flash[ok ? :notice : :alert] = message
        redirect_to discovery_index_path
      end
    end
  end

  def assign_stats_period_vars
    @stats_period = Discovery::StatsPeriod.normalize(params[:stats_period])
    @stats_period_links = Discovery::StatsPeriod::OPTIONS.to_h do |value, _label|
      [value, discovery_index_path(discovery_index_query_params(stats_period: value))]
    end
  end

  def discovery_index_query_params(overrides = {})
    {
      stats_period: @stats_period,
      captured_view: @captured_view,
      hide_archived: @hide_archived,
      archive_filter: @archive_filter
    }.merge(overrides).compact
  end

  def assign_captured_list_vars
    @captured_view = params[:captured_view].presence_in(%w[working archived]) || "working"
    @hide_archived = if params.key?(:hide_archived)
                       ActiveModel::Type::Boolean.new.cast(params[:hide_archived])
                     else
                       true
                     end
    @archive_filter = params[:archive_filter].presence_in(DiscoveryBusiness::ARCHIVE_FILTERS) ||
                      DiscoveryBusiness::ARCHIVE_FILTER_ALL
  end

  def load_captured_businesses
    DiscoveryBusiness.for_captured_list(
      view: @captured_view,
      hide_archived: @hide_archived,
      archive_filter: @archive_filter
    )
  end

  def render_runs_html
    runs = DiscoveryRun.recent_first.recent_window.limit(DiscoveryRun::RECENT_LIMIT)
    render_to_string(
      partial: "discovery/runs_table",
      locals: { recent_discovery_runs: runs },
      formats: [:html]
    )
  end

  def save_businesses_params
    {
      filter_city: params[:filter_city],
      rows: Array(params[:rows])
    }
  end

  def save_result_message(result)
    parts = []
    parts << "#{result.created} #{'business'.pluralize(result.created)} captured" if result.created.positive?

    if result.skip_messages.present?
      parts.concat(result.skip_messages.uniq)
    elsif result.skipped.positive?
      parts << "#{result.skipped} already captured (skipped)"
    end

    parts.presence&.join(" — ") || "No businesses captured."
  end

  def load_run_message(run, row_count)
    when_label = helpers.l(run.started_at, format: :short)
    "Loaded #{row_count} #{'business'.pluralize(row_count)} from run on #{when_label}."
  end

  def load_wa_sos_source
    @wa_sos_source = DiscoverySource.ensure_wa_sos!(current_organization)
    @sos_settings = @wa_sos_source.wa_sos_settings.to_fetch_settings(
      business_type_id: params[:business_type_id],
      date_cadence: params[:date_cadence],
      start_date: params[:start_date],
      end_date: params[:end_date]
    )
    @filter_city = @wa_sos_source.wa_sos_settings.normalized_filter_city
  end

  def wa_sos_settings_attrs_from_params
    attrs = {}

    if params[:organization].present?
      org_params = params.require(:organization).permit(
        :discovery_wa_sos_business_type_id,
        :discovery_wa_sos_date_cadence,
        :discovery_wa_sos_city
      )
      attrs[:business_type_id] = org_params[:discovery_wa_sos_business_type_id] if org_params.key?(:discovery_wa_sos_business_type_id)
      attrs[:date_cadence] = org_params[:discovery_wa_sos_date_cadence] if org_params.key?(:discovery_wa_sos_date_cadence)
      attrs[:filter_city] = org_params[:discovery_wa_sos_city] if org_params.key?(:discovery_wa_sos_city)
    end

    if params[:discovery_source].present?
      source_params = params.require(:discovery_source).permit(settings: [:business_type_id, :date_cadence, :filter_city, :active_only])
      attrs.merge!(source_params[:settings].to_h.compact) if source_params[:settings].present?
    end

    attrs.compact_blank
  end

  def authorize_sos_defaults!
    authorize! :manage, :settings
  end

  def fetch_result_message(success, row_count, search_entity_name: nil)
    return "Request failed — see browser console." unless success

    if search_entity_name.present?
      if row_count.positive?
        "#{row_count} #{'match'.pluralize(row_count)} for \"#{search_entity_name}\"."
      else
        "No businesses matched \"#{search_entity_name}\"."
      end
    elsif row_count.positive?
      "#{row_count} #{'business'.pluralize(row_count)} returned."
    else
      "Request succeeded but no businesses were returned."
    end
  end

  def defaults_saved_message(attrs)
    search_fields = attrs.values_at(:business_type_id, :date_cadence).compact_blank
    city_only = attrs[:filter_city].present? && search_fields.empty?

    city_only ? "City filter default saved." : "WA SOS source settings saved."
  end
end
