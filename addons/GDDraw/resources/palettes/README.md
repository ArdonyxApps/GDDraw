# Bundled starter palettes

Place release-owned `.hex` palettes directly in this folder. GDDraw scans it in
addition to the user's configured palette folder. No starter colors are included
yet; add the selected palettes here before packaging the release.

Use one six-digit RGB or eight-digit RGBA color per line, optionally prefixed with
`#`. The filename supplies the palette name. Keep filenames stable between releases:
they identify bundled entries and per-project Hide choices. Only `.hex` files in
this folder are scanned; documentation and license files are ignored.

Bundled palettes are labeled in the selector. Users can edit their project copy,
but Save creates a separate HEX palette in the configured user folder. Hide removes
the entry from that project's selector without deleting this file. Restore Bundled
Palettes makes hidden entries available again.

Before distributing third-party palettes, verify redistribution permission and add
the author's name, source URL, license, and any required notices alongside the files
(for example, in `ATTRIBUTION.md`). Preserve license texts as separate `.md` or
license files. Do not include a palette whose redistribution terms are unclear.

## Author credits

Fill in `attribution.json` in this folder. It starts with an empty `palettes`
object so no placeholder credits appear in the UI. Use the exact palette filename,
including capitalization and `.hex`, as the key. For example:

```json
{
  "version": 1,
  "palettes": {
    "example-palette.hex": {
      "author": "Artist Name",
      "url": "https://lospec.com/palette-list/example-palette",
      "license": "License name or redistribution permission details"
    }
  }
}
```

Replace the example filename and values with the actual details. Add more entries
inside `palettes`, separated by commas. JSON does not allow comments or trailing
commas. The author is required (maximum 256 characters); URL and license are
optional (maximum 2,048 characters each). URLs must use `https://` or `http://`.
Link to the author's profile or the original palette page. Leave URL out for a
plain-text credit. The complete metadata file must be no larger than 1 MiB.

The panel shows **Palette by Artist Name** beneath the swatches. The author's name
opens the supplied URL only when clicked; license details appear in the footer's
tooltip. Author names are plain text, not BBCode. Missing entries have no footer.
Use **Rescan Palette Folder** after editing the JSON to see changes immediately.
An invalid metadata file reports a warning, preserves existing credits, and does
not prevent valid HEX palettes from loading. Correcting or removing an entry in
a valid metadata file updates the corresponding bundled palette on rescan.

Editing a credited starter displays **Based on a palette by Artist Name**. Saved
user copies retain that credit and license in the project collection, including
after restart and rescan. They remain independent of later bundled metadata
changes. HEX save/export files contain colors only: credit metadata does not
travel with a standalone HEX file. Include attribution separately when sharing.

The `license` field records information; it does not grant redistribution rights
or replace any required full license text. Keep required notices alongside the
palette files as described above.
