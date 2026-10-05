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

objects = [
    b'<< /Type /Catalog /Pages 2 0 R >>',
    b'<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>',
    b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 4 0 R >>',
]
for color in (b'0 0 0 rg', b'1 0 0 rg'):
    stream = color + b' 20 20 160 260 re f\n'
    objects.append(b'<< /Length ' + str(len(stream)).encode() + b' >>\nstream\n' + stream + b'endstream')
    if color == b'0 0 0 rg':
        objects.append(b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 6 0 R >>')
pdf = bytearray(b'%PDF-1.4\n')
offsets = [0]
for number, value in enumerate(objects, 1):
    offsets.append(len(pdf))
    pdf += f'{number} 0 obj\n'.encode() + value + b'\nendobj\n'
xref = len(pdf)
pdf += f'xref\n0 {len(offsets)}\n'.encode() + b'0000000000 65535 f \n'
for offset in offsets[1:]:
    pdf += f'{offset:010d} 00000 n \n'.encode()
pdf += f'trailer\n<< /Root 1 0 R /Size {len(offsets)} >>\nstartxref\n{xref}\n%%EOF\n'.encode()
(temporary / 'pages.pdf').write_bytes(pdf)
(temporary / 'invalid.pdf').write_bytes(b'not a PDF')
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

xcrun --sdk macosx clang -fblocks \
  -I "$root_dir/src/image" \
  -I "$root_dir/src/image/archive" \
  -I "$root_dir/src/image/pdf" \
  -I "$root_dir/src/app/controller" \
  -I "$root_dir/src/extensions" \
  "$root_dir/src/image/COImageLoader.m" \
  "$root_dir/src/image/archive/COArchiveReader.m" \
  "$root_dir/src/image/pdf/COPDFImage.m" \
  "$root_dir/src/image/pdf/COPDFImageRep.m" \
  "$root_dir/src/extensions/NSString_Compare.m" \
  "$root_dir/test/pdf_render_test.m" \
  -framework Cocoa -framework Quartz -framework ImageIO -framework UniformTypeIdentifiers -larchive \
  -o "$tmp_dir/pdf_render_test"
"$tmp_dir/pdf_render_test" "$tmp_dir/pages.pdf" "$tmp_dir/invalid.pdf"

python3 - "$root_dir" "$tmp_dir" <<'PY'
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
temporary = Path(sys.argv[2])
sources = sorted(path for path in (root / 'src').rglob('*.m') if path.name != 'main.m')
includes = sorted({path.parent for path in (root / 'src').rglob('*.h')})
binary = temporary / 'launch_open_test'
command = ['xcrun', '--sdk', 'macosx', 'clang', '-fblocks',
           '-include', str(root / 'src/coo2_Prefix.pch')]
for directory in includes:
    command.extend(['-I', str(directory)])
command.extend(str(path) for path in sources)
command.extend([str(root / 'test/launch_open_test.m'),
                '-framework', 'Cocoa', '-framework', 'Quartz',
                '-framework', 'ImageIO', '-framework', 'UniformTypeIdentifiers',
                '-framework', 'Carbon', '-larchive', '-o', str(binary)])
subprocess.run(command, check=True)
subprocess.run([str(binary)], check=True)
PY
