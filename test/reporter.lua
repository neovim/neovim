---@alias test.reporter.SummaryStatus
---| 'skipped'
---| 'failure'
---| 'error'

---@class test.reporter.ColorMap
---@field bright fun(s: any): string
---@field green fun(s: any): string
---@field yellow fun(s: any): string
---@field magenta fun(s: any): string
---@field red fun(s: any): string
---@field cyan fun(s: any): string
---@field dim fun(s: any): string

---@class test.reporter.SectionColors
---@field succ fun(s: any): string
---@field skip fun(s: any): string
---@field fail fun(s: any): string
---@field errr fun(s: any): string
---@field test fun(s: any): string
---@field file fun(s: any): string
---@field time fun(s: any): string
---@field sect fun(s: any): string
---@field nmbr fun(s: any): string

---@class test.reporter.SummaryFormat
---@field header string
---@field test string
---@field footer string

---@class test.reporter.FileElement
---@field name string
---@field duration? number

---@class test.reporter.Options
---@field verbose boolean
---@field summary_file string
---@field test_path_label? string
---@field get_failure_output? fun(): string?

---@class test.reporter
---@field opts test.reporter.Options
---@field colors test.reporter.ColorMap
---@field file_count integer
---@field file_names_seen table<string, boolean>
---@field file_test_count integer
---@field test_count integer
---@field success_count integer
---@field skipped_count integer
---@field failure_count integer
---@field error_count integer
---@field pendings test.harness.Record[]
---@field failures test.harness.Record[]
---@field errors test.harness.Record[]
---@field c test.reporter.SectionColors
---@field global_setup string
---@field file_start_string string
---@field run_string string
---@field success_string string
---@field skipped_string string
---@field failure_string string
---@field error_string string
---@field file_end_string string
---@field global_teardown string
---@field suite_end_string string
---@field success_status string
---@field time_string string
---@field summary_strings table<test.reporter.SummaryStatus, test.reporter.SummaryFormat>
local Reporter = {}
Reporter.__index = Reporter

---@return test.reporter.ColorMap
local function identity_colors()
  return setmetatable({}, {
    __index = function()
      return function(s)
        return s == nil and '' or tostring(s)
      end
    end,
  })
end

---@param code string
---@return fun(s: any): string
local function ansi_color(code)
  return function(s)
    return ('\27[%sm%s\27[0m'):format(code, s == nil and '' or tostring(s))
  end
end

---@return test.reporter.ColorMap
local function ansi_colors()
  return {
    bright = ansi_color('1'),
    green = ansi_color('32'),
    yellow = ansi_color('33'),
    magenta = ansi_color('35'),
    red = ansi_color('31'),
    cyan = ansi_color('36'),
    dim = ansi_color('2'),
  }
end

---@return boolean
local function use_colors()
  if not os.getenv('TEST_COLORS') then
    return true
  end

  local value = os.getenv('TEST_COLORS'):lower()
  return not (value == 'false' or value == '0' or value == 'no' or value == 'off')
end

---@param path? string
---@return any
local function open_summary_file(path)
  if type(path) ~= 'string' or path == '-' then
    return io.stdout
  end

  local file = assert(io.open(path, 'w'))
  return file
end

---@param opts test.reporter.Options
---@return test.reporter
function Reporter.new(opts)
  local colors = identity_colors()
  if use_colors() then
    colors = ansi_colors()
  end

  ---@type test.reporter
  local self = setmetatable({
    opts = opts,
    colors = colors,
    file_count = 0,
    file_names_seen = {},
    file_test_count = 0,
    test_count = 0,
    success_count = 0,
    skipped_count = 0,
    failure_count = 0,
    error_count = 0,
    pendings = {},
    failures = {},
    errors = {},
  }, Reporter)

  self.c = {
    succ = function(s)
      return colors.bright(colors.green(s))
    end,
    skip = function(s)
      return colors.bright(colors.yellow(s))
    end,
    fail = function(s)
      return colors.bright(colors.magenta(s))
    end,
    errr = function(s)
      return colors.bright(colors.red(s))
    end,
    test = tostring,
    file = colors.cyan,
    time = colors.dim,
    sect = function(s)
      return colors.green(colors.dim(s))
    end,
    nmbr = colors.bright,
  }

  self.global_setup = self.c.sect('--------') .. ' Global test environment setup.\n'
  self.file_start_string = self.c.sect('--------')
    .. ' Running tests from '
    .. self.c.file('%s')
    .. '\n'
  self.run_string = self.c.sect('RUN     ') .. ' ' .. self.c.test('%s') .. ': '
  self.success_string = self.c.succ('OK') .. '\n'
  self.skipped_string = self.c.skip('SKIP') .. '\n'
  self.failure_string = self.c.fail('FAIL') .. '\n'
  self.error_string = self.c.errr('ERR') .. '\n'
  self.file_end_string = self.c.sect('--------')
    .. ' '
    .. self.c.nmbr('%d')
    .. ' %s from '
    .. self.c.file('%s')
    .. ' '
    .. self.c.time('(%.2f ms total)')
    .. '\n\n'
  self.global_teardown = self.c.sect('--------') .. ' Global test environment teardown.\n'
  self.suite_end_string = self.c.sect('========')
    .. ' '
    .. self.c.nmbr('%d')
    .. ' %s from '
    .. self.c.nmbr('%d')
    .. ' test %s ran. '
    .. self.c.time('(%.2f ms total)')
    .. '\n'
  self.success_status = self.c.succ('PASSED  ') .. ' ' .. self.c.nmbr('%d') .. ' %s.\n'
  self.time_string = self.c.time('%.2f ms')

  self.summary_strings = {
    skipped = {
      header = self.c.skip('SKIPPED ') .. ' ' .. self.c.nmbr('%d') .. ' %s, listed below:\n',
      test = self.c.skip('SKIPPED ') .. ' %s\n',
      footer = ' ' .. self.c.nmbr('%d') .. ' SKIPPED %s\n',
    },
    failure = {
      header = self.c.fail('FAILED  ') .. ' ' .. self.c.nmbr('%d') .. ' %s, listed below:\n',
      test = self.c.fail('FAILED  ') .. ' %s\n',
      footer = ' ' .. self.c.nmbr('%d') .. ' FAILED %s\n',
    },
    error = {
      header = self.c.errr('ERROR   ') .. ' ' .. self.c.nmbr('%d') .. ' %s, listed below:\n',
      test = self.c.errr('ERROR   ') .. ' %s\n',
      footer = ' ' .. self.c.nmbr('%d') .. ' %s\n',
    },
  }

  return self
end

---@param element? { duration?: number }
---@return number
local function get_elapsed_time_ms(element)
  if element and element.duration then
    return element.duration * 1000
  end

  return tonumber('nan')
end

---@param message any
---@return string
local function stringify_message(message)
  if type(message) == 'string' then
    return message
  elseif message == nil then
    return ''
  end

  return vim.inspect(message)
end

---@param pending test.harness.Record
---@return boolean
function Reporter.na_check(_, pending)
  if pending.name and vim.list_contains(vim.split(pending.name, '[ :]'), 'N/A') then
    return true
  end

  if type(pending.message) == 'string' then
    return vim.list_contains(vim.split(pending.message, '[ :]'), 'N/A')
  end

  return false
end

---@param pending test.harness.Record
---@return string
function Reporter.pending_description(_, pending)
  local message = stringify_message(pending.message)
  if message == '' then
    return ''
  end

  return message .. '\n'
end

---@param failure test.harness.Record
---@return string
function Reporter:failure_description(failure)
  local message = stringify_message(failure.message)
  if message == '' then
    message = 'Nil error'
  end

  local text = message .. '\n'
  if self.opts.verbose and failure.traceback then
    text = text .. failure.traceback .. '\n'
  end

  return text
end

---@param element? test.harness.Element
---@return string
function Reporter:get_file_line(element)
  local trace = element and element.trace
  if not trace or not trace.short_src then
    return ''
  end

  local source = vim.fs.normalize(trace.short_src)
  local line = trace.currentline or 0
  return self.colors.cyan(source) .. ' @ ' .. self.colors.cyan(line) .. ': '
end

---@param status test.reporter.SummaryStatus
---@param count integer
---@param list test.harness.Record[]
---@param describe fun(self: test.reporter, item: test.harness.Record): string
---@return string
function Reporter:get_test_list(status, count, list, describe)
  if count == 0 then
    return ''
  end

  local summary = self.summary_strings[status]
  local tests = count == 1 and 'test' or 'tests'
  local errors = count == 1 and 'error' or 'errors'
  local output = summary.header:format(count, status == 'error' and errors or tests)
  local na_count = 0

  for _, item in ipairs(list) do
    if status == 'skipped' and self:na_check(item) then
      na_count = na_count + 1
    else
      local fullname = self:get_file_line(item.element) .. self.colors.bright(item.name)
      output = output .. summary.test:format(fullname)
      output = output .. describe(self, item)
    end
  end

  if na_count > 0 then
    output = output
      .. self.colors.bright(
        ('%d N/A %s not shown\n'):format(na_count, na_count == 1 and 'test' or 'tests')
      )
  end

  return output
end

---@param status test.reporter.SummaryStatus
---@param count integer
---@return string
function Reporter:get_summary(status, count)
  if count == 0 then
    return ''
  end

  local tests = count == 1 and 'TEST' or 'TESTS'
  local errors = count == 1 and 'ERROR' or 'ERRORS'
  return self.summary_strings[status].footer:format(count, status == 'error' and errors or tests)
end

---@return string
function Reporter:get_summary_string()
  local tests = self.success_count == 1 and 'test' or 'tests'
  local summary = self.success_status:format(self.success_count, tests)
  summary = summary
    .. self:get_test_list(
      'skipped',
      self.skipped_count,
      self.pendings,
      Reporter.pending_description
    )
  summary = summary
    .. self:get_test_list(
      'failure',
      self.failure_count,
      self.failures,
      Reporter.failure_description
    )
  summary = summary
    .. self:get_test_list('error', self.error_count, self.errors, Reporter.failure_description)

  if (self.skipped_count + self.failure_count + self.error_count) > 0 then
    summary = summary .. '\n'
  end

  summary = summary .. self:get_summary('skipped', self.skipped_count)
  summary = summary .. self:get_summary('failure', self.failure_count)
  summary = summary .. self:get_summary('error', self.error_count)
  return summary
end

---@return nil
---@param repeat_index? integer
---@param repeat_count? integer
function Reporter:suite_start(repeat_index, repeat_count)
  if repeat_count and repeat_count > 1 and repeat_index then
    io.write(('\nRepeating all tests (run %d of %d) . . .\n\n'):format(repeat_index, repeat_count))
  end
  io.write(self.global_setup)
  io.flush()
end

---@param file test.reporter.FileElement
function Reporter:file_start(file)
  self.file_test_count = 0
  io.write(self.file_start_string:format(vim.fs.normalize(file.name)))
  io.flush()
end

---@param test test.harness.Element
function Reporter:test_start(test)
  local testid = _G._nvim_test_id or ''
  local desc = ('%s %s'):format(testid, test.full_name)
  io.write(self.run_string:format(desc))
  io.flush()
end

---@param element test.harness.Element
---@param text string
function Reporter:write_status(element, text)
  io.write(self.time_string:format(get_elapsed_time_ms(element)) .. ' ' .. text)
  io.flush()
end

---@param test test.harness.Element
---@param status test.harness.ResultStatus
---@param record test.harness.Record
function Reporter:test_end(test, status, record)
  self.file_test_count = self.file_test_count + 1
  self.test_count = self.test_count + 1

  if status == 'success' then
    self.success_count = self.success_count + 1
    self:write_status(test, self.success_string)
    return
  end

  if status == 'pending' then
    self.skipped_count = self.skipped_count + 1
    self.pendings[#self.pendings + 1] = record
    self:write_status(test, self.skipped_string)
    return
  end

  if status == 'failure' then
    self.failure_count = self.failure_count + 1
    self.failures[#self.failures + 1] = record
    self:write_status(test, self.failure_string .. self:failure_description(record))
    return
  end

  self.error_count = self.error_count + 1
  self.errors[#self.errors + 1] = record
  self:write_status(test, self.error_string .. self:failure_description(record))
end

---@param file test.reporter.FileElement
function Reporter:file_end(file)
  local tests = self.file_test_count == 1 and 'test' or 'tests'
  local name = vim.fs.normalize(file.name)
  if not self.file_names_seen[name] then
    self.file_names_seen[name] = true
    self.file_count = self.file_count + 1
  end
  io.write(
    self.file_end_string:format(self.file_test_count, tests, name, get_elapsed_time_ms(file))
  )
  io.flush()
end

---@param duration number
function Reporter:suite_end(duration)
  local tests = self.test_count == 1 and 'test' or 'tests'
  local files = self.file_count == 1 and 'file' or 'files'
  if type(self.opts.test_path_label) == 'string' then
    files = files .. ' of ' .. self.opts.test_path_label
  end

  io.write(self.global_teardown)
  io.flush()

  local summary = open_summary_file(self.opts.summary_file)
  summary:write('\n')
  summary:write(
    self.suite_end_string:format(self.test_count, tests, self.file_count, files, duration * 1000)
  )
  summary:write(self:get_summary_string())
  if (self.failure_count > 0 or self.error_count > 0) and self.opts.get_failure_output then
    local output = self.opts.get_failure_output()
    if output then
      summary:write(output)
    end
  end
  summary:flush()
  if summary ~= io.stdout then
    summary:close()
  end
end

---@return boolean
function Reporter:has_failures()
  return self.failure_count > 0 or self.error_count > 0
end

return Reporter
