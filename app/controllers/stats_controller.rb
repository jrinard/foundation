class StatsController < ApplicationController
  def index
    @user = current_user
    @stats = Stats.new
  end

  def show
  end

  def new
    @stats = Stats.new
  end

  def edit
  end

  def create
    @stats = Stats.new(stats_params)
    respond_to do |format|
      if @stats.save
        format.json { render json: { redirect: customers_path } }
        flash[:notice] = "Stats was successfully created."
      else
        format.html { render :new }
        format.json { render json: @stats.errors, status: :unprocessable_entity }
        flash[:notice] = "There was an error while creating a Stats."
      end
    end
  end

  def update
    @main_stats = Stats.find(params[:id])
    if @main_stats.update(stats_params)
      redirect_to settings_path(id: params[:subaction])
    else
      flash[:notice] = "There was an error. Updating the message."
      render :edit
    end
  end

  def destroy
    @stats = Stats.find(params[:id])
    referrer = request.referrer
    if @stats.destroy
      flash[:notice] = "Stats has been deleted!"
      if referrer.present? && referrer.include?("customers")
        render json: { redirect: customers_path }
      else
        render json: { redirect: root_path }
      end
    else
      flash[:notice] = "Error service has NOT been deleted!"
      redirect_to root_path
    end
  end

  private

  def stats_params
    params.require(:stats).permit(
      :month_by_text,
      :month_by_number,
      :year_by_text,
      :year_by_number,
      :week_start_by_text,
      :week_start_by_date,
      :week_end_by_text,
      :week_end_by_date,
      :monday,
      :tuesday,
      :wednesday,
      :thursday,
      :friday,
      :saturday,
      :sunday,
      :total_leads_and_customers,
      :total_leads_on_board,
      :total_customers_on_board,
      :total_leads_and_customers_closed,
      :total_leads_closed,
      :total_customers_closed,
      :main,
      :user_id
    )
  end
end
