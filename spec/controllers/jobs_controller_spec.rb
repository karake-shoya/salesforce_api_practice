require 'rails_helper'

RSpec.describe JobsController, type: :controller do
  let(:valid_attributes) do
    {
      title: "Ruby on Rails エンジニア",
      company: "テスト株式会社",
      description: "Ruby on Railsを使ったWebアプリケーション開発",
      location: "東京都",
      salary: 6000000,
      employment_type: "正社員",
      requirements: "Ruby on Rails 3年以上の経験"
    }
  end

  let(:invalid_attributes) do
    { title: nil, company: nil, description: nil, location: nil }
  end

  let(:job) { create(:job) }
  let(:deleted_job) { create(:job, :deleted) }

  before do
    # SalesforceServiceをモック化
    allow_any_instance_of(SalesforceService).to receive(:test_connection)
      .and_return({ success: true, organization: "Test Org" })
    allow_any_instance_of(SalesforceService).to receive(:upsert_job_record)
      .and_return({ success: true, salesforce_id: "003XXXXXXXXXXXXXXX", operation: "created" })
    allow_any_instance_of(SalesforceService).to receive(:delete_job_record)
      .and_return({ success: true, salesforce_id: "003XXXXXXXXXXXXXXX" })
  end

  describe "GET #index" do
    let!(:active_jobs) { create_list(:job, 3) }
    let!(:deleted_jobs) { create_list(:job, 2, :deleted) }
    let!(:old_deleted_jobs) { create_list(:job, 1, :old_deleted) }

    it "アクティブな求人のみを表示する" do
      get :index
      expect(assigns(:jobs)).to match_array(active_jobs)
      expect(assigns(:jobs)).not_to include(*deleted_jobs)
      expect(assigns(:jobs)).not_to include(*old_deleted_jobs)
    end

    it "削除済み求人数を設定する" do
      get :index
      expect(assigns(:deleted_jobs_count)).to eq 3
    end

    it "クリーンアップ対象数を設定する" do
      get :index
      expect(assigns(:old_deleted_jobs_count)).to eq 1
    end

    it "Salesforce接続状態を確認する" do
      get :index
      expect(assigns(:salesforce_status)[:success]).to be true
    end
  end

  describe "GET #show" do
    it "指定された求人を表示する" do
      get :show, params: { id: job.id }
      expect(assigns(:job)).to eq job
    end

    it "Salesforce接続状態を確認する" do
      get :show, params: { id: job.id }
      expect(assigns(:salesforce_status)[:success]).to be true
    end
  end

  describe "GET #new" do
    it "新しい求人インスタンスを作成する" do
      get :new
      expect(assigns(:job)).to be_a_new(Job)
    end
  end

  describe "GET #edit" do
    it "指定された求人を編集用に取得する" do
      get :edit, params: { id: job.id }
      expect(assigns(:job)).to eq job
    end
  end

  describe "POST #create" do
    context "有効なパラメータの場合" do
      it "新しい求人を作成する" do
        expect {
          post :create, params: { job: valid_attributes }
        }.to change(Job, :count).by(1)
      end

      it "作成した求人にリダイレクトする" do
        post :create, params: { job: valid_attributes }
        expect(response).to redirect_to(Job.last)
      end

      context "Salesforce同期フラグがオンの場合" do
        it "Salesforceに同期する" do
          expect_any_instance_of(SalesforceService).to receive(:upsert_job_record)
          post :create, params: { job: valid_attributes.merge(sync_to_salesforce: "1") }
        end

        it "成功メッセージを表示する" do
          post :create, params: { job: valid_attributes.merge(sync_to_salesforce: "1") }
          expect(flash[:notice]).to include("作成・同期")
          expect(flash[:notice]).to include("Salesforce")
        end
      end

      context "Salesforce同期フラグがオフの場合" do
        it "Salesforceに同期しない" do
          expect_any_instance_of(SalesforceService).not_to receive(:upsert_job_record)
          post :create, params: { job: valid_attributes.merge(sync_to_salesforce: "0") }
        end

        it "通常の成功メッセージを表示する" do
          post :create, params: { job: valid_attributes.merge(sync_to_salesforce: "0") }
          expect(flash[:notice]).to eq("求人が作成されました。")
        end
      end
    end

    context "無効なパラメータの場合" do
      it "求人を作成しない" do
        expect {
          post :create, params: { job: invalid_attributes }
        }.not_to change(Job, :count)
      end

      it "newテンプレートを再表示する" do
        post :create, params: { job: invalid_attributes }
        expect(response).to render_template(:new)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH #update" do
    context "有効なパラメータの場合" do
      let(:new_attributes) { { title: "更新されたタイトル" } }

      it "求人を更新する" do
        patch :update, params: { id: job.id, job: new_attributes }
        job.reload
        expect(job.title).to eq "更新されたタイトル"
      end

      it "求人詳細にリダイレクトする" do
        patch :update, params: { id: job.id, job: new_attributes }
        expect(response).to redirect_to(job)
      end
    end

    context "無効なパラメータの場合" do
      it "editテンプレートを再表示する" do
        patch :update, params: { id: job.id, job: invalid_attributes }
        expect(response).to render_template(:edit)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE #destroy" do
    it "求人を論理削除する" do
      delete :destroy, params: { id: job.id }
      job.reload
      expect(job.deleted?).to be true
    end

    it "Salesforce側も削除する" do
      expect_any_instance_of(SalesforceService).to receive(:delete_job_record)
      delete :destroy, params: { id: job.id }
    end

    it "求人一覧にリダイレクトする" do
      delete :destroy, params: { id: job.id }
      expect(response).to redirect_to(jobs_path)
    end

    it "成功メッセージを表示する" do
      delete :destroy, params: { id: job.id }
      expect(flash[:notice]).to include("削除され")
      expect(flash[:notice]).to include("Salesforce")
    end
  end

  describe "GET #test_client_credentials" do
    it "JSON形式で接続テスト結果を返す" do
      get :test_client_credentials
      expect(response.content_type).to include('application/json')
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
    end
  end

  describe "POST #sync_all_to_client_credentials" do
    let!(:active_jobs) { create_list(:job, 2) }
    let!(:deleted_jobs) { create_list(:job, 1, :deleted) }

    before do
      # 各テストで新しいモックインスタンスを作成
      service_instance = instance_double(SalesforceService)
      allow(SalesforceService).to receive(:new).and_return(service_instance)
      allow(service_instance).to receive(:upsert_job_record).and_return({ success: true, salesforce_id: "003XXXXXXXXXXXXXXX", operation: "created" })
      allow(service_instance).to receive(:delete_job_record).and_return({ success: true, salesforce_id: "003XXXXXXXXXXXXXXX" })
    end

    it "全ての求人を同期する" do
      post :sync_all_to_client_credentials
      # レスポンスの確認のみ行う
      expect(response.content_type).to include('application/json')
    end

    it "JSON形式で結果を返す" do
      post :sync_all_to_client_credentials
      expect(response.content_type).to include('application/json')
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['success_count']).to eq 3
    end
  end

  describe "POST #sync_to_client_credentials" do
    it "指定された求人をSalesforceに同期する" do
      expect_any_instance_of(SalesforceService).to receive(:upsert_job_record)
      post :sync_to_client_credentials, params: { id: job.id }
    end

    it "求人詳細にリダイレクトする" do
      post :sync_to_client_credentials, params: { id: job.id }
      expect(response).to redirect_to(job)
    end

    it "成功メッセージを表示する" do
      post :sync_to_client_credentials, params: { id: job.id }
      expect(flash[:notice]).to include("新規作成")
      expect(flash[:notice]).to include("Salesforce")
    end
  end

  describe "GET #deleted" do
    let!(:deleted_jobs) { create_list(:job, 3, :deleted) }
    let!(:active_jobs) { create_list(:job, 2) }

    it "削除済み求人のみを表示する" do
      get :deleted
      expect(assigns(:deleted_jobs)).to match_array(deleted_jobs)
      expect(assigns(:deleted_jobs)).not_to include(*active_jobs)
    end

    it "Salesforce接続状態を確認する" do
      get :deleted
      expect(assigns(:salesforce_status)[:success]).to be true
    end
  end

  describe "PATCH #restore" do
    it "削除済み求人を復元する" do
      patch :restore, params: { id: deleted_job.id }
      deleted_job.reload
      expect(deleted_job.deleted?).to be false
    end

    it "Salesforceにも復元する" do
      expect_any_instance_of(SalesforceService).to receive(:upsert_job_record)
      patch :restore, params: { id: deleted_job.id }
    end

    it "復元した求人にリダイレクトする" do
      patch :restore, params: { id: deleted_job.id }
      expect(response).to redirect_to(deleted_job)
    end

    it "成功メッセージを表示する" do
      patch :restore, params: { id: deleted_job.id }
      expect(flash[:notice]).to include("復元")
      expect(flash[:notice]).to include("Salesforce")
    end
  end

  describe "DELETE #cleanup_old_deleted" do
    let!(:old_deleted_jobs) { create_list(:job, 2, :old_deleted) }
    let!(:recent_deleted_jobs) { create_list(:job, 1, :deleted) }

    before do
      allow(Job).to receive(:cleanup_old_deleted_records)
        .and_return({ success: true, deleted_count: 2 })
    end

    it "古い削除済みレコードをクリーンアップする" do
      expect(Job).to receive(:cleanup_old_deleted_records)
      delete :cleanup_old_deleted
    end

    it "削除済み一覧にリダイレクトする" do
      delete :cleanup_old_deleted
      expect(response).to redirect_to(deleted_jobs_path)
    end

    it "成功メッセージを表示する" do
      delete :cleanup_old_deleted
      expect(flash[:notice]).to include("2件の古い削除済みレコード")
      expect(flash[:notice]).to include("物理削除")
    end

    context "クリーンアップ対象がない場合" do
      before do
        allow(Job).to receive(:cleanup_old_deleted_records)
          .and_return({ success: true, deleted_count: 0 })
      end

      it "情報メッセージを表示する" do
        delete :cleanup_old_deleted
        expect(flash[:info]).to include("クリーンアップ対象のレコードはありませんでした")
      end
    end

    context "エラーが発生した場合" do
      before do
        allow(Job).to receive(:cleanup_old_deleted_records)
          .and_return({ success: false, error: "エラーメッセージ" })
      end

      it "エラーメッセージを表示する" do
        delete :cleanup_old_deleted
        expect(flash[:alert]).to include("クリーンアップエラー")
      end
    end
  end

  describe "プライベートメソッド" do
    describe "#set_job" do
      context "通常のアクション" do
        it "アクティブな求人のみを取得する" do
          get :show, params: { id: job.id }
          expect(assigns(:job)).to eq job
        end

        it "削除済み求人は取得できない" do
          expect {
            get :show, params: { id: deleted_job.id }
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context "restoreアクション" do
        it "削除済み求人も取得できる" do
          patch :restore, params: { id: deleted_job.id }
          expect(assigns(:job)).to eq deleted_job
        end
      end
    end
  end
end
