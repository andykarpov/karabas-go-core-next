#!/usr/bin/env python3
# pcf_modes.py <in.pcf> <out.pcf> <system_pll .v> <mode>: the constraints of a routed build for another mode of the
# clocks, for the trce runs of `make <board>-modes`. ngdbuild derives the PERIODs of system_pll from the static
# attributes of its PLL_ADV (VGA-0); the DRP logic reprograms it for the other VGA modes.
#   vga<n>     the PERIODs (and the 180 degree phases) of the PLL outputs with the S<n> values of the .v file;
#              the clocks derived from them (hdmi_pll, the MIDI DCM) follow, as they do on the board.
#   cpu        the CPU flip-flops (TG_CLK_CPU) on cpu_clk_s, the BUFGMUX input I0 of CLK_CPU made by a flip-flop on
#              CLK_28 (3.5 / 7 / 14 MHz): taken out of the group of CLK_28 (BUFGMUX input I1, the 28 MHz mode) and
#              given the PERIOD of 14 MHz, the fastest of these, with the edges of CLK_28. The clock of I0 comes
#              later than that of I1 (the clock to output of cpu_clk_s and its route to the BUFGMUX, 2.5 to 4.7 ns):
#              trce cannot add a delay to a derived clock (a PHASE moves the launch edge to the edge of CLK_28 just
#              before; INPUT_JITTER is not used on a PLL output), so a path CLK_28 -> CPU with less hold slack than
#              that is a race in these modes (see the ucf).
import re
import sys

src, dst, pllv, mode = sys.argv[1:5]
text = open(src).read()

# the derived PERIOD constraints of the PLL outputs: TS_<prefix>_clk<k>_bufgin, but output 0, which also drives
# the BUFGMUX of the cpu clock, is named after the net of the top, CLK_28_pll
ts_re = re.compile(r'(TS_(\w*CLKSYS_PLL\w*_clk(\d)_bufgin|CLK_28_pll()) = PERIOD TIMEGRP\s+"[^"]+"\s+)'
                   r'TS_CLK_50MHZ\s*/\s*[\d.]+(?:\s+PHASE\s+[\d.]+\s+ns)?(\s+HIGH\s+50%;)')
found = ts_re.findall(text)
if len(found) != 5:
    sys.exit('pcf_modes.py: %d PERIODs of system_pll in %s, expected 5' % (len(found), src))

if mode.startswith('vga'):
    n = int(mode[3:])
    v = open(pllv).read()

    def attr(name):
        m = re.search(r'\.S%d_%s\((\d+)\)' % (n, name), v)
        if not m:
            sys.exit('pcf_modes.py: S%d_%s not in %s' % (n, name, pllv))
        return int(m.group(1))

    mult, div = attr('CLKFBOUT_MULT'), attr('DIVCLK_DIVIDE')

    def sub(m):
        k = int(m.group(3) or 0)
        odiv = attr('CLKOUT%d_DIVIDE' % k)
        phase = attr('CLKOUT%d_PHASE' % k) / 1000.0
        factor = mult / (div * odiv)
        period = 20.0 / factor
        ph = '' if phase == 0 else ' PHASE %.7g ns' % (period * phase / 360.0)
        return '%sTS_CLK_50MHZ / %.9g%s%s' % (m.group(1), factor, ph, m.group(5))

    text = ts_re.sub(sub, text)
    print('pcf_modes.py: VGA-%d, VCO %g MHz, CLK_28 %.4f MHz' % (n, 50.0 * mult / div,
          50.0 * mult / div / attr('CLKOUT0_DIVIDE')))
elif mode == 'cpu':
    clk0 = 'CLK_28_pll'

    def group(name):
        m = re.search(r'^TIMEGRP %s = (.*?);\n' % re.escape(name), text, re.M | re.S)
        if not m:
            sys.exit('pcf_modes.py: TIMEGRP %s not in %s' % (name, src))
        return m

    cpu = set(re.findall(r'(?:BEL|PIN) "[^"]+"', group('TG_CLK_CPU').group(1)))
    g = group(clk0)
    members = re.findall(r'(?:BEL|PIN) "[^"]+"', g.group(1))
    kept = [x for x in members if x not in cpu]
    if len(kept) == len(members) or not cpu:
        sys.exit('pcf_modes.py: the CPU flip-flops are not in %s' % clk0)
    text = text[:g.start()] + 'TIMEGRP %s = %s;\n' % (clk0, ' '.join(kept)) + text[g.end():]
    text = text.replace('SCHEMATIC END;', 'TS_CPU_SLOW = PERIOD TIMEGRP "TG_CLK_CPU" TS_CLK_28_pll * 2 HIGH 50%;\n'
                        'SCHEMATIC END;', 1)
    if 'TS_CPU_SLOW' not in text:
        sys.exit('pcf_modes.py: no SCHEMATIC END in ' + src)
    print('pcf_modes.py: %d CPU flip-flops on cpu_clk_s at 14 MHz' % (len(members) - len(kept)))
else:
    sys.exit('pcf_modes.py: unknown mode ' + mode)

open(dst, 'w').write(text)
