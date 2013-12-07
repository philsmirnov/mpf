# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
set :output, '/home/deploy/apps/mpf/shared/log/cron.log'
job_type :command, 'cd :path && :task :output'

 every 3.hours do
   command './mm.sh -s'
end
