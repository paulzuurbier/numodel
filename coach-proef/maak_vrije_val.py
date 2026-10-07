"""Proof of concept: write vrije-val.cma7/.cmr7 and vrije-val-vast.cma7.

Run from the repository root:  python3 coach-proef/maak_vrije_val.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cma, make_textmodel as mt

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, '..', '0. Leeg model tekst.cmr7')

body = """v := v + g*dt
y := y + v*dt
t := t + dt
Als y <= 2 Dan Stop EindAls
"""
init = """t := 0       's
dt := 0,05   's
v := 0       'm/s
y := 100     'm
g := -9,81   'm/s^2
"""
variables = [('t', 's', 0, 5, 2), ('dt', 's', 0, 1, 2), ('v', 'm/s', -50, 0, 3),
             ('y', 'm', 0, 100, 3), ('g', 'm/s^2', -10, 0, 3)]

data = mt.build(TEMPLATE, body, init, variables, {'stop': '10', 'step': '0,05'})
for ext in ('cmr7', 'cma7'):
    open(os.path.join(HERE, f'vrije-val.{ext}'), 'wb').write(data)

# Same model, but with switching to the graphical view disabled.
magic, items = cma.parse(data)
desc = items[0][3]                      # [Description] container
for k, it in enumerate(desc):
    if it[1] == b'CanSwitchModelModes':
        desc[k] = ('leaf', it[1], it[2], it[3], b'\x00')
open(os.path.join(HERE, 'vrije-val-vast.cma7'), 'wb').write(cma.serialise(magic, items))
print('ok')
