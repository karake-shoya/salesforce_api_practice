# Salesforce API 連携練習アプリ

このプロジェクトは、SalesforceのAPI連携を練習するためのRailsアプリケーションです。
求人データをサイト側で作成し、Salesforceに自動同期する機能を提供します。

## 機能

- 求人データの作成・表示
- SalesforceへのAPI連携（自動同期）
- Salesforce接続テスト

## 技術スタック

- **Ruby on Rails** 8.0.2
- **PostgreSQL** (データベース)
- **TailwindCSS** (スタイリング)
- **Restforce** (Salesforce API gem)
- **Active Job** (非同期処理)

## セットアップ手順

### 1. 依存関係のインストール

```bash
bundle install
```

### 2. データベースの作成・マイグレーション

```bash
rails db:create
rails db:migrate
```

### 3. Salesforce設定

#### 3.1 Connected App の作成（Salesforce側）

1. Salesforce にログイン
2. Setup → App Manager → New Connected App
3. 以下を設定：
   - Connected App Name: 任意の名前
   - API Name: 自動生成
   - Contact Email: あなたのメール
   - Enable OAuth Settings: チェック
   - Callback URL: http://localhost:3000/callback (ローカル開発用)
   - Selected OAuth Scopes: "Full access (full)" を追加

#### 3.2 Security Token の取得

1. Salesforce にログイン
2. 右上のプロフィール → Settings → Reset My Security Token
3. メールで送られてくるSecurity Tokenをメモ

#### 3.3 環境変数の設定

`.env` ファイルを作成し、以下の情報を設定：

```bash
# Salesforce API Settings
SALESFORCE_CLIENT_ID=your_connected_app_consumer_key
SALESFORCE_CLIENT_SECRET=your_connected_app_consumer_secret
SALESFORCE_USERNAME=your_salesforce_username
SALESFORCE_PASSWORD=your_salesforce_password
SALESFORCE_SECURITY_TOKEN=your_security_token
SALESFORCE_HOST=login.salesforce.com
```

### 4. Salesforce カスタムオブジェクトの作成

Salesforce側で以下のカスタムオブジェクト `Job__c` を作成してください：

| フィールド名 | API名 | 型 |
|------------|-------|-----|
| 求人タイトル | Name | Text |
| 会社 | Company__c | Text |
| 概要 | Description__c | Long Text Area |
| 勤務地 | Location__c | Text |
| 給与 | Salary__c | Text |
| 雇用形態 | Employment_Type__c | Text |
| 応募要件 | Requirements__c | Long Text Area |
| 掲載日 | Posted_Date__c | Date |

## 使い方

### 1. アプリケーションの起動

```bash
rails server
```

ブラウザで `http://localhost:3000` にアクセス

### 2. Salesforce接続テスト

1. トップページの「Salesforce接続テスト」ボタンをクリック
2. 正常に接続できれば成功メッセージが表示されます

### 3. 求人データの作成・同期

1. 「新しい求人を登録」をクリック
2. 求人情報を入力
3. 「Salesforceに同期する」にチェック
4. 「求人を登録」をクリック

データがSalesforceに自動同期されます！

## トラブルシューティング

### よくあるエラー

**認証エラー (Unauthorized)**
- Salesforceの認証情報（Username, Password, Security Token）を確認
- Connected Appの設定を確認

**API制限エラー**
- Salesforce Developer Editionの1日のAPI制限を確認
- 不要なリクエストを減らす

**カスタムオブジェクトが見つからない**
- Salesforce側で `Job__c` オブジェクトが正しく作成されているか確認
- API名が正しいか確認

## 次のステップ

このアプリを使って以下を試してみてください：

- [ ] Salesforceからデータを取得する機能の追加
- [ ] データの更新・削除処理の実装
- [ ] エラーハンドリングの改善
- [ ] バッチ処理での大量データ同期
- [ ] Salesforceのトリガーを使った双方向同期

## 参考資料

- [Restforce gem documentation](https://github.com/restforce/restforce)
- [Salesforce REST API documentation](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/)
- [Connected App設定ガイド](https://help.salesforce.com/s/articleView?id=sf.connected_app_create.htm)

---

頑張って！🚀
