#!/usr/bin/env python3

r"""Generates Nvim :help docs from C/Lua docstrings, using Doxygen.

Also generates *.mpack files. To inspect the *.mpack structure:
    :new | put=v:lua.vim.inspect(v:lua.vim.mpack.decode(readfile('runtime/doc/api.mpack','B')))

Flow:
    main
      extract_from_xml
        fmt_node_as_vimhelp   \
          para_as_map          } recursive
            update_params_map /
              render_node

TODO: eliminate this script and use Lua+treesitter (requires parsers for C and
Lua markdown-style docstrings).

The generated :help text for each function is formatted as follows:

  - Max width of 78 columns (`text_width`).
  - Indent with spaces (not tabs).
  - Indent of 4 columns for body text (`indentation`).
  - Function signature and helptag (right-aligned) on the same line.
    - Signature and helptag must have a minimum of 8 spaces between them.
    - If the signature is too long, it is placed on the line after the helptag.
      Signature wraps at `text_width - 8` characters with subsequent
      lines indented to the open parenthesis.
    - Subsection bodies are indented an additional 4 spaces.
  - Body consists of function description, parameters, return description, and
    C declaration (`INCLUDE_C_DECL`).
  - Parameters are omitted for the `void` and `Error *` types, or if the
    parameter is marked as [out].
  - Each function documentation is separated by a single line.
"""

from __future__ import annotations  # PEP-563, python 3.7+

import argparse
import collections
import dataclasses
import logging
import os
import re
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path
from typing import Any, Callable, Dict, List, Tuple
from xml.dom import minidom

if sys.version_info >= (3, 8):
    from typing import Literal

import msgpack

Element = minidom.Element
Document = minidom.Document

MIN_PYTHON_VERSION = (3, 7)
MIN_DOXYGEN_VERSION = (1, 9, 0)

if sys.version_info < MIN_PYTHON_VERSION:
    print("requires Python {}.{}+".format(*MIN_PYTHON_VERSION))
    sys.exit(1)

doxygen_version = tuple((int(i) for i in subprocess.check_output(["doxygen", "-v"],
                        universal_newlines=True).split()[0].split('.')))

if doxygen_version < MIN_DOXYGEN_VERSION:
    print("\nRequires doxygen {}.{}.{}+".format(*MIN_DOXYGEN_VERSION))
    print("Your doxygen version is {}.{}.{}\n".format(*doxygen_version))
    sys.exit(1)


# Need a `nvim` that supports `-l`, try the local build
nvim_path = Path(__file__).parent / "../build/bin/nvim"
if nvim_path.exists():
    nvim = nvim_path.resolve()
else:
    # Until 0.9 is released, use this hacky way to check that "nvim -l foo.lua" works.
    nvim_out = subprocess.check_output(['nvim', '-h'], universal_newlines=True)
    nvim_version = [line for line in nvim_out.split('\n')
                    if '-l ' in line]
    if len(nvim_version) == 0:
        print((
            "\nYou need to have a local Neovim build or a `nvim` version 0.9 for `-l` "
            "support to build the documentation."))
        sys.exit(1)
    nvim = 'nvim'


# DEBUG = ('DEBUG' in os.environ)
INCLUDE_C_DECL = os.environ.get('INCLUDE_C_DECL', '0') != '0'
INCLUDE_DEPRECATED = os.environ.get('INCLUDE_DEPRECATED', '0') != '0'

log = logging.getLogger(__name__)

LOG_LEVELS = {
    logging.getLevelName(level): level for level in [
        logging.DEBUG, logging.INFO, logging.ERROR
    ]
}

text_width = 78
indentation = 4
SECTION_SEP = '=' * text_width

script_path = os.path.abspath(__file__)
base_dir = os.path.dirname(os.path.dirname(script_path))
out_dir = os.path.join(base_dir, 'tmp-{target}-doc')
filter_cmd = '%s %s' % (sys.executable, script_path)
msgs = []  # Messages to show on exit.
lua2dox = os.path.join(base_dir, 'scripts', 'lua2dox.lua')


SectionName = str

Docstring = str  # Represents (formatted) vimdoc string

FunctionName = str


@dataclasses.dataclass
class Config:
    """Config for documentation."""

    mode: Literal['c', 'lua']

    filename: str
    """Generated documentation target, e.g. api.txt"""

    section_order: List[str]
    """Section ordering."""

    files: List[str]
    """List of files/directories for doxygen to read, relative to `base_dir`."""

    file_patterns: str
    """file patterns used by doxygen."""

    section_name: Dict[str, SectionName]
    """Section name overrides. Key: filename (e.g., vim.c)"""

    section_fmt: Callable[[SectionName], str]
    """For generated section names."""

    helptag_fmt: Callable[[SectionName], str]
    """Section helptag."""

    fn_helptag_fmt: Callable[[str, str, bool], str]
    """Per-function helptag."""

    module_override: Dict[str, str]
    """Module name overrides (for Lua)."""

    append_only: List[str]
    """Append the docs for these modules, do not start a new section."""

    fn_name_prefix: str
    """Only function with this prefix are considered"""

    fn_name_fmt: Callable[[str, str], str] | None = None

    include_tables: bool = True


CONFIG: Dict[str, Config] = {
    'api': Config(
        mode='c',
        filename = 'api.txt',
        # Section ordering.
        section_order=[x for x in [
            'vim.c',
            'vimscript.c',
            'command.c',
            'options.c',
            'buffer.c',
            'extmark.c',
            'window.c',
            'win_config.c',
            'tabpage.c',
            'autocmd.c',
            'ui.c',
            'deprecated.c' if INCLUDE_DEPRECATED else ''
        ] if x],
        files=['src/nvim/api'],
        file_patterns = '*.h *.c',
        fn_name_prefix = 'nvim_',
        section_name={
            'vim.c': 'Global',
        },
        section_fmt=lambda name: f'{name} Functions',
        helptag_fmt=lambda name: f'*api-{name.lower()}*',
        fn_helptag_fmt=lambda fstem, name, istbl: f'*{name}()*',
        module_override={},
        append_only=[],
    ),
    'lua': Config(
        mode='lua',
        filename='lua.txt',
        section_order=[
            'highlight.lua',
            'diff.lua',
            'mpack.lua',
            'json.lua',
            'base64.lua',
            'spell.lua',
            'builtin.lua',
            '_options.lua',
            '_editor.lua',
            '_inspector.lua',
            'shared.lua',
            'loader.lua',
            'uri.lua',
            'ui.lua',
            'filetype.lua',
            'keymap.lua',
            'fs.lua',
            'glob.lua',
            'lpeg.lua',
            're.lua',
            'regex.lua',
            'secure.lua',
            'version.lua',
            'iter.lua',
            'snippet.lua',
            'text.lua',
        ],
        files=[
            'runtime/lua/vim/iter.lua',
            'runtime/lua/vim/_editor.lua',
            'runtime/lua/vim/_options.lua',
            'runtime/lua/vim/shared.lua',
            'runtime/lua/vim/loader.lua',
            'runtime/lua/vim/uri.lua',
            'runtime/lua/vim/ui.lua',
            'runtime/lua/vim/filetype.lua',
            'runtime/lua/vim/keymap.lua',
            'runtime/lua/vim/fs.lua',
            'runtime/lua/vim/highlight.lua',
            'runtime/lua/vim/secure.lua',
            'runtime/lua/vim/version.lua',
            'runtime/lua/vim/_inspector.lua',
            'runtime/lua/vim/snippet.lua',
            'runtime/lua/vim/text.lua',
            'runtime/lua/vim/glob.lua',
            'runtime/lua/vim/_meta/builtin.lua',
            'runtime/lua/vim/_meta/diff.lua',
            'runtime/lua/vim/_meta/mpack.lua',
            'runtime/lua/vim/_meta/json.lua',
            'runtime/lua/vim/_meta/base64.lua',
            'runtime/lua/vim/_meta/regex.lua',
            'runtime/lua/vim/_meta/lpeg.lua',
            'runtime/lua/vim/_meta/re.lua',
            'runtime/lua/vim/_meta/spell.lua',
        ],
        file_patterns='*.lua',
        fn_name_prefix='',
        fn_name_fmt=lambda fstem, name: (
            name if fstem in [ 'vim.iter' ] else
            f'vim.{name}' if fstem in [ '_editor', 'vim.regex'] else
            f'vim.{name}' if fstem == '_options' and not name[0].isupper() else
            f'{fstem}.{name}' if fstem.startswith('vim') else
            name
        ),
        section_name={
            'lsp.lua': 'core',
            '_inspector.lua': 'inspector',
        },
        section_fmt=lambda name: (
            'Lua module: vim' if name.lower() == '_editor' else
            'LUA-VIMSCRIPT BRIDGE' if name.lower() == '_options' else
            f'VIM.{name.upper()}' if name.lower() in [
                'highlight', 'mpack', 'json', 'base64', 'diff', 'spell',
                'regex', 'lpeg', 're',
            ] else
            'VIM' if name.lower() == 'builtin' else
            f'Lua module: vim.{name.lower()}'),
        helptag_fmt=lambda name: (
            '*lua-vim*' if name.lower() == '_editor' else
            '*lua-vimscript*' if name.lower() == '_options' else
            f'*vim.{name.lower()}*'),
        fn_helptag_fmt=lambda fstem, name, istbl: (
            f'*vim.opt:{name.split(":")[-1]}()*' if ':' in name and name.startswith('Option') else
            # Exclude fstem for methods
            f'*{name}()*' if ':' in name else
            f'*vim.{name}()*' if fstem.lower() == '_editor' else
            f'*vim.{name}*' if fstem.lower() == '_options' and istbl else
            # Prevents vim.regex.regex
            f'*{fstem}()*' if fstem.endswith('.' + name) else
            f'*{fstem}.{name}{"" if istbl else "()"}*'
            ),
        module_override={
            # `shared` functions are exposed on the `vim` module.
            'shared': 'vim',
            '_inspector': 'vim',
            'uri': 'vim',
            'ui': 'vim.ui',
            'loader': 'vim.loader',
            'filetype': 'vim.filetype',
            'keymap': 'vim.keymap',
            'fs': 'vim.fs',
            'highlight': 'vim.highlight',
            'secure': 'vim.secure',
            'version': 'vim.version',
            'iter': 'vim.iter',
            'diff': 'vim',
            'builtin': 'vim',
            'mpack': 'vim.mpack',
            'json': 'vim.json',
            'base64': 'vim.base64',
            'regex': 'vim.regex',
            'lpeg': 'vim.lpeg',
            're': 'vim.re',
            'spell': 'vim.spell',
            'snippet': 'vim.snippet',
            'text': 'vim.text',
            'glob': 'vim.glob',
        },
        append_only=[
            'shared.lua',
        ],
    ),
    'lsp': Config(
        mode='lua',
        filename='lsp.txt',
        section_order=[
            'lsp.lua',
            'buf.lua',
            'diagnostic.lua',
            'codelens.lua',
            'inlay_hint.lua',
            'tagfunc.lua',
            'semantic_tokens.lua',
            'handlers.lua',
            'util.lua',
            'log.lua',
            'rpc.lua',
            'protocol.lua',
        ],
        files=[
            'runtime/lua/vim/lsp',
            'runtime/lua/vim/lsp.lua',
        ],
        file_patterns='*.lua',
        fn_name_prefix='',
        section_name={'lsp.lua': 'lsp'},
        section_fmt=lambda name: (
            'Lua module: vim.lsp'
            if name.lower() == 'lsp'
            else f'Lua module: vim.lsp.{name.lower()}'),
        helptag_fmt=lambda name: (
            '*lsp-core*'
            if name.lower() == 'lsp'
            else f'*lsp-{name.lower()}*'),
        fn_helptag_fmt=lambda fstem, name, istbl: (
            f'*vim.lsp.{name}{"" if istbl else "()"}*' if fstem == 'lsp' and name != 'client' else
            # HACK. TODO(justinmk): class/structure support in lua2dox
            '*vim.lsp.client*' if 'lsp.client' == f'{fstem}.{name}' else
            f'*vim.lsp.{fstem}.{name}{"" if istbl else "()"}*'),
        module_override={},
        append_only=[],
    ),
    'diagnostic': Config(
        mode='lua',
        filename='diagnostic.txt',
        section_order=[
            'diagnostic.lua',
        ],
        files=['runtime/lua/vim/diagnostic.lua'],
        file_patterns='*.lua',
        fn_name_prefix='',
        include_tables=False,
        section_name={'diagnostic.lua': 'diagnostic'},
        section_fmt=lambda _: 'Lua module: vim.diagnostic',
        helptag_fmt=lambda _: '*diagnostic-api*',
        fn_helptag_fmt=lambda fstem, name, istbl: f'*vim.{fstem}.{name}{"" if istbl else "()"}*',
        module_override={},
        append_only=[],
    ),
    'treesitter': Config(
        mode='lua',
        filename='treesitter.txt',
        section_order=[
            'treesitter.lua',
            'language.lua',
            'query.lua',
            'highlighter.lua',
            'languagetree.lua',
            'dev.lua',
        ],
        files=[
            'runtime/lua/vim/treesitter.lua',
            'runtime/lua/vim/treesitter/',
        ],
        file_patterns='*.lua',
        fn_name_prefix='',
        section_name={},
        section_fmt=lambda name: (
            'Lua module: vim.treesitter'
            if name.lower() == 'treesitter'
            else f'Lua module: vim.treesitter.{name.lower()}'),
        helptag_fmt=lambda name: (
            '*lua-treesitter-core*'
            if name.lower() == 'treesitter'
            else f'*lua-treesitter-{name.lower()}*'),
        fn_helptag_fmt=lambda fstem, name, istbl: (
            f'*vim.{fstem}.{name}()*'
            if fstem == 'treesitter'
            else f'*{name}()*'
            if name[0].isupper()
            else f'*vim.treesitter.{fstem}.{name}()*'),
        module_override={},
        append_only=[],
    ),
}

param_exclude = (
    'channel_id',
)

# Annotations are displayed as line items after API function descriptions.
annotation_map = {
    'FUNC_API_FAST': '|api-fast|',
    'FUNC_API_TEXTLOCK': 'not allowed when |textlock| is active or in the |cmdwin|',
    'FUNC_API_TEXTLOCK_ALLOW_CMDWIN': 'not allowed when |textlock| is active',
    'FUNC_API_REMOTE_ONLY': '|RPC| only',
    'FUNC_API_LUA_ONLY': 'Lua |vim.api| only',
}


def nvim_api_info() -> Tuple[int, bool]:
    """Returns NVIM_API_LEVEL, NVIM_API_PRERELEASE from CMakeLists.txt"""
    if not hasattr(nvim_api_info, 'LEVEL'):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        cmake_file_path = os.path.join(script_dir, '..', 'CMakeLists.txt')
        with open(cmake_file_path, 'r') as cmake_file:
            cmake_content = cmake_file.read()

        api_level_match = re.search(r'set\(NVIM_API_LEVEL (\d+)\)', cmake_content)
        api_prerelease_match = re.search(
            r'set\(NVIM_API_PRERELEASE (\w+)\)', cmake_content
        )

        if not api_level_match or not api_prerelease_match:
            raise RuntimeError(
                'Could not find NVIM_API_LEVEL or NVIM_API_PRERELEASE in CMakeLists.txt'
            )

        nvim_api_info.LEVEL = int(api_level_match.group(1))
        nvim_api_info.PRERELEASE = api_prerelease_match.group(1).lower() == 'true'

    return nvim_api_info.LEVEL, nvim_api_info.PRERELEASE


# Raises an error with details about `o`, if `cond` is in object `o`,
# or if `cond()` is callable and returns True.
def debug_this(o, cond=True):
    name = ''
    if cond is False:
        return
    if not isinstance(o, str):
        try:
            name = o.nodeName
            o = o.toprettyxml(indent='  ', newl='\n')
        except Exception:
            pass
    if (cond is True
            or (callable(cond) and cond())
            or (not callable(cond) and cond in o)):
        raise RuntimeError('xxx: {}\n{}'.format(name, o))


# Appends a message to a list which will be printed on exit.
def msg(s):
    msgs.append(s)


# Print all collected messages.
def msg_report():
    for m in msgs:
        print(f'    {m}')


# Print collected messages, then throw an exception.
def fail(s):
    msg_report()
    raise RuntimeError(s)


def find_first(parent, name):
    """Finds the first matching node within parent."""
    sub = parent.getElementsByTagName(name)
    if not sub:
        return None
    return sub[0]


def iter_children(parent, name):
    """Yields matching child nodes within parent."""
    for child in parent.childNodes:
        if child.nodeType == child.ELEMENT_NODE and child.nodeName == name:
            yield child


def get_child(parent, name):
    """Gets the first matching child node."""
    for child in iter_children(parent, name):
        return child
    return None


def self_or_child(n):
    """Gets the first child node, or self."""
    if len(n.childNodes) == 0:
        return n
    return n.childNodes[0]


def align_tags(line):
    tag_regex = r"\s(\*.+?\*)(?:\s|$)"
    tags = re.findall(tag_regex, line)

    if len(tags) > 0:
        line = re.sub(tag_regex, "", line)
        tags = " " + " ".join(tags)
        line = line + (" " * (78 - len(line) - len(tags))) + tags
    return line


def clean_lines(text):
    """Removes superfluous lines.

    The beginning and end of the string is trimmed.  Empty lines are collapsed.
    """
    return re.sub(r'\A\n\s*\n*|\n\s*\n*\Z', '', re.sub(r'(\n\s*\n+)+', '\n\n', text))


def is_blank(text):
    return '' == clean_lines(text)


def get_text(n):
    """Recursively concatenates all text in a node tree."""
    text = ''
    if n.nodeType == n.TEXT_NODE:
        return n.data
    if n.nodeName == 'computeroutput':
        for node in n.childNodes:
            text += get_text(node)
        return '`{}`'.format(text)
    if n.nodeName == 'sp': # space, used in "programlisting" nodes
        return ' '
    for node in n.childNodes:
        if node.nodeType == node.TEXT_NODE:
            text += node.data
        elif node.nodeType == node.ELEMENT_NODE:
            text += get_text(node)
    return text


# Gets the length of the last line in `text`, excluding newline ("\n") char.
def len_lastline(text):
    lastnl = text.rfind('\n')
    if -1 == lastnl:
        return len(text)
    if '\n' == text[-1]:
        return lastnl - (1 + text.rfind('\n', 0, lastnl))
    return len(text) - (1 + lastnl)


def len_lastline_withoutindent(text, indent):
    n = len_lastline(text)
    return (n - len(indent)) if n > len(indent) else 0


# Returns True if node `n` contains only inline (not block-level) elements.
def is_inline(n):
    # if len(n.childNodes) == 0:
    #     return n.nodeType == n.TEXT_NODE or n.nodeName == 'computeroutput'
    for c in n.childNodes:
        if c.nodeType != c.TEXT_NODE and c.nodeName != 'computeroutput':
            return False
        if not is_inline(c):
            return False
    return True


def doc_wrap(text, prefix='', width=70, func=False, indent=None) -> str:
    """Wraps text to `width`.

    First line is prefixed with `prefix`, subsequent lines are aligned.
    If `func` is True, only wrap at commas.
    """
    if not width:
        # return prefix + text
        return text

    # Whitespace used to indent all lines except the first line.
    indent = ' ' * len(prefix) if indent is None else indent
    indent_only = (prefix == '' and indent is not None)

    if func:
        lines = [prefix]
        for part in text.split(', '):
            if part[-1] not in ');':
                part += ', '
            if len(lines[-1]) + len(part) > width:
                lines.append(indent)
            lines[-1] += part
        return '\n'.join(x.rstrip() for x in lines).rstrip()

    # XXX: Dummy prefix to force TextWrapper() to wrap the first line.
    if indent_only:
        prefix = indent

    tw = textwrap.TextWrapper(break_long_words=False,
                              break_on_hyphens=False,
                              width=width,
                              initial_indent=prefix,
                              subsequent_indent=indent)
    result = '\n'.join(tw.wrap(text.strip()))

    # XXX: Remove the dummy prefix.
    if indent_only:
        result = result[len(indent):]

    return result


def max_name(names):
    if len(names) == 0:
        return 0
    return max(len(name) for name in names)


def update_params_map(parent, ret_map, width=text_width - indentation):
    """Updates `ret_map` with name:desc key-value pairs extracted
    from Doxygen XML node `parent`.
    """
    params = collections.OrderedDict()
    for node in parent.childNodes:
        if node.nodeType == node.TEXT_NODE:
            continue
        name_node = find_first(node, 'parametername')
        if name_node.getAttribute('direction') == 'out':
            continue
        name = get_text(name_node)
        if name in param_exclude:
            continue
        params[name.strip()] = node
    max_name_len = max_name(params.keys()) + 8
    # `ret_map` is a name:desc map.
    for name, node in params.items():
        desc = ''
        desc_node = get_child(node, 'parameterdescription')
        if desc_node:
            desc = fmt_node_as_vimhelp(
                    desc_node, width=width, indent=(' ' * max_name_len))
            ret_map[name] = desc
    return ret_map


def render_node(n: Element, text: str, prefix='', *,
                indent: str = '',
                width: int = (text_width - indentation),
                fmt_vimhelp: bool = False):
    """Renders a node as Vim help text, recursively traversing all descendants."""

    def ind(s):
        return s if fmt_vimhelp else ''

    # Get the current column offset from the last line of `text`
    # (needed to appropriately wrap multiple and contiguous inline elements)
    col_offset: int = len_lastline(text)

    text = ''
    # space_preceding = (len(text) > 0 and ' ' == text[-1][-1])
    # text += (int(not space_preceding) * ' ')

    if n.nodeName == 'preformatted':
        o = get_text(n)
        ensure_nl = '' if o[-1] == '\n' else '\n'
        if o[0:4] == 'lua\n':
            text += '>lua{}{}\n<'.format(ensure_nl, o[3:-1])
        elif o[0:4] == 'vim\n':
            text += '>vim{}{}\n<'.format(ensure_nl, o[3:-1])
        elif o[0:5] == 'help\n':
            text += o[4:-1]
        else:
            text += '>{}{}\n<'.format(ensure_nl, o)
    elif n.nodeName == 'programlisting': # codeblock (```)
        o = get_text(n)
        text += '>'
        if 'filename' in n.attributes:
            filename = n.attributes['filename'].value
            text += filename.lstrip('.')

        text += '\n{}\n<'.format(textwrap.indent(o, ' ' * 4))
    elif is_inline(n):
        o = get_text(n).strip()
        if o:
            DEL = chr(127)  # a dummy character to pad for proper line wrap
            assert len(DEL) == 1
            dummy_padding = DEL * max(0, col_offset - len(prefix))
            text += doc_wrap(dummy_padding + o,
                             prefix=prefix, indent=indent, width=width
                            ).replace(DEL, "")
    elif n.nodeName == 'verbatim':
        # TODO: currently we don't use this. The "[verbatim]" hint is there as
        # a reminder that we must decide how to format this if we do use it.
        text += ' [verbatim] {}'.format(get_text(n))
    elif n.nodeName == 'listitem':
        for c in n.childNodes:
            result = render_node(
                c,
                text,
                indent=indent + (' ' * len(prefix)),
                width=width
            )
            if is_blank(result):
                continue
            text += indent + prefix + result
    elif n.nodeName in ('para', 'heading'):
        did_prefix = False
        for c in n.childNodes:
            c_text = render_node(c, text, prefix=(prefix if not did_prefix else ''), indent=indent, width=width)
            if (is_inline(c)
                    and '' != c_text.strip()
                    and text
                    and text[-1] not in (' ', '(', '|')
                    and not c_text.startswith(')')):
                text += ' '
            text += c_text
            did_prefix = True
    elif n.nodeName == 'itemizedlist':
        for c in n.childNodes:
            text += '{}\n'.format(render_node(c, text, prefix='• ',
                                              indent=indent, width=width))
    elif n.nodeName == 'orderedlist':
        i = 1
        for c in n.childNodes:
            if is_blank(get_text(c)):
                text += '\n'
                continue
            text += '{}\n'.format(render_node(c, text, prefix='{}. '.format(i),
                                              indent=indent, width=width))
            i = i + 1
    elif n.nodeName == 'simplesect' and 'note' == n.getAttribute('kind'):
        text += ind('  ')
        for c in n.childNodes:
            if is_blank(render_node(c, text, prefix='• ', indent='    ', width=width)):
                continue
            text += render_node(c, text, prefix='• ', indent='    ', width=width)
        # text += '\n'
    elif n.nodeName == 'simplesect' and 'warning' == n.getAttribute('kind'):
        text += 'Warning:\n    '
        for c in n.childNodes:
            text += render_node(c, text, indent='    ', width=width)
        text += '\n'
    elif n.nodeName == 'simplesect' and 'see' == n.getAttribute('kind'):
        text += ind('  ')
        # Example:
        #   <simplesect kind="see">
        #     <para>|autocommand|</para>
        #   </simplesect>
        for c in n.childNodes:
            text += render_node(c, text, prefix='• ', indent='    ', width=width)
    elif n.nodeName == 'simplesect' and 'return' == n.getAttribute('kind'):
        text += ind('    ')
        for c in n.childNodes:
            text += render_node(c, text, indent='    ', width=width)
    elif n.nodeName == 'computeroutput':
        return get_text(n)
    else:
        raise RuntimeError('unhandled node type: {}\n{}'.format(
            n.nodeName, n.toprettyxml(indent='  ', newl='\n')))

    return text


def para_as_map(parent: Element,
                indent: str = '',
                width: int = (text_width - indentation),
                ):
    """Extracts a Doxygen XML <para> node to a map.

    Keys:
        'text': Text from this <para> element
        'note': List of @note strings
        'params': <parameterlist> map
        'return': List of @return strings
        'seealso': List of @see strings
        'xrefs': ?
    """
    chunks = {
        'text': '',
        'note': [],
        'params': collections.OrderedDict(),
        'return': [],
        'seealso': [],
        'prerelease': False,
        'xrefs': []
    }

    # Ordered dict of ordered lists.
    groups = collections.OrderedDict([
        ('note', []),
        ('params', []),
        ('return', []),
        ('seealso', []),
        ('xrefs', []),
    ])

    # Gather nodes into groups.  Mostly this is because we want "parameterlist"
    # nodes to appear together.
    text = ''
    kind = ''
    if is_inline(parent):
        # Flatten inline text from a tree of non-block nodes.
        text = doc_wrap(render_node(parent, ""),
                        indent=indent, width=width)
    else:
        prev = None  # Previous node
        for child in parent.childNodes:
            if child.nodeName == 'parameterlist':
                groups['params'].append(child)
            elif child.nodeName == 'xrefsect':
                groups['xrefs'].append(child)
            elif child.nodeName == 'simplesect':
                kind = child.getAttribute('kind')
                if kind == 'note':
                    groups['note'].append(child)
                elif kind == 'return':
                    groups['return'].append(child)
                elif kind == 'see':
                    groups['seealso'].append(child)
                elif kind == 'warning':
                    text += render_node(child, text, indent=indent, width=width)
                elif kind == 'since':
                    since_match = re.match(r'^(\d+)', get_text(child))
                    since = int(since_match.group(1)) if since_match else 0
                    NVIM_API_LEVEL, NVIM_API_PRERELEASE = nvim_api_info()
                    if since > NVIM_API_LEVEL or (
                        since == NVIM_API_LEVEL and NVIM_API_PRERELEASE
                    ):
                        chunks['prerelease'] = True
                else:
                    raise RuntimeError('unhandled simplesect: {}\n{}'.format(
                        child.nodeName, child.toprettyxml(indent='  ', newl='\n')))
            else:
                child_text = render_node(child, text, indent=indent, width=width)
                if (prev is not None
                        and is_inline(self_or_child(prev))
                        and is_inline(self_or_child(child))
                        and '' != get_text(self_or_child(child)).strip()
                        and text
                        and text[-1] not in (' ', '(', '|')
                        and not child_text.startswith(')')):
                    text += ' '

                text += child_text
                prev = child

    chunks['text'] += text

    # Generate map from the gathered items.
    if len(groups['params']) > 0:
        for child in groups['params']:
            update_params_map(child, ret_map=chunks['params'], width=width)
    for child in groups['note']:
        chunks['note'].append(render_node(
            child, '', indent=indent, width=width).rstrip())
    for child in groups['return']:
        chunks['return'].append(render_node(
            child, '', indent=indent, width=width))
    for child in groups['seealso']:
        # Example:
        #   <simplesect kind="see">
        #     <para>|autocommand|</para>
        #   </simplesect>
        chunks['seealso'].append(render_node(
            child, '', indent=indent, width=width))

    xrefs = set()
    for child in groups['xrefs']:
        # XXX: Add a space (or any char) to `title` here, otherwise xrefs
        # ("Deprecated" section) acts very weird...
        title = get_text(get_child(child, 'xreftitle')) + ' '
        xrefs.add(title)
        xrefdesc = get_text(get_child(child, 'xrefdescription'))
        chunks['xrefs'].append(doc_wrap(xrefdesc, prefix='{}: '.format(title),
                                        width=width) + '\n')

    return chunks, xrefs


def is_program_listing(para):
    """
    Return True if `para` contains a "programlisting" (i.e. a Markdown code
    block ```).

    Sometimes a <para> element will have only a single "programlisting" child
    node, but othertimes it will have extra whitespace around the
    "programlisting" node.

    @param para XML <para> node
    @return True if <para> is a programlisting
    """

    # Remove any child text nodes that are only whitespace
    children = [
        n for n in para.childNodes
        if n.nodeType != n.TEXT_NODE or n.data.strip() != ''
    ]

    return len(children) == 1 and children[0].nodeName == 'programlisting'


FunctionParam = Tuple[
    str,  # type
    str,  # parameter name
]

@dataclasses.dataclass
class FunctionDoc:
    """Data structure for function documentation. Also exported as msgpack."""

    annotations: List[str]
    """Attributes, e.g., FUNC_API_REMOTE_ONLY. See annotation_map"""

    notes: List[Docstring]
    """Notes: (@note strings)"""

    signature: str
    """Function signature with *tags*."""

    parameters: List[FunctionParam]
    """Parameters: (type, name)"""

    parameters_doc: Dict[str, Docstring]
    """Parameters documentation. Key is parameter name, value is doc."""

    doc: List[Docstring]
    """Main description for the function. Separated by paragraph."""

    return_: List[Docstring]
    """Return:, or Return (multiple): (@return strings)"""

    seealso: List[Docstring]
    """See also: (@see strings)"""

    xrefs: List[Docstring]
    """XRefs. Currently only used to track Deprecated functions."""

    # for INCLUDE_C_DECL
    c_decl: str | None = None

    prerelease: bool = False

    def export_mpack(self) -> Dict[str, Any]:
        """Convert a dict to be exported as mpack data."""
        exported = self.__dict__.copy()
        del exported['notes']
        del exported['c_decl']
        del exported['prerelease']
        del exported['xrefs']
        exported['return'] = exported.pop('return_')
        return exported

    def doc_concatenated(self) -> Docstring:
        """Concatenate all the paragraphs in `doc` into a single string, but
        remove blank lines before 'programlisting' blocks. #25127

        BEFORE (without programlisting processing):
            ```vimdoc
            Example:

            >vim
                :echo nvim_get_color_by_name("Pink")
            <
            ```

        AFTER:
            ```vimdoc
            Example: >vim
                :echo nvim_get_color_by_name("Pink")
            <
            ```
        """
        def is_program_listing(paragraph: str) -> bool:
            lines = paragraph.strip().split('\n')
            return lines[0].startswith('>') and lines[-1] == '<'

        rendered = []
        for paragraph in self.doc:
            if is_program_listing(paragraph):
                rendered.append(' ')  # Example: >vim
            elif rendered:
                rendered.append('\n\n')
            rendered.append(paragraph)
        return ''.join(rendered)

    def render(self) -> Docstring:
        """Renders function documentation as Vim :help text."""
        rendered_blocks: List[Docstring] = []

        def fmt_param_doc(m):
            """Renders a params map as Vim :help text."""
            max_name_len = max_name(m.keys()) + 4
            out = ''
            for name, desc in m.items():
                if name == 'self':
                    continue
                name = '  • {}'.format('{{{}}}'.format(name).ljust(max_name_len))
                out += '{}{}\n'.format(name, desc)
            return out.rstrip()

        # Generate text from the gathered items.
        chunks: List[Docstring] = [self.doc_concatenated()]

        notes = []
        if self.prerelease:
            notes = ["  This API is pre-release (unstable)."]
        notes += self.notes
        if len(notes) > 0:
            chunks.append('\nNote: ~')
            for s in notes:
                chunks.append('  ' + s)

        if self.parameters_doc:
            chunks.append('\nParameters: ~')
            chunks.append(fmt_param_doc(self.parameters_doc))

        if self.return_:
            chunks.append('\nReturn (multiple): ~' if len(self.return_) > 1
                          else '\nReturn: ~')
            for s in self.return_:
                chunks.append('    ' + s)

        if self.seealso:
            chunks.append('\nSee also: ~')
            for s in self.seealso:
                chunks.append('  ' + s)

        # Note: xrefs are currently only used to remark "Deprecated: "
        # for deprecated functions; visible when INCLUDE_DEPRECATED is set
        for s in self.xrefs:
            chunks.append('\n' + s)

        rendered_blocks.append(clean_lines('\n'.join(chunks).strip()))
        rendered_blocks.append('')

        return clean_lines('\n'.join(rendered_blocks).strip())


def fmt_node_as_vimhelp(parent: Element, width=text_width - indentation, indent=''):
    """Renders (nested) Doxygen <para> nodes as Vim :help text.

    Only handles "text" nodes. Used for individual elements (see render_node())
    and in extract_defgroups().

    NB: Blank lines in a docstring manifest as <para> tags.
    """
    rendered_blocks = []

    for child in parent.childNodes:
        para, _ = para_as_map(child, indent, width)

        # 'programlisting' blocks are Markdown code blocks. Do not include
        # these as a separate paragraph, but append to the last non-empty line
        # in the text
        if is_program_listing(child):
            while rendered_blocks and rendered_blocks[-1] == '':
                rendered_blocks.pop()
            rendered_blocks[-1] += ' ' + para['text']
            continue

        # Generate text from the gathered items.
        chunks = [para['text']]

        rendered_blocks.append(clean_lines('\n'.join(chunks).strip()))
        rendered_blocks.append('')

    return clean_lines('\n'.join(rendered_blocks).strip())


def extract_from_xml(filename, target, *,
                     width: int, fmt_vimhelp: bool) -> Tuple[
    Dict[FunctionName, FunctionDoc],
    Dict[FunctionName, FunctionDoc],
]:
    """Extracts Doxygen info as maps without formatting the text.

    Returns two maps:
      1. Functions
      2. Deprecated functions

    The `fmt_vimhelp` variable controls some special cases for use by
    fmt_doxygen_xml_as_vimhelp(). (TODO: ugly :)
    """
    config: Config = CONFIG[target]

    fns: Dict[FunctionName, FunctionDoc] = {}
    deprecated_fns: Dict[FunctionName, FunctionDoc] = {}

    dom = minidom.parse(filename)
    compoundname = get_text(dom.getElementsByTagName('compoundname')[0])
    for member in dom.getElementsByTagName('memberdef'):
        if member.getAttribute('static') == 'yes' or \
                member.getAttribute('kind') != 'function' or \
                member.getAttribute('prot') == 'private' or \
                get_text(get_child(member, 'name')).startswith('_'):
            continue

        loc = find_first(member, 'location')
        if 'private' in loc.getAttribute('file'):
            continue

        return_type = get_text(get_child(member, 'type'))
        if return_type == '':
            continue

        if 'local_function' in return_type:  # Special from lua2dox.lua.
            continue

        istbl = return_type.startswith('table')  # Special from lua2dox.lua.
        if istbl and not config.include_tables:
            continue

        if return_type.startswith(('ArrayOf', 'DictionaryOf')):
            parts = return_type.strip('_').split('_')
            return_type = '{}({})'.format(parts[0], ', '.join(parts[1:]))

        name = get_text(get_child(member, 'name'))

        annotations = get_text(get_child(member, 'argsstring'))
        if annotations and ')' in annotations:
            annotations = annotations.rsplit(')', 1)[-1].strip()
        # XXX: (doxygen 1.8.11) 'argsstring' only includes attributes of
        # non-void functions.  Special-case void functions here.
        if name == 'nvim_get_mode' and len(annotations) == 0:
            annotations += 'FUNC_API_FAST'
        annotations = filter(None, map(lambda x: annotation_map.get(x),
                                       annotations.split()))

        params = []
        type_length = 0

        for param in iter_children(member, 'param'):
            param_type = get_text(get_child(param, 'type')).strip()
            param_name = ''
            declname = get_child(param, 'declname')
            if declname:
                param_name = get_text(declname).strip()
            elif config.mode == 'lua':
                # XXX: this is what lua2dox gives us...
                param_name = param_type
                param_type = ''

            if param_name in param_exclude:
                continue

            if fmt_vimhelp and param_type.endswith('*'):
                param_type = param_type.strip('* ')
                param_name = '*' + param_name

            type_length = max(type_length, len(param_type))
            params.append((param_type, param_name))

        # Handle Object Oriented style functions here.
        #   We make sure they have "self" in the parameters,
        #   and a parent function
        if return_type.startswith('function') \
                and len(return_type.split(' ')) >= 2 \
                and any(x[1] == 'self' for x in params):
            split_return = return_type.split(' ')
            name = f'{split_return[1]}:{name}'
            params = [x for x in params if x[1] != 'self']

        c_args = []
        for param_type, param_name in params:
            c_args.append(('    ' if fmt_vimhelp else '') + (
                '%s %s' % (param_type.ljust(type_length), param_name)).strip())

        if not fmt_vimhelp:
            pass
        else:
            fstem = '?'
            if '.' in compoundname:
                fstem = compoundname.split('.')[0]
                fstem = config.module_override.get(fstem, fstem)
            vimtag = config.fn_helptag_fmt(fstem, name, istbl)

            if config.fn_name_fmt:
                name = config.fn_name_fmt(fstem, name)

        if istbl:
            aopen, aclose = '', ''
        else:
            aopen, aclose = '(', ')'

        prefix = name + aopen
        suffix = ', '.join('{%s}' % a[1] for a in params
                           if a[0] not in ('void', 'Error', 'Arena',
                                           'lua_State')) + aclose

        if not fmt_vimhelp:
            c_decl = '%s %s(%s);' % (return_type, name, ', '.join(c_args))
            signature = prefix + suffix
        else:
            c_decl = textwrap.indent('%s %s(\n%s\n);' % (return_type, name,
                                                         ',\n'.join(c_args)),
                                     '    ')

            # Minimum 8 chars between signature and vimtag
            lhs = (width - 8) - len(vimtag)

            if len(prefix) + len(suffix) > lhs:
                signature = vimtag.rjust(width) + '\n'
                signature += doc_wrap(suffix, width=width, prefix=prefix,
                                      func=True)
            else:
                signature = prefix + suffix
                signature += vimtag.rjust(width - len(signature))

        # Tracks `xrefsect` titles.  As of this writing, used only for separating
        # deprecated functions.
        xrefs_all = set()
        paras: List[Dict[str, Any]] = []  # paras means paragraphs!
        brief_desc = find_first(member, 'briefdescription')
        if brief_desc:
            for child in brief_desc.childNodes:
                para, xrefs = para_as_map(child)
                paras.append(para)
                xrefs_all.update(xrefs)

        desc = find_first(member, 'detaileddescription')
        if desc:
            paras_detail = []  # override briefdescription
            for child in desc.childNodes:
                para, xrefs = para_as_map(child)
                paras_detail.append(para)
                xrefs_all.update(xrefs)
            log.debug(
                textwrap.indent(
                    re.sub(r'\n\s*\n+', '\n',
                           desc.toprettyxml(indent='  ', newl='\n')),
                    ' ' * indentation))

            # override briefdescription, if detaileddescription is not empty
            # (note: briefdescription can contain some erroneous luadoc
            #  comments from preceding comments, this is a bug of lua2dox)
            if any((para['text'] or para['note'] or para['params'] or
                    para['return'] or para['seealso']
                    ) for para in paras_detail):
                paras = paras_detail

        fn = FunctionDoc(
            annotations=list(annotations),
            notes=[],
            signature=signature,
            parameters=params,
            parameters_doc=collections.OrderedDict(),
            doc=[],
            return_=[],
            seealso=[],
            xrefs=[],
        )

        for m in paras:
            if m.get('text', ''):
                fn.doc.append(m['text'])
            if 'params' in m:
                # Merge OrderedDicts.
                fn.parameters_doc.update(m['params'])
            if 'return' in m and len(m['return']) > 0:
                fn.return_ += m['return']
            if 'seealso' in m and len(m['seealso']) > 0:
                fn.seealso += m['seealso']
            if m.get('prerelease', False):
                fn.prerelease = True
            if 'note' in m:
                fn.notes += m['note']
            if 'xrefs' in m:
                fn.xrefs += m['xrefs']

        if INCLUDE_C_DECL:
            fn.c_decl = c_decl

        if 'Deprecated' in str(xrefs_all):
            deprecated_fns[name] = fn
        elif name.startswith(config.fn_name_prefix):
            fns[name] = fn

    # sort functions by name (lexicographically)
    fns = collections.OrderedDict(sorted(
        fns.items(),
        key=lambda key_item_tuple: key_item_tuple[0].lower(),
    ))
    deprecated_fns = collections.OrderedDict(sorted(deprecated_fns.items()))
    return fns, deprecated_fns


def fmt_doxygen_xml_as_vimhelp(filename, target) -> Tuple[Docstring, Docstring]:
    """Entrypoint for generating Vim :help from from Doxygen XML.

    Returns 2 items:
      1. Vim help text for functions found in `filename`.
      2. Vim help text for deprecated functions.
    """
    config: Config = CONFIG[target]

    fns_txt = {}  # Map of func_name:vim-help-text.
    deprecated_fns_txt = {}  # Map of func_name:vim-help-text.

    fns: Dict[FunctionName, FunctionDoc]
    deprecated_fns: Dict[FunctionName, FunctionDoc]
    fns, deprecated_fns = extract_from_xml(
        filename, target, width=text_width, fmt_vimhelp=True)

    def _handle_fn(fn_name: FunctionName, fn: FunctionDoc,
                   fns_txt: Dict[FunctionName, Docstring], deprecated=False):
        # Generate Vim :help for parameters.

        # Generate body from FunctionDoc, not XML nodes
        doc = fn.render()
        if not doc and fn_name.startswith("nvim__"):
            return
        if not doc:
            doc = ('TODO: Documentation' if not deprecated
                   else 'Deprecated.')

        # Annotations: put before Parameters
        annotations: str = '\n'.join(fn.annotations)
        if annotations:
            annotations = ('\n\nAttributes: ~\n' +
                           textwrap.indent(annotations, '    '))
            i = doc.rfind('Parameters: ~')
            if i == -1:
                doc += annotations
            else:
                doc = doc[:i] + annotations + '\n\n' + doc[i:]

        # C Declaration: (debug only)
        if INCLUDE_C_DECL:
            doc += '\n\nC Declaration: ~\n>\n'
            assert fn.c_decl is not None
            doc += fn.c_decl
            doc += '\n<'

        # Start of function documentations. e.g.,
        # nvim_cmd({*cmd}, {*opts})                                         *nvim_cmd()*
        func_doc = fn.signature + '\n'
        func_doc += textwrap.indent(clean_lines(doc), ' ' * indentation)

        # Verbatim handling.
        func_doc = re.sub(r'^\s+([<>])$', r'\1', func_doc, flags=re.M)

        def process_helptags(func_doc: str) -> str:
            lines: List[str] = func_doc.split('\n')
            # skip ">lang ... <" regions
            is_verbatim: bool = False
            for i in range(len(lines)):
                if re.search(' >([a-z])*$', lines[i]):
                    is_verbatim = True
                elif is_verbatim and lines[i].strip() == '<':
                    is_verbatim = False
                if not is_verbatim:
                    lines[i] = align_tags(lines[i])
            return "\n".join(lines)

        func_doc = process_helptags(func_doc)

        if (fn_name.startswith(config.fn_name_prefix)
            and fn_name != "nvim_error_event"):
            fns_txt[fn_name] = func_doc

    for fn_name, fn in fns.items():
        _handle_fn(fn_name, fn, fns_txt)
    for fn_name, fn in deprecated_fns.items():
        _handle_fn(fn_name, fn, deprecated_fns_txt, deprecated=True)

    return (
        '\n\n'.join(list(fns_txt.values())),
        '\n\n'.join(list(deprecated_fns_txt.values())),
    )


def delete_lines_below(filename, tokenstr):
    """Deletes all lines below the line containing `tokenstr`, the line itself,
    and one line above it.
    """
    lines = open(filename).readlines()
    i = 0
    found = False
    for i, line in enumerate(lines, 1):
        if tokenstr in line:
            found = True
            break
    if not found:
        raise RuntimeError(f'not found: "{tokenstr}"')
    i = max(0, i - 2)
    with open(filename, 'wt') as fp:
        fp.writelines(lines[0:i])


def extract_defgroups(base: str, dom: Document) -> Dict[SectionName, Docstring]:
    '''Generate module-level (section) docs (@defgroup).'''
    section_docs = {}

    for compound in dom.getElementsByTagName('compound'):
        if compound.getAttribute('kind') != 'group':
            continue

        # Doxygen "@defgroup" directive.
        groupname = get_text(find_first(compound, 'name'))
        groupxml = os.path.join(base, '%s.xml' %
                                compound.getAttribute('refid'))

        group_parsed = minidom.parse(groupxml)
        doc_list = []
        brief_desc = find_first(group_parsed, 'briefdescription')
        if brief_desc:
            for child in brief_desc.childNodes:
                doc_list.append(fmt_node_as_vimhelp(child))

        desc = find_first(group_parsed, 'detaileddescription')
        if desc:
            doc = fmt_node_as_vimhelp(desc)

            if doc:
                doc_list.append(doc)

        # Can't use '.' in @defgroup, so convert to '--'
        # "vim.json" => "vim-dot-json"
        groupname = groupname.replace('-dot-', '.')

        section_docs[groupname] = "\n".join(doc_list)

    return section_docs


@dataclasses.dataclass
class Section:
    """Represents a section. Includes section heading (defgroup)
    and all the FunctionDoc that belongs to this section."""

    name: str
    '''Name of the section. Usually derived from basename of lua/c src file.
    Example: "Autocmd".'''

    title: str
    '''Formatted section config. see config.section_fmt().
    Example: "Autocmd Functions". '''

    helptag: str
    '''see config.helptag_fmt(). Example: *api-autocmd*'''

    @property
    def id(self) -> str:
        '''section id: Module/Section id matched against @defgroup.
           e.g., "*api-autocmd*" => "api-autocmd"
        '''
        return self.helptag.strip('*')

    doc: str = ""
    '''Section heading docs extracted from @defgroup.'''

    # TODO: Do not carry rendered text, but handle FunctionDoc for better OOP
    functions_text: Docstring | None = None
    '''(Rendered) doc of all the functions that belong to this section.'''

    deprecated_functions_text: Docstring | None = None
    '''(Rendered) doc of all the deprecated functions that belong to this
    section.'''

    def __repr__(self):
        return f"Section(title='{self.title}', helptag='{self.helptag}')"

    @classmethod
    def make_from(cls, filename: str, config: Config,
                  section_docs: Dict[SectionName, str],
                  *,
                  functions_text: Docstring,
                  deprecated_functions_text: Docstring,
                  ):
        # filename: e.g., 'autocmd.c'
        # name: e.g. 'autocmd'
        name = os.path.splitext(filename)[0].lower()

        # section name: e.g. "Autocmd"
        sectname: SectionName
        sectname = name.upper() if name == 'ui' else name.title()
        sectname = config.section_name.get(filename, sectname)

        # Formatted (this is what's going to be written in the vimdoc)
        # e.g., "Autocmd Functions"
        title: str = config.section_fmt(sectname)

        # section tag: e.g., "*api-autocmd*"
        section_tag: str = config.helptag_fmt(sectname)

        section = cls(name=sectname, title=title, helptag=section_tag,
                      functions_text=functions_text,
                      deprecated_functions_text=deprecated_functions_text,
                      )
        section.doc = section_docs.get(section.id) or ''
        return section

    def render(self, add_header=True) -> str:
        """Render as vimdoc."""
        doc = ''

        if add_header:
            doc += SECTION_SEP
            doc += '\n{}{}'.format(
                self.title,
                self.helptag.rjust(text_width - len(self.title))
            )

        if self.doc:
            doc += '\n\n' + self.doc

        if self.functions_text:
            doc += '\n\n' + self.functions_text

        if INCLUDE_DEPRECATED and self.deprecated_functions_text:
            doc += f'\n\n\nDeprecated {self.name} Functions: ~\n\n'
            doc += self.deprecated_functions_text

        return doc

    def __bool__(self) -> bool:
        """Whether this section has contents. Used for skipping empty ones."""
        return bool(self.doc or self.functions_text or
                    (INCLUDE_DEPRECATED and self.deprecated_functions_text))


def main(doxygen_config, args):
    """Generates:

    1. Vim :help docs
    2. *.mpack files for use by API clients

    Doxygen is called and configured through stdin.
    """
    for target in CONFIG:
        if args.target is not None and target != args.target:
            continue

        config: Config = CONFIG[target]

        mpack_file = os.path.join(
            base_dir, 'runtime', 'doc',
            config.filename.replace('.txt', '.mpack'))
        if os.path.exists(mpack_file):
            os.remove(mpack_file)

        output_dir = out_dir.format(target=target)
        log.info("Generating documentation for %s in folder %s",
                 target, output_dir)
        debug = args.log_level >= logging.DEBUG
        p = subprocess.Popen(
                ['doxygen', '-'],
                stdin=subprocess.PIPE,
                # silence warnings
                # runtime/lua/vim/lsp.lua:209: warning: argument 'foo' not found
                stderr=(subprocess.STDOUT if debug else subprocess.DEVNULL))
        p.communicate(
            doxygen_config.format(
                input=' '.join([f'"{file}"' for file in config.files]),
                output=output_dir,
                filter=filter_cmd,
                file_patterns=config.file_patterns)
            .encode('utf8')
        )
        if p.returncode:
            sys.exit(p.returncode)

        # Collects all functions as each module is processed.
        fn_map_full: Dict[FunctionName, FunctionDoc] = {}
        # key: filename (e.g. autocmd.c)
        sections: Dict[str, Section] = {}

        base = os.path.join(output_dir, 'xml')
        dom = minidom.parse(os.path.join(base, 'index.xml'))

        # Collect all @defgroups (section headings after the '===...' separator
        section_docs: Dict[SectionName, Docstring] = extract_defgroups(base, dom)

        # Generate docs for all functions in the current module.
        for compound in dom.getElementsByTagName('compound'):
            if compound.getAttribute('kind') != 'file':
                continue

            filename = get_text(find_first(compound, 'name'))
            if not (
                filename.endswith('.c') or
                filename.endswith('.lua')
            ):
                continue

            xmlfile = os.path.join(base, '{}.xml'.format(compound.getAttribute('refid')))

            # Extract unformatted (*.mpack).
            fn_map, _ = extract_from_xml(
                xmlfile, target, width=9999, fmt_vimhelp=False)

            # Extract formatted (:help).
            functions_text, deprecated_text = fmt_doxygen_xml_as_vimhelp(
                xmlfile, target)

            if not functions_text and not deprecated_text:
                continue

            filename = os.path.basename(filename)

            section: Section = Section.make_from(
                filename, config, section_docs,
                functions_text=functions_text,
                deprecated_functions_text=deprecated_text,
            )

            if section:  # if not empty
                sections[filename] = section
                fn_map_full.update(fn_map)
            else:
                log.debug("Skipping empty section: %s", section)

        if len(sections) == 0:
            fail(f'no sections for target: {target} (look for errors near "Preprocessing" log lines above)')
        if len(sections) > len(config.section_order):
            raise RuntimeError(
                '{}: found new modules {}; '
                'update the "section_order" map'.format(
                    target,
                    set(sections).difference(config.section_order))
            )
        first_section_tag = sections[config.section_order[0]].helptag

        docs = ''

        for filename in config.section_order:
            try:
                section: Section = sections.pop(filename)
            except KeyError:
                msg(f'warning: empty docs, skipping (target={target}): {filename}')
                msg(f'    existing docs: {sections.keys()}')
                continue

            add_sep_and_header = filename not in config.append_only
            docs += section.render(add_header=add_sep_and_header)
            docs += '\n\n\n'

        docs = docs.rstrip() + '\n\n'
        docs += f' vim:tw=78:ts=8:sw={indentation}:sts={indentation}:et:ft=help:norl:\n'

        doc_file = os.path.join(base_dir, 'runtime', 'doc', config.filename)

        if os.path.exists(doc_file):
            delete_lines_below(doc_file, first_section_tag)
        with open(doc_file, 'ab') as fp:
            fp.write(docs.encode('utf8'))

        fn_map_full_exported = collections.OrderedDict(sorted(
            (name, fn_doc.export_mpack()) for (name, fn_doc) in fn_map_full.items()
        ))
        with open(mpack_file, 'wb') as fp:
            fp.write(msgpack.packb(fn_map_full_exported, use_bin_type=True))  # type: ignore

        if not args.keep_tmpfiles:
            shutil.rmtree(output_dir)

    msg_report()


def filter_source(filename, keep_tmpfiles):
    output_dir = out_dir.format(target='lua2dox')
    name, extension = os.path.splitext(filename)
    if extension == '.lua':
        args = [str(nvim), '-l', lua2dox, filename] + (['--outdir', output_dir] if keep_tmpfiles else [])
        p = subprocess.run(args, stdout=subprocess.PIPE)
        op = ('?' if 0 != p.returncode else p.stdout.decode('utf-8'))
        print(op)
    else:
        """Filters the source to fix macros that confuse Doxygen."""
        with open(filename, 'rt') as fp:
            print(re.sub(r'^(ArrayOf|DictionaryOf)(\(.*?\))',
                         lambda m: m.group(1)+'_'.join(
                             re.split(r'[^\w]+', m.group(2))),
                         fp.read(), flags=re.M))


def parse_args():
    targets = ', '.join(CONFIG.keys())
    ap = argparse.ArgumentParser(
        description="Generate helpdoc from source code")
    ap.add_argument(
        "--log-level", "-l", choices=LOG_LEVELS.keys(),
        default=logging.getLevelName(logging.ERROR), help="Set log verbosity"
    )
    ap.add_argument('source_filter', nargs='*',
                    help="Filter source file(s)")
    ap.add_argument('-k', '--keep-tmpfiles', action='store_true',
                    help="Keep temporary files (tmp-xx-doc/ directories, including tmp-lua2dox-doc/ for lua2dox.lua quasi-C output)")
    ap.add_argument('-t', '--target',
                    help=f'One of ({targets}), defaults to "all"')
    return ap.parse_args()


Doxyfile = textwrap.dedent('''
    OUTPUT_DIRECTORY       = {output}
    INPUT                  = {input}
    INPUT_ENCODING         = UTF-8
    FILE_PATTERNS          = {file_patterns}
    RECURSIVE              = YES
    INPUT_FILTER           = "{filter}"
    EXCLUDE                =
    EXCLUDE_SYMLINKS       = NO
    EXCLUDE_PATTERNS       = */private/* */health.lua */_*.lua
    EXCLUDE_SYMBOLS        =
    EXTENSION_MAPPING      = lua=C
    EXTRACT_PRIVATE        = NO

    GENERATE_HTML          = NO
    GENERATE_DOCSET        = NO
    GENERATE_HTMLHELP      = NO
    GENERATE_QHP           = NO
    GENERATE_TREEVIEW      = NO
    GENERATE_LATEX         = NO
    GENERATE_RTF           = NO
    GENERATE_MAN           = NO
    GENERATE_DOCBOOK       = NO
    GENERATE_AUTOGEN_DEF   = NO

    GENERATE_XML           = YES
    XML_OUTPUT             = xml
    XML_PROGRAMLISTING     = NO

    ENABLE_PREPROCESSING   = YES
    MACRO_EXPANSION        = YES
    EXPAND_ONLY_PREDEF     = NO
    MARKDOWN_SUPPORT       = YES
''')

if __name__ == "__main__":
    args = parse_args()
    print("Setting log level to %s" % args.log_level)
    args.log_level = LOG_LEVELS[args.log_level]
    log.setLevel(args.log_level)
    log.addHandler(logging.StreamHandler())

    # When invoked as a filter, args won't be passed, so use an env var.
    if args.keep_tmpfiles:
        os.environ['NVIM_KEEP_TMPFILES'] = '1'
    keep_tmpfiles = ('NVIM_KEEP_TMPFILES' in os.environ)

    if len(args.source_filter) > 0:
        filter_source(args.source_filter[0], keep_tmpfiles)
    else:
        main(Doxyfile, args)

# vim: set ft=python ts=4 sw=4 tw=79 et :
