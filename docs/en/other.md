# coo2 Additional information

[English](other.md) · [日本語](../other.md)

[Introduction](index.md) · [User manual](manual.md) · [Additional information](other.md) · [Development notes](DEVELOPMENT.md)

## Relationship to cooViewer

coo2 is an independent fork of [cooViewer](https://github.com/coo-ona/cooViewer), developed by coo. It has its own app name and preference identifier and is not an official release by the original author.

The documentation in this repository is for coo2. Downloads of the original cooViewer are a separate app. See the [README](../../README.en.md#build) for coo2 build instructions.

## Preferences and uninstalling

coo2 stores its preferences in `~/Library/Preferences/io.github.mi-ak.coo2.plist`. The original cooViewer uses a separate identifier, so deleting this file does not delete the original app's preferences.

To uninstall, quit coo2 and delete the app and the preference file above. This file contains keyboard and mouse bindings, bookmarks, history, and settings for individual books. Save a copy before deleting it if you want to keep those settings.

Legacy settings data and file aliases are converted to the current format when loaded. This does not automatically copy the original cooViewer's preferences into coo2. See the [development notes](DEVELOPMENT.md#verification) for implementation details.

## Reporting issues

When reporting a coo2 issue to this fork's maintainer, include:

- The coo2 and macOS versions
- The file format and whether it is password-protected
- The display mode, reading direction, and steps to reproduce the issue
- The expected behavior and the actual behavior

## License and acknowledgments

coo2 is distributed under cooViewer's MIT-style license. See the [full license](../licenses/Licence.txt), which includes coo's copyright notice and permission text. This document is also bundled with the built app.

Thanks to coo for publishing the original design, implementation, and documentation, and to the community for providing feedback from the early stages of development.

Copyright © 2005- coo. All rights reserved.
