local M = {}

---@class vim.ui.select.Opts
---@inlinedoc
---
--- Text of the prompt. Defaults to `Select one of:`
---@field prompt? string
---
--- Function to format an
--- individual item from `items`. Defaults to `tostring`.
---@field format_item? fun(item: any):string
---
--- Arbitrary hint string indicating the item shape.
--- Plugins reimplementing `vim.ui.select` may wish to
--- use this to infer the structure or semantics of
--- `items`, or the context in which select() was called.
---@field kind? string

--- Prompts the user to pick from a list of items, allowing arbitrary (potentially asynchronous)
--- work until `on_choice`.
---
--- Example:
---
--- ```lua
--- vim.ui.select({ 'tabs', 'spaces' }, {
---     prompt = 'Select tabs or spaces:',
---     format_item = function(item)
---         return "I'd like to choose " .. item
---     end,
--- }, function(choice)
---     if choice == 'spaces' then
---         vim.o.expandtab = true
---     else
---         vim.o.expandtab = false
---     end
--- end)
--- ```
---
---@generic T
---@param items T[] Arbitrary items
---@param opts vim.ui.select.Opts Additional options
---@param on_choice fun(item: T|nil, idx: integer|nil)
---               Called once the user made a choice.
---               `idx` is the 1-based index of `item` within `items`.
---               `nil` if the user aborted the dialog.
function M.select(items, opts, on_choice)
  vim.validate('items', items, 'table')
  vim.validate('on_choice', on_choice, 'function')
  opts = opts or {}
  local choices = { opts.prompt or 'Select one of:' }
  local format_item = opts.format_item or tostring
  for i, item in
    ipairs(items --[[@as any[] ]])
  do
    table.insert(choices, string.format('%d: %s', i, format_item(item)))
  end
  local choice = vim.fn.inputlist(choices)
  if choice < 1 or choice > #items then
    on_choice(nil, nil)
  else
    on_choice(items[choice], choice)
  end
end

---@class vim.ui.input.Opts
---@inlinedoc
---
---Text of the prompt
---@field prompt? string
---
---Default reply to the input
---@field default? string
---
---Specifies type of completion supported
---for input. Supported types are the same
---that can be supplied to a user-defined
---command using the "-complete=" argument.
---See |:command-completion|
---@field completion? string
---
---Function that will be used for highlighting
---user inputs.
---@field highlight? function

--- Prompts the user for input, allowing arbitrary (potentially asynchronous) work until
--- `on_confirm`.
---
--- Example:
---
--- ```lua
--- vim.ui.input({ prompt = 'Enter value for shiftwidth: ' }, function(input)
---     vim.o.shiftwidth = tonumber(input)
--- end)
--- ```
---
---@param opts? vim.ui.input.Opts Additional options. See |input()|
---@param on_confirm fun(input?: string)
---               Called once the user confirms or abort the input.
---               `input` is what the user typed (it might be
---               an empty string if nothing was entered), or
---               `nil` if the user aborted the dialog.
function M.input(opts, on_confirm)
  vim.validate('opts', opts, 'table', true)
  vim.validate('on_confirm', on_confirm, 'function')

  opts = (opts and not vim.tbl_isempty(opts)) and opts or vim.empty_dict()

  -- Note that vim.fn.input({}) returns an empty string when cancelled.
  -- vim.ui.input() should distinguish aborting from entering an empty string.
  local _canceled = vim.NIL
  opts = vim.tbl_extend('keep', opts, { cancelreturn = _canceled })

  local ok, input = pcall(vim.fn.input, opts)
  if not ok or input == _canceled then
    on_confirm(nil)
  else
    on_confirm(input)
  end
end

---@class vim.ui.open.Opts
---@inlinedoc
---
--- Command used to open the path or URL.
---@field cmd? string[]

--- Opens `path` with the system default handler (macOS `open`, Windows `explorer.exe`, Linux
--- `xdg-open`, …), or returns (but does not show) an error message on failure.
---
--- Can also be invoked with `:Open`. [:Open]()
---
--- Expands "~/" and environment variables in filesystem paths.
---
--- Examples:
---
--- ```lua
--- -- Asynchronous.
--- vim.ui.open("https://neovim.io/")
--- vim.ui.open("~/path/to/file")
--- -- Use the "osurl" command to handle the path or URL.
--- vim.ui.open("gh#neovim/neovim!29490", { cmd = { 'osurl' } })
--- -- Synchronous (wait until the process exits).
--- local cmd, err = vim.ui.open("$VIMRUNTIME")
--- if cmd then
---   cmd:wait()
--- end
--- ```
---
---@param path string Path or URL to open
---@param opt? vim.ui.open.Opts Options
---
---@return vim.SystemObj|nil # Command object, or nil if not found.
---@return nil|string # Error message on failure, or nil on success.
---
---@see |vim.system()|
function M.open(path, opt)
  vim.validate('path', path, 'string')
  local is_uri = path:match('%w+:')
  if not is_uri then
    path = vim.fs.normalize(path)
  end

  opt = opt or {}
  local cmd ---@type string[]
  local job_opt = { text = true, detach = true } --- @type vim.SystemOpts

  if opt.cmd then
    cmd = vim.list_extend(opt.cmd --[[@as string[] ]], { path })
  elseif vim.fn.has('mac') == 1 then
    cmd = { 'open', path }
  elseif vim.fn.has('win32') == 1 then
    if vim.fn.executable('rundll32') == 1 then
      cmd = { 'rundll32', 'url.dll,FileProtocolHandler', path }
    else
      return nil, 'vim.ui.open: rundll32 not found'
    end
  elseif vim.fn.executable('xdg-open') == 1 then
    cmd = { 'xdg-open', path }
    job_opt.stdout = false
    job_opt.stderr = false
  elseif vim.fn.executable('wslview') == 1 then
    cmd = { 'wslview', path }
  elseif vim.fn.executable('explorer.exe') == 1 then
    cmd = { 'explorer.exe', path }
  elseif vim.fn.executable('lemonade') == 1 then
    cmd = { 'lemonade', 'open', path }
  else
    return nil, 'vim.ui.open: no handler found (tried: wslview, explorer.exe, xdg-open, lemonade)'
  end

  return vim.system(cmd, job_opt), nil
end

--- Returns all URLs at cursor, if any.
--- @return string[]
function M._get_urls()
  local urls = {} ---@type string[]

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, { row, col }, { row, col }, {
    details = true,
    type = 'highlight',
    overlap = true,
  })
  for _, v in ipairs(extmarks) do
    local details = v[4]
    if details and details.url then
      urls[#urls + 1] = details.url
    end
  end

  local highlighter = vim.treesitter.highlighter.active[bufnr]
  if highlighter then
    local range = { row, col, row, col }
    local ltree = highlighter.tree:language_for_range(range)
    local lang = ltree:lang()
    local query = vim.treesitter.query.get(lang, 'highlights')
    if query then
      local tree = assert(ltree:tree_for_range(range))
      for _, match, metadata in query:iter_matches(tree:root(), bufnr, row, row + 1) do
        for id, nodes in pairs(match) do
          for _, node in ipairs(nodes) do
            if vim.treesitter.node_contains(node, range) then
              local url = metadata[id] and metadata[id].url
              if url and match[url] then
                for _, n in
                  ipairs(match[url] --[[@as TSNode[] ]])
                do
                  urls[#urls + 1] =
                    vim.treesitter.get_node_text(n, bufnr, { metadata = metadata[url] })
                end
              end
            end
          end
        end
      end
    end
  end

  if #urls == 0 then
    -- If all else fails, use the filename under the cursor
    table.insert(
      urls,
      vim._with({ go = { isfname = vim.o.isfname .. ',@-@' } }, function()
        return vim.fn.expand('<cfile>')
      end)
    )
  end

  return urls
end

do
  ---@class ProgressMessage
  ---@field title? string   Title of the progress message
  ---@field status string  Status: "running" | "success" | "failed" | "cancel"
  ---@field percent? integer Percent complete (0–100)
  ---@private

  ---Cache of active progress messages, keyed by msg_id
  ---@type table<integer, ProgressMessage>
  local progress = {}

  -- store progress events
  local progress_group = vim.api.nvim_create_augroup('nvim.status.progress', { clear = true })
  vim.api.nvim_create_autocmd('Progress', {
    group = progress_group,
    desc = 'Track progress messages for statusline',
    ---@param ev {data: {id: integer, title: string, status: string, percent: integer}}
    callback = function(ev)
      if not ev.data or not ev.data.id then
        return
      end
      progress[ev.data.id] = {
        title = ev.data.title,
        status = ev.data.status,
        percent = ev.data.percent or 0,
      }

      -- Clear finished items
      if
        ev.data.status == 'success'
        or ev.data.percent == 100
        or ev.data.status == 'failed'
        or ev.data.status == 'cancel'
      then
        progress[ev.data.id] = nil
      end
    end,
  })

  ---Return statusline text summarizing progress messages.
  --- - If none: returns empty string
  --- - If one running item: "title: 42%"
  --- - If multiple running items: "Progress: N items AVG%"
  ---@param running ProgressMessage[]
  ---@return string
  local function progress_status_fmt(running)
    local count = #running
    if count == 0 then
      return '' -- nothing to show
    elseif count == 1 then
      local progress_item = running[1]
      if progress_item.title == nil then
        return string.format('%d%%%% ', progress_item.percent or 0)
      end
      return string.format('%s: %d%%%% ', progress_item.title, progress_item.percent or 0)
    else
      local sum = 0 ---@type integer
      for _, progress_item in ipairs(running) do
        sum = sum + (progress_item.percent or 0)
      end
      local avg = math.floor(sum / count)
      return string.format('Progress: %d items %d%%%% ', count, avg)
    end
  end

  ---@class vim.ui.get_progress_status.Opts
  ---custom formater for progress messages
  ---@field fmt? fun(running: ProgressMessage[]):string
  --
  --- Function to format the list of running progress messages for statusline
  ---@param opts? vim.ui.get_progress_status.Opts Options
  ---@return string Statusline component text
  function M.get_progress_status(opts)
    vim.validate('opts', opts, 'table', true)
    if opts ~= nil then
      vim.validate('fmt', opts.fmt, 'function', true)
    end
    if opts == nil or opts.fmt == nil then
      opts = { fmt = progress_status_fmt }
    end

    local running = {} ---@type ProgressMessage[]
    for _, msg in pairs(progress) do
      if msg.status == 'running' then
        table.insert(running, msg)
      end
    end
    return opts.fmt(running) or ''
  end
end

return M
