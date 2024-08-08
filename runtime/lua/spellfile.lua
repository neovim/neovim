local M = {}

M.config = {
  url = 'https://ftp.nluug.nl/pub/vim/runtime/spell',
  encoding = vim.o.encoding,
  rtp = vim.opt.rtp:get(),
}

M.done = {}

M.setup = function(opts)
  M.done = {}
  M.config = vim.tbl_extend('force', M.config, opts or {})
end

M.directory_choices = function()
  local options = {}
  for _, dir in ipairs(M.config.rtp) do
    local spell = dir .. '/spell'
    if vim.fn.isdirectory(spell) == 1 then
      table.insert(options, spell)
    end
  end
  return options
end

M.choose_directory = function()
  local options = M.directory_choices()
  if #options == 0 then
    vim.notify('No spell directory found in the runtimepath')
    return
  elseif #options == 1 then
    return options[1]
  end

  local prompt = {}
  for idx, dir in pairs(options) do
    table.insert(prompt, string.format('%d: %s', idx, dir))
  end
  local choice = vim.ui.inputlist(prompt)
  if choice <= 0 or choice > #options then
    return
  end

  return options[choice]
end

M.exists = function(file_name)
  local is_file = function(pth)
    local stat = vim.uv.fs_stat(pth)
    return stat ~= nil and stat.type ~= nil and stat.type == 'file'
  end

  for _, dir in pairs(M.directory_choices()) do
    if is_file(dir .. '/' .. file_name) then
      return true
    end
  end
  return false
end

M.parse = function(lang)
  local code = string.sub(lang:lower(), 1, 2)

  local encoding = vim.bo.fileencoding
  if encoding == '' then
    encoding = M.config.encoding
  end
  if encoding == 'iso-8859-1' then
    encoding = 'latin1'
  end

  local files = {
    string.format('%s.%s.spl', code, encoding),
    string.format('%s.%s.sug', code, encoding),
  }
  local missing = {}
  for _, name in ipairs(files) do
    if not M.exists(name) then
      table.insert(missing, name)
    end
  end

  return {
    files = missing,
    key = string.format('%s.%s', code, encoding),
    lang = code,
    encoding = encoding,
  }
end

M.download = function(data)
  local prompt =
    string.format('No spell file found for %s in %s. Download it? [y/N] ', data.lang, data.encoding)
  if vim.fn.input(prompt):lower() ~= 'y' then
    return
  end
  local dir = M.choose_directory()
  if dir == nil then
    return
  end

  for _, name in ipairs(data.files) do
    local url = M.config.url .. '/' .. name
    local pth = dir .. '/' .. name
    local cmd = ''
    if vim.fn.executable('curl') == 1 then
      cmd = string.format('curl -fLo %s %s', pth, url)
    else
      vim.notify('No curl found. You need curl installed to dowloand spell files.')
      return
    end

    vim.notify(string.format('\nDownloading %s...', name))
    vim.system(cmd)
  end
end

M.load_file = function(lang)
  local data = M.parse(lang)
  if #data.files == 0 then
    return
  end
  for key, _ in pairs(M.done) do
    if key == data.key then
      vim.notify('Already tried this language before: ' .. lang:lower())
      return
    end
  end

  M.download(data)
  M.done[data.key] = true
end

return M
