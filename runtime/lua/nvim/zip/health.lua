local M = {}

local health = vim.health

local function check_backend()
  health.start('nvim.zip: backend')

  local exe = vim.fn.exepath('unzip')
  if exe == '' then
    health.error('`unzip` executable not found', {
      'Install Info-ZIP `unzip` to browse and read archives.',
      'Or `:packadd old-zip` to use the legacy plugin.',
    })
    return
  end

  local out = vim.system({ exe, '-v' }, { text = true }):wait()
  local version = vim.split(out.stdout or '', '\n')[1] or ''
  health.ok(('`unzip` found: %s'):format(exe))
  if version ~= '' then
    health.info(version)
  end
end

local function check_active()
  health.start('nvim.zip: active implementation')

  local legacy = vim.fn.exists('#zip') == 1
  local builtin = vim.fn.exists('#nvim.zip') == 1

  if legacy then
    health.info('`old-zip` is loaded, so it handles archives instead of zip.lua')
    health.info('zip.lua yields to it and removes its own autocommands')
    return
  end

  if not builtin then
    if vim.g.loaded_nvim_zip_plugin ~= nil then
      health.warn('zip.lua is disabled by `g:loaded_nvim_zip_plugin`', {
        'Unset it before startup to enable the builtin zip plugin.',
      })
    else
      health.warn('No zip plugin is active')
    end
    return
  end

  health.ok('zip.lua is active')
end

function M.check()
  check_backend()
  check_active()
end

return M
