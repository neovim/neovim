-- Usage:
--    # verbose
--    nvim -es +"lua require('scripts.lintcommit').main()"
--
--    # silent
--    nvim -es +"lua require('scripts.lintcommit').main({trace=false})"
--
--    # self-test
--    nvim -es +"lua require('scripts.lintcommit')._test()"

local M = {}

local _trace = false

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
  if _trace then
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

-- Returns nil if the given commit message is valid, or returns a string
-- message explaining why it is invalid.
local function validate_commit(commit_message)
  local commit_split = vim.split(commit_message, ":")

  -- Return true if the type is vim-patch since most of the normal rules don't
  -- apply.
  if commit_split[1] == "vim-patch" then
    return nil
  end

  -- Check that message isn't too long.
  if commit_message:len() > 80 then
    return [[Commit message is too long, a maximum of 80 characters is allowed.]]
  end


  if vim.tbl_count(commit_split) < 2 then
    return [[Commit message does not include colons.]]
  end

  local before_colon = commit_split[1]
  local after_colon = commit_split[2]

  -- Check if commit introduces a breaking change.
  if vim.endswith(before_colon, "!") then
    before_colon = before_colon:sub(1, -2)
  end

  -- Check if type is correct
  local type = vim.split(before_colon, "%(")[1]
  local allowed_types = {'build', 'ci', 'docs', 'feat', 'fix', 'perf', 'refactor', 'revert', 'test', 'chore', 'vim-patch'}
  if not vim.tbl_contains(allowed_types, type) then
    return string.format(
      'Invalid commit type "%s". Allowed types are:\n    %s',
      type,
      vim.inspect(allowed_types))
  end

  -- Check if scope is empty
  if before_colon:match("%(") then
    local scope = vim.trim(before_colon:match("%((.*)%)"))
    if scope == '' then
      return [[Scope can't be empty.]]
    end
  end

  -- Check that description doesn't end with a period
  if vim.endswith(after_colon, ".") then
    return [[Description ends with a period (".").]]
  end

  -- Check that description has exactly one whitespace after colon, followed by
  -- a lowercase letter and then any number of letters.
  if not string.match(after_colon, '^ %l%a*') then
    return [[There should be one whitespace after the colon and the first letter should lowercase.]]
  end

  return nil
end

function M.main(opt)
  _trace = not opt or not not opt.trace

  local branch = run({'git', 'branch', '--show-current'}, true)
  -- TODO(justinmk): check $GITHUB_REF
  local ancestor = run({'git', 'merge-base', 'origin/master', branch})
  if not ancestor then
    ancestor = run({'git', 'merge-base', 'upstream/master', branch})
  end
  local commits_str = run({'git', 'rev-list', ancestor..'..'..branch}, true)

  local commits = {}
  for substring in commits_str:gmatch("%S+") do
     table.insert(commits, substring)
  end

  local failed = 0
  for _, commit_id in ipairs(commits) do
    local msg = run({'git', 'show', '-s', '--format=%s' , commit_id})
    if vim.v.shell_error ~= 0 then
      p('Invalid commit-id: '..commit_id..'"')
    else
      local invalid_msg = validate_commit(msg)
      if invalid_msg then
        failed = failed + 1
        p(string.format([[
Invalid commit message: "%s"
    Commit: %s
    %s
    See also:
        https://github.com/neovim/neovim/blob/master/CONTRIBUTING.md#commit-messages
        https://www.conventionalcommits.org/en/v1.0.0/
]],
          msg,
          commit_id,
          invalid_msg))
      end
    end
  end

  if failed > 0 then
    die()  -- Exit with error.
  else
    p('')
  end
end

function M._test()
  -- message:expected_result
  local test_cases = {
    ['ci: normal message'] = true,
    ['build: normal message'] = true,
    ['docs: normal message'] = true,
    ['feat: normal message'] = true,
    ['fix: normal message'] = true,
    ['perf: normal message'] = true,
    ['refactor: normal message'] = true,
    ['revert: normal message'] = true,
    ['test: normal message'] = true,
    ['chore: normal message'] = true,
    ['ci(window): message with scope'] = true,
    ['ci!: message with breaking change'] = true,
    ['ci(tui)!: message with scope and breaking change'] = true,
    ['vim-patch:8.2.3374: Pyret files are not recognized (#15642)'] = true,
    ['vim-patch:8.1.1195,8.2.{3417,3419}'] = true,
    [':no type before colon 1'] = false,
    [' :no type before colon 2'] = false,
    ['  :no type before colon 3'] = false,
    ['ci(empty description):'] = false,
    ['ci(whitespace as description): '] = false,
    ['docs(multiple whitespaces as description):   '] = false,
    ['ci no colon after type'] = false,
    ['test:  extra space after colon'] = false,
    ['ci:	tab after colon'] = false,
    ['ci:no space after colon'] = false,
    ['ci :extra space before colon'] = false,
    ['refactor(): empty scope'] = false,
    ['ci( ): whitespace as scope'] = false,
    ['chore: period at end of sentence.'] = false,
    ['ci: Starting sentence capitalized'] = false,
    ['unknown: using unknown type'] = false,
    ['chore: you\'re saying this commit message just goes on and on and on and on and on and on for way too long?'] = false,
  }

  local failed = 0
  for message, expected in pairs(test_cases) do
    local is_valid = (nil == validate_commit(message))
    if is_valid ~= expected then
      failed = failed + 1
      p(string.format('[ FAIL ]: expected=%s, got=%s\n    input: "%s"', expected, is_valid, message))
    end
  end

  if failed > 0 then
    die()  -- Exit with error.
  end

end

return M
