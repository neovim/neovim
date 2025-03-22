local M = {}

--- @param module string
---@return string
function M.includeexpr(module)
  local fname = module:gsub('%.', '/')

  local root = vim.fs.root(vim.api.nvim_buf_get_name(0), 'lua') or vim.fn.getcwd()
  for _, suf in ipairs { '.lua', '/init.lua' } do
    local path = vim.fs.joinpath(root, 'lua', fname .. suf)
    if vim.uv.fs_stat(path) then
      return path
    end
  end

  local modInfo = vim.loader.find(module)[1]
  return modInfo and modInfo.modpath or module
end

---@param keyword string
---@param opts {prefix: string?, suffix: string?, regex: string?, pattern: string?, on_keyword: function?}
---@return boolean
local function lookup_help(keyword, opts)
  if opts.regex and opts.pattern then
    error("Cannot use both regex and pattern options", vim.log.levels.ERROR)
    return false
  end
  if opts.regex then
    local match_start, match_end = vim.regex(opts.regex):match_str(keyword)
    if not match_start then
      return false
    end
    keyword = keyword:sub(match_start + 1, match_end)
  elseif opts.pattern then
    keyword = keyword:match(opts.pattern)
  elseif opts.on_keyword then
    keyword = opts.on_keyword(keyword)
  end
  if keyword and keyword ~= "" then
    if opts.prefix then
      keyword = opts.prefix .. keyword
    end
    if opts.suffix then
      keyword = keyword .. opts.suffix
    end
    return pcall(vim.cmd.help, vim.fn.escape(keyword, " []*?"))
  end
  return false
end

function M.keywordprg()
  local temp_isk = vim.o.iskeyword
  vim.cmd("set iskeyword+=.,#")
  ---@diagnostic disable-next-line: assign-type-mismatch
  local _, cword = pcall(vim.fn.expand, "<cword>") ---@type boolean, string
  vim.o.iskeyword = temp_isk
  if not cword or #cword == 0 then return end
  local list_of_opts = {
    -- Nvim API
    { regex = [[nvim_.\+]], suffix = '()' },
    -- Vimscript functions
    { regex = [[\(vim\.fn\.\)\@<=\w\+]], suffix = '()' },
    -- Options
    { regex = [[\(vim\.\(o\|go\|bo\|wo\|opt\|opt_local\|opt_global\)\.\)\@<=\w\+]], prefix = "'", suffix = "'" },
    -- Vimscript variables
    {
      ---@param keyword string
      ---@return string?
      on_keyword = function(keyword)
        local match_start, match_end = vim.regex([[\(vim\.\(g\|b\|w\|v\|t\)\.\)\@<=\w\+]]):match_str(keyword)
        if not match_start then return end
        return keyword:sub(match_start - 1, match_start - 1) .. ':' .. keyword:sub(match_start + 1, match_end)
      end
    },
    -- Ex commands
    { regex = [[\(vim\.cmd\.\)\@<=\w\+]], prefix = ":" },
    -- Luv
    { regex = [[\(vim\.uv\.\)\@<=\w\+]],  suffix = '()' },
    -- Luaref
    { prefix = 'lua-' },
    -- environment variable
    { regex = [[\(vim\.env\.\)\@<=\w\+]], prefix = "$" },
    -- Other
    {}
  }
  local success ---@type boolean
  for _, opts in ipairs(list_of_opts) do
    success = lookup_help(cword, opts)
    if success then
      break
    end
  end
  if not success then
    vim.notify("Sorry, can't find relevant help for " .. cword, vim.log.levels.ERROR)
  end
end

return M
