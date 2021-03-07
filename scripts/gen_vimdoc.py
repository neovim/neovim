#!/usr/bin/env python3
"""Generates Nvim :help docs from C/Lua docstrings, using Doxygen.

Also generates *.mpack files. To inspect the *.mpack structure:

    :new | put=v:lua.vim.inspect(msgpackparse(readfile('runtime/doc/api.mpack')))


Flow:
    main
      extract_from_xml
        fmt_node_as_vimhelp   \
          para_as_map          } recursive
            update_params_map /
              render_node

This would be easier using lxml and XSLT, but:

  1. This should avoid needing Python dependencies, especially ones that are
     C modules that have library dependencies (lxml requires libxml and
     libxslt).
  2. I wouldn't know how to deal with nested indentation in <para> tags using
     XSLT.

Each function :help block is formatted as follows:

  - Max width of 78 columns (`text_width`).
  - Indent with spaces (not tabs).
  - Indent of 16 columns for body text.
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
import argparse
import os
import re
import sys
import shutil
import textwrap
import subprocess
import collections
import msgpack
import logging

from xml.dom import minidom

MIN_PYTHON_VERSION = (3, 5)

if sys.version_info < MIN_PYTHON_VERSION:
    print("requires Python {}.{}+".format(*MIN_PYTHON_VERSION))
    sys.exit(1)

# DEBUG = ('DEBUG' in os.environ)
INCLUDE_C_DECL = ('INCLUDE_C_DECL' in os.environ)
INCLUDE_DEPRECATED = ('INCLUDE_DEPRECATED' in os.environ)

log = logging.getLogger(__name__)

LOG_LEVELS = {
    logging.getLevelName(level): level for level in [
        logging.DEBUG, logging.INFO, logging.ERROR
    ]
}

fmt_vimhelp = False  # HACK
text_width = 78
script_path = os.path.abspath(__file__)
base_dir = os.path.dirname(os.path.dirname(script_path))
out_dir = os.path.join(base_dir, 'tmp-{target}-doc')
filter_cmd = '%s %s' % (sys.executable, script_path)
seen_funcs = set()
msgs = []  # Messages to show on exit.
lua2dox_filter = os.path.join(base_dir, 'scripts', 'lua2dox_filter')

CONFIG = {
    'api': {
        'mode': 'c',
        'filename': 'api.txt',
        # String used to find the start of the generated part of the doc.
        'section_start_token': '*api-global*',
        # Section ordering.
        'section_order': [
            'vim.c',
            'buffer.c',
            'window.c',
            'tabpage.c',
            'ui.c',
        ],
        # List of files/directories for doxygen to read, separated by blanks
        'files': os.path.join(base_dir, 'src/nvim/api'),
        # file patterns used by doxygen
        'file_patterns': '*.h *.c',
        # Only function with this prefix are considered
        'fn_name_prefix': 'nvim_',
        # Section name overrides.
        'section_name': {
            'vim.c': 'Global',
        },
        # For generated section names.
        'section_fmt': lambda name: f'{name} Functions',
        # Section helptag.
        'helptag_fmt': lambda name: f'*api-{name.lower()}*',
        # Per-function helptag.
        'fn_helptag_fmt': lambda fstem, name: f'*{name}()*',
        # Module name overrides (for Lua).
        'module_override': {},
        # Append the docs for these modules, do not start a new section.
        'append_only': [],
    },
    'lua': {
        'mode': 'lua',
        'filename': 'lua.txt',
        'section_start_token': '*lua-vim*',
        'section_order': [
            'vim.lua',
            'shared.lua',
            'uri.lua',
        ],
        'files': ' '.join([
            os.path.join(base_dir, 'src/nvim/lua/vim.lua'),
            os.path.join(base_dir, 'runtime/lua/vim/shared.lua'),
            os.path.join(base_dir, 'runtime/lua/vim/uri.lua'),
        ]),
        'file_patterns': '*.lua',
        'fn_name_prefix': '',
        'section_name': {
            'lsp.lua': 'core',
        },
        'section_fmt': lambda name: f'Lua module: {name.lower()}',
        'helptag_fmt': lambda name: f'*lua-{name.lower()}*',
        'fn_helptag_fmt': lambda fstem, name: f'*{fstem}.{name}()*',
        'module_override': {
            # `shared` functions are exposed on the `vim` module.
            'shared': 'vim',
            'uri': 'vim',
        },
        'append_only': [
            'shared.lua',
        ],
    },
    'lsp': {
        'mode': 'lua',
        'filename': 'lsp.txt',
        'section_start_token': '*lsp-core*',
        'section_order': [
            'lsp.lua',
            'buf.lua',
            'diagnostic.lua',
            'handlers.lua',
            'util.lua',
            'log.lua',
            'rpc.lua',
            'protocol.lua',
        ],
        'files': ' '.join([
            os.path.join(base_dir, 'runtime/lua/vim/lsp'),
            os.path.join(base_dir, 'runtime/lua/vim/lsp.lua'),
        ]),
        'file_patterns': '*.lua',
        'fn_name_prefix': '',
        'section_name': {'lsp.lua': 'lsp'},
        'section_fmt': lambda name: (
            'Lua module: vim.lsp'
            if name.lower() == 'lsp'
            else f'Lua module: vim.lsp.{name.lower()}'),
        'helptag_fmt': lambda name: (
            '*lsp-core*'
            if name.lower() == 'lsp'
            else f'*lsp-{name.lower()}*'),
        'fn_helptag_fmt': lambda fstem, name: (
            f'*vim.lsp.{name}()*'
            if fstem == 'lsp' and name != 'client'
            else (
                '*vim.lsp.client*'
                # HACK. TODO(justinmk): class/structure support in lua2dox
                if 'lsp.client' == f'{fstem}.{name}'
                else f'*vim.lsp.{fstem}.{name}()*')),
        'module_override': {},
        'append_only': [],
    },
}

param_exclude = (
    'channel_id',
)

# Annotations are displayed as line items after API function descriptions.
annotation_map = {
    'FUNC_API_FAST': '{fast}',
    'FUNC_API_CHECK_TEXTLOCK': 'not allowed when |textlock| is active',
}


# Tracks `xrefsect` titles.  As of this writing, used only for separating
# deprecated functions.
xrefs = set()


# Raises an error with details about `o`, if `cond` is in object `o`,
# or if `cond()` is callable and returns True.
def debug_this(o, cond=True):
    name = ''
    if not isinstance(o, str):
        try:
            name = o.nodeName
            o = o.toprettyxml(indent='  ', newl='\n')
        except Exception:
            pass
    if ((callable(cond) and cond())
            or (not callable(cond) and cond)
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


def clean_text(text):
    """Cleans text.

    Only cleans superfluous whitespace at the moment.
    """
    return ' '.join(text.split()).strip()


def clean_lines(text):
    """Removes superfluous lines.

    The beginning and end of the string is trimmed.  Empty lines are collapsed.
    """
    return re.sub(r'\A\n\s*\n*|\n\s*\n*\Z', '', re.sub(r'(\n\s*\n+)+', '\n\n', text))


def is_blank(text):
    return '' == clean_lines(text)


def get_text(n, preformatted=False):
    """Recursively concatenates all text in a node tree."""
    text = ''
    if n.nodeType == n.TEXT_NODE:
        return n.data
    if n.nodeName == 'computeroutput':
        for node in n.childNodes:
            text += get_text(node)
        return '`{}` '.format(text)
    for node in n.childNodes:
        if node.nodeType == node.TEXT_NODE:
            text += node.data if preformatted else clean_text(node.data)
        elif node.nodeType == node.ELEMENT_NODE:
            text += ' ' + get_text(node, preformatted)
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


def doc_wrap(text, prefix='', width=70, func=False, indent=None):
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


def update_params_map(parent, ret_map, width=62):
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


def render_node(n, text, prefix='', indent='', width=62):
    """Renders a node as Vim help text, recursively traversing all descendants."""
    global fmt_vimhelp
    global has_seen_preformatted

    def ind(s):
        return s if fmt_vimhelp else ''

    text = ''
    # space_preceding = (len(text) > 0 and ' ' == text[-1][-1])
    # text += (int(not space_preceding) * ' ')

    if n.nodeName == 'preformatted':
        o = get_text(n, preformatted=True)
        ensure_nl = '' if o[-1] == '\n' else '\n'
        text += '>{}{}\n<'.format(ensure_nl, o)

    elif is_inline(n):
        text = doc_wrap(get_text(n), indent=indent, width=width)
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
        for c in n.childNodes:
            text += render_node(c, text, indent=indent, width=width)
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
        text += '\nNote:\n    '
        for c in n.childNodes:
            text += render_node(c, text, indent='    ', width=width)
        text += '\n'
    elif n.nodeName == 'simplesect' and 'warning' == n.getAttribute('kind'):
        text += 'Warning:\n    '
        for c in n.childNodes:
            text += render_node(c, text, indent='    ', width=width)
        text += '\n'
    elif (n.nodeName == 'simplesect'
            and n.getAttribute('kind') in ('return', 'see')):
        text += ind('    ')
        for c in n.childNodes:
            text += render_node(c, text, indent='    ', width=width)
    elif n.nodeName == 'computeroutput':
        return get_text(n)
    else:
        raise RuntimeError('unhandled node type: {}\n{}'.format(
            n.nodeName, n.toprettyxml(indent='  ', newl='\n')))

    return text


def para_as_map(parent, indent='', width=62):
    """Extracts a Doxygen XML <para> node to a map.

    Keys:
        'text': Text from this <para> element
        'params': <parameterlist> map
        'return': List of @return strings
        'seealso': List of @see strings
        'xrefs': ?
    """
    chunks = {
        'text': '',
        'params': collections.OrderedDict(),
        'return': [],
        'seealso': [],
        'xrefs': []
    }

    # Ordered dict of ordered lists.
    groups = collections.OrderedDict([
        ('params', []),
        ('return', []),
        ('seealso', []),
        ('xrefs', []),
    ])

    # Gather nodes into groups.  Mostly this is because we want "parameterlist"
    # nodes to appear together.
    text = ''
    kind = ''
    last = ''
    if is_inline(parent):
        # Flatten inline text from a tree of non-block nodes.
        text = doc_wrap(render_node(parent, ""), indent=indent, width=width)
    else:
        prev = None  # Previous node
        for child in parent.childNodes:
            if child.nodeName == 'parameterlist':
                groups['params'].append(child)
            elif child.nodeName == 'xrefsect':
                groups['xrefs'].append(child)
            elif child.nodeName == 'simplesect':
                last = kind
                kind = child.getAttribute('kind')
                if kind == 'return' or (kind == 'note' and last == 'return'):
                    groups['return'].append(child)
                elif kind == 'see':
                    groups['seealso'].append(child)
                elif kind in ('note', 'warning'):
                    text += render_node(child, text, indent=indent, width=width)
                else:
                    raise RuntimeError('unhandled simplesect: {}\n{}'.format(
                        child.nodeName, child.toprettyxml(indent='  ', newl='\n')))
            else:
                if (prev is not None
                        and is_inline(self_or_child(prev))
                        and is_inline(self_or_child(child))
                        and '' != get_text(self_or_child(child)).strip()
                        and text
                        and ' ' != text[-1]):
                    text += ' '

                text += render_node(child, text, indent=indent, width=width)
                prev = child

    chunks['text'] += text

    # Generate map from the gathered items.
    if len(groups['params']) > 0:
        for child in groups['params']:
            update_params_map(child, ret_map=chunks['params'], width=width)
    for child in groups['return']:
        chunks['return'].append(render_node(
            child, '', indent=indent, width=width))
    for child in groups['seealso']:
        chunks['seealso'].append(render_node(
            child, '', indent=indent, width=width))
    for child in groups['xrefs']:
        # XXX: Add a space (or any char) to `title` here, otherwise xrefs
        # ("Deprecated" section) acts very weird...
        title = get_text(get_child(child, 'xreftitle')) + ' '
        xrefs.add(title)
        xrefdesc = get_text(get_child(child, 'xrefdescription'))
        chunks['xrefs'].append(doc_wrap(xrefdesc, prefix='{}: '.format(title),
                                        width=width) + '\n')

    return chunks


def fmt_node_as_vimhelp(parent, width=62, indent=''):
    """Renders (nested) Doxygen <para> nodes as Vim :help text.

    NB: Blank lines in a docstring manifest as <para> tags.
    """
    rendered_blocks = []

    def fmt_param_doc(m):
        """Renders a params map as Vim :help text."""
        max_name_len = max_name(m.keys()) + 4
        out = ''
        for name, desc in m.items():
            name = '    {}'.format('{{{}}}'.format(name).ljust(max_name_len))
            out += '{}{}\n'.format(name, desc)
        return out.rstrip()

    def has_nonexcluded_params(m):
        """Returns true if any of the given params has at least
        one non-excluded item."""
        if fmt_param_doc(m) != '':
            return True

    for child in parent.childNodes:
        para = para_as_map(child, indent, width)

        # Generate text from the gathered items.
        chunks = [para['text']]
        if len(para['params']) > 0 and has_nonexcluded_params(para['params']):
            chunks.append('\nParameters: ~')
            chunks.append(fmt_param_doc(para['params']))
        if len(para['return']) > 0:
            chunks.append('\nReturn: ~')
            for s in para['return']:
                chunks.append(s)
        if len(para['seealso']) > 0:
            chunks.append('\nSee also: ~')
            for s in para['seealso']:
                chunks.append(s)
        for s in para['xrefs']:
            chunks.append(s)

        rendered_blocks.append(clean_lines('\n'.join(chunks).strip()))
        rendered_blocks.append('')

    return clean_lines('\n'.join(rendered_blocks).strip())


def extract_from_xml(filename, target, width):
    """Extracts Doxygen info as maps without formatting the text.

    Returns two maps:
      1. Functions
      2. Deprecated functions

    The `fmt_vimhelp` global controls some special cases for use by
    fmt_doxygen_xml_as_vimhelp(). (TODO: ugly :)
    """
    global xrefs
    global fmt_vimhelp
    xrefs.clear()
    fns = {}  # Map of func_name:docstring.
    deprecated_fns = {}  # Map of func_name:docstring.

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

        if not fmt_vimhelp:
            pass
        else:
            fstem = '?'
            if '.' in compoundname:
                fstem = compoundname.split('.')[0]
                fstem = CONFIG[target]['module_override'].get(fstem, fstem)
            vimtag = CONFIG[target]['fn_helptag_fmt'](fstem, name)

        params = []
        type_length = 0

        for param in iter_children(member, 'param'):
            param_type = get_text(get_child(param, 'type')).strip()
            param_name = ''
            declname = get_child(param, 'declname')
            if declname:
                param_name = get_text(declname).strip()
            elif CONFIG[target]['mode'] == 'lua':
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

        c_args = []
        for param_type, param_name in params:
            c_args.append(('    ' if fmt_vimhelp else '') + (
                '%s %s' % (param_type.ljust(type_length), param_name)).strip())

        prefix = '%s(' % name
        suffix = '%s)' % ', '.join('{%s}' % a[1] for a in params
                                   if a[0] not in ('void', 'Error'))
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

        paras = []
        brief_desc = find_first(member, 'briefdescription')
        if brief_desc:
            for child in brief_desc.childNodes:
                paras.append(para_as_map(child))

        desc = find_first(member, 'detaileddescription')
        if desc:
            for child in desc.childNodes:
                paras.append(para_as_map(child))
            log.debug(
                textwrap.indent(
                    re.sub(r'\n\s*\n+', '\n',
                           desc.toprettyxml(indent='  ', newl='\n')), ' ' * 16))

        fn = {
            'annotations': list(annotations),
            'signature': signature,
            'parameters': params,
            'parameters_doc': collections.OrderedDict(),
            'doc': [],
            'return': [],
            'seealso': [],
        }
        if fmt_vimhelp:
            fn['desc_node'] = desc  # HACK :(

        for m in paras:
            if 'text' in m:
                if not m['text'] == '':
                    fn['doc'].append(m['text'])
            if 'params' in m:
                # Merge OrderedDicts.
                fn['parameters_doc'].update(m['params'])
            if 'return' in m and len(m['return']) > 0:
                fn['return'] += m['return']
            if 'seealso' in m and len(m['seealso']) > 0:
                fn['seealso'] += m['seealso']

        if INCLUDE_C_DECL:
            fn['c_decl'] = c_decl

        if 'Deprecated' in str(xrefs):
            deprecated_fns[name] = fn
        elif name.startswith(CONFIG[target]['fn_name_prefix']):
            fns[name] = fn

        xrefs.clear()

    fns = collections.OrderedDict(sorted(fns.items()))
    deprecated_fns = collections.OrderedDict(sorted(deprecated_fns.items()))
    return (fns, deprecated_fns)


def fmt_doxygen_xml_as_vimhelp(filename, target):
    """Entrypoint for generating Vim :help from from Doxygen XML.

    Returns 3 items:
      1. Vim help text for functions found in `filename`.
      2. Vim help text for deprecated functions.
    """
    global fmt_vimhelp
    fmt_vimhelp = True
    fns_txt = {}  # Map of func_name:vim-help-text.
    deprecated_fns_txt = {}  # Map of func_name:vim-help-text.
    fns, _ = extract_from_xml(filename, target, width=text_width)

    for name, fn in fns.items():
        # Generate Vim :help for parameters.
        if fn['desc_node']:
            doc = fmt_node_as_vimhelp(fn['desc_node'])
        if not doc:
            doc = 'TODO: Documentation'

        annotations = '\n'.join(fn['annotations'])
        if annotations:
            annotations = ('\n\nAttributes: ~\n' +
                           textwrap.indent(annotations, '    '))
            i = doc.rfind('Parameters: ~')
            if i == -1:
                doc += annotations
            else:
                doc = doc[:i] + annotations + '\n\n' + doc[i:]

        if INCLUDE_C_DECL:
            doc += '\n\nC Declaration: ~\n>\n'
            doc += fn['c_decl']
            doc += '\n<'

        func_doc = fn['signature'] + '\n'
        func_doc += textwrap.indent(clean_lines(doc), ' ' * 16)

        # Verbatim handling.
        func_doc = re.sub(r'^\s+([<>])$', r'\1', func_doc, flags=re.M)

        split_lines = func_doc.split('\n')
        start = 0
        while True:
            try:
                start = split_lines.index('>', start)
            except ValueError:
                break

            try:
                end = split_lines.index('<', start)
            except ValueError:
                break

            split_lines[start + 1:end] = [
                ('    ' + x).rstrip()
                for x in textwrap.dedent(
                    "\n".join(
                        split_lines[start+1:end]
                    )
                ).split("\n")
            ]

            start = end

        func_doc = "\n".join(split_lines)

        if 'Deprecated' in xrefs:
            deprecated_fns_txt[name] = func_doc
        elif name.startswith(CONFIG[target]['fn_name_prefix']):
            fns_txt[name] = func_doc

        xrefs.clear()

    fmt_vimhelp = False
    return ('\n\n'.join(list(fns_txt.values())),
            '\n\n'.join(list(deprecated_fns_txt.values())))


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


def main(config, args):
    """Generates:

    1. Vim :help docs
    2. *.mpack files for use by API clients

    Doxygen is called and configured through stdin.
    """
    for target in CONFIG:
        if args.target is not None and target != args.target:
            continue
        mpack_file = os.path.join(
            base_dir, 'runtime', 'doc',
            CONFIG[target]['filename'].replace('.txt', '.mpack'))
        if os.path.exists(mpack_file):
            os.remove(mpack_file)

        output_dir = out_dir.format(target=target)
        debug = args.log_level >= logging.DEBUG
        p = subprocess.Popen(
                ['doxygen', '-'],
                stdin=subprocess.PIPE,
                # silence warnings
                # runtime/lua/vim/lsp.lua:209: warning: argument 'foo' not found
                stderr=(subprocess.STDOUT if debug else subprocess.DEVNULL))
        p.communicate(
            config.format(
                input=CONFIG[target]['files'],
                output=output_dir,
                filter=filter_cmd,
                file_patterns=CONFIG[target]['file_patterns'])
            .encode('utf8')
        )
        if p.returncode:
            sys.exit(p.returncode)

        fn_map_full = {}  # Collects all functions as each module is processed.
        sections = {}
        intros = {}
        sep = '=' * text_width

        base = os.path.join(output_dir, 'xml')
        dom = minidom.parse(os.path.join(base, 'index.xml'))

        # generate docs for section intros
        for compound in dom.getElementsByTagName('compound'):
            if compound.getAttribute('kind') != 'group':
                continue

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

            intros[groupname] = "\n".join(doc_list)

        for compound in dom.getElementsByTagName('compound'):
            if compound.getAttribute('kind') != 'file':
                continue

            filename = get_text(find_first(compound, 'name'))
            if filename.endswith('.c') or filename.endswith('.lua'):
                xmlfile = os.path.join(base,
                                       '{}.xml'.format(compound.getAttribute('refid')))
                # Extract unformatted (*.mpack).
                fn_map, _ = extract_from_xml(xmlfile, target, width=9999)
                # Extract formatted (:help).
                functions_text, deprecated_text = fmt_doxygen_xml_as_vimhelp(
                    os.path.join(base, '{}.xml'.format(
                                 compound.getAttribute('refid'))), target)

                if not functions_text and not deprecated_text:
                    continue
                else:
                    name = os.path.splitext(
                            os.path.basename(filename))[0].lower()
                    sectname = name.upper() if name == 'ui' else name.title()
                    doc = ''
                    intro = intros.get(f'api-{name}')
                    if intro:
                        doc += '\n\n' + intro

                    if functions_text:
                        doc += '\n\n' + functions_text

                    if INCLUDE_DEPRECATED and deprecated_text:
                        doc += f'\n\n\nDeprecated {sectname} Functions: ~\n\n'
                        doc += deprecated_text

                    if doc:
                        filename = os.path.basename(filename)
                        sectname = CONFIG[target]['section_name'].get(
                                filename, sectname)
                        title = CONFIG[target]['section_fmt'](sectname)
                        helptag = CONFIG[target]['helptag_fmt'](sectname)
                        sections[filename] = (title, helptag, doc)
                        fn_map_full.update(fn_map)

        if len(sections) == 0:
            fail(f'no sections for target: {target}')
        if len(sections) > len(CONFIG[target]['section_order']):
            raise RuntimeError(
                'found new modules "{}"; update the "section_order" map'.format(
                    set(sections).difference(CONFIG[target]['section_order'])))

        docs = ''

        i = 0
        for filename in CONFIG[target]['section_order']:
            try:
                title, helptag, section_doc = sections.pop(filename)
            except KeyError:
                msg(f'warning: empty docs, skipping (target={target}): {filename}')
                continue
            i += 1
            if filename not in CONFIG[target]['append_only']:
                docs += sep
                docs += '\n%s%s' % (title,
                                    helptag.rjust(text_width - len(title)))
            docs += section_doc
            docs += '\n\n\n'

        docs = docs.rstrip() + '\n\n'
        docs += ' vim:tw=78:ts=8:ft=help:norl:\n'

        doc_file = os.path.join(base_dir, 'runtime', 'doc',
                                CONFIG[target]['filename'])

        delete_lines_below(doc_file, CONFIG[target]['section_start_token'])
        with open(doc_file, 'ab') as fp:
            fp.write(docs.encode('utf8'))

        fn_map_full = collections.OrderedDict(sorted(fn_map_full.items()))
        with open(mpack_file, 'wb') as fp:
            fp.write(msgpack.packb(fn_map_full, use_bin_type=True))

        if not args.keep_tmpfiles:
            shutil.rmtree(output_dir)

    msg_report()


def filter_source(filename):
    name, extension = os.path.splitext(filename)
    if extension == '.lua':
        p = subprocess.run([lua2dox_filter, filename], stdout=subprocess.PIPE)
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
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--log-level", "-l", choices=LOG_LEVELS.keys(),
        default=logging.getLevelName(logging.ERROR), help="Set log verbosity"
    )
    ap.add_argument('source_filter', nargs='*',
                    help="Filter source file(s)")
    ap.add_argument('-k', '--keep-tmpfiles', action='store_true',
                    help="Keep temporary files")
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
    EXCLUDE_PATTERNS       = */private/*
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

    if len(args.source_filter) > 0:
        filter_source(args.source_filter[0])
    else:
        main(Doxyfile, args)

# vim: set ft=python ts=4 sw=4 tw=79 et :
