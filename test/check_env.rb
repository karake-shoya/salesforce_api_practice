require "dotenv"
Dotenv.load

puts "🔧 環境変数チェック"
puts "=" * 50

# 必要な環境変数のリスト
required_vars = [
  "SALESFORCE_CLIENT_ID",
  "SALESFORCE_CLIENT_SECRET",
  "SALESFORCE_USERNAME",
  "SALESFORCE_PASSWORD",
  "SALESFORCE_SECURITY_TOKEN",
  "SALESFORCE_HOST"
]

puts "📋 環境変数の設定状況:"
required_vars.each do |var|
  value = ENV[var]
  if value && !value.empty?
    # 機密情報は一部だけ表示
    if var.include?("SECRET") || var.include?("PASSWORD") || var.include?("TOKEN")
      masked_value = value.length > 4 ? "#{value[0..3]}#{'*' * (value.length - 4)}" : "****"
      puts "  ✅ #{var}: #{masked_value}"
    else
      puts "  ✅ #{var}: #{value}"
    end
  else
    puts "  ❌ #{var}: 未設定"
  end
end

puts "\n🔍 .envファイルの存在確認:"
if File.exist?(".env")
  puts "  ✅ .envファイル: 存在"
  file_size = File.size(".env")
  puts "  📏 ファイルサイズ: #{file_size}バイト"
else
  puts "  ❌ .envファイル: 存在しない"
end

puts "\n💡 ヒント:"
puts "  - 環境変数が未設定の場合は .env ファイルを確認してください"
puts "  - パスワードに特殊文字が含まれる場合はクォートで囲んでください"
puts "  - セキュリティトークンは最新のものを使用してください"
