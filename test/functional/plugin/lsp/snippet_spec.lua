local helpers = require('test.functional.helpers')(after_each)
local snippet = require('vim.lsp._snippet_grammar')

local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('vim.lsp._snippet_grammar', function()
  before_each(helpers.clear)
  after_each(helpers.clear)

  local parse = function(...)
    local res = exec_lua('return require("vim.lsp._snippet_grammar").parse(...)', ...)
    return res.data.children
  end

  it('parses only text', function()
    eq({
      { type = snippet.NodeType.Text, data = { text = 'TE$}XT' } },
    }, parse('TE\\$\\}XT'))
  end)

  it('parses tabstops', function()
    eq({
      { type = snippet.NodeType.Tabstop, data = { tabstop = 1 } },
      { type = snippet.NodeType.Tabstop, data = { tabstop = 2 } },
    }, parse('$1${2}'))
  end)

  it('parses nested placeholders', function()
    eq({
      {
        type = snippet.NodeType.Placeholder,
        data = {
          tabstop = 1,
          value = {
            type = snippet.NodeType.Placeholder,
            data = {
              tabstop = 2,
              value = { type = snippet.NodeType.Tabstop, data = { tabstop = 3 } },
            },
          },
        },
      },
    }, parse('${1:${2:${3}}}'))
  end)

  it('parses variables', function()
    eq({
      { type = snippet.NodeType.Variable, data = { name = 'VAR' } },
      { type = snippet.NodeType.Variable, data = { name = 'VAR' } },
      {
        type = snippet.NodeType.Variable,
        data = {
          name = 'VAR',
          default = { type = snippet.NodeType.Tabstop, data = { tabstop = 1 } },
        },
      },
      {
        type = snippet.NodeType.Variable,
        data = {
          name = 'VAR',
          regex = 'regex',
          options = '',
          format = {
            {
              type = snippet.NodeType.Format,
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
        type = snippet.NodeType.Choice,
        data = { tabstop = 1, values = { ',', '|' } },
      },
    }, parse('${1|\\,,\\||}'))
  end)

  it('parses format', function()
    eq(
      {
        {
          type = snippet.NodeType.Variable,
          data = {
            name = 'VAR',
            regex = 'regex',
            options = '',
            format = {
              {
                type = snippet.NodeType.Format,
                data = { capture = 1, modifier = 'upcase' },
              },
              {
                type = snippet.NodeType.Format,
                data = { capture = 1, if_text = 'if_text' },
              },
              {
                type = snippet.NodeType.Format,
                data = { capture = 1, else_text = 'else_text' },
              },
              {
                type = snippet.NodeType.Format,
                data = { capture = 1, if_text = 'if_text', else_text = 'else_text' },
              },
              {
                type = snippet.NodeType.Format,
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
        type = snippet.NodeType.Placeholder,
        data = {
          tabstop = 1,
          value = { type = snippet.NodeType.Text, data = { text = '' } },
        },
      },
      {
        type = snippet.NodeType.Text,
        data = { text = ' ' },
      },
      {
        type = snippet.NodeType.Variable,
        data = {
          name = 'VAR',
          regex = 'erg',
          format = {
            {
              type = snippet.NodeType.Format,
              data = { capture = 1, if_text = '' },
            },
          },
          options = 'g',
        },
      },
    }, parse('${1:} ${VAR/erg/${1:+}/g}'))
  end)
end)
