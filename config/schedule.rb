job_type :sidekiq, "cd :path && :environment_variable=:environment bundle exec sidekiq-client push :task :output"

every 2.minutes, :roles => [:app] do
  sidekiq "UpdateCourseDataWorker"
end
