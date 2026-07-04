# godot-D_FileEnumWatcher

Godot 4 エディタプラグイン。ファイルシステムを監視し、設定された拡張子にマッチするリソースファイルを検出、重複のないエントリ一覧を管理し、そこから GDScript の enum コードを自動生成します。

各エントリは Godot の ResourceUID で追跡されるため、ファイルのリネームや移動が発生しても enum のキーは UID が有効である限り安定しています。

## 特徴

- **ファイルシステム監視** — `EditorFileSystem.filesystem_changed` および `sources_changed` シグナルをリッスン。2フレームのデバウンスで連続イベントを結合。
- **Enum コード生成** — ソート済みエントリ、`NONE = -1` センチネル、UID 値を含む GDScript `enum` ブロックを出力。
- **インプレース置換** — 既存の名前付き enum ブロックを `.gd` ファイル内で検出し、手書きコードを保持したまま置換。
- **ユニークで有効なキー** — ファイル名を GDScript 識別子として有効な形にサニタイズ。衝突時は数値サフィックスを付与。
- **ルックアップマップ** — `uid → name` および `name → uid` の辞書を生成するヘルパーを提供。

## インストール

1. `addons/godot-D_FileEnumWatcher/` ディレクトリをプロジェクトの `addons/` にコピーします。
2. **プロジェクト → プロジェクト設定 → プラグイン** でプラグインを有効にします（将来プラグインスクリプトが追加された場合）。
3. _(推奨)_ `project.godot` の `editor_plugins/` に `res://addons/godot-D_FileEnumWatcher/core/` を追加すると、`FileEnumWatcher`、`FEWEntry`、`FEWEnumCodegen`、`FEWFileWatcher` がエディタで利用可能になります。

> **注意:** 現在このアドオンは GUI を持つ本格的なエディタプラグインではなく、再利用可能なスクリプトライブラリとして動作します。独自のツールスクリプトでクラスをインスタンス化して使用します。

## 使用例

```gdscript
extends Node

@tool

func _ready() -> void:
    var watcher := FileEnumWatcher.new()
    watcher.set_extensions([".tscn", ".tres", ".res"])
    watcher.add_include_path("res://scenes/")
    watcher.add_include_path("res://resources/")

    # エントリ変更の通知を受け取る
    watcher.entries_changed.connect(_on_entries_changed)

    # enum ブロックを生成
    var codegen := FEWEnumCodegen
    var enum_block := codegen.build_enum(watcher.get_entries(), "SceneId")
    print(enum_block)
    # 出力:
    # enum SceneId {
    #     NONE = -1,
    #     MY_SCENE = 1234567890,
    #     ...
    # }

    # GDScript ファイル内の既存 enum を置換
    var source := FileAccess.get_file_as_string("res://enums.gd")
    var updated := codegen.replace_enum_in_source(source, "SceneId", enum_block)
    # 更新内容をディスクに書き込む...

    # 後始末
    watcher.destroy()

func _on_entries_changed(entries: Array[FEWEntry]) -> void:
    print("Entries updated: ", entries.size())
```

## API 概要

### `FileEnumWatcher`
高レベルファサード。インクルードパスを管理し、ファイルシステムをスキャンして `entries_changed` シグナルを発行します。

| メソッド | 説明 |
|----------|------|
| `set_extensions(exts)` / `get_extensions()` | 監視する拡張子を設定 / 取得。 |
| `add_include_path(path)` → `bool` | 監視対象のディレクトリまたはファイルを追加。無効または既にカバー済みの場合は `false`。 |
| `remove_include_path(path)` | パスを削除し、その配下のエントリを登録解除。 |
| `get_entries()` → `Array[FEWEntry]` | 登録済みの全エントリを返す。 |
| `get_entry_by_uid(uid)` → `FEWEntry` | ResourceUID でエントリを検索。 |
| `sync()` | 全インクルードパスを再スキャン、移動されたファイルを更新、削除されたものを除去。 |
| `suppress_next_change()` | 次のファイルシステム変更イベントを抑制（自身の書き込み後に呼ぶ）。 |
| `handle_focus_in()` | 即座に再チェックを実行（エディタがフォーカスを取り戻したときに呼ぶ）。 |
| `destroy()` | シグナルを切断しリソースを解放。 |

### `FEWEntry`
ファイルパス、UID、サニタイズ済み enum キーを保持するデータクラス。

### `FEWEnumCodegen`
状態を持たないコード生成ユーティリティ。

| メソッド | 説明 |
|----------|------|
| `sanitize_key(text)` → `String` | 任意のテキストを有効な GDScript enum キーに変換。 |
| `build_enum(entries, enum_name, none_value)` → `String` | 完全な `enum { ... }` ブロック文字列を生成。 |
| `replace_enum_in_source(source, enum_name, new_block)` → `String` | GDScript ソース文字列内の enum ブロックを置換または追記。 |
| `build_uid_to_name_map(entries)` → `Dictionary` | `uid → name` ルックアップ辞書を構築。 |
| `build_name_to_uid_map(entries)` → `Dictionary` | `name → uid` ルックアップ辞書を構築。 |

### `FEWFileWatcher`
低レベル watcher。監視対象ファイルの追加・削除・変更を検出して `files_changed` を発行します。通常は `FileEnumWatcher` 経由で使用します。

## ライセンス

MIT
