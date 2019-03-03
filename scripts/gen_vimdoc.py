#!/usr/bin/env python3
"""Generates Nvim help docs from C docstrings, by parsing Doxygen XML.

This would be easier using lxml and XSLT, but:

  1. This should avoid needing Python dependencies, especially ones that are
     C modules that have library dependencies (lxml requires libxml and
     libxslt).
  2. I wouldn't know how to deal with nested indentation in <para> tags using
     XSLT.

Each function documentation is formatted with the following rules:

  - Maximum width of 78 characters (`text_width`).
  - Spaces for indentation.
  - Function signature and helptag are on the same line.
    - Helptag is right aligned.
    - Signature and helptag must have a minimum of 8 spaces between them.
    - If the signature is too long, it is placed on the line after the
      helptag.  The signature wraps at `text_width - 8` characters with
      subsequent lines indented to the open parenthesis.
  - Documentation body will be indented by 16 spaces.
    - Subsection bodies are indented an additional 4 spaces.
  - Documentation body consists of the function description, parameter details,
    return description, and C declaration.
  - Parameters are omitted for the `void` and `Error *` types, or if the
    parameter is marked as [out].
  - Each function documentation is separated by a single line.

The C declaration is added to the end to show actual argument types.
"""
import os
import re
import sys
import shutil
import textwrap
import subprocess
import collections
import pprint

from xml.dom import minidom

if sys.version_info[0] < 3:
    print("use Python 3")
    sys.exit(1)

DEBUG = ('DEBUG' in os.environ)
INCLUDE_C_DECL = ('INCLUDE_C_DECL' in os.environ)
INCLUDE_DEPRECATED = ('INCLUDE_DEPRECATED' in os.environ)

doc_filename = 'api.txt'
# String used to find the start of the generated part of the doc.
section_start_token = '*api-global*'
# Required prefix for API function names.
api_func_name_prefix = 'nvim_'

# Section name overrides.
section_name = {
    'vim.c': 'Global',
}

# Section ordering.
section_order = (
    'vim.c',
    'buffer.c',
    'window.c',
    'tabpage.c',
    'ui.c',
)

param_exclude = (
    'channel_id',
)

# Annotations are displayed as line items after API function descriptions.
annotation_map = {
    'FUNC_API_ASYNC': '{async}',
}

text_width = 78
script_path = os.path.abspath(__file__)
base_dir = os.path.dirname(os.path.dirname(script_path))
src_dir = os.path.join(base_dir, 'src/nvim/api')
out_dir = os.path.join(base_dir, 'tmp-api-doc')
filter_cmd = '%s %s' % (sys.executable, script_path)
seen_funcs = set()

# Tracks `xrefsect` titles.  As of this writing, used only for separating
# deprecated functions.
xrefs = set()

def debug_this(s, n):
    o = n if isinstance(n, str) else n.toprettyxml(indent='  ', newl='\n')
    name = '' if isinstance(n, str) else n.nodeName
    if s in o:
        raise RuntimeError('xxx: {}\n{}'.format(name, o))


# XML Parsing Utilities {{{
def find_first(parent, name):
    """Finds the first matching node within parent."""
    sub = parent.getElementsByTagName(name)
    if not sub:
        return None
    return sub[0]


def get_children(parent, name):
    """Yield matching child nodes within parent."""
    for child in parent.childNodes:
        if child.nodeType == child.ELEMENT_NODE and child.nodeName == name:
            yield child


def get_child(parent, name):
    """Get the first matching child node."""
    for child in get_children(parent, name):
        return child
    return None


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


def get_text(parent):
    """Combine all text in a node."""
    if parent.nodeType == parent.TEXT_NODE:
        return parent.data

    out = ''
    for node in parent.childNodes:
        if node.nodeType == node.TEXT_NODE:
            out += clean_text(node.data)
        elif node.nodeType == node.ELEMENT_NODE:
            out += ' ' + get_text(node)
    return out


# Gets the length of the last line in `text`, excluding newline ("\n") char.
def len_lastline(text):
    lastnl = text.rfind('\n')
    if -1 == lastnl:
        return len(text)
    if '\n' == text[-1]:
        return lastnl - (1+ text.rfind('\n', 0, lastnl))
    return len(text) - (1 + lastnl)


def len_lastline_withoutindent(text, indent):
    n = len_lastline(text)
    return (n - len(indent)) if n > len(indent) else 0


# Returns True if node `n` contains only inline (not block-level) elements.
def is_inline(n):
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

    tw = textwrap.TextWrapper(break_long_words = False,
                              break_on_hyphens = False,
                              width=width,
                              initial_indent=prefix,
                              subsequent_indent=indent)
    result = '\n'.join(tw.wrap(text.strip()))

    # XXX: Remove the dummy prefix.
    if indent_only:
        result = result[len(indent):]

    return result


def render_params(parent, width=62):
    """Renders Doxygen <parameterlist> tag as Vim help text."""
    name_length = 0
    items = []
    for node in parent.childNodes:
        if node.nodeType == node.TEXT_NODE:
            continue

        name_node = find_first(node, 'parametername')
        if name_node.getAttribute('direction') == 'out':
            continue

        name = get_text(name_node)
        if name in param_exclude:
            continue

        name = '{%s}' % name
        name_length = max(name_length, len(name) + 2)
        items.append((name.strip(), node))

    out = ''
    for name, node in items:
        name = '    {}'.format(name.ljust(name_length))

        desc = ''
        desc_node = get_child(node, 'parameterdescription')
        if desc_node:
            desc = parse_parblock(desc_node, width=width,
                    indent=(' ' * len(name)))

        out += '{}{}\n'.format(name, desc)
    return out.rstrip()

# Renders a node as Vim help text, recursively traversing all descendants.
def render_node(n, text, prefix='', indent='', width=62):
    text = ''
    # space_preceding = (len(text) > 0 and ' ' == text[-1][-1])
    # text += (int(not space_preceding) * ' ')

    if n.nodeType == n.TEXT_NODE:
        # `prefix` is NOT sent to doc_wrap, it was already handled by now.
        text += doc_wrap(n.data, indent=indent, width=width)
    elif n.nodeName == 'computeroutput':
        text += ' `{}` '.format(get_text(n))
    elif is_inline(n):
        for c in n.childNodes:
            text += render_node(c, text)
        text = doc_wrap(text, indent=indent, width=width)
    elif n.nodeName == 'verbatim':
        # TODO: currently we don't use this. The "[verbatim]" hint is there as
        # a reminder that we must decide how to format this if we do use it.
        text += ' [verbatim] {}'.format(get_text(n))
    elif n.nodeName == 'listitem':
        for c in n.childNodes:
            text += indent + prefix + render_node(c, text, indent=indent+(' ' * len(prefix)), width=width)
    elif n.nodeName == 'para':
        for c in n.childNodes:
            text += render_node(c, text, indent=indent, width=width)
        if is_inline(n):
            text = doc_wrap(text, indent=indent, width=width)
    elif n.nodeName == 'itemizedlist':
        for c in n.childNodes:
            text += '{}\n'.format(render_node(c, text, prefix='- ',
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
        text += 'Note:\n    '
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
        text += '    '
        for c in n.childNodes:
            text += render_node(c, text, indent='    ', width=width)
    else:
        raise RuntimeError('unhandled node type: {}\n{}'.format(
            n.nodeName, n.toprettyxml(indent='  ', newl='\n')))
    return text

def render_para(parent, indent='', width=62):
    """Renders Doxygen <para> containing arbitrary nodes.

    NB: Blank lines in a docstring manifest as <para> tags.
    """
    if is_inline(parent):
        return clean_lines(doc_wrap(render_node(parent, ''),
            indent=indent, width=width).strip())

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
            text += render_node(child, text, indent=indent, width=width)

    chunks = [text]
    # Generate text from the gathered items.
    if len(groups['params']) > 0:
        chunks.append('\nParameters: ~')
        for child in groups['params']:
            chunks.append(render_params(child, width=width))
    if len(groups['return']) > 0:
        chunks.append('\nReturn: ~')
        for child in groups['return']:
            chunks.append(render_node(child, chunks[-1][-1], indent=indent, width=width))
    if len(groups['seealso']) > 0:
        chunks.append('\nSee also: ~')
        for child in groups['seealso']:
            chunks.append(render_node(child, chunks[-1][-1], indent=indent, width=width))
    for child in groups['xrefs']:
        title = get_text(get_child(child, 'xreftitle'))
        xrefs.add(title)
        xrefdesc = render_para(get_child(child, 'xrefdescription'), width=width)
        chunks.append(doc_wrap(xrefdesc, prefix='{}: '.format(title),
                              width=width) + '\n')

    return clean_lines('\n'.join(chunks).strip())


def parse_parblock(parent, prefix='', width=62, indent=''):
    """Renders a nested block of <para> tags as Vim help text."""
    paragraphs = []
    for child in parent.childNodes:
        paragraphs.append(render_para(child, width=width, indent=indent))
        paragraphs.append('')
    return clean_lines('\n'.join(paragraphs).strip())
# }}}


def parse_source_xml(filename):
    """Collects API functions.

    Returns two strings:
      1. API functions
      2. Deprecated API functions

    Caller decides what to do with the deprecated documentation.
    """
    global xrefs
    xrefs = set()
    functions = []
    deprecated_functions = []

    dom = minidom.parse(filename)
    for member in dom.getElementsByTagName('memberdef'):
        if member.getAttribute('static') == 'yes' or \
                member.getAttribute('kind') != 'function':
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
            annotations += 'FUNC_API_ASYNC'
        annotations = filter(None, map(lambda x: annotation_map.get(x),
                                       annotations.split()))

        vimtag = '*{}()*'.format(name)
        params = []
        type_length = 0

        for param in get_children(member, 'param'):
            param_type = get_text(get_child(param, 'type')).strip()
            param_name = ''
            declname = get_child(param, 'declname')
            if declname:
                param_name = get_text(declname).strip()

            if param_name in param_exclude:
                continue

            if param_type.endswith('*'):
                param_type = param_type.strip('* ')
                param_name = '*' + param_name
            type_length = max(type_length, len(param_type))
            params.append((param_type, param_name))

        c_args = []
        for param_type, param_name in params:
            c_args.append('    ' + (
                '%s %s' % (param_type.ljust(type_length), param_name)).strip())

        c_decl = textwrap.indent('%s %s(\n%s\n);' % (return_type, name,
                                                     ',\n'.join(c_args)),
                                 '    ')

        prefix = '%s(' % name
        suffix = '%s)' % ', '.join('{%s}' % a[1] for a in params
                                   if a[0] not in ('void', 'Error'))

        # Minimum 8 chars between signature and vimtag
        lhs = (text_width - 8) - len(prefix)

        if len(prefix) + len(suffix) > lhs:
            signature = vimtag.rjust(text_width) + '\n'
            signature += doc_wrap(suffix, width=text_width-8, prefix=prefix,
                                  func=True)
        else:
            signature = prefix + suffix
            signature += vimtag.rjust(text_width - len(signature))

        doc = ''
        desc = find_first(member, 'detaileddescription')
        if desc:
            doc = parse_parblock(desc)
            if DEBUG:
                print(textwrap.indent(
                    re.sub(r'\n\s*\n+', '\n',
                           desc.toprettyxml(indent='  ', newl='\n')), ' ' * 16))

        if not doc:
            doc = 'TODO: Documentation'

        annotations = '\n'.join(annotations)
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
            doc += c_decl
            doc += '\n<'

        func_doc = signature + '\n'
        func_doc += textwrap.indent(clean_lines(doc), ' ' * 16)
        func_doc = re.sub(r'^\s+([<>])$', r'\1', func_doc, flags=re.M)

        if 'Deprecated' in xrefs:
            deprecated_functions.append(func_doc)
        elif name.startswith(api_func_name_prefix):
            functions.append(func_doc)

        xrefs.clear()

    return '\n\n'.join(functions), '\n\n'.join(deprecated_functions)


def delete_lines_below(filename, tokenstr):
    """Deletes all lines below the line containing `tokenstr`, the line itself,
    and one line above it.
    """
    lines = open(filename).readlines()
    i = 0
    for i, line in enumerate(lines, 1):
        if tokenstr in line:
            break
    i = max(0, i - 2)
    with open(filename, 'wt') as fp:
        fp.writelines(lines[0:i])

def gen_docs(config):
    """Generate documentation.

    Doxygen is called and configured through stdin.
    """
    p = subprocess.Popen(['doxygen', '-'], stdin=subprocess.PIPE)
    p.communicate(config.format(input=src_dir, output=out_dir,
                                filter=filter_cmd).encode('utf8'))
    if p.returncode:
        sys.exit(p.returncode)

    sections = {}
    intros = {}
    sep = '=' * text_width

    base = os.path.join(out_dir, 'xml')
    dom = minidom.parse(os.path.join(base, 'index.xml'))

    # generate docs for section intros
    for compound in dom.getElementsByTagName('compound'):
        if compound.getAttribute('kind') != 'group':
            continue

        groupname = get_text(find_first(compound, 'name'))
        groupxml = os.path.join(base, '%s.xml' % compound.getAttribute('refid'))

        desc = find_first(minidom.parse(groupxml), 'detaileddescription')
        if desc:
            doc = parse_parblock(desc)
            if doc:
                intros[groupname] = doc

    for compound in dom.getElementsByTagName('compound'):
        if compound.getAttribute('kind') != 'file':
            continue

        filename = get_text(find_first(compound, 'name'))
        if filename.endswith('.c'):
            functions, deprecated = parse_source_xml(
                os.path.join(base, '%s.xml' % compound.getAttribute('refid')))

            if not functions and not deprecated:
                continue

            if functions or deprecated:
                name = os.path.splitext(os.path.basename(filename))[0]
                if name == 'ui':
                    name = name.upper()
                else:
                    name = name.title()

                doc = ''

                intro = intros.get('api-%s' % name.lower())
                if intro:
                    doc += '\n\n' + intro

                if functions:
                    doc += '\n\n' + functions

                if INCLUDE_DEPRECATED and deprecated:
                    doc += '\n\n\nDeprecated %s Functions: ~\n\n' % name
                    doc += deprecated

                if doc:
                    filename = os.path.basename(filename)
                    name = section_name.get(filename, name)
                    title = '%s Functions' % name
                    helptag = '*api-%s*' % name.lower()
                    sections[filename] = (title, helptag, doc)

    if not sections:
        return

    docs = ''

    i = 0
    for filename in section_order:
        if filename not in sections:
            continue
        title, helptag, section_doc = sections.pop(filename)

        i += 1
        docs += sep
        docs += '\n%s%s' % (title, helptag.rjust(text_width - len(title)))
        docs += section_doc
        docs += '\n\n\n'

    if sections:
        # In case new API sources are added without updating the order dict.
        for title, helptag, section_doc in sections.values():
            i += 1
            docs += sep
            docs += '\n%s%s' % (title, helptag.rjust(text_width - len(title)))
            docs += section_doc
            docs += '\n\n\n'

    docs = docs.rstrip() + '\n\n'
    docs += ' vim:tw=78:ts=8:ft=help:norl:\n'

    doc_file = os.path.join(base_dir, 'runtime/doc', doc_filename)
    delete_lines_below(doc_file, section_start_token)
    with open(doc_file, 'ab') as fp:
        fp.write(docs.encode('utf8'))
    shutil.rmtree(out_dir)


def filter_source(filename):
    """Filters the source to fix macros that confuse Doxygen."""
    with open(filename, 'rt') as fp:
        print(re.sub(r'^(ArrayOf|DictionaryOf)(\(.*?\))',
                     lambda m: m.group(1)+'_'.join(
                         re.split(r'[^\w]+', m.group(2))),
                     fp.read(), flags=re.M))


# Doxygen Config {{{
Doxyfile = '''
OUTPUT_DIRECTORY       = {output}
INPUT                  = {input}
INPUT_ENCODING         = UTF-8
FILE_PATTERNS          = *.h *.c
RECURSIVE              = YES
INPUT_FILTER           = "{filter}"
EXCLUDE                =
EXCLUDE_SYMLINKS       = NO
EXCLUDE_PATTERNS       = */private/*
EXCLUDE_SYMBOLS        =

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
'''
# }}}

if __name__ == "__main__":
    if len(sys.argv) > 1:
        filter_source(sys.argv[1])
    else:
        gen_docs(Doxyfile)

# vim: set ft=python ts=4 sw=4 tw=79 et fdm=marker :
