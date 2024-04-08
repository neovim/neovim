local t = require('test.functional.testutil')(after_each)
local snippet = require('vim.lsp._snippet_grammar')
local type = snippet.NodeType

local eq = t.eq
local exec_lua = t.exec_lua

describe('vim.lsp._snippet_grammar', function()
  before_each(t.clear)
  after_each(t.clear)

  local parse = function(...)
    local res = exec_lua('return require("vim.lsp._snippet_grammar").parse(...)', ...)
    return res.data.children
  end

  it('parses only text', function()
    eq({
      { type = type.Text, data = { text = 'TE$}XT' } },
    }, parse('TE\\$\\}XT'))
  end)

  it('parses tabstops', function()
    eq({
      { type = type.Tabstop, data = { tabstop = 1 } },
      { type = type.Tabstop, data = { tabstop = 2 } },
    }, parse('$1${2}'))
  end)

  it('parses nested placeholders', function()
    eq({
      {
        type = type.Placeholder,
        data = {
          tabstop = 1,
          value = {
            type = type.Placeholder,
            data = {
              tabstop = 2,
              value = { type = type.Tabstop, data = { tabstop = 3 } },
            },
          },
        },
      },
    }, parse('${1:${2:${3}}}'))
  end)

  it('parses variables', function()
    eq({
      { type = type.Variable, data = { name = 'VAR' } },
      { type = type.Variable, data = { name = 'VAR' } },
      {
        type = type.Variable,
        data = {
          name = 'VAR',
          default = { type = type.Tabstop, data = { tabstop = 1 } },
        },
      },
      {
        type = type.Variable,
        data = {
          name = 'VAR',
          regex = 'regex',
          options = '',
          format = {
            {
              type = type.Format,
              data = { capture = 1, modifier = 'upcase' },
            },
          },
        },
      },
    }, parse('$VAR${VAR}${VAR:$1}${VAR/regex/${1:/upcase}/}'))
  end)

  it('parses choice', function()
    eq({
      {
        type = type.Choice,
        data = { tabstop = 1, values = { ',', '|' } },
      },
    }, parse('${1|\\,,\\||}'))
  end)

  it('parses format', function()
    eq(
      {
        {
          type = type.Variable,
          data = {
            name = 'VAR',
            regex = 'regex',
            options = '',
            format = {
              {
                type = type.Format,
                data = { capture = 1, modifier = 'upcase' },
              },
              {
                type = type.Format,
                data = { capture = 1, if_text = 'if_text' },
              },
              {
                type = type.Format,
                data = { capture = 1, else_text = 'else_text' },
              },
              {
                type = type.Format,
                data = { capture = 1, if_text = 'if_text', else_text = 'else_text' },
              },
              {
                type = type.Format,
                data = { capture = 1, else_text = 'else_text' },
              },
            },
          },
        },
      },
      parse(
        '${VAR/regex/${1:/upcase}${1:+if_text}${1:-else_text}${1:?if_text:else_text}${1:else_text}/}'
      )
    )
  end)

  it('parses empty strings', function()
    eq({
      {
        type = type.Placeholder,
        data = {
          tabstop = 1,
          value = { type = type.Text, data = { text = '' } },
        },
      },
      {
        type = type.Text,
        data = { text = ' ' },
      },
      {
        type = type.Variable,
        data = {
          name = 'VAR',
          regex = 'erg',
          format = {
            {
              type = type.Format,
              data = { capture = 1, if_text = '' },
            },
          },
          options = 'g',
        },
      },
    }, parse('${1:} ${VAR/erg/${1:+}/g}'))
  end)

  it('parses closing curly brace as text', function()
    eq(
      {
        { type = type.Text, data = { text = 'function ' } },
        { type = type.Tabstop, data = { tabstop = 1 } },
        { type = type.Text, data = { text = '() {\n  ' } },
        { type = type.Tabstop, data = { tabstop = 0 } },
        { type = type.Text, data = { text = '\n}' } },
      },
      parse(table.concat({
        'function $1() {',
        '  $0',
        '}',
      }, '\n'))
    )
  end)
end)
