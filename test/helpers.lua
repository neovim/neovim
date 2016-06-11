local assert = require('luassert')
local lfs = require('lfs')

local check_logs_useless_lines = {
  ['Warning: noted but unhandled ioctl']=1,
  ['could cause spurious value errors to appear']=2,
  ['See README_MISSING_SYSCALL_OR_IOCTL for guidance']=3,
}

local eq = function(exp, act)
  return assert.are.same(exp, act)
end
local neq = function(exp, act)
  return assert.are_not.same(exp, act)
end
local ok = function(res)
  return assert.is_true(res)
end

local function check_logs()
  local log_dir = os.getenv('LOG_DIR')
  local runtime_errors = 0
  if log_dir and lfs.attributes(log_dir, 'mode') == 'directory' then
    for tail in lfs.dir(log_dir) do
      if tail:sub(1, 30) == 'valgrind-' or tail:find('san%.') then
        local file = log_dir .. '/' .. tail
        local fd = io.open(file)
        local start_msg = ('='):rep(20) .. ' File ' .. file .. ' ' .. ('='):rep(20)
        local lines = {}
        local warning_line = 0
        for line in fd:lines() do
          local cur_warning_line = check_logs_useless_lines[line]
          if cur_warning_line == warning_line + 1 then
            warning_line = cur_warning_line
          else
            lines[#lines + 1] = line
          end
        end
        fd:close()
        os.remove(file)
        if #lines > 0 then
          -- local out = os.getenv('TRAVIS_CI_BUILD') and io.stdout or io.stderr
          local out = io.stdout
          out:write(start_msg .. '\n')
          out:write('= ' .. table.concat(lines, '\n= ') .. '\n')
          out:write(select(1, start_msg:gsub('.', '=')) .. '\n')
          runtime_errors = runtime_errors + 1
        end
      end
    end
  end
  assert(0 == runtime_errors)
end

return {
  eq = eq,
  neq = neq,
  ok = ok,
  check_logs = check_logs,
}
