local helpers = require('test.functional.helpers')(after_each)
local snippet = require('vim.lsp._snippet')

local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('vim.lsp._snippet', function()
  before_each(helpers.clear)
  after_each(helpers.clear)

  local parse = function(...)
    return exec_lua('return require("vim.lsp._snippet").parse(...)', ...)
  end

  it('should parse only text', function()
    eq({
      type = snippet.NodeType.SNIPPET,
      children = {
        {
          type = snippet.NodeType.TEXT,
          raw = 'TE\\$\\}XT',
          esc = 'TE$}XT',
        },
      },
    }, parse('TE\\$\\}XT'))
  end)

  it('should parse tabstop', function()
    eq({
      type = snippet.NodeType.SNIPPET,
      children = {
        {
          type = snippet.NodeType.TABSTOP,
          tabstop = 1,
        },
        {
          type = snippet.NodeType.TABSTOP,
          tabstop = 2,
        },
      },
    }, parse('$1${2}'))
  end)

  it('should parse placeholders', function()
    eq({
      type = snippet.NodeType.SNIPPET,
      children = {
        {
          type = snippet.NodeType.PLACEHOLDER,
          tabstop = 1,
          children = {
            {
              type = snippet.NodeType.PLACEHOLDER,
              tabstop = 2,
              children = {
                {
                  type = snippet.NodeType.TEXT,
                  raw = 'TE\\$\\}XT',
                  esc = 'TE$}XT',
                },
                {
                  type = snippet.NodeType.TABSTOP,
                  tabstop = 3,
                },
                {
                  type = snippet.NodeType.TABSTOP,
                  tabstop = 1,
                  transform = {
                    type = snippet.NodeType.TRANSFORM,
                    pattern = 'regex',
                    option = 'i',
                    format = {
                      {
                        type = snippet.NodeType.FORMAT,
                        capture_index = 1,
                        modifier = 'upcase',
                      },
                    },
                  },
                },
                {
                  type = snippet.NodeType.TEXT,
                  raw = 'TE\\$\\}XT',
                  esc = 'TE$}XT',
                },
              },
            },
          },
        },
      },
    }, parse('${1:${2:TE\\$\\}XT$3${1/regex/${1:/upcase}/i}TE\\$\\}XT}}'))
  end)

  it('should parse variables', function()
    eq({
      type = snippet.NodeType.SNIPPET,
      children = {
        {
          type = snippet.NodeType.VARIABLE,
          name = 'VAR',
        },
        {
          type = snippet.NodeType.VARIABLE,
          name = 'VAR',
        },
        {
          type = snippet.NodeType.VARIABLE,
          name = 'VAR',
          children = {
            {
              type = snippet.NodeType.TABSTOP,
              tabstop = 1,
            },
          },
        },
        {
          type = snippet.NodeType.VARIABLE,
          name = 'VAR',
          transform = {
            type = snippet.NodeType.TRANSFORM,
            pattern = 'regex',
            format = {
              {
                type = snippet.NodeType.FORMAT,
                capture_index = 1,
                modifier = 'upcase',
              },
            },
          },
        },
      },
    }, parse('$VAR${VAR}${VAR:$1}${VAR/regex/${1:/upcase}/}'))
  end)

  it('should parse choice', function()
    eq({
      type = snippet.NodeType.SNIPPET,
      children = {
        {
          type = snippet.NodeType.CHOICE,
          tabstop = 1,
          items = {
            ',',
            '|',
          },
        },
      },
    }, parse('${1|\\,,\\||}'))
  end)

  it('should parse format', function()
    eq({
      type = snippet.NodeType.SNIPPET,
      children = {
        {
          type = snippet.NodeType.VARIABLE,
          name = 'VAR',
          transform = {
            type = snippet.NodeType.TRANSFORM,
            pattern = 'regex',
            format = {
              {
                type = snippet.NodeType.FORMAT,
                capture_index = 1,
                modifier = 'upcase',
              },
              {
                type = snippet.NodeType.FORMAT,
                capture_index = 1,
                if_text = 'if_text',
                else_text = '',
              },
              {
                type = snippet.NodeType.FORMAT,
                capture_index = 1,
                if_text = '',
                else_text = 'else_text',
              },
              {
                type = snippet.NodeType.FORMAT,
                capture_index = 1,
                else_text = 'else_text',
                if_text = 'if_text',
              },
              {
                type = snippet.NodeType.FORMAT,
                capture_index = 1,
                if_text = '',
                else_text = 'else_text',
              },
            },
          },
        },
      },
    }, parse('${VAR/regex/${1:/upcase}${1:+if_text}${1:-else_text}${1:?if_text:else_text}${1:else_text}/}'))
  end)

  it('should parse empty strings', function()
    eq({
      children = {
        {
          children = { {
            esc = '',
            raw = '',
            type = 7,
          } },
          tabstop = 1,
          type = 2,
        },
        {
          esc = ' ',
          raw = ' ',
          type = 7,
        },
        {
          name = 'VAR',
          transform = {
            format = {
              {
                capture_index = 1,
                else_text = '',
                if_text = '',
                type = 6,
              },
            },
            option = 'g',
            pattern = 'erg',
            type = 5,
          },
          type = 3,
        },
      },
      type = 0,
    }, parse('${1:} ${VAR/erg/${1:?:}/g}'))
  end)
end)
