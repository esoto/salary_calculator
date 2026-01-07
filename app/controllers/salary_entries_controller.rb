class SalaryEntriesController < ApplicationController
  before_action :set_salary_entry, only: [:show, :edit, :update, :destroy]

  def index
    @year = params[:year]&.to_i || Date.current.year
    @salary_entries = SalaryEntry.for_year(@year).ordered
    @available_years = SalaryEntry.distinct.pluck(:year).sort.reverse
    @available_years = [@year] if @available_years.empty?
  end

  def show
  end

  def new
    @salary_entry = SalaryEntry.new(year: Date.current.year, month: Date.current.month)
  end

  def create
    @salary_entry = SalaryEntry.new(salary_entry_params)

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
    @summary = SalaryEntry.yearly_summary(@year)
    @available_years = SalaryEntry.distinct.pluck(:year).sort.reverse
    @available_years = [@year] if @available_years.empty?
  end

  private

  def set_salary_entry
    @salary_entry = SalaryEntry.find(params[:id])
  end

  def salary_entry_params
    params.require(:salary_entry).permit(:month, :year, :hours_worked, :hourly_rate)
  end
end
