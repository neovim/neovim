local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local eq = helpers.eq

before_each(clear)

describe('Query:iter_captures', function()
  it('includes metadata for all captured nodes #23664', function()
    insert([[
      const char *sql = "SELECT * FROM Students WHERE name = 'Robert'); DROP TABLE Students;--";
    ]])

    local query = [[
      (declaration
        type: (_)
        declarator: (init_declarator
          declarator: (pointer_declarator
            declarator: (identifier)) @_id
          value: (string_literal
            (string_content) @injection.content))
        (#set! injection.language "sql")
        (#contains? @_id "sql"))
    ]]

    local result = exec_lua(
      [[
      local injections = vim.treesitter.query.parse("c", ...)
      local parser = vim.treesitter.get_parser(0, "c")
      local root = parser:parse()[1]:root()
      local t = {}
      for id, node, metadata in injections:iter_captures(root, 0) do
        t[id] = metadata
      end
      return t
    ]],
      query
    )

    eq({
      [1] = { ['injection.language'] = 'sql' },
      [2] = { ['injection.language'] = 'sql' },
    }, result)
  end)

  it('only evaluates predicates once per match', function()
    insert([[
      void foo(int x, int y);
    ]])
    local query = [[
      (declaration
        type: (_)
        declarator: (function_declarator
          declarator: (identifier) @function.name
          parameters: (parameter_list
            (parameter_declaration
              type: (_)
              declarator: (identifier) @argument)))
        (#eq? @function.name "foo"))
    ]]

    local result = exec_lua(
      [[
      local query = vim.treesitter.query.parse("c", ...)
      local match_preds = query.match_preds
      local called = 0
      function query:match_preds(...)
        called = called + 1
        return match_preds(self, ...)
      end
      local parser = vim.treesitter.get_parser(0, "c")
      local root = parser:parse()[1]:root()
      local captures = {}
      for id, node in query:iter_captures(root, 0) do
        captures[#captures + 1] = id
      end
      return { called, captures }
    ]],
      query
    )

    eq({ 2, { 1, 1, 2, 2 } }, result)
  end)
end)
