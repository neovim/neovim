--[=[

actions.lua

Define common actions that can be taken on different LSP structures.

Module structure is:

  actions.<lsp_structure_name>.<action_name>

  Where:
    lsp_structure_name:
      Name of the structure as defined in the LSP specification.

      For example: Location, LocationLink, Hover, etc.

      All structures are assumed to be (wherever possible) either a singular or list of those items.
        The LSP spec often has something return either `Location` or `Location[]`.
        All callbacks here should be able to handle either of them.


    action_name:
      Name of what the user can expect to happen when this function is called.


  Example:
    actions.Location.jump_first will jump to the singular Location passed or the first Location in a Location[].

  In general, actions should handle a singular or list of objects where it makes sense (as in the above).


All actions should return a function that returns a function of that has the structure of: >

  function(err, method, params, client_id, bufnr)
<

  which is the same interface as those called by the client after an asynchronous request.

All builtin actions are wrapped in a metatable that allows two conveniences:

  1. When calling the `action` directly, it will perform the default action.

    You can write the code directly as a call (through the use of `__call` metamethod): >

      Location.jump_first(_, method, result)
<

  2. Allows for storing a callback with different configuration by using the `with` key: >

      local my_highlight = Location.highlight.with { higroup = 'Substitute', timeout = 100 }

<


-- Don't make this a local variable if you want to use it in a mapping
-- it needs to be global to be accessed easily.
--
-- The convention is to prefix with `on` to differentiate from other Location objects
-- from other namespaces.
onLocation = require('vim.lsp.actions').Location

-- only `jump` to definition
vim.lsp.buf.definition { callbacks = onLocation.jump_first }

-- `jump` to definition, and then `highlight` the item
vim.lsp.buf.definition { callbacks = { onLocation.jump_first, onLocation.highlight } }

-- `jump to definition, and then perform a `highlight` action with `higroup` set to 'Substitute' and timeout set to 2s
vim.lsp.buf.definition {
  callbacks = {
    onLocation.jump_first, onLocation.highlight.with { higroup = 'Substitute', timeout = 2000 }
  }
}


To explain:
Actions should be composable
Actions should be chainable / consecutive

If an action returns false, stop the chain of actions.
  If it returns false, it can optionally return an error message.

--]=]

local api = vim.api

local log = require('vim.lsp.log')
local structures = require('vim.lsp.structures')
local util = require('vim.lsp.util')

local wrap_generator = util.wrap_generator

local actions = {}


local handle_success_and_message = function(method, success, message)
  if success == false then
    log.info(method, message)
    return false
  end
end


--- Location actions.
-- Supports both Location and LocationLink
--@ref |structures.Location|
actions.Location = {}

--- Jump to the first location. Accepts Location and Location[]
actions.Location.jump_first = function()
  return function(_, method, location, _, _)
    return handle_success_and_message(method, structures.Location.jump(location))
  end
end

--- Jump to the first Location. If more than one Location is returned, quickfix list is populated
actions.Location.jump_and_quickfix = function()
  return function(_, method, result)
    -- How can I not repeat myself here.
    if result == nil or vim.tbl_isempty(result) then
      log.info(method, 'No location found')
      return nil
    end

    structures.Location.jump(result)

    -- textDocument/definition can return Location or Location[]
    -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition
    if vim.tbl_islist(result) and #result > 1 then
      structures.Location.set_qflist(result, true)
    end
  end
end

--- Preview a location in a floating windows
--
--@param args: Config table: ~
--              lines_above: Number of lines to show above the location in the preview. Default 0
--              lines_below: Number of lines to show below the location in the preview. Default 0
actions.Location.preview = function(args)
  args = args or {}

  local lines_above = args.lines_above or 0
  local lines_below = args.lines_below or 0

  return function(_, method, location)
    local success = structures.Location.preview(location, lines_above, lines_below)

    if success == false then
      log.info(method, 'No location found')
      return false
    end
  end
end


--- Highlight a location
--
--@param args: Config table: ~
--              higroup: Name of the highlight group
--              timeout: Number of ms before highlight is cleared.
actions.Location.highlight = function(args)
  args = args or {}

  local higroup = args.higroup or "IncSearch"
  local timeout = args.timeout or 250

  return function(_, method, location)
    local success = structures.Location.highlight(location, higroup, timeout)

    if success == false then
      log.info(method, 'No location found')
      return false
    end
  end
end

--- Set the quickfix list for Location or Location[]
--
--@param args: Config table: ~
--              open_list: Whether to open list or not. Default true
actions.Location.set_qflist = function(args)
  args = args or {}

  local open_list = true
  if args.open_list ~= nil then
    open_list = args.open_list
  end

  return function(_, method, location)
    local success = structures.Location.set_qflist(location, open_list)

    if success == false then
      log.info(method, 'No locations found')
      return
    end
  end
end

--- Set the loc list for Location or Location[]
--
--@param args: Config table: ~
--              open_list: Whether to open list or not. Default true
actions.Location.set_loclist = function(args)
  args = args or {}

  local open_list = true
  if args.open_list ~= nil then
    open_list = args.open_list
  end

  return function(_, method, location)
    local success = structures.Location.set_loclist(location, open_list)

    if success == false then
      log.info(method, 'No locations found')
      return false
    end
  end
end

-- All actions for Location should work for LocationLink
actions.LocationLink = vim.deepcopy(actions.Location)


--- Diagnostic Actions
--
--@ref |structures.Diagnostic}
actions.Diagnostic = {}

--- Handle the caching and display of diagnostics from the `textDocument/publishDiagnostics` notification.
--
--@param args: Config table: ~
--      should_underline (bool): Should underlines be displayed
--      update_in_insert (bool): Should diagnostic displays be updated while in insert mode
actions.Diagnostic.handle_publish_diagnostics = function(args)

  -- TODO(tjdevries): This should be tied somehow with the function that exists in structures.Diagnostic...
  args = vim.tbl_extend("force", {
    should_underline = true,
    update_in_insert = true,
  }, args or {})

  return function(_, method, notification, client_id)
    local uri = notification.uri
    local bufnr = vim.uri_to_bufnr(uri)
    if not bufnr then
      return
    end

    -- Unloaded buffers should not handle diagnostics.
    --    When the buffer is loaded, we'll call on_attach, which sends textDocument/didOpen.
    --    This should trigger another publish of the diagnostics.
    --
    -- In particular, this stops a ton of spam when first starting a server for current
    -- unloaded buffers.
    if not api.nvim_buf_is_loaded(bufnr) then
      return
    end

    local diagnostics = notification.diagnostics

    -- util.buf_diagnostics_save_positions(bufnr, notification.diagnostics)
    structures.Diagnostic.save_buf_diagnostics(diagnostics, bufnr, client_id)

    if not args.update_in_insert then
      local mode = vim.api.nvim_get_mode()

      if string.sub(mode.mode, 1, 1) == 'i' then
        structures.Diagnostic.buf_schedule_display_on_insert_leave(bufnr, client_id, args)
        return
      end
    end

    structures.Diagnostic.display(diagnostics, bufnr, client_id, args)
  end
end

actions.Symbol = {}

actions.Symbol.set_qflist = function(args)
  args = args or {}

  local open_list = true
  if args.open_list ~= nil then
    open_list = args.open_list
  end

  return function(_, method, result, _, bufnr)
    if not result or vim.tbl_isempty(result) then
      log.info(method, 'No symbols found')
      return
    end

    util.set_qflist(util.symbols_to_items(result, bufnr))

    if open_list then
      api.nvim_command("copen")
      api.nvim_command("wincmd p")
    end
  end
end

actions.WorkspaceEdit = {}
actions.WorkspaceEdit.apply = function()
  return function(_, method, workspace_edit)
    if not workspace_edit then
      log.info(method, 'No workspace edits provided')
      return
    end

    return structures.WorkspaceEdit.apply_workspace_edit(workspace_edit)
  end
end

actions.TextEdit = {}
actions.TextEdit.apply = function()
  return function(_, _, text_edits, _, bufnr)
    return structures.TextEdit.aplly_edits(text_edits, bufnr)
  end
end

actions.TextDocumentEdit = {}
actions.TextDocumentEdit.apply = function()
  return function(_, _, text_document_edit)
    return structures.TextDocumentEdit.apply_document_edit(text_document_edit)
  end
end

---------------------------------------------------
-- All built-in LSP structures should be of the right type.
---------------------------------------------------
for lsp_structure, action_set in pairs(actions) do
  for action_name, generator in pairs(action_set) do
    actions[lsp_structure][action_name] = wrap_generator(generator)
  end
end

-- local _validator = function(f)
--   return function(err, method, result, client_id, bufnr)
--     if err then
--       error(tostring(err))
--     end

--     if not result then
--       return
--     end

--     return f(err, method, result, client_id, bufnr)
--   end
-- end

return actions
