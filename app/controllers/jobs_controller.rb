class JobsController < ApplicationController
  before_action :set_job, only: [ :show, :edit, :update, :destroy, :sync_to_client_credentials, :restore ]

  def index
    @jobs = Job.active.order(created_at: :desc)
    @deleted_jobs_count = Job.deleted.count
    @old_deleted_jobs_count = Job.soft_deleted_old.count

    # Client Credentials Flow接続テスト
    @salesforce_status = test_client_credentials_connection
  end

  def show
    # Client Credentials Flow接続テスト
    @salesforce_status = test_client_credentials_connection
  end

  def new
    @job = Job.new
  end

  def create
    @job = Job.new(job_params)

    if @job.save
      # デバッグ用ログ
      Rails.logger.info "=== Salesforce同期チェック ==="
      Rails.logger.info "sync_to_salesforce パラメータ: #{params[:job][:sync_to_salesforce].inspect}"
      Rails.logger.info "パラメータの型: #{params[:job][:sync_to_salesforce].class}"

      # チェックボックスがオンの場合のみSalesforceに同期
      if params[:job][:sync_to_salesforce].in?([ "1", "true", true ])
        Rails.logger.info "✅ Salesforce同期を実行します"
        sync_result = sync_to_salesforce_client_credentials(@job)

        if sync_result[:success]
          operation_text = sync_result[:operation] == "created" ? "作成・同期" : "作成・更新"
          flash[:notice] = "求人が#{operation_text}され、Salesforce (Client Credentials) に登録されました！ ID: #{sync_result[:salesforce_id]}"
        else
          flash[:alert] = "求人は作成されましたが、Salesforce同期に失敗しました: #{sync_result[:error]}"
        end
      else
        Rails.logger.info "❌ Salesforce同期をスキップします"
        flash[:notice] = "求人が作成されました。"
      end

      redirect_to @job
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @job.update(job_params)
      redirect_to @job, notice: "\u6C42\u4EBA\u304C\u66F4\u65B0\u3055\u308C\u307E\u3057\u305F\u3002"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # 論理削除を実行
    @job.soft_delete!

    # Salesforce側も削除
    sync_result = delete_from_salesforce_client_credentials(@job)

    if sync_result[:success]
      flash[:notice] = "求人が削除され、Salesforce (Client Credentials) からも削除されました。"
    else
      flash[:alert] = "求人は削除されましたが、Salesforce削除に失敗しました: #{sync_result[:error]}"
    end

    redirect_to jobs_path
  end

  # Client Credentials Flow専用アクション
  def test_client_credentials
    result = test_client_credentials_connection
    render json: result
  end

  def sync_all_to_client_credentials
    success_count = 0
    error_count = 0
    created_count = 0
    updated_count = 0
    deleted_count = 0
    errors = []

    # アクティブなレコードを同期（作成・更新）
    Job.active.each do |job|
      result = sync_to_salesforce_client_credentials(job)
      if result[:success]
        success_count += 1
        if result[:operation] == "created"
          created_count += 1
        else
          updated_count += 1
        end
      else
        error_count += 1
        errors << "Job #{job.id}: #{result[:error]}"
      end
    end

    # 削除されたレコードをSalesforce側からも削除
    Job.deleted.each do |job|
      result = delete_from_salesforce_client_credentials(job)
      if result[:success]
        success_count += 1
        deleted_count += 1
      else
        error_count += 1
        errors << "Job #{job.id} (削除): #{result[:error]}"
      end
    end

    render json: {
      success: error_count == 0,
      message: "成功: #{success_count}件 (新規作成: #{created_count}件, 更新: #{updated_count}件, 削除: #{deleted_count}件), 失敗: #{error_count}件",
      success_count: success_count,
      created_count: created_count,
      updated_count: updated_count,
      deleted_count: deleted_count,
      error_count: error_count,
      errors: errors
    }
  end

  def sync_to_client_credentials
    result = sync_to_salesforce_client_credentials(@job)

    if result[:success]
      operation_text = result[:operation] == "created" ? "新規作成" : "更新"
      flash[:notice] = "求人がSalesforce (Client Credentials) に#{operation_text}されました！ ID: #{result[:salesforce_id]}"
    else
      flash[:alert] = "Salesforce同期に失敗しました: #{result[:error]}"
    end

    redirect_to @job
  end

  # 削除済み求人一覧
  def deleted
    @deleted_jobs = Job.deleted.order(deleted_at: :desc)
    @salesforce_status = test_client_credentials_connection
  end

  # 求人復元
  def restore
    @job.restore!

    # Salesforceにも復元（再作成）
    sync_result = sync_to_salesforce_client_credentials(@job)

    if sync_result[:success]
      operation_text = sync_result[:operation] == "created" ? "復元・作成" : "復元・更新"
      flash[:notice] = "求人が復元され、Salesforce (Client Credentials) に#{operation_text}されました！ ID: #{sync_result[:salesforce_id]}"
    else
      flash[:alert] = "求人は復元されましたが、Salesforce同期に失敗しました: #{sync_result[:error]}"
    end

    redirect_to @job
  end

  # 古い削除済みレコードのクリーンアップ
  def cleanup_old_deleted
    result = Job.cleanup_old_deleted_records

    if result[:success]
      if result[:deleted_count] > 0
        flash[:notice] = "✅ #{result[:deleted_count]}件の古い削除済みレコード（6ヶ月以上前）を物理削除しました。"
      else
        flash[:info] = "クリーンアップ対象のレコードはありませんでした。"
      end
    else
      flash[:alert] = "❌ クリーンアップエラー: #{result[:error]}"
    end

    redirect_to deleted_jobs_path
  end

  private

  def set_job
    if action_name == "restore"
      @job = Job.with_deleted.find(params[:id])
    else
      @job = Job.find(params[:id])
    end
  end

  def job_params
    params.require(:job).permit(:title, :company, :description, :location, :salary, :employment_type, :requirements, :posted_at, :sync_to_salesforce)
  end

  def sync_to_salesforce_client_credentials(job)
    service = SalesforceService.new
    service.upsert_job_record(job)
  end

  def test_client_credentials_connection
    service = SalesforceService.new
    service.test_connection
  end

  def delete_from_salesforce_client_credentials(job)
    service = SalesforceService.new
    service.delete_job_record(job)
  end
end
