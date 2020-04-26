import os
import shutil
from tempfile import NamedTemporaryFile
from xml.dom import minidom

import gen_vimdoc


def setup_module(module):
    base_dir = "tmp-test-dir"
    shutil.rmtree(base_dir, ignore_errors=True)
    os.mkdir(base_dir)


def _make_xml_text(name, detailed_description, prot="public"):
    return f"""
        <doxygen xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="compound.xsd" version="1.8.19">
          <compounddef id="vim_8lua" kind="file" language="C++">
            <compoundname>vim.lua</compoundname>
              <memberdef kind="function" id="vim_8lua_1a16e7cdb295de1c6dd616838c60e6c9eb" prot="{prot}" static="no" const="no" explicit="no" inline="no" virt="non-virtual">
                <type>function vim</type>
                <definition>function vim empty_dict</definition>
                <argsstring>()</argsstring>
                <name>{name}</name>
                <briefdescription>
                    A brief description
                </briefdescription>
                <detaileddescription>
                    {detailed_description}
                </detaileddescription>
                <inbodydescription>
                    An inbody description
                </inbodydescription>
                <location file="src/nvim/lua/vim.lua" line="246" column="13" bodyfile="src/nvim/lua/vim.lua" bodystart="246" bodyend="246"/>
              </memberdef>
            <briefdescription>
            </briefdescription>
            <detaileddescription>
            </detaileddescription>
            <location file="src/nvim/lua/vim.lua"/>
          </compounddef>
        </doxygen>
    """


EMPTY_DICT_TEXT = _make_xml_text(
    "empty_dict",
    """
    <para>A detailed description</para>
    <para>Another line</para>
    """,
)

BASIC_LUA_CONFIG = {
    "mode": "lua",
    "fn_name_prefix": "",
    "fn_helptag_fmt": lambda fstem, name: f"*{fstem}.{name}()*",
    "file_patterns": "*.lua",
    "module_override": {},
    "section_name": {},
    "section_fmt": lambda name: f"{name} Functions",
    "helptag_fmt": lambda name: f"*lua-{name.lower()}*",
    "append_only": [],
}


def test_can_import():
    # If this test fails, try running like:
    # $ PYTHONPATH=scripts pytest
    assert gen_vimdoc.Doxyfile


def test_simple_extract_from_xml():
    dom = minidom.parseString(EMPTY_DICT_TEXT)
    functions, dep_functions = gen_vimdoc.extract_from_xml(
        dom, BASIC_LUA_CONFIG, width=9999
    )

    assert functions["empty_dict"]["signature"] == "empty_dict()"
    assert functions["empty_dict"]["doc"] == [
        "A detailed description",
        "Another line",
    ]


def test_simple_text_from_xml():
    dom = minidom.parseString(EMPTY_DICT_TEXT)
    fn_text, dep_text = gen_vimdoc.fmt_doxygen_xml_as_vimhelp(
        dom, BASIC_LUA_CONFIG
    )

    assert (
        """empty_dict()                                                *vim.empty_dict()*
                A detailed description

                Another line"""
        == fn_text
    )

    assert dep_text == ""


def test_ignores_underscore_prefixed_names():
    dom = minidom.parseString(
        _make_xml_text("_ignored_func", "Does not matter")
    )
    fn_text, dep_text = gen_vimdoc.fmt_doxygen_xml_as_vimhelp(
        dom, BASIC_LUA_CONFIG
    )

    assert "" == fn_text
    assert "" == dep_text

    functions, dep_functions = gen_vimdoc.extract_from_xml(
        dom, BASIC_LUA_CONFIG, width=9999
    )
    assert {} == functions
    assert {} == dep_functions


def test_ignores_private_functions():
    dom = minidom.parseString(
        _make_xml_text("ignored_func", "Does not matter", prot="private")
    )
    fn_text, dep_text = gen_vimdoc.fmt_doxygen_xml_as_vimhelp(
        dom, BASIC_LUA_CONFIG
    )

    assert "" == fn_text
    assert "" == dep_text

    functions, dep_functions = gen_vimdoc.extract_from_xml(
        dom, BASIC_LUA_CONFIG, width=9999
    )
    assert {} == functions
    assert {} == dep_functions


def _process_temp_lua_file(lua_text: str):
    base_dir = "tmp-test-dir"

    with NamedTemporaryFile(
        prefix="tmp_lua", suffix=".lua", dir=base_dir, mode="w+"
    ) as fp:
        fp.write(lua_text)
        fp.flush()

        test_config = BASIC_LUA_CONFIG.copy()
        test_config["files"] = os.path.join(base_dir, fp.name)
        test_config["recursive"] = False
        test_config["section_order"] = [fp.name]

        docs, fn_map_full = gen_vimdoc.process_target(
            "test", test_config, gen_vimdoc.Doxyfile, "./tmp-test-dir",
        )

        # input()

    return docs, fn_map_full


def test_gen_doxy():
    docs, fn_map_full = _process_temp_lua_file(
        """
--- This is a test function
---
--- Wow, very cool
function test_func()
    return 5
end

return test_func
"""
    )

    assert fn_map_full["test_func"]["doc"] == [
        "This is a test function",
        "Wow, very cool",
    ]


def test_local_functions_are_not_exported():
    docs, fn_map_full = _process_temp_lua_file(
        """
--- This is a test function
---
--- Wow, very cool
local function test_func()
    return 5
end

return test_func
"""
    )

    assert fn_map_full == {}


def test_function_module_name_show_up():
    docs, fn_map_full = _process_temp_lua_file(
        """

local M = {}

--- This is a test function
---
--- Wow, very cool
function M.test_func()
    return 5
end

return M
"""
    )

    assert fn_map_full["test_func"]["doc"] == [
        "This is a test function",
        "Wow, very cool",
    ]


def test_module_name_function_show_up():
    docs, fn_map_full = _process_temp_lua_file(
        """

local M = {}

--- This is a test function
---
--- Wow, very cool
M.test_func = function()
    return 5
end

return M
"""
    )

    assert fn_map_full["test_func"]["doc"] == [
        "This is a test function",
        "Wow, very cool",
    ]


# vim: set ft=python ts=4 sw=4 tw=79 et :
