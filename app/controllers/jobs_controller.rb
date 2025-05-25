class JobsController < ApplicationController
  before_action :set_job, only: [ :show ]

  def index
    @jobs = Job.all.order(created_at: :desc)
  end

  def new
    @job = Job.new
  end

  def create
    @job = Job.new(job_params)

    if @job.save
      flash[:notice] = "求人データが作成されました！"
      if params[:job][:sync_to_salesforce] == "1"
        flash[:info] = "Salesforceへの同期処理を開始しました。"
      end
      redirect_to jobs_path
    else
      flash.now[:alert] = "求人データの作成に失敗しました。"
      render :new
    end
  end

  def show
  end

  # Salesforce接続テスト用のアクション
  def test_salesforce_connection
    salesforce_service = SalesforceService.new
    result = salesforce_service.test_connection

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:alert] = "Salesforce接続エラー: #{result[:error]}"
    end

    redirect_to jobs_path
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def job_params
    params.require(:job).permit(:title, :company, :description, :location, :salary, :employment_type, :requirements, :posted_at, :sync_to_salesforce)
  end
end
