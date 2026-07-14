# Foundation scheduled tasks.
#
# Weekly Stats: run create_weekly_stats on Mondays (e.g. Heroku Scheduler).
# Use create_weekly_stats_force for manual/dev seeding any day.

def create_weekly_stat_for_organization!(organization, monday_date)
  week_start_date = monday_date
  week_end_date = (monday_date + 6.days).end_of_day

  Stats.unscoped_by_organization.create!(
    organization: organization,
    main: true,
    month_by_text: monday_date.strftime("%B"),
    month_by_number: monday_date.month,
    year_by_text: monday_date.strftime("%Y"),
    year_by_number: monday_date.year,
    week_start_by_text: week_start_date.strftime("%-m/%-d/%y"),
    week_start_by_date: week_start_date,
    week_end_by_text: week_end_date.strftime("%-m/%-d/%y"),
    week_end_by_date: week_end_date
  )
end

desc "Create a new Stat record for the current week (Mondays only)"
task create_weekly_stats: :environment do
  today = Date.today
  unless today.monday?
    puts "=== Waiting for Monday to create Stat record. Today is #{today}"
    next
  end

  monday_date = today.beginning_of_week(:monday)
  Organization.find_each do |organization|
    create_weekly_stat_for_organization!(organization, monday_date)
    puts "=== New weekly Stat for #{organization.slug} (week starting #{monday_date})"
  end
end

desc "Force-create a new Stat record for the current week (any day)"
task create_weekly_stats_force: :environment do
  monday_date = Date.today.beginning_of_week(:monday)

  Organization.find_each do |organization|
    create_weekly_stat_for_organization!(organization, monday_date)
    puts "=== New weekly Stat for #{organization.slug} (week starting #{monday_date})"
  end
end
