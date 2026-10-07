"""Parse/serialise CMA Coach 7 files (.cma7/.cmr7) -- reverse engineered."""
import struct, sys

MAGIC_LEN = 16

def parse_items(d, i, end):
    items = []
    while i < end:
        ln, kind = struct.unpack_from('<II', d, i)
        if kind == 0x0b:                      # leaf record
            namelen, flag, typ = d[i+8], d[i+9], d[i+10]
            # namelen may be 16-bit? keep raw bytes
            name = d[i+11:i+11+namelen]
            val = d[i+11+namelen:i+ln]
            items.append(('leaf', name, flag, typ, val))
        elif kind == 0:                       # container
            hdr = d[i+8:i+13]                 # 0e 00 00 00 00
            namelen = d[i+13]
            name = d[i+14:i+14+namelen]
            try:
                kids = parse_items(d, i+14+namelen, i+ln)
            except Exception:
                kids = d[i+14+namelen:i+ln]   # opaque payload
            items.append(('cont', name, hdr, kids))
        else:
            raise ValueError(f'unknown kind {kind:#x} at {i}')
        i += ln
    assert i == end, (i, end)
    return items

def parse(d):
    return d[:MAGIC_LEN], parse_items(d, MAGIC_LEN, len(d))

def ser_items(items):
    out = b''
    for it in items:
        if it[0] == 'leaf':
            _, name, flag, typ, val = it
            body = struct.pack('<I', 0x0b) + bytes([len(name), flag, typ]) + name + val
        else:
            _, name, hdr, kids = it
            payload = kids if isinstance(kids, bytes) else ser_items(kids)
            body = struct.pack('<I', 0) + hdr + bytes([len(name)]) + name + payload
        out += struct.pack('<I', len(body) + 4) + body
    return out

def serialise(magic, items):
    return magic + ser_items(items)

def dump(items, ind=0):
    for it in items:
        if it[0] == 'cont':
            print(' '*ind + f'[{it[1].decode()}]')
            if isinstance(it[3], bytes): print(' '*(ind+2) + 'RAW ' + it[3][:40].hex(' '))
            else: dump(it[3], ind+2)
        else:
            _, name, flag, typ, val = it
            v = val
            if typ == 6: v = val.decode('utf-16-le', 'replace')
            elif typ == 4: v = val.decode('latin-1')
            elif typ == 2: v = struct.unpack('<i', val)[0] if len(val)==4 else val.hex()
            else: v = val.hex()
            s = repr(v)
            print(' '*ind + f'{name.decode()} f{flag} t{typ} = {s[:110]}')

if __name__ == '__main__':
    d = open(sys.argv[1], 'rb').read()
    magic, items = parse(d)
    assert serialise(magic, items) == d, 'roundtrip mismatch'
    print('roundtrip OK', magic.hex(' '))
    if len(sys.argv) > 2: dump(items)
