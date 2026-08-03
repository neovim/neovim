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

--- @return boolean Whether an implementation that needs the backend is handling archives.
local function check_active()
  health.start('nvim.zip: active implementation')

  local legacy = vim.fn.exists('#zip') == 1
  local builtin = vim.fn.exists('#nvim.zip') == 1

  if legacy then
    health.info('`old-zip` is loaded, so it handles archives instead of zip.lua')
    health.info('zip.lua defers to it while it is loaded')
    -- `old-zip` shells out to the same backend.
    return true
  end

  if not builtin then
    if vim.g.loaded_nvim_zip_plugin ~= nil then
      health.info('Disabled (`g:loaded_nvim_zip_plugin` is set).')
    else
      health.warn('No zip plugin is active')
    end
    return false
  end

  health.ok('zip.lua is active')
  return true
end

function M.check()
  -- Report the backend only when something is actually going to run it, so that disabling the
  -- plugin does not report a missing `unzip` as an error.
  if check_active() then
    check_backend()
  end
end

return M
