from xml.dom import minidom

import gen_vimdoc


def _make_xml_text(name, detailed_description):
    return """
        <doxygen xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="compound.xsd" version="1.8.19">
          <compounddef id="vim_8lua" kind="file" language="C++">
            <compoundname>vim.lua</compoundname>
              <memberdef kind="function" id="vim_8lua_1a16e7cdb295de1c6dd616838c60e6c9eb" prot="public" static="no" const="no" explicit="no" inline="no" virt="non-virtual">
                <type>function vim</type>
                <definition>function vim empty_dict</definition>
                <argsstring>()</argsstring>
                <name>{}</name>
                <briefdescription>
                    A brief description
                </briefdescription>
                <detaileddescription>
                    {}
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
    """.format(
        name, detailed_description
    )


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
    "module_override": {},
    "fn_helptag_fmt": lambda fstem, name: f"*{fstem}.{name}()*",
}


def test_can_import():
    # If this test fails, try running like:
    # $ PYTHONPATH=scripts pytest
    assert gen_vimdoc.Doxyfile


def test_simple_extract_from_xml():
    dom = minidom.parseString(EMPTY_DICT_TEXT)
    functions, dep_functions = gen_vimdoc.extract_from_xml(dom, BASIC_LUA_CONFIG, width=9999)

    assert functions["empty_dict"]["signature"] == "empty_dict()"
    assert functions["empty_dict"]["doc"] == ["A detailed description", "Another line"]


def test_simple_text_from_xml():
    dom = minidom.parseString(EMPTY_DICT_TEXT)
    fn_text, dep_text = gen_vimdoc.fmt_doxygen_xml_as_vimhelp(dom, BASIC_LUA_CONFIG)

    assert (
        """empty_dict()                                                *vim.empty_dict()*
                A detailed description

                Another line"""
        == fn_text
    )

    assert dep_text == ""


def test_ignores_underscore_prefixed_names():
    dom = minidom.parseString(_make_xml_text("_ignored_func", "Does not matter"))
    fn_text, dep_text = gen_vimdoc.fmt_doxygen_xml_as_vimhelp(dom, BASIC_LUA_CONFIG)

    assert "" == fn_text
    assert "" == dep_text

    functions, dep_functions = gen_vimdoc.extract_from_xml(dom, BASIC_LUA_CONFIG, width=9999)
    assert {} == functions
    assert {} == dep_functions
