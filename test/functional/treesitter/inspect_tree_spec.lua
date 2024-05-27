local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local insert = n.insert
local dedent = t.dedent
local eq = t.eq
local exec_lua = n.exec_lua
local feed = n.feed

describe('vim.treesitter.inspect_tree', function()
  before_each(clear)

  local expect_tree = function(x)
    local expected = vim.split(vim.trim(dedent(x)), '\n')
    local actual = n.buf_lines(0) ---@type string[]
    eq(expected, actual)
  end

  it('working', function()
    insert([[
      print()
      ]])

    exec_lua([[
      vim.treesitter.start(0, 'lua')
      vim.treesitter.inspect_tree()
    ]])

    expect_tree [[
      (chunk ; [0, 0] - [2, 0]
        (function_call ; [0, 0] - [0, 7]
          name: (identifier) ; [0, 0] - [0, 5]
          arguments: (arguments))) ; [0, 5] - [0, 7]
      ]]
  end)

  it('can toggle to show anonymous nodes', function()
    insert([[
      print()
      ]])

    exec_lua([[
      vim.treesitter.start(0, 'lua')
      vim.treesitter.inspect_tree()
    ]])
    feed('a')

    expect_tree [[
      (chunk ; [0, 0] - [2, 0]
        (function_call ; [0, 0] - [0, 7]
          name: (identifier) ; [0, 0] - [0, 5]
          arguments: (arguments ; [0, 5] - [0, 7]
            "(" ; [0, 5] - [0, 6]
            ")"))) ; [0, 6] - [0, 7]
      ]]
  end)

  it('works for injected trees', function()
    insert([[
      ```lua
      return
      ```
      ]])

    exec_lua([[
      vim.treesitter.start(0, 'markdown')
      vim.treesitter.get_parser():parse()
      vim.treesitter.inspect_tree()
    ]])

    expect_tree [[
      (document ; [0, 0] - [4, 0]
        (section ; [0, 0] - [4, 0]
          (fenced_code_block ; [0, 0] - [3, 0]
            (fenced_code_block_delimiter) ; [0, 0] - [0, 3]
            (info_string ; [0, 3] - [0, 6]
              (language)) ; [0, 3] - [0, 6]
            (block_continuation) ; [1, 0] - [1, 0]
            (code_fence_content ; [1, 0] - [2, 0]
              (chunk ; [1, 0] - [2, 0]
                (return_statement)) ; [1, 0] - [1, 6]
              (block_continuation)) ; [2, 0] - [2, 0]
            (fenced_code_block_delimiter)))) ; [2, 0] - [2, 3]
      ]]
  end)

  it('can toggle to show languages', function()
    insert([[
      ```lua
      return
      ```
      ]])

    exec_lua([[
      vim.treesitter.start(0, 'markdown')
      vim.treesitter.get_parser():parse()
      vim.treesitter.inspect_tree()
    ]])
    feed('I')

    expect_tree [[
      (document ; [0, 0] - [4, 0] markdown
        (section ; [0, 0] - [4, 0] markdown
          (fenced_code_block ; [0, 0] - [3, 0] markdown
            (fenced_code_block_delimiter) ; [0, 0] - [0, 3] markdown
            (info_string ; [0, 3] - [0, 6] markdown
              (language)) ; [0, 3] - [0, 6] markdown
            (block_continuation) ; [1, 0] - [1, 0] markdown
            (code_fence_content ; [1, 0] - [2, 0] markdown
              (chunk ; [1, 0] - [2, 0] lua
                (return_statement)) ; [1, 0] - [1, 6] lua
              (block_continuation)) ; [2, 0] - [2, 0] markdown
            (fenced_code_block_delimiter)))) ; [2, 0] - [2, 3] markdown
      ]]
  end)

  it('updates source and tree buffer windows and closes them correctly', function()
    insert([[
      print()
      ]])

    -- setup two windows for the source buffer
    exec_lua([[
      source_win = vim.api.nvim_get_current_win()
      vim.api.nvim_open_win(0, false, {
        win = 0,
        split = 'left'
      })
    ]])

    -- setup three windows for the tree buffer
    exec_lua([[
      vim.treesitter.start(0, 'lua')
      vim.treesitter.inspect_tree()
      tree_win = vim.api.nvim_get_current_win()
      tree_win_copy_1 = vim.api.nvim_open_win(0, false, {
        win = 0,
        split = 'left'
      })
      tree_win_copy_2 = vim.api.nvim_open_win(0, false, {
        win = 0,
        split = 'left'
      })
    ]])

    -- close original source window
    exec_lua('vim.api.nvim_win_close(source_win, false)')

    -- navigates correctly to the remaining source buffer window
    feed('<CR>')
    eq('', n.api.nvim_get_vvar('errmsg'))

    -- close original tree window
    exec_lua([[
       vim.api.nvim_set_current_win(tree_win_copy_1)
       vim.api.nvim_win_close(tree_win, false)
    ]])

    -- navigates correctly to the remaining source buffer window
    feed('<CR>')
    eq('', n.api.nvim_get_vvar('errmsg'))

    -- close source buffer window and all remaining tree windows
    t.pcall_err(exec_lua, 'vim.api.nvim_win_close(0, false)')

    eq(false, exec_lua('return vim.api.nvim_win_is_valid(tree_win_copy_1)'))
    eq(false, exec_lua('return vim.api.nvim_win_is_valid(tree_win_copy_2)'))
  end)
end)
