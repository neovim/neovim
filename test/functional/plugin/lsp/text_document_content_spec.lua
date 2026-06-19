local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')

local eq = t.eq
local retry = t.retry

local api = n.api
local command = n.command
local exec_lua = n.exec_lua

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.text_document_content', function()
  before_each(function()
    clear_notrace()
    exec_lua(create_server_definition)
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  local function wait_for_scheme(scheme)
    retry(nil, nil, function()
      eq(
        1,
        exec_lua(function(pattern)
          return #vim.api.nvim_get_autocmds({
            group = 'nvim.lsp.text_document_content',
            event = 'BufReadCmd',
            pattern = pattern,
          })
        end, scheme .. '://*')
      )
    end)
  end

  it('loads text document content from a static provider', function()
    exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          workspace = {
            textDocumentContent = {
              schemes = { 'td' },
            },
          },
        },
        handlers = {
          ['workspace/textDocumentContent'] = function(_, params, callback)
            callback(nil, { text = 'content for ' .. params.uri .. '\r\nnext\n' })
          end,
        },
      })

      vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)

    wait_for_scheme('td')
    command('edit td://document')
    eq(
      { 'content for td://document', 'next' },
      exec_lua(function()
        return vim.api.nvim_buf_get_lines(0, 0, -1, false)
      end)
    )

    eq(
      { buftype = 'nofile', modifiable = false, readonly = true, swapfile = false },
      exec_lua(function()
        return {
          buftype = vim.bo.buftype,
          modifiable = vim.bo.modifiable,
          readonly = vim.bo.readonly,
          swapfile = vim.bo.swapfile,
        }
      end)
    )
  end)

  it('loads text document content from a dynamic provider', function()
    exec_lua(function()
      _G.server = _G._create_server({
        handlers = {
          ['workspace/textDocumentContent'] = function(_, params, callback)
            callback(nil, { text = 'dynamic ' .. params.uri })
          end,
        },
      })

      local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd }))
      vim.lsp.handlers['client/registerCapability'](nil, {
        registrations = {
          {
            id = 'textDocumentContent',
            method = 'workspace/textDocumentContent',
            registerOptions = { schemes = { 'dyn' } },
          },
        },
      }, { client_id = client_id, method = 'client/registerCapability' })
    end)

    wait_for_scheme('dyn')
    command('edit dyn://document')
    eq(
      { 'dynamic dyn://document' },
      exec_lua(function()
        return vim.api.nvim_buf_get_lines(0, 0, -1, false)
      end)
    )
  end)

  it('removes scheme handling when dynamically unregistered', function()
    exec_lua(function()
      _G.server = _G._create_server({
        handlers = {
          ['workspace/textDocumentContent'] = function(_, _, callback)
            callback(nil, { text = 'unregistered' })
          end,
        },
      })

      local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd }))
      vim.lsp.handlers['client/registerCapability'](nil, {
        registrations = {
          {
            id = 'textDocumentContent',
            method = 'workspace/textDocumentContent',
            registerOptions = { schemes = { 'gone' } },
          },
        },
      }, { client_id = client_id, method = 'client/registerCapability' })
      vim.lsp.handlers['client/unregisterCapability'](nil, {
        unregisterations = {
          { id = 'textDocumentContent', method = 'workspace/textDocumentContent' },
        },
      }, { client_id = client_id, method = 'client/unregisterCapability' })
    end)

    eq(
      {},
      exec_lua(function()
        return vim.api.nvim_get_autocmds({
          group = 'nvim.lsp.text_document_content',
          event = 'BufReadCmd',
          pattern = 'gone://*',
        })
      end)
    )
  end)

  it('refreshes loaded buffers from the requesting client', function()
    local client_id = exec_lua(function()
      _G.content = 'initial'
      _G.server = _G._create_server({
        capabilities = {
          workspace = {
            textDocumentContent = {
              schemes = { 'refresh' },
            },
          },
        },
        handlers = {
          ['workspace/textDocumentContent'] = function(_, _, callback)
            callback(nil, { text = _G.content })
          end,
        },
      })

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)

    wait_for_scheme('refresh')
    command('edit refresh://document')
    eq(
      { 'initial' },
      exec_lua(function()
        return vim.api.nvim_buf_get_lines(0, 0, -1, false)
      end)
    )

    eq(
      true,
      exec_lua(function(client_id_)
        _G.content = 'updated'
        local result = vim.lsp.handlers['workspace/textDocumentContent/refresh'](nil, {
          uri = 'refresh://document',
        }, { client_id = client_id_, method = 'workspace/textDocumentContent/refresh' })
        return result == vim.NIL
      end, client_id)
    )
    eq(
      { 'updated' },
      exec_lua(function()
        return vim.api.nvim_buf_get_lines(0, 0, -1, false)
      end)
    )
  end)

  it('warns and uses the first client when multiple clients support a scheme', function()
    exec_lua(function()
      _G.notifications = {}
      vim.notify = function(msg, level)
        table.insert(_G.notifications, { msg = msg, level = level })
      end

      _G.server1 = _G._create_server({
        capabilities = { workspace = { textDocumentContent = { schemes = { 'multi' } } } },
        handlers = {
          ['workspace/textDocumentContent'] = function(_, _, callback)
            callback(nil, { text = 'first' })
          end,
        },
      })
      _G.server2 = _G._create_server({
        capabilities = { workspace = { textDocumentContent = { schemes = { 'multi' } } } },
        handlers = {
          ['workspace/textDocumentContent'] = function(_, _, callback)
            callback(nil, { text = 'second' })
          end,
        },
      })

      vim.lsp.start({ name = 'dummy1', cmd = _G.server1.cmd })
      vim.lsp.start({ name = 'dummy2', cmd = _G.server2.cmd })
    end)

    wait_for_scheme('multi')
    command('edit multi://document')
    eq(
      { 'first' },
      exec_lua(function()
        return vim.api.nvim_buf_get_lines(0, 0, -1, false)
      end)
    )

    eq(
      true,
      exec_lua(function()
        return vim.iter(_G.notifications):any(function(item)
          return item.level == vim.log.levels.WARN
            and item.msg:match('Multiple LSP clients support workspace/textDocumentContent')
              ~= nil
        end)
      end)
    )
  end)
end)
