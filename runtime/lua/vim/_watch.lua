-- Create a file watcher, each watcher is identified by the buffer number of the file it is watching.

local uv = vim.loop

local M = {}
M.__index = M
local WatcherList = {}

-- Checks if a buffer should have a M attached to it.
local function buf_isvalid(bufnr)
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buflisted = vim.api.nvim_buf_get_option(bufnr, 'buflisted')
  local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

  return buflisted or buftype == '' or buftype == 'acwrite'
end

-- Checks for pending notifications and reacts if notifications are pending.
local function handle_pending_notifications()
  for _, watcher in pairs(WatcherList) do
    if watcher.pending_notifs and buf_isvalid(watcher.bufnr) then
      vim.api.nvim_command(string.format('checktime %d', watcher.bufnr))
      watcher.pending_notifs = false
    end
  end
end

-- Start the libuv fs_event handle
local function fs_event_start_buf(bufnr)
  local watcher = WatcherList[bufnr]
  if watcher.handle and not watcher.handle:is_closing() then
    watcher.handle:close()
  end
  watcher.handle = uv.new_fs_event()
  watcher.handle:start(
    watcher.fpath,
    {},
    vim.schedule_wrap(function(...)
      watcher:on_change(...)
  end))
end

--- Get the backend for a Watcher depending upon the value of filechangenotify option
--- For now only supports libuv fs_event.
--- Can add more watchers in the future.
local function get_watcher_backend()
  return fs_event_start_buf
end

--- Creates and initializes a new Watcher object with the given filename.
---
--@param bufnr: (required, number) The buffer number of the buffer that
--- is to be watched.
function M:new(bufnr)
  vim.validate({ bufnr = {bufnr, 'number', false} })
  -- get full path name for the file
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local fpath = vim.fn.fnamemodify(fname, ':p')
  local w = {
    bufnr = bufnr,
    fname = fname,
    fpath = fpath,
    handle = nil,
    pending_notifs = false,
    _start_handle = get_watcher_backend(),
  }
  setmetatable(w, self)
  return w
end

--- Starts the M
---
--@param self: (required, table) The M which should be started.
function M:start_handle()
  if self._start_handle then
    self._start_handle(self.bufnr)
  end
end

--- Stops the M and closes the handle.
---
--@param self: (required, table) The M which should be stopped.
function M:stop_handle()
  if self.handle == nil then
    return
  end

  self.handle:stop()

  -- close the handle altogether, for windows.
  if self.handle:is_closing() then
    return
  end
  self.handle:close()
end

--- Debounces the M. Completely closes the handle and starts again with a new
--- handle. Necessary for cases when the file being monitored is edited via editors
--- like vim, which, depending on the value of `backupcopy`, move the original file
--- for backing it up.
---
--@param self:(required, table) The M object which should be debounced.
function M:debounce()
  self:stop_handle()
  self:start_handle()
end

--- Callback for M handle. Marks a M as having pending
--- notifications. The nature of notification is determined while
--- responding to the notification.
---
--@param err: (string) Error if any occured during the execution of the callback.
---
function M:on_change(err)
  if err ~= nil then
    error(err)
  end

  self.pending_notifs = true
  handle_pending_notifications()

  self:debounce()
end

--- Starts and initializes a Watcher for the given path. A thin wrapper around
--- Watcher:start() that can be called from vimscript.
---
--@param bufnr: (required, string) The path that the M should watch.
local function start_watching_buf(bufnr)
  bufnr = tonumber(bufnr)
  if not buf_isvalid(bufnr) then
    return
  end

  if WatcherList[bufnr] ~= nil then
    WatcherList[bufnr]:debounce()
    return
  end

  WatcherList[bufnr] = M:new(bufnr)
  WatcherList[bufnr]:start_handle()
end

--- Stops the Watcher watching a given file and closes it's handle. A
--- thin wrapper around Watcher:stop() that can be called from vimscript.
---
--@param bufnr: (required, string) The buffer number of the buffer
--- that was being watched.
local function stop_watching_buf(bufnr)
  bufnr = tonumber(bufnr)
  -- can't close watchers for certain buffers
  if not buf_isvalid(bufnr) then
    return
  end

  -- shouldn't happen
  if WatcherList[bufnr] == nil then
    return
  end

  WatcherList[bufnr]:stop_handle()
end

return {
  start = start_watching_buf,
  stop = stop_watching_buf,
}