-- Usage:
--    nvim -es +'luafile scripts/lintcommit.lua'

local trace = true

-- Print message
local function p(s)
  vim.cmd('set verbose=1')
  vim.api.nvim_echo({{s, ''}}, false, {})
  vim.cmd('set verbose=0')
end

local function die()
  p('')
  vim.cmd("cquit 1")
end

-- Executes and returns the output of `cmd`, or nil on failure.
--
-- Prints `cmd` if `trace` is enabled.
local function run(cmd, or_die)
  if trace then
    p('run: '..vim.inspect(cmd))
  end
  local rv = vim.trim(vim.fn.system(cmd)) or ''
  if vim.v.shell_error ~= 0 then
    if or_die then
      p(rv)
      die()
    end
    return nil
  end
  return rv
end

local function commit_message_is_ok(commit_message)
  local commit_split = vim.split(commit_message, ":")

  -- Return true if the type is vim-patch since most of the normal rules don't
  -- apply.
  if commit_split[1] == "vim-patch" then
    return true
  end

  -- Check that message isn't too long.
  if commit_message:len() > 80 then
    p([[Commit message is too long, a maximum of 80 characters is allowed.]])
    return false
  end

  -- Return false if no colons are detected.
  if vim.tbl_count(commit_split) < 2 then
    p([[Commit message does not include colons.]])
    return false
  end

  local before_colon = commit_split[1]
  local after_colon = commit_split[2]

  -- Check if commit introduces a breaking change.
  if vim.endswith(before_colon, "!") then
    before_colon = before_colon:sub(1, -2)
  end

  -- Check if type is correct
  local type = vim.split(before_colon, "%(")[1]
  local allowed_types = {"build", "ci", "docs", "feat", "fix", "perf", "refactor", "revert", "test", "chore"}
  if not vim.tbl_contains(allowed_types, type) then
    p([[Commit type is not recognized. Allowed types are: build, ci, docs, feat, fix, perf, refactor, revert, test, chore.]])
    return false
  end

  -- Check if scope is empty
  if before_colon:match("%(") then
    local scope = vim.trim(before_colon:match("%((.*)%)"))
    if scope == '' then
      p([[Scope can't be empty.]])
      return false
    end
  end

  -- Check that description doesn't end with a period
  if vim.endswith(after_colon, ".") then
      p([[Description ends with a period (\".\").]])
    return false
  end

  -- Check that description has exactly one whitespace after colon, followed by
  -- a lowercase letter and then any number of letters.
  if not string.match(after_colon, '^ %l%a*') then
      p([[There should be one whitespace after the colon and the first letter should lowercase.]])
    return false
  end

  return true
end

local function main()
  local branch = run({'git', 'branch', '--show-current'}, true)
  local ancestor = run({'git', 'merge-base', 'origin/master', branch})
  if not ancestor then
    ancestor = run({'git', 'merge-base', 'upstream/master', branch})
  end
  local commits_str = run({'git', 'rev-list', ancestor..'..'..branch}, true)

  local commits = {}
  for substring in commits_str:gmatch("%S+") do
     table.insert(commits, substring)
  end

  for _, commit_hash in ipairs(commits) do
    local message = run({'git', 'show', '-s', '--format=%s' , commit_hash})
    if vim.v.shell_error ~= 0 then
      p('Invalid commit-id: '..commit_hash..'"')
    elseif not commit_message_is_ok(message) then
      p('Invalid commit format: '..message)
      die()
    end
  end
end

local function _test()
  local good_messages = {
    "ci: normal message",
    "build: normal message",
    "docs: normal message",
    "feat: normal message",
    "fix: normal message",
    "perf: normal message",
    "refactor: normal message",
    "revert: normal message",
    "test: normal message",
    "chore: normal message",
    "ci(window): message with scope",
    "ci!: message with breaking change",
    "ci(tui)!: message with scope and breaking change",
    "vim-patch:8.2.3374: Pyret files are not recognized (#15642)",
    "vim-patch:8.1.1195,8.2.{3417,3419}",
  }

  local bad_messages = {
    ":no type before colon 1",
    " :no type before colon 2",
    "  :no type before colon 3",
    "ci(empty description):",
    "ci(whitespace as description): ",
    "docs(multiple whitespaces as description):   ",
    "ci no colon after type",
    "test:  extra space after colon",
    "ci:	tab after colon",
    "ci:no space after colon",
    "ci :extra space before colon",
    "refactor(): empty scope",
    "ci( ): whitespace as scope",
    "chore: period at end of sentence.",
    "ci: Starting sentence capitalized",
    "unknown: using unknown type",
    "chore: you're saying this commit message just goes on and on and on and on and on and on for way too long?",
  }

  p('Messages expected to pass:')

  for _, message in ipairs(good_messages) do
    if commit_message_is_ok(message) then
      p('[ PASSED ] : '..message)
    else
      p('[ FAIL ]   : '..message)
    end
  end

  p("Messages expected to fail:")

  for _, message in ipairs(bad_messages) do
    if commit_message_is_ok(message) then
      p('[ PASSED ] : '..message)
    else
      p('[ FAIL ]   : '..message)
    end
  end
end

-- _test()
main()
