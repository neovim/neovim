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

    exec_lua(function()
      vim.treesitter.start(0, 'lua')
      vim.treesitter.inspect_tree()
    end)

    expect_tree [[
      (chunk ; [0, 0] - [2, 0]
        (function_call ; [0, 0] - [0, 7]
          name: (identifier) ; [0, 0] - [0, 5]
          arguments: (arguments))) ; [0, 5] - [0, 7]
      ]]
  end)

  it('can toggle to show anonymous nodes', function()
    insert([[
      print('hello')
      ]])

    exec_lua(function()
      vim.treesitter.start(0, 'lua')
      vim.treesitter.inspect_tree()
    end)
    feed('a')

    expect_tree [[
      (chunk ; [0, 0] - [2, 0]
        (function_call ; [0, 0] - [0, 14]
          name: (identifier) ; [0, 0] - [0, 5]
          arguments: (arguments ; [0, 5] - [0, 14]
            "(" ; [0, 5] - [0, 6]
            (string ; [0, 6] - [0, 13]
              start: "'" ; [0, 6] - [0, 7]
              content: (string_content) ; [0, 7] - [0, 12]
              end: "'") ; [0, 12] - [0, 13]
            ")"))) ; [0, 13] - [0, 14]
      ]]
  end)

  it('works for injected trees', function()
    insert([[
      ```lua
      return
      ```
      ]])

    exec_lua(function()
      vim.treesitter.start(0, 'markdown')
      vim.treesitter.get_parser():parse()
      vim.treesitter.inspect_tree()
    end)

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

    exec_lua(function()
      vim.treesitter.start(0, 'markdown')
      vim.treesitter.get_parser():parse()
      vim.treesitter.inspect_tree()
    end)
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
    local name = t.tmpname()
    n.command('edit ' .. name)
    insert([[
      print()
      ]])
    n.command('set filetype=lua | write')

    -- setup two windows for the source buffer
    exec_lua(function()
      _G.source_win = vim.api.nvim_get_current_win()
      _G.source_win2 = vim.api.nvim_open_win(0, false, {
        win = 0,
        split = 'left',
      })
    end)

    -- setup three windows for the tree buffer
    exec_lua(function()
      vim.treesitter.inspect_tree()
      _G.tree_win = vim.api.nvim_get_current_win()
      _G.tree_win2 = vim.api.nvim_open_win(0, false, {
        win = 0,
        split = 'left',
      })
      _G.tree_win3 = vim.api.nvim_open_win(0, false, {
        win = 0,
        split = 'left',
      })
    end)

    -- close original source window without closing tree views
    exec_lua('vim.api.nvim_set_current_win(source_win)')
    feed(':quit<CR>')
    eq('', n.api.nvim_get_vvar('errmsg'))
    eq(true, exec_lua('return vim.api.nvim_win_is_valid(tree_win)'))
    eq(true, exec_lua('return vim.api.nvim_win_is_valid(tree_win2)'))
    eq(true, exec_lua('return vim.api.nvim_win_is_valid(tree_win3)'))

    -- navigates correctly to the remaining source buffer window
    exec_lua('vim.api.nvim_set_current_win(tree_win)')
    feed('<CR>')
    eq('', n.api.nvim_get_vvar('errmsg'))
    eq(true, exec_lua('return vim.api.nvim_get_current_win() == source_win2'))

    -- close original tree window
    exec_lua(function()
      vim.api.nvim_set_current_win(_G.tree_win2)
      vim.api.nvim_win_close(_G.tree_win, false)
    end)

    -- navigates correctly to the remaining source buffer window
    feed('<CR>')
    eq('', n.api.nvim_get_vvar('errmsg'))
    eq(true, exec_lua('return vim.api.nvim_get_current_win() == source_win2'))

    -- close source buffer window and all remaining tree windows
    n.expect_exit(n.command, 'quit')
  end)

  it('shows which nodes are missing', function()
    insert([[
      int main() {
          if (a.) {
          //    ^ MISSING field_identifier here
              if (1) d()
              //        ^ MISSING ";" here
          }
      }
      ]])

    exec_lua(function()
      vim.treesitter.start(0, 'c')
      vim.treesitter.inspect_tree()
    end)
    feed('a')

    expect_tree [[
      (translation_unit ; [0, 0] - [8, 0]
        (function_definition ; [0, 0] - [6, 1]
          type: (primitive_type) ; [0, 0] - [0, 3]
          declarator: (function_declarator ; [0, 4] - [0, 10]
            declarator: (identifier) ; [0, 4] - [0, 8]
            parameters: (parameter_list ; [0, 8] - [0, 10]
              "(" ; [0, 8] - [0, 9]
              ")")) ; [0, 9] - [0, 10]
          body: (compound_statement ; [0, 11] - [6, 1]
            "{" ; [0, 11] - [0, 12]
            (if_statement ; [1, 4] - [5, 5]
              "if" ; [1, 4] - [1, 6]
              condition: (parenthesized_expression ; [1, 7] - [1, 11]
                "(" ; [1, 7] - [1, 8]
                (field_expression ; [1, 8] - [1, 10]
                  argument: (identifier) ; [1, 8] - [1, 9]
                  operator: "." ; [1, 9] - [1, 10]
                  field: (MISSING field_identifier)) ; [1, 10] - [1, 10]
                ")") ; [1, 10] - [1, 11]
              consequence: (compound_statement ; [1, 12] - [5, 5]
                "{" ; [1, 12] - [1, 13]
                (comment) ; [2, 4] - [2, 41]
                (if_statement ; [3, 8] - [4, 36]
                  "if" ; [3, 8] - [3, 10]
                  condition: (parenthesized_expression ; [3, 11] - [3, 14]
                    "(" ; [3, 11] - [3, 12]
                    (number_literal) ; [3, 12] - [3, 13]
                    ")") ; [3, 13] - [3, 14]
                  consequence: (expression_statement ; [3, 15] - [4, 36]
                    (call_expression ; [3, 15] - [3, 18]
                      function: (identifier) ; [3, 15] - [3, 16]
                      arguments: (argument_list ; [3, 16] - [3, 18]
                        "(" ; [3, 16] - [3, 17]
                        ")")) ; [3, 17] - [3, 18]
                    (comment) ; [4, 8] - [4, 36]
                    (MISSING ";"))) ; [4, 36] - [4, 36]
                "}")) ; [5, 4] - [5, 5]
            "}"))) ; [6, 0] - [6, 1]
      ]]
  end)
end)
