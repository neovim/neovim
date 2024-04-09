---@diagnostic disable: no-unknown
local t = require('test.functional.testutil')()
local eq = t.eq
local exec_lua = t.exec_lua

--- Convert completion results.
---
---@param line string line contents. Mark cursor position with `|`
---@param candidates lsp.CompletionList|lsp.CompletionItem[]
---@param lnum? integer 0-based, defaults to 0
---@return {items: table[], server_start_boundary: integer?}
local function complete(line, candidates, lnum)
  lnum = lnum or 0
  -- nvim_win_get_cursor returns 0 based column, line:find returns 1 based
  local cursor_col = line:find('|') - 1
  line = line:gsub('|', '')
  return exec_lua(
    [[
    local line, cursor_col, lnum, result = ...
    local line_to_cursor = line:sub(1, cursor_col)
    local client_start_boundary = vim.fn.match(line_to_cursor, '\\k*$')
    local items, server_start_boundary = require("vim.lsp._completion")._convert_results(
      line,
      lnum,
      cursor_col,
      client_start_boundary,
      nil,
      result,
      "utf-16"
    )
    return {
      items = items,
      server_start_boundary = server_start_boundary
    }
  ]],
    line,
    cursor_col,
    lnum,
    candidates
  )
end

describe('vim.lsp._completion', function()
  before_each(t.clear)

  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
  it('prefers textEdit over label as word', function()
    local range0 = {
      start = { line = 0, character = 0 },
      ['end'] = { line = 0, character = 0 },
    }
    local completion_list = {
      -- resolves into label
      { label = 'foobar', sortText = 'a', documentation = 'documentation' },
      {
        label = 'foobar',
        sortText = 'b',
        documentation = { value = 'documentation' },
      },
      -- resolves into insertText
      { label = 'foocar', sortText = 'c', insertText = 'foobar' },
      { label = 'foocar', sortText = 'd', insertText = 'foobar' },
      -- resolves into textEdit.newText
      {
        label = 'foocar',
        sortText = 'e',
        insertText = 'foodar',
        textEdit = { newText = 'foobar', range = range0 },
      },
      { label = 'foocar', sortText = 'f', textEdit = { newText = 'foobar', range = range0 } },
      -- real-world snippet text
      {
        label = 'foocar',
        sortText = 'g',
        insertText = 'foodar',
        insertTextFormat = 2,
        textEdit = {
          newText = 'foobar(${1:place holder}, ${2:more ...holder{\\}})',
          range = range0,
        },
      },
      {
        label = 'foocar',
        sortText = 'h',
        insertText = 'foodar(${1:var1} typ1, ${2:var2} *typ2) {$0\\}',
        insertTextFormat = 2,
      },
      -- nested snippet tokens
      {
        label = 'foocar',
        sortText = 'i',
        insertText = 'foodar(${1:${2|typ1,typ2|}}) {$0\\}',
        insertTextFormat = 2,
      },
      -- braced tabstop
      { label = 'foocar', sortText = 'j', insertText = 'foodar()${0}', insertTextFormat = 2 },
      -- plain text
      {
        label = 'foocar',
        sortText = 'k',
        insertText = 'foodar(${1:var1})',
        insertTextFormat = 1,
      },
    }
    local expected = {
      {
        abbr = 'foobar',
        word = 'foobar',
      },
      {
        abbr = 'foobar',
        word = 'foobar',
      },
      {
        abbr = 'foocar',
        word = 'foobar',
      },
      {
        abbr = 'foocar',
        word = 'foobar',
      },
      {
        abbr = 'foocar',
        word = 'foobar',
      },
      {
        abbr = 'foocar',
        word = 'foobar',
      },
      {
        abbr = 'foocar',
        word = 'foobar(place holder, more ...holder{})',
      },
      {
        abbr = 'foocar',
        word = 'foodar(var1 typ1, var2 *typ2) {}',
      },
      {
        abbr = 'foocar',
        word = 'foodar(typ1) {}',
      },
      {
        abbr = 'foocar',
        word = 'foodar()',
      },
      {
        abbr = 'foocar',
        word = 'foodar(${1:var1})',
      },
    }
    local result = complete('|', completion_list)
    result = vim.tbl_map(function(x)
      return {
        abbr = x.abbr,
        word = x.word,
      }
    end, result.items)
    eq(expected, result)
  end)
  it('uses correct start boundary', function()
    local completion_list = {
      isIncomplete = false,
      items = {
        {
          filterText = 'this_thread',
          insertText = 'this_thread',
          insertTextFormat = 1,
          kind = 9,
          label = ' this_thread',
          score = 1.3205767869949,
          sortText = '4056f757this_thread',
          textEdit = {
            newText = 'this_thread',
            range = {
              start = { line = 0, character = 7 },
              ['end'] = { line = 0, character = 11 },
            },
          },
        },
      },
    }
    local expected = {
      abbr = ' this_thread',
      dup = 1,
      empty = 1,
      icase = 1,
      kind = 'Module',
      menu = '',
      word = 'this_thread',
    }
    local result = complete('  std::this|', completion_list)
    eq(7, result.server_start_boundary)
    local item = result.items[1]
    item.user_data = nil
    eq(expected, item)
  end)

  it('should search from start boundary to cursor position', function()
    local completion_list = {
      isIncomplete = false,
      items = {
        {
          filterText = 'this_thread',
          insertText = 'this_thread',
          insertTextFormat = 1,
          kind = 9,
          label = ' this_thread',
          score = 1.3205767869949,
          sortText = '4056f757this_thread',
          textEdit = {
            newText = 'this_thread',
            range = {
              start = { line = 0, character = 7 },
              ['end'] = { line = 0, character = 11 },
            },
          },
        },
        {
          filterText = 'notthis_thread',
          insertText = 'notthis_thread',
          insertTextFormat = 1,
          kind = 9,
          label = ' notthis_thread',
          score = 1.3205767869949,
          sortText = '4056f757this_thread',
          textEdit = {
            newText = 'notthis_thread',
            range = {
              start = { line = 0, character = 7 },
              ['end'] = { line = 0, character = 11 },
            },
          },
        },
      },
    }
    local expected = {
      abbr = ' this_thread',
      dup = 1,
      empty = 1,
      icase = 1,
      kind = 'Module',
      menu = '',
      word = 'this_thread',
    }
    local result = complete('  std::this|is', completion_list)
    eq(1, #result.items)
    local item = result.items[1]
    item.user_data = nil
    eq(expected, item)
  end)

  it('uses defaults from itemDefaults', function()
    --- @type lsp.CompletionList
    local completion_list = {
      isIncomplete = false,
      itemDefaults = {
        editRange = {
          start = { line = 1, character = 1 },
          ['end'] = { line = 1, character = 4 },
        },
        insertTextFormat = 2,
        data = 'foobar',
      },
      items = {
        {
          label = 'hello',
          data = 'item-property-has-priority',
          textEditText = 'hello',
        },
      },
    }
    local result = complete('|', completion_list)
    eq(1, #result.items)
    local item = result.items[1].user_data.nvim.lsp.completion_item --- @type lsp.CompletionItem
    eq(2, item.insertTextFormat)
    eq('item-property-has-priority', item.data)
    eq({ line = 1, character = 1 }, item.textEdit.range.start)
  end)
end)
