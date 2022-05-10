local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua

before_each(clear)

describe('vim.treesitter.get_query_files', function()
  it('returns query files for specific language', function()
    exec_lua [[
      query_files = vim.treesitter.get_query_files('c', 'highlights')
    ]]
    eq(1, exec_lua "return #query_files")
  end)

  it('respects config: query_file_ignore', function()
    -- adding ignore pattern
    exec_lua [[
      vim.treesitter.config({
        query_file_ignore = { "/runtime/" }
      }, "c")
      query_files = vim.treesitter.get_query_files('c', 'highlights')
    ]]
    eq(0, exec_lua "return #query_files")

    -- removing ignore pattern
    exec_lua [[
      vim.treesitter.config({
        query_file_ignore = {}
      }, "c")
      query_files = vim.treesitter.get_query_files('c', 'highlights')
    ]]
    eq(1, exec_lua "return #query_files")

    -- adding ignore pattern (using callback function)
    exec_lua [[
      vim.treesitter.config({
        query_file_ignore = function(patterns)
          table.insert(patterns, "/runtime/")
          return patterns
        end
      }, "c")
      query_files = vim.treesitter.get_query_files('c', 'highlights')
    ]]
    eq(0, exec_lua "return #query_files")

    -- removing ignore pattern (using callback function)
    exec_lua [[
      vim.treesitter.config({
        query_file_ignore = function(patterns)
          return nil
        end
      }, "c")
      query_files = vim.treesitter.get_query_files('c', 'highlights')
    ]]
    eq(1, exec_lua "return #query_files")
  end)
end)
