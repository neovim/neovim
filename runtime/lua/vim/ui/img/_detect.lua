local terminal = require('vim.img._terminal')

local TERM_QUERY = {
  -- Request device attributes (DA2).
  --
  -- It typically returns information about the terminal type and supported features.
  --
  -- Response format is typically something like '\033[>...;...;...c'
  DEVICE_ATTRIBUTES = terminal.code.ESC .. '[>q',

  -- Request device status report (DSR), checking if terminal is okay.
  --
  -- Response indicates its current state.
  DEVICE_STATUS_REPORT = terminal.code.ESC .. '[5n',
}

local TERM_RESPONSE = {
  -- Indicates that the terminal is functioning normally (no error).
  --
  -- 0 means 'OK'; other values indicate different states or errors.
  OK = terminal.code.ESC .. '[0n',
}

---Detects supported graphics of the terminal.
---@return {graphics:'iterm2'|'kitty'|'sixel'|nil, tmux:boolean, broken_sixel_cursor_placement:boolean}
return function()
  local results = { graphics = nil, tmux = false, broken_sixel_cursor_placement = false }

  local term = os.getenv('TERM')
  if term == 'xterm-kitty' or term == 'xterm-ghostty' or term == 'ghostty' then
    results.graphics = 'kitty'
  end

  local term_program = os.getenv('TERM_PROGRAM')
  if term_program == 'vscode' then
    results.graphics = 'iterm2'
    results.broken_sixel_cursor_placement = true
  end

  local _, err = terminal.query({
    query = table.concat({
      TERM_QUERY.DEVICE_ATTRIBUTES,
      TERM_QUERY.DEVICE_STATUS_REPORT,
    }),
    handler = function(buffer)
      local function has(s)
        return string.find(buffer, s, 1, true) ~= nil
      end

      if has('iTerm2') or has('Konsole 2') then
        results.graphics = 'iterm2'
      end

      if has('WezTerm') then
        results.graphics = 'iterm2'
        results.broken_sixel_cursor_placement = true
      end

      if has('kitty') or has('ghostty') then
        results.graphics = 'kitty'
      end

      if has('mlterm') then
        results.graphics = 'sixel'
      end

      if has('XTerm') or has('foot') then
        results.graphics = 'sixel'
        results.broken_sixel_cursor_placement = true
      end

      if has('tmux') then
        results.tmux = true
      end

      -- Check if we have received the ok terminal response
      local start = string.find(buffer, TERM_RESPONSE.OK, 1, true)
      if start then
        return string.sub(buffer, start)
      end
    end,
    timeout = 250,
  })

  assert(not err, err)

  return results
end
