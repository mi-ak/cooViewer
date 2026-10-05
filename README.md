# coo2 0.1.0

[日本語](README.md) · [English](README.en.md)

macOS 向けの画像・コミックアーカイブビューアです。**HEIC の写真を変換せずにそのまま開けます。** WebP の静止画像の表示、アニメーション GIF／WebP の再生、暗証番号付き PDF の閲覧にも対応します。

**coo2 は coo 氏による [cooViewer](https://github.com/coo-ona/cooViewer) の派生版で、元の作者による公式版ではありません。** 機能の紹介は [coo2 の紹介](docs/index.md)、操作方法は [操作マニュアル](docs/manual.md) を参照してください。

## ビルド

Apple Silicon 搭載の macOS 15 以降を対象に、フル版 Xcode の `xcodebuild` で arm64 版をビルドします。アーカイブ読み込みには macOS の `libarchive` を使用します。追加のアーカイブフレームワークは不要です。

```sh
xcodebuild -project coo2.xcodeproj -scheme coo2 \
  -configuration Development -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

アプリは `build/Products/Development/coo2.app` に出力されます。配布向けには `-configuration Deployment` を指定してください。

## バージョン

公開バージョンは `主.サブ.更新` の 3 桁です。最初の派生版を `0.1.0` とし、大きな変更では主、新機能ではサブ、修正では更新をカウントアップします。上位の桁を上げたときは、下位の桁を 0 に戻します。Xcode の `MARKETING_VERSION` に公開バージョン、`CURRENT_PROJECT_VERSION` に配布ビルドごとに増やす整数を設定します。

## テスト

```sh
sh test/run_tests.sh
```

このテストはアーカイブの読み込みと安全な展開、旧形式の設定とファイルエイリアスの移行、ファイル名の自然順ソート、複数ページ PDF の並行描画と暗証番号、起動時の指定ファイルと前回の本の選択を確認します。

## ディレクトリ

- `src/`: アプリの Objective-C ソース。機能別のサブディレクトリに分割。
- `test/`: テストコードと実行スクリプト。
- `resource/`: Xcode がアプリに組み込む画像、アイコン、メニュー、翻訳、およびローカライズ作業ファイル。
- `docs/`: 操作マニュアル、開発資料、ライセンス。
- `tools/`: ローカライズ補助ツール。

依存関係とファイル追加時の注意点は [開発資料](docs/DEVELOPMENT.md) を参照してください。

## アンインストール

アプリ本体と `~/Library/Preferences/io.github.mi-ak.coo2.plist` を削除してください。元の cooViewer の設定は別に保存されます。

## ライセンス

coo2 は cooViewer の MIT 形式のライセンスに基づく派生版です。原作者 coo 氏の著作権表示と許諾文を含む[原作のライセンス](docs/licenses/Licence.txt)を参照してください。ライセンス文書は生成されるアプリにも同梱されます。
