# Register a gdb pretty printer for UGrid instances. Usage:
#
# - start gdb
# - run `source contrib/gdb/nvim-gdb-pretty-printers.py`
# - when a `UGrid` pointer can be evaluated in the current frame, just print
#   it's value normally: `p *grid` (assuming `grid` is the variable name
#   holding the pointer)
# - highlighting can be activated by setting the NVIM_GDB_HIGHLIGHT_UGRID
#   environment variable(only xterm-compatible terminals supported). This
#   can be done while gdb is running through the python interface:
#   `python os.environ['NVIM_GDB_HIGHLIGHT_UGRID'] = '1'`
import os
import gdb
import gdb.printing


SGR0 = '\x1b(B\x1b[m'


def get_color_code(bg, color_num):
    if color_num < 16:
        prefix = 3
        if color_num > 7:
            prefix = 9
        if bg:
            prefix += 1
        color_num %= 8
    else:
        prefix = '48;5;' if bg else '38;5;'
    return '\x1b[{0}{1}m'.format(prefix, color_num)


def highlight(attrs):
    fg, bg = [int(attrs['foreground']), int(attrs['background'])]
    rv = [SGR0]  # start with sgr0
    if fg != -1:
        rv.append(get_color_code(False, fg))
    if bg != -1:
        rv.append(get_color_code(True, bg))
    if bool(attrs['bold']):
        rv.append('\x1b[1m')
    if bool(attrs['italic']):
        rv.append('\x1b[3m')
    if bool(attrs['undercurl']) or bool(attrs['underline']):
        rv.append('\x1b[4m')
    if bool(attrs['reverse']):
        rv.append('\x1b[7m')
    return ''.join(rv)


class UGridPrinter(object):
    def __init__(self, val):
        self.val = val

    def to_string(self):
        do_hl = (os.getenv('NVIM_GDB_HIGHLIGHT_UGRID') and
                 os.getenv('NVIM_GDB_HIGHLIGHT_UGRID') != '0')
        grid = self.val
        height = int(grid['height'])
        width = int(grid['width'])
        delimiter = '-' * (width + 2)
        rows = [delimiter]
        for row in range(height):
            cols = []
            if do_hl:
                cols.append(SGR0)
            curhl = None
            for col in range(width):
                cell = grid['cells'][row][col]
                if do_hl:
                    hl = highlight(cell['attrs'])
                    if hl != curhl:
                        cols.append(hl)
                        curhl = hl
                cols.append(cell['data'].string('utf-8'))
            if do_hl:
                cols.append(SGR0)
            rows.append('|' + ''.join(cols) + '|')
        rows.append(delimiter)
        return '\n' + '\n'.join(rows)

    def display_hint(self):
        return 'hint'


def pretty_printers():
    pp = gdb.printing.RegexpCollectionPrettyPrinter('nvim')
    pp.add_printer('UGrid', '^ugrid$', UGridPrinter)
    return pp


gdb.printing.register_pretty_printer(gdb, pretty_printers(), replace=True)
