-- Create a file watcher, each watcher is identified by the name of the file that it
-- watches.

local uv = vim.loop

local Watcher = {}
local WatcherList = {}

-- Callback for the check handle, checks if there are pending notifications
-- for any watcher, and handles them as per the value of the `fcnotify`
-- option.
local function check_notifications()
  for f, watcher in pairs(WatcherList) do
    local option = vim.api.nvim_buf_get_option(watcher.bufnr, 'filechangenotify')
    if watcher.pending_notifs and watcher.paused == false and option ~= 'off' then
      if uv.fs_stat(watcher.ffname) ~= nil then
        vim.api.nvim_command('checktime '..watcher.bufnr)
        watcher.pending_notifs = false
      else
        print("ERR: File "..watcher.fname.." removed")
      end
    end
  end
end

-- Checks if a buffer should have a watcher attached to it.
-- Ignores all the buffers that aren't listed, or have a buf id
-- less than 0.
-- Ignores the [NO NAME] buffer.
local function valid_buf(fname)
  if fname == '' then
    return false
  end

  local bufnr = vim.api.nvim_call_function('bufnr', {fname})
  local buflisted = vim.api.nvim_buf_get_option(bufnr, 'buflisted')
  local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

  if bufnr < 0 or not buflisted or buftype == 'nofile' then
    return false
  end
  return true
end

local check_handle = uv.new_check()
check_handle:start(vim.schedule_wrap(check_notifications))

-- Creates and initializes a new watcher with the given filename.
--
--@param fname: (required, string) The path that the watcher should watch.
function Watcher:new(fname)
  vim.validate{fname = {fname, 'string', false}}
  -- get full path name for the file
  local ffname = vim.api.nvim_call_function('fnamemodify', {fname, ':p'})
  w = {bufnr = vim.api.nvim_call_function('bufnr', {fname}),
       fname = fname, ffname = ffname, handle = nil,
       paused = false, pending_notifs = false,}
  setmetatable(w, self)
  self.__index = self
  return w
end

-- Starts the watcher
function Watcher:start()
  self.handle = uv.new_fs_event()
  self.handle:start(self.ffname, {}, function(...)
    self:on_change(...)
  end)
end

-- Stops the watcher and closes the handle.
function Watcher:stop()
  self.handle:stop()

  -- close the handle altogether, for windows.
  if self.handle:is_closing() then
    return
  end
  self.handle:close()
end

function Watcher:on_change(err, fname, event)
  self.pending_notifs = true

  self:stop()
  self:start()
end

-- Starts and initializes a watcher for the given path.
--
--@param fname: (required, string) The path that the watcher should watch.
function Watcher.start_watch(fname)
  if not valid_buf(fname) then
    return
  end

  if WatcherList[fname] ~= nil then
    WatcherList[fname]:stop()
  end

  WatcherList[fname] = Watcher:new(fname)
  WatcherList[fname]:start()
end

-- Stops the watcher watching a given file and closes it's handle.
--
--@param fname: (required, string) The path which is being watched.
function Watcher.stop_watch(fname)
  -- can't close watchers for certain buffers
  if not valid_buf(fname) then
    return
  end

  print(fname)
  -- shouldn't happen
  if WatcherList[fname] == nil then
    print(fname..' not exists')
    return
  end

  WatcherList[fname]:stop()
end

function Watcher:pause_notif()
  self.paused = true
end

function Watcher:resume_notif()
  self.paused = false
end

function Watcher.pause_notif_all()
  check_handle:stop()
end

function Watcher.resume_notif_all()
  check_handle:start(vim.schedule_wrap(check_notifications))
end

function Watcher.print_all()
  print('Printing all watchers:')
  for i, watcher in pairs(WatcherList) do
    print(vim.inspect(watcher))
  end
end
return Watcher
