# Rakuyomi Renamer

Rakuyomi Renamer is a KOReader plugin that exports friendly-named copies of Rakuyomi-downloaded `.cbz` chapter files.

It reads Rakuyomi's own cached metadata through Rakuyomi's backend API, reproduces Rakuyomi's hashed chapter filename, then copies matching downloaded chapters into:

```text
<KOReader data dir>/rakuyomi-renamed/
```

The original files in Rakuyomi's downloads folder are left untouched so Rakuyomi can still recognize downloaded chapters.

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
