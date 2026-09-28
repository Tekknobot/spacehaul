MAGO FONT NOTE

The UI font is explicitly bound to res://Fonts/mago1.ttf for desktop and Web exports.
Do not replace it with a SystemFont or runtime directory scan; browser exports may fall
back to the browser/system default font when the custom font is not an explicit resource dependency.

UI scale used by this build:
- 64 px: generated body / planet title
- 32 px: body type and major section headings
- 16 px: metadata, scan text, buttons, catalog entries, hints
