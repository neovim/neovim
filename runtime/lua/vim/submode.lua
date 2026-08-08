--- @brief
---
--- WORK IN PROGRESS custom submodes! Early testing of existing features
--- is appreciated, but expect breaking changes without notice.
---
---Define custom interactive submodes:
---- Repeatedly ask user for key presses via |getcharstr()|.
---- Handle each key with a dedicated function handler that acts on a persistent state table.
---  It is allowed to change |vim-modes|, text, cursor, etc.
---- Stop when handle says so or after |CTRL-C|. Return a value that was set by the handler.
---
---Executes synchronously and can return value when submode is stopped.
---Submodes can be nested, but only one submode is active.

-- TODO:
-- - Allow "hooking" into submode:
--   - `SubmodeEnter`, `SubmodeLeave`, `SubmodeChanged` events.
--   - `opts.desc_keys` to allow submode "advertize" what it can do.
--     Helpful for "which-key" like plugins.
--   - `vim.submode.set(state)`?

local M = {}

--- @alias vim.submode.handler fun(state: vim.submode.State, key: string?): vim.submode.State?

--- @class vim.submode.keyset.start
--- @inlinedoc
--- @field desc? string Submode name. Default: 'Submode'.
---
--- Keys that are emulated before asking for the user input. Using values that
--- can be an output of |getcharstr()| should be preferred, but a key handler
--- should work with any string. Default: `{}`.
--- @field init_keys? string[]
---
--- @field getchar_opts? table Options for |getcharstr()|.

--- @class vim.submode.State
---
--- Any information to be reused during submode session. Handlers should not change
--- fields that tehy don't "own".
--- @field data table
--- @field errmsg? string First error message caught during submode execution.
--- @field handler vim.submode.handler Submode handler.
--- @field opts vim.submode.keyset.start Submode options.
--- @field output? any Value to return after submode is ended.
--- @field status "start"|"progress"|"end"|"cancel"

--- @type vim.submode.State?
local active_state

local function validate_state(x)
  vim.validate('state', x, 'table')
  vim.validate('state.data', x.data, 'table')
  vim.validate('state.errmsg', x.errmsg, 'string', true)
  vim.validate('state.handler', x.handler, 'function')
  vim.validate('state.opts', x.opts, 'table')
  vim.validate('state.opts.desc', x.opts.desc, 'string')
  vim.validate('state.opts.init_keys', x.opts.init_keys, vim.islist, 'list')
  for i = 1, #x.opts.init_keys do
    vim.validate('state.opts.init_keys[' .. i .. ']', x.opts.init_keys[i], 'string')
  end
  vim.validate('state.opts.getchar_opts', x.opts.getchar_opts, 'table')
  vim.validate('state.status', x.status, function(s)
    if s == 'start' or s == 'progress' or s == 'cancel' or s == 'end' then
      return true, nil
    end
    return false, 'one of "start", "progress", "cancel", "end"'
  end)
end

--- @param state? vim.submode.State
--- @param errmsg string
local function cache_error(state, errmsg)
  if state ~= nil then
    state.errmsg = state.errmsg or errmsg
    state.status = 'cancel'
  end
end

--- @param state vim.submode.State
--- @return boolean
local function is_end(state)
  return state.status == 'end' or state.status == 'cancel'
end

--- @param state vim.submode.State
--- @param key? string
local function apply_handler(state, key)
  active_state = state
  -- Use handler from `state` as it potentially allows adjusting it from the outside
  local ok_handler, res = pcall(state.handler, state, key)
  if not ok_handler then
    cache_error(state, res) ---@diagnostic disable-line: param-type-mismatch
  end

  local new_state = (ok_handler and res or nil) or state

  local ok_state, msg = pcall(validate_state, new_state)
  if not ok_state then
    --- @cast msg string
    cache_error(state, msg)
  end

  active_state = ok_state and new_state or state
  return active_state
end

local is_in_getcharstr = false

--- @param state vim.submode.State
local function getcharstr(state)
  is_in_getcharstr = true
  local ok, char = false, ''
  if vim.tbl_count(state.opts.getchar_opts) == 0 then
    ok, char = pcall(vim.fn.getcharstr, -1)
  else
    ok, char = pcall(vim.fn.getcharstr, -1, state.opts.getchar_opts)
  end
  is_in_getcharstr = false

  -- Cache possible error if it doesn't come from pressing <C-c>
  local is_ctrl_c = (not ok and char == 'Keyboard interrupt') or (ok and char == '\3')
  if not ok and not is_ctrl_c then
    cache_error(state, char)
  end

  return (ok and not is_ctrl_c) and char or nil
end

--- @class vim.submode.keyset.start.ret
--- @inlinedoc
--- @field output any Submode output as `state.output` value.
--- @field status "end"|"cancel" status Final submode status.

--- @param state vim.submode.State
--- @return vim.submode.keyset.start.ret
local function finish(state)
  -- "Teardown" step
  state = apply_handler(state)

  active_state = nil

  if state.errmsg ~= nil then
    error(state.errmsg, 0)
  end
  return { output = state.output, status = state.status == 'end' and 'end' or 'cancel' }
end

--- @param handler vim.submode.handler Submode handler. Expected to modify input state in place
--- or return a valid state table. Must set `state.status` to "end" or "cancel" for submode to stop.
--- Called once before the first key press, once per key press, once after the last key press.
--- @param opts vim.submode.keyset.start?
--- @return vim.submode.keyset.start.ret
function M.start(handler, opts)
  vim.validate('handler', handler, 'function')
  vim.validate('opts', opts, 'table', true)
  local default_opts = { desc = 'Submode', init_keys = {}, getchar_opts = {} }
  opts = vim.tbl_extend('force', default_opts, opts or {})

  --- @type vim.submode.State
  local state = { data = {}, handler = handler, opts = vim.deepcopy(opts), status = 'start' }
  validate_state(state)
  active_state = state

  state = apply_handler(state, nil)
  if is_end(state) then
    return finish(state)
  end
  state.status = 'progress'

  for _, key in ipairs(state.opts.init_keys) do
    state = apply_handler(state, key)
    if is_end(state) then
      return finish(state)
    end
  end

  -- while not is_end(state) do
  while not is_end(state) do
    active_state = state
    local key = getcharstr(state)
    if key == nil and not is_end(state) then
      state.status = 'cancel'
    end
    if is_end(state) then
      break
    end
    state = apply_handler(state, key)
  end

  return finish(state)
end

--- Refresh active submode
--- Calls submode's handler with `nil` key.
function M.refresh()
  if active_state == nil then
    return
  end
  active_state = apply_handler(active_state, nil)
  if not is_end(active_state) then
    return
  end

  -- Terminate properly if waiting for user key
  if is_in_getcharstr then
    vim.api.nvim_feedkeys('\3', 't', true)
  else
    finish(active_state)
  end
end

--- Gets active submode state, if any
--- @return vim.submode.State?
function M.get()
  -- TODO: This errors if `active.state` data contains userdata.
  -- Either write custom copy wrapper or adjust `vim.deepcopy`
  return vim.deepcopy(active_state) ---@diagnostic disable-line: param-type-mismatch
end

return M
