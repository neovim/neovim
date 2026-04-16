--- @alias test.reporter.SummaryStatus 'skipped' | 'failure' | 'error'

--- @class test.reporter.ColorMap
--- @field bright fun(s: any): string
--- @field green fun(s: any): string
--- @field yellow fun(s: any): string
--- @field magenta fun(s: any): string
--- @field red fun(s: any): string
--- @field cyan fun(s: any): string
--- @field dim fun(s: any): string

--- @class test.reporter.FileElement
--- @field name string
--- @field duration? number

--- @class test.reporter.Options
--- @field paths string[]
--- @field verbose boolean
--- @field summary_file string

--- @class test.base_reporter
--- @field new fun(opts: test.reporter.Options): test.base_reporter
--- @field suite_start fun(self: test.base_reporter, repeat_index?: integer, repeat_count?: integer)
--- @field file_start fun(self: test.base_reporter, file: test.reporter.FileElement)
--- @field test_start fun(self: test.base_reporter, name: string)
--- @field test_end fun(self: test.base_reporter, record: test.harness.Record)
--- @field file_end fun(self: test.base_reporter, file: test.reporter.FileElement, test_count: integer)
--- @field suite_end fun(self: test.base_reporter, duration: number, run_summary: test.harness.RunSummary, failure_output?: string)

--- @class test.reporter : test.base_reporter
--- @field opts test.reporter.Options
--- @field colors test.reporter.ColorMap
local M = {}
M.__index = M

--- @return test.reporter.ColorMap
local function identity_colors()
  return setmetatable({}, {
    __index = function()
      return function(s)
        return s == nil and '' or tostring(s)
      end
    end,
  })
end

--- @param code string
--- @return fun(s: any): string
local function ansi_color(code)
  return function(s)
    return ('\27[%sm%s\27[0m'):format(code, s == nil and '' or tostring(s))
  end
end

local ansi_colors = {
  bright = ansi_color('1'),
  green = ansi_color('32'),
  yellow = ansi_color('33'),
  magenta = ansi_color('35'),
  red = ansi_color('31'),
  cyan = ansi_color('36'),
  dim = ansi_color('2'),
}

--- @return boolean
local function use_colors()
  local test_colors = os.getenv('TEST_COLORS')
  if not test_colors then
    return true
  end

  local value = test_colors:lower()
  return not (value == 'false' or value == '0' or value == 'no' or value == 'off')
end

--- @param path? string
--- @return file
local function open_summary_file(path)
  if type(path) ~= 'string' or path == '-' then
    return io.stdout
  end

  return (assert(io.open(path, 'w')))
end

--- @param opts test.reporter.Options
--- @return test.reporter
function M.new(opts)
  local colors = identity_colors()
  if use_colors() then
    colors = ansi_colors
  end

  --- @type test.reporter
  local self = setmetatable({
    opts = opts,
    colors = colors,
  }, M)

  return self
end

--- @param element? { duration?: number }
--- @return number
local function get_elapsed_time_ms(element)
  if element and element.duration then
    return element.duration * 1000
  end

  return tonumber('nan')
end

--- @private
--- @param s any
--- @return string
function M:succ(s)
  return self.colors.bright(self.colors.green(s))
end

--- @private
--- @param s any
--- @return string
function M:skip(s)
  return self.colors.bright(self.colors.yellow(s))
end

--- @private
--- @param s any
--- @return string
function M:fail(s)
  return self.colors.bright(self.colors.magenta(s))
end

--- @private
--- @param s any
--- @return string
function M:errr(s)
  return self.colors.bright(self.colors.red(s))
end

--- @private
--- @param s any
--- @return string
function M:fpath(s)
  return self.colors.cyan(s)
end

--- @private
--- @param s any
--- @return string
function M:time(s)
  return self.colors.dim(s)
end

--- @private
--- @param s any
--- @return string
function M:sect(s)
  return self.colors.green(self.colors.dim(s))
end

--- @private
--- @param s any
--- @return string
function M:nmbr(s)
  return self.colors.bright(s)
end

--- @private
--- @param status test.harness.ResultStatus
--- @return string
function M:result_text(status)
  if status == 'success' then
    return ('%s\n'):format(self:succ('OK'))
  elseif status == 'pending' then
    return ('%s\n'):format(self:skip('SKIP'))
  elseif status == 'failure' then
    return ('%s\n'):format(self:fail('FAIL'))
  end

  return ('%s\n'):format(self:errr('ERR'))
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @return string
function M:summary_label(status)
  if status == 'skipped' then
    return self:skip('SKIPPED ')
  elseif status == 'failure' then
    return self:fail('FAILED  ')
  end

  return self:errr('ERROR   ')
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @param count integer
--- @return string
function M:summary_header_noun(status, count)
  if status == 'error' then
    return count == 1 and 'error' or 'errors'
  end

  return count == 1 and 'test' or 'tests'
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @param count integer
--- @return string
function M:summary_footer_noun(status, count)
  if status == 'skipped' then
    return count == 1 and 'SKIPPED TEST' or 'SKIPPED TESTS'
  elseif status == 'failure' then
    return count == 1 and 'FAILED TEST' or 'FAILED TESTS'
  elseif status == 'error' then
    return count == 1 and 'ERROR' or 'ERRORS'
  end

  return count == 1 and 'TEST' or 'TESTS'
end

--- @param message any
--- @return string
local function stringify_message(message)
  if type(message) == 'string' then
    return message
  elseif message == nil then
    return ''
  end

  return vim.inspect(message)
end

--- @private
--- @param pending test.harness.Record
--- @return boolean
function M:na_check(pending)
  if pending.name and vim.list_contains(vim.split(pending.name, '[ :]'), 'N/A') then
    return true
  end

  if type(pending.message) == 'string' then
    return vim.list_contains(vim.split(pending.message, '[ :]'), 'N/A')
  end

  return false
end

--- @private
--- @param pending test.harness.Record
--- @return string
function M:pending_description(pending)
  local message = stringify_message(pending.message)
  if message == '' then
    return ''
  end

  return table.concat({ message, '\n' })
end

--- @private
--- @param failure test.harness.Record
--- @return string
function M:failure_description(failure)
  local message = stringify_message(failure.message)
  if message == '' then
    message = 'Nil error'
  end

  local parts = { message, '\n' }
  if self.opts.verbose and failure.traceback then
    parts[#parts + 1] = failure.traceback
    parts[#parts + 1] = '\n'
  end

  return table.concat(parts)
end

--- @private
--- @param trace? test.harness.Trace
--- @return string
function M:get_file_line(trace)
  if not trace or not trace.short_src then
    return ''
  end

  local source = vim.fs.normalize(trace.short_src)
  local line = trace.currentline or 0
  return self:fpath(source) .. ' @ ' .. self:fpath(line) .. ': '
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @param count integer
--- @param list test.harness.Record[]
--- @param describe fun(self: test.reporter, item: test.harness.Record): string
--- @return string
function M:get_test_list(status, count, list, describe)
  if count == 0 then
    return ''
  end

  local label = self:summary_label(status)
  local parts = {
    ('%s %s %s, listed below:\n'):format(
      label,
      self:nmbr(count),
      self:summary_header_noun(status, count)
    ),
  }
  local na_count = 0

  for _, item in ipairs(list) do
    if status == 'skipped' and self:na_check(item) then
      na_count = na_count + 1
    else
      local fullname = self:get_file_line(item.trace) .. self:nmbr(item.name)
      parts[#parts + 1] = ('%s %s\n'):format(label, fullname)
      parts[#parts + 1] = describe(self, item)
    end
  end

  if na_count > 0 then
    parts[#parts + 1] =
      self:nmbr(('%d N/A %s not shown\n'):format(na_count, na_count == 1 and 'test' or 'tests'))
  end

  return table.concat(parts)
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @param count integer
--- @return string
function M:get_summary(status, count)
  if count == 0 then
    return ''
  end

  return (' %s %s\n'):format(self:nmbr(count), self:summary_footer_noun(status, count))
end

--- @private
--- @return string
--- @param summary test.harness.RunSummary
function M:get_summary_string(summary)
  local tests = summary.success_count == 1 and 'test' or 'tests'
  local parts = {
    ('%s %s %s.\n'):format(self:succ('PASSED  '), self:nmbr(summary.success_count), tests),
    self:get_test_list('skipped', summary.skipped_count, summary.pendings, M.pending_description),
    self:get_test_list('failure', summary.failure_count, summary.failures, M.failure_description),
    self:get_test_list('error', summary.error_count, summary.errors, M.failure_description),
  }

  if (summary.skipped_count + summary.failure_count + summary.error_count) > 0 then
    parts[#parts + 1] = '\n'
  end

  parts[#parts + 1] = self:get_summary('skipped', summary.skipped_count)
  parts[#parts + 1] = self:get_summary('failure', summary.failure_count)
  parts[#parts + 1] = self:get_summary('error', summary.error_count)
  return table.concat(parts)
end

--- @return nil
--- @param repeat_index? integer
--- @param repeat_count? integer
function M:suite_start(repeat_index, repeat_count)
  if repeat_count and repeat_count > 1 and repeat_index then
    io.write(('\nRepeating all tests (run %d of %d) . . .\n\n'):format(repeat_index, repeat_count))
  end
  io.write(('%s Global test environment setup.\n'):format(self:sect('--------')))
  io.flush()
end

--- @param file test.reporter.FileElement
function M:file_start(file)
  io.write(
    ('%s Running tests from %s\n'):format(
      self:sect('--------'),
      self:fpath(vim.fs.normalize(file.name))
    )
  )
  io.flush()
end

--- @param name string
function M:test_start(name)
  local desc = ('%s %s'):format(_G._nvim_test_id or '', name)
  io.write(('%s %s: '):format(self:sect('RUN     '), desc))
  io.flush()
end

--- @private
--- @param record { duration?: number }
--- @param text string
function M:write_status(record, text)
  io.write(('%s %s'):format(self:time(('%.2f ms'):format(get_elapsed_time_ms(record))), text))
  io.flush()
end

--- @param record test.harness.Record
function M:test_end(record)
  local text = self:result_text(record.status)
  if record.status == 'failure' or record.status == 'error' then
    text = text .. self:failure_description(record)
  end

  self:write_status(record, text)
end

--- @param file test.reporter.FileElement
--- @param test_count integer
function M:file_end(file, test_count)
  io.write(
    ('%s %s %s from %s %s\n\n'):format(
      self:sect('--------'),
      self:nmbr(test_count),
      test_count == 1 and 'test' or 'tests',
      self:fpath(vim.fs.normalize(file.name)),
      self:time(('(%.2f ms total)'):format(get_elapsed_time_ms(file)))
    )
  )
  io.flush()
end

--- @param duration number
--- @param run_summary test.harness.RunSummary
--- @param failure_output? string
function M:suite_end(duration, run_summary, failure_output)
  local tests = run_summary.test_count == 1 and 'test' or 'tests'
  local files = run_summary.file_count == 1 and 'file' or 'files'

  io.write(('%s Global test environment teardown.\n'):format(self:sect('--------')))
  io.flush()

  local fpath = function(s)
    return self:fpath(s)
  end

  local summary_file = open_summary_file(self.opts.summary_file)
  summary_file:write('\n')
  summary_file:write(
    ('%s %s %s from %s test %s of %s ran. %s\n'):format(
      self:sect('========'),
      self:nmbr(run_summary.test_count),
      tests,
      self:nmbr(run_summary.file_count),
      files,
      vim.iter(self.opts.paths):map(fpath):join(';'),
      self:time(('(%.2f ms total)'):format(duration * 1000))
    )
  )
  summary_file:write(self:get_summary_string(run_summary))
  if failure_output then
    summary_file:write(failure_output)
  end
  summary_file:flush()
  if summary_file ~= io.stdout then
    summary_file:close()
  end
end

return M
