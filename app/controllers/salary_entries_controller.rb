# app/controllers/salary_entries_controller.rb
class SalaryEntriesController < ApplicationController
  before_action :set_salary_entry, only: [ :show, :edit, :update, :destroy ]

  def index
    @year = params[:year]&.to_i || Date.current.year
    @salary_entries = current_user.salary_entries.for_year(@year).ordered
    @available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse
    @available_years = [ @year ] if @available_years.empty?
  end

  def show
  end

  def new
    @salary_entry = current_user.salary_entries.new(
      year: Date.current.year,
      month: Date.current.month,
      hourly_rate: current_user.default_hourly_rate
    )
    calculate_vacation_limit_status
  end

  def create
    @salary_entry = current_user.salary_entries.new(salary_entry_params)
    calculate_vacation_limit_status

    if @salary_entry.save
      redirect_to @salary_entry, notice: "Salary entry was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    calculate_vacation_limit_status
  end

  def update
    @salary_entry.assign_attributes(salary_entry_params)
    calculate_vacation_limit_status

    if @salary_entry.save
      redirect_to @salary_entry, notice: "Salary entry was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @salary_entry.destroy
    redirect_to salary_entries_path, notice: "Salary entry was successfully deleted."
  end

  def summary
    @year = params[:year]&.to_i || Date.current.year
    @summary = current_user.salary_entries.yearly_summary(@year)
    @available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse
    @available_years = [ @year ] if @available_years.empty?
  end

  private

  def set_salary_entry
    @salary_entry = current_user.salary_entries.find(params[:id])
  end

  def salary_entry_params
    params.require(:salary_entry).permit(:month, :year, :hours_worked, :hourly_rate,
                                          :vacation_days_taken, :holiday_days_taken,
                                          :vacation_over_limit_acknowledged)
  end

  def calculate_vacation_limit_status
    return unless current_user.vacation_enabled
    return unless @salary_entry.present?

    year = @salary_entry.year || Date.current.year
    balance = current_user.vacation_balance_for_year(year, exclude_entry: @salary_entry)

    @salary_entry.cached_vacation_balance = balance
    @over_vacation_limit = balance[:balance] < 0
    @vacation_over_by = balance[:balance].abs if @over_vacation_limit
    @vacation_balance = balance
  end
end
