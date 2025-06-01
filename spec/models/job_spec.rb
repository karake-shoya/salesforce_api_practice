require 'rails_helper'

RSpec.describe Job, type: :model do
  describe 'バリデーション' do
    it '有効なファクトリを持つ' do
      expect(build(:job)).to be_valid
    end

    it 'titleが必須' do
      job = build(:job, title: nil)
      expect(job).not_to be_valid
      expect(job.errors[:title]).to include("can't be blank")
    end

    it 'companyが必須' do
      job = build(:job, company: nil)
      expect(job).not_to be_valid
      expect(job.errors[:company]).to include("can't be blank")
    end

    it 'descriptionが必須' do
      job = build(:job, description: nil)
      expect(job).not_to be_valid
      expect(job.errors[:description]).to include("can't be blank")
    end

    it 'locationが必須' do
      job = build(:job, location: nil)
      expect(job).not_to be_valid
      expect(job.errors[:location]).to include("can't be blank")
    end
  end

  describe 'スコープ' do
    let!(:active_job) { create(:job) }
    let!(:deleted_job) { create(:job, :deleted) }
    let!(:old_deleted_job) { create(:job, :old_deleted) }

    describe '.active' do
      it 'アクティブな求人のみを返す' do
        expect(Job.active).to include(active_job)
        expect(Job.active).not_to include(deleted_job)
        expect(Job.active).not_to include(old_deleted_job)
      end
    end

    describe '.deleted' do
      it '削除済みの求人のみを返す' do
        expect(Job.deleted).to include(deleted_job)
        expect(Job.deleted).to include(old_deleted_job)
        expect(Job.deleted).not_to include(active_job)
      end
    end

    describe '.with_deleted' do
      it '全ての求人を返す' do
        expect(Job.with_deleted).to include(active_job)
        expect(Job.with_deleted).to include(deleted_job)
        expect(Job.with_deleted).to include(old_deleted_job)
      end
    end

    describe '.soft_deleted_old' do
      it '6ヶ月以上前に削除された求人のみを返す' do
        expect(Job.soft_deleted_old).to include(old_deleted_job)
        expect(Job.soft_deleted_old).not_to include(deleted_job)
        expect(Job.soft_deleted_old).not_to include(active_job)
      end
    end
  end

  describe 'default_scope' do
    let!(:active_job) { create(:job) }
    let!(:deleted_job) { create(:job, :deleted) }

    it 'デフォルトでアクティブな求人のみを返す' do
      expect(Job.all).to include(active_job)
      expect(Job.all).not_to include(deleted_job)
    end
  end

  describe '論理削除機能' do
    let(:job) { create(:job) }

    describe '#soft_delete!' do
      it '求人を論理削除する' do
        expect { job.soft_delete! }.to change { job.deleted_at }.from(nil)
        expect(job.deleted?).to be true
      end

      it '論理削除後はdefault_scopeで取得できない' do
        job.soft_delete!
        expect(Job.all).not_to include(job)
      end
    end

    describe '#deleted?' do
      it 'アクティブな求人はfalseを返す' do
        expect(job.deleted?).to be false
      end

      it '削除済みの求人はtrueを返す' do
        job.soft_delete!
        expect(job.deleted?).to be true
      end
    end

    describe '#restore!' do
      let(:deleted_job) { create(:job, :deleted) }

      it '削除済みの求人を復元する' do
        expect { deleted_job.restore! }.to change { deleted_job.deleted_at }.to(nil)
        expect(deleted_job.deleted?).to be false
      end

      it '復元後はdefault_scopeで取得できる' do
        deleted_job.restore!
        expect(Job.all).to include(deleted_job)
      end
    end
  end

  describe 'クリーンアップ機能' do
    let!(:recent_deleted) { create(:job, :deleted) }
    let!(:old_deleted1) { create(:job, :old_deleted) }
    let!(:old_deleted2) { create(:job, :old_deleted) }
    let!(:active_job) { create(:job) }

    before do
      # SalesforceServiceをモック化
      allow_any_instance_of(SalesforceService).to receive(:delete_job_record)
        .and_return({ success: true, message: "削除成功" })
    end

    describe '.cleanup_old_deleted_records' do
      it '6ヶ月以上前の削除済みレコードを物理削除する' do
        expect {
          Job.cleanup_old_deleted_records
        }.to change { Job.with_deleted.count }.by(-2)

        expect(Job.with_deleted).to include(recent_deleted)
        expect(Job.with_deleted).to include(active_job)
        expect(Job.with_deleted).not_to include(old_deleted1)
        expect(Job.with_deleted).not_to include(old_deleted2)
      end

      it '削除件数を正しく返す' do
        result = Job.cleanup_old_deleted_records
        expect(result[:success]).to be true
        expect(result[:deleted_count]).to eq 2
      end

      it 'Salesforce側の削除も実行する' do
        service_instance = instance_double(SalesforceService)
        allow(SalesforceService).to receive(:new).and_return(service_instance)
        allow(service_instance).to receive(:delete_job_record)
          .with(old_deleted1).and_return({ success: true })
        allow(service_instance).to receive(:delete_job_record)
          .with(old_deleted2).and_return({ success: true })

        Job.cleanup_old_deleted_records
      end

      context 'クリーンアップ対象がない場合' do
        before do
          Job.soft_deleted_old.delete_all
        end

        it '削除件数0を返す' do
          result = Job.cleanup_old_deleted_records
          expect(result[:success]).to be true
          expect(result[:deleted_count]).to eq 0
        end
      end

      context 'Salesforce削除でエラーが発生した場合' do
        before do
          allow_any_instance_of(SalesforceService).to receive(:delete_job_record)
            .and_raise(StandardError.new("API Error"))
        end

        it 'エラーをログに記録して処理を継続する' do
          expect(Rails.logger).to receive(:warn).at_least(:once)
          result = Job.cleanup_old_deleted_records
          expect(result[:success]).to be true
        end
      end
    end
  end

  describe 'Salesforce連携' do
    let(:job) { build(:job, :with_salesforce_sync) }

    it 'sync_to_salesforce属性を持つ' do
      expect(job).to respond_to(:sync_to_salesforce)
      expect(job.sync_to_salesforce).to eq "1"
    end
  end
end
