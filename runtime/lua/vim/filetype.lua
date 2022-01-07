local api = vim.api
local M = {}

_G['vim.filetype.autocmd.counter'] = 0
api.nvim_exec([[
" should we really care "reloaded" situation? (e.g. augroup and au!)
augroup vimfiletypeautocmdcounter
  autocmd!
  autocmd FileType * lua _G['vim.filetype.autocmd.counter'] = _G['vim.filetype.autocmd.counter'] + 1
augroup END
]], false)

-- wrap side-effectful filetype setting function
-- it will not execute the wrapped function if it's not targeting the current buffer
-- this is for reusing old vim side-effectful logic inside new lua file type detection logic
local function wrap_legacy_side_effectful_filetype_detector(fn)
  return function(clue, ...)
    if clue.is_current_buffer then
      local before = _G['vim.filetype.autocmd.counter']
      local ret = fn(clue, ...)
      if type(ret) == 'string' then
        return ret
      end
      -- :setfiletype was called and FileType autocmd was fired during the execution of fn
      if _G['vim.filetype.autocmd.counter'] ~= before then
        return vim.api.nvim_buf_get_option(0, "filetype")
      end
    end
  end
end


function create_definition()
  local INNER_M = {}

  ---@private
  -- Function used for patterns that end in a star ("*"): don't set the filetype if the
  -- file name matches ft_ignore_pat.
  local function starsetf(ft)
    return function(clue)
      if clue.path then
        local path = clue.path
        if not vim.g.ft_ignore_pat then
          return ft
        end

        local re = vim.regex(vim.g.ft_ignore_pat)
        if not re:match_str(path) then
          return ft
        end
      end
    end
  end

  INNER_M.extension = {
    cpp = function()
      if vim.g.cynlib_syntax_for_cc then
        return "cynlib"
      end
      return "cpp"
    end,
    ts = function(clue)
      if clue.getline(1):find("<%?xml") then
        return "xml"
      else
        return "typescript"
      end
    end,
    lua = 'lua',
    tsx = "typescriptreact",
    E = wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#FTe"]() end),
    htm = wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#FThtml"]() end),
    html = wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#FThtml"]() end),
  }

  INNER_M.filename = {
    ["a2psrc"] = "a2ps",
    ["/etc/a2ps.cfg"] = "a2ps",
    [".a2psrc"] = "a2ps",
    [".asoundrc"] = "alsaconf",
    ["/usr/share/alsa/alsa.conf"] = "alsaconf",
    ["/etc/asound.conf"] = "alsaconf",
    WORKSPACE = "bzl",
    BUILD = "bzl",
    [".tcshrc"] = wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#SetFileTypeShell"]("tcsh") end),
    ["/etc/profile"] = wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#SetFileTypeSH"](vim.fn.getline(1)) end),
    APKBUILD = wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#SetFileTypeSH"]("bash") end),
    ["bash.bashrc"] = wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#SetFileTypeSH"]("bash") end),
    bashrc = wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#SetFileTypeSH"]("bash") end),
    crontab = starsetf('crontab'),
  }

  INNER_M.filename_pattern = {
    {".*/etc/a2ps/.*%.cfg", "a2ps"},
    {"bash%-fc[-%.]", wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#SetFileTypeSH"]("bash") end)},
    {".*/usr/share/alsa/alsa%.conf",  "alsaconf"},
    {".*hgrc",  "cfg"},
    {".*%.cmake%.in",  "cmake"},
    {".*/etc/blkid%.tab%.old",  "xml"},
    {".*/etc/xdg/menus/.*%.menu",  "xml"},
    {".*Xmodmap",  "xmodmap"},
    {".*/etc/zprofile",  "zsh"},
    {"ae%d+%.txt",  'mail'},
    {"%.bash[_-]logout", wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#SetFileTypeSH"]("bash") end)},
  }

  INNER_M.filename_pattern_low_priority = {
    {'zsh.*', starsetf('zsh')},
    {"%.cshrc.*", wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#CSH"]() end)},
    {"%.gtkrc.*", starsetf('gtkrc')},
    {"%.kshrc.*", wrap_legacy_side_effectful_filetype_detector(function() vim.fn["dist#ft#SetFileTypeSH"]("ksh") end)},
  }

  INNER_M.firstline = {
    {"^#!.*%f[%w]node%f[^%w]", 'javascript'},
  }

  return INNER_M
end


---@private
local function getline(bufnr, lnum)
  return api.nvim_buf_get_lines(bufnr, lnum-1, lnum, false)[1]
end


---@private
local function normalize_path(path)
  return (path:gsub("\\", "/"))
end

function M.set_filetype_for_current_buffer(bufname)
  bufname = bufname or api.nvim_buf_get_name(0)

  local ft = M.detect {
    path = vim.fn.resolve(vim.fn.fnamemodify(normalize_path(bufname), ":p")),
    getline = function(n) return getline(0, n) end,
    is_current_buffer = true,
  }
  -- Since is_current_buffer = true, some logic might have already called `:setfiletype`
  -- In that case we should not set filetype here again to avoid duplicated FileType autocmd firing
  if ft and vim.fn.did_filetype() == 0 then
    api.nvim_buf_set_option(0, "filetype", ft)
  end
end

function M.detect(clue)
  -- Lua version of https://github.com/neovim/neovim/blob/09d270bcea5f81a0772e387244cc841e280a5339/runtime/filetype.vim#L18-L35
  if clue.path then
    local stripped_path, ext = clue.path:match[[^(.+)%.([%w_-]+)$]]
    local ignored_extensions = {['bak']=true, ['rpmsave']=true, ['dpkg-old']=true, orig=true}
    if stripped_path and ignored_extensions[ext] then
      local ft = M.detect_main(vim.tbl_extend('force', clue, {path = stripped_path}))
      if ft then return ft end
    end
  end

  return M.detect_main(clue)
end

local function dispatch(ft, clue, ...)
  if type(ft) == 'function' then
    return ft(clue, ...)
  end
  return ft
end

M.definition = create_definition()

local function ipairs_reverse_iterator(tbl, i)
    i = i - 1
    if i ~= 0 then
      return i, tbl[i]
    end
end

local function ipairs_reverse(tbl)
    return ipairs_reverse_iterator, tbl, #tbl + 1
end

local function match_filename_pattern(clue, def)
  if clue.path then
    local path = clue.path
    local basename = vim.fn.fnamemodify(path, ":t")
    for _, value in ipairs_reverse(def) do
      local pattern, ft = unpack(value)
      -- If the pattern contains a / match against the full path, otherwise just the tail
      local pat = "^" .. pattern .. "$"
      local matches
      if pattern:find("/") then
        -- if pattern contains "/", match against the fullpath rather than basename
        matches = path:match(pat)
      else
        matches = basename:match(pat)
      end
      if matches then
        resolved_filetype = dispatch(ft, clue, matches)
        if resolved_filetype then return resolved_filetype end
      end
    end
  end
end

M.strategy = {
  filename = function(clue)
    if clue.path then
      local path = clue.path
      local basename = vim.fn.fnamemodify(path, ":t")
      local ext = vim.fn.fnamemodify(path, ":e")
      -- First check for the simple case where the full path exists as a key
      resolved_filetype = dispatch(M.definition.filename[path], clue)
      if resolved_filetype then return resolved_filetype end

      -- Next check against just the file name
      resolved_filetype = dispatch(M.definition.filename[basename], clue)
      if resolved_filetype then return resolved_filetype end
    end
  end,
  filename_pattern = function(clue)
    return match_filename_pattern(clue, M.definition.filename_pattern)
  end,
  filename_pattern_low_priority = function(clue)
    return match_filename_pattern(clue, M.definition.filename_pattern_low_priority)
  end,
  extension = function(clue)
    if clue.path then
      local ext = vim.fn.fnamemodify(clue.path, ":e")
      resolved_filetype = dispatch(M.definition.extension[ext], clue)
      if resolved_filetype then return resolved_filetype end
    end
  end,
  firstline = function(clue)
    if clue.getline then
      local firstline = clue.getline(1)
      if firstline then
        for _, item in ipairs_reverse(M.definition.firstline) do
          local pattern, ft = unpack(item)
          local matches = firstline:match(pattern)
          if matches then
            return dispatch(ft, clue, matches)
          end
        end
      end
    end
  end,
  scripts = function(clue)
    -- TODO
    -- parse shebang?
    -- should we use "shebang" instead of "firstline"...?
  end,
  scripts_dot_vim = wrap_legacy_side_effectful_filetype_detector(function()
    api.nvim_command'runtime! scripts.vim'
  end)                         
}

function M.detect_main(clue)
  local ft

  ft = M.strategy.filename(clue)
  if ft then return ft end

  ft = M.strategy.filename_pattern(clue)
  if ft then return ft end

  ft = M.strategy.extension(clue)
  if ft then return ft end

  ft = M.strategy.filename_pattern_low_priority(clue)
  if ft then return ft end

  ft = M.strategy.firstline(clue)
  if ft then return ft end

  ft = M.strategy.scripts(clue)
  if ft then return ft end

  ft = M.strategy.scripts_dot_vim(clue)
  if ft then return ft end
end

return M
