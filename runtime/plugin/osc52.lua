local tty = vim.iter(vim.api.nvim_list_uis()):any(function(ui)
  return ui.chan == 1 and ui.stdout_tty
end)

if
  not tty
  or vim.g.clipboard ~= nil
  or vim.o.clipboard ~= ''
  or not os.getenv('SSH_TTY')
  or os.getenv('TMUX')
then
  return
end

require('vim.termcap').query('Ms', function(cap, seq)
  assert(cap == 'Ms')

  -- If the terminal reports a sequence other than OSC 52 for the Ms capability
  -- then ignore it. We only support OSC 52 (for now)
  if not seq:match('^\027%]52') then
    return
  end

  local osc52 = require('vim.ui.clipboard.osc52')

  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = osc52.copy('+'),
      ['*'] = osc52.copy('*'),
    },
    paste = {
      ['+'] = osc52.paste('+'),
      ['*'] = osc52.paste('*'),
    },
  }
end)
