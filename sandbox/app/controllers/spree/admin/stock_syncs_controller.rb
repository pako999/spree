module Spree
  module Admin
    class StockSyncsController < Spree::Admin::BaseController
      SYNC_JOBS = %w[SyncBamStockJob SyncPoint7StockJob SyncPrydeStockJob SyncGaastraStockJob].freeze

      def index
        latest_ids = Spree::StockSyncLog.where(job_name: SYNC_JOBS)
                                        .group(:job_name)
                                        .maximum(:id)
        @latest_logs = Spree::StockSyncLog.where(id: latest_ids.values.compact).index_by(&:job_name)
        @job_names   = SYNC_JOBS
        @recent_logs = Spree::StockSyncLog.where(job_name: SYNC_JOBS)
                                          .order(started_at: :desc)
                                          .limit(40)
      end

      def run
        job_name = params[:job].to_s

        unless SYNC_JOBS.include?(job_name)
          flash[:error] = "Unknown sync job."
          redirect_to spree.admin_stock_syncs_path and return
        end

        job_name.constantize.perform_later
        label = Spree::StockSyncLog::FRIENDLY_NAMES[job_name] || job_name
        flash[:success] = "#{label} sync queued."
        redirect_to spree.admin_stock_syncs_path
      end
    end
  end
end
