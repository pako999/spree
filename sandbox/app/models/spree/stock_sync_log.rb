module Spree
  class StockSyncLog < Spree.base_class
    FRIENDLY_NAMES = {
      'SyncBamStockJob'     => 'Boards & More',
      'SyncPoint7StockJob'  => 'Point7',
      'SyncPrydeStockJob'   => 'NeilPryde / Cabrinha / JP',
      'SyncGaastraStockJob' => 'Gaastra / Tabou',
      'SyncNobileStockJob'  => 'Nobile'
    }.freeze

    scope :latest_per_job, -> {
      ids = group(:job_name).maximum(:id).values.compact
      where(id: ids).order(:job_name)
    }

    def friendly_name
      FRIENDLY_NAMES[job_name] || job_name
    end

    def duration_seconds
      return nil unless started_at && finished_at
      (finished_at - started_at).round(1)
    end

    def running?  = status == 'running'
    def success?  = status == 'success'
    def failed?   = status == 'failed'
  end
end
