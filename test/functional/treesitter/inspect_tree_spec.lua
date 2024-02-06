local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local insert = helpers.insert
local dedent = helpers.dedent
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local feed = helpers.feed

describe('vim.treesitter.inspect_tree', function()
  before_each(clear)

  local expect_tree = function(x)
    local expected = vim.split(vim.trim(dedent(x)), '\n')
    local actual = helpers.buf_lines(0) ---@type string[]
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
end)
