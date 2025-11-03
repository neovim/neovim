#!/usr/bin/env -S nvim -l

local function die(msg)
  print(msg)
  vim.cmd('cquit 1')
end

--- Executes and returns the output of `cmd`, or nil on failure.
--- if die_on_fail is true, process dies with die_msg on failure
--- @param cmd string[]
--- @param die_on_fail boolean
--- @param die_msg string
--- @param stdin string?
---
--- @return string?
local function _run(cmd, die_on_fail, die_msg, stdin)
  local rv = vim.system(cmd, { stdin = stdin }):wait()
  if rv.code ~= 0 then
    if rv.stdout:len() > 0 then
      print(rv.stdout)
    end
    if rv.stderr:len() > 0 then
      print(rv.stderr)
    end
    if die_on_fail then
      die(die_msg)
    end
    return nil
  end
  return rv.stdout
end

--- Run a command, return nil on failure
--- @param cmd string[]
--- @param stdin string?
---
--- @return string?
local function run(cmd, stdin)
  return _run(cmd, false, '', stdin)
end

--- Run a command, die on failure with err_msg
--- @param cmd string[]
--- @param err_msg string
--- @param stdin string?
---
--- @return string
local function run_die(cmd, err_msg, stdin)
  return assert(_run(cmd, true, err_msg, stdin))
end

do
  local pr_list = vim.json.decode(
    run_die(
      { 'gh', 'pr', 'list', '--label', 'typo', '--json', 'number' },
      'Failed to get list of typo PRs'
    )
  )
  --- @type integer[]
  local pr_numbers = vim
    .iter(pr_list)
    :map(function(pr)
      return pr.number
    end)
    :totable()
  table.sort(pr_numbers)

  local close_pr_lines = {}
  local co_author_lines = {}
  for _, pr_number in ipairs(pr_numbers) do
    local patch_file = run_die(
      { 'gh', 'pr', 'diff', tostring(pr_number), '--patch' },
      'Failed to get patch of PR ' .. pr_number
    )
    if run({ 'git', 'apply', '--index', '-' }, patch_file) then
      table.insert(close_pr_lines, ('Close #%d'):format(pr_number))
      for author in patch_file:gmatch('\nFrom: (.- <.->)\n') do
        local co_author_line = ('Co-authored-by: %s'):format(author)
        if not vim.list_contains(co_author_lines, co_author_line) then
          table.insert(co_author_lines, co_author_line)
        end
      end
      for author in patch_file:gmatch('\nCo%-authored%-by: (.- <.->)\n') do
        local co_author_line = ('Co-authored-by: %s'):format(author)
        if not vim.list_contains(co_author_lines, co_author_line) then
          table.insert(co_author_lines, co_author_line)
        end
      end
    else
      print('Failed to apply patch of PR ' .. pr_number)
    end
  end

  local msg = ('docs: small fixes\n\n%s\n\n%s\n'):format(
    table.concat(close_pr_lines, '\n'),
    table.concat(co_author_lines, '\n')
  )
  print(run_die({ 'git', 'commit', '--file', '-' }, 'Failed to create commit', msg))
end
