local M = {}

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
---@param opts table Additional options
---     - prompt (string|nil)
---               Text of the prompt. Defaults to `Select one of:`
---     - format_item (function item -> text)
---               Function to format an
---               individual item from `items`. Defaults to `tostring`.
---     - kind (string|nil)
---               Arbitrary hint string indicating the item shape.
---               Plugins reimplementing `vim.ui.select` may wish to
---               use this to infer the structure or semantics of
---               `items`, or the context in which select() was called.
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
---@param opts table? Additional options. See |input()|
---     - prompt (string|nil)
---               Text of the prompt
---     - default (string|nil)
---               Default reply to the input
---     - completion (string|nil)
---               Specifies type of completion supported
---               for input. Supported types are the same
---               that can be supplied to a user-defined
---               command using the "-complete=" argument.
---               See |:command-completion|
---     - highlight (function)
---               Function that will be used for highlighting
---               user inputs.
---@param on_confirm function ((input|nil) -> ())
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
---@param opt? { cmd?: string[] } Options
---     - cmd string[]|nil Command used to open the path or URL.
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

---@alias vim.ui.progress.Token integer|string
---@class vim.ui.progress.Task
---@field title string
---@field message? string
---@field cancellable boolean
---@field percentage? number

---@class vim.ui.progress.Progress
---@field ns table<integer, table<vim.ui.progress.Token, vim.ui.progress.Task>>
---@field on_new fun(ns_id: integer, token: vim.ui.progress.Token, task: vim.ui.progress.Task): nil
---@field on_update fun(ns_id: integer, token: vim.ui.progress.Token, task: vim.ui.progress.Task): nil
---@field on_finish fun(ns_id: integer, token: vim.ui.progress.Token, task: vim.ui.progress.Task): nil
---@field on_fail fun(ns_id: integer, token: vim.ui.progress.Token, task: vim.ui.progress.Task): nil
M._progress = {
  ns = {},
}

M._progress.on_new = function(_, _, task)
  vim.api.nvim_echo({
    {
      string.format('START %s%s', task.title, (task.message and ' | ' .. task.message or '')),
      'MsgArea',
    },
  }, false, {})
end

M._progress.on_update = function(_, _, task)
  vim.api.nvim_echo({
    {
      string.format(
        '(%d) %s%s',
        task.percentage * 100,
        task.title,
        (task.message and ' | ' .. task.message or '')
      ),
      'MsgArea',
    },
  }, false, {})
end

M._progress.on_finish = function(_, _, task)
  vim.api.nvim_echo({
    {
      string.format('DONE %s%s', task.title, (task.message and ' | ' .. task.message or '')),
      'MsgArea',
    },
  }, false, {})
end

M._progress.on_fail = function(_, _, task)
  vim.api.nvim_echo({
    {
      string.format('FAIL %s%s', task.title, (task.message and ' | ' .. task.message or '')),
      'ErrorMsg',
    },
  }, false, {})
end

--- @param ns_id integer Namespace for progress source. Implementations can
---   use to display information about the source (like name of LSP server)
---   based on namespace's name.
--- @param token vim.ui.progress.Token Token to identify specific progress report
---   within namespace.
--- @param kind 'start'|'report'|'finish'|'fail' Stage of progress.
--- @param opts? { title: string?, cancellable: boolean?, message: string?, percentage: number? }
---   Notes:
---   - `title` is required for `'begin'` kind.
---   - `message` can be used to show more detailed `#done / #total` progress,
---     as is currently done by LSP servers.
function M._progress.call(self, ns_id, token, kind, opts)
  vim.validate('ns_id', ns_id, 'number', false)
  vim.validate('token', token, { 'number', 'string' }, false)
  vim.validate('kind', kind, 'string', false)
  vim.validate('opts', opts, function(v)
    vim.validate('opts', v, 'table', true)
    vim.validate('opts.title', v.title, 'string', true)
    vim.validate('opts.cancellable', v.cancellable, 'boolean', true)
    vim.validate('opts.message', v.message, 'string', true)
    vim.validate('opts.percentage', v.percentage, function(percentage)
      if type(percentage) ~= 'number' or percentage > 1 or percentage < 0 then
        return false
      end
      return true
    end, true, 'number between 0 and 1')
    return true
  end, true)
  --[[@cast opts -nil]]

  if not self.ns[ns_id] then
    self.ns[ns_id] = {}
  end

  if not self.ns[ns_id][token] then
    if kind ~= 'start' then
      error('new progress token without start: ' .. token)
    end
    ---@diagnostic disable-next-line: missing-fields
    self.ns[ns_id][token] = {}
  elseif kind == 'start' then
    error('progress token already started: ' .. token)
  end

  local task = self.ns[ns_id][token]

  if opts.title then
    if kind ~= 'start' then
      error('progress title can not be set after start: ' .. token)
    end
    task.title = opts.title
  end
  if not opts.title and kind == 'start' then
    error('progress title is required for start: ' .. token)
  end

  if opts.cancellable and kind ~= 'start' then
    error('progress can not be set to cancellable after start: ' .. token)
  end
  task.cancellable = opts.cancellable or task.cancellable or true

  task.message = opts.message or task.message

  if opts.percentage and kind ~= 'report' then
    error(
      'can not update task progress with progress kind "'
        .. kind
        .. '"; use report instead: '
        .. token
    )
  end
  task.percentage = opts.percentage or task.percentage

  local _task = vim.deepcopy(task)
  if kind == 'start' then
    vim.schedule(function()
      self.on_new(ns_id, token, _task)
    end)
    return
  end
  if kind == 'report' then
    vim.schedule(function()
      self.on_update(ns_id, token, _task)
    end)
    return
  end

  self.ns[ns_id][token] = nil
  if kind == 'finish' then
    vim.schedule(function()
      self.on_finish(ns_id, token, _task)
    end)
  elseif kind == 'fail' then
    vim.schedule(function()
      self.on_fail(ns_id, token, _task)
    end)
  end
end

M.progress = setmetatable(M._progress, {
  __call = M._progress.call,
})

return M
