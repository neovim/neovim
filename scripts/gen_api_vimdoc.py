#!/usr/bin/env python3
"""Parses Doxygen XML output to generate Neovim's API documentation.

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

from xml.dom import minidom

if sys.version_info[0] < 3:
    print("use Python 3")
    sys.exit(1)

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


def doc_wrap(text, prefix='', width=70, func=False):
    """Wraps text to `width`.

    The first line is prefixed with `prefix`, and subsequent lines are aligned.
    If `func` is True, only wrap at commas.
    """
    if not width:
        return text

    indent_space = ' ' * len(prefix)

    if func:
        lines = [prefix]
        for part in text.split(', '):
            if part[-1] not in ');':
                part += ', '
            if len(lines[-1]) + len(part) > width:
                lines.append(indent_space)
            lines[-1] += part
        return '\n'.join(x.rstrip() for x in lines).rstrip()

    tw = textwrap.TextWrapper(break_long_words = False,
                              break_on_hyphens = False,
                              width=width,
                              initial_indent=prefix,
                              subsequent_indent=indent_space)
    return '\n'.join(tw.wrap(text.strip()))


def parse_params(parent, width=62):
    """Parse Doxygen `parameterlist`."""
    name_length = 0
    items = []
    for child in parent.childNodes:
        if child.nodeType == child.TEXT_NODE:
            continue

        name_node = find_first(child, 'parametername')
        if name_node.getAttribute('direction') == 'out':
            continue

        name = get_text(name_node)
        if name in param_exclude:
            continue

        name = '{%s}' % name
        name_length = max(name_length, len(name) + 2)

        desc = ''
        desc_node = get_child(child, 'parameterdescription')
        if desc_node:
            desc = parse_parblock(desc_node, width=None)
        items.append((name.strip(), desc.strip()))

    out = 'Parameters: ~\n'
    for name, desc in items:
        name = '    %s' % name.ljust(name_length)
        out += doc_wrap(desc, prefix=name, width=width) + '\n'
    return out.strip()


def parse_para(parent, width=62):
    """Parse doxygen `para` tag.

    I assume <para> is a paragraph block or "a block of text".  It can contain
    text nodes, or other tags.
    """
    line = ''
    lines = []
    for child in parent.childNodes:
        if child.nodeType == child.TEXT_NODE:
            line += child.data
        elif child.nodeName == 'computeroutput':
            line += '`%s`' % get_text(child)
        else:
            if line:
                lines.append(doc_wrap(line, width=width))
                line = ''

            if child.nodeName == 'parameterlist':
                lines.append(parse_params(child, width=width))
            elif child.nodeName == 'xrefsect':
                title = get_text(get_child(child, 'xreftitle'))
                xrefs.add(title)
                xrefdesc = parse_para(get_child(child, 'xrefdescription'))
                lines.append(doc_wrap(xrefdesc, prefix='%s: ' % title,
                                      width=width) + '\n')
            elif child.nodeName == 'simplesect':
                kind = child.getAttribute('kind')
                if kind == 'note':
                    lines.append('Note:')
                    lines.append(doc_wrap(parse_para(child),
                                          prefix='    ',
                                          width=width))
                elif kind == 'return':
                    lines.append('%s: ~' % kind.title())
                    lines.append(doc_wrap(parse_para(child),
                                          prefix='    ',
                                          width=width))
            else:
                lines.append(get_text(child))

    if line:
        lines.append(doc_wrap(line, width=width))
    return clean_lines('\n'.join(lines).strip())


def parse_parblock(parent, width=62):
    """Parses a nested block of `para` tags.

    Named after the \parblock command, but not directly related.
    """
    paragraphs = []
    for child in parent.childNodes:
        if child.nodeType == child.TEXT_NODE:
            paragraphs.append(doc_wrap(child.data, width=width))
        elif child.nodeName == 'para':
            paragraphs.append(parse_para(child, width=width))
        else:
            paragraphs.append(doc_wrap(get_text(child), width=width))
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
            return_type = '%s(%s)' % (parts[0], ', '.join(parts[1:]))

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

        vimtag = '*%s()*' % name
        args = []
        type_length = 0

        for param in get_children(member, 'param'):
            arg_type = get_text(get_child(param, 'type')).strip()
            arg_name = ''
            declname = get_child(param, 'declname')
            if declname:
                arg_name = get_text(declname).strip()

            if arg_name in param_exclude:
                continue

            if arg_type.endswith('*'):
                arg_type = arg_type.strip('* ')
                arg_name = '*' + arg_name
            type_length = max(type_length, len(arg_type))
            args.append((arg_type, arg_name))

        c_args = []
        for arg_type, arg_name in args:
            c_args.append('    ' + (
                '%s %s' % (arg_type.ljust(type_length), arg_name)).strip())

        c_decl = textwrap.indent('%s %s(\n%s\n);' % (return_type, name,
                                                     ',\n'.join(c_args)),
                                 '    ')

        prefix = '%s(' % name
        suffix = '%s)' % ', '.join('{%s}' % a[1] for a in args
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
            if 'DEBUG' in os.environ:
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

        if 'INCLUDE_C_DECL' in os.environ:
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

                if 'INCLUDE_DEPRECATED' in os.environ and deprecated:
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
'''
# }}}

if __name__ == "__main__":
    if len(sys.argv) > 1:
        filter_source(sys.argv[1])
    else:
        gen_docs(Doxyfile)

# vim: set ft=python ts=4 sw=4 tw=79 et fdm=marker :
