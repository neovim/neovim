--- @class (private) TermFeatures
--- @field osc52 boolean?

local id = vim.api.nvim_create_augroup('nvim.osc52', { clear = true })
vim.api.nvim_create_autocmd('UIEnter', {
  group = id,
  desc = 'Enable OSC 52 feature flag if a supporting TUI is attached',
  callback = function()
    -- If OSC 52 is explicitly disabled by the user then don't do anything
    if vim.g.termfeatures ~= nil and vim.g.termfeatures.osc52 == false then
      return
    end

    local tty = false
    for _, ui in ipairs(vim.api.nvim_list_uis()) do
      if ui.stdout_tty then
        tty = true
        break
      end
    end

    -- Do not query when no TUI is attached
    if not tty then
      return
    end

    -- Clear existing OSC 52 value, since this is a new UI we might be attached to a different
    -- terminal
    do
      local termfeatures = vim.g.termfeatures or {} ---@type TermFeatures
      termfeatures.osc52 = nil
      vim.g.termfeatures = termfeatures
    end

    -- Check DA1 first
    vim.api.nvim_create_autocmd('TermResponse', {
      group = id,
      nested = true,
      callback = function(args)
        local resp = args.data.sequence ---@type string
        local params = resp:match('^\027%[%?([%d;]+)c$')
        if params then
          -- Check termfeatures again, it may have changed between the query and response.
          if vim.g.termfeatures ~= nil and vim.g.termfeatures.osc52 ~= nil then
            return true
          end

          for param in string.gmatch(params, '%d+') do
            if param == '52' then
              local termfeatures = vim.g.termfeatures or {} ---@type TermFeatures
              termfeatures.osc52 = true
              vim.g.termfeatures = termfeatures
              return true
            end
          end

          -- Do not use XTGETTCAP on terminals that echo unknown sequences
          if vim.env.TERM_PROGRAM == 'Apple_Terminal' then
            return true
          end

          -- Fallback to XTGETTCAP
          require('vim.termcap').query('Ms', function(cap, found, seq)
            if not found then
              return
            end

            -- Check termfeatures again, it may have changed between the query and response.
            if vim.g.termfeatures ~= nil and vim.g.termfeatures.osc52 ~= nil then
              return
            end

            assert(cap == 'Ms')

            -- If the terminal reports a sequence other than OSC 52 for the Ms capability
            -- then ignore it. We only support OSC 52 (for now)
            if not seq or not seq:match('^\027%]52') then
              return
            end

            local termfeatures = vim.g.termfeatures or {} ---@type TermFeatures
            termfeatures.osc52 = true
            vim.g.termfeatures = termfeatures
          end)

          return true
        end
      end,
    })

    -- Write DA1 request
    io.stdout:write('\027[c')
  end,
})

vim.api.nvim_create_autocmd('UILeave', {
  group = id,
  desc = 'Reset OSC 52 feature flag if no TUIs are attached',
  callback = function()
    -- If OSC 52 is explicitly disabled by the user then don't do anything
    if vim.g.termfeatures ~= nil and vim.g.termfeatures.osc52 == false then
      return
    end

    -- If no TUI is connected to Nvim's stdout then reset the OSC 52 term features flag
    for _, ui in ipairs(vim.api.nvim_list_uis()) do
      if ui.stdout_tty then
        return
      end
    end

    local termfeatures = vim.g.termfeatures or {} ---@type TermFeatures
    termfeatures.osc52 = nil
    vim.g.termfeatures = termfeatures
  end,
})
