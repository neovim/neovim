-- luacheck: globals vim

-- This file contains a table of all the functions that should be fired via autocmds.
-- The table is set up such that:
-- {
--   'request/name' : {'BufWritePre', {'User', 'LSPRequestName'}}
-- }

local log = require('lsp.log')
local util = require('neovim.util')

local Enum = require('neovim.meta').Enum

local AutocmdEnum = Enum:new({
  AuGroup = 'LanguageServerProtocol',
  AuPrefix = 'LSP',
})


local AcceptedAutocmdPostfixes = Enum:new({
  pre = 'pre',
  post = 'post',
  response = 'response',
  notification = 'notification',
})

local initialized_filetypes = {}
local initialized_buffers = {}
local initialized_autocmds = {}


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
    {'User', 'LSP/textDocument/rename/pre'},
  },
}

--- Helper function to call `:doautocmd`
-- @param autocmd (string): The autocmd to be called
local doautocmd = function(autocmd)
  if type(autocmd) ~= 'string' then
    return nil
  end

  log.debug('Sending autocmd: ', autocmd)
  return vim.api.nvim_command('silent doautocmd ' .. autocmd)
end

--- Helper function to call `:doautocmd` for the various stages of execution of an LSP action
-- @param method (string): The name of the method that is being executed. For example, 'textDocument/hover'.
-- @param stage (string): The stage of execution. For example, 'pre'.
local lsp_doautocmd = function(method, stage)
  local stage_name = AcceptedAutocmdPostfixes[stage]

  local method_name
  if type(method) == 'string' then
    method_name = method
  elseif type(method) == 'table' then
    method_name = table.concat(method, '/')
  else
    log.info('Unknown method type: ', util.tostring(method))
    method_name = 'UNKNOWN'
  end

  doautocmd(string.format('User %s/%s/%s', AutocmdEnum.AuPrefix, method_name, stage_name))
end

--- Get the event string
-- @param autocmd_item (string|table)   - The autocmd event that will trigger this autocmd
-- @param autocmd_pattern (string)      - (Optional) See |autocmd-patterns|. If not specified, '<buffer>'
local get_autocmd_event_name = function(autocmd_item, autocmd_pattern)
  if autocmd_pattern == nil or autocmd_pattern == '' then
    autocmd_pattern = '<buffer>'
  end

  local autocmd_string
  if type(autocmd_item) == 'string' then
    autocmd_string = string.format('%s %s', autocmd_item, autocmd_pattern)
  elseif type(autocmd_item == 'table') then
    -- This is typically {'User', 'LSP/...'} -> 'User LSP/*'

    -- Since User autocmds these are not registered exclusively to the buffer, we should only register them once
    if autocmd_item[1] == 'User' then
      if initialized_autocmds[autocmd_item] then
        return ''
      end

      initialized_autocmds[autocmd_item] = true
    end

    autocmd_string = table.concat(autocmd_item, ' ')
  else
    log.debug('Unknown autocmd_item type: ', autocmd_item)
    return ''
  end

  return autocmd_string
end

--- Register an autocmd with neovim
-- @param request_name (string)         - Name of the request to register
-- @param autocmd_item (string|table)   - The autocmd event that will trigger this autocmd
-- @param autocmd_pattern (string)      - (Optional) See |autocmd-patterns|. If not specified, '*'
local nvim_enable_autocmd = function(request_name, autocmd_item, autocmd_pattern)
  local autocmd_event = get_autocmd_event_name(autocmd_item, autocmd_pattern)

  if #autocmd_event == 0 then
    return
  end

  local silent_level = 'silent!'
  local command = string.format(
    [[%s autocmd %s lua require('lsp.plugin').client.request_async('%s')]],
    silent_level,
    autocmd_event,
    request_name
  )

  vim.api.nvim_command(command)

  -- TODO: Determine if we need to be adding these to the "default autocmds"
  -- if util.table.is_empty(default_autocmds[request_name]) then
  --   return
  -- end
  -- if not util.table.is_empty(default_autocmds[request_name]) then
  --   table.insert(default_autocmds[request_name], autocmd_item)
  -- end
end

--- Export the autocmds from the table
-- @param autocmd_table (table)     - (Optional) Table to give the list of autocmds to generate.
--                                      If not passed in, then we will use the default tables.
-- @param autocmd_pattern (string)  - (Optional) See |autocmd-patterns|. If not specified, '<buffer>'
local export_autocmds = function(autocmd_table, autocmd_pattern)
  if util.table.is_empty(autocmd_table) then
    autocmd_table = default_autocmds
  end

  for request_name, autocmd_list in pairs(autocmd_table) do
    for _, autocmd_item in ipairs(autocmd_list) do
      print(request_name, autocmd_item, autocmd_pattern)
      nvim_enable_autocmd(request_name, autocmd_item, autocmd_pattern)
    end
  end
end

--- Initialize the autocmds required for LSP functionality for a particular buffer
-- @param autocmd_pattern (string)  - (Optional) See |autocmd-patterns|. If not specified, '<buffer>'
local initialize_buffer_autocmds = function(autocmd_pattern)
  local buf_number = vim.api.nvim_buf_get_number(0)
  if initialized_buffers[buf_number] then
    return
  end
  initialized_buffers[buf_number] = true

  -- Set up the default autocmds for a buffer
  export_autocmds(default_autocmds, autocmd_pattern)
end

--- Initialize the filetype autocmd that will set up autocmds on a per-buffer basis
-- @param filetype (string) - The filetype to initialize the autocmds for
local initialize_filetype_autocmds = function(filetype)
  if filetype == nil or filetype == '' then
    return
  end

  if initialized_filetypes[filetype] ~= nil then
    return
  end
  initialized_filetypes[filetype] = true

  vim.api.nvim_command(
    string.format(
      [[autocmd Filetype %s nested lua require('lsp.autocmds').initialize_buffer_autocmds()]],
      filetype
    )
  )

  -- If we're starting the server in a file where the filetype is already set,
  -- we should initialize the buffer autocmds manually
  if filetype == vim.api.nvim_buf_get_option(0, 'filetype') then
    initialize_buffer_autocmds()
  end
end


return {
  default_autocmds = default_autocmds,
  export_autocmds = export_autocmds,
  lsp_doautocmd = lsp_doautocmd,
  get_autocmd_event_name = get_autocmd_event_name,
  nvim_enable_autocmd = nvim_enable_autocmd,

  initialize_filetype_autocmds = initialize_filetype_autocmds,
  initialize_buffer_autocmds = initialize_buffer_autocmds,
}
