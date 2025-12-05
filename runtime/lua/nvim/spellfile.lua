--- @brief
--- Asks the user to download missing spellfiles. The spellfile is written to
--- `stdpath('data') .. 'site/spell'` or the first writable directory in the
--- 'runtimepath'.
---
--- The plugin can be disabled by setting `g:loaded_spellfile_plugin = 1`.

local M = {}

--- @class nvim.spellfile.Info
--- @inlinedoc
--- @field files string[]
--- @field key string
--- @field lang string
--- @field encoding string
--- @field dir string

--- A table with the following fields:
--- @class nvim.spellfile.Opts
---
--- The base URL from where the spellfiles are downloaded. Uses `g:spellfile_URL`
--- if it's set, otherwise https://ftp.nluug.nl/pub/vim/runtime/spell.
--- @field url string
---
--- Number of milliseconds after which the [vim.net.request()] times out.
--- (default: 15000)
--- @field timeout_ms integer
---
--- Whether to ask user to confirm download.
--- (default: `true`)
--- @field confirm boolean

--- @type nvim.spellfile.Opts
local config = {
  url = vim.g.spellfile_URL or 'https://ftp.nluug.nl/pub/vim/runtime/spell',
  timeout_ms = 15000,
  confirm = true,
}

--- Configure spellfile download options. For example:
--- ```lua
--- require('nvim.spellfile').config({ url = '...' })
--- ```
--- @param opts nvim.spellfile.Opts? When omitted or `nil`, retrieve the
---   current configuration. Otherwise, a configuration table.
--- @return nvim.spellfile.Opts? : Current config if {opts} is omitted.
function M.config(opts)
  vim.validate('opts', opts, 'table', true)
  if not opts then
    return vim.deepcopy(config, true)
  end
  for k, v in
    pairs(opts --[[@as table<any,any>]])
  do
    config[k] = v
  end
end

--- TODO(justinmk): add on_done/on_err callbacks to download(), instead of exposing this?
---@type table<string, boolean>
M._done = {}

---@return string[]
local function rtp_list()
  return vim.opt.rtp:get()
end

---@param msg string
---@param level vim.log.levels?
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

---@param lang string
---@return string
local function normalize_lang(lang)
  local l = (lang or ''):lower():gsub('-', '_')
  return (l:match('^[^,%s]+') or l)
end

---@param path string
---@return boolean
local function file_ok(path)
  local s = vim.uv.fs_stat(path)
  return s ~= nil and s.type == 'file' and (s.size or 0) > 0
end

---@param dir string
---@return boolean
local function can_use_dir(dir)
  return not not (vim.fn.isdirectory(dir) == 1 and vim.uv.fs_access(dir, 'W'))
end

---@return string[]
local function writable_spell_dirs_from_rtp()
  local dirs = {}
  for _, dir in ipairs(rtp_list()) do
    local spell = vim.fs.joinpath(vim.fs.abspath(dir), 'spell')
    if can_use_dir(spell) then
      table.insert(dirs, spell)
    end
  end
  return dirs
end

---@return string?
local function ensure_target_dir()
  local dir = vim.fs.abspath(vim.fs.joinpath(vim.fn.stdpath('data'), 'site/spell'))
  if vim.fn.isdirectory(dir) == 0 and pcall(vim.fn.mkdir, dir, 'p') then
    notify('Created ' .. dir)
  end
  if can_use_dir(dir) then
    return dir
  end

  -- Else, look for a spell/ dir in 'runtimepath'.
  local dirs = writable_spell_dirs_from_rtp()
  if #dirs > 0 then
    return dirs[1]
  end

  dir = vim.fn.fnamemodify(dir, ':~')
  error(('cannot find a writable spell/ dir in runtimepath, and %s is not usable'):format(dir))
end

local function reload_spell_silent()
  vim.cmd('silent! setlocal spell!')
  if vim.bo.spelllang and vim.bo.spelllang ~= '' then
    vim.cmd('silent! setlocal spelllang=' .. vim.bo.spelllang)
  end
  vim.cmd('echo ""')
end

--- Fetch file via blocking HTTP GET and write to `outpath`.
---
--- Treats status==0 as success if file exists.
---
--- @param url string
--- @param outpath string
--- @return boolean ok, integer|nil status, string|nil err
local function fetch_file_sync(url, outpath)
  local done, err, res = false, nil, nil
  vim.net.request(url, { outpath = outpath }, function(e, r)
    err, res, done = e, r, true
  end)
  vim.wait(config.timeout_ms, function()
    return done
  end, 50, false)

  local status = res and res.status or 0
  local ok = (not err) and ((status >= 200 and status < 300) or (status == 0 and file_ok(outpath)))
  return not not ok, (status ~= 0 and status or nil), err
end

---@param lang string
---@return nvim.spellfile.Info
local function parse(lang)
  local code = normalize_lang(lang)
  local enc = 'utf-8'
  local dir = ensure_target_dir()

  local missing = {}
  local candidates = {
    string.format('%s.%s.spl', code, enc),
    string.format('%s.%s.sug', code, enc),
  }
  for _, fn in ipairs(candidates) do
    if not file_ok(vim.fs.joinpath(dir, fn)) then
      table.insert(missing, fn)
    end
  end

  return {
    files = missing,
    key = code .. '.' .. enc,
    lang = code,
    encoding = enc,
    dir = dir,
  }
end

---@param info nvim.spellfile.Info
local function download(info)
  local dir = info.dir or ensure_target_dir()
  if not dir then
    notify('No (writable) spell directory found and could not create one.', vim.log.levels.ERROR)
    return
  end

  local lang = info.lang
  local enc = info.encoding

  local spl_utf8 = string.format('%s.%s.spl', lang, enc)
  local spl_ascii = string.format('%s.ascii.spl', lang)
  local sug_name = string.format('%s.%s.sug', lang, enc)

  local url_utf8 = config.url .. '/' .. spl_utf8
  local out_utf8 = vim.fs.joinpath(dir, spl_utf8)
  notify('Downloading ' .. spl_utf8 .. ' …')
  local ok, st, err = fetch_file_sync(url_utf8, out_utf8)
  if not ok then
    notify(
      ('Could not get %s (status %s): trying %s …'):format(
        spl_utf8,
        tostring(st or 'nil'),
        spl_ascii
      )
    )
    local url_ascii = config.url .. '/' .. spl_ascii
    local out_ascii = vim.fs.joinpath(dir, spl_ascii)
    local ok2, st2, err2 = fetch_file_sync(url_ascii, out_ascii)
    if not ok2 then
      notify(
        ('No spell file available for %s (utf8:%s ascii:%s) — %s'):format(
          lang,
          tostring(st or err or 'fail'),
          tostring(st2 or err2 or 'fail'),
          url_utf8
        ),
        vim.log.levels.WARN
      )
      vim.schedule(function()
        vim.cmd('echo ""')
      end)
      M._done[info.key] = true
      return
    end
    notify('Saved ' .. spl_ascii .. ' to ' .. out_ascii)
  else
    notify('Saved ' .. spl_utf8 .. ' to ' .. out_utf8)
  end

  reload_spell_silent()

  if not file_ok(vim.fs.joinpath(dir, sug_name)) then
    local url_sug = config.url .. '/' .. sug_name
    local out_sug = vim.fs.joinpath(dir, sug_name)
    notify('Downloading ' .. sug_name .. ' …')
    local ok3, st3, err3 = fetch_file_sync(url_sug, out_sug)
    if ok3 then
      notify('Saved ' .. sug_name .. ' to ' .. out_sug)
    else
      local is404 = (st3 == 404) or (tostring(err3 or ''):match('%f[%d]404%f[%D]') ~= nil)
      if is404 then
        notify('Suggestion file not available: ' .. sug_name, vim.log.levels.DEBUG)
      else
        notify(
          ('Failed to download %s (status %s): %s'):format(
            sug_name,
            tostring(st3 or 'nil'),
            tostring(err3 or '')
          ),
          vim.log.levels.INFO
        )
      end
      vim.schedule(function()
        vim.cmd('echo ""')
      end)
    end
  end

  M._done[info.key] = true
end

--- Download spellfiles for language {lang} if available.
--- @param lang string Language code.
--- @return nvim.spellfile.Info?
function M.get(lang)
  local info = parse(lang)
  if #info.files == 0 then
    return
  end
  if M._done[info.key] then
    notify('Already attempted spell load for ' .. lang, vim.log.levels.DEBUG)
    return
  end

  if config.confirm then
    local prompt = ('No spell file found for %s (%s). Download? [y/N] '):format(
      info.lang,
      info.encoding
    )
    vim.ui.input({ prompt = prompt }, function(input)
      -- properly clear the message window
      vim.api.nvim_echo({ { ' ' } }, false, { kind = 'empty' })
      if not input or input:lower() ~= 'y' then
        return
      end
      download(info)
    end)
  else
    download(info)
  end

  return info
end

return M
