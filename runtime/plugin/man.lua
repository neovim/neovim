if vim.g.loaded_man ~= nil then
  return
end
vim.g.loaded_man = true

vim.api.nvim_create_user_command('Man', function(params)
  local man = require('man')
  if params.bang then
    man.init_pager()
  else
    local ok, err = pcall(man.open_page, params.count, params.smods, params.fargs)
    if not ok then
      vim.notify(man.errormsg or err, vim.log.levels.ERROR)
    end
  end
end, {
  bang = true,
  bar = true,
  addr = 'other',
  nargs = '*',
  complete = function(...)
    return require('man').man_complete(...)
  end,
})

local augroup = vim.api.nvim_create_augroup('man', {})

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = augroup,
  pattern = 'man://*',
  callback = function(params)
    require('man').read_page(vim.fn.matchstr(params.match, 'man://\\zs.*'))
  end,
})

if (vim.g.man_redraw_resized or 1) == 1 then
  local resize_timer, resized_winids

  local function redraw_manpages()
    if resized_winids == nil then
      return
    end
    local current_winid = vim.api.nvim_get_current_win()
    for _, winid in ipairs(resized_winids) do
      local buf = vim.api.nvim_win_get_buf(winid)
      if
        vim.api.nvim_win_is_valid(winid)
        and vim.api.nvim_buf_get_option(buf, 'filetype') == 'man'
        and vim.api.nvim_buf_get_var(buf, 'pager') == false
      then
        local bufname = vim.api.nvim_buf_get_name(buf)
        local ref = vim.fn.matchstr(bufname, 'man://\\zs.*')
        if ref ~= '' then
          vim.api.nvim_set_current_win(winid)
          local winview = vim.fn.winsaveview()
          pcall(require('man').read_page, ref)
          vim.fn.winrestview(winview)
        end
      end
    end
    vim.api.nvim_set_current_win(current_winid)
    resize_timer, resized_winids = nil, nil
  end

  vim.api.nvim_create_autocmd('WinResized', {
    group = augroup,
    callback = function()
      if resize_timer ~= nil then
        resize_timer:stop()
      end
      resized_winids = vim.v.event.windows
      resize_timer = vim.defer_fn(redraw_manpages, vim.g.man_redraw_debounce_ms or 1000)
    end,
  })
end
