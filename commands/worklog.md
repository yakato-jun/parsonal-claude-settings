---
description: 案件ベースのワークログ管理 - tmp/ 配下の作業ログで作業を進めます
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - Edit
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# /worklog - 案件ベースのワークログ管理

## 引数の処理

引数: `$ARGUMENTS`

以下のルールで引数を解釈する:

| パターン | 判定方法 | 動作 |
|----------|----------|------|
| 空文字列 | 引数なし | **対話モード** |
| `list` | 完全一致 | **一覧表示** |
| `new <名前>` | `new` で始まる | **新規作成** |
| その他 | 上記以外 | **直接指定** |

---

## 対話モード（引数なし）

1. プロジェクトルートの `tmp/` 配下を走査
   - `tmp/*/worklog.md` を Glob で検索
   - 更新日時でソート（`ls -t` 等を使用）
2. AskUserQuestion で確認:
   - 最新の案件を選択肢として提示（最大3件 + 「新規作成」）
   - 各選択肢に案件名と Status を表示
3. 選択された案件の worklog.md を読み込み
4. Tasks セクション内の未完了チェックボックス（`- [ ]`）を TaskCreate で展開
5. 作業開始

## 一覧表示（`list`）

- `tmp/*/worklog.md` を検索し一覧表示
- 各案件: ディレクトリ名、Status、Updated 日付を表示
- 旧形式のフラットファイル（`tmp/*.md`）も認識して表示

## 新規作成（`new <名前>`）

1. `tmp/<名前>/` ディレクトリを作成
2. 以下のテンプレートで `worklog.md` を作成:
   - Created / Updated: 現在日付（`date +%Y-%m-%d` で取得）
   - Branch: 現在のブランチ名（`git rev-parse --abbrev-ref HEAD` で取得）
3. Objective をユーザーに確認（AskUserQuestion または対話で）
4. 作業開始

## 直接指定（`<パス or 名前>`）

- `tmp/<引数>/worklog.md` を探して読み込み
- 見つからなければ `tmp/` 配下で部分一致検索
- 見つかったら Tasks を展開して作業開始

---

## ディレクトリ構成規約

```
<project>/tmp/
├── <案件A>/
│   ├── worklog.md       # 作業ログ本体（1案件1ファイル）
│   └── ...              # 分析結果、中間ファイル等
├── <案件B>/
│   └── worklog.md
└── (旧形式のファイル)    # 既存のフラットファイルも認識する
```

- 案件ディレクトリ名: チケット番号やスラッグ（例: `AMRSW-2181_scbdriver-unification`）
- `worklog.md` が各案件の起点ファイル

## worklog.md テンプレート

新規作成時に以下のテンプレートを使用する:

```markdown
# <案件名>

- **Created**: YYYY-MM-DD
- **Updated**: YYYY-MM-DD
- **Ticket**: <JIRAチケット等>
- **Branch**: <ブランチ名>
- **Status**: In Progress / Completed / Suspended

## Objective

<この案件で達成したいこと>

## Current State

<現在の状態・進捗>

## Tasks

- [ ] タスク1

## Decision Log

### YYYY-MM-DD: <判断タイトル>
Rationale: ...

## Notes

<その他のメモ・分析結果等>
```

---

## 記録ルール

### 記録タイミング

- **ユーザーから新しい指示を受けた時**: 指示内容を記録
- **タスク完了時**: 完了状態を更新
- **方針転換が発生した時**: 理由と新しい方針を記録
- **重要な判断を行った時**: 判断内容と根拠を Decision Log に記録

### 更新対象

- worklog.md の該当セクションを直接更新（追記ではなく、現在の正しい状態を維持）
- 完了したタスクは削除せず、ステータスを `[x]` に更新
- Updated の日付を更新

### 言語

- ログ本体は日本語で記載する（language 設定に準拠）

### 作業ファイル

- 作業ファイルの名前には `MMdd_hhmm_` を prefix で付ける（`date +%m%d_%H%M_` で取得）
- 必要以上に新しいファイルを作らない（`_modified`, `_final`, `_completed` 等の派生ファイル禁止）

### 完了通知

- 作業完了時の音声通知は `/done` スキルに委譲する
