local autocmds = require('lsp.autocmds')
local callbacks = require('lsp.callbacks')
local log = require('lsp.log')

local config = {
  autocmds = {
    --- Enable an event for a particular request
    -- @param TODO(tjdevries)
    enable_event = function(request_name, autocmd_event, autocmd_pattern)
      autocmds.get_autocmd_event_name(autocmd_event, autocmd_pattern)
      autocmds.nvim_enable_autocmd(request_name, autocmd_event)
    end,

    disable_event = function(request_name)
      print(request_name)
      -- TODO(tjdevries)
    end,
  },

  callbacks = {
    --- Configure the error callback used to print or display errors
    -- @param new_error_cb  (required)  The function reference to call instead of the default error_callback
    set_error_callback = function(new_error_cb)
      callbacks.set_error_callback('nvim/error_callback', new_error_cb)
    end,

    set_default_callback = function(method, cb)
      callbacks.set_default_callback(method, cb)
    end,

    disable = function(method)
      callbacks.set_default_callback(method, nil)
    end,

    add_callback = function(method, cb)
      callbacks.add_callback(method, cb)
    end,

    add_filetype_callback = function(method, cb, filetype)
      callbacks.add_filetype_callback(method, cb, filetype)
    end,

    set_option = function(method, option, value)
      callbacks.set_option(method, option, value)
    end,
  },

  log = {
    set_file_level = function(level)
      log:set_file_level(level)
    end,

    set_outfile = function(file_name)
      log:set_outfile(vim.api.nvim_call_function('expand', {file_name}))
    end,

    set_console_level = function(level)
      log:set_console_level(level)
    end,
  },

  request = {
    timeout = 2
  },
}





return config
