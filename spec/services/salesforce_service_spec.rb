require 'rails_helper'

RSpec.describe SalesforceService, type: :service do
  let(:service) { SalesforceService.new }
  let(:job) { create(:job) }

  describe '#test_connection' do
    context '接続成功の場合', :vcr do
      it '成功レスポンスを返す' do
        result = service.test_connection
        expect(result[:success]).to be true
        expect(result[:message]).to include("接続成功")
        expect(result[:organization]).to be_present
      end
    end

    context '接続失敗の場合' do
      before do
        allow(service).to receive(:get_access_token).and_return(nil)
      end

      it '失敗レスポンスを返す' do
        result = service.test_connection
        expect(result[:success]).to be false
        expect(result[:error]).to include("トークン取得に失敗")
      end
    end
  end

  describe '#upsert_job_record' do
    let(:mock_client) { double('Restforce::Client') }

    before do
      allow(service).to receive(:get_authenticated_client).and_return(mock_client)
    end

    context '新規作成の場合' do
      before do
        allow(mock_client).to receive(:upsert!).and_return("003XXXXXXXXXXXXXXX")
      end

      it '成功レスポンスを返す' do
        result = service.upsert_job_record(job)
        expect(result[:success]).to be true
        expect(result[:salesforce_id]).to eq "003XXXXXXXXXXXXXXX"
        expect(result[:operation]).to eq "created"
      end

      it '正しいパラメータでupsertを呼び出す' do
        expect(mock_client).to receive(:upsert!).with(
          "Job__c",
          "RailsJobID__c",
          hash_including(
            Name: job.title,
            Company__c: job.company,
            Description__c: job.description,
            Location__c: job.location,
            RailsJobID__c: job.id
          )
        )
        service.upsert_job_record(job)
      end
    end

    context '更新の場合' do
      before do
        allow(mock_client).to receive(:upsert!).and_return(true)
      end

      it '更新として認識する' do
        result = service.upsert_job_record(job)
        expect(result[:success]).to be true
        expect(result[:operation]).to eq "updated"
      end
    end

    context 'API エラーの場合' do
      before do
        allow(mock_client).to receive(:upsert!)
          .and_raise(Restforce::ResponseError.new("API Error"))
      end

      it 'エラーレスポンスを返す' do
        result = service.upsert_job_record(job)
        expect(result[:success]).to be false
        expect(result[:error]).to include("API エラー")
      end
    end

    context '認証失敗の場合' do
      before do
        allow(service).to receive(:get_authenticated_client).and_return(nil)
      end

      it '認証エラーを返す' do
        result = service.upsert_job_record(job)
        expect(result[:success]).to be false
        expect(result[:error]).to include("認証に失敗")
      end
    end
  end

  describe '#delete_job_record' do
    let(:mock_client) { double('Restforce::Client') }
    let(:mock_query_result) { double('QueryResult') }

    before do
      allow(service).to receive(:get_authenticated_client).and_return(mock_client)
    end

    context 'レコードが存在する場合' do
      let(:salesforce_record) { double('Record', Id: '003XXXXXXXXXXXXXXX') }

      before do
        allow(mock_query_result).to receive(:empty?).and_return(false)
        allow(mock_query_result).to receive(:first).and_return(salesforce_record)
        allow(mock_client).to receive(:query).and_return(mock_query_result)
        allow(mock_client).to receive(:destroy!)
      end

      it '成功レスポンスを返す' do
        result = service.delete_job_record(job)
        expect(result[:success]).to be true
        expect(result[:salesforce_id]).to eq '003XXXXXXXXXXXXXXX'
        expect(result[:message]).to include("削除しました")
      end

      it '正しいクエリで検索する' do
        expect(mock_client).to receive(:query)
          .with("SELECT Id FROM Job__c WHERE RailsJobID__c = '#{job.id}' LIMIT 1")
        service.delete_job_record(job)
      end

      it 'destroy!を呼び出す' do
        expect(mock_client).to receive(:destroy!).with("Job__c", '003XXXXXXXXXXXXXXX')
        service.delete_job_record(job)
      end
    end

    context 'レコードが存在しない場合' do
      before do
        allow(mock_query_result).to receive(:empty?).and_return(true)
        allow(mock_client).to receive(:query).and_return(mock_query_result)
      end

      it '成功レスポンス（既に削除済み）を返す' do
        result = service.delete_job_record(job)
        expect(result[:success]).to be true
        expect(result[:message]).to include("見つかりませんでした")
      end
    end

    context 'API エラーの場合' do
      before do
        allow(mock_client).to receive(:query)
          .and_raise(Restforce::ResponseError.new("API Error"))
      end

      it 'エラーレスポンスを返す' do
        result = service.delete_job_record(job)
        expect(result[:success]).to be false
        expect(result[:error]).to include("API エラー")
      end
    end
  end

  describe '#query_jobs' do
    let(:mock_client) { double('Restforce::Client') }
    let(:mock_jobs) { [
      double('Job', Id: '1', Name: 'Job 1'),
      double('Job', Id: '2', Name: 'Job 2')
    ] }

    before do
      allow(service).to receive(:get_authenticated_client).and_return(mock_client)
      allow(mock_jobs).to receive(:size).and_return(2)
      allow(mock_jobs).to receive(:to_a).and_return(mock_jobs)
    end

    context '成功の場合' do
      before do
        allow(mock_client).to receive(:query).and_return(mock_jobs)
      end

      it '求人データを返す' do
        result = service.query_jobs(5)
        expect(result[:success]).to be true
        expect(result[:jobs]).to eq mock_jobs
        expect(result[:count]).to eq 2
      end

      it '正しいクエリを実行する' do
        expect(mock_client).to receive(:query)
          .with("SELECT Id, Name, Company__c, Location__c, Salary__c, CreatedDate FROM Job__c ORDER BY CreatedDate DESC LIMIT 5")
        service.query_jobs(5)
      end
    end

    context 'エラーの場合' do
      before do
        allow(mock_client).to receive(:query).and_raise(StandardError.new("Query Error"))
      end

      it 'エラーレスポンスを返す' do
        result = service.query_jobs
        expect(result[:success]).to be false
        expect(result[:error]).to include("求人データ取得エラー")
      end
    end
  end

  describe 'プライベートメソッド' do
    describe '#get_access_token' do
      context 'SSL証明書検証が有効な場合' do
        it 'VERIFY_PEERを使用する' do
          stub_request(:post, "https://test.salesforce.com/services/oauth2/token")
            .to_return(status: 200, body: '{"access_token":"token","instance_url":"https://test.salesforce.com"}')

          allow(ENV).to receive(:[]).with('SALESFORCE_HOST').and_return('test.salesforce.com')
          allow(ENV).to receive(:[]).with('SALESFORCE_CLIENT_ID').and_return('client_id')
          allow(ENV).to receive(:[]).with('SALESFORCE_CLIENT_SECRET').and_return('client_secret')

          # プライベートメソッドを直接テストするため
          token_data = service.send(:get_access_token)
          expect(token_data).to be_present
          expect(token_data['access_token']).to eq 'token'
        end
      end

      context 'トークン取得失敗の場合' do
        it 'nilを返す' do
          stub_request(:post, "https://test.salesforce.com/services/oauth2/token")
            .to_return(status: 400, body: '{"error":"invalid_client"}')

          allow(ENV).to receive(:[]).with('SALESFORCE_HOST').and_return('test.salesforce.com')
          allow(ENV).to receive(:[]).with('SALESFORCE_CLIENT_ID').and_return('invalid_id')
          allow(ENV).to receive(:[]).with('SALESFORCE_CLIENT_SECRET').and_return('invalid_secret')

          token_data = service.send(:get_access_token)
          expect(token_data).to be_nil
        end
      end
    end

    describe '#create_restforce_client' do
      let(:token_data) do
        {
          'access_token' => 'test_token',
          'instance_url' => 'https://test.salesforce.com'
        }
      end

      it 'Restforceクライアントを作成する' do
        client = service.send(:create_restforce_client, token_data)
        expect(client).to be_a(Restforce::Client)
      end

      it 'SSL検証が有効になっている' do
        allow(Restforce).to receive(:new).and_call_original
        service.send(:create_restforce_client, token_data)
        expect(Restforce).to have_received(:new).with(
          hash_including(ssl: { verify: true })
        )
      end
    end
  end
end
