# Salesforce API 連携練習アプリ

このプロジェクトは、SalesforceのAPI連携を練習するためのRailsアプリケーションです。
求人データをサイト側で作成し、Salesforceに自動同期する機能を提供します。

## 機能

- 求人データの作成・表示・編集・削除
- **Client Credentials Flow** によるSalesforce API連携
- Salesforceへのリアルタイム同期（求人作成時）
- Salesforce接続テスト機能
- 全求人データの一括Salesforce同期
- Salesforceからの求人データ取得

## 技術スタック

- **Ruby on Rails** 8.0.2
- **PostgreSQL** (データベース)
- **TailwindCSS** (スタイリング)
- **Restforce** (Salesforce API gem)
- **Solid Queue** (バックグラウンドジョブ処理)
- **Client Credentials Flow** (OAuth 2.0認証)

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
   - **Enable OAuth Settings: チェック**
   - **Enable Client Credentials Flow: チェック** ⭐️ 重要！
   - Selected OAuth Scopes: "Full access (full)" を追加

#### 3.2 環境変数の設定

`.env` ファイルを作成し、以下の情報を設定：

```bash
# Salesforce Client Credentials Flow Settings
SALESFORCE_CLIENT_ID=your_connected_app_consumer_key
SALESFORCE_CLIENT_SECRET=your_connected_app_consumer_secret
SALESFORCE_HOST=login.salesforce.com
```

**注意**: Client Credentials Flowでは、Username/Password/Security Tokenは不要です！

### 4. Salesforce カスタムオブジェクトの作成

Salesforce側で以下のカスタムオブジェクト `Job__c` を作成してください：

| フィールド名 | API名 | 型 |
|------------|-------|-----|
| 求人タイトル | Name | Text |
| 会社 | Company__c | Text |
| 概要 | Description__c | Long Text Area |
| 勤務地 | Location__c | Text |
| 給与 | Salary__c | Text |
| 雇用形態 | EmploymentType__c | Text |
| 応募要件 | Requirements__c | Long Text Area |
| 掲載日 | PostedDate__c | Date |

## 使い方

### 1. アプリケーションの起動

```bash
rails server
```

ブラウザで `http://localhost:3000` にアクセス

### 2. Salesforce接続テスト

1. トップページで自動的に接続テストが実行されます
2. 正常に接続できれば「Client Credentials Flow 接続成功」が表示されます
3. 手動テストは `/jobs/test_client_credentials` エンドポイントでも可能

### 3. 求人データの作成・同期

1. 「新しい求人を登録」をクリック
2. 求人情報を入力
3. 「求人を登録」をクリック

**データが自動的にSalesforceにリアルタイム同期されます！** ⚡️

### 4. 追加機能

**一括同期**
- `/jobs/sync_all_to_client_credentials` で全求人データを一括同期

**Salesforceデータ取得**
- `SalesforceService#query_jobs` でSalesforceから求人データを取得可能

## API エンドポイント

| エンドポイント | 機能 |
|---------------|------|
| `GET /jobs` | 求人一覧表示 + 接続テスト |
| `POST /jobs` | 求人作成 + Salesforce同期 |
| `GET /jobs/test_client_credentials` | 接続テスト（JSON） |
| `POST /jobs/sync_all_to_client_credentials` | 一括同期（JSON） |
| `POST /jobs/:id/sync_to_client_credentials` | 個別同期 |

## トラブルシューティング

### よくあるエラー

**認証エラー (Unauthorized)**
- Connected AppでClient Credentials Flowが有効になっているか確認
- SALESFORCE_CLIENT_IDとSALESFORCE_CLIENT_SECRETが正しいか確認

**API制限エラー**
- Salesforce Developer Editionの1日のAPI制限を確認
- 不要なリクエストを減らす

**カスタムオブジェクトが見つからない**
- Salesforce側で `Job__c` オブジェクトが正しく作成されているか確認
- API名が正しいか確認（`EmploymentType__c`, `PostedDate__c` など）

**SSL証明書エラー**
- 開発環境では `ssl: { verify: false }` で回避済み

## アーキテクチャ

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Rails App     │    │ SalesforceService│    │   Salesforce    │
│                 │    │                  │    │                 │
│ JobsController  │───▶│ Client Creds     │───▶│   Job__c        │
│                 │    │ Authentication   │    │   Object        │
│ Job Model       │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 次のステップ

このアプリを使って以下を試してみてください：

- [ ] ✅ Salesforceからデータを取得する機能（実装済み）
- [ ] データの更新・削除処理の実装
- [ ] エラーハンドリングの改善
- [ ] Webhookを使った双方向同期
- [ ] バッチ処理での大量データ同期の最適化
- [ ] ユーザー認証機能の追加

## 参考資料

- [Restforce gem documentation](https://github.com/restforce/restforce)
- [Salesforce REST API documentation](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/)
- [Client Credentials Flow設定ガイド](https://help.salesforce.com/s/articleView?id=sf.remoteaccess_oauth_client_credentials_flow.htm)
- [Connected App設定ガイド](https://help.salesforce.com/s/articleView?id=sf.connected_app_create.htm)

---

頑張って！🚀
