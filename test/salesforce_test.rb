require "dotenv"
Dotenv.load

# Railsアプリケーションの環境を読み込み
require_relative "../config/environment"

puts "🔧 SalesforceService テスト"
puts "=" * 50

# テスト用の求人データ
class TestJob
  attr_accessor :title, :company, :description, :location, :salary, :employment_type, :requirements, :posted_at

  def initialize
    @title = "Ruby Developer (Test)"
    @company = "Test Company"
    @description = "Ruby on Rails development position"
    @location = "Tokyo"
    @salary = "5000000"
    @employment_type = "正社員"
    @requirements = "Ruby, Rails experience required"
    @posted_at = Time.now
  end
end

def test_salesforce_connection
  puts "\n🚀 Salesforce接続テスト"

  service = SalesforceService.new
  result = service.test_connection

  if result[:success]
    puts "✅ 接続成功！"
    puts "   組織名: #{result[:organization]}"
    puts "   メッセージ: #{result[:message]}"
  else
    puts "❌ 接続失敗: #{result[:error]}"
  end

  result[:success]
end

def test_job_creation
  puts "\n📝 求人データ作成テスト"

  service = SalesforceService.new
  test_job = TestJob.new

  result = service.create_job_record(test_job)

  if result[:success]
    puts "✅ 求人作成成功！"
    puts "   Salesforce ID: #{result[:salesforce_id]}"
  else
    puts "❌ 求人作成失敗: #{result[:error]}"
  end

  result[:success]
end

def test_job_query
  puts "\n🔍 求人データ取得テスト"

  service = SalesforceService.new
  result = service.query_jobs(5)

  if result[:success]
    puts "✅ 求人データ取得成功！"
    puts "   取得件数: #{result[:count]}件"

    if result[:jobs].any?
      puts "   最新の求人:"
      result[:jobs].first(3).each_with_index do |job, index|
        puts "     #{index + 1}. #{job['Name']} - #{job['Company__c']}"
      end
    else
      puts "   求人データがありません"
    end
  else
    puts "❌ 求人データ取得失敗: #{result[:error]}"
  end

  result[:success]
end

# メインテスト実行
begin
  puts "環境変数確認:"
  puts "  SALESFORCE_HOST: #{ENV['SALESFORCE_HOST']}"
  puts "  SALESFORCE_CLIENT_ID: #{ENV['SALESFORCE_CLIENT_ID'] ? '設定済み' : '未設定'}"
  puts "  SALESFORCE_CLIENT_SECRET: #{ENV['SALESFORCE_CLIENT_SECRET'] ? '設定済み' : '未設定'}"

  # 1. 接続テスト
  connection_success = test_salesforce_connection

  if connection_success
    # 2. 求人作成テスト
    creation_success = test_job_creation

    # 3. 求人取得テスト
    query_success = test_job_query

    puts "\n" + "=" * 50
    puts "📊 テスト結果サマリー"
    puts "  接続テスト: #{connection_success ? '✅ 成功' : '❌ 失敗'}"
    puts "  求人作成: #{creation_success ? '✅ 成功' : '❌ 失敗'}"
    puts "  求人取得: #{query_success ? '✅ 成功' : '❌ 失敗'}"

    if connection_success && creation_success && query_success
      puts "\n🎉 全てのテストが成功しました！"
    else
      puts "\n⚠️  一部のテストで問題が発生しました"
    end
  else
    puts "\n❌ 接続テストが失敗したため、他のテストをスキップします"
  end

rescue => e
  puts "\n❌ テスト実行エラー: #{e.message}"
  puts "エラークラス: #{e.class}"
  puts "バックトレース:"
  puts e.backtrace.first(5).map { |line| "  #{line}" }
end
