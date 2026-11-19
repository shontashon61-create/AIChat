import os, struct, zlib, zipfile, pathlib

def chunk(t, data):
    return struct.pack('>I', len(data)) + t + data + struct.pack('>I', zlib.crc32(t + data) & 0xffffffff)

def write_png(path, size):
    raw = b''
    scale = 1024 / size
    for y in range(size):
        t = y / (size - 1) if size > 1 else 0
        r0 = int(124 + (37 - 124) * t)
        g0 = int(58 + (99 - 58) * t)
        b0 = int(237 + (235 - 237) * t)
        row = bytearray([0])
        Y = y * scale
        for x in range(size):
            X = x * scale
            r, g, b = r0, g0, b0
            if 220 <= X <= 804 and 300 <= Y <= 680:
                inside = True
                if X < 310 and Y < 390:
                    inside = (X - 310) ** 2 + (Y - 390) ** 2 <= 90 ** 2
                elif X > 714 and Y < 390:
                    inside = (X - 714) ** 2 + (Y - 390) ** 2 <= 90 ** 2
                elif X < 310 and Y > 590:
                    inside = (X - 310) ** 2 + (Y - 590) ** 2 <= 90 ** 2
                elif X > 714 and Y > 590:
                    inside = (X - 714) ** 2 + (Y - 590) ** 2 <= 90 ** 2
                if inside:
                    r, g, b = 255, 255, 255
            for cx, cy in [(360, 490), (512, 490), (664, 490)]:
                if (X - cx) ** 2 + (Y - cy) ** 2 <= 42 ** 2:
                    r, g, b = 124, 58, 237
            row.extend([r, g, b, 255])
        raw += bytes(row)
    ihdr = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)
    print(path, size, len(png))

outdir = os.path.join('AIChat', 'Assets.xcassets', 'AppIcon.appiconset')
os.makedirs(outdir, exist_ok=True)
for name, s in {'icon-1024': 1024, 'icon-180': 180, 'icon-120': 120, 'icon-87': 87, 'icon-80': 80, 'icon-60': 60, 'icon-58': 58, 'icon-40': 40}.items():
    write_png(os.path.join(outdir, name + '.png'), s)
print('icons done')
root = pathlib.Path('.').resolve()
backup = root.parent / 'AIChat-backup-2026-11-19.zip'
with zipfile.ZipFile(backup, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in root.rglob('*'):
        if '.easycode' in p.parts or '.git' in p.parts:
            continue
        if p.is_file():
            z.write(p, p.relative_to(root))
print('backup:', str(backup), backup.stat().st_size)
