#!/usr/bin/env python3
# buffer_wrap.py <in.vhd> <entity> <out.vhd>: ISim leaves VHDL 'buffer' ports undriven when a Verilog module
# instantiates the entity (as modules/sim/mcu/mcu_sim_wrap.py, without generics). Writes the entity renamed to
# <entity>_core and a wrapper <entity> with 'out' ports in place of the 'buffer' ones.
import re
import sys

src, name = open(sys.argv[1]).read(), sys.argv[2]
ent = re.search(r'entity %s is(.*?)end %s;' % (name, name), src, re.S | re.I).group(1)
core = re.sub(r'\bentity %s is' % name, 'entity %s_core is' % name, src, flags=re.I)
core = re.sub(r'\bend %s;' % name, 'end %s_core;' % name, core, flags=re.I)
core = re.sub(r'\barchitecture (\w+) of %s is' % name, r'architecture \1 of %s_core is' % name, core, flags=re.I)
ports = re.findall(r'^\s*(\w+)\s*:\s*(in|out|buffer)\s+([^;\n]*?)(?:\s*:=\s*[^;\n]*)?\s*;?\s*(?:--.*)?$',
                   ent.split('port', 1)[1], re.M | re.I)
bufs = [p for p in ports if p[1].lower() == 'buffer']
wrap = "library ieee;\nuse ieee.std_logic_1164.all;\n\nentity %s is" % name
wrap += re.sub(r'\bbuffer\b', 'out', ent, flags=re.I) + "end %s;\n\narchitecture sim of %s is\n" % (name, name)
for n, d, t in bufs:
    wrap += "\tsignal %s_s : %s;\n" % (n, t.strip())
wrap += "begin\n\tU: entity work.%s_core port map (\n" % name
wrap += ",\n".join("\t\t%s => %s%s" % (n, n, "_s" if d.lower() == 'buffer' else "") for n, d, t in ports)
wrap += "\n\t);\n"
for n, d, t in bufs:
    wrap += "\t%s <= %s_s;\n" % (n, n)
wrap += "end sim;\n"
open(sys.argv[3], "w").write(core + "\n\n" + wrap)
