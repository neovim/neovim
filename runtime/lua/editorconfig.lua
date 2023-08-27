local M = {}

--- @type table<string,fun(bufnr: integer, val: string, opts?: table)>
M.properties = {}

--- Modified version of the builtin assert that does not include error position information
---
---@param v any Condition
---@param message string Error message to display if condition is false or nil
---@return any v if not false or nil, otherwise an error is displayed
---
---@private
local function assert(v, message)
  return v or error(message, 0)
end

--- Show a warning message
---
---@param msg string Message to show
---
---@private
local function warn(msg, ...)
  vim.notify_once(string.format(msg, ...), vim.log.levels.WARN, {
    title = 'editorconfig',
  })
end

function M.properties.charset(bufnr, val)
  assert(
    vim.tbl_contains({ 'utf-8', 'utf-8-bom', 'latin1', 'utf-16be', 'utf-16le' }, val),
    'charset must be one of "utf-8", "utf-8-bom", "latin1", "utf-16be", or "utf-16le"'
  )
  if val == 'utf-8' or val == 'utf-8-bom' then
    vim.bo[bufnr].fileencoding = 'utf-8'
    vim.bo[bufnr].bomb = val == 'utf-8-bom'
  elseif val == 'utf-16be' then
    vim.bo[bufnr].fileencoding = 'utf-16'
  else
    vim.bo[bufnr].fileencoding = val
  end
end

function M.properties.end_of_line(bufnr, val)
  vim.bo[bufnr].fileformat = assert(
    ({ lf = 'unix', crlf = 'dos', cr = 'mac' })[val],
    'end_of_line must be one of "lf", "crlf", or "cr"'
  )
end

function M.properties.indent_style(bufnr, val, opts)
  assert(val == 'tab' or val == 'space', 'indent_style must be either "tab" or "space"')
  vim.bo[bufnr].expandtab = val == 'space'
  if val == 'tab' and not opts.indent_size then
    vim.bo[bufnr].shiftwidth = 0
    vim.bo[bufnr].softtabstop = 0
  end
end

function M.properties.indent_size(bufnr, val, opts)
  if val == 'tab' then
    vim.bo[bufnr].shiftwidth = 0
    vim.bo[bufnr].softtabstop = 0
  else
    local n = assert(tonumber(val), 'indent_size must be a number')
    vim.bo[bufnr].shiftwidth = n
    vim.bo[bufnr].softtabstop = -1
    if not opts.tab_width then
      vim.bo[bufnr].tabstop = n
    end
  end
end

function M.properties.tab_width(bufnr, val)
  vim.bo[bufnr].tabstop = assert(tonumber(val), 'tab_width must be a number')
end

function M.properties.max_line_length(bufnr, val)
  local n = tonumber(val)
  if n then
    vim.bo[bufnr].textwidth = n
  else
    assert(val == 'off', 'max_line_length must be a number or "off"')
    vim.bo[bufnr].textwidth = 0
  end
end

function M.properties.trim_trailing_whitespace(bufnr, val)
  assert(
    val == 'true' or val == 'false',
    'trim_trailing_whitespace must be either "true" or "false"'
  )
  if val == 'true' then
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = 'editorconfig',
      buffer = bufnr,
      callback = function()
        local view = vim.fn.winsaveview()
        vim.api.nvim_command('silent! undojoin')
        vim.api.nvim_command('silent keepjumps keeppatterns %s/\\s\\+$//e')
        vim.fn.winrestview(view)
      end,
    })
  else
    vim.api.nvim_clear_autocmds({
      event = 'BufWritePre',
      group = 'editorconfig',
      buffer = bufnr,
    })
  end
end

function M.properties.insert_final_newline(bufnr, val)
  assert(val == 'true' or val == 'false', 'insert_final_newline must be either "true" or "false"')
  vim.bo[bufnr].fixendofline = val == 'true'

  -- 'endofline' can be read to detect if the file contains a final newline,
  -- so only change 'endofline' right before writing the file
  local endofline = val == 'true'
  if vim.bo[bufnr].endofline ~= endofline then
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = 'editorconfig',
      buffer = bufnr,
      once = true,
      callback = function()
        vim.bo[bufnr].endofline = endofline
      end,
    })
  end
end

--- Modified version of |glob2regpat()| that does not match path separators on *.
---
--- This function replaces single instances of * with the regex pattern [^/]*. However, the star in
--- the replacement pattern also gets interpreted by glob2regpat, so we insert a placeholder, pass
--- it through glob2regpat, then replace the placeholder with the actual regex pattern.
---
---@param glob string Glob to convert into a regular expression
---@return string Regular expression
---
---@private
local function glob2regpat(glob)
  local placeholder = '@@PLACEHOLDER@@'
  return (
    string.gsub(
      vim.fn.glob2regpat(
        vim.fn.substitute(
          string.gsub(glob, '{(%d+)%.%.(%d+)}', '[%1-%2]'),
          '\\*\\@<!\\*\\*\\@!',
          placeholder,
          'g'
        )
      ),
      placeholder,
      '[^/]*'
    )
  )
end

--- Parse a single line in an EditorConfig file
---
---@param line string Line
---@return string|nil If the line contains a pattern, the glob pattern
---@return string|nil If the line contains a key-value pair, the key
---@return string|nil If the line contains a key-value pair, the value
---
---@private
local function parse_line(line)
  if line:find('^%s*[^ #;]') then
    local glob = (line:match('%b[]') or ''):match('^%s*%[(.*)%]%s*$')
    if glob then
      return glob, nil, nil
    end

    local key, val = line:match('^%s*([^:= ][^:=]-)%s*[:=]%s*(.-)%s*$')
    if key ~= nil and val ~= nil then
      return nil, key:lower(), val:lower()
    end
  end
end

--- Parse options from an .editorconfig file
---
---@param filepath string File path of the file to apply EditorConfig settings to
---@param dir string Current directory
---@return table<string,string|boolean> Table of options to apply to the given file
---
---@private
local function parse(filepath, dir)
  local pat --- @type vim.regex?
  local opts = {} --- @type table<string,string|boolean>
  local f = io.open(dir .. '/.editorconfig')
  if f then
    for line in f:lines() do
      local glob, key, val = parse_line(line)
      if glob then
        glob = glob:find('/') and (dir .. '/' .. glob:gsub('^/', '')) or ('**/' .. glob)
        local ok, regpat = pcall(glob2regpat, glob)
        if ok then
          pat = vim.regex(regpat)
        else
          pat = nil
          warn('editorconfig: Error occurred while parsing glob pattern "%s": %s', glob, regpat)
        end
      elseif key ~= nil and val ~= nil then
        if key == 'root' then
          assert(val == 'true' or val == 'false', 'root must be either "true" or "false"')
          opts.root = val == 'true'
        elseif pat and pat:match_str(filepath) then
          opts[key] = val
        end
      end
    end
    f:close()
  end
  return opts
end

--- Configure the given buffer with options from an .editorconfig file
---
---@param bufnr integer Buffer number to configure
---
---@private
function M.config(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
  if vim.bo[bufnr].buftype ~= '' or not vim.bo[bufnr].modifiable or path == '' then
    return
  end

  local opts = {} --- @type table<string,string|boolean>
  for parent in vim.fs.parents(path) do
    for k, v in pairs(parse(path, parent)) do
      if opts[k] == nil then
        opts[k] = v
      end
    end

    if opts.root then
      break
    end
  end

  local applied = {} --- @type table<string,string|boolean>
  for opt, val in pairs(opts) do
    if val ~= 'unset' then
      local func = M.properties[opt]
      if func then
        local ok, err = pcall(func, bufnr, val, opts)
        if ok then
          applied[opt] = val
        else
          warn('editorconfig: invalid value for option %s: %s. %s', opt, val, err)
        end
      end
    end
  end

  vim.b[bufnr].editorconfig = applied
end

return M
