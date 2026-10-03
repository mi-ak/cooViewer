#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d /private/tmp/cooviewer-test.XXXXXX)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

python3 - "$tmp_dir" <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_STORED
import sys

temporary = Path(sys.argv[1])
with ZipFile(temporary / 'nested.zip', 'w', compression=ZIP_STORED) as archive:
    archive.writestr('pages/first.txt', 'page one')
with ZipFile(temporary / 'traversal.zip', 'w') as archive:
    archive.writestr('../escape.txt', 'escape')
data = (temporary / 'nested.zip').read_bytes()
assert data.count(b'page one') == 1
(temporary / 'corrupt.zip').write_bytes(data.replace(b'page one', b'page two'))
PY

xcrun --sdk macosx clang \
  -I "$root_dir/src/image/archive" \
  "$root_dir/src/image/archive/COArchiveReader.m" \
  "$root_dir/test/archive_reader_test.m" \
  -framework Cocoa -larchive -o "$tmp_dir/archive_reader_test"

mkdir "$tmp_dir/output"
"$tmp_dir/archive_reader_test" "$tmp_dir/nested.zip" "$tmp_dir/traversal.zip" "$tmp_dir/corrupt.zip" "$tmp_dir/output"
echo 'Archive reader tests passed.'

: > "$tmp_dir/book.txt"
xcrun --sdk macosx clang \
  -I "$root_dir/src/preference" \
  -I "$root_dir/src/app/controller" \
  "$root_dir/test/settings_migration_test.m" \
  -framework Cocoa -framework Carbon -o "$tmp_dir/settings_migration_test"
"$tmp_dir/settings_migration_test" "$tmp_dir/book.txt"

xcrun --sdk macosx clang \
  -I "$root_dir/src/extensions" \
  "$root_dir/src/extensions/NSString_Compare.m" \
  "$root_dir/test/string_compare_test.m" \
  -framework Foundation -o "$tmp_dir/string_compare_test"
"$tmp_dir/string_compare_test"
