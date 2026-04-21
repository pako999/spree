# Base class for all stock sync jobs.
# Wraps perform with error handling — any unhandled exception triggers a
# Telegram notification then re-raises so SolidQueue marks the job as failed.
class SyncStockBaseJob < ApplicationJob
  queue_as :default

  around_perform do |job, block|
    block.call
  rescue => e
    Spree::TelegramNotifier.send_sync_failure(job.class.name, e)
    raise
  end
end
