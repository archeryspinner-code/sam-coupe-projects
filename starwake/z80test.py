import re
import z80

LOAD_ADDR = 0x8000
STACK_TOP = 0xEF00
HALT_ADDR = 0x7000   # safe: above all screen memory (0x0000-0x5FFF), below LOAD_ADDR

LST_FILE = 'starwake.lst'
BIN_FILE = 'starwake.bin'


def load_symbols(lst_file=LST_FILE):
    sym = {}
    pat = re.compile(r'^(\w+)\s+EQU\s+0?([0-9A-Fa-f]+)H', re.MULTILINE)
    with open(lst_file) as f:
        text = f.read()
    for name, hexval in pat.findall(text):
        sym[name] = int(hexval, 16)
    return sym


def load_binary(bin_file=BIN_FILE):
    with open(bin_file, 'rb') as f:
        return f.read()


def fresh_machine(binary):
    m = z80.Z80Machine()
    m.memory[LOAD_ADDR:LOAD_ADDR + len(binary)] = binary
    m.sp = STACK_TOP
    return m


def call(m, addr, max_runs=2000, halt_addr=HALT_ADDR):
    m.memory[halt_addr] = 0x76  # HALT
    m.sp = STACK_TOP - 2
    m.memory[m.sp] = halt_addr & 0xFF
    m.memory[m.sp + 1] = (halt_addr >> 8) & 0xFF
    m.pc = addr
    for i in range(max_runs):
        m.run()
        if m.halted:
            m.halted = False
            return None
    return f"TIMEOUT pc={hex(m.pc)}"
