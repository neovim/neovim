--- @brief
--- Nvim supports EditorConfig. When a file is opened, after running |ftplugin|s
--- and |FileType| autocommands, Nvim searches all parent directories of that file
--- for ".editorconfig" files, parses them, and applies any properties that match
--- the opened file. Think of it like 'modeline' for an entire (recursive)
--- directory. For more information see https://editorconfig.org/.

--- @brief [g:editorconfig]() [b:editorconfig]()
---
--- EditorConfig is enabled by default. To disable it, add to your config:
--- ```lua
--- vim.g.editorconfig = false
--- ```
---
--- (Vimscript: `let g:editorconfig = v:false`). It can also be disabled
--- per-buffer by setting the [b:editorconfig] buffer-local variable to `false`.
---
--- Nvim stores the applied properties in [b:editorconfig] if it is not `false`.

--- @brief [editorconfig-custom-properties]()
---
--- New properties can be added by adding a new entry to the "properties" table.
--- The table key is a property name and the value is a callback function which
--- accepts the number of the buffer to be modified, the value of the property
--- in the `.editorconfig` file, and (optionally) a table containing all of the
--- other properties and their values (useful for properties which depend on other
--- properties). The value is always a string and must be coerced if necessary.
--- Example:
---
--- ```lua
---
--- require('editorconfig').properties.foo = function(bufnr, val, opts)
---   if opts.charset and opts.charset ~= "utf-8" then
---     error("foo can only be set when charset is utf-8", 0)
---   end
---   vim.b[bufnr].foo = val
--- end
---
--- ```

--- @brief [editorconfig-properties]()
---
--- The following properties are supported by default:

--- @type table<string,fun(bufnr: integer, val: string, opts?: table)>
local properties = {}

--- @private
--- Modified version of the builtin assert that does not include error position information
---
--- @param v any Condition
--- @param message string Error message to display if condition is false or nil
--- @return any v if not false or nil, otherwise an error is displayed
local function assert(v, message)
  return v or error(message, 0)
end

--- @private
--- Show a warning message
--- @param msg string Message to show
local function warn(msg, ...)
  vim.notify_once(msg:format(...), vim.log.levels.WARN, {
    title = 'editorconfig',
  })
end

--- If "true", then stop searching for `.editorconfig` files in parent
--- directories. This property must be at the top-level of the
--- `.editorconfig` file (i.e. it must not be within a glob section).
function properties.root()
  -- Unused
end

--- One of `"utf-8"`, `"utf-8-bom"`, `"latin1"`, `"utf-16be"`, or `"utf-16le"`.
--- Sets the 'fileencoding' and 'bomb' options.
function properties.charset(bufnr, val)
  assert(
    vim.list_contains({ 'utf-8', 'utf-8-bom', 'latin1', 'utf-16be', 'utf-16le' }, val),
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

--- One of `"lf"`, `"crlf"`, or `"cr"`.
--- These correspond to setting 'fileformat' to "unix", "dos", or "mac",
--- respectively.
function properties.end_of_line(bufnr, val)
  vim.bo[bufnr].fileformat = assert(
    ({ lf = 'unix', crlf = 'dos', cr = 'mac' })[val],
    'end_of_line must be one of "lf", "crlf", or "cr"'
  )
end

--- One of `"tab"` or `"space"`. Sets the 'expandtab' option.
function properties.indent_style(bufnr, val, opts)
  assert(val == 'tab' or val == 'space', 'indent_style must be either "tab" or "space"')
  vim.bo[bufnr].expandtab = val == 'space'
  if val == 'tab' and not opts.indent_size then
    vim.bo[bufnr].shiftwidth = 0
    vim.bo[bufnr].softtabstop = 0
  end
end

--- A number indicating the size of a single indent. Alternatively, use the
--- value "tab" to use the value of the tab_width property. Sets the
--- 'shiftwidth' and 'softtabstop' options. If this value is not "tab" and
--- the tab_width property is not set, 'tabstop' is also set to this value.
function properties.indent_size(bufnr, val, opts)
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

--- The display size of a single tab character. Sets the 'tabstop' option.
function properties.tab_width(bufnr, val)
  vim.bo[bufnr].tabstop = assert(tonumber(val), 'tab_width must be a number')
end

--- A number indicating the maximum length of a single
--- line. Sets the 'textwidth' option.
function properties.max_line_length(bufnr, val)
  local n = tonumber(val)
  if n then
    vim.bo[bufnr].textwidth = n
  else
    assert(val == 'off', 'max_line_length must be a number or "off"')
    vim.bo[bufnr].textwidth = 0
  end
end

--- When `"true"`, trailing whitespace is automatically removed when the buffer is written.
function properties.trim_trailing_whitespace(bufnr, val)
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

--- `"true"` or `"false"` to ensure the file always has a trailing newline as its last byte.
--- Sets the 'fixendofline' and 'endofline' options.
function properties.insert_final_newline(bufnr, val)
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

--- @private
--- Modified version of [glob2regpat()] that does not match path separators on `*`.
---
--- This function replaces single instances of `*` with the regex pattern `[^/]*`.
--- However, the star in the replacement pattern also gets interpreted by glob2regpat,
--- so we insert a placeholder, pass it through glob2regpat, then replace the
--- placeholder with the actual regex pattern.
---
--- @param glob string Glob to convert into a regular expression
--- @return string regex Regular expression
local function glob2regpat(glob)
  local placeholder = '@@PLACEHOLDER@@'
  local glob1 = vim.fn.substitute(
    glob:gsub('{(%d+)%.%.(%d+)}', '[%1-%2]'),
    '\\*\\@<!\\*\\*\\@!',
    placeholder,
    'g'
  )
  local regpat = vim.fn.glob2regpat(glob1)
  return (regpat:gsub(placeholder, '[^/]*'))
end

--- @private
--- Parse a single line in an EditorConfig file
--- @param line string Line
--- @return string? glob pattern if the line contains a pattern
--- @return string? key if the line contains a key-value pair
--- @return string? value if the line contains a key-value pair
local function parse_line(line)
  if not line:find('^%s*[^ #;]') then
    return
  end

  --- @type string?
  local glob = (line:match('%b[]') or ''):match('^%s*%[(.*)%]%s*$')
  if glob then
    return glob
  end

  local key, val = line:match('^%s*([^:= ][^:=]-)%s*[:=]%s*(.-)%s*$')
  if key ~= nil and val ~= nil then
    return nil, key:lower(), val:lower()
  end
end

--- @private
--- Parse options from an `.editorconfig` file
--- @param filepath string File path of the file to apply EditorConfig settings to
--- @param dir string Current directory
--- @return table<string,string|boolean> Table of options to apply to the given file
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

local M = {}

-- Exposed for use in syntax/editorconfig.vim`
M.properties = properties

--- @private
--- Configure the given buffer with options from an `.editorconfig` file
--- @param bufnr integer Buffer number to configure
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
        --- @type boolean, string?
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
