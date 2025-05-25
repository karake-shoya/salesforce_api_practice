class SyncToSalesforceJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    job = Job.find(job_id)
    salesforce_service = SalesforceService.new

    result = salesforce_service.create_job_record(job)

    if result[:success]
      Rails.logger.info "Job ID #{job_id} successfully synced to Salesforce with ID: #{result[:salesforce_id]}"
    else
      Rails.logger.error "Failed to sync Job ID #{job_id} to Salesforce: #{result[:error]}"
      # 必要に応じて、失敗した場合の処理を追加（再試行、通知など）
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Job with ID #{job_id} not found: #{e.message}"
  rescue => e
    Rails.logger.error "Unexpected error syncing Job ID #{job_id}: #{e.message}"
    raise # Active Jobの再試行機能を利用するためにエラーを再発生
  end
end
