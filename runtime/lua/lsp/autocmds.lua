-- This file contains a table of all the functions that should be fired via autocmds.
-- The table is set up such that:
-- {
--   'request/name' : {'BufWritePre', {'User', 'LSPRequestName'}}
-- }
--
-- Also has a function to setup all the autocommands

-- local requests = require('lsp.request').requests
local log = require('neovim.log')
local util = require('neovim.util')


local autocmd_table = {
  ['textDocument/didOpen'] = {
    -- After initialization, make sure to tell the LSP that we opened the file
    {'User', 'initialize/post'},

    'BufReadPost',
    -- 'BufEnter',
  },

  ['textDocument/willSave'] = {
    'BufWritePre',
  },

  ['textDocument/didSave'] = {
    'BufWritePost',
  },

  -- TODO(tjdevries): Not too familiar with close autocommands
  ['textDocument/didClose'] = {
    'BufDelete',
    'BufWipeout',
  },

  ['textDocument/didChange'] = {
    'BufWritePost',
    'TextChanged',
    'InsertLeave',
  },
}

local accepted_autocomand_postfixes = {
  pre = true,
  post = true,
  response = true,
}

local doautocmd = function(autocmd)
  if type(autocmd) ~= 'string' then
    return nil
  end

  -- TODO: Was having problem with errors here... remove the silent for awhile to see why
  log.debug('Sending autocmd: ', autocmd)
  return vim.api.nvim_command('silent doautocmd ' .. autocmd)
end

local lsp_doautocmd = function(method, stage)
  if not accepted_autocomand_postfixes[stage] then
    return nil
  end

  local method_name
  if type(method) == 'string' then
    method_name = method
  elseif type(method) == 'table' then
    method_name = table.concat(method, '/')
  else
    log.info('Unknown method type: ' .. util.tostring(method))
    method_name = 'UNKNOWN'
  end

  doautocmd('LanguageServerProtocol User ' .. method_name .. '/' .. stage)
end

local export_autocmds = function()
  local autocmd_string
  for request_name, autocmd_list in pairs(autocmd_table) do
    for _, autocmd_item in ipairs(autocmd_list) do
      if type(autocmd_item) == 'string' then
        autocmd_string = autocmd_item .. ' *'
      elseif type(autocmd_item == 'table') then
        autocmd_string = table.concat(autocmd_item, ' ')
      else
        -- TODO: Error out here or something
        autocmd_string = ''
      end

      if #autocmd_string > 0 then
        vim.api.nvim_command(
          string.format(
            [[autocmd %s nested call luaeval("require('lsp.plugin').client.request_async('%s')")]],
            autocmd_string, request_name)
          )
      end
    end
  end
end

-- Allow users to configure what autocmds are associated with messages
local reset_method = function()
  -- TODO(tjdevries)
end

local set_method = function()
  -- TODO(tjdevries)
end

return {
  default_autocmd_table = autocmd_table,
  export_autocmds = export_autocmds,
  lsp_doautocmd = lsp_doautocmd,
  reset_method = reset_method,
  set_method = set_method,
}
