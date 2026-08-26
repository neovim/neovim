local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local api = n.api
local clear = n.clear
local eq = t.eq
local exec_capture = n.exec_capture
local exec_lua = n.exec_lua
local feed = n.feed

-- Reference text
-- aa
--  aa
--   aa
--
--   aa
--  aa
-- aa
local example_lines = { 'aa', ' aa', '  aa', '', '  aa', ' aa', 'aa' }

local set_commentstring = function(commentstring)
  api.nvim_set_option_value('commentstring', commentstring, { buf = 0 })
end

local get_lines = function(from, to)
  from, to = from or 0, to or -1
  return api.nvim_buf_get_lines(0, from, to, false)
end

local set_lines = function(lines, from, to)
  from, to = from or 0, to or -1
  api.nvim_buf_set_lines(0, from, to, false, lines)
end

local set_cursor = function(row, col)
  api.nvim_win_set_cursor(0, { row, col })
end

local get_cursor = function()
  return api.nvim_win_get_cursor(0)
end

local setup_treesitter = function()
  -- NOTE: This leverages bundled Vimscript and Lua tree-sitter parsers
  api.nvim_set_option_value('filetype', 'vim', { buf = 0 })
  exec_lua('vim.treesitter.start()')
end

before_each(function()
  -- avoid options, but we still need TS parsers
  clear({ args_rm = { '--cmd' }, args = { '--clean', '--cmd', n.runtime_set } })
end)

describe('commenting', function()
  before_each(function()
    set_lines(example_lines)
    set_commentstring('# %s')
  end)

  describe('toggle_lines()', function()
    local toggle_lines = function(...)
      exec_lua('require("vim._comment").toggle_lines(...)', ...)
    end

    it('works', function()
      toggle_lines(3, 5)
      eq({ '  # aa', '  #', '  # aa' }, get_lines(2, 5))

      toggle_lines(3, 5)
      eq({ '  aa', '', '  aa' }, get_lines(2, 5))
    end)

    it("works with different 'commentstring' options", function()
      local validate = function(lines_before, lines_after, lines_again)
        set_lines(lines_before)
        toggle_lines(1, #lines_before)
        eq(lines_after, get_lines())
        toggle_lines(1, #lines_before)
        eq(lines_again or lines_before, get_lines())
      end

      -- Single whitespace inside comment parts (main case)
      set_commentstring('# %s #')
      -- - General case
      validate(
        { 'aa', '  aa', 'aa  ', '  aa  ' },
        { '# aa #', '#   aa #', '# aa   #', '#   aa   #' }
      )
      -- - Tabs
      validate(
        { 'aa', '\taa', 'aa\t', '\taa\t' },
        { '# aa #', '# \taa #', '# aa\t #', '# \taa\t #' }
      )
      -- - With indent
      validate({ ' aa', '  aa' }, { ' # aa #', ' #  aa #' })
      -- - With blank/empty lines
      validate(
        { '  aa', '', '  ', '\t' },
        { '  # aa #', '  ##', '  ##', '  ##' },
        { '  aa', '', '', '' }
      )

      set_commentstring('# %s')
      validate({ 'aa', '  aa', 'aa  ', '  aa  ' }, { '# aa', '#   aa', '# aa  ', '#   aa  ' })
      validate({ 'aa', '\taa', 'aa\t', '\taa\t' }, { '# aa', '# \taa', '# aa\t', '# \taa\t' })
      validate({ ' aa', '  aa' }, { ' # aa', ' #  aa' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '  # aa', '  #', '  #', '  #' },
        { '  aa', '', '', '' }
      )

      set_commentstring('%s #')
      validate({ 'aa', '  aa', 'aa  ', '  aa  ' }, { 'aa #', '  aa #', 'aa   #', '  aa   #' })
      validate({ 'aa', '\taa', 'aa\t', '\taa\t' }, { 'aa #', '\taa #', 'aa\t #', '\taa\t #' })
      validate({ ' aa', '  aa' }, { ' aa #', '  aa #' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '  aa #', '  #', '  #', '  #' },
        { '  aa', '', '', '' }
      )

      -- No whitespace in parts
      set_commentstring('#%s#')
      validate({ 'aa', '  aa', 'aa  ', '  aa  ' }, { '#aa#', '#  aa#', '#aa  #', '#  aa  #' })
      validate({ 'aa', '\taa', 'aa\t', '\taa\t' }, { '#aa#', '#\taa#', '#aa\t#', '#\taa\t#' })
      validate({ ' aa', '  aa' }, { ' #aa#', ' # aa#' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '  #aa#', '  ##', '  ##', '  ##' },
        { '  aa', '', '', '' }
      )

      set_commentstring('#%s')
      validate({ 'aa', '  aa', 'aa  ', '  aa  ' }, { '#aa', '#  aa', '#aa  ', '#  aa  ' })
      validate({ 'aa', '\taa', 'aa\t', '\taa\t' }, { '#aa', '#\taa', '#aa\t', '#\taa\t' })
      validate({ ' aa', '  aa' }, { ' #aa', ' # aa' })
      validate({ '  aa', '', '  ', '\t' }, { '  #aa', '  #', '  #', '  #' }, { '  aa', '', '', '' })

      set_commentstring('%s#')
      validate({ 'aa', '  aa', 'aa  ', '  aa  ' }, { 'aa#', '  aa#', 'aa  #', '  aa  #' })
      validate({ 'aa', '\taa', 'aa\t', '\taa\t' }, { 'aa#', '\taa#', 'aa\t#', '\taa\t#' })
      validate({ ' aa', '  aa' }, { ' aa#', '  aa#' })
      validate({ '  aa', '', '  ', '\t' }, { '  aa#', '  #', '  #', '  #' }, { '  aa', '', '', '' })

      -- Extra whitespace inside comment parts
      set_commentstring('#  %s  #')
      validate(
        { 'aa', '  aa', 'aa  ', '  aa  ' },
        { '#  aa  #', '#    aa  #', '#  aa    #', '#    aa    #' }
      )
      validate(
        { 'aa', '\taa', 'aa\t', '\taa\t' },
        { '#  aa  #', '#  \taa  #', '#  aa\t  #', '#  \taa\t  #' }
      )
      validate({ ' aa', '  aa' }, { ' #  aa  #', ' #   aa  #' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '  #  aa  #', '  ##', '  ##', '  ##' },
        { '  aa', '', '', '' }
      )

      set_commentstring('#  %s')
      validate({ 'aa', '  aa', 'aa  ', '  aa  ' }, { '#  aa', '#    aa', '#  aa  ', '#    aa  ' })
      validate({ 'aa', '\taa', 'aa\t', '\taa\t' }, { '#  aa', '#  \taa', '#  aa\t', '#  \taa\t' })
      validate({ ' aa', '  aa' }, { ' #  aa', ' #   aa' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '  #  aa', '  #', '  #', '  #' },
        { '  aa', '', '', '' }
      )

      set_commentstring('%s  #')
      validate({ 'aa', '  aa', 'aa  ', '  aa  ' }, { 'aa  #', '  aa  #', 'aa    #', '  aa    #' })
      validate({ 'aa', '\taa', 'aa\t', '\taa\t' }, { 'aa  #', '\taa  #', 'aa\t  #', '\taa\t  #' })
      validate({ ' aa', '  aa' }, { ' aa  #', '  aa  #' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '  aa  #', '  #', '  #', '  #' },
        { '  aa', '', '', '' }
      )

      -- Whitespace outside of comment parts
      set_commentstring(' # %s # ')
      validate(
        { 'aa', '  aa', 'aa  ', '  aa  ' },
        { ' # aa # ', ' #   aa # ', ' # aa   # ', ' #   aa   # ' }
      )
      validate(
        { 'aa', '\taa', 'aa\t', '\taa\t' },
        { ' # aa # ', ' # \taa # ', ' # aa\t # ', ' # \taa\t # ' }
      )
      validate({ ' aa', '  aa' }, { '  # aa # ', '  #  aa # ' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '   # aa # ', '  ##', '  ##', '  ##' },
        { '  aa', '', '', '' }
      )

      set_commentstring(' # %s ')
      validate(
        { 'aa', '  aa', 'aa  ', '  aa  ' },
        { ' # aa ', ' #   aa ', ' # aa   ', ' #   aa   ' }
      )
      validate(
        { 'aa', '\taa', 'aa\t', '\taa\t' },
        { ' # aa ', ' # \taa ', ' # aa\t ', ' # \taa\t ' }
      )
      validate({ ' aa', '  aa' }, { '  # aa ', '  #  aa ' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '   # aa ', '  #', '  #', '  #' },
        { '  aa', '', '', '' }
      )

      set_commentstring(' %s # ')
      validate(
        { 'aa', '  aa', 'aa  ', '  aa  ' },
        { ' aa # ', '   aa # ', ' aa   # ', '   aa   # ' }
      )
      validate(
        { 'aa', '\taa', 'aa\t', '\taa\t' },
        { ' aa # ', ' \taa # ', ' aa\t # ', ' \taa\t # ' }
      )
      validate({ ' aa', '  aa' }, { '  aa # ', '   aa # ' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '   aa # ', '  #', '  #', '  #' },
        { '  aa', '', '', '' }
      )

      -- LaTeX
      set_commentstring('% %s')
      validate({ 'aa', '  aa', 'aa  ', '  aa  ' }, { '% aa', '%   aa', '% aa  ', '%   aa  ' })
      validate({ 'aa', '\taa', 'aa\t', '\taa\t' }, { '% aa', '% \taa', '% aa\t', '% \taa\t' })
      validate({ ' aa', '  aa' }, { ' % aa', ' %  aa' })
      validate(
        { '  aa', '', '  ', '\t' },
        { '  % aa', '  %', '  %', '  %' },
        { '  aa', '', '', '' }
      )
    end)

    it('respects tree-sitter injections', function()
      setup_treesitter()

      local lines = {
        'set background=dark',
        'lua << EOF',
        'print(1)',
        'vim.api.nvim_exec2([[',
        '    set background=light',
        ']])',
        'EOF',
      }

      -- Single line comments
      local validate = function(line, ref_output)
        set_lines(lines)
        toggle_lines(line, line)
        eq(ref_output, get_lines(line - 1, line)[1])
      end

      validate(1, '"set background=dark')
      validate(2, '"lua << EOF')
      validate(3, '-- print(1)')
      validate(4, '-- vim.api.nvim_exec2([[')
      validate(5, '    "set background=light')
      validate(6, '-- ]])')
      validate(7, '"EOF')

      -- Multiline comments should be computed based on first line 'commentstring'
      set_lines(lines)
      toggle_lines(1, 3)
      local out_lines = get_lines()
      eq('"set background=dark', out_lines[1])
      eq('"lua << EOF', out_lines[2])
      eq('"print(1)', out_lines[3])
    end)

    it('correctly computes indent', function()
      toggle_lines(2, 4)
      eq({ ' # aa', ' #  aa', ' #' }, get_lines(1, 4))
    end)

    it('correctly detects comment/uncomment', function()
      local validate = function(from, to, ref_lines)
        set_lines({ '', 'aa', '# aa', '# aa', 'aa', '' })
        toggle_lines(from, to)
        eq(ref_lines, get_lines())
      end

      -- It should uncomment only if all non-blank lines are comments
      validate(3, 4, { '', 'aa', 'aa', 'aa', 'aa', '' })
      validate(2, 4, { '', '# aa', '# # aa', '# # aa', 'aa', '' })
      validate(3, 5, { '', 'aa', '# # aa', '# # aa', '# aa', '' })
      validate(1, 6, { '#', '# aa', '# # aa', '# # aa', '# aa', '#' })

      -- Blank lines should be ignored when making a decision
      set_lines({ '# aa', '', '  ', '\t', '# aa' })
      toggle_lines(1, 5)
      eq({ 'aa', '', '  ', '\t', 'aa' }, get_lines())
    end)

    it('correctly matches comment parts during checking and uncommenting', function()
      local validate = function(from, to, ref_lines)
        set_lines({ '/*aa*/', '/* aa */', '/*  aa  */' })
        toggle_lines(from, to)
        eq(ref_lines, get_lines())
      end

      -- Should first try to match 'commentstring' parts exactly with their
      -- whitespace, with fallback on trimmed parts
      set_commentstring('/*%s*/')
      validate(1, 3, { 'aa', ' aa ', '  aa  ' })
      validate(2, 3, { '/*aa*/', ' aa ', '  aa  ' })
      validate(3, 3, { '/*aa*/', '/* aa */', '  aa  ' })

      set_commentstring('/* %s */')
      validate(1, 3, { 'aa', 'aa', ' aa ' })
      validate(2, 3, { '/*aa*/', 'aa', ' aa ' })
      validate(3, 3, { '/*aa*/', '/* aa */', ' aa ' })

      set_commentstring('/*  %s  */')
      validate(1, 3, { 'aa', ' aa ', 'aa' })
      validate(2, 3, { '/*aa*/', ' aa ', 'aa' })
      validate(3, 3, { '/*aa*/', '/* aa */', 'aa' })

      set_commentstring(' /*%s*/ ')
      validate(1, 3, { 'aa', ' aa ', '  aa  ' })
      validate(2, 3, { '/*aa*/', ' aa ', '  aa  ' })
      validate(3, 3, { '/*aa*/', '/* aa */', '  aa  ' })
    end)

    it('uncomments on inconsistent indent levels', function()
      set_lines({ '# aa', ' # aa', '  # aa' })
      toggle_lines(1, 3)
      eq({ 'aa', ' aa', '  aa' }, get_lines())
    end)

    it('respects tabs', function()
      api.nvim_set_option_value('expandtab', false, { buf = 0 })
      set_lines({ '\t\taa', '\t\taa' })

      toggle_lines(1, 2)
      eq({ '\t\t# aa', '\t\t# aa' }, get_lines())

      toggle_lines(1, 2)
      eq({ '\t\taa', '\t\taa' }, get_lines())
    end)

    it('works with trailing whitespace', function()
      -- Without right-hand side
      set_commentstring('# %s')
      set_lines({ ' aa', ' aa  ', '  ' })
      toggle_lines(1, 3)
      eq({ ' # aa', ' # aa  ', ' #' }, get_lines())
      toggle_lines(1, 3)
      eq({ ' aa', ' aa  ', '' }, get_lines())

      -- With right-hand side
      set_commentstring('%s #')
      set_lines({ ' aa', ' aa  ', '  ' })
      toggle_lines(1, 3)
      eq({ ' aa #', ' aa   #', ' #' }, get_lines())
      toggle_lines(1, 3)
      eq({ ' aa', ' aa  ', '' }, get_lines())

      -- Trailing whitespace after right side should be preserved for non-blanks
      set_commentstring('%s #')
      set_lines({ ' aa #  ', ' aa #\t', ' #  ', ' #\t' })
      toggle_lines(1, 4)
      eq({ ' aa  ', ' aa\t', '', '' }, get_lines())
    end)
  end)

  describe('Operator', function()
    it('works in Normal mode', function()
      set_cursor(2, 2)
      feed('gc', 'ap')
      eq({ '# aa', '#  aa', '#   aa', '#', '  aa', ' aa', 'aa' }, get_lines())
      -- Cursor moves to start line
      eq({ 1, 0 }, get_cursor())

      -- Supports `v:count`
      set_lines(example_lines)
      set_cursor(2, 0)
      feed('2gc', 'ap')
      eq({ '# aa', '#  aa', '#   aa', '#', '#   aa', '#  aa', '# aa' }, get_lines())
    end)

    it('allows dot-repeat in Normal mode', function()
      local doubly_commented = { '# # aa', '# #  aa', '# #   aa', '# #', '#   aa', '#  aa', '# aa' }

      set_lines(example_lines)
      set_cursor(2, 2)
      feed('gc', 'ap')
      feed('.')
      eq(doubly_commented, get_lines())

      -- Not immediate dot-repeat
      set_lines(example_lines)
      set_cursor(2, 2)
      feed('gc', 'ap')
      set_cursor(7, 0)
      feed('.')
      eq(doubly_commented, get_lines())
    end)

    it('works in Visual mode', function()
      set_cursor(2, 2)
      feed('v', 'ap', 'gc')
      eq({ '# aa', '#  aa', '#   aa', '#', '  aa', ' aa', 'aa' }, get_lines())

      -- Cursor moves to start line
      eq({ 1, 0 }, get_cursor())
    end)

    it('allows dot-repeat after initial Visual mode', function()
      -- local example_lines = { 'aa', ' aa', '  aa', '', '  aa', ' aa', 'aa' }

      set_lines(example_lines)
      set_cursor(2, 2)
      feed('vip', 'gc')
      eq({ '# aa', '#  aa', '#   aa', '', '  aa', ' aa', 'aa' }, get_lines())
      eq({ 1, 0 }, get_cursor())

      -- Dot-repeat after first application in Visual mode applies to the paragraph at cursor (not
      -- a fixed-size region).
      feed('.')
      eq(example_lines, get_lines())

      set_cursor(3, 0)
      feed('.')
      eq({ '# aa', '#  aa', '#   aa', '', '  aa', ' aa', 'aa' }, get_lines())
    end)

    it("respects 'commentstring'", function()
      set_commentstring('/*%s*/')
      set_cursor(2, 2)
      feed('gc', 'ap')
      eq({ '/*aa*/', '/* aa*/', '/*  aa*/', '/**/', '  aa', ' aa', 'aa' }, get_lines())
    end)

    it("works with empty 'commentstring'", function()
      set_commentstring('')
      set_cursor(2, 2)
      feed('gc', 'ap')
      eq(example_lines, get_lines())
      eq([[Option 'commentstring' is empty.]], exec_capture('1messages'))
    end)

    it('respects tree-sitter injections', function()
      setup_treesitter()

      local lines = {
        'set background=dark',
        'lua << EOF',
        'print(1)',
        'vim.api.nvim_exec2([[',
        '    set background=light',
        ']])',
        'EOF',
      }

      -- Single line comments
      local validate = function(line, ref_output)
        set_lines(lines)
        set_cursor(line, 0)
        feed('gc_')
        eq(ref_output, get_lines(line - 1, line)[1])
      end

      validate(1, '"set background=dark')
      validate(2, '"lua << EOF')
      validate(3, '-- print(1)')
      validate(4, '-- vim.api.nvim_exec2([[')
      validate(5, '    "set background=light')
      validate(6, '-- ]])')
      validate(7, '"EOF')

      -- Has proper dot-repeat which recomputes 'commentstring'
      set_lines(lines)

      set_cursor(1, 0)
      feed('gc_')
      eq('"set background=dark', get_lines()[1])

      set_cursor(3, 0)
      feed('.')
      eq('-- print(1)', get_lines()[3])

      -- Multiline comments should be computed based on cursor position
      -- which in case of Visual selection means its left part
      set_lines(lines)
      set_cursor(1, 0)
      feed('v2j', 'gc')
      local out_lines = get_lines()
      eq('"set background=dark', out_lines[1])
      eq('"lua << EOF', out_lines[2])
      eq('"print(1)', out_lines[3])
    end)

    it("recomputes local 'commentstring' based on cursor position", function()
      setup_treesitter()
      local lines = {
        '  print(1)',
        'lua << EOF',
        '  print(1)',
        'EOF',
      }
      set_lines(lines)

      set_cursor(1, 1)
      feed('gc_')
      eq('  "print(1)', get_lines()[1])

      set_lines(lines)
      set_cursor(3, 2)
      feed('.')
      eq('  -- print(1)', get_lines()[3])
    end)

    it('preserves marks', function()
      set_cursor(2, 0)
      -- Set '`<' and '`>' marks
      feed('VV')
      feed('gc', 'ip')
      eq({ 2, 0 }, api.nvim_buf_get_mark(0, '<'))
      eq({ 2, 2147483647 }, api.nvim_buf_get_mark(0, '>'))
    end)
  end)

  describe('Current line', function()
    it('works', function()
      set_lines(example_lines)
      set_cursor(1, 1)
      feed('gcc')
      eq({ '# aa', ' aa' }, get_lines(0, 2))

      -- Does not comment empty line
      set_lines(example_lines)
      set_cursor(4, 0)
      feed('gcc')
      eq({ '  aa', '', '  aa' }, get_lines(2, 5))

      -- Supports `v:count`
      set_lines(example_lines)
      set_cursor(2, 0)
      feed('2gcc')
      eq({ 'aa', ' # aa', ' #  aa' }, get_lines(0, 3))
    end)

    it('allows dot-repeat', function()
      set_lines(example_lines)
      set_cursor(1, 1)
      feed('gcc')
      feed('.')
      eq(example_lines, get_lines())

      -- Not immediate dot-repeat
      set_lines(example_lines)
      set_cursor(1, 1)
      feed('gcc')
      set_cursor(7, 0)
      feed('.')
      eq({ '# aa' }, get_lines(6, 7))
    end)

    it('respects tree-sitter injections', function()
      setup_treesitter()

      local lines = {
        'set background=dark',
        'lua << EOF',
        'print(1)',
        'EOF',
      }
      set_lines(lines)

      set_cursor(1, 0)
      feed('gcc')
      eq({ '"set background=dark', 'lua << EOF', 'print(1)', 'EOF' }, get_lines())

      -- Should work with dot-repeat
      set_cursor(3, 0)
      feed('.')
      eq({ '"set background=dark', 'lua << EOF', '-- print(1)', 'EOF' }, get_lines())
    end)

    it('respects tree-sitter commentstring metadata', function()
      exec_lua [=[
        vim.treesitter.query.set('vim', 'highlights', [[
          ((list) @_list (#set! @_list bo.commentstring "!! %s"))
        ]])
      ]=]
      setup_treesitter()

      local lines = {
        'set background=dark',
        'let mylist = [',
        [[  \"a",]],
        [[  \"b",]],
        [[  \"c",]],
        '  \\]',
      }
      set_lines(lines)

      set_cursor(1, 0)
      feed('gcc')
      eq(
        { '"set background=dark', 'let mylist = [', [[  \"a",]], [[  \"b",]], [[  \"c",]], '  \\]' },
        get_lines()
      )

      -- Should work with dot-repeat
      set_cursor(4, 0)
      feed('.')
      eq({
        '"set background=dark',
        'let mylist = [',
        [[  \"a",]],
        [[  !! \"b",]],
        [[  \"c",]],
        '  \\]',
      }, get_lines())
    end)

    it('only applies the innermost tree-sitter commentstring metadata', function()
      exec_lua [=[
        vim.treesitter.query.set('vim', 'highlights', [[
          ((list) @_list (#gsub! @_list "(.*)" "%1") (#set! bo.commentstring "!! %s"))
          ((script_file) @_src (#set! @_src bo.commentstring "## %s"))
        ]])
      ]=]
      setup_treesitter()

      local lines = {
        'set background=dark',
        'let mylist = [',
        [[  \"a",]],
        [[  \"b",]],
        [[  \"c",]],
        '  \\]',
      }
      set_lines(lines)

      set_cursor(1, 0)
      feed('gcc')
      eq({
        '## set background=dark',
        'let mylist = [',
        [[  \"a",]],
        [[  \"b",]],
        [[  \"c",]],
        '  \\]',
      }, get_lines())

      -- Should work with dot-repeat
      set_cursor(4, 0)
      feed('.')
      eq({
        '## set background=dark',
        'let mylist = [',
        [[  \"a",]],
        [[  !! \"b",]],
        [[  \"c",]],
        '  \\]',
      }, get_lines())
    end)

    it('respects injected tree-sitter commentstring metadata', function()
      exec_lua [=[
        vim.treesitter.query.set('lua', 'highlights', [[
          ((string) @string (#set! @string bo.commentstring "; %s"))
        ]])
      ]=]
      setup_treesitter()

      local lines = {
        'set background=dark',
        'lua << EOF',
        'print[[',
        'Inside string',
        ']]',
        'EOF',
      }
      set_lines(lines)

      set_cursor(1, 0)
      feed('gcc')
      eq({
        '"set background=dark',
        'lua << EOF',
        'print[[',
        'Inside string',
        ']]',
        'EOF',
      }, get_lines())

      -- Should work with dot-repeat
      set_cursor(4, 0)
      feed('.')
      eq({
        '"set background=dark',
        'lua << EOF',
        'print[[',
        '; Inside string',
        ']]',
        'EOF',
      }, get_lines())

      set_cursor(3, 0)
      feed('.')
      eq({
        '"set background=dark',
        'lua << EOF',
        '-- print[[',
        '; Inside string',
        ']]',
        'EOF',
      }, get_lines())
    end)

    it('works across combined injections #30799', function()
      exec_lua [=[
        vim.treesitter.query.set('lua', 'injections', [[
          ((function_call
            name: (_) @_vimcmd_identifier
            arguments: (arguments
              (string
                content: _ @injection.content)))
            (#eq? @_vimcmd_identifier "vim.cmd")
            (#set! injection.language "vim")
            (#set! injection.combined))
        ]])
      ]=]

      api.nvim_set_option_value('filetype', 'lua', { buf = 0 })
      exec_lua('vim.treesitter.start()')

      local lines = {
        'vim.cmd([[" some text]])',
        'local a = 123',
        'vim.cmd([[" some more text]])',
      }
      set_lines(lines)

      set_cursor(2, 0)
      feed('gcc')
      eq({
        'vim.cmd([[" some text]])',
        '-- local a = 123',
        'vim.cmd([[" some more text]])',
      }, get_lines())
    end)
  end)

  describe('Textobject', function()
    it('works', function()
      set_lines({ 'aa', '# aa', '# aa', 'aa' })
      set_cursor(2, 0)
      feed('d', 'gc')
      eq({ 'aa', 'aa' }, get_lines())
    end)

    it('allows dot-repeat', function()
      set_lines({ 'aa', '# aa', '# aa', 'aa', '# aa' })
      set_cursor(2, 0)
      feed('d', 'gc')
      set_cursor(3, 0)
      feed('.')
      eq({ 'aa', 'aa' }, get_lines())
    end)

    it('does nothing when not inside textobject', function()
      -- Builtin operators
      feed('d', 'gc')
      eq(example_lines, get_lines())

      -- Comment operator
      local validate_no_action = function(line, col)
        set_lines(example_lines)
        set_cursor(line, col)
        feed('gc', 'gc')
        eq(example_lines, get_lines())
      end

      validate_no_action(1, 1)
      validate_no_action(2, 2)

      -- Doesn't work (but should) because both `[` and `]` are set to (1, 0)
      -- (instead of more reasonable (1, -1) or (0, 2147483647)).
      -- validate_no_action(1, 0)
    end)

    it('respects tree-sitter injections', function()
      setup_treesitter()
      local lines = {
        '"set background=dark',
        '"set termguicolors',
        'lua << EOF',
        '-- print(1)',
        '-- print(2)',
        'EOF',
      }
      set_lines(lines)

      set_cursor(1, 0)
      feed('dgc')
      eq({ 'lua << EOF', '-- print(1)', '-- print(2)', 'EOF' }, get_lines())

      -- Should work with dot-repeat
      set_cursor(2, 0)
      feed('.')
      eq({ 'lua << EOF', 'EOF' }, get_lines())
    end)
  end)
end)
