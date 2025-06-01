require 'rails_helper'
require 'rake'

RSpec.describe 'cleanup rake tasks', type: :task do
  before do
    Rake.application.rake_require 'tasks/cleanup'
    Rake::Task.define_task(:environment)
  end

  describe 'jobs:cleanup_old_deleted' do
    let(:task) { Rake::Task['jobs:cleanup_old_deleted'] }
    let!(:old_deleted_jobs) { create_list(:job, 2, :old_deleted) }
    let!(:recent_deleted_jobs) { create_list(:job, 1, :deleted) }

    before do
      task.reenable
      allow_any_instance_of(SalesforceService).to receive(:delete_job_record)
        .and_return({ success: true })
    end

    it 'タスクが存在する' do
      expect(task).not_to be_nil
    end

    it '古い削除済みレコードをクリーンアップする' do
      expect {
        capture_stdout { task.invoke }
      }.to change { Job.with_deleted.count }.by(-2)
    end

    it '成功メッセージを出力する' do
      output = capture_stdout { task.invoke }
      expect(output).to include('クリーンアップ完了')
      expect(output).to include('2件のレコードを物理削除')
    end

    context 'クリーンアップ対象がない場合' do
      before do
        Job.soft_deleted_old.delete_all
      end

      it '対象なしメッセージを出力する' do
        output = capture_stdout { task.invoke }
        expect(output).to include('クリーンアップ対象のレコードはありませんでした')
      end
    end
  end

  describe 'jobs:deleted_stats' do
    let(:task) { Rake::Task['jobs:deleted_stats'] }
    let!(:active_jobs) { create_list(:job, 3) }
    let!(:recent_deleted_jobs) { create_list(:job, 2, :deleted) }
    let!(:old_deleted_jobs) { create_list(:job, 1, :old_deleted) }

    before do
      task.reenable
    end

    it 'タスクが存在する' do
      expect(task).not_to be_nil
    end

    it '統計情報を正しく出力する' do
      output = capture_stdout { task.invoke }
      expect(output).to include('削除済み総数: 3件')
      expect(output).to include('6ヶ月以内: 2件')
      expect(output).to include('6ヶ月以上: 1件')
    end

    context 'クリーンアップ対象がある場合' do
      it '警告メッセージを出力する' do
        output = capture_stdout { task.invoke }
        expect(output).to include('1件のレコードがクリーンアップ対象です')
        expect(output).to include('rails jobs:cleanup_old_deleted')
      end
    end

    context 'クリーンアップ対象がない場合' do
      before do
        Job.soft_deleted_old.delete_all
      end

      it '対象なしメッセージを出力する' do
        output = capture_stdout { task.invoke }
        expect(output).to include('クリーンアップ対象のレコードはありません')
      end
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
