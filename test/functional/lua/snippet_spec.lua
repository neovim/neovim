local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local feed = helpers.feed
local exec_lua = helpers.exec_lua

describe('vim.snippet', function()
  before_each(function()
    clear()
    exec_lua([[
      vim.snippet.dispose()
      vim.api.nvim_buf_set_keymap(0, 'n', '<C-l>', '<Cmd>lua vim.snippet.sync()<CR>', { noremap = true })
      vim.api.nvim_buf_set_keymap(0, 'i', '<C-l>', '<Cmd>lua vim.snippet.sync()<CR>', { noremap = true })
      vim.api.nvim_buf_set_keymap(0, 's', '<C-l>', '<Cmd>lua vim.snippet.sync()<CR>', { noremap = true })
      vim.api.nvim_buf_set_keymap(0, 'i', '<Tab>', '<Cmd>lua vim.snippet.jump(vim.snippet.JumpDirection.Next)<CR>', { noremap = true })
      vim.api.nvim_buf_set_keymap(0, 's', '<Tab>', '<Cmd>lua vim.snippet.jump(vim.snippet.JumpDirection.Next)<CR>', { noremap = true })
      vim.api.nvim_buf_set_keymap(0, 'i', '<S-Tab>', '<Cmd>lua vim.snippet.jump(vim.snippet.JumpDirection.Prev)<CR>', { noremap = true })
      vim.api.nvim_buf_set_keymap(0, 's', '<S-Tab>', '<Cmd>lua vim.snippet.jump(vim.snippet.JumpDirection.Prev)<CR>', { noremap = true })
      vim.api.nvim_buf_set_keymap(0, 's', '<BS>', '"\\<BS>" .. (getcurpos()[2] == col("$") - 1 ? "a" : "i")', { noremap = true, expr = true })

      function get_state()
        local m = vim.api.nvim_get_mode().mode
        local s = vim.fn.getpos("'<")
        local e = vim.fn.getpos("'>")
        local c = vim.fn.getpos('.')
        return {
          m = m,
          s = m ~= 's' and ({ c[2] - 1, c[3] - 1 }) or ({ s[2] - 1, s[3] - 1 }),
          e = m ~= 's' and ({ c[2] - 1, c[3] - 1 }) or ({ e[2] - 1, e[3] - 1 }),
        }
      end
    ]])
  end)
  after_each(function()
    clear()
  end)

  it('should expand snippet with considering buffer indent setting', function()
    local snippet = table.concat({
      'class ${1:ClassName} {',
      '\tpublic $1($2) {',
      '\t\t${3}',
      '\t}',
      '}',
      ''
    }, '\n')

    for _, case in ipairs({
      {
        base_indent = [[  ]],
        indent_setting = [[
          vim.o.expandtab = true
          vim.o.shiftwidth = 2
        ]],
        expects = {
          '  class ClassName {',
          '    public ClassName() {',
          '      ',
          '    }',
          '  }',
          '  ',
        }
      }, {
        base_indent = [[  ]],
        indent_setting = [[
          vim.o.expandtab = true
          vim.o.shiftwidth = 0
          vim.o.tabstop = 2
        ]],
        expects = {
          '  class ClassName {',
          '    public ClassName() {',
          '      ',
          '    }',
          '  }',
          '  ',
        }
      }, {
        base_indent = [[<Tab>]],
        indent_setting = [[
          vim.o.expandtab = false
        ]],
        expects = {
          '\tclass ClassName {',
          '\t\tpublic ClassName() {',
          '\t\t\t',
          '\t\t}',
          '\t}',
          '\t',
        }
      }
    }) do
      clear()
      exec_lua(case.indent_setting)
      feed('i' .. case.base_indent)
      exec_lua('vim.snippet.expand(...)', snippet)
      eq(case.expects, helpers.buf_lines(0))
    end
  end)

  it('should able to jump to all placeholders', function()
    exec_lua('vim.snippet.expand(...)', table.concat({
      'class ${1:ClassName} {',
      '\tpublic $1($2) {',
      '\t\t${3}',
      '\t}',
      '}',
      ''
    }, '\n'))
    local cases = {
      { m = 's', s = { 0, 6 }, e = { 0, 14 }, },
      { m = 'i', s = { 1, 18 }, e = { 1, 18 }, },
      { m = 'i', s = { 2, 2 }, e = { 2, 2 }, },
      { m = 'i', s = { 5, 0 }, e = { 5, 0 }, },
    }
    for i = 1, #cases do
      eq(cases[i], exec_lua([[return get_state()]]))
      eq(i ~= #cases, exec_lua([[return vim.snippet.jumpable(vim.snippet.JumpDirection.Next)]]))
      feed('<Tab>')
    end
    eq(cases[#cases], exec_lua([[return get_state()]]))
    for i = #cases, 1, -1 do
      eq(cases[i], exec_lua([[return get_state()]]))
      eq(i ~= 1, exec_lua([[return vim.snippet.jumpable(vim.snippet.JumpDirection.Prev)]]))
      feed('<S-Tab>')
    end
    eq(cases[1], exec_lua([[return get_state()]]))
  end)

  it('should sync same tabstop mark', function()
    exec_lua('vim.snippet.expand(...)', table.concat({
      'class ${1:ClassName} {',
      '\tpublic $1($2) {',
      '\t\t${3}',
      '\t}',
      '}',
      ''
    }, '\n'))
    feed('ModifiedClassName<C-l>')
    eq({
      'class ModifiedClassName {',
      '\tpublic ModifiedClassName() {',
      '\t\t',
      '\t}',
      '}',
      '',
    }, helpers.buf_lines(0))
  end)

  it('should dispose directly modified non-origin mark', function()
    exec_lua('vim.snippet.expand(...)', table.concat({
      'class ${1:ClassName} {',
      '\tpublic $1($2) {',
      '\t\t${3}',
      '\t}',
      '}',
      ''
    }, '\n'))
    feed('<Esc><Cmd>call cursor(2, 9)<CR>ciwDirectlyModified<C-l>')
    eq({
      'class ClassName {',
      '\tpublic DirectlyModified() {',
      '\t\t',
      '\t}',
      '}',
      '',
    }, helpers.buf_lines(0))
  end)

  it('should restore the state with undo', function()
    exec_lua('vim.snippet.expand(...)', table.concat({
      'class ${1:ClassName} {',
      '\tpublic $1($2) {',
      '\t\t${3}',
      '\t}',
      '}',
      ''
    }, '\n'))

    feed('ModifiedClassName<C-l><Tab>argument<Esc>')
    eq({
      'class ModifiedClassName {',
      '\tpublic ModifiedClassName(argument) {',
      '\t\t',
      '\t}',
      '}',
      '',
    }, helpers.buf_lines(0))

    feed('u<C-l>')
    eq({
      'class ClassName {',
      '\tpublic ClassName() {',
      '\t\t',
      '\t}',
      '}',
      '',
    }, helpers.buf_lines(0))

    feed('i<S-Tab><C-g>o<Esc>aModified<C-l>')
    eq({
      'class ClassNameModified {',
      '\tpublic ClassNameModified() {',
      '\t\t',
      '\t}',
      '}',
      '',
    }, helpers.buf_lines(0))
  end)

  it('should dispose snippet if edit outside of range', function()
    feed('i<CR>')
    exec_lua('vim.snippet.expand(...)', table.concat({
      'class ${1:ClassName} {',
      '\tpublic $1($2) {',
      '\t\t${3}',
      '\t}',
      '}',
      ''
    }, '\n'))
    feed('<Esc>ggiEdit')
    local state = exec_lua([[return get_state()]])
    feed('<Tab>')
    eq(exec_lua([[return get_state()]]), state)
  end)

  it('should expand snippet even if cursor is in the middle of text', function()
    feed('i()<Left>')
    exec_lua('vim.snippet.expand(...)', table.concat({
      'class ${1:ClassName} {',
      '\tpublic $1($2) {',
      '\t\t${3}',
      '\t}',
      '}',
      ''
    }, '\n'))
    eq({
      '(class ClassName {',
      '\tpublic ClassName() {',
      '\t\t',
      '\t}',
      '}',
      ')',
    }, helpers.buf_lines(0))
  end)

end)

