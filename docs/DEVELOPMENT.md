# coo2 開発資料

[日本語](DEVELOPMENT.md) · [English](en/DEVELOPMENT.md)

[紹介](index.md) · [操作マニュアル](manual.md) · [補足情報](other.md) · [開発資料](DEVELOPMENT.md)

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

`coo2.xcodeproj/project.pbxproj` はファイル参照を個別に持っています。ソースやリソースを追加・移動した際は、Xcode のグループ、Build Phases、および実際のパスを合わせて更新してください。モジュールをまたぐ Objective-C ヘッダの検索先は `src/**` です。

実行時の画像は `resource/images/`、アイコンカタログは `resource/AppIcon.xcassets/`、ローカライズ対象は `resource/*.lproj/` にあります。画像ファイルはアプリのリソースディレクトリ直下にコピーされるため、コードからは従来どおり `NSBundle` のファイル名で参照します。`resource/localization/` は翻訳編集用の Xcode ローカライズ資料で、アプリへコピーしません。

## 検証

ルートの README にあるコマンドで Development ビルドを行います。`sh test/run_tests.sh` でアーカイブ処理、設定移行、ファイル名の自然順ソート、PDF の並行描画と暗証番号、起動時の本の選択を検証します。テスト用の ZIP と PDF、旧形式の設定データは一時ディレクトリに生成します。

`pdf_render_test.m` は、画像ファイルを指定したときに周辺やサブフォルダの暗証番号付き PDF を読み込まず、PDF やフォルダを直接指定したときは従来どおり認証して閲覧できることも確認します。

`launch_open_test.m` は実際のアプリケーションデリゲートのコールバックを呼び、指定ファイルが起動完了の前後に届く場合、ファイル指定なしの場合、自動復元が無効の場合、指定ファイルを開けない場合を検証します。ウィンドウ表示と設定の読み込みはテスト用のオブジェクトに置き換え、ユーザーの環境設定を変更しません。

`COFileBookmarks.h` は旧 Carbon AliasRecord を読み込み時に `NSURL` ブックマークへ変換します。`COArchivedSettings.h` は旧 `NSArchiver` データを読み込んで安全な keyed archive へ書き換えます。旧形式の読み込みは既存設定の移行専用です。

画面表示の変更は、ビルドに加えて macOS 上でアプリを起動して確認してください。現在、GUI の自動テストターゲットはありません。
