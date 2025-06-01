namespace :jobs do
  desc "6ヶ月以上前に削除された求人レコードを物理削除する"
  task cleanup_old_deleted: :environment do
    puts "=== 古い削除済み求人レコードのクリーンアップを開始します ==="
    puts "対象: 6ヶ月以上前に削除されたレコード"
    puts "実行時刻: #{Time.current}"
    puts ""

    result = Job.cleanup_old_deleted_records

    if result[:success]
      if result[:deleted_count] > 0
        puts "✅ クリーンアップ完了: #{result[:deleted_count]}件のレコードを物理削除しました"
      else
        puts "ℹ️  クリーンアップ対象のレコードはありませんでした"
      end
    else
      puts "❌ クリーンアップエラー: #{result[:error]}"
      exit 1
    end

    puts ""
    puts "=== クリーンアップ処理が完了しました ==="
  end

  desc "削除済みレコードの統計情報を表示する"
  task deleted_stats: :environment do
    total_deleted = Job.deleted.count
    old_deleted = Job.soft_deleted_old.count
    recent_deleted = total_deleted - old_deleted

    puts "=== 削除済み求人レコード統計 ==="
    puts "実行時刻: #{Time.current}"
    puts ""
    puts "削除済み総数: #{total_deleted}件"
    puts "  - 6ヶ月以内: #{recent_deleted}件"
    puts "  - 6ヶ月以上: #{old_deleted}件 (クリーンアップ対象)"
    puts ""

    if old_deleted > 0
      puts "⚠️  #{old_deleted}件のレコードがクリーンアップ対象です"
      puts "実行コマンド: rails jobs:cleanup_old_deleted"
    else
      puts "✅ クリーンアップ対象のレコードはありません"
    end
  end
end
