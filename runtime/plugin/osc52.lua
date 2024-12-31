local tty = false
for _, ui in ipairs(vim.api.nvim_list_uis()) do
  if ui.chan == 1 and ui.stdout_tty then
    tty = true
    break
  end
end

-- Do not query when any of the following is true:
--   * TUI is not attached
--   * OSC 52 support is explicitly disabled via g:termfeatures
--   * Using a badly behaved terminal
if
  not tty
  or (vim.g.termfeatures ~= nil and vim.g.termfeatures.osc52 == false)
  or vim.env.TERM_PROGRAM == 'Apple_Terminal'
then
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

  local termfeatures = vim.g.termfeatures or {}
  termfeatures.osc52 = true
  vim.g.termfeatures = termfeatures
end)
