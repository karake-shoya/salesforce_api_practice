class Job < ApplicationRecord
  validates :title, presence: true
  validates :company, presence: true
  validates :description, presence: true
  validates :location, presence: true

  # Salesforce連携用の属性
  attr_accessor :sync_to_salesforce

  # コールバック: 求人データ作成後にSalesforceに同期
  after_create :sync_to_salesforce_if_requested

  private

  def sync_to_salesforce_if_requested
    return unless sync_to_salesforce.present? && sync_to_salesforce == "1"

    SyncToSalesforceJob.perform_later(self.id)
  end
end
