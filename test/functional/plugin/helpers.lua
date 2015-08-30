local paths = require('test.config.paths')

local helpers = require('test.functional.helpers')
local spawn, set_session, nvim_prog, merge_args =
  helpers.spawn, helpers.set_session, helpers.nvim_prog, helpers.merge_args

local additional_cmd = ''

local function nvim_argv()
  local rtp_value = ('\'%s/runtime\''):format(
      paths.test_source_path:gsub('\'', '\'\''))
  local nvim_argv = {nvim_prog, '-u', 'NORC', '-i', 'NONE', '-N',
                     '--cmd', 'set shortmess+=I background=light noswapfile',
                     '--cmd', 'let &runtimepath=' .. rtp_value,
                     '--cmd', additional_cmd,
                     '--embed'}
  if helpers.prepend_argv then
    return merge_args(helpers.prepend_argv, nvim_argv)
  else
    return nvim_argv
  end
end

local session = nil

local reset = function()
  if session then
    session:exit(0)
  end
  session = spawn(nvim_argv())
  set_session(session)
end

local set_additional_cmd = function(s)
  additional_cmd = s
end

return {
  reset=reset,
  set_additional_cmd=set_additional_cmd,
}
