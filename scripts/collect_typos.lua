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

--- MIME-decode if python3 is available, else returns the input unchanged.
local function mime_decode(encoded)
  local has_python = vim.system({ 'python3', '--version' }, { text = true }):wait()
  if has_python.code ~= 0 then
    return encoded
  end

  local pycode = string.format(
    vim.text.indent(
      0,
      [[
      import sys
      from email.header import decode_header
      inp = %q
      parts = []
      for txt, cs in decode_header(inp):
          if isinstance(txt, bytes):
              try:
                  parts.append(txt.decode(cs or "utf-8", errors="replace"))
              except Exception:
                  parts.append(txt.decode("utf-8", errors="replace"))
          else:
              parts.append(txt)
      sys.stdout.write("".join(parts))
      ]]
    ),
    encoded
  )

  local result = vim.system({ 'python3', '-c', pycode }, { text = true }):wait()

  if result.code ~= 0 or not result.stdout then
    return encoded
  end

  -- Trim trailing newline Python prints only if program prints it
  return vim.trim(result.stdout)
end

local function get_commit_msg(close_pr_lines, co_author_lines)
  return ('docs: misc\n\n%s\n\n%s\n'):format(
    table.concat(close_pr_lines, '\n'),
    table.concat(co_author_lines, '\n')
  )
end

local function get_fail_msg(msg, pr_number, close_pr_lines, co_author_lines)
  return ('%s %s\n\nPending commit message:\n%s'):format(
    msg,
    pr_number or '',
    get_commit_msg(close_pr_lines, co_author_lines)
  )
end

local function main()
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
    print(('PR #%s'):format(pr_number))
    local patch_file = run_die(
      { 'gh', 'pr', 'diff', tostring(pr_number), '--patch' },
      get_fail_msg('Failed to get patch for PR', pr_number, close_pr_lines, co_author_lines)
    )
    -- Using --3way allows skipping changes already included in a previous commit.
    -- If there are conflicts, it will fail and need manual conflict resolution.
    if run({ 'git', 'apply', '--index', '--3way', '-' }, patch_file) then
      table.insert(close_pr_lines, ('Close #%d'):format(pr_number))
      for author in patch_file:gmatch('\nFrom: (.- <.->)\n') do
        local co_author_line = ('Co-authored-by: %s'):format(mime_decode(author))
        if not vim.list_contains(co_author_lines, co_author_line) then
          table.insert(co_author_lines, co_author_line)
        end
      end
      for author in patch_file:gmatch('\nCo%-authored%-by: (.- <.->)\n') do
        local co_author_line = ('Co-authored-by: %s'):format(mime_decode(author))
        if not vim.list_contains(co_author_lines, co_author_line) then
          table.insert(co_author_lines, co_author_line)
        end
      end
    else
      print(
        get_fail_msg('Failed to apply patch for PR', pr_number, close_pr_lines, co_author_lines)
      )
    end
  end

  local msg = get_commit_msg(close_pr_lines, co_author_lines)
  print(
    run_die(
      { 'git', 'commit', '--file', '-' },
      get_fail_msg('Failed to create commit', nil, close_pr_lines, co_author_lines),
      msg
    )
  )
end

main()
