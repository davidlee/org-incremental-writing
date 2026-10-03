# ASM-001: Source file names are unique across configured sources

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->

Accepted limitation, user ruling during SL-003 design (2026-10-03, inq-5).
The queue view's File column shows the file name without its directory, so
two same-named files in different source directories look alike there. The
user's corpus has unique file names (Denote), and handling non-unique names
is not a priority. Revisit if a user reports same-named files; the fix is a
path relative to the source directory in the File column.
