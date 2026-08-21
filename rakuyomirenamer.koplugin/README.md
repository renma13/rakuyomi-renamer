# Rakuyomi Renamer

Rakuyomi Renamer is a KOReader plugin that renames Rakuyomi-downloaded `.cbz` chapter files using Rakuyomi's cached manga and chapter metadata.

Version 3 moves the real CBZ file from Rakuyomi's hash-based filename to a friendly filename in the same downloads folder, then tries to create a tiny compatibility link at the old hash-based path so Rakuyomi can still find the downloaded chapter.

That means storage use is effectively one CBZ, not two full copies.

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

Open KOReader's main menu and choose `Rakuyomi Renamer`.

## Caveat

Some Kindle storage folders do not support symlinks or hardlinks. If link creation fails, the chapter is still renamed and remains readable as a friendly CBZ, but Rakuyomi may no longer mark that chapter as downloaded until it is downloaded again.
