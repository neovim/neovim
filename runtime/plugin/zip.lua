if vim.g.loaded_nvim_zip_plugin ~= nil or vim.fn.exists('#zip') == 1 then
  return
end
vim.g.loaded_nvim_zip_plugin = true

local api = vim.api

-- Extension aliases inherited from the legacy plugin:
-- https://github.com/neovim/neovim/blob/7ba955fe079d4aa2554fea8e7235651fafd40efb/runtime/plugin/zipPlugin.vim#L34-L35
---@type string[]
local extensions = {
  'aar',
  'apk',
  'cbz',
  'celzip',
  'crtx',
  'docm',
  'docx',
  'dotm',
  'dotx',
  'ear',
  'epub',
  'gcsx',
  'glox',
  'gqsx',
  'ja',
  'jar',
  'kmz',
  'odb',
  'odc',
  'odf',
  'odg',
  'odi',
  'odm',
  'odp',
  'ods',
  'odt',
  'otc',
  'otf',
  'otg',
  'oth',
  'oti',
  'otp',
  'ots',
  'ott',
  'oxt',
  'pkpass',
  'potm',
  'potx',
  'ppam',
  'ppsm',
  'ppsx',
  'pptm',
  'pptx',
  'sldx',
  'thmx',
  'vdw',
  'war',
  'whl',
  'wsz',
  'xap',
  'xlam',
  'xlsb',
  'xlsm',
  'xlsx',
  'xltm',
  'xltx',
  'xpi',
  'zip',
}
---@type string[]
local archive_patterns = {}
for _, extension in ipairs(extensions) do
  archive_patterns[#archive_patterns + 1] = ('*.%s'):format(extension)
end
vim.keymap.set('n', '<Plug>(nvim-zip-extract)', function()
  require('nvim.zip')._extract()
end, { silent = true, desc = 'Extract zip archive entry' })

local group = api.nvim_create_augroup('nvim.zip', { clear = true })

---@return boolean
local function legacy_loaded()
  return vim.fn.exists('#zip') == 1
end

api.nvim_create_autocmd('BufReadCmd', {
  group = group,
  pattern = 'zip://*',
  desc = 'Read zip archive entry',
  callback = function(ev)
    if legacy_loaded() then
      return true
    end
    require('nvim.zip').read(ev.buf, ev.match)
  end,
})

api.nvim_create_autocmd('BufReadCmd', {
  group = group,
  pattern = archive_patterns,
  desc = 'Browse zip archives',
  callback = function(ev)
    if legacy_loaded() then
      return true
    end
    if ev.match:match('^%a[%w+.-]*://') then
      return
    end
    require('nvim.zip').browse(ev.buf, ev.match)
  end,
})
