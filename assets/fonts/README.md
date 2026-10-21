# Interface typography

The shared interface now uses Barlow Regular for body text and Barlow Condensed
SemiBold for headings, buttons and heavier broadcast text. This is an original
sports-menu pairing inspired by the compact typography requested by the owner;
it is not an EA/FIFA font or a claim of exact font matching.

Unmodified upstream Google Fonts files, downloaded 2026-10-20:

- https://raw.githubusercontent.com/google/fonts/main/ofl/barlow/Barlow-Regular.ttf
- https://raw.githubusercontent.com/google/fonts/main/ofl/barlow/OFL.txt
- https://raw.githubusercontent.com/google/fonts/main/ofl/barlowcondensed/BarlowCondensed-SemiBold.ttf
- https://raw.githubusercontent.com/google/fonts/main/ofl/barlowcondensed/OFL.txt

Both are redistributed under the included SIL Open Font License notices.
The previous DejaVu assets and their original notice remain available.
Keep the font import mode and raw-file export inclusion: the shared loader reads
FontFile.data directly, avoiding the earlier parallel font-import crash.
