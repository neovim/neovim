-- luacheck: globals vim

local ClientObject = require ('runtime.lua.lsp.client')

local log = require('neovim.log')
local lsp_util = require('runtime.lua.lsp.util')

local client_map = {}

local plugin = {
  client = {},
  helpers = {},
}

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
plugin.client.get = function(filetype)
  filetype = lsp_util.get_filetype(filetype)

  -- TODO: Throw error if no client started?
  return client_map[filetype]
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
plugin.client.request = function(name, args, cb, filetype)
  return plugin.client.get(filetype):request(name, args, cb)
end
plugin.client.request_async = function(name, args, cb, filetype)
  plugin.client.get(filetype):request_async(name, args, cb)
end
plugin.client.wait_request = function(request_id, filetype)
  return plugin.client.get(filetype)._results[request_id]
end
plugin.client.get_callback = function(request_name, cb)
  if cb then
    return cb
  end

  return require('lsp.callbacks').get_callback_function(request_name)
end
-- Non-client commands
-- Determines if a request is supported or not
plugin.is_supported_request = function(request_name)
  return plugin.client.get_callback(request_name) ~= nil
end

return plugin
