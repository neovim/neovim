local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local t_lsp = require('test.functional.plugin.lsp.testutil')

local feed = n.feed
local eq = t.eq
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err
local stop = n.stop
local read_file = t.read_file
local write_file = t.write_file
local api = n.api
local is_os = t.is_os
local skip = t.skip
local command = n.command
local fn = n.fn
local tmpname = t.tmpname

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

-- TODO(justinmk): hangs on Windows https://github.com/neovim/neovim/pull/11837
if skip(is_os('win')) then
  return
end

describe('vim.lsp.util', function()
  before_each(function()
    clear_notrace()
  end)

  after_each(function()
    stop()
    exec_lua(function()
      vim.iter(vim.lsp.get_clients({ _uninitialized = true })):each(function(client)
        client:stop(true)
      end)
    end)
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  describe('lsp.util.rename', function()
    local pathsep = n.get_pathsep()

    it('can rename an existing file', function()
      local old = tmpname()
      write_file(old, 'Test content')
      local new = tmpname(false)
      local lines = exec_lua(function()
        local old_bufnr = vim.fn.bufadd(old)
        vim.fn.bufload(old_bufnr)
        vim.lsp.util.rename(old, new)
        -- the existing buffer is renamed in-place and its contents is kept
        local new_bufnr = vim.fn.bufadd(new)
        vim.fn.bufload(new_bufnr)
        return (old_bufnr == new_bufnr) and vim.api.nvim_buf_get_lines(new_bufnr, 0, -1, true)
      end)
      eq({ 'Test content' }, lines)
      local exists = vim.uv.fs_stat(old) ~= nil
      eq(false, exists)
      exists = vim.uv.fs_stat(new) ~= nil
      eq(true, exists)
      os.remove(new)
    end)

    it('can rename a directory', function()
      -- only reserve the name, file must not exist for the test scenario
      local old_dir = tmpname(false)
      local new_dir = tmpname(false)

      n.mkdir_p(old_dir)

      local file = 'file.txt'
      write_file(old_dir .. pathsep .. file, 'Test content')

      local lines = exec_lua(function()
        local old_bufnr = vim.fn.bufadd(old_dir .. pathsep .. file)
        vim.fn.bufload(old_bufnr)
        vim.lsp.util.rename(old_dir, new_dir)
        -- the existing buffer is renamed in-place and its contents is kept
        local new_bufnr = vim.fn.bufadd(new_dir .. pathsep .. file)
        vim.fn.bufload(new_bufnr)
        return (old_bufnr == new_bufnr) and vim.api.nvim_buf_get_lines(new_bufnr, 0, -1, true)
      end)
      eq({ 'Test content' }, lines)
      eq(false, vim.uv.fs_stat(old_dir) ~= nil)
      eq(true, vim.uv.fs_stat(new_dir) ~= nil)
      eq(true, vim.uv.fs_stat(new_dir .. pathsep .. file) ~= nil)

      os.remove(new_dir)
    end)

    it('does not touch buffers that do not match path prefix', function()
      local old = tmpname(false)
      local new = tmpname(false)
      n.mkdir_p(old)

      eq(
        true,
        exec_lua(function()
          local old_prefixed = 'explorer://' .. old
          local old_suffixed = old .. '.bak'
          local new_prefixed = 'explorer://' .. new
          local new_suffixed = new .. '.bak'

          local old_prefixed_buf = vim.fn.bufadd(old_prefixed)
          local old_suffixed_buf = vim.fn.bufadd(old_suffixed)
          local new_prefixed_buf = vim.fn.bufadd(new_prefixed)
          local new_suffixed_buf = vim.fn.bufadd(new_suffixed)

          vim.lsp.util.rename(old, new)

          return vim.api.nvim_buf_is_valid(old_prefixed_buf)
            and vim.api.nvim_buf_is_valid(old_suffixed_buf)
            and vim.api.nvim_buf_is_valid(new_prefixed_buf)
            and vim.api.nvim_buf_is_valid(new_suffixed_buf)
            and vim.api.nvim_buf_get_name(old_prefixed_buf) == old_prefixed
            and vim.api.nvim_buf_get_name(old_suffixed_buf) == old_suffixed
            and vim.api.nvim_buf_get_name(new_prefixed_buf) == new_prefixed
            and vim.api.nvim_buf_get_name(new_suffixed_buf) == new_suffixed
        end)
      )

      os.remove(new)
    end)

    it(
      'does not rename file if target exists and ignoreIfExists is set or overwrite is false',
      function()
        local old = tmpname()
        write_file(old, 'Old File')
        local new = tmpname()
        write_file(new, 'New file')

        exec_lua(function()
          vim.lsp.util.rename(old, new, { ignoreIfExists = true })
        end)

        eq(true, vim.uv.fs_stat(old) ~= nil)
        eq('New file', read_file(new))

        exec_lua(function()
          vim.lsp.util.rename(old, new, { overwrite = false })
        end)

        eq(true, vim.uv.fs_stat(old) ~= nil)
        eq('New file', read_file(new))
      end
    )

    it('maintains undo information for loaded buffer', function()
      local old = tmpname()
      write_file(old, 'line')
      local new = tmpname(false)

      local undo_kept = exec_lua(function()
        vim.opt.undofile = true
        vim.cmd.edit(old)
        vim.cmd.normal('dd')
        vim.cmd.write()
        local undotree = vim.fn.undotree()
        vim.lsp.util.rename(old, new)
        -- Renaming uses :saveas, which updates the "last write" information.
        -- Other than that, the undotree should remain the same.
        undotree.save_cur = undotree.save_cur + 1
        undotree.save_last = undotree.save_last + 1
        undotree.entries[1].save = undotree.entries[1].save + 1
        return vim.deep_equal(undotree, vim.fn.undotree())
      end)
      eq(false, vim.uv.fs_stat(old) ~= nil)
      eq(true, vim.uv.fs_stat(new) ~= nil)
      eq(true, undo_kept)
    end)

    it('maintains undo information for unloaded buffer', function()
      local old = tmpname()
      write_file(old, 'line')
      local new = tmpname(false)

      local undo_kept = exec_lua(function()
        vim.opt.undofile = true
        vim.cmd.split(old)
        vim.cmd.normal('dd')
        vim.cmd.write()
        local undotree = vim.fn.undotree()
        vim.cmd.bdelete()
        vim.lsp.util.rename(old, new)
        vim.cmd.edit(new)
        return vim.deep_equal(undotree, vim.fn.undotree())
      end)
      eq(false, vim.uv.fs_stat(old) ~= nil)
      eq(true, vim.uv.fs_stat(new) ~= nil)
      eq(true, undo_kept)
    end)

    it('does not rename file when it conflicts with a buffer without file', function()
      local old = tmpname()
      write_file(old, 'Old File')
      local new = tmpname(false)

      local lines = exec_lua(function()
        local old_buf = vim.fn.bufadd(old)
        vim.fn.bufload(old_buf)
        local conflict_buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(conflict_buf, new)
        vim.api.nvim_buf_set_lines(conflict_buf, 0, -1, true, { 'conflict' })
        vim.api.nvim_win_set_buf(0, conflict_buf)
        vim.lsp.util.rename(old, new)
        return vim.api.nvim_buf_get_lines(conflict_buf, 0, -1, true)
      end)
      eq({ 'conflict' }, lines)
      eq('Old File', read_file(old))
    end)

    it('does override target if overwrite is true', function()
      local old = tmpname()
      write_file(old, 'Old file')
      local new = tmpname()
      write_file(new, 'New file')
      exec_lua(function()
        vim.lsp.util.rename(old, new, { overwrite = true })
      end)

      eq(false, vim.uv.fs_stat(old) ~= nil)
      eq(true, vim.uv.fs_stat(new) ~= nil)
      eq('Old file', read_file(new))
    end)
  end)

  describe('lsp.util.locations_to_items', function()
    it('convert Location[] to items', function()
      local expected_template = {
        {
          filename = '/fake/uri',
          lnum = 1,
          end_lnum = 2,
          col = 3,
          end_col = 4,
          text = 'testing',
          user_data = {},
        },
      }
      local test_params = {
        {
          {
            uri = 'file:///fake/uri',
            range = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 1, character = 3 },
            },
          },
        },
        {
          {
            uri = 'file:///fake/uri',
            range = {
              start = { line = 0, character = 2 },
              -- LSP spec: if character > line length, default to the line length.
              ['end'] = { line = 1, character = 10000 },
            },
          },
        },
      }
      for _, params in ipairs(test_params) do
        local actual = exec_lua(function(params0)
          local bufnr = vim.uri_to_bufnr('file:///fake/uri')
          local lines = { 'testing', '123' }
          vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
          return vim.lsp.util.locations_to_items(params0, 'utf-16')
        end, params)
        local expected = vim.deepcopy(expected_template)
        expected[1].user_data = params[1]
        eq(expected, actual)
      end
    end)

    it('convert LocationLink[] to items', function()
      local expected = {
        {
          filename = '/fake/uri',
          lnum = 1,
          end_lnum = 1,
          col = 3,
          end_col = 4,
          text = 'testing',
          user_data = {
            targetUri = 'file:///fake/uri',
            targetRange = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            },
            targetSelectionRange = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            },
          },
        },
      }
      local actual = exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri')
        local lines = { 'testing', '123' }
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        local locations = {
          {
            targetUri = vim.uri_from_bufnr(bufnr),
            targetRange = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            },
            targetSelectionRange = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            },
          },
        }
        return vim.lsp.util.locations_to_items(locations, 'utf-16')
      end)
      eq(expected, actual)
    end)
  end)

  describe('lsp.util.symbols_to_items', function()
    describe('convert DocumentSymbol[] to items', function()
      it('documentSymbol has children', function()
        local expected = {
          {
            col = 1,
            end_col = 1,
            end_lnum = 2,
            filename = '',
            kind = 'File',
            lnum = 2,
            text = '[File] TestA',
          },
          {
            col = 1,
            end_col = 1,
            end_lnum = 4,
            filename = '',
            kind = 'Module',
            lnum = 4,
            text = '[Module] TestB',
          },
          {
            col = 1,
            end_col = 1,
            end_lnum = 6,
            filename = '',
            kind = 'Namespace',
            lnum = 6,
            text = '[Namespace] TestC',
          },
        }
        eq(
          expected,
          exec_lua(function()
            local doc_syms = {
              {
                deprecated = false,
                detail = 'A',
                kind = 1,
                name = 'TestA',
                range = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 0,
                    line = 2,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 4,
                    line = 1,
                  },
                },
                children = {
                  {
                    children = {},
                    deprecated = false,
                    detail = 'B',
                    kind = 2,
                    name = 'TestB',
                    range = {
                      start = {
                        character = 0,
                        line = 3,
                      },
                      ['end'] = {
                        character = 0,
                        line = 4,
                      },
                    },
                    selectionRange = {
                      start = {
                        character = 0,
                        line = 3,
                      },
                      ['end'] = {
                        character = 4,
                        line = 3,
                      },
                    },
                  },
                },
              },
              {
                deprecated = false,
                detail = 'C',
                kind = 3,
                name = 'TestC',
                range = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 0,
                    line = 6,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 4,
                    line = 5,
                  },
                },
              },
            }
            return vim.lsp.util.symbols_to_items(doc_syms, nil, 'utf-16')
          end)
        )
      end)

      it('documentSymbol has no children', function()
        local expected = {
          {
            col = 1,
            end_col = 1,
            end_lnum = 2,
            filename = '',
            kind = 'File',
            lnum = 2,
            text = '[File] TestA',
          },
          {
            col = 1,
            end_col = 1,
            end_lnum = 6,
            filename = '',
            kind = 'Namespace',
            lnum = 6,
            text = '[Namespace] TestC',
          },
        }
        eq(
          expected,
          exec_lua(function()
            local doc_syms = {
              {
                deprecated = false,
                detail = 'A',
                kind = 1,
                name = 'TestA',
                range = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 0,
                    line = 2,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 4,
                    line = 1,
                  },
                },
              },
              {
                deprecated = false,
                detail = 'C',
                kind = 3,
                name = 'TestC',
                range = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 0,
                    line = 6,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 4,
                    line = 5,
                  },
                },
              },
            }
            return vim.lsp.util.symbols_to_items(doc_syms, nil, 'utf-16')
          end)
        )
      end)

      it('handles deprecated items', function()
        local expected = {
          {
            col = 1,
            end_col = 1,
            end_lnum = 2,
            filename = '',
            kind = 'File',
            lnum = 2,
            text = '[File] TestA (deprecated)',
          },
          {
            col = 1,
            end_col = 1,
            end_lnum = 6,
            filename = '',
            kind = 'Namespace',
            lnum = 6,
            text = '[Namespace] TestC (deprecated)',
          },
        }
        eq(
          expected,
          exec_lua(function()
            local doc_syms = {
              {
                deprecated = true,
                detail = 'A',
                kind = 1,
                name = 'TestA',
                range = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 0,
                    line = 2,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 4,
                    line = 1,
                  },
                },
              },
              {
                detail = 'C',
                kind = 3,
                name = 'TestC',
                range = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 0,
                    line = 6,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 4,
                    line = 5,
                  },
                },
                tags = { 1 }, -- deprecated
              },
            }
            return vim.lsp.util.symbols_to_items(doc_syms, nil, 'utf-16')
          end)
        )
      end)
    end)

    it('convert SymbolInformation[] to items', function()
      local expected = {
        {
          col = 1,
          end_col = 1,
          end_lnum = 3,
          filename = '/test_a',
          kind = 'File',
          lnum = 2,
          text = '[File] TestA in TestAContainer',
        },
        {
          col = 1,
          end_col = 1,
          end_lnum = 5,
          filename = '/test_b',
          kind = 'Module',
          lnum = 4,
          text = '[Module] TestB in TestBContainer (deprecated)',
        },
      }
      eq(
        expected,
        exec_lua(function()
          local sym_info = {
            {
              deprecated = false,
              kind = 1,
              name = 'TestA',
              location = {
                range = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 0,
                    line = 2,
                  },
                },
                uri = 'file:///test_a',
              },
              containerName = 'TestAContainer',
            },
            {
              deprecated = true,
              kind = 2,
              name = 'TestB',
              location = {
                range = {
                  start = {
                    character = 0,
                    line = 3,
                  },
                  ['end'] = {
                    character = 0,
                    line = 4,
                  },
                },
                uri = 'file:///test_b',
              },
              containerName = 'TestBContainer',
            },
          }
          return vim.lsp.util.symbols_to_items(sym_info, nil, 'utf-16')
        end)
      )
    end)
  end)

  describe('lsp.util.jump_to_location', function()
    local target_bufnr --- @type integer

    before_each(function()
      target_bufnr = exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri')
        local lines = { '1st line of text', 'å å ɧ 汉语 ↥ 🤦 🦄' }
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      end)
    end)

    local location = function(start_line, start_char, end_line, end_char)
      return {
        uri = 'file:///fake/uri',
        range = {
          start = { line = start_line, character = start_char },
          ['end'] = { line = end_line, character = end_char },
        },
      }
    end

    local jump = function(msg)
      eq(true, exec_lua('return vim.lsp.util.jump_to_location(...)', msg, 'utf-16'))
      eq(target_bufnr, fn.bufnr('%'))
      return {
        line = fn.line('.'),
        col = fn.col('.'),
      }
    end

    it('jumps to a Location', function()
      local pos = jump(location(0, 9, 0, 9))
      eq(1, pos.line)
      eq(10, pos.col)
    end)

    it('jumps to a LocationLink', function()
      local pos = jump({
        targetUri = 'file:///fake/uri',
        targetSelectionRange = {
          start = { line = 0, character = 4 },
          ['end'] = { line = 0, character = 4 },
        },
        targetRange = {
          start = { line = 1, character = 5 },
          ['end'] = { line = 1, character = 5 },
        },
      })
      eq(1, pos.line)
      eq(5, pos.col)
    end)

    it('jumps to the correct multibyte column', function()
      local pos = jump(location(1, 2, 1, 2))
      eq(2, pos.line)
      eq(4, pos.col)
      eq('å', fn.expand('<cword>'))
    end)

    it('adds current position to jumplist before jumping', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local mark = api.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 1, 0 }, mark)

      api.nvim_win_set_cursor(0, { 2, 3 })
      jump(location(0, 9, 0, 9))

      mark = api.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 2, 3 }, mark)
    end)
  end)

  describe('lsp.util.show_document', function()
    local target_bufnr --- @type integer
    local target_bufnr2 --- @type integer

    before_each(function()
      target_bufnr = exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri')
        local lines = { '1st line of text', 'å å ɧ 汉语 ↥ 🤦 🦄' }
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      end)

      target_bufnr2 = exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri2')
        local lines = { '1st line of text', 'å å ɧ 汉语 ↥ 🤦 🦄' }
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      end)
    end)

    local location = function(start_line, start_char, end_line, end_char, second_uri)
      return {
        uri = second_uri and 'file:///fake/uri2' or 'file:///fake/uri',
        range = {
          start = { line = start_line, character = start_char },
          ['end'] = { line = end_line, character = end_char },
        },
      }
    end

    local show_document = function(msg, focus, reuse_win)
      eq(
        true,
        exec_lua(
          'return vim.lsp.util.show_document(...)',
          msg,
          'utf-16',
          { reuse_win = reuse_win, focus = focus }
        )
      )
      if focus == true or focus == nil then
        eq(target_bufnr, fn.bufnr('%'))
      end
      return {
        line = fn.line('.'),
        col = fn.col('.'),
      }
    end

    it('jumps to a Location if focus is true', function()
      local pos = show_document(location(0, 9, 0, 9), true, true)
      eq(1, pos.line)
      eq(10, pos.col)

      -- expectation: Cursor is placed past EOL (append position) in insert mode
      n.feed('I')
      pos = show_document(location(0, 16, 0, 16), true, true)
      eq(1, pos.line)
      eq(17, pos.col)
      eq('i', api.nvim_get_mode().mode)
    end)

    it('jumps to a Location if focus is true via handler', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server()
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        local result = {
          uri = 'file:///fake/uri',
          selection = {
            start = { line = 0, character = 9 },
            ['end'] = { line = 0, character = 9 },
          },
          takeFocus = true,
        }
        local ctx = {
          client_id = client_id,
          method = 'window/showDocument',
        }
        vim.lsp.handlers['window/showDocument'](nil, result, ctx)
        vim.lsp.get_client_by_id(client_id):stop()
        return {
          cursor = vim.api.nvim_win_get_cursor(0),
        }
      end)
      eq(1, result.cursor[1])
      eq(9, result.cursor[2])
    end)

    it('jumps to a Location if focus not set', function()
      local pos = show_document(location(0, 9, 0, 9), nil, true)
      eq(1, pos.line)
      eq(10, pos.col)
    end)

    it('does not add current position to jumplist if not focus', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local mark = api.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 1, 0 }, mark)

      api.nvim_win_set_cursor(0, { 2, 3 })
      show_document(location(0, 9, 0, 9), false, true)
      show_document(location(0, 9, 0, 9, true), false, true)

      mark = api.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 1, 0 }, mark)
    end)

    it('does not change cursor position if not focus and not reuse_win', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local cursor = api.nvim_win_get_cursor(0)

      show_document(location(0, 9, 0, 9), false, false)
      eq(cursor, api.nvim_win_get_cursor(0))
    end)

    it('does not change window if not focus', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local win = api.nvim_get_current_win()

      -- same document/bufnr
      show_document(location(0, 9, 0, 9), false, true)
      eq(win, api.nvim_get_current_win())

      -- different document/bufnr, new window/split
      show_document(location(0, 9, 0, 9, true), false, true)
      eq(2, #api.nvim_list_wins())
      eq(win, api.nvim_get_current_win())
    end)

    it("respects 'reuse_win' parameter", function()
      api.nvim_win_set_buf(0, target_bufnr)

      -- does not create a new window if the buffer is already open
      show_document(location(0, 9, 0, 9), false, true)
      eq(1, #api.nvim_list_wins())

      -- creates a new window even if the buffer is already open
      show_document(location(0, 9, 0, 9), false, false)
      eq(2, #api.nvim_list_wins())
    end)

    it('correctly sets the cursor of the split if range is given without focus', function()
      api.nvim_win_set_buf(0, target_bufnr)

      show_document(location(0, 9, 0, 9, true), false, true)

      local wins = api.nvim_list_wins()
      eq(2, #wins)
      table.sort(wins)

      eq({ 1, 0 }, api.nvim_win_get_cursor(wins[1]))
      eq({ 1, 9 }, api.nvim_win_get_cursor(wins[2]))
    end)

    it('does not change cursor of the split if not range and not focus', function()
      api.nvim_win_set_buf(0, target_bufnr)
      api.nvim_win_set_cursor(0, { 2, 3 })

      exec_lua(function()
        vim.cmd.new()
      end)
      api.nvim_win_set_buf(0, target_bufnr2)
      api.nvim_win_set_cursor(0, { 2, 3 })

      show_document({ uri = 'file:///fake/uri2' }, false, true)

      local wins = api.nvim_list_wins()
      eq(2, #wins)
      eq({ 2, 3 }, api.nvim_win_get_cursor(wins[1]))
      eq({ 2, 3 }, api.nvim_win_get_cursor(wins[2]))
    end)

    it('respects existing buffers', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local win = api.nvim_get_current_win()

      exec_lua(function()
        vim.cmd.new()
      end)
      api.nvim_win_set_buf(0, target_bufnr2)
      api.nvim_win_set_cursor(0, { 2, 3 })
      local split = api.nvim_get_current_win()

      -- reuse win for open document/bufnr if called from split
      show_document(location(0, 9, 0, 9, true), false, true)
      eq({ 1, 9 }, api.nvim_win_get_cursor(split))
      eq(2, #api.nvim_list_wins())

      api.nvim_set_current_win(win)

      -- reuse win for open document/bufnr if called outside the split
      show_document(location(0, 9, 0, 9, true), false, true)
      eq({ 1, 9 }, api.nvim_win_get_cursor(split))
      eq(2, #api.nvim_list_wins())
    end)
  end)

  describe('lsp.util._make_floating_popup_size', function()
    before_each(function()
      exec_lua(function()
        _G.contents = { 'text tαxt txtα tex', 'text tααt tααt text', 'text tαxt tαxt' }
      end)
    end)

    it('calculates size correctly', function()
      eq(
        { 19, 3 },
        exec_lua(function()
          return { vim.lsp.util._make_floating_popup_size(_G.contents) }
        end)
      )
    end)

    it('calculates size correctly with wrapping', function()
      eq(
        { 15, 5 },
        exec_lua(function()
          return {
            vim.lsp.util._make_floating_popup_size(_G.contents, { width = 15, wrap_at = 14 }),
          }
        end)
      )
    end)

    it('handles NUL bytes in text', function()
      exec_lua(function()
        _G.contents = {
          '\000\001\002\003\004\005\006\007\008\009',
          '\010\011\012\013\014\015\016\017\018\019',
          '\020\021\022\023\024\025\026\027\028\029',
        }
      end)
      command('set list listchars=')
      eq(
        { 20, 3 },
        exec_lua(function()
          return { vim.lsp.util._make_floating_popup_size(_G.contents) }
        end)
      )
      command('set display+=uhex')
      eq(
        { 40, 3 },
        exec_lua(function()
          return { vim.lsp.util._make_floating_popup_size(_G.contents) }
        end)
      )
    end)
    it('handles empty line', function()
      exec_lua(function()
        _G.contents = {
          '',
        }
      end)
      eq(
        { 20, 1 },
        exec_lua(function()
          return { vim.lsp.util._make_floating_popup_size(_G.contents, { width = 20 }) }
        end)
      )
    end)

    it('considers string title when computing width', function()
      eq(
        { 17, 2 },
        exec_lua(function()
          return {
            vim.lsp.util._make_floating_popup_size(
              { 'foo', 'bar' },
              { title = 'A very long title' }
            ),
          }
        end)
      )
    end)

    it('considers [string,string][] title when computing width', function()
      eq(
        { 17, 2 },
        exec_lua(function()
          return {
            vim.lsp.util._make_floating_popup_size(
              { 'foo', 'bar' },
              { title = { { 'A very ', 'Normal' }, { 'long title', 'Normal' } } }
            ),
          }
        end)
      )
    end)
  end)

  describe('lsp.util.trim.trim_empty_lines', function()
    it('properly trims empty lines', function()
      eq(
        { { 'foo', 'bar' } },
        exec_lua(function()
          --- @diagnostic disable-next-line:deprecated
          return vim.lsp.util.trim_empty_lines({ { 'foo', 'bar' }, nil })
        end)
      )
    end)
  end)

  describe('lsp.util.convert_signature_help_to_markdown_lines', function()
    it('can handle negative activeSignature', function()
      local result = exec_lua(function()
        local signature_help = {
          activeParameter = 0,
          activeSignature = -1,
          signatures = {
            {
              documentation = 'some doc',
              label = 'TestEntity.TestEntity()',
              parameters = {},
            },
          },
        }
        return vim.lsp.util.convert_signature_help_to_markdown_lines(signature_help, 'cs', { ',' })
      end)
      local expected = { '```cs', 'TestEntity.TestEntity()', '```', '---', 'some doc' }
      eq(expected, result)
    end)

    it('highlights active parameters in multiline signature labels', function()
      local _, hl = exec_lua(function()
        local signature_help = {
          activeSignature = 0,
          signatures = {
            {
              activeParameter = 1,
              label = 'fn bar(\n    _: void,\n    _: void,\n) void',
              parameters = {
                { label = '_: void' },
                { label = '_: void' },
              },
            },
          },
        }
        return vim.lsp.util.convert_signature_help_to_markdown_lines(signature_help, 'zig', { '(' })
      end)
      -- Note that although the highlight positions below are 0-indexed, the 2nd parameter
      -- corresponds to the 3rd line because the first line is the ``` from the
      -- Markdown block.
      local expected = { 3, 4, 3, 11 }
      eq(expected, hl)
    end)
  end)

  describe('lsp.util.get_effective_tabstop', function()
    local function test_tabstop(tabsize, shiftwidth)
      exec_lua(string.format(
        [[
          vim.bo.shiftwidth = %d
          vim.bo.tabstop = 2
        ]],
        shiftwidth
      ))
      eq(
        tabsize,
        exec_lua(function()
          return vim.lsp.util.get_effective_tabstop()
        end)
      )
    end

    it('with shiftwidth = 1', function()
      test_tabstop(1, 1)
    end)

    it('with shiftwidth = 0', function()
      test_tabstop(2, 0)
    end)
  end)

  describe('markdown and floating helpers', function()
    before_each(n.clear)

    describe('stylize_markdown', function()
      local stylize_markdown = function(content, opts)
        return exec_lua(function()
          local bufnr = vim.uri_to_bufnr('file:///fake/uri')
          vim.fn.bufload(bufnr)
          return vim.lsp.util.stylize_markdown(bufnr, content, opts)
        end)
      end

      it('code fences', function()
        local lines = {
          '```lua',
          "local hello = 'world'",
          '```',
        }
        local expected = {
          "local hello = 'world'",
        }
        local opts = {}
        eq(expected, stylize_markdown(lines, opts))
      end)

      it('code fences with whitespace surrounded info string', function()
        local lines = {
          '```   lua   ',
          "local hello = 'world'",
          '```',
        }
        local expected = {
          "local hello = 'world'",
        }
        local opts = {}
        eq(expected, stylize_markdown(lines, opts))
      end)

      it('adds separator after code block', function()
        local lines = {
          '```lua',
          "local hello = 'world'",
          '```',
          '',
          'something',
        }
        local expected = {
          "local hello = 'world'",
          '─────────────────────',
          'something',
        }
        local opts = { separator = true }
        eq(expected, stylize_markdown(lines, opts))
      end)

      it('replaces supported HTML entities', function()
        local lines = {
          '1 &lt; 2',
          '3 &gt; 2',
          '&quot;quoted&quot;',
          '&apos;apos&apos;',
          '&ensp; &emsp;',
          '&amp;',
        }
        local expected = {
          '1 < 2',
          '3 > 2',
          '"quoted"',
          "'apos'",
          '   ',
          '&',
        }
        local opts = {}
        eq(expected, stylize_markdown(lines, opts))
      end)
    end)

    it('convert_input_to_markdown_lines', function()
      local r = exec_lua(function()
        local hover_data = {
          kind = 'markdown',
          value = '```lua\nfunction vim.api.nvim_buf_attach(buffer: integer, send_buffer: boolean, opts: vim.api.keyset.buf_attach)\n  -> boolean\n```\n\n---\n\n Activates buffer-update events. Example:\n\n\n\n ```lua\n events = {}\n vim.api.nvim_buf_attach(0, false, {\n   on_lines = function(...)\n     table.insert(events, {...})\n   end,\n })\n ```\n\n\n @see `nvim_buf_detach()`\n @see `api-buffer-updates-lua`\n@*param* `buffer` — Buffer handle, or 0 for current buffer\n\n\n\n@*param* `send_buffer` — True if whole buffer.\n Else the first notification will be `nvim_buf_changedtick_event`.\n\n\n@*param* `opts` — Optional parameters.\n\n - on_lines: Lua callback. Args:\n   - the string "lines"\n   - buffer handle\n   - b:changedtick\n@*return* — False if foo;\n\n otherwise True.\n\n@see foo\n@see bar\n\n',
        }
        return vim.lsp.util.convert_input_to_markdown_lines(hover_data)
      end)
      local expected = {
        '```lua',
        'function vim.api.nvim_buf_attach(buffer: integer, send_buffer: boolean, opts: vim.api.keyset.buf_attach)',
        '  -> boolean',
        '```',
        '',
        '---',
        '',
        ' Activates buffer-update events. Example:',
        '',
        '',
        '',
        ' ```lua',
        ' events = {}',
        ' vim.api.nvim_buf_attach(0, false, {',
        '   on_lines = function(...)',
        '     table.insert(events, {...})',
        '   end,',
        ' })',
        ' ```',
        '',
        '',
        ' @see `nvim_buf_detach()`',
        ' @see `api-buffer-updates-lua`',
        '',
        -- For each @param/@return: #30695
        --  - Separate each by one empty line.
        --  - Remove all other blank lines.
        '@*param* `buffer` — Buffer handle, or 0 for current buffer',
        '',
        '@*param* `send_buffer` — True if whole buffer.',
        ' Else the first notification will be `nvim_buf_changedtick_event`.',
        '',
        '@*param* `opts` — Optional parameters.',
        ' - on_lines: Lua callback. Args:',
        '   - the string "lines"',
        '   - buffer handle',
        '   - b:changedtick',
        '',
        '@*return* — False if foo;',
        ' otherwise True.',
        '@see foo',
        '@see bar',
      }
      eq(expected, r)
    end)

    describe('_normalize_markdown', function()
      it('collapses consecutive blank lines', function()
        local result = exec_lua(function()
          local lines = {
            'foo',
            '',
            '',
            '',
            'bar',
            '',
            'baz',
          }
          return vim.lsp.util._normalize_markdown(lines)
        end)
        eq({ 'foo', '', 'bar', '', 'baz' }, result)
      end)

      it('removes preceding and trailing empty lines', function()
        local result = exec_lua(function()
          local lines = {
            '',
            'foo',
            'bar',
            '',
            '',
          }
          return vim.lsp.util._normalize_markdown(lines)
        end)
        eq({ 'foo', 'bar' }, result)
      end)
    end)

    describe('make_floating_popup_options', function()
      local function assert_anchor(anchor_bias, expected_anchor)
        local opts = exec_lua(function()
          return vim.lsp.util.make_floating_popup_options(30, 10, { anchor_bias = anchor_bias })
        end)

        eq(expected_anchor, string.sub(opts.anchor, 1, 1))
      end

      before_each(function()
        local _ = Screen.new(80, 80)
        feed('79i<CR><Esc>') -- fill screen with empty lines
      end)

      describe('when on the first line it places window below', function()
        before_each(function()
          feed('gg')
        end)

        it('for anchor_bias = "auto"', function()
          assert_anchor('auto', 'N')
        end)

        it('for anchor_bias = "above"', function()
          assert_anchor('above', 'N')
        end)

        it('for anchor_bias = "below"', function()
          assert_anchor('below', 'N')
        end)
      end)

      describe('when on the last line it places window above', function()
        before_each(function()
          feed('G')
        end)

        it('for anchor_bias = "auto"', function()
          assert_anchor('auto', 'S')
        end)

        it('for anchor_bias = "above"', function()
          assert_anchor('above', 'S')
        end)

        it('for anchor_bias = "below"', function()
          assert_anchor('below', 'S')
        end)
      end)

      describe('with 20 lines above, 59 lines below', function()
        before_each(function()
          feed('gg20j')
        end)

        it('places window below for anchor_bias = "auto"', function()
          assert_anchor('auto', 'N')
        end)

        it('places window above for anchor_bias = "above"', function()
          assert_anchor('above', 'S')
        end)

        it('places window below for anchor_bias = "below"', function()
          assert_anchor('below', 'N')
        end)
      end)

      describe('with 59 lines above, 20 lines below', function()
        before_each(function()
          feed('G20k')
        end)

        it('places window above for anchor_bias = "auto"', function()
          assert_anchor('auto', 'S')
        end)

        it('places window above for anchor_bias = "above"', function()
          assert_anchor('above', 'S')
        end)

        it('places window below for anchor_bias = "below"', function()
          assert_anchor('below', 'N')
        end)

        it('bordered window truncates dimensions correctly', function()
          local opts = exec_lua(function()
            return vim.lsp.util.make_floating_popup_options(100, 100, { border = 'single' })
          end)

          eq(56, opts.height)
        end)

        it('title with winborder option #35179', function()
          local opts = exec_lua(function()
            vim.o.winborder = 'single'
            return vim.lsp.util.make_floating_popup_options(100, 100, { title = 'Title' })
          end)
          eq('Title', opts.title)
        end)
      end)
    end)

    describe('open_floating_preview', function()
      before_each(function()
        Screen.new(10, 10)
        feed('9i<CR><Esc>G4k')
      end)
      local var_name = 'lsp_floating_preview'

      it('after fclose', function()
        exec_lua(function()
          vim.lsp.util.open_floating_preview({ 'test' }, '', { height = 5, width = 2 })
        end)
        eq(true, api.nvim_win_is_valid(api.nvim_buf_get_var(0, var_name)))
        command('fclose')
        -- b:lsp_floating_preview should be cleared.
        eq('Key not found: lsp_floating_preview', pcall_err(api.nvim_buf_get_var, 0, var_name))
      end)

      it('after CursorMoved', function()
        local result, winfixbuf = exec_lua(function()
          vim.lsp.util.open_floating_preview({ 'test' }, '', { height = 5, width = 2 })
          local winnr = vim.b[vim.api.nvim_get_current_buf()].lsp_floating_preview
          local result = vim.api.nvim_win_is_valid(winnr)
          local winfixbuf = vim.wo[winnr].winfixbuf
          vim.api.nvim_feedkeys(vim.keycode('G'), 'txn', false)
          return result, winfixbuf
        end)
        eq(true, result)
        -- 'winfixbuf' should be set. #39058
        eq(true, winfixbuf)
        -- b:lsp_floating_preview should be cleared.
        eq('Key not found: lsp_floating_preview', pcall_err(api.nvim_buf_get_var, 0, var_name))
      end)
    end)

    it('open_floating_preview zindex greater than current window', function()
      local screen = Screen.new()
      exec_lua(function()
        vim.api.nvim_open_win(0, true, {
          relative = 'editor',
          border = 'single',
          height = 11,
          width = 51,
          row = 2,
          col = 2,
        })
        vim.keymap.set('n', 'K', function()
          vim.lsp.util.open_floating_preview({ 'foo' }, '', { border = 'single' })
        end, {})
      end)
      feed('K')
      screen:expect([[
        ┌───────────────────────────────────────────────────┐|
        │{4:^                                                   }│|
        │┌───┐{11:                                              }│|
        ││{4:foo}│{11:                                              }│|
        │└───┘{11:                                              }│|
        │{11:~                                                  }│|*7
        └───────────────────────────────────────────────────┘|
                                                             |
      ]])
    end)

    it('open_floating_preview height reduced for concealed lines', function()
      local screen = Screen.new()
      screen:add_extra_attr_ids({
        [100] = {
          background = Screen.colors.LightMagenta,
          foreground = Screen.colors.Brown,
          bold = true,
        },
        [101] = { background = Screen.colors.LightMagenta, foreground = Screen.colors.Blue },
        [102] = { background = Screen.colors.LightMagenta, foreground = Screen.colors.DarkCyan },
      })
      exec_lua([[
      vim.g.syntax_on = false
      vim.lsp.util.open_floating_preview({ '```lua', 'local foo', '```' }, 'markdown', {
        border = 'single',
        focus = false,
      })
    ]])
      screen:expect([[
      ^                                                     |
      ┌─────────┐{1:                                          }|
      │{100:local}{101: }{102:foo}│{1:                                          }|
      └─────────┘{1:                                          }|
      {1:~                                                    }|*9
                                                           |
    ]])
      -- Entering window keeps lines concealed and doesn't end up below inner window size.
      feed('<C-w>wG')
      screen:expect([[
                                                           |
      ┌─────────┐{1:                                          }|
      │{101:^```}{4:      }│{1:                                          }|
      └─────────┘{1:                                          }|
      {1:~                                                    }|*9
                                                           |
    ]])
      -- Correct height when float inherits 'conceallevel' >= 2 #32639
      command('close | set conceallevel=2')
      feed('<Ignore>') -- Prevent CursorMoved closing the next float immediately
      exec_lua([[
      vim.lsp.util.open_floating_preview({ '```lua', 'local foo', '```' }, 'markdown', {
        border = 'single',
        focus = false,
      })
    ]])
      screen:expect([[
      ^                                                     |
      ┌─────────┐{1:                                          }|
      │{100:local}{101: }{102:foo}│{1:                                          }|
      └─────────┘{1:                                          }|
      {1:~                                                    }|*9
                                                           |
    ]])
      -- This tests the valid winline code path (why doesn't the above?).
      exec_lua([[
      vim.cmd.only()
      vim.lsp.util.open_floating_preview({ 'foo', '```lua', 'local bar', '```' }, 'markdown', {
        border = 'single',
        focus = false,
      })
    ]])
      feed('<C-W>wG')
      screen:expect([[
                                                           |
      ┌─────────┐{1:                                          }|
      │{100:local}{101: }{102:bar}│{1:                                          }|
      │{101:^```}{4:      }│{1:                                          }|
      └─────────┘{1:                                          }|
      {1:~                                                    }|*8
                                                           |
    ]])
    end)

    it('open_floating_preview height does not exceed max_height', function()
      local screen = Screen.new()
      exec_lua([[
        vim.lsp.util.open_floating_preview(vim.fn.range(1, 10), 'markdown', {
          border = 'single',
          width = 5,
          max_height = 5,
          focus = false,
        })
      ]])
      screen:expect([[
        ^                                                     |
        ┌─────┐{1:                                              }|
        │{4:1    }│{1:                                              }|
        │{4:2    }│{1:                                              }|
        │{4:3    }│{1:                                              }|
        │{4:4    }│{1:                                              }|
        │{4:5    }│{1:                                              }|
        └─────┘{1:                                              }|
        {1:~                                                    }|*5
                                                             |
      ]])
    end)
  end)
end)
