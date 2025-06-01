class Job < ApplicationRecord
  validates :title, presence: true
  validates :company, presence: true
  validates :description, presence: true
  validates :location, presence: true

  # 論理削除機能
  default_scope { where(deleted_at: nil) }

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
  scope :with_deleted, -> { unscoped }
  scope :soft_deleted_old, -> { deleted.where("deleted_at < ?", 6.months.ago) }

  # Salesforce連携用の属性
  attr_accessor :sync_to_salesforce

  # コールバック: 求人データ作成後にSalesforceに同期
  after_create :sync_to_salesforce_if_requested

  # 論理削除メソッド
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  # 削除されているかチェック
  def deleted?
    deleted_at.present?
  end

  # 復元メソッド
  def restore!
    update!(deleted_at: nil)
  end

  # 6ヶ月以上前に削除されたレコードを物理削除
  def self.cleanup_old_deleted_records
    old_records = soft_deleted_old
    count = old_records.count

    if count > 0
      Rails.logger.info "=== 古い削除済みレコードのクリーンアップ開始 ==="
      Rails.logger.info "対象レコード数: #{count}件"

      # Salesforce側からも削除
      old_records.each do |job|
        begin
          service = SalesforceService.new
          result = service.delete_job_record(job)
          Rails.logger.info "Salesforce削除結果 (Job ID: #{job.id}): #{result[:success] ? '成功' : result[:error]}"
        rescue => e
          Rails.logger.warn "Salesforce削除エラー (Job ID: #{job.id}): #{e.message}"
        end
      end

      # 物理削除実行
      deleted_count = old_records.delete_all
      Rails.logger.info "✅ #{deleted_count}件の古い削除済みレコードを物理削除しました"

      { success: true, deleted_count: deleted_count }
    else
      Rails.logger.info "クリーンアップ対象のレコードはありません"
      { success: true, deleted_count: 0 }
    end
  rescue => e
    Rails.logger.error "❌ クリーンアップエラー: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def sync_to_salesforce_if_requested
    return unless sync_to_salesforce.present? && sync_to_salesforce == "1"

    SyncToSalesforceJob.perform_later(self.id)
  end
end
