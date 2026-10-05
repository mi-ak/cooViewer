# coo2 User manual

[English](manual.md) · [日本語](../manual.md)

[Introduction](index.md) · [User manual](manual.md) · [Additional information](other.md) · [Development notes](DEVELOPMENT.md)

This manual describes coo2's default settings. If you have changed the keyboard or mouse bindings, check your current settings under “Input” in Preferences.

## Contents

- [Opening a book](#opening-a-book)
- [Viewer window](#viewer-window)
- [Thumbnail view](#thumbnail-view)
- [Original-size window](#original-size-window)
- [Editing bookmarks](#editing-bookmarks)
- [Loupe and filters](#loupe-and-filters)
- [Preferences](#preferences)
- [Configuring keyboard controls](#configuring-keyboard-controls)
- [Configuring mouse controls](#configuring-mouse-controls)
- [Assignable actions](#assignable-actions)

## Opening a book

Choose “File” → “Open…” (`Command+O`) to select an image, a folder containing images, an archive, or a PDF. You can also drag it onto the coo2 icon. This manual refers to these items as “books.”

Open HEIC photos directly, without converting them to JPEG or another format. WebP still images, animated GIFs, and animated WebP playback are also supported. See the [introduction](index.md#supported-files) for system requirements and common formats.

When you select an image file, coo2 opens the images in the same folder as a book. It does not load neighboring PDFs or archives, so their passwords are not requested. Opening the folder itself also loads the PDFs and archives inside it.

Enable “Read nested folders” in Preferences to include subfolders when opening a folder.

When you open a password-protected PDF or a supported encrypted archive, a password prompt appears. Enter the correct password and click “OK.” Some archive encryption methods cannot be decrypted by the macOS version of `libarchive`.

## Viewer window

The main window displays images and PDF pages.

### Menu shortcuts

| Action | Key |
| --- | --- |
| Open a book | `Command+O` |
| Open the last book and page | `Command+Shift+O` |
| Toggle fullscreen | `Command+F` |
| Fit to Screen | `Command+1` |
| Fit to Screen Width | `Command+2` |
| No Scale | `Command+3` |
| Fit to Screen Width(divide) | `Command+4` |
| Rotate left | `Command+5` |
| Rotate right | `Command+6` |
| Open filters | `Command+Shift+F` |
| Minimize the window | `Command+M` |
| Close the book | `Esc`, `Command+W` |
| Open Preferences | `Command+,` |

While entering a page number, `Esc` cancels the entry.

### Display modes

| Mode | Display behavior |
| --- | --- |
| Fit to Screen (normal mode) | Scales the entire image to fit on the screen. |
| Fit to Screen Width | Scales the image to the screen width. Scroll to read tall pages. |
| No Scale | Displays the image without scaling. Scroll to read areas outside the screen. |
| Fit to Screen Width(divide) | Fits each half of a spread to the screen width. Read by scrolling and moving between pages. |

You can limit enlargement in normal mode using “Max enlargement” in Preferences.

### Keyboard controls in normal mode

The following table assumes right-to-left reading. By default, `Z`/`X`, `←`/`→`, and their `Shift` and `Option` combinations reverse their forward/backward actions when reading left to right. `Space` and `Shift+Space` always move to the next and previous pages, regardless of reading direction.

| Action | Key |
| --- | --- |
| Next page | `Z`, `←`, `Space` |
| Previous page | `X`, `→`, `Shift+Space` |
| Advance one page (shift the spread) | `Shift+Z`, `Shift+←` |
| Go back one page (shift the spread) | `Shift+X`, `Shift+→` |
| Skip ahead 10 pages | `Tab` |
| Go back 10 pages | `Shift+Tab` |
| Jump to 0%–90% through the book | `0`–`9` |
| Enter a page number to jump to | `Return`, numeric keypad `Enter` |
| First page | `Option+X`, `Option+→` |
| Last page | `Option+Z`, `Option+←` |
| Next bookmark | `C`, `↓` |
| Previous bookmark | `D`, `↑` |
| Add/remove a bookmark for the current page | `A` |
| View the left image at original size | `Q` |
| View the right image at original size | `W` |
| Show thumbnails | `T` |
| Toggle single-page/two-page spread | `S` |
| Toggle page information | `P` |
| Toggle the page bar | `O` |
| Start/stop the slideshow | `G` |
| Change reading direction | `R` |
| Toggle the loupe | `L` |
| Next book | `Control+C`, `Control+↓` |
| Previous book | `Control+D`, `Control+↑` |
| Next subfolder/archive | `Control+Shift+C`, `Control+Shift+↓` |
| Previous subfolder/archive | `Control+Shift+D`, `Control+Shift+↑` |

Letter keys are shown in uppercase for readability. You do not need to hold `Shift` unless it is explicitly listed.

You can change the number of pages skipped by `Tab` in the keyboard settings. To jump to a page number, press `Return`, enter the number, and press `Return` again. `Delete` removes one digit, and `Esc` cancels.

`R` cycles through “Right to Left” → “Left to Right” → “Right to Left (single)” → “Left to Right (single).” The next/previous book shortcuts open the destination book at its first page, regardless of the loop setting.

### Keyboard controls in scrolling modes

In Fit to Screen Width mode, the following bindings take priority over normal-mode bindings. No Scale and divided-spread modes use these controls too, with the left and right arrow keys also scrolling horizontally. Other keys inherit the normal-mode bindings.

| Action | Key |
| --- | --- |
| Scroll down one screen; go to the next page at the end | `Space` |
| Scroll up one screen; go to the previous page at the start | `Shift+Space` |
| Scroll up one screen | `Page Up` |
| Scroll down one screen | `Page Down` |
| Scroll to the start of the page | `Home` |
| Scroll to the end of the page | `End` |
| Scroll up | `↑` |
| Scroll down | `↓` |
| Scroll left (No Scale and divided-spread modes) | `←` |
| Scroll right (No Scale and divided-spread modes) | `→` |

If the page also extends beyond the screen horizontally, `Space` moves sideways after reaching the bottom, displaying the next region from the top. `Shift+Space` follows the reverse path.

### Mouse controls

| Action | Right to left | Left to right |
| --- | --- | --- |
| Next page | Click the left half of the screen | Click the right half of the screen |
| Previous page | Click the right half of the screen | Click the left half of the screen |
| Advance one page | `Shift`-click the left half | `Shift`-click the right half |
| Go back one page | `Shift`-click the right half | `Shift`-click the left half |

| Common action | Method |
| --- | --- |
| Jump to a page | Click a position on the page bar |
| Show the menu bar | Move the pointer to the top of the screen in fullscreen mode |
| Show the context menu | Right-click or `Control`-click |
| Next/previous page | Scroll the wheel down/up (normal mode) |
| Toggle the loupe | Click the middle button, such as the wheel button |

In scrolling modes, drag to pan the image. A regular click scrolls up/down one screen and moves to the previous/next page when needed, depending on which half you click and the reading direction. You can change wheel behavior under “Input” → “When you can scroll” in Preferences.

The pointer hides automatically when idle and reappears when you move the mouse.

### Trackpad controls

| Gesture | Default action |
| --- | --- |
| Swipe left/right | Next/previous page; reversed for left-to-right reading |
| Swipe down/up | Next/previous book |
| Pinch out/in | Switch to a display mode that enlarges/reduces the image |
| Rotate clockwise/counterclockwise | Rotate the image right/left |

You can also change gesture bindings in the mouse settings.

### Menus

| Menu | Main items |
| --- | --- |
| coo2 | About coo2, Preferences…, Quit coo2 |
| File | Open a book, Open the last page, Recent Books, Open in Same Folder, close the book |
| Slideshow | Start/stop the slideshow |
| Bookmark | Jump to saved pages, edit bookmarks |
| Setting | Reading direction, sorting, single-page/spread toggle, delete the current book's settings |
| View | Display modes, left/right rotation, filters |
| Window | Toggle fullscreen, minimize the window |

“Open in Same Folder” lists books in the current book's folder, sorted by name. Page sorting options are filename, creation date, modification date, and shuffle. Date sorting is unavailable for books without the required date information.

## Thumbnail view

Press `T` or choose “Show Thumbnail” from the context menu to open the thumbnail view.

| Action | Method |
| --- | --- |
| Change sorting | Choose Name, Creation Date, or Modification Date from the sort menu. This also changes the main view. |
| Next thumbnail screen | A key assigned to next page, wheel down, or the next-screen arrow button |
| Previous thumbnail screen | A key assigned to previous page, wheel up, or the previous-screen arrow button |
| Jump to thumbnail screens 1–10 | `0`–`9` |
| Open a selected page | Click its thumbnail |
| Close | `Esc`, `Command+W`, or the close button |

Preferences let you change the thumbnail row and column counts and choose whether to show thumbnails when opening a book.

## Original-size window

Press `Q`/`W` or choose “View at Original Size” from the context menu to display the left/right image in a separate window.

| Action | Method |
| --- | --- |
| Next/previous page | Keys assigned to next/previous page (`Z`/`X` by default) |
| Scroll down; go to the next page at the end | `Space` |
| Scroll up; go to the previous page at the start | `Shift+Space` |
| Move up, down, left, or right | Arrow keys or drag the image |
| Scroll to the start/end | `Home`/`End` |
| Scroll up/down one screen | `Page Up`/`Page Down` |
| Close | `Esc`, `Command+W`, the close button, or click the window behind it |

In this window, arrow keys scroll instead of turning pages. Enable “Fit original size window to image size” to resize the window when turning pages.

## Editing bookmarks

Press `A` while reading to add a bookmark. Press it again on the same page to remove it. Choose a saved page from the Bookmark menu to jump to it.

### Edit the current book

With a book open, choose “Bookmark” → “Edit Bookmark...” to display the editing sheet.

| Action | Method |
| --- | --- |
| Rename | Double-click the bookmark name and edit it |
| Delete | Select a bookmark and press `Delete`, or choose “Delete this Bookmark” from the context menu |
| Add | Enter a page number in the bottom-left field and click “Add New Bookmark” |

### Edit all books

With no book open, choose “Edit Bookmark...” to display the window for all bookmarks.

| Action | Method |
| --- | --- |
| Open a book | Select it under “BookName” and double-click or click “Open” |
| Show a book in Finder | Select it under “BookName” and click “Show in Finder” |
| Delete all bookmarks for a book | Select it under “BookName” and press `Delete` |
| Edit individual bookmarks | Select a book, then rename, delete, or add bookmarks by page number |

## Loupe and filters

Press `L` or click the middle button to show the loupe and magnify the area near the pointer. Change its size and magnification under “Appearance” in Preferences.

Choose “View” → “Filter” (`Command+Shift+F`) to select filters such as color adjustments, color effects, sharpening, and blur. Adjust each added filter's parameters, and use its close button to remove it.

## Preferences

Choose “coo2” → “Preferences…” (`Command+,`).

### General

| Setting | Description |
| --- | --- |
| Default Book Setting | Set reading direction, single-page display, and sorting. Reading direction also determines which half you click for next/previous pages in single-page mode. |
| Single page | Automatically identify images to display alone based on their width when the height is normalized to 1,000 pixels. |
| Max enlargement | Limit how much small images are enlarged to fit the screen. |
| Slideshow Delay | Set the automatic page-turning interval from 0 to 300 seconds. |
| Read nested folders | Include subfolders when reading a folder. |
| Loop | Choose what happens when you go past the first or last page: loop within the book, move to the next/previous book, do nothing, or another available option. |
| Remember changed book settings | Save each book's reading direction, sorting, and single-page/spread settings. |
| Remember the last page of all books | Save your reading position in each book. |
| Go to the last page when open if remembered | Choose whether to always resume the saved position, ask, or never resume. |
| Number of items in the Open Recent menu | Set how many books appear in “Recent Books.” |
| Open the last book on launch | Choose whether to open the previous book automatically. |

When you launch coo2 with a specified file or archive, it opens that book directly. “Open the last book on launch” applies only when you launch without specifying a file.

Opening a book from “Open the last page” or “Recent Books” resumes the saved reading position.

### Appearance

Adjust the background color; the position, font, text color, background, and border of page information; and the position, size, colors, read portion, and thumbnails of the page bar. You can also configure visibility and automatic hiding of page information and the page bar, plus loupe size and magnification.

This tab also contains thumbnail row and column counts, the option to show thumbnails when opening a book, and “Fit original size window to image size.”

### Input

Change keyboard and mouse bindings in their respective tabs. You can configure bindings for each display mode.

| Setting | Description |
| --- | --- |
| Action when PrevPage with “PageUp + PrevPage” | Choose whether to show the start or end of the previous page when this action turns back a page. |
| Sensitivity | Adjust mouse wheel sensitivity. |
| When you can scroll | Choose regular scrolling, scrolling through horizontal regions as well, scrolling with page turning, or page turning only. |

“Normal Scroll” scrolls vertically. Hold `Shift` to scroll horizontally.

### Advanced

| Setting | Description |
| --- | --- |
| Buffering mode | Choose `Old` or `New`. As noted in the interface, `Old` does not work correctly on Retina displays. |
| Image Interpolation | Set smoothing when scaling images. |
| Cache | Set cache sizes for images, screen rendering, and thumbnails. |
| Use CALayer | Choose GPU-based rendering. If the display appears blurry, try switching this setting. |
| Open PDF links in the default browser | Choose always, ask, or never. |
| Change current folder when the currently open book was moved | Choose how to handle a book that has moved. |
| Disposing of settings | Clean up saved book settings and history. |

## Configuring keyboard controls

1. Open “Input” → “Keyboard” in Preferences.
2. Select the display mode to configure using the mode selector below the table.
3. Click “Add...” and press the key you want to assign, holding `Shift`, `Option`, or `Control` if needed.
4. Select an action from the action menu.
5. For actions with a value, such as skipping pages or scrolling up, enter the amount in the adjacent field.
6. To reverse forward/backward actions according to reading direction, select “Switch to the reverse action in "read from left to right".”
7. Click “OK” to add the binding.

To remove a binding, select its row and click “Delete.” Use “Reset...” to restore defaults. Duplicate key bindings are not detected automatically, so check the table for conflicts.

Normal-mode bindings form the base settings. If another mode has a binding for the same key, that mode's binding takes priority. For example, assigning `Space` to next page in normal mode and to scroll down one screen plus next page in Fit to Screen Width mode makes its behavior depend on the mode.

Divided-spread mode uses the input settings for No Scale mode. coo2 does not support Apple Remote input.

## Configuring mouse controls

1. Open “Input” → “Mouse” in Preferences.
2. Select the display mode to configure using the mode selector below the table.
3. Click “Add...” and select an action from the action menu.
4. Select any modifier keys and specify a button or gesture. For button actions, also choose the event type, such as click or drag.
5. Set any movement amount and whether to reverse the action according to reading direction.
6. Click “OK” to add the binding.

On a typical three-button mouse, `button0` is left, `button1` is right, and `button2` is middle. Swipe, pinch, and rotation gestures are also available.

To remove a binding, select its row and click “Delete.” Use “Reset...” to restore defaults. Check for duplicate combinations. Mode-specific bindings follow the same priority rules as keyboard bindings.

## Assignable actions

### Pages, books, and bookmarks

| Action | Description |
| --- | --- |
| Next/previous page | Turn pages by the displayed unit when viewing spreads. |
| Advance/go back one page | Shift the spread by one page, for example from pages 3–4 to 4–5. |
| First/last page | Jump to the start/end of the book. |
| Skip ahead/back | Move by the configured number of pages. The default `Tab` binding skips 10 pages. |
| Go to a page | Press the assigned key, enter a page number, and press the same key to confirm. |
| Go to a percentage | Jump to the specified percentage through the book. |
| Next/previous bookmark | Jump to the nearest bookmark after/before the current position. |
| Add/remove bookmark | Toggle the current page's bookmark. |
| Next/previous folder or archive | Open the next/previous book in the same folder, sorted by name, at its first page. |
| Next/previous subfolder or archive | Jump to the boundaries of subfolders or archives within the loaded book. |
| Open the last page | Open the previous book and page. |
| Slideshow | Turn pages automatically at the configured interval. |

### Display and book settings

| Action | Description |
| --- | --- |
| Show thumbnails | Open the thumbnail view. |
| View the left/right image at original size | Display the image on the left/right of the screen at original size, regardless of reading direction. |
| Show the left/right image in Finder | Reveal the image's location. For an image inside an archive, reveal the archive file. |
| Move the left/right image to Trash | Move the selected image to Trash. For an image inside an archive, this affects the entire book. |
| Toggle single-page/spread | Change the current page pairing. |
| Change reading direction | Cycle through left-to-right and right-to-left directions and their single-page options. |
| Change sorting/shuffle | Change the order of images in the book. |
| Show page information/page bar | Toggle page information or the bar indicating your reading position. |
| Show loupe/change loupe magnification | Magnify the area near the pointer and adjust the magnification. |
| Rotate left/right | Rotate the displayed image. |
| Change display mode | Cycle through Fit to Screen → Fit to Screen Width → divided spread → No Scale. |
| Enlarge/reduce display mode | Move forward/backward one step through the same sequence. |
| Fullscreen/minimize/close | Control the window. |

When the option to remember book settings is enabled, changes such as reading direction and spread settings are retained for the next time you open the book.

### Scrolling

| Action | Description |
| --- | --- |
| Scroll up/down one screen | Scroll in screen-sized steps. |
| Scroll up/down one screen plus previous/next page | Move vertically, shift to horizontal regions when needed, and turn pages at the start/end of the page. |
| Scroll to the start/end | Move to the start/end of the page. Horizontal position follows the reading direction. |
| Scroll up/down/left/right | Move by the configured amount. The default arrow-key amount is 20. |
| Drag scroll (mouse only) | Pan the image while holding a button. Assign this to a drag event. |

### Mouse-only actions

Combined actions such as next/previous page, advance/go back one page, last/first page, next/previous bookmark, and next/previous folder or archive choose their action based on which half of the screen you use. Forward/backward navigation also follows the reading direction.

Combined left/right actions for original-size viewing, showing an image in Finder, moving it to Trash, and rotation can act on the side you click. You can also assign the context menu to a button.
