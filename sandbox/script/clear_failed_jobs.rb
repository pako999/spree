# frozen_string_literal: true
# One-off: clear the backlog of failed SolidQueue jobs.
# After this, ApplicationJob#discard_on handlers prevent re-accumulation.
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/clear_failed_jobs.rb"

before = SolidQueue::FailedExecution.count
puts "Failed executions before: #{before}"

# Delete in batches to avoid long-running lock
deleted = 0
loop do
  batch = SolidQueue::FailedExecution.limit(1000).delete_all
  deleted += batch
  print "."
  break if batch < 1000
end

puts "\nDeleted: #{deleted}"
puts "Failed executions after: #{SolidQueue::FailedExecution.count}"

# Also clean up the orphaned Job records that no longer have executions
orphaned = SolidQueue::Job.where(
  "NOT EXISTS (SELECT 1 FROM solid_queue_ready_executions WHERE solid_queue_ready_executions.job_id = solid_queue_jobs.id)" \
  " AND NOT EXISTS (SELECT 1 FROM solid_queue_claimed_executions WHERE solid_queue_claimed_executions.job_id = solid_queue_jobs.id)" \
  " AND NOT EXISTS (SELECT 1 FROM solid_queue_scheduled_executions WHERE solid_queue_scheduled_executions.job_id = solid_queue_jobs.id)" \
  " AND NOT EXISTS (SELECT 1 FROM solid_queue_failed_executions WHERE solid_queue_failed_executions.job_id = solid_queue_jobs.id)"
).where(finished_at: nil).where("created_at < ?", 1.day.ago)

puts "Orphaned stale job records: #{orphaned.count}"
SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.1)
puts "Done."
