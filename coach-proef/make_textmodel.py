"""Build a Coach 7 text model from the empty text-model template."""
import sys, struct, math
sys.path.insert(0, sys.path[0])  # allow running from this folder
import cma

def ext80(x):
    """Encode float as 80-bit x87 extended (little endian)."""
    if x == 0: return bytes(10)
    sign = 0x8000 if x < 0 else 0
    m, e = math.frexp(abs(x))            # x = m * 2**e, 0.5 <= m < 1
    mant = int(m * (1 << 64))            # explicit integer bit at bit 63
    return struct.pack('<QH', mant, sign | (e - 1 + 16383))

def leaf(name, typ, val, flag=0):
    return ('leaf', name.encode(), flag, typ, val)

def text_pair(name, s):
    """ANSI + _uuuu UTF-16 leaves (both kinds as Coach writes them)."""
    a = s.encode('cp1252', 'replace')
    u = s.encode('utf-16-le')
    if name == '':  # long-text form (flag 1, 4-byte prefix) used for model text
        return [leaf('', 4, b'\0'*4 + a, 1), leaf('_uuuu', 6, b'\0'*4 + u, 1)]
    return [leaf(name, 4, a), leaf(name + '_uuuu', 6, u)]

def find(items, name):
    for it in items:
        if it[0] == 'cont' and it[1] == name.encode(): return it
    raise KeyError(name)

def replace(items, name, kids):
    for k, it in enumerate(items):
        if it[0] == 'cont' and it[1] == name.encode():
            items[k] = ('cont', it[1], it[2], kids); return
    raise KeyError(name)

def build(template, body, init, variables, xml_settings=None):
    magic, items = cma.parse(open(template, 'rb').read())
    replace(items, 'ModelBody', text_pair('', body))
    replace(items, 'ModelInit', text_pair('', init))
    vl = [leaf('Number', 2, struct.pack('<i', len(variables)))]
    for n, (name, unit, lo, hi, dec) in enumerate(variables, 1):
        vl += text_pair(f'Name{n}', name) + text_pair(f'Label{n}', name)
        vl += text_pair(f'Unit{n}', unit)
        vl += [leaf(f'Min{n}', 3, ext80(lo)), leaf(f'Max{n}', 3, ext80(hi)),
               leaf(f'Decimals{n}', 0, bytes([dec]))]
    replace(items, 'VarList', vl)
    if xml_settings:
        xmlc = find(items, 'ModelXML')
        a, u = xmlc[3]
        x = a[4][4:].decode('cp1252')
        for tag, val in xml_settings.items():
            i = x.index(f'<{tag}>') + len(tag) + 2; j = x.index(f'</{tag}>', i)
            x = x[:i] + val + x[j:]
        replace(items, 'ModelXML',
                [leaf('', 4, b'\0'*4 + x.encode('cp1252'), 1),
                 leaf('_uuuu', 6, b'\0'*4 + x.encode('utf-16-le'), 1)])
    return cma.serialise(magic, items)

# sanity: ext80 matches Coach's encoding of 10 and 0
assert ext80(10).hex() == '00000000000000a00240', ext80(10).hex()
