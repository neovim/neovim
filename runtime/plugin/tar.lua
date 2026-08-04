if vim.g.loaded_nvim_tar_plugin ~= nil or vim.fn.exists('#tar') == 1 then
  return
end
vim.g.loaded_nvim_tar_plugin = true

local api = vim.api

---@type string[]
local archive_patterns = {
  '*.cbt',
  '*.lrp',
  '*.tar',
  '*.tar.Z',
  '*.tar.bz2',
  '*.tar.bz3',
  '*.tar.gz',
  '*.tar.lz4',
  '*.tar.lzma',
  '*.tar.xz',
  '*.tar.zst',
  '*.tbz',
  '*.tgz',
  '*.tlz4',
  '*.txz',
  '*.tzst',
}

local group = api.nvim_create_augroup('nvim.tar', { clear = true })

---@return boolean
local function legacy_loaded()
  return vim.fn.exists('#tar') == 1
end

api.nvim_create_autocmd('BufReadCmd', {
  group = group,
  pattern = 'nvim-tar://*',
  desc = 'Read tar archive entry',
  callback = function(ev)
    if legacy_loaded() then
      return true
    end
    require('nvim.tar').read(ev.buf, ev.match)
  end,
})

api.nvim_create_autocmd('BufReadCmd', {
  group = group,
  pattern = archive_patterns,
  desc = 'Browse tar archives',
  callback = function(ev)
    if legacy_loaded() then
      return true
    end
    if ev.match:match('^%a[%w+.-]*://') then
      return
    end
    require('nvim.tar').browse(ev.buf, ev.match)
  end,
})
