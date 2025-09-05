local M = {}

--- @class SpellfileConfig
--- @field url string
--- @field timeout_ms integer

---@class SpellInfo
---@field files string[]
---@field key string
---@field lang string
---@field encoding string
---@field dir string

---@type SpellfileConfig
M.config = {
  url = 'https://ftp.nluug.nl/pub/vim/runtime/spell',
  timeout_ms = 15000,
}

---@type table<string, boolean>
M._done = {}

---@return string[]
local function rtp_list()
  return vim.opt.rtp:get()
end

function M.isDone(key)
  return M._done[key]
end

function M.setup(opts)
  M._done = {}
  M.config = vim.tbl_extend('force', M.config, opts or {})
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

---@param lang string
---@return string
local function normalize_lang(lang)
  local l = (lang or ''):lower():gsub('-', '_')
  return (l:match('^[^,%s]+') or l)
end

local function writable_spell_dirs_from_rtp()
  local dirs = {}
  for _, dir in ipairs(rtp_list()) do
    local spell = vim.fs.joinpath(vim.fn.fnamemodify(dir, ':p'), 'spell')
    if vim.fn.isdirectory(spell) == 1 and vim.uv.fs_access(spell, 'W') then
      table.insert(dirs, spell)
    end
  end
  return dirs
end

local function default_spell_dir()
  return vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'spell')
end

local function ensure_target_dir()
  local dirs = writable_spell_dirs_from_rtp()
  if #dirs > 0 then
    return dirs[1]
  end
  local target = default_spell_dir()
  if vim.fn.isdirectory(target) ~= 1 then
    vim.fn.mkdir(target, 'p')
    notify('Created ' .. target)
  end
  return target
end

local function file_ok(path)
  local s = vim.uv.fs_stat(path)
  return s and s.type == 'file' and (s.size or 0) > 0
end

local function reload_spell_silent()
  vim.cmd('silent! setlocal spell!')
  if vim.bo.spelllang and vim.bo.spelllang ~= '' then
    vim.cmd('silent! setlocal spelllang=' .. vim.bo.spelllang)
  end
  vim.cmd('echo ""')
end

--- Blocking GET to file with timeout; treats status==0 as success if file exists.
--- @return boolean ok, integer|nil status, string|nil err
local function http_get_to_file_sync(url, outpath, timeout_ms)
  local done, err, res = false, nil, nil
  vim.net.request(url, { outpath = outpath }, function(e, r)
    err, res, done = e, r, true
  end)
  vim.wait(timeout_ms or M.config.timeout_ms, function()
    return done
  end, 50, false)

  local status = res and res.status or 0
  local ok = (not err) and ((status >= 200 and status < 300) or (status == 0 and file_ok(outpath)))
  return ok, (status ~= 0 and status or nil), err
end

---@return string[]
function M.directory_choices()
  local opts = {}
  for _, dir in ipairs(rtp_list()) do
    local spelldir = vim.fs.joinpath(vim.fn.fnamemodify(dir, ':p'), 'spell')
    if vim.fn.isdirectory(spelldir) == 1 then
      table.insert(opts, spelldir)
    end
  end
  return opts
end

function M.choose_directory()
  local dirs = writable_spell_dirs_from_rtp()
  if #dirs == 0 then
    return ensure_target_dir()
  elseif #dirs == 1 then
    return dirs[1]
  end
  local prompt ---@type string[]
  prompt = {}
  for i, d in
    ipairs(dirs --[[@as string[] ]])
  do
    prompt[i] = string.format('%d: %s', i, d)
  end
  local choice = vim.fn.inputlist(prompt)
  if choice < 1 or choice > #dirs then
    return dirs[1]
  end
  return dirs[choice]
end

function M.parse(lang)
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

---@param info SpellInfo
function M.download(info)
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

  local url_utf8 = M.config.url .. '/' .. spl_utf8
  local out_utf8 = vim.fs.joinpath(dir, spl_utf8)
  notify('Downloading ' .. spl_utf8 .. ' …')
  local ok, st, err = http_get_to_file_sync(url_utf8, out_utf8, M.config.timeout_ms)
  if not ok then
    notify(
      ('Could not get %s (status %s): trying %s …'):format(
        spl_utf8,
        tostring(st or 'nil'),
        spl_ascii
      )
    )
    local url_ascii = M.config.url .. '/' .. spl_ascii
    local out_ascii = vim.fs.joinpath(dir, spl_ascii)
    local ok2, st2, err2 = http_get_to_file_sync(url_ascii, out_ascii, M.config.timeout_ms)
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
    local url_sug = M.config.url .. '/' .. sug_name
    local out_sug = vim.fs.joinpath(dir, sug_name)
    notify('Downloading ' .. sug_name .. ' …')
    local ok3, st3, err3 = http_get_to_file_sync(url_sug, out_sug, M.config.timeout_ms)
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

function M.load_file(lang)
  local info = M.parse(lang)
  if #info.files == 0 then
    return
  end
  if M._done[info.key] then
    notify('Already attempted spell load for ' .. lang, vim.log.levels.DEBUG)
    return
  end

  local answer = vim.fn.input(
    string.format('No spell file found for %s (%s). Download? [y/N] ', info.lang, info.encoding)
  )
  if (answer or ''):lower() ~= 'y' then
    return
  end

  M.download(info)
end

function M.exists(filename)
  local stat = (vim.uv or vim.loop).fs_stat
  for _, dir in ipairs(M.directory_choices()) do
    local p = vim.fs.joinpath(dir, filename)
    local s = stat(p)
    if s and s.type == 'file' then
      return true
    end
  end
  return false
end

return M
