-- luacheck: globals vim

local get_callback_function = require('runtime.lua.lsp.callbacks').get_callback_function
local ClientObject = require ('runtime.lua.lsp.client')

local log = require('runtime.lua.log')
local lsp_util = require('runtime.lua.lsp.util')

local plugin = {
  client = {},
  helpers = {},
}


-- Helpers
local client_map = {}

plugin.helpers.get_command = function(cmd, filetype)
  if cmd ~= nil then
    return cmd
  end

  filetype = lsp_util.get_filetype(filetype)
  return plugin.client.get_configuration(filetype).command
end

plugin.helpers.get_arguments = function(args, filetype)
  filetype = lsp_util.get_filetype(filetype)

  if args ~= nil then
    return args
  end

  return plugin.client.get_configuration(filetype).arguments
end

plugin.client.get_callback = function(name, cb)
  -- If we actually have a callback, then pass it
  if cb then
    return cb
  end

  return get_callback_function(name)
end

plugin.client.add = function(ftype, configuration)
  vim.api.nvim_call_function('lsp#client#add', {ftype, configuration})
end

plugin.client.get_configuration = function(ftype)
  return vim.api.nvim_call_function('lsp#client#get_configuration', {ftype})
end

plugin.client.start = function(cmd, args, filetype)
  filetype = lsp_util.get_filetype(filetype)
  cmd = plugin.helpers.get_command(cmd, filetype)
  args = plugin.helpers.get_arguments(args, filetype)

  local name = plugin.client.get_configuration(filetype).name

  -- TODO(tjdevries): Debug guard
  vim.api.nvim_set_var('__langserver_command', cmd)

  -- Start the client
  log.debug('[LSP.plugin] Starting client...')
  local client = ClientObject.new(name, filetype, cmd, args)
  if client == nil then
    log.error('client was nil with arguments: ', cmd, ' ', args)
    return nil
  end
  client:initialize()

  -- Store the client in our map
  client_map[filetype] = client

  return client
end

-- TODO(tjdevries): Asyncify this, it seems to not read if I just send it
--          Wait until we can use job control to worry about that
plugin.client.request = function(name, args, filetype, cb)
  local result = plugin.client.get(filetype):request(name, args)

  log.debug('getting callback')
  local final_cb = plugin.client.get_callback(name, cb)

  if final_cb then
    log.debug('calling callback')
    return final_cb(result)
  else
    return nil
  end
end

plugin.client.get = function(filetype)
  filetype = lsp_util.get_filetype(filetype)

  -- TODO: Throw error if no client started?
  return client_map[filetype]
end

-- Non-client commands
-- Determines if a request is supported or not
plugin.is_supported_request = function(request_name)
  return get_callback_function(request_name) ~= nil
end

return plugin
