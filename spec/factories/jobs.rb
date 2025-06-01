FactoryBot.define do
  factory :job do
    title { "Ruby on Rails エンジニア" }
    company { "テスト株式会社" }
    description { "Ruby on Railsを使ったWebアプリケーション開発をお任せします。" }
    location { "東京都渋谷区" }
    salary { 6000000 }
    employment_type { "正社員" }
    requirements { "Ruby on Rails 3年以上の経験" }
    posted_at { Time.current }

    # 削除済みの求人
    trait :deleted do
      deleted_at { 1.week.ago }
    end

    # 古い削除済み求人（6ヶ月以上前）
    trait :old_deleted do
      deleted_at { 7.months.ago }
    end

    # Salesforce同期フラグ付き
    trait :with_salesforce_sync do
      sync_to_salesforce { "1" }
    end

    # 異なる雇用形態
    trait :contract do
      employment_type { "契約社員" }
    end

    trait :part_time do
      employment_type { "パート・アルバイト" }
    end

    # 異なる会社
    trait :different_company do
      company { "別の会社株式会社" }
      title { "フロントエンドエンジニア" }
      description { "React.jsを使ったフロントエンド開発" }
    end
  end
end
