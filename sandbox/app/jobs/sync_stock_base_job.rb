# Base class for all stock sync jobs.
# - Creates a StockSyncLog entry before the job runs and updates it on completion.
# - On failure, sends a Telegram notification then re-raises so SolidQueue marks the job failed.
# - Each subclass should call report_sync_stats(...) at the end of perform to record results.
class SyncStockBaseJob < ApplicationJob
  queue_as :default

  def report_sync_stats(matched:, updated:, skipped:, unmatched:, total_in_feed: 0)
    @sync_stats = {
      matched:       matched,
      updated:       updated,
      skipped:       skipped,
      unmatched:     unmatched,
      total_in_feed: total_in_feed
    }
  end

  around_perform do |job, block|
    # Mark any stale "running" entries for this job as failed (leftover from crashed runs)
    Spree::StockSyncLog.where(job_name: job.class.name, status: 'running')
                       .where('started_at < ?', 30.minutes.ago)
                       .update_all(status: 'failed', finished_at: Time.current,
                                   error_message: 'Marked failed: job did not complete (process crash or timeout)')

    log = Spree::StockSyncLog.create!(
      job_name:   job.class.name,
      status:     'running',
      started_at: Time.current
    )

    begin
      block.call
      stats = job.instance_variable_get(:@sync_stats) || {}
      log.update!(status: 'success', finished_at: Time.current, **stats)
    rescue => e
      log.update!(status: 'failed', finished_at: Time.current,
                  error_message: "#{e.class}: #{e.message.to_s.truncate(500)}")
      Spree::TelegramNotifier.send_sync_failure(job.class.name, e)
      raise
    end
  end
end
