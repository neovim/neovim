local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local feed = helpers.feed
local exec_lua = helpers.exec_lua

describe('vim.snippet', function()
  for _, selection in ipairs({ 'inclusive', 'exclusive' }) do
    for _, virtualedit in ipairs({ '', 'all', 'onemore' }) do
      describe(('selection=%s, virtualedit=%s'):format(selection, virtualedit), function()
        before_each(function()
          clear()
          exec_lua(([[
            vim.o.selection = '%s';
            vim.o.virtualedit = '%s';
            vim.snippet.dispose()
            vim.keymap.set({ 'n', 'i', 's' }, '<C-l>', '<Cmd>lua vim.snippet._sync()<CR>', { buffer = true })
            vim.keymap.set({ 'i', 's' }, '<Tab>', '<Cmd>lua vim.snippet.jump(vim.snippet.JumpDirection.Next)<CR>', { buffer = true })
            vim.keymap.set({ 'i', 's' }, '<S-Tab>', '<Cmd>lua vim.snippet.jump(vim.snippet.JumpDirection.Prev)<CR>', { buffer = true })
            vim.keymap.set({ 's' }, '<BS>', '"\\<BS>" .. (getcurpos()[2] == col("$") - 1 ? "a" : "i")', { expr = true })

            function get_state()
              local m = vim.api.nvim_get_mode().mode
              local select_s = vim.fn.getpos("'<")
              local select_e = vim.fn.getpos("'>")
              local cursor = vim.fn.getpos('.')
              local exclusive_offset = vim.o.selection == 'exclusive' and 1 or 0
              return {
                m = m,
                s = m ~= 's' and ({ cursor[2] - 1, cursor[3] - 1 }) or ({ select_s[2] - 1, select_s[3] - 1 }),
                e = m ~= 's' and ({ cursor[2] - 1, cursor[3] - 1 }) or ({ select_e[2] - 1, select_e[3] - exclusive_offset }),
              }
            end
          ]]):format(selection, virtualedit))
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

        it('should be able to jump through all placeholders', function()
          exec_lua('vim.snippet.expand(...)', table.concat({
            'class ${1:ClassName} {',
            '\tpublic $1($2) {',
            '\t\t${3}',
            '\t}',
            '}',
            ''
          }, '\n'))
          local cases = {
            { m = 's', s = { 0, 6 },  e = { 0, 15 }, },
            { m = 'i', s = { 1, 18 }, e = { 1, 18 }, },
            { m = 'i', s = { 2, 2 },  e = { 2, 2 }, },
            { m = 'i', s = { 5, 0 },  e = { 5, 0 }, },
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

        it('should sync same tabstops', function()
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

        -- We can't manage `complete(...)` in test.
        -- it('should insert selected choice', function()
        --   exec_lua('vim.snippet.expand(...)', table.concat({
        --     'console.${1|log,info,warn,error|}($2);',
        --   }, '\n'))
        --   feed('<C-n><C-n><C-n><C-y>')
        --   eq({
        --     'console.warn();',
        --   }, helpers.buf_lines(0))
        -- end)

        it('should dispose directly modified non-origin tabstop', function()
          exec_lua('vim.snippet.expand(...)', table.concat({
            'class ${1:ClassName} {',
            '\tpublic $1($2) {',
            '\t\t${3}',
            '\t}',
            '}',
            ''
          }, '\n'))
          eq({
            'class ClassName {',
            '\tpublic ClassName() {',
            '\t\t',
            '\t}',
            '}',
            '',
          }, helpers.buf_lines(0))
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

          local to_insert = selection == 'exclusive' and 'i' or 'a'
          feed(('i<S-Tab><C-g>o<Esc>%sModified<C-l>'):format(to_insert))
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

        it('should merge snippet with existing snippet', function()
          exec_lua('vim.snippet.expand(...)', table.concat({
            'class ${1:ClassName} {',
            '\tpublic $1($2) {',
            '\t\t${3}',
            '\t}',
            '}',
            ''
          }, '\n'))
          feed('<Tab><Tab>') -- jump to $3

          -- expand new snippet while already activating another snippet.
          exec_lua('vim.snippet.expand(...)', table.concat({
            'class ${1:ClassName} {',
            '\tpublic $1($2) {',
            '\t\t${3}',
            '\t}',
            '}',
            ''
          }, '\n'))
          eq({
            'class ClassName {',
            '\tpublic ClassName() {',
            '\t\tclass ClassName {',
            '\t\t\tpublic ClassName() {',
            '\t\t\t\t',
            '\t\t\t}',
            '\t\t}',
            '\t\t',
            '\t}',
            '}',
            '',
          }, helpers.buf_lines(0))

          -- jump through all placeholders.
          local next_cases = {
            { m = 's', s = { 2, 8 },  e = { 2, 17 }, },
            { m = 'i', s = { 3, 20 }, e = { 3, 20 }, },
            { m = 'i', s = { 4, 4 },  e = { 4, 4 }, },
            { m = 'i', s = { 7, 2 },  e = { 7, 2 }, },
            { m = 'i', s = { 10, 0 }, e = { 10, 0 }, },
          }
          for i = 1, #next_cases do
            eq(next_cases[i], exec_lua([[return get_state()]]))
            eq(i ~= #next_cases, exec_lua([[return vim.snippet.jumpable(vim.snippet.JumpDirection.Next)]]))
            feed('<Tab>')
          end

          local prev_cases = {
            { m = 'i', s = { 10, 0 }, e = { 10, 0 }, },
            { m = 'i', s = { 7, 2 },  e = { 7, 2 }, },
            { m = 'i', s = { 4, 4 },  e = { 4, 4 }, },
            { m = 'i', s = { 3, 20 }, e = { 3, 20 }, },
            { m = 's', s = { 2, 8 },  e = { 2, 17 }, },
            { m = 's', s = { 2, 2 },  e = { 7, 2 }, },
            { m = 'i', s = { 1, 18 }, e = { 1, 18 }, },
            { m = 's', s = { 0, 6 },  e = { 0, 15 }, },
          }
          for i = 1, #prev_cases do
            eq(prev_cases[i], exec_lua([[return get_state()]]))
            eq(i ~= #prev_cases, exec_lua([[return vim.snippet.jumpable(vim.snippet.JumpDirection.Prev)]]))
            feed('<S-Tab>')
          end
        end)
      end)
    end
  end
end)
