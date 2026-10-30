-- What plugins ask the user through, shown by the GUI: |vim.ui.select()| is
-- a picker (biscide.picker), |vim.ui.input()| Nvim's own prompt on the
-- command line (the status line shows it), |vim.notify()| a message (the
-- messages panel keeps it). A configuration's plugins may have set their
-- own (in floating windows the GUI does not show): biscide's are set again
-- once they have loaded. A plugin that draws Nvim's messages itself
-- (noice.nvim) is turned off: the GUI shows them.

local M = {}

---@param items any[]
---@param opts table
---@param on_choice fun(item: any?, idx: integer?)
function M.select(items, opts, on_choice)
  opts = opts or {}
  local format = opts.format_item or tostring
  local chosen = false
  require("biscide.picker").open({
    title = (opts.prompt or "Select"):gsub(":%s*$", ""),
    items = vim.list_slice(items, 1, #items),
    format = function(it)
      return { text = tostring(format(it)), kind = opts.kind }
    end,
    confirm = function(item, idx)
      chosen = true
      on_choice(item, idx)
    end,
    cancel = function()
      if not chosen then
        on_choice(nil, nil)
      end
    end,
  })
end

---@param opts table
---@param on_confirm fun(input: string?)
function M.input(opts, on_confirm)
  opts = opts or {}
  local ok, input = pcall(vim.fn.input, {
    prompt = opts.prompt or "",
    default = opts.default or "",
    completion = opts.completion,
    highlight = opts.highlight,
    cancelreturn = "\0",
  })
  if not ok or input == "\0" then
    input = nil
  end
  on_confirm(input)
end

---@param msg string
---@param level? integer
---@param opts? table
function M.notify(msg, level, opts)
  level = level or vim.log.levels.INFO
  local title = type(opts) == "table" and opts.title
  local text = title and (title .. ": " .. msg) or tostring(msg)
  local hl = level >= vim.log.levels.ERROR and "ErrorMsg" or level == vim.log.levels.WARN and "WarningMsg" or nil
  vim.api.nvim_echo({ { text, hl } }, true, {
    err = level >= vim.log.levels.ERROR,
    kind = level == vim.log.levels.WARN and "wmsg" or nil,
  })
end

--- biscide's set (again, over what plugins set).
function M.setup()
  vim.ui.select = M.select
  vim.ui.input = M.input
  vim.notify = M.notify
  if package.loaded["noice"] then
    pcall(vim.cmd, "Noice disable")
  end
end

--- Set now, and once the configuration's lazy plugins have loaded.
function M.install()
  M.setup()
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("biscide_ui", { clear = true }),
    pattern = { "VeryLazy", "LazyDone" },
    callback = function()
      vim.schedule(M.setup)
    end,
  })
end

return M
