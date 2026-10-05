# coo2 Development notes

[English](DEVELOPMENT.md) · [日本語](../DEVELOPMENT.md)

[Introduction](index.md) · [User manual](manual.md) · [Additional information](other.md) · [Development notes](DEVELOPMENT.md)

## Dependencies

The application entry point is `src/main.m`. UI and input coordination live in `src/app/controller/`. The main dependencies are:

```text
app/controller ──> image/COImageLoader ──> image/archive/COArchiveReader ──> macOS libarchive
       │                    └────────────> image/pdf ────────────────────> Quartz/PDFKit
       ├───────> app/window, app/full_image, thumbnail, bookmark, preference, filter
       └───────> AppKit keyboard and mouse input
```

`src/extensions/` contains Foundation/AppKit categories shared across features. `COArchiveReader` provides the boundary between the image loader and archive handling, so the loader does not depend directly on archive format implementations.

## Xcode project and resources

`coo2.xcodeproj/project.pbxproj` lists individual file references. When adding or moving source files or resources, update the Xcode groups, Build Phases, and actual paths together. The search path for Objective-C headers across modules is `src/**`.

Runtime images are in `resource/images/`, the icon catalog is in `resource/AppIcon.xcassets/`, and localized resources are in `resource/*.lproj/`. Images are copied directly into the app's resource directory, so code continues to reference them by filename through `NSBundle`. `resource/localization/` contains Xcode localization material for translation editing and is not copied into the app.

## Verification

Run a Development build using the command in the root [README](../../README.en.md#build). Run `sh test/run_tests.sh` to verify archive handling, settings migration, natural filename sorting, concurrent PDF rendering and passwords, and book selection at launch. Test ZIPs, PDFs, and legacy settings data are generated in a temporary directory.

`pdf_render_test.m` also checks that selecting an image skips protected PDFs in the same folder and subfolders, while directly opening a PDF or folder still supports authentication and viewing.

`launch_open_test.m` calls the real application delegate callbacks to check file requests arriving before or after launch completes, launches without a file, disabled automatic restoration, and failure to open an explicitly requested file. Test objects replace window display and preference loading, so the tests do not modify the user's preferences.

`COFileBookmarks.h` converts legacy Carbon AliasRecord data to `NSURL` bookmarks when loaded. `COArchivedSettings.h` reads legacy `NSArchiver` data and rewrites it as a secure keyed archive. Legacy loading is used only to migrate existing settings.

For display changes, build the app and also launch it on macOS to check the result. There is currently no automated GUI test target.
