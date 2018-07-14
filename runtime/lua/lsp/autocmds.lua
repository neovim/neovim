-- This file contains a table of all the functions that should be fired via autocmds.
-- The table is set up such that:
-- {
--   'request/name' : {'BufWritePre', {'User', 'LSPRequestName'}}
-- }
--
-- Also has a function to setup all the autocommands

-- local requests = require('lsp.request').requests
local log = require('lsp.log')
local util = require('neovim.util')


local default_autocmds = {
  ['textDocument/didOpen'] = {
    -- After initialization, make sure to tell the LSP that we opened the file
    {'User', 'LSP/initialize/post'},

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
    -- TODO(tjdevries): Do we need this one when we have the other options?
    'BufWritePost',

    'TextChanged',
    'InsertLeave',

    {'User', 'LSP/textDocument/completion/pre'},
  },
}

local accepted_autocomand_postfixes = {
  pre = true,
  post = true,
  response = true,
  notification = true,
}

local doautocmd = function(autocmd)
  if type(autocmd) ~= 'string' then
    return nil
  end

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

  doautocmd('User LSP/' .. method_name .. '/' .. stage)
end

--- Export the autocmds from the table
-- @param autocmd_table (table) - Optional table to give the list of autocmds to generate.
--                                  If not passed in, then we will use the default tables.
local export_autocmds = function(autocmd_table, autocmd_pattern)
  if util.table.is_empty(autocmd_table) then
    autocmd_table = default_autocmds
  end

  local autocmd_string
  for request_name, autocmd_list in pairs(autocmd_table) do
    for _, autocmd_item in ipairs(autocmd_list) do
      autocmd_string = get_autocmd_event_name(autocmd_item, autocmd_pattern)

      if #autocmd_string > 0 then
        nvim_enable_autocmd(request_name, autocmd_string)
      end
    end
  end
end


--- Get the event string
-- @param autocmd_item (string)     -
-- @param autocmd_pattern (string)  - (Optional) See |autocmd-patterns|. If not specified, '*'
local get_autocmd_event_name = function(autocmd_item, autocmd_pattern)
  if autocmd_pattern == nil or autocmd_pattern == '' then
    autocmd_pattern = '*'
  end

  local autocmd_string
  if type(autocmd_item) == 'string' then
    autocmd_string = autocmd_item .. autocmd_pattern
  elseif type(autocmd_item == 'table') then
    autocmd_string = table.concat(autocmd_item, ' ')
  else
    -- TODO: Error out here or something
    autocmd_string = ''
  end

  return autocmd_string
end

--- Register an autocmd with neovim
-- @param request_name (string) - Name of the request to register
-- @param autocmd_event (string) - Native or User even that will fire this event
local nvim_enable_autocmd = function(request_name, autocmd_event)
  local command = string.format(
    [[autocmd %s nested lua require('lsp.plugin').client.request('%s')]],
    autocmd_event,
    request_name
  )

  vim.api.nvim_command(command)
end


-- Allow users to configure what autocmds are associated with messages
local reset_method = function()
  -- TODO(tjdevries)
end

local set_method = function()
  -- TODO(tjdevries)
end

return {
  default_autocmds = default_autocmds,
  export_autocmds = export_autocmds,
  lsp_doautocmd = lsp_doautocmd,
  reset_method = reset_method,
  set_method = set_method,
}
