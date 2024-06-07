-- Usage:
--    # verbose
--    nvim -l scripts/lintcommit.lua main --trace
--
--    # silent
--    nvim -l scripts/lintcommit.lua main
--
--    # self-test
--    nvim -l scripts/lintcommit.lua _test

--- @type table<string,fun(opt: LintcommitOptions)>
local M = {}

local _trace = false

-- Print message
local function p(s)
  vim.cmd('set verbose=1')
  vim.api.nvim_echo({ { s, '' } }, false, {})
  vim.cmd('set verbose=0')
end

-- Executes and returns the output of `cmd`, or nil on failure.
--
-- Prints `cmd` if `trace` is enabled.
local function run(cmd, or_die)
  if _trace then
    p('run: ' .. vim.inspect(cmd))
  end
  local rv = vim.trim(vim.fn.system(cmd)) or ''
  if vim.v.shell_error ~= 0 then
    if or_die then
      p(rv)
      os.exit(1)
    end
    return nil
  end
  return rv
end

-- Returns nil if the given commit message is valid, or returns a string
-- message explaining why it is invalid.
local function validate_commit(commit_message)
  local commit_split = vim.split(commit_message, ':', { plain = true })
  -- Return nil if the type is vim-patch since most of the normal rules don't
  -- apply.
  if commit_split[1] == 'vim-patch' then
    return nil
  end

  -- Check that message isn't too long.
  if commit_message:len() > 80 then
    return [[Commit message is too long, a maximum of 80 characters is allowed.]]
  end

  local before_colon = commit_split[1]

  local after_idx = 2
  if before_colon:match('^[^%(]*%([^%)]*$') then
    -- Need to find the end of commit scope when commit scope contains colons.
    while after_idx <= vim.tbl_count(commit_split) do
      after_idx = after_idx + 1
      if commit_split[after_idx - 1]:find(')') then
        break
      end
    end
  end
  if after_idx > vim.tbl_count(commit_split) then
    return [[Commit message does not include colons.]]
  end
  local after_colon = ''
  while after_idx <= vim.tbl_count(commit_split) do
    after_colon = after_colon .. commit_split[after_idx]
    after_idx = after_idx + 1
  end

  -- Check if commit introduces a breaking change.
  if vim.endswith(before_colon, '!') then
    before_colon = before_colon:sub(1, -2)
  end

  -- Check if type is correct
  local type = vim.split(before_colon, '(', { plain = true })[1]
  local allowed_types =
    { 'build', 'ci', 'docs', 'feat', 'fix', 'perf', 'refactor', 'revert', 'test', 'vim-patch' }
  if not vim.tbl_contains(allowed_types, type) then
    return string.format(
      [[Invalid commit type "%s". Allowed types are:
      %s.
    If none of these seem appropriate then use "fix"]],
      type,
      vim.inspect(allowed_types)
    )
  end

  -- Check if scope is appropriate
  if before_colon:match('%(') then
    local scope = vim.trim(commit_message:match('%((.-)%)'))

    if scope == '' then
      return [[Scope can't be empty]]
    end

    if vim.startswith(scope, 'nvim_') then
      return [[Scope should be "api" instead of "nvim_..."]]
    end

    local alternative_scope = {
      ['filetype.vim'] = 'filetype',
      ['filetype.lua'] = 'filetype',
      ['tree-sitter'] = 'treesitter',
      ['ts'] = 'treesitter',
      ['hl'] = 'highlight',
    }

    if alternative_scope[scope] then
      return ('Scope should be "%s" instead of "%s"'):format(alternative_scope[scope], scope)
    end
  end

  -- Check that description doesn't end with a period
  if vim.endswith(after_colon, '.') then
    return [[Description ends with a period (".").]]
  end

  -- Check that description starts with a whitespace.
  if after_colon:sub(1, 1) ~= ' ' then
    return [[There should be a whitespace after the colon.]]
  end

  -- Check that description doesn't start with multiple whitespaces.
  if after_colon:sub(1, 2) == '  ' then
    return [[There should only be one whitespace after the colon.]]
  end

  -- Allow lowercase or ALL_UPPER but not Titlecase.
  if after_colon:match('^ *%u%l') then
    return [[Description first word should not be Capitalized.]]
  end

  -- Check that description isn't just whitespaces
  if vim.trim(after_colon) == '' then
    return [[Description shouldn't be empty.]]
  end

  return nil
end

--- @param opt? LintcommitOptions
function M.main(opt)
  _trace = not opt or not not opt.trace

  local branch = run({ 'git', 'rev-parse', '--abbrev-ref', 'HEAD' }, true)
  -- TODO(justinmk): check $GITHUB_REF
  local ancestor = run({ 'git', 'merge-base', 'origin/master', branch })
  if not ancestor then
    ancestor = run({ 'git', 'merge-base', 'upstream/master', branch })
  end
  local commits_str = run({ 'git', 'rev-list', ancestor .. '..' .. branch }, true)
  assert(commits_str)

  local commits = {} --- @type string[]
  for substring in commits_str:gmatch('%S+') do
    table.insert(commits, substring)
  end

  local failed = 0
  for _, commit_id in ipairs(commits) do
    local msg = run({ 'git', 'show', '-s', '--format=%s', commit_id })
    if vim.v.shell_error ~= 0 then
      p('Invalid commit-id: ' .. commit_id .. '"')
    else
      local invalid_msg = validate_commit(msg)
      if invalid_msg then
        failed = failed + 1

        -- Some breathing room
        if failed == 1 then
          p('\n')
        end

        p(string.format(
          [[
Invalid commit message: "%s"
    Commit: %s
    %s
]],
          msg,
          commit_id,
          invalid_msg
        ))
      end
    end
  end

  if failed > 0 then
    p([[
See also:
    https://github.com/neovim/neovim/blob/master/CONTRIBUTING.md#commit-messages

]])
    os.exit(1)
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
    ['ci(window): message with scope'] = true,
    ['ci!: message with breaking change'] = true,
    ['ci(tui)!: message with scope and breaking change'] = true,
    ['vim-patch:8.2.3374: Pyret files are not recognized (#15642)'] = true,
    ['vim-patch:8.1.1195,8.2.{3417,3419}'] = true,
    ['revert: "ci: use continue-on-error instead of "|| true""'] = true,
    ['fixup'] = false,
    ['fixup: commit message'] = false,
    ['fixup! commit message'] = false,
    [':no type before colon 1'] = false,
    [' :no type before colon 2'] = false,
    ['  :no type before colon 3'] = false,
    ['ci(empty description):'] = false,
    ['ci(only whitespace as description): '] = false,
    ['docs(multiple whitespaces as description):   '] = false,
    ['revert(multiple whitespaces and then characters as description):  description'] = false,
    ['ci no colon after type'] = false,
    ['test:  extra space after colon'] = false,
    ['ci:	tab after colon'] = false,
    ['ci:no space after colon'] = false,
    ['ci :extra space before colon'] = false,
    ['refactor(): empty scope'] = false,
    ['ci( ): whitespace as scope'] = false,
    ['ci: period at end of sentence.'] = false,
    ['ci: period: at end of sentence.'] = false,
    ['ci: Capitalized first word'] = false,
    ['ci: UPPER_CASE First Word'] = true,
    ['unknown: using unknown type'] = false,
    ['feat: foo:bar'] = true,
    ['feat: :foo:bar'] = true,
    ['feat(something): foo:bar'] = true,
    ['feat(something): :foo:bar'] = true,
    ['feat(:grep): read from pipe'] = true,
    ['feat(:grep/:make): read from pipe'] = true,
    ['feat(:grep): foo:bar'] = true,
    ['feat(:grep/:make): foo:bar'] = true,
    ['feat(:grep)'] = false,
    ['feat(:grep/:make)'] = false,
    ['feat(:grep'] = false,
    ['feat(:grep/:make'] = false,
    ["ci: you're saying this commit message just goes on and on and on and on and on and on for way too long?"] = false,
  }

  local failed = 0
  for message, expected in pairs(test_cases) do
    local is_valid = (nil == validate_commit(message))
    if is_valid ~= expected then
      failed = failed + 1
      p(
        string.format('[ FAIL ]: expected=%s, got=%s\n    input: "%s"', expected, is_valid, message)
      )
    end
  end

  if failed > 0 then
    os.exit(1)
  end
end

--- @class LintcommitOptions
--- @field trace? boolean
local opt = {}

for _, a in ipairs(arg) do
  if vim.startswith(a, '--') then
    local nm, val = a:sub(3), true
    if vim.startswith(a, '--no') then
      nm, val = a:sub(5), false
    end

    if nm == 'trace' then
      opt.trace = val
    end
  end
end

for _, a in ipairs(arg) do
  if M[a] then
    M[a](opt)
  end
end
