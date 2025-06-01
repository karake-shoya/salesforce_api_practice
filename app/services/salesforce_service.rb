require "net/http"
require "uri"
require "json"

class SalesforceService
  def initialize
    @token_data = nil
    @client = nil
  end

  def upsert_job_record(job)
    begin
      # クライアント取得（認証含む）
      client = get_authenticated_client
      return { success: false, error: "認証に失敗しました" } unless client

      # 外部ID RailsJobID__c を使ってupsert操作（重複防止）
      response = client.upsert!("Job__c", "RailsJobID__c", {
        Name: job.title,
        Company__c: job.company,
        Description__c: job.description,
        Location__c: job.location,
        Salary__c: job.salary,
        EmploymentType__c: job.employment_type,
        Requirements__c: job.requirements,
        PostedDate__c: job.posted_at&.strftime("%Y-%m-%d"),
        RailsJobID__c: job.id  # Rails側のIDを外部IDとして設定
      })

      Rails.logger.info "✅ Salesforce record upserted with ID: #{response} (Rails Job ID: #{job.id})"
      { success: true, salesforce_id: response, operation: response.is_a?(String) ? "created" : "updated" }
    rescue Restforce::ResponseError => e
      Rails.logger.error "❌ Salesforce API error: #{e.message}"
      { success: false, error: "API エラー: #{e.message}" }
    rescue => e
      Rails.logger.error "❌ Unexpected error: #{e.message}"
      { success: false, error: "予期しないエラー: #{e.message}" }
    end
  end

  # 後方互換性のため、古いメソッド名も残しておく
  def create_job_record(job)
    upsert_job_record(job)
  end

  def delete_job_record(job)
    begin
      # クライアント取得（認証含む）
      client = get_authenticated_client
      return { success: false, error: "認証に失敗しました" } unless client

      # 外部ID RailsJobID__c でレコードを検索
      existing_records = client.query("SELECT Id FROM Job__c WHERE RailsJobID__c = '#{job.id}' LIMIT 1")

      if existing_records.empty?
        Rails.logger.warn "⚠️  Salesforce record not found for Rails Job ID: #{job.id}"
        return { success: true, message: "Salesforceにレコードが見つかりませんでした（既に削除済みの可能性）" }
      end

      # Salesforceレコードを削除
      salesforce_id = existing_records.first.Id
      client.destroy!("Job__c", salesforce_id)

      Rails.logger.info "✅ Salesforce record deleted: #{salesforce_id} (Rails Job ID: #{job.id})"
      { success: true, salesforce_id: salesforce_id, message: "Salesforceレコードを削除しました" }
    rescue Restforce::ResponseError => e
      Rails.logger.error "❌ Salesforce API error: #{e.message}"
      { success: false, error: "API エラー: #{e.message}" }
    rescue => e
      Rails.logger.error "❌ Unexpected error: #{e.message}"
      { success: false, error: "予期しないエラー: #{e.message}" }
    end
  end

  def test_connection
    begin
      Rails.logger.info "=== Client Credentials Flow 接続テスト開始 ==="

      # トークン取得
      token_data = get_access_token
      return { success: false, error: "トークン取得に失敗しました" } unless token_data

      # Restforceクライアント作成
      client = create_restforce_client(token_data)
      return { success: false, error: "クライアント作成に失敗しました" } unless client

      # 基本テスト実行
      org_info = client.query("SELECT Id, Name FROM Organization LIMIT 1")
      org_name = org_info.first&.Name

      Rails.logger.info "✅ Client Credentials Flow 接続成功"
      Rails.logger.info "✅ 組織名: #{org_name}"

      # Job__c カスタムオブジェクトの確認
      begin
        job_count = client.query("SELECT COUNT() FROM Job__c")
        count = job_count.first&.dig("expr0") || 0
        Rails.logger.info "✅ Job__c レコード数: #{count}"
      rescue => e
        Rails.logger.warn "⚠️  Job__c カスタムオブジェクト: #{e.message}"
      end

      { success: true, message: "Client Credentials Flow 接続成功", organization: org_name }
    rescue => e
      Rails.logger.error "❌ 接続テストエラー: #{e.message}"
      { success: false, error: "接続テストエラー: #{e.message}" }
    end
  end

  def query_jobs(limit = 10)
    begin
      client = get_authenticated_client
      return { success: false, error: "認証に失敗しました" } unless client

      jobs = client.query("SELECT Id, Name, Company__c, Location__c, Salary__c, CreatedDate FROM Job__c ORDER BY CreatedDate DESC LIMIT #{limit}")

      Rails.logger.info "✅ #{jobs.size}件の求人データを取得"
      { success: true, jobs: jobs.to_a, count: jobs.size }
    rescue => e
      Rails.logger.error "❌ 求人データ取得エラー: #{e.message}"
      { success: false, error: "求人データ取得エラー: #{e.message}" }
    end
  end

  private

  def get_authenticated_client
    # キャッシュされたクライアントがあれば使用
    return @client if @client

    # トークン取得
    token_data = get_access_token
    return nil unless token_data

    # Restforceクライアント作成
    @client = create_restforce_client(token_data)
    @client
  end

  def get_access_token
    # キャッシュされたトークンがあれば使用（簡易実装）
    return @token_data if @token_data

    begin
      uri = URI("https://#{ENV['SALESFORCE_HOST']}/services/oauth2/token")

      params = {
        "grant_type" => "client_credentials",
        "client_id" => ENV["SALESFORCE_CLIENT_ID"],
        "client_secret" => ENV["SALESFORCE_CLIENT_SECRET"]
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request.set_form_data(params)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request["Accept"] = "application/json"
      request["User-Agent"] = "Rails-Salesforce-ClientCredentials/1.0"

      response = http.request(request)

      if response.code == "200"
        @token_data = JSON.parse(response.body)
        Rails.logger.info "✅ Client Credentials トークン取得成功"
        @token_data
      else
        Rails.logger.error "❌ トークン取得失敗: #{response.code} - #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "❌ トークン取得エラー: #{e.message}"
      nil
    end
  end

  def create_restforce_client(token_data)
    begin
      Restforce.new(
        oauth_token: token_data["access_token"],
        instance_url: token_data["instance_url"],
        api_version: "58.0",
        timeout: 30,
        ssl: { verify: false },
        logger: Rails.logger,
        log_level: :info
      )
    rescue => e
      Rails.logger.error "❌ Restforceクライアント作成エラー: #{e.message}"
      nil
    end
  end
end
