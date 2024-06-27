---@diagnostic disable: no-unknown
local t = require('test.testutil')
local t_lsp = require('test.functional.plugin.lsp.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local neq = t.neq
local exec_lua = n.exec_lua
local feed = n.feed
local retry = t.retry

local create_server_definition = t_lsp.create_server_definition

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
    local items, server_start_boundary = require("vim.lsp.completion")._convert_results(
      line,
      lnum,
      cursor_col,
      1,
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

describe('vim.lsp.completion: item conversion', function()
  before_each(n.clear)

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
      -- plain text
      {
        label = 'foocar',
        sortText = 'g',
        insertText = 'foodar(${1:var1})',
        insertTextFormat = 1,
      },
      {
        label = '•INT16_C(c)',
        insertText = 'INT16_C(${1:c})',
        insertTextFormat = 2,
        filterText = 'INT16_C',
        sortText = 'h',
        textEdit = {
          newText = 'INT16_C(${1:c})',
          range = range0,
        },
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
        word = 'foodar(${1:var1})', -- marked as PlainText, text is used as is
      },
      {
        abbr = '•INT16_C(c)',
        word = 'INT16_C',
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

  it('filters on label if filterText is missing', function()
    local completion_list = {
      { label = 'foo' },
      { label = 'bar' },
    }
    local result = complete('fo|', completion_list)
    local expected = {
      {
        abbr = 'foo',
        word = 'foo',
      },
    }
    result = vim.tbl_map(function(x)
      return {
        abbr = x.abbr,
        word = x.word,
      }
    end, result.items)
    eq(expected, result)
  end)

  it('trims trailing newline or tab from textEdit', function()
    local range0 = {
      start = { line = 0, character = 0 },
      ['end'] = { line = 0, character = 0 },
    }
    local items = {
      {
        detail = 'ansible.builtin',
        filterText = 'lineinfile ansible.builtin.lineinfile builtin ansible',
        kind = 7,
        label = 'ansible.builtin.lineinfile',
        sortText = '2_ansible.builtin.lineinfile',
        textEdit = {
          newText = 'ansible.builtin.lineinfile:\n	',
          range = range0,
        },
      },
    }
    local result = complete('|', items)
    result = vim.tbl_map(function(x)
      return {
        abbr = x.abbr,
        word = x.word,
      }
    end, result.items)

    local expected = {
      {
        abbr = 'ansible.builtin.lineinfile',
        word = 'ansible.builtin.lineinfile:',
      },
    }
    eq(expected, result)
  end)

  it('prefers wordlike components for snippets', function()
    -- There are two goals here:
    --
    -- 1. The `word` should match what the user started typing, so that vim.fn.complete() doesn't
    --    filter it away, preventing snippet expansion
    --
    -- For example, if they type `items@ins`, luals returns `table.insert(items, $0)` as
    -- textEdit.newText and `insert` as label.
    -- There would be no prefix match if textEdit.newText is used as `word`
    --
    -- 2. If users do not expand a snippet, but continue typing, they should see a somewhat reasonable
    --    `word` getting inserted.
    --
    -- For example in:
    --
    --  insertText: "testSuites ${1:Env}"
    --  label: "testSuites"
    --
    -- "testSuites" should have priority as `word`, as long as the full snippet gets expanded on accept (<c-y>)
    local range0 = {
      start = { line = 0, character = 0 },
      ['end'] = { line = 0, character = 0 },
    }
    local completion_list = {
      -- luals postfix snippet (typed text: items@ins|)
      {
        label = 'insert',
        insertTextFormat = 2,
        textEdit = {
          newText = 'table.insert(items, $0)',
          range = range0,
        },
      },

      -- eclipse.jdt.ls `new` snippet
      {
        label = 'new',
        insertTextFormat = 2,
        textEdit = {
          newText = '${1:Object} ${2:foo} = new ${1}(${3});\n${0}',
          range = range0,
        },
        textEditText = '${1:Object} ${2:foo} = new ${1}(${3});\n${0}',
      },

      -- eclipse.jdt.ls `List.copyO` function call completion
      {
        label = 'copyOf(Collection<? extends E> coll) : List<E>',
        insertTextFormat = 2,
        insertText = 'copyOf',
        textEdit = {
          newText = 'copyOf(${1:coll})',
          range = range0,
        },
      },
    }
    local expected = {
      {
        abbr = 'copyOf(Collection<? extends E> coll) : List<E>',
        word = 'copyOf',
      },
      {
        abbr = 'insert',
        word = 'insert',
      },
      {
        abbr = 'new',
        word = 'new',
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
      info = '',
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
          filterText = 'no_match',
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
      info = '',
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

  it(
    'uses insertText as textEdit.newText if there are editRange defaults but no textEditText',
    function()
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
            insertText = 'the-insertText',
            label = 'hello',
            data = 'item-property-has-priority',
          },
        },
      }
      local result = complete('|', completion_list)
      eq(1, #result.items)
      local text = result.items[1].user_data.nvim.lsp.completion_item.textEdit.newText
      eq('the-insertText', text)
    end
  )
end)

describe('vim.lsp.completion: protocol', function()
  before_each(function()
    clear()
    exec_lua(create_server_definition)
    exec_lua([[
      _G.capture = {}
      vim.fn.complete = function(col, matches)
        _G.capture.col = col
        _G.capture.matches = matches
      end
    ]])
  end)

  after_each(clear)

  --- @param completion_result lsp.CompletionList
  --- @return integer
  local function create_server(completion_result)
    return exec_lua(
      [[
      local result = ...
      local server = _create_server({
        capabilities = {
          completionProvider = {
            triggerCharacters = { '.' }
          }
        },
        handlers = {
          ['textDocument/completion'] = function(_, _, callback)
            callback(nil, result)
          end
        }
      })

      bufnr = vim.api.nvim_get_current_buf()
      vim.api.nvim_win_set_buf(0, bufnr)
      return vim.lsp.start({ name = 'dummy', cmd = server.cmd, on_attach = function(client, bufnr)
        vim.lsp.completion.enable(true, client.id, bufnr)
      end})
    ]],
      completion_result
    )
  end

  local function assert_matches(fn)
    retry(nil, nil, function()
      fn(exec_lua('return _G.capture.matches'))
    end)
  end

  --- @param pos [integer, integer]
  local function trigger_at_pos(pos)
    exec_lua(
      [[
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(win, ...)
      vim.lsp.completion.trigger()
    ]],
      pos
    )

    retry(nil, nil, function()
      neq(nil, exec_lua('return _G.capture.col'))
    end)
  end

  it('fetches completions and shows them using complete on trigger', function()
    create_server({
      isIncomplete = false,
      items = {
        {
          label = 'hello',
        },
      },
    })

    feed('ih')
    trigger_at_pos({ 1, 1 })

    assert_matches(function(matches)
      eq({
        {
          abbr = 'hello',
          dup = 1,
          empty = 1,
          icase = 1,
          info = '',
          kind = 'Unknown',
          menu = '',
          user_data = {
            nvim = {
              lsp = {
                client_id = 1,
                completion_item = {
                  label = 'hello',
                },
              },
            },
          },
          word = 'hello',
        },
      }, matches)
    end)
  end)

  it('merges results from multiple clients', function()
    create_server({
      isIncomplete = false,
      items = {
        {
          label = 'hello',
        },
      },
    })
    create_server({
      isIncomplete = false,
      items = {
        {
          label = 'hallo',
        },
      },
    })

    feed('ih')
    trigger_at_pos({ 1, 1 })

    assert_matches(function(matches)
      eq(2, #matches)
      eq('hello', matches[1].word)
      eq('hallo', matches[2].word)
    end)
  end)

  it('executes commands', function()
    local completion_list = {
      isIncomplete = false,
      items = {
        {
          label = 'hello',
          command = {
            arguments = { '1', '0' },
            command = 'dummy',
            title = '',
          },
        },
      },
    }
    local client_id = create_server(completion_list)

    exec_lua(
      [[
      _G.called = false
      local client = vim.lsp.get_client_by_id(...)
      client.commands.dummy = function ()
        _G.called = true
      end
    ]],
      client_id
    )

    feed('ih')
    trigger_at_pos({ 1, 1 })

    exec_lua(
      [[
      local client_id, item = ...
      vim.v.completed_item = {
        user_data = {
          nvim = {
            lsp = {
              client_id = client_id,
              completion_item = item
            }
          }
        }
      }
    ]],
      client_id,
      completion_list.items[1]
    )

    feed('<C-x><C-o><C-y>')

    assert_matches(function(matches)
      eq(1, #matches)
      eq('hello', matches[1].word)
      eq(true, exec_lua('return _G.called'))
    end)
  end)
end)
