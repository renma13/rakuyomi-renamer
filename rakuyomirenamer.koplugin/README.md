# Rakuyomi Renamer

Rakuyomi Renamer is a KOReader plugin that renames Rakuyomi-downloaded `.cbz` chapter files using Rakuyomi's cached manga and chapter metadata. It can also set a custom KOReader cover from the page currently visible in the reader.

Version 3 moves the real CBZ file from Rakuyomi's hash-based filename to a friendly filename in the same downloads folder, then tries to create a tiny compatibility link at the old hash-based path so Rakuyomi can still find the downloaded chapter.

That means storage use is effectively one CBZ, not two full copies.

Version 8 changes the cover workflow to avoid crashes on Kindle and avoid hidden menu items:

```text
Open to pick cover page
Use this page
```

Long-press a CBZ and choose `Open to pick cover page`. KOReader opens the chapter normally and enters cover-picking mode. A prompt appears on each page with `Use this page`, `Keep looking`, and `Cancel`.

Choose `Keep looking`, flip to the next candidate page, then use the prompt when the correct cover is visible. This saves a screenshot of the currently visible page as KOReader's custom cover for that book. The CBZ itself is not rewritten.

## Filename Format

When volume metadata is available:

```text
Series - Vol. 1 - Ch. 4 - Chapter Title.cbz
```

When volume metadata is missing:

```text
Series - Ch. 4 - Chapter Title.cbz
```

## Installation

Copy `rakuyomi-renamer.koplugin` into KOReader's `plugins` folder next to `rakuyomi.koplugin`, then restart KOReader.

Open KOReader's main menu and choose `Rakuyomi Renamer` to rename Rakuyomi downloads.

To set a cover, long-press a `.cbz` file in KOReader or Bookshelf and choose `Open to pick cover page`. Use the prompt that appears while reading.

## Caveat

Some Kindle storage folders do not support symlinks or hardlinks. If link creation fails, the chapter is still renamed and remains readable as a friendly CBZ, but Rakuyomi may no longer mark that chapter as downloaded until it is downloaded again.

The cover picker no longer tries to render hidden pages from the file dialog. That approach caused crashes on Kindle. Version 6 uses the already-open reader screen instead, which is slower by a few taps but much safer.
