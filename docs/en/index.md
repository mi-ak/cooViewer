# coo2 — Read comics comfortably

[English](index.md) · [日本語](../index.md)

[Introduction](index.md) · [User manual](manual.md) · [Additional information](other.md) · [Development notes](DEVELOPMENT.md)

coo2 is an image and comic archive viewer for macOS, designed for reading comics, photo books, and similar collections. Open an image folder, archive, or PDF as a “book” and read it as single pages or two-page spreads.

**coo2 is a fork of [cooViewer](https://github.com/coo-ona/cooViewer) by coo. It is not an official release by the original author.** This documentation describes coo2's controls and system requirements.

## System requirements

- A Mac with Apple Silicon (arm64)
- macOS 15 or later
- The full Xcode installation, if building from source

See the [README](../../README.en.md#build) for build instructions.

## Supported files

| Type | Common formats |
| --- | --- |
| Images and image folders | HEIC, JPEG, PNG, GIF, TIFF, BMP, AVIF, WebP, and others |
| Comic archives | ZIP/CBZ, RAR/CBR, 7z, LHA/LZH, and others |
| Other archives | TAR, gzip, bzip2, XZ, CAB, CPIO, PAX, XAR, ar, and others |
| PDF | Multipage and password-protected PDFs |

In addition to WebP still images, coo2 supports animated GIF and animated WebP playback.

Image and archive support depends on the formats supported by macOS and the compression or encryption method used. Password-protected archives are supported when the macOS version of `libarchive` can decrypt them.

## Features

### Open HEIC photos without conversion

View HEIC photos directly, without converting them to JPEG or another format. You can also read HEIC images inside folders and archives, using page navigation and thumbnails just as you would with other images.

### Choose how you turn pages

Read from right to left or left to right, with single-page options for either direction. Switch between fitting the whole image to the screen, fitting to the screen width, viewing at original size, and splitting a spread into separate halves.

Customize keyboard, mouse, and trackpad controls. You can assign multiple keys to the same action and use different bindings for each display mode.

### Find the page you want

Use thumbnails, the page bar, or direct page-number entry to jump to a page. By default, `0`–`9` jump to positions from 0% to 90% through the book, and `Tab` skips ahead 10 pages.

Press `A` to bookmark a favorite page. Press it again on the same page to remove the bookmark. You can give bookmarks names.

### Continue where you left off

Remember the last book, your reading position in each book, and each book's reading direction and spread settings. Resume from “Recent Books” or “Open the last page,” or reopen the previous book at launch.

### Adjust the display

Use the loupe, original-size view, rotation, and filters such as color adjustment and sharpening. Preferences also let you change the background color, page information and page bar colors and positions, and thumbnail row and column counts.

### Browse automatically

Set the slideshow interval and choose what happens at the end of a book. You can also move between books in the same folder.

## Getting started

1. Launch coo2.
2. Choose “File” → “Open…” (`Command+O`) and select an image, image folder, archive, or PDF. You can also drag it onto the coo2 icon.
3. With the default right-to-left reading direction, press `Space`, `Z`, or `←`, or click the left half of the screen, to advance to the next page.

See the [user manual](manual.md) for details. The [additional information](other.md) page covers the license and preference files.
