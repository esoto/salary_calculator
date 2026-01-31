# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create admin user
admin = User.find_or_create_by!(email_address: "admin@example.com") do |user|
  user.name = "Admin User"
  user.password = "password123"
  user.vacation_days_per_year = 18
  user.holiday_days_per_year = 10
  user.hours_per_day = 8
  user.aguinaldo_enabled = true
  user.vacation_enabled = true
  user.holiday_enabled = true
end
puts "Created admin user: #{admin.email_address}"

# Create sample salary entries for 2024
# Simulating a freelancer with varying hours and rates throughout the year
salary_data_2024 = [
  { month: 1,  hours_worked: 160, hourly_rate: 450, vacation_days_taken: 0, holiday_days_taken: 1 },
  { month: 2,  hours_worked: 152, hourly_rate: 450, vacation_days_taken: 0, holiday_days_taken: 1 },
  { month: 3,  hours_worked: 168, hourly_rate: 450, vacation_days_taken: 0, holiday_days_taken: 0 },
  { month: 4,  hours_worked: 144, hourly_rate: 475, vacation_days_taken: 2, holiday_days_taken: 2 },
  { month: 5,  hours_worked: 160, hourly_rate: 475, vacation_days_taken: 0, holiday_days_taken: 1 },
  { month: 6,  hours_worked: 152, hourly_rate: 475, vacation_days_taken: 1, holiday_days_taken: 0 },
  { month: 7,  hours_worked: 120, hourly_rate: 500, vacation_days_taken: 5, holiday_days_taken: 0 },
  { month: 8,  hours_worked: 168, hourly_rate: 500, vacation_days_taken: 0, holiday_days_taken: 0 },
  { month: 9,  hours_worked: 160, hourly_rate: 500, vacation_days_taken: 0, holiday_days_taken: 1 },
  { month: 10, hours_worked: 152, hourly_rate: 500, vacation_days_taken: 0, holiday_days_taken: 0 },
  { month: 11, hours_worked: 144, hourly_rate: 525, vacation_days_taken: 2, holiday_days_taken: 1 },
  { month: 12, hours_worked: 128, hourly_rate: 525, vacation_days_taken: 4, holiday_days_taken: 2 }
]

salary_data_2024.each do |data|
  SalaryEntry.find_or_create_by!(user: admin, year: 2024, month: data[:month]) do |entry|
    entry.hours_worked = data[:hours_worked]
    entry.hourly_rate = data[:hourly_rate]
    entry.vacation_days_taken = data[:vacation_days_taken]
    entry.holiday_days_taken = data[:holiday_days_taken]
  end
end
puts "Created 12 salary entries for 2024"

puts "Seeding complete!"
