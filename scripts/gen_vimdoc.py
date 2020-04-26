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

TODO:
- Handle defs like 'vim.g' and others getting generated

- Handle local functions being exported, even though they should not be
    - I think I fixed this, but there is a new problem

    ```lua
    local function do_x()
    end

    return {
      do_stuff = do_x
    }
    ```
"""

import argparse
import collections
import os
import re
import shutil
import subprocess
import sys
import textwrap
from typing import Any
from typing import Dict
from xml.dom import minidom

try:
    import msgpack
except ImportError:
    print("package 'msgpack' is required to run the script", file=sys.stderr)
    sys.exit(1)

if sys.version_info[0] < 3 or sys.version_info[1] < 5:
    print("requires Python 3.5+", file=sys.stderr)
    sys.exit(1)

script_path = os.path.abspath(__file__)
base_dir = os.path.dirname(os.path.dirname(script_path))
out_dir = os.path.join(base_dir, "tmp-{target}-doc")
filter_cmd = "{} {}".format(
    sys.executable, os.path.join(base_dir, "scripts", "vim2dox_filter.py")
)
lua2dox_filter = os.path.join(base_dir, "scripts", "lua2dox_filter")

if not shutil.which("doxygen"):
    print("Missing Requirement: doxygen", file=sys.stderr)
    sys.exit(1)

if not any(
    shutil.which(x)
    for x in {
        "./.deps/usr/bin/luajit",
        "./.deps/usr/bin/lua",
        "lua",
        "luajit",
        "texlua",
    }
):
    print("Missing Requirement: Need lua or luajit", file=sys.stderr)
    sys.exit(1)

if subprocess.run([lua2dox_filter, "--test"]).returncode:
    print("Failed to execute: ", f"$ {lua2dox_filter} --test", file=sys.stderr)
    sys.exit(1)

# TODO: Why are we just checking if they are in the environ or not,
#       instead of checking their values?
DEBUG = "DEBUG" in os.environ
TARGET = os.environ.get("TARGET", None)
INCLUDE_C_DECL = "INCLUDE_C_DECL" in os.environ
INCLUDE_DEPRECATED = "INCLUDE_DEPRECATED" in os.environ

fmt_vimhelp = False  # HACK
text_width = 78

# TODO: Figure out the right type for this.
# TypeDom = minidom.Document
TypeDom = Any


# fmt: off
CONFIG: Dict[str, Any] = {
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
        ],
        'files': ' '.join([
            os.path.join(base_dir, 'src/nvim/lua/vim.lua'),
            os.path.join(base_dir, 'runtime/lua/vim/shared.lua'),
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
        },
        'append_only': [
            'shared.lua',
        ],
        # TODO(tjdevries): local function exclusion
        'excluded_symbols': [
            'make_meta_accessor',
        ],
    },
    'lsp': {
        'mode': 'lua',
        'filename': 'lsp.txt',
        'section_start_token': '*lsp-core*',
        'section_order': [
            'lsp.lua',
            'protocol.lua',
            'buf.lua',
            'callbacks.lua',
            'log.lua',
            'rpc.lua',
            'util.lua'
        ],
        'files': ' '.join([
            os.path.join(base_dir, 'runtime/lua/vim/lsp'),
            os.path.join(base_dir, 'runtime/lua/vim/lsp.lua'),
        ]),
        'file_patterns': '*.lua',
        'fn_name_prefix': '',
        'section_name': {},
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
# fmt: on

param_exclude = ("channel_id",)

# Annotations are displayed as line items after API function descriptions.
annotation_map = {
    "FUNC_API_FAST": "{fast}",
}


# Tracks `xrefsect` titles.  As of this writing, used only for separating
# deprecated functions.
xrefs = set()


# Raises an error with details about `o`, if `cond` is in object `o`,
# or if `cond()` is callable and returns True.
def debug_this(cond, o):
    name = ""
    if not isinstance(o, str):
        try:
            name = o.nodeName
            o = o.toprettyxml(indent="  ", newl="\n")
        except Exception:
            pass

    if (
        (callable(cond) and cond())
        or (not callable(cond) and cond)
        or (not callable(cond) and cond in o)
    ):
        raise RuntimeError("xxx: {}\n{}".format(name, o))


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
    return next(iter_children(parent, name), None)


def self_or_child(n):
    """Gets the first child node, or self."""
    if len(n.childNodes) == 0:
        return n
    return n.childNodes[0]


def clean_text(text):
    """Cleans text.

    Only cleans superfluous whitespace at the moment.
    """
    return " ".join(text.split()).strip()


def clean_lines(text):
    """Removes superfluous lines.

    The beginning and end of the string is trimmed.  Empty lines are collapsed.
    """
    return re.sub(
        r"\A\n\s*\n*|\n\s*\n*\Z", "", re.sub(r"(\n\s*\n+)+", "\n\n", text)
    )


def is_blank(text):
    return "" == clean_lines(text)


def get_text(n, preformatted=False):
    """Recursively concatenates all text in a node tree."""
    text = ""
    if n.nodeType == n.TEXT_NODE:
        return n.data
    if n.nodeName == "computeroutput":
        for node in n.childNodes:
            text += get_text(node)
        return "`{}` ".format(text)
    for node in n.childNodes:
        if node.nodeType == node.TEXT_NODE:
            text += node.data if preformatted else clean_text(node.data)
        elif node.nodeType == node.ELEMENT_NODE:
            text += " " + get_text(node, preformatted)
    return text


# Gets the length of the last line in `text`, excluding newline ("\n") char.
def len_lastline(text):
    lastnl = text.rfind("\n")
    if -1 == lastnl:
        return len(text)
    if "\n" == text[-1]:
        return lastnl - (1 + text.rfind("\n", 0, lastnl))
    return len(text) - (1 + lastnl)


def len_lastline_withoutindent(text, indent):
    n = len_lastline(text)
    return (n - len(indent)) if n > len(indent) else 0


# Returns True if node `n` contains only inline (not block-level) elements.
def is_inline(n):
    # if len(n.childNodes) == 0:
    #     return n.nodeType == n.TEXT_NODE or n.nodeName == 'computeroutput'
    for c in n.childNodes:
        if c.nodeType != c.TEXT_NODE and c.nodeName != "computeroutput":
            return False
        if not is_inline(c):
            return False
    return True


def doc_wrap(text, prefix="", width=70, func=False, indent=None):
    """Wraps text to `width`.

    First line is prefixed with `prefix`, subsequent lines are aligned.
    If `func` is True, only wrap at commas.
    """
    if not width:
        # return prefix + text
        return text

    # Whitespace used to indent all lines except the first line.
    indent = " " * len(prefix) if indent is None else indent
    indent_only = prefix == "" and indent is not None

    if func:
        lines = [prefix]
        for part in text.split(", "):
            if part[-1] not in ");":
                part += ", "
            if len(lines[-1]) + len(part) > width:
                lines.append(indent)
            lines[-1] += part
        return "\n".join(x.rstrip() for x in lines).rstrip()

    # XXX: Dummy prefix to force TextWrapper() to wrap the first line.
    if indent_only:
        prefix = indent

    tw = textwrap.TextWrapper(
        break_long_words=False,
        break_on_hyphens=False,
        width=width,
        initial_indent=prefix,
        subsequent_indent=indent,
    )
    result = "\n".join(tw.wrap(text.strip()))

    # XXX: Remove the dummy prefix.
    if indent_only:
        result = result[len(indent) :]

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
        name_node = find_first(node, "parametername")
        if name_node.getAttribute("direction") == "out":
            continue
        name = get_text(name_node)
        if name in param_exclude:
            continue
        params[name.strip()] = node
    max_name_len = max_name(params.keys()) + 8
    # `ret_map` is a name:desc map.
    for name, node in params.items():
        desc = ""
        desc_node = get_child(node, "parameterdescription")
        if desc_node:
            desc = fmt_node_as_vimhelp(
                desc_node, width=width, indent=(" " * max_name_len)
            )
            ret_map[name] = desc
    return ret_map


def render_node(n, text, prefix="", indent="", width=62):
    """Renders a node as Vim help text, recursively traversing all descendants."""
    global fmt_vimhelp

    def ind(s):
        return s if fmt_vimhelp else ""

    text = ""
    # space_preceding = (len(text) > 0 and ' ' == text[-1][-1])
    # text += (int(not space_preceding) * ' ')

    if n.nodeName == "preformatted":
        o = get_text(n, preformatted=True)
        ensure_nl = "" if o[-1] == "\n" else "\n"
        text += ">{}{}\n<".format(ensure_nl, o)
    elif is_inline(n):
        text = doc_wrap(get_text(n), indent=indent, width=width)
    elif n.nodeName == "verbatim":
        # TODO: currently we don't use this. The "[verbatim]" hint is there as
        # a reminder that we must decide how to format this if we do use it.
        text += " [verbatim] {}".format(get_text(n))
    elif n.nodeName == "listitem":
        for c in n.childNodes:
            result = render_node(
                c, text, indent=indent + (" " * len(prefix)), width=width
            )

            # It's possible to get empty list items, so we should skip them.
            if is_blank(result):
                continue

            text += indent + prefix + result
    elif n.nodeName in ("para", "heading"):
        for c in n.childNodes:
            text += render_node(c, text, indent=indent, width=width)
    elif n.nodeName == "itemizedlist":
        for c in n.childNodes:
            text += "{}\n".format(
                render_node(c, text, prefix="• ", indent=indent, width=width)
            )
    elif n.nodeName == "orderedlist":
        i = 1
        for c in n.childNodes:
            if is_blank(get_text(c)):
                text += "\n"
                continue
            text += "{}\n".format(
                render_node(
                    c,
                    text,
                    prefix="{}. ".format(i),
                    indent=indent,
                    width=width,
                )
            )
            i = i + 1
    elif n.nodeName == "simplesect" and "note" == n.getAttribute("kind"):
        text += "Note:\n    "
        for c in n.childNodes:
            text += render_node(c, text, indent="    ", width=width)
        text += "\n"
    elif n.nodeName == "simplesect" and "warning" == n.getAttribute("kind"):
        text += "Warning:\n    "
        for c in n.childNodes:
            text += render_node(c, text, indent="    ", width=width)
        text += "\n"
    elif n.nodeName == "simplesect" and n.getAttribute("kind") in (
        "return",
        "see",
    ):
        text += ind("    ")
        for c in n.childNodes:
            text += render_node(c, text, indent="    ", width=width)
    else:
        raise RuntimeError(
            "unhandled node type: {}\n{}".format(
                n.nodeName, n.toprettyxml(indent="  ", newl="\n")
            )
        )

    return text


def para_as_map(parent, indent="", width=62):
    """Extracts a Doxygen XML <para> node to a map.

    Keys:
        'text': Text from this <para> element
        'params': <parameterlist> map
        'return': List of @return strings
        'seealso': List of @see strings
        'xrefs': ?
    """
    chunks = {
        "text": "",
        "params": collections.OrderedDict(),
        "return": [],
        "seealso": [],
        "xrefs": [],
    }

    # Ordered dict of ordered lists.
    groups = collections.OrderedDict(
        [("params", []), ("return", []), ("seealso", []), ("xrefs", [])]
    )

    # Gather nodes into groups.  Mostly this is because we want "parameterlist"
    # nodes to appear together.
    text = ""
    kind = ""
    last = ""
    if is_inline(parent):
        # Flatten inline text from a tree of non-block nodes.
        text = doc_wrap(render_node(parent, ""), indent=indent, width=width)
    else:
        prev = None  # Previous node
        for child in parent.childNodes:
            if child.nodeName == "parameterlist":
                groups["params"].append(child)
            elif child.nodeName == "xrefsect":
                groups["xrefs"].append(child)
            elif child.nodeName == "simplesect":
                last = kind
                kind = child.getAttribute("kind")
                if kind == "return" or (kind == "note" and last == "return"):
                    groups["return"].append(child)
                elif kind == "see":
                    groups["seealso"].append(child)
                elif kind in ("note", "warning"):
                    text += render_node(
                        child, text, indent=indent, width=width
                    )
                else:
                    raise RuntimeError(
                        "unhandled simplesect: {}\n{}".format(
                            child.nodeName,
                            child.toprettyxml(indent="  ", newl="\n"),
                        )
                    )
            else:
                # if not text:
                #     assert False, get_text(parent)

                if (
                    prev is not None
                    and is_inline(self_or_child(prev))
                    and is_inline(self_or_child(child))
                    and "" != get_text(self_or_child(child)).strip()
                    and (text and " " != text[-1])
                ):
                    text += " "
                text += render_node(child, text, indent=indent, width=width)
                prev = child

    chunks["text"] += text

    # Generate map from the gathered items.
    if len(groups["params"]) > 0:
        for child in groups["params"]:
            update_params_map(child, ret_map=chunks["params"], width=width)
    for child in groups["return"]:
        chunks["return"].append(
            render_node(child, "", indent=indent, width=width)
        )
    for child in groups["seealso"]:
        chunks["seealso"].append(
            render_node(child, "", indent=indent, width=width)
        )
    for child in groups["xrefs"]:
        # XXX: Add a space (or any char) to `title` here, otherwise xrefs
        # ("Deprecated" section) acts very weird...
        title = get_text(get_child(child, "xreftitle")) + " "
        xrefs.add(title)
        xrefdesc = get_text(get_child(child, "xrefdescription"))
        chunks["xrefs"].append(
            doc_wrap(xrefdesc, prefix="{}: ".format(title), width=width) + "\n"
        )

    return chunks


def fmt_node_as_vimhelp(parent, width=62, indent=""):
    """Renders (nested) Doxygen <para> nodes as Vim :help text.

    NB: Blank lines in a docstring manifest as <para> tags.
    """
    rendered_blocks = []

    def fmt_param_doc(m):
        """Renders a params map as Vim :help text."""
        max_name_len = max_name(m.keys()) + 4
        out = ""
        for name, desc in m.items():
            name = "    {}".format("{{{}}}".format(name).ljust(max_name_len))
            out += "{}{}\n".format(name, desc)
        return out.rstrip()

    def has_nonexcluded_params(m):
        """Returns true if any of the given params has at least
        one non-excluded item."""
        if fmt_param_doc(m) != "":
            return True

    for child in parent.childNodes:
        para = para_as_map(child, indent, width)

        # Generate text from the gathered items.
        chunks = [para["text"]]
        if len(para["params"]) > 0 and has_nonexcluded_params(para["params"]):
            chunks.append("\nParameters: ~")
            chunks.append(fmt_param_doc(para["params"]))
        if len(para["return"]) > 0:
            chunks.append("\nReturn: ~")
            for s in para["return"]:
                chunks.append(s)
        if len(para["seealso"]) > 0:
            chunks.append("\nSee also: ~")
            for s in para["seealso"]:
                chunks.append(s)
        for s in para["xrefs"]:
            chunks.append(s)

        rendered_blocks.append(clean_lines("\n".join(chunks).strip()))
        rendered_blocks.append("")
    return clean_lines("\n".join(rendered_blocks).strip())


def extract_from_xml(dom, target_config, width):
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

    # Map of func_name:docstring.
    fns = {}
    deprecated_fns = {}

    compoundname = get_text(dom.getElementsByTagName("compoundname")[0])
    for member in dom.getElementsByTagName("memberdef"):
        if (
            member.getAttribute("static") == "yes"
            or member.getAttribute("kind") != "function"
            or member.getAttribute("prot") == "private"
            or get_text(get_child(member, "name")).startswith("_")
        ):
            continue

        loc = find_first(member, "location")
        if "private" in loc.getAttribute("file"):
            continue

        return_type = get_text(get_child(member, "type"))
        if return_type == "":
            continue

        if return_type.startswith(("ArrayOf", "DictionaryOf")):
            parts = return_type.strip("_").split("_")
            return_type = "{}({})".format(parts[0], ", ".join(parts[1:]))

        name = get_text(get_child(member, "name"))

        annotations = get_text(get_child(member, "argsstring"))
        if annotations and ")" in annotations:
            annotations = annotations.rsplit(")", 1)[-1].strip()
        # XXX: (doxygen 1.8.11) 'argsstring' only includes attributes of
        # non-void functions.  Special-case void functions here.
        if name == "nvim_get_mode" and len(annotations) == 0:
            annotations += "FUNC_API_FAST"
        annotations = filter(
            None, map(lambda x: annotation_map.get(x), annotations.split())
        )

        if not fmt_vimhelp:
            pass
        else:
            fstem = "?"
            if "." in compoundname:
                fstem = compoundname.split(".")[0]
                fstem = target_config["module_override"].get(fstem, fstem)
            vimtag = target_config["fn_helptag_fmt"](fstem, name)

        params = []
        type_length = 0

        for param in iter_children(member, "param"):
            param_type = get_text(get_child(param, "type")).strip()
            param_name = ""
            declname = get_child(param, "declname")
            if declname:
                param_name = get_text(declname).strip()
            elif target_config["mode"] == "lua":
                # XXX: this is what lua2dox gives us...
                param_name = param_type
                param_type = ""

            if param_name in param_exclude:
                continue

            if fmt_vimhelp and param_type.endswith("*"):
                param_type = param_type.strip("* ")
                param_name = "*" + param_name
            type_length = max(type_length, len(param_type))
            params.append((param_type, param_name))

        c_args = []
        for param_type, param_name in params:
            c_args.append(
                ("    " if fmt_vimhelp else "")
                + (
                    "%s %s" % (param_type.ljust(type_length), param_name)
                ).strip()
            )

        prefix = "%s(" % name
        suffix = "%s)" % ", ".join(
            "{%s}" % a[1] for a in params if a[0] not in ("void", "Error")
        )
        if not fmt_vimhelp:
            c_decl = "%s %s(%s);" % (return_type, name, ", ".join(c_args))
            signature = prefix + suffix
        else:
            c_decl = textwrap.indent(
                "%s %s(\n%s\n);" % (return_type, name, ",\n".join(c_args)),
                "    ",
            )

            # Minimum 8 chars between signature and vimtag
            lhs = (width - 8) - len(vimtag)

            if len(prefix) + len(suffix) > lhs:
                signature = vimtag.rjust(width) + "\n"
                signature += doc_wrap(
                    suffix, width=width - 8, prefix=prefix, func=True
                )
            else:
                signature = prefix + suffix
                signature += vimtag.rjust(width - len(signature))

        paras = []
        desc = find_first(member, "detaileddescription")
        if desc:
            for child in desc.childNodes:
                paras.append(para_as_map(child))
            if DEBUG:
                print(
                    textwrap.indent(
                        re.sub(
                            r"\n\s*\n+",
                            "\n",
                            desc.toprettyxml(indent="  ", newl="\n"),
                        ),
                        " " * 16,
                    )
                )

        fn = {
            "annotations": list(annotations),
            "signature": signature,
            "parameters": params,
            "parameters_doc": collections.OrderedDict(),
            "doc": [],
            "return": [],
            "seealso": [],
        }
        if fmt_vimhelp:
            fn["desc_node"] = desc  # HACK :(

        for m in paras:
            if "text" in m:
                if not m["text"] == "":
                    fn["doc"].append(m["text"])
            if "params" in m:
                # Merge OrderedDicts.
                fn["parameters_doc"].update(m["params"])
            if "return" in m and len(m["return"]) > 0:
                fn["return"] += m["return"]
            if "seealso" in m and len(m["seealso"]) > 0:
                fn["seealso"] += m["seealso"]

        if INCLUDE_C_DECL:
            fn["c_decl"] = c_decl

        if "Deprecated" in str(xrefs):
            deprecated_fns[name] = fn
        elif name.startswith(target_config["fn_name_prefix"]):
            fns[name] = fn

        xrefs.clear()

    fns = collections.OrderedDict(sorted(fns.items()))
    deprecated_fns = collections.OrderedDict(sorted(deprecated_fns.items()))
    return (fns, deprecated_fns)


def fmt_doxygen_xml_as_vimhelp(doxygen_dom, target_config):
    """Entrypoint for generating Vim :help from from Doxygen XML.

    Returns 2 items:
      1. Vim help text for functions found in `filename`.
      2. Vim help text for deprecated functions.
    """
    global fmt_vimhelp
    fmt_vimhelp = True
    fns_txt = {}  # Map of func_name:vim-help-text.
    deprecated_fns_txt = {}  # Map of func_name:vim-help-text.

    fns, _ = extract_from_xml(doxygen_dom, target_config, width=text_width)

    for name, fn in fns.items():
        # Generate Vim :help for parameters.
        if fn["desc_node"]:
            doc = fmt_node_as_vimhelp(fn["desc_node"])
        if not doc:
            doc = "TODO: Documentation"

        annotations = "\n".join(fn["annotations"])
        if annotations:
            annotations = "\n\nAttributes: ~\n" + textwrap.indent(
                annotations, "    "
            )
            i = doc.rfind("Parameters: ~")
            if i == -1:
                doc += annotations
            else:
                doc = doc[:i] + annotations + "\n\n" + doc[i:]

        if INCLUDE_C_DECL:
            doc += "\n\nC Declaration: ~\n>\n"
            doc += fn["c_decl"]
            doc += "\n<"

        func_doc = fn["signature"] + "\n"
        func_doc += textwrap.indent(clean_lines(doc), " " * 16)
        func_doc = re.sub(r"^\s+([<>])$", r"\1", func_doc, flags=re.M)

        if "Deprecated" in xrefs:
            deprecated_fns_txt[name] = func_doc
        elif name.startswith(target_config["fn_name_prefix"]):
            fns_txt[name] = func_doc

        xrefs.clear()

    fmt_vimhelp = False
    return (
        "\n\n".join(list(fns_txt.values())),
        "\n\n".join(list(deprecated_fns_txt.values())),
    )


def delete_lines_below(filename, tokenstr):
    """Deletes all lines below the line containing `tokenstr`, the line itself,
    and one line above it.
    """
    if not os.path.exists(filename):
        return

    with open(filename) as reader:
        lines = reader.readlines()

    i = 0
    found = False
    for i, line in enumerate(lines, 1):
        if tokenstr in line:
            found = True
            break

    if not found:
        raise RuntimeError(f'not found: "{tokenstr}" in filename "{filename}"')

    i = max(0, i - 2)
    with open(filename, "wt") as fp:
        fp.writelines(lines[0:i])


def main(config):
    """Generates:

    1. Vim :help docs
    2. *.mpack files for use by API clients

    Doxygen is called and configured through stdin.
    """
    for target in CONFIG:
        log("Processing target:", target)

        if TARGET is not None and target != TARGET:
            log("==> Skipping target:", target)
            continue

        output_dir = os.path.join(base_dir, "runtime", "doc")
        generate_help_and_mpack_for_target(
            target, CONFIG[target], config, output_dir
        )


def generate_help_and_mpack_for_target(
    target: str,
    target_conf: Dict[str, Any],
    doxy_string: str,
    output_dir: str,
    remove_files: bool = False,
):
    mpack_file = os.path.join(
        output_dir, target_conf["filename"].replace(".txt", ".mpack")
    )

    # Always remove the file at start.
    if os.path.exists(mpack_file):
        os.remove(mpack_file)

    tmp_output_dir = out_dir.format(target=target)
    try:
        docs, fn_map_full = process_target(
            target, target_conf, doxy_string, tmp_output_dir
        )

        doc_file = os.path.join(
            base_dir, "runtime", "doc", target_conf["filename"]
        )
        delete_lines_below(doc_file, target_conf["section_start_token"])
        with open(doc_file, "ab") as fp:
            fp.write(docs.encode("utf8"))

        with open(mpack_file, "wb") as fp:
            fp.write(msgpack.packb(fn_map_full, use_bin_type=True))

    finally:
        if remove_files:
            shutil.rmtree(tmp_output_dir)
            os.remove(mpack_file)


def process_target(
    target: str, target_conf: Dict[str, Any], doxy_string: str, output_dir: str
):
    p = doxygen_subprocess(DEBUG)

    doxy_config = format_doxy_config(
        doxy_string,
        doxygen_input=target_conf["files"],
        output=output_dir,
        doxygen_filter=filter_cmd,
        file_patterns=target_conf["file_patterns"],
        excluded=" ".join(target_conf.get("excluded_symbols", [])),
        recursive=target_conf.get("recursive", True),
    )

    print(doxy_config)

    p.communicate(doxy_config.encode("utf8"))
    if p.returncode:
        print("Doxygen failed for target:", target, file=sys.stderr)
        sys.exit(p.returncode)

    base = os.path.join(output_dir, "xml")
    dom = minidom.parse(os.path.join(base, "index.xml"))

    associated_doms_from_ref_ids = get_associated_doms_from_ref_ids(dom, base)
    docs, fn_map_full = get_doc_from_dom(
        dom, associated_doms_from_ref_ids, target, target_conf, text_width
    )

    return docs, fn_map_full


SectionTuple = collections.namedtuple(
    "SectionTuple", ["title", "helptag", "doc"]
)


def get_associated_doms_from_ref_ids(
    dom: TypeDom, base: str
) -> Dict[str, TypeDom]:
    associated_doms_from_ref_ids: Dict[str, TypeDom] = {}

    for compound in dom.getElementsByTagName("compound"):
        ref_id = compound.getAttribute("refid")
        associated_doms_from_ref_ids[ref_id] = minidom.parse(
            os.path.join(base, "{}.xml".format(ref_id))
        )

    return associated_doms_from_ref_ids


def get_doc_from_dom(
    dom: TypeDom,
    associated_doms_from_ref_ids: Dict[str, TypeDom],
    target: str,
    target_config: Dict[str, Any],
    text_width: int,
):
    fn_map_full = {}  # Collects all functions as each module is processed.
    sections: Dict[str, SectionTuple] = {}
    sep = "=" * text_width

    intros = get_intros_from_dom(dom, associated_doms_from_ref_ids)

    for compound in dom.getElementsByTagName("compound"):
        if compound.getAttribute("kind") != "file":
            continue

        filename = get_text(find_first(compound, "name"))
        if filename.endswith(".c") or filename.endswith(".lua"):
            ref_dom = associated_doms_from_ref_ids[
                compound.getAttribute("refid")
            ]

            # Extract unformatted (*.mpack).
            fn_map, _ = extract_from_xml(ref_dom, target_config, width=9999)

            # Extract formatted (:help).
            functions_text, deprecated_text = fmt_doxygen_xml_as_vimhelp(
                ref_dom, target_config
            )

            if not functions_text and not deprecated_text:
                continue
            else:
                name = os.path.splitext(os.path.basename(filename))[0].lower()
                sectname = name.upper() if name == "ui" else name.title()
                doc = ""
                intro = intros.get(f"api-{name}")

                if intro:
                    doc += "\n\n" + intro

                if functions_text:
                    doc += "\n\n" + functions_text

                if INCLUDE_DEPRECATED and deprecated_text:
                    doc += f"\n\n\nDeprecated {sectname} Functions: ~\n\n"
                    doc += deprecated_text

                if doc:
                    filename = os.path.basename(filename)
                    sectname = target_config["section_name"].get(
                        filename, sectname
                    )
                    title = target_config["section_fmt"](sectname)
                    helptag = target_config["helptag_fmt"](sectname)

                    sections[filename] = SectionTuple(title, helptag, doc)
                    fn_map_full.update(fn_map)

    # TODO(tjdevries): It is possible to put this back,
    # but I don't think we need it anymore after writing tests.
    # assert sections, filename

    if len(sections) > len(target_config["section_order"]):
        raise RuntimeError(
            'found new modules "{}"; update the "section_order" map'.format(
                set(sections).difference(target_config["section_order"])
            )
        )

    docs = ""

    i = 0
    for filename in target_config["section_order"]:
        if filename not in sections:
            # assert False, f"{filename} not in {set(sections.keys())}"
            continue

        title, helptag, section_doc = sections.pop(filename)
        i += 1
        if filename not in target_config["append_only"]:
            docs += sep
            docs += "\n%s%s" % (title, helptag.rjust(text_width - len(title)))
        docs += section_doc
        docs += "\n\n\n"

    docs = docs.rstrip() + "\n\n"
    docs += " vim:tw=78:ts=8:ft=help:norl:\n"

    fn_map_full = collections.OrderedDict(sorted(fn_map_full.items()))

    return docs, fn_map_full


def get_intros_from_dom(
    dom: TypeDom, associated_doms_from_ref_ids: Dict[str, TypeDom]
) -> Dict[str, str]:
    intros = {}

    # generate docs for section intros
    for compound in dom.getElementsByTagName("compound"):
        if compound.getAttribute("kind") != "group":
            continue

        groupname = get_text(find_first(compound, "name"))
        groupxml = associated_doms_from_ref_ids[compound.getAttribute("refid")]

        desc = find_first(groupxml, "detaileddescription")
        if desc:
            doc = fmt_node_as_vimhelp(desc)
            if doc:
                intros[groupname] = doc

    return intros


def log(*args, **kwargs):
    if DEBUG:
        print(*args, **kwargs)


def doxygen_subprocess(show_stderr):
    return subprocess.Popen(
        ["doxygen", "-"],
        stdin=subprocess.PIPE,
        stderr=(subprocess.STDOUT if show_stderr else subprocess.DEVNULL),
    )


def format_doxy_config(
    doxy_file,
    doxygen_input,
    output,
    doxygen_filter,
    file_patterns,
    excluded,
    recursive=True,
):
    return doxy_file.format(
        doxygen_input=doxygen_input,
        output=output,
        doxygen_filter=doxygen_filter,
        file_patterns=file_patterns,
        excluded=excluded,
        recursive=recursive,
    )


Doxyfile = textwrap.dedent(
    """
    OUTPUT_DIRECTORY       = {output}
    INPUT                  = {doxygen_input}
    INPUT_ENCODING         = UTF-8
    FILE_PATTERNS          = {file_patterns}
    RECURSIVE              = {recursive}
    INPUT_FILTER           = "{doxygen_filter}"
    EXCLUDE                =
    EXCLUDE_SYMLINKS       = NO
    EXCLUDE_PATTERNS       = */private/*
    EXCLUDE_SYMBOLS        = {excluded}
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
    XML_PROGRAMLISTING     = YES

    ENABLE_PREPROCESSING   = YES
    MACRO_EXPANSION        = YES
    EXPAND_ONLY_PREDEF     = NO
    MARKDOWN_SUPPORT       = YES
"""
)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="gen_vimdoc", description="Generate vim docs from Lua & C Files."
    )

    parser.add_argument(
        "--doxy-template",
        help="Optional Doxygen template file. Used to pass params to doxygen. See 'Doxyfile' in script for example",
    )

    args = parser.parse_args()

    if args.doxy_template:
        with open(args.doxy_template, "r") as reader:
            doxy_file = reader.read()
    else:
        doxy_file = Doxyfile

    main(doxy_file)

# vim: set ft=python ts=4 sw=4 tw=79 et :
