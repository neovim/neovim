#!/usr/bin/python
# vim: set fileencoding=utf-8:

from __future__ import print_function, unicode_literals, division

from clang.cindex import Index, CursorKind
from collections import namedtuple, OrderedDict, defaultdict
import sys
import os


DECL_KINDS = {
    CursorKind.FUNCTION_DECL,
}


Strip = namedtuple('Strip', 'start_line start_column end_line end_column')


def main(progname, cfname, only_static, move_all):
    cfname = os.path.abspath(os.path.normpath(cfname))

    hfname1 = os.path.splitext(cfname)[0] + os.extsep + 'h'
    hfname2 = os.path.splitext(cfname)[0] + '_defs' + os.extsep + 'h'

    files_to_modify = (cfname, hfname1, hfname2)

    index = Index.create()
    src_dirname = os.path.join(os.path.dirname(__file__), '..', 'src')
    src_dirname = os.path.abspath(os.path.normpath(src_dirname))
    relname = os.path.join(src_dirname, 'nvim')
    unit = index.parse(cfname, args=('-I' + src_dirname,
                                     '-DUNIX',
                                     '-DEXITFREE',
                                     '-DFEAT_USR_CMDS',
                                     '-DFEAT_CMDL_COMPL',
                                     '-DFEAT_COMPL_FUNC',
                                     '-DPROTO',
                                     '-DUSE_MCH_ERRMSG'))
    cursor = unit.cursor

    tostrip = defaultdict(OrderedDict)
    definitions = set()

    for child in cursor.get_children():
        if not (child.location and child.location.file):
            continue
        fname = os.path.abspath(os.path.normpath(child.location.file.name))
        if fname not in files_to_modify:
            continue
        if child.kind not in DECL_KINDS:
            continue
        if only_static and next(child.get_tokens()).spelling == 'static':
            continue

        if child.is_definition() and fname == cfname:
            definitions.add(child.spelling)
        else:
            stripdict = tostrip[fname]
            assert(child.spelling not in stripdict)
            stripdict[child.spelling] = Strip(
                child.extent.start.line,
                child.extent.start.column,
                child.extent.end.line,
                child.extent.end.column,
            )

    for (fname, stripdict) in tostrip.items():
        if not move_all:
            for name in set(stripdict) - definitions:
                stripdict.pop(name)

        if not stripdict:
            continue

        if fname.endswith('.h'):
            is_h_file = True
            include_line = next(reversed(stripdict.values())).start_line + 1
        else:
            is_h_file = False
            include_line = next(iter(stripdict.values())).start_line

        lines = None
        generated_existed = os.path.exists(fname + '.generated.h')
        with open(fname, 'rb') as F:
            lines = list(F)

        stripped = []

        for name, position in reversed(stripdict.items()):
            sl = slice(position.start_line - 1, position.end_line)
            if is_h_file:
                include_line -= sl.stop - sl.start
            stripped += lines[sl]
            lines[sl] = ()

        if not generated_existed:
            lines[include_line:include_line] = [
                '#ifdef INCLUDE_GENERATED_DECLARATIONS\n',
                '# include "{0}.generated.h"\n'.format(
                    os.path.relpath(fname, relname)),
                '#endif\n',
            ]

        with open(fname, 'wb') as F:
            F.writelines(lines)


if __name__ == '__main__':
    progname = sys.argv[0]
    args = sys.argv[1:]
    if not args or '--help' in args:
        print('Usage:')
        print('')
        print('  {0} [--static [--all]] file.c...'.format(progname))
        print('')
        print('Stripts all declarations from file.c, file.h and file_defs.h.')
        print('If --static argument is given then only static declarations are')
        print('stripped. Declarations are stripped only if corresponding')
        print('definition is found unless --all argument was given.')
        print('')
        print('Note: it is assumed that static declarations starts with "static"')
        print('      keyword.')
        sys.exit(0 if args else 1)

    if args[0] == '--static':
        only_static = True
        args = args[1:]
    else:
        only_static = False

    if args[0] == '--all':
        move_all = True
        args = args[1:]
    else:
        move_all = False

    for cfname in args:
        print('Processing {0}'.format(cfname))
        main(progname, cfname, only_static, move_all)
