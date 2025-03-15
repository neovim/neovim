#compdef nvim

# zsh completions for 'nvim'
# automatically generated with http://github.com/RobSis/zsh-completion-generator
local arguments

arguments=(
  '--cmd[execute <cmd> before any config]'
  '-l[\[args...\] Execute Lua <script> (with optional args)]'
  '-S[source <session> after loading the first file]'
  '-s[read Normal mode commands from <scriptin>] file:_files'
  '-u[use this config file]'
  '-d[diff mode]'
  {-es,-Es}'[silent (batch) mode]'
  '(- *)'{-h,--help}'[print this help message]'
  '-i[use this shada file]'
  '-n[no swap file, use memory only]'
  '-o+[open N windows (default: one per file)]'
  '-O+[open N vertical windows (default: one per file)]'
  '-p+[open N tab pages (default: one per file)]'
  '-R[read-only (view) mode]'
  '(- *)'{-v,--version}'[print version information]'
  '-V[verbose \[level\]\[file\]]'
  '--api-info[write msgpack-encoded API metadata to stdout]'
  '--clean["Factory defaults" (skip user config and plugins, shada)]'
  '--embed[use stdin/stdout as a msgpack-rpc channel]'
  '--headless[dont start a user interface]'
  '--listen[serve RPC API from this address]'
  '--remote[\[-subcommand\] Execute commands remotely on a server]'
  '--server[connect to this Nvim server]'
  '--startuptime[write startup timing messages to <file>]'
  '*:filename:_files'
)

_arguments -s $arguments
