"""Convert an ASCII (P3) PPM to PNG. Pure stdlib, no dependencies.
Usage:  python ppm2png.py image.ppm [image.png]
"""
import sys, zlib, struct

def read_p3(path):
    with open(path, "rb") as f:
        toks = f.read().split()
    if toks[0] != b"P3":
        raise ValueError("not a P3 (ASCII) PPM")
    w, h, maxv = int(toks[1]), int(toks[2]), int(toks[3])
    vals = toks[4:]
    if len(vals) != w * h * 3:
        raise ValueError(f"expected {w*h*3} samples, got {len(vals)}")
    data = bytes(min(255, int(v) * 255 // maxv) for v in vals)  # scale to 8-bit
    return w, h, data

def write_png(path, w, h, rgb):
    def chunk(typ, data):
        return (struct.pack(">I", len(data)) + typ + data +
                struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff))
    stride = w * 3
    raw = bytearray()
    for y in range(h):
        raw.append(0)                       # filter type 0 (none) per scanline
        raw += rgb[y*stride:(y+1)*stride]
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))

if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "image.ppm"
    dst = sys.argv[2] if len(sys.argv) > 2 else src.rsplit(".", 1)[0] + ".png"
    w, h, data = read_p3(src)
    write_png(dst, w, h, data)
    print(f"{src} -> {dst}  ({w}x{h})")
