return setmetatable({}, {
    __index = function(t, key)
      local mode = string.sub(key, 1, 1)
      local noremap = string.find(key, 'noremap')
      t[key] = function(lhs, rhs, args)
        local opts = {noremap=noremap}
        if args then
          for _, arg in pairs(args) do
            opts[arg] = true
          end
        end
        vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
      end
      return t[key]
    end
  })
