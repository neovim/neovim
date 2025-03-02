-- use treesitter over syntax
vim.treesitter.start()

vim.bo.omnifunc = 'v:lua.vim.lua_omnifunc'

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
    .. '\n call v:lua.vim.treesitter.stop() \n setl omnifunc<'

if _G._nvim_loaded_ftplugin_lua then
  return
end
_G._nvim_loaded_ftplugin_lua = true

do
  -- Ideally we should just call complete() inside omnifunc, though there are
  -- some bugs, so fake the two-step dance for now.
  local matches --- @type any[]

  --- Omnifunc for completing Lua values from the runtime Lua interpreter,
  --- similar to the builtin completion for the `:lua` command.
  ---
  --- Activate using `set omnifunc=v:lua.vim.lua_omnifunc` in a Lua buffer.
  --- @param find_start 1|0
  function vim.lua_omnifunc(find_start, _)
    if find_start == 1 then
      local line = vim.api.nvim_get_current_line()
      local prefix = string.sub(line, 1, vim.api.nvim_win_get_cursor(0)[2])
      local pos
      matches, pos = vim._expand_pat(prefix)
      return (#matches > 0 and pos) or -1
    else
      return matches
    end
  end
end
