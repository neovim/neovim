if vim.g.loaded_undotree_plugin ~= nil then
  return
end
vim.g.loaded_undotree_plugin = true

local function usage()
  vim.notify(
    'Usage: Undotree [mods][size]Undotree [winid|buffer] [title=title]',
    vim.log.levels.ERROR
  )
end

--- @param params vim.api.keyset.create_user_command.command_args
--- @return table|nil
local function get_args(params)
  local nargs = tonumber(params.nargs)
  if nargs and nargs > 2 then
    return usage()
  end

  local title = params.args:match('title=(%w+)')
  local bufnr = params.args:match('bufnr=(%d+)')
  local winid = params.args:match('winid=(%d+)')

  --- @type vim.undotree.opts
  local opts = {
    title = title,
    bufnr = bufnr and tonumber(bufnr),
    winid = winid and tonumber(winid),
  }

  if #params.mods == 0 or params.count ~= -1 then
    local modifiers = params.mods
    local count = params.count ~= 0 and params.count or 30
    if #modifiers > 0 then
      opts.command = ('%s %dnew'):format(modifiers or 'sp', count)
    else
      opts.command = ('%dvnew'):format(count)
    end
  end

  if not #params.args then
    return opts
  end

  local buffer = params.args
  buffer = buffer:gsub('title=%w+', '')
  buffer = buffer:gsub('bufnr=%d+', '')
  buffer = buffer:gsub('winid=%d+', '')
  buffer = vim.trim(buffer)
  if #buffer == 0 then
    return opts
  end

  vim.cmd.edit(buffer)
  return opts
end

-- usage: '[mods][count]Undotree [buffer] [title=title]' (e.g: vert aboveleft 20Undotree 10 / belowright Undotree myfile)
vim.api.nvim_create_user_command('Undotree', function(params)
  local args = get_args(params)
  if not args then
    return
  end
  vim.schedule(function()
    require('undotree').open(args)
  end)
end, {
  nargs = '*',
  count = true,
  bang = true,
  complete = function(arglead, cmdline)
    --- @param buf number
    local loaded_bufs = vim.tbl_filter(function(buf)
      return vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) ~= ''
    end, vim.api.nvim_list_bufs())

    if arglead == 'title=' then
      return
    end
    if arglead == 'bufnr=' then
      return vim.tbl_map(tostring, loaded_bufs)
    end
    if arglead == 'winid=' then
      return vim.tbl_map(tostring, vim.api.nvim_tabpage_list_wins(0))
    end
    local args_complete = {
      cmdline:match('title=(%w*)') == nil and 'title=',
    }
    if not cmdline:match('bufnr=(%d*)') and not cmdline:match('winid=(%d*)') then
      table.insert(args_complete, 'bufnr=')
      table.insert(args_complete, 'winid=')
    end
    --- @param buf number
    local buf_complete = vim.tbl_map(function(buf)
      return vim.api.nvim_buf_get_name(buf)
    end, loaded_bufs)
    return vim.list_extend(args_complete, buf_complete)
  end,
})
