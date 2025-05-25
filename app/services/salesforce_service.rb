class SalesforceService
  def initialize
    @client = Restforce.new(
      username: ENV["SALESFORCE_USERNAME"],
      password: ENV["SALESFORCE_PASSWORD"],
      security_token: ENV["SALESFORCE_SECURITY_TOKEN"],
      client_id: ENV["SALESFORCE_CLIENT_ID"],
      client_secret: ENV["SALESFORCE_CLIENT_SECRET"],
      host: ENV["SALESFORCE_HOST"] || "login.salesforce.com"
    )
  end

  def create_job_record(job)
    begin
      # Salesforceにカスタムオブジェクトまたは既存オブジェクトとして求人データを作成
      response = @client.create!("Job__c", {
        Name: job.title,
        Company__c: job.company,
        Description__c: job.description,
        Location__c: job.location,
        Salary__c: job.salary,
        Employment_Type__c: job.employment_type,
        Requirements__c: job.requirements,
        Posted_Date__c: job.posted_at&.strftime("%Y-%m-%d")
      })

      Rails.logger.info "Salesforce record created with ID: #{response}"
      { success: true, salesforce_id: response }
    rescue Restforce::UnauthorizedError => e
      Rails.logger.error "Salesforce authentication failed: #{e.message}"
      { success: false, error: "認証エラー: #{e.message}" }
    rescue Restforce::ResponseError => e
      Rails.logger.error "Salesforce API error: #{e.message}"
      { success: false, error: "API エラー: #{e.message}" }
    rescue => e
      Rails.logger.error "Unexpected error: #{e.message}"
      { success: false, error: "予期しないエラー: #{e.message}" }
    end
  end

  def test_connection
    begin
      @client.authenticate!
      Rails.logger.info "Salesforce connection successful"
      { success: true, message: "Salesforce接続成功" }
    rescue => e
      Rails.logger.error "Salesforce connection failed: #{e.message}"
      { success: false, error: e.message }
    end
  end
end
