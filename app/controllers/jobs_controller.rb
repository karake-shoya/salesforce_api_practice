class JobsController < ApplicationController
  before_action :set_job, only: [ :show, :edit, :update, :destroy ]

  def index
    @jobs = Job.all.order(created_at: :desc)

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
      # Client Credentials FlowでSalesforceに同期
      sync_result = sync_to_salesforce_client_credentials(@job)

      if sync_result[:success]
        flash[:notice] = "求人が作成され、Salesforce (Client Credentials) に同期されました！ ID: #{sync_result[:salesforce_id]}"
      else
        flash[:alert] = "求人は作成されましたが、Salesforce同期に失敗しました: #{sync_result[:error]}"
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
    @job.destroy
    redirect_to jobs_path, notice: "\u6C42\u4EBA\u304C\u524A\u9664\u3055\u308C\u307E\u3057\u305F\u3002"
  end

  # Client Credentials Flow専用アクション
  def test_client_credentials
    result = test_client_credentials_connection
    render json: result
  end

  def sync_all_to_client_credentials
    success_count = 0
    error_count = 0
    errors = []

    Job.all.each do |job|
      result = sync_to_salesforce_client_credentials(job)
      if result[:success]
        success_count += 1
      else
        error_count += 1
        errors << "Job #{job.id}: #{result[:error]}"
      end
    end

    render json: {
      success: error_count == 0,
      message: "成功: #{success_count}件, 失敗: #{error_count}件",
      success_count: success_count,
      error_count: error_count,
      errors: errors
    }
  end

  def sync_to_client_credentials
    result = sync_to_salesforce_client_credentials(@job)

    if result[:success]
      flash[:notice] = "求人がSalesforce (Client Credentials) に同期されました！ ID: #{result[:salesforce_id]}"
    else
      flash[:alert] = "Salesforce同期に失敗しました: #{result[:error]}"
    end

    redirect_to @job
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def job_params
    params.require(:job).permit(:title, :company, :description, :location, :salary, :employment_type, :requirements, :posted_at)
  end

  def sync_to_salesforce_client_credentials(job)
    service = SalesforceService.new
    service.create_job_record(job)
  end

  def test_client_credentials_connection
    service = SalesforceService.new
    service.test_connection
  end
end
