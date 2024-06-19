local M = {}

if vim.g.spellfile_URL == nil then
  -- Always use https:// because it's secure. The certificate is for nluug.nl,
  -- thus we can't use the alias ftp.vim.org here.
  vim.g.spellfile_URL = 'https://ftp.nluug.nl/pub/vim/runtime/spell'
end
local spellfile_URL ---@type string

---@return string[]
local function available_dirs()
  local dirs = vim
    .iter(vim.fn.globpath(vim.o.rtp, 'spell', nil, true))
    :filter(function(dir)
      -- TODO: does this check permissions correctly in Windows? Probably no
      return vim.fn.filewritable(dir) == 2
    end)
    :totable()
  return dirs
end

---@param dir string
---@param lang string
---@param encoding string
local function download_sug(dir, lang, encoding)
  local sug_filename = ('%s.%s.sug'):format(lang, encoding)
  local sug_url = ('%s/%s'):format(spellfile_URL, sug_filename)
  vim.notify(('Downloading %s ...'):format(sug_filename), vim.log.levels.INFO)
  local as = ('%s/%s'):format(dir, sug_filename)
  vim.net.download(sug_url, {
    as = as,
    on_exit = vim.schedule_wrap(function(err)
      if err then
        return vim.notify(err, vim.log.levels.ERROR)
      end
      local sug = io.open(as)
      if not sug then
        return vim.notify(("Couldn't open file %s"):format(as), vim.log.levels.ERROR)
      end
      local sug_first_line = sug:read()
      sug:close()
      if not sug_first_line:find('VIMsug') then
        return vim.notify('Download failed', vim.log.levels.ERROR)
      end
      vim.notify(('%s downloaded'):format(as), vim.log.levels.INFO)
    end),
  })
end

--- lang -> true
---@type table<string, true>
local done = {}

-- TODO: SpellFileMissing expects a sync download. Using an async one needs `:set spell` again once the download has finished (and gives an error)
-- TODO: rewrite \runtime\doc\spell.txt *spell-SpellFileMissing* *spellfile.vim* (?)
-- TODO: rewrite src\nvim\spell.c:1615 (#3027) to use this function instead
---@param lang string
function M.download_spell(lang)
  -- Check for sandbox/modeline. #11359
  local ok = pcall(vim.cmd('!'))
  if not ok then
    error('Cannot download spellfile in sandbox/modeline. Try ":set spell" from the cmdline.')
  end

  lang = lang:lower()

  if spellfile_URL ~= vim.g.spellfile_URL then
    done = {}
    spellfile_URL = vim.g.spellfile_URL
  end

  if done[lang] then
    if vim.o.verbose ~= 0 then
      vim.notify('Tried this language/encoding before.', vim.log.levels.INFO)
    end
    return
  end
  done[lang] = true

  local dirs = available_dirs()
  if #dirs == 0 then
    local dir_to_create = vim.fn.stdpath('data') .. '/site/spell'
    if vim.o.verbose ~= 0 or dir_to_create ~= '' then
      vim.notify('No (writable) spell directory found.', vim.log.levels.INFO)
    end
    vim.fn.mkdir(dir_to_create, 'p')
    dirs = available_dirs()

    if #dirs == 0 then
      vim.notify(('Failed to create: %s'):format(dir_to_create), vim.log.levels.INFO)
    else
      vim.notify(('Created %s'):format(dir_to_create), vim.log.levels.INFO)
    end
  end

  if
    vim.fn.confirm(
      ('No spell file for "%s" in %s\nDownload it?'):format(lang, vim.o.encoding),
      '&Yes\n&No',
      2
    ) ~= 1
  then
    return
  end

  local choice ---@type integer
  if #dirs == 1 then
    choice = 1
  else
    local msg = 'In which directory do you want to write the file:'
      .. vim
        .iter(ipairs(dirs))
        :map(function(i, dir)
          return ('\n%d. %s'):format(i, dir)
        end)
        :join('')
    local choices = '&Cancel'
      .. vim
        .iter(ipairs(dirs))
        :map(function(i, _dir)
          return ('\n&%d'):format(i)
        end)
        :join('')
    choice = vim.fn.confirm(msg, choices) - 1
  end

  if choice < 1 then
    return
  end

  -- TODO: normalize `as`?
  local dir = dirs[choice]

  local encoding = vim.o.encoding == 'iso-8859-15' and 'latin1' or vim.o.encoding
  local spell_filename = ('%s.%s.spl'):format(lang, encoding)
  local spell_url = ('%s/%s'):format(spellfile_URL, spell_filename)
  vim.notify(('Downloading %s ...'):format(spell_filename), vim.log.levels.INFO)
  local as = ('%s/%s'):format(dir, spell_filename)
  vim.net.download(spell_url, {
    as = as,
    on_exit = vim.schedule_wrap(function(err)
      if err then
        return vim.notify(err, vim.log.levels.ERROR)
      end
      local spell = io.open(as)
      if not spell then
        return vim.notify(("Couldn't open file %s"):format(as), vim.log.levels.ERROR)
      end
      local spell_first_line = spell:read()
      spell:close()
      if spell_first_line:find('VIMspell') then
        vim.notify(('%s downloaded'):format(as), vim.log.levels.INFO)
        return download_sug(dir, lang, encoding)
      end

      encoding = 'ascii'
      spell_filename = ('%s.%s.spl'):format(lang, encoding)
      as = ('%s/%s'):format(dir, spell_filename)
      vim.notify(('Could not find it, trying %s ...'):format(spell_filename), vim.log.levels.WARN)
      spell_url = ('%s/%s'):format(spellfile_URL, spell_filename)
      vim.net.download(spell_url, {
        as = as,
        on_exit = vim.schedule_wrap(function(err2)
          if err2 then
            return vim.notify(err2, vim.log.levels.ERROR)
          end
          spell = io.open(as)
          if not spell then
            return vim.notify(("Couldn't open file %s"):format(as), vim.log.levels.ERROR)
          end
          spell_first_line = spell:read()
          spell:close()
          if spell_first_line:find('VIMspell') then
            vim.notify(('%s downloaded'):format(as), vim.log.levels.INFO)
            return download_sug(dir, lang, encoding)
          end
          vim.notify('Download failed', vim.log.levels.ERROR)
        end),
      })
    end),
  })
end

return M
