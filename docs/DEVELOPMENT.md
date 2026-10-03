# 開発資料

## 依存関係

アプリの起動点は `src/main.m`、画面と操作の統合は `src/app/controller/` です。主要な依存関係は次のとおりです。

```text
app/controller ──> image/COImageLoader ──> image/archive/COArchiveReader ──> macOS libarchive
       │                    └────────────> image/pdf ────────────────────> Quartz/PDFKit
       ├───────> app/window, app/full_image, thumbnail, bookmark, preference, filter
       └───────> AppKit のキー・マウス入力
```

`src/extensions/` には複数の機能から使う Foundation/AppKit のカテゴリを置きます。`COArchiveReader` を境界にしているため、画像ローダーはアーカイブ形式の実装に直接依存しません。

## Xcode プロジェクトとリソース

`cooViewer.xcodeproj/project.pbxproj` はファイル参照を個別に持っています。ソースやリソースを追加・移動した際は、Xcode のグループ、Build Phases、および実際のパスを合わせて更新してください。モジュールをまたぐ Objective-C ヘッダの検索先は `src/**` です。

実行時の画像は `resource/images/`、アイコンカタログは `resource/AppIcon.xcassets/`、ローカライズ対象は `resource/*.lproj/` にあります。画像ファイルはアプリのリソースディレクトリ直下にコピーされるため、コードからは従来どおり `NSBundle` のファイル名で参照します。`resource/localization/` は翻訳編集用の Xcode ローカライズ資料で、アプリへコピーしません。

## 検証

ルートの README にあるコマンドで Development ビルドを行います。`sh test/run_tests.sh` でアーカイブ処理、設定移行、ファイル名の自然順ソートを検証します。テスト用の ZIP と旧形式の設定データは一時ディレクトリに生成します。

`COFileBookmarks.h` は旧 Carbon AliasRecord を読み込み時に `NSURL` ブックマークへ変換します。`COArchivedSettings.h` は旧 `NSArchiver` データを読み込んで安全な keyed archive へ書き換えます。旧形式の読み込みは既存設定の移行専用です。

画面表示の変更は、ビルドに加えて macOS 上でアプリを起動して確認してください。現在、GUI の自動テストターゲットはありません。
