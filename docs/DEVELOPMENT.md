# 開発資料

## 依存関係

アプリの起動点は `src/main.m`、画面と操作の統合は `src/app/controller/` です。主要な依存関係は次のとおりです。

```text
app/controller ──> image/COImageLoader ──> image/archive/COArchiveReader ──> macOS libarchive
       │                    └────────────> image/pdf ────────────────────> Quartz/PDFKit
       ├───────> app/window, app/full_image, thumbnail, bookmark, preference, filter
       └───────> remote ──────────────────────────────────────────────────> IOKit/Carbon
```

`src/extensions/` には複数の機能から使う Foundation/AppKit のカテゴリを置きます。`remote/` は Remote Control Wrapper 由来のコードです。`COArchiveReader` を境界にしているため、画像ローダーはアーカイブ形式の実装に直接依存しません。

## Xcode プロジェクトとリソース

`cooViewer.xcodeproj/project.pbxproj` はファイル参照を個別に持っています。ソースやリソースを追加・移動した際は、Xcode のグループ、Build Phases、および実際のパスを合わせて更新してください。モジュールをまたぐ Objective-C ヘッダの検索先は `src/**` です。

実行時の画像は `resource/images/`、アイコンカタログは `resource/AppIcon.xcassets/`、ローカライズ対象は `resource/*.lproj/` にあります。画像ファイルはアプリのリソースディレクトリ直下にコピーされるため、コードからは従来どおり `NSBundle` のファイル名で参照します。`resource/localization/` は翻訳編集用の Xcode ローカライズ資料で、アプリへコピーしません。

## 検証

ルートの README にあるコマンドで Development ビルドを行います。アーカイブ処理の回帰テストは `sh test/run_tests.sh` で実行します。テスト用の ZIP は一時ディレクトリに生成し、macOS の `libarchive` と実際の `COArchiveReader.m` をリンクして検証します。

画面表示の変更は、ビルドに加えて macOS 上でアプリを起動して確認してください。現在、GUI の自動テストターゲットはありません。
