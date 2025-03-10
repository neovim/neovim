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

    -- Do not query when any of the following is true:
    --   * No TUI is attached
    --   * Using a badly behaved terminal
    if not tty or vim.env.TERM_PROGRAM == 'Apple_Terminal' then
      local termfeatures = vim.g.termfeatures or {} ---@type TermFeatures
      termfeatures.osc52 = nil
      vim.g.termfeatures = termfeatures
      return
    end

    require('vim.termcap').query('Ms', function(cap, found, seq)
      if not found then
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
