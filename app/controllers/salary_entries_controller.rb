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
  end

  def create
    @salary_entry = current_user.salary_entries.new(salary_entry_params)

    if @salary_entry.save
      redirect_to @salary_entry, notice: "Salary entry was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @salary_entry.update(salary_entry_params)
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
                                          :vacation_days_taken, :holiday_days_taken)
  end
end
