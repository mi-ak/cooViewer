# coo2 0.1.1

[English](README.en.md) · [日本語](README.md)

An image and comic archive viewer for macOS. **Open HEIC photos directly, without converting them.** coo2 also supports WebP still images, animated GIF and WebP playback, and password-protected PDFs.

**coo2 is a fork of [cooViewer](https://github.com/coo-ona/cooViewer) by coo. It is not an official release by the original author.** See the [introduction](docs/en/index.md) for features and the [user manual](docs/en/manual.md) for instructions.

## Build

Build the arm64 app for Apple Silicon Macs running macOS 15 or later, using `xcodebuild` from the full Xcode installation. Archive reading uses the macOS version of `libarchive`; no additional archive framework is required.

```sh
xcodebuild -project coo2.xcodeproj -scheme coo2 \
  -configuration Development -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

The app is written to `build/Products/Development/coo2.app`. Use `-configuration Deployment` for distribution builds.

## Versioning

Public versions use three components: `major.minor.patch`. The first fork release is `0.1.0`. Increment the major version for large changes, the minor version for new features, and the patch version for fixes. Reset the lower components to zero when incrementing a higher component. Set Xcode's `MARKETING_VERSION` to the public version and `CURRENT_PROJECT_VERSION` to an integer that increases with each distribution build.

## Tests

```sh
sh test/run_tests.sh
```

The tests cover archive reading and safe extraction, migration of legacy settings and file aliases, natural filename sorting, concurrent rendering and passwords for multipage PDFs, and selection of an explicitly requested file versus the previous book at launch.

## Directories

- `src/`: Objective-C application source, organized by feature.
- `test/`: Test code and the test runner.
- `resource/`: Images, icons, menus, and translations bundled by Xcode, plus localization working files.
- `docs/`: User manual, development notes, and license.
- `tools/`: Localization helpers.

See the [development notes](docs/en/DEVELOPMENT.md) for dependencies and guidance on adding files.

## Uninstall

Delete the app and `~/Library/Preferences/io.github.mi-ak.coo2.plist`. The original cooViewer's preferences are stored separately.

## License

coo2 is a fork distributed under cooViewer's MIT-style license. See the [original license](docs/licenses/Licence.txt), which includes coo's copyright notice and permission text. The license is also bundled with the built app.
