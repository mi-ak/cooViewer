# cooViewer1.2b
https://coo-ona.github.io/cooViewer/

## 現行Mac / Apple Silicon (M2以降) でのビルド

アーカイブ読み込みはmacOS標準の `libarchive` を使用するため、追加のアーカイブフレームワークは不要です。

```sh
git clone https://github.com/coo-ona/cooViewer.git
cd cooViewer
xcodebuild -project cooViewer.xcodeproj -scheme cooViewer -configuration Deployment -arch arm64
```

Intel Macでも動かすUniversal 2バイナリを作る場合は、`-arch arm64 -arch x86_64` と指定します。

フル版のXcode（Command Line Toolsのみでは不可）が必要です。

## 開発環境
MacBook Pro (2.3GHz/16GB)<br>
MacOS X 10.14.5

## 操作方法
https://coo-ona.github.io/cooViewer/manual.html

## アンインストール
・アプリ本体<br>
・/Users/(ユーザー名)/ライブラリ/Preferences/jp.coo.cooViewer.plist<br>
を消してください

## 著作権、免責等
cooViewerはMITライセンスです。
ライセンスについては添付のLicence.txtを参照してください。

このソフトウェアはRemote Control Wrapper ( http://www.martinkahr.com/source-code/ ) を使用しています。<br>
ライセンスについては添付のLicence_RemoteControlWrapper.txtを参照してください。

64bit化対応にあたり、スレの皆様をはじめ、多くの方にご協力いただきました。ありがとうございます。
また、nibをxibに変換いただいたkanjitalk755さんには特に感謝申し上げます。
