local a = vim.api
local F = vim.F
local lsp = vim.lsp

local config = {
  defaults = {
    autostart = true,
    root_markers = { '.git', '.hg', '.svn' },
  },
}

---@private
local function validate(opts)
  if not opts.filetypes or #opts.filetypes == 0 then
    return false, 'missing filetypes'
  end

  if not opts.cmd or #opts.cmd == 0 then
    return false, 'missing cmd'
  end

  if opts.root_markers and opts.root_dir then
    return false, 'only one of root_markers and root_dir should be specified'
  end

  return true
end

return function(opts)
  if not opts then
    -- Return current config
    return vim.deepcopy(config)
  end

  for k, v in pairs(opts.defaults or {}) do
    config.defaults[k] = v
  end

  if not opts.servers then
    return
  end

  a.nvim_create_augroup('nvim_lsp', { clear = false })

  if not config.servers then
    config.servers = {}
  end

  for k, v in pairs(opts.servers) do
    local ok, err = validate(v)
    if not ok then
      a.nvim_echo({ { string.format('Configuration for server %s is invalid: %s', k, err), 'WarningMsg' } }, true, {})
    else
      config.servers[k] = v
      a.nvim_create_autocmd('FileType', {
        group = 'nvim_lsp',
        pattern = v.filetypes,
        callback = function(args)
          local autostart = F.if_nil(v.autostart, config.defaults.autostart)
          if type(autostart) == 'function' then
            local fname = a.nvim_buf_get_name(args.buf)
            autostart = autostart(fname, args.buf)
          end

          if type(autostart) == 'boolean' and not autostart then
            return
          end

          lsp.buf_start(args.buf, k)
        end,
      })
    end
  end
end
