# cooViewer 1.2b

macOS 向けの画像・コミックアーカイブビューアです。操作方法は [マニュアル](docs/manual.html) を参照してください。

## ビルド

Apple Silicon 搭載の macOS 15 以降を対象に、フル版 Xcode の `xcodebuild` で arm64 版をビルドします。アーカイブ読み込みには macOS の `libarchive` を使用します。追加のアーカイブフレームワークは不要です。

```sh
xcodebuild -project cooViewer.xcodeproj -scheme cooViewer \
  -configuration Development -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

アプリは `build/Products/Development/cooViewer.app` に出力されます。配布向けには `-configuration Deployment` を指定してください。

## テスト

```sh
sh test/run_tests.sh
```

このテストはアーカイブの読み込み、階層付きファイルの展開、不正な展開先の拒否、破損したアーカイブによる既存ファイルの上書き防止を確認します。

## ディレクトリ

- `src/`: アプリの Objective-C ソース。機能別のサブディレクトリに分割。
- `test/`: テストコードと実行スクリプト。
- `resource/`: Xcode がアプリに組み込む画像、アイコン、メニュー、翻訳、およびローカライズ作業ファイル。
- `docs/`: 操作マニュアル、開発資料、ライセンス。
- `tools/`: ローカライズ補助ツール。

依存関係とファイル追加時の注意点は [開発資料](docs/DEVELOPMENT.md) を参照してください。

## アンインストール

アプリ本体と `~/Library/Preferences/jp.coo.cooViewer.plist` を削除してください。

## ライセンス

cooViewer は MIT ライセンスです。[本体のライセンス](docs/licenses/Licence.txt) と [Remote Control Wrapper のライセンス](docs/licenses/Licence_RemoteControlWrapper.txt) を参照してください。
両ライセンス文書は生成されるアプリにも同梱されます。
