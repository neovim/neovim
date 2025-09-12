#compdef nvim

# zsh completions for 'nvim'
# automatically generated with http://github.com/RobSis/zsh-completion-generator
local arguments

arguments=(
  '*--cmd[execute <cmd> before any config]:command'
  '*-c[Execute <cmd> after config and first file]:command'
  '-l[Execute Lua <script> (with optional args)]:script:_files -g "*.lua"'  # TODO: remaining args are passed to <script> and not opened by nvim for edit
  '-S[source <session> after loading the first file]::session:_files'
  '-s[read Normal mode commands from <scriptin>]:file:_files'
  '-u[use this config file]:config'
  '-d[diff mode]'
  {-es,-Es}'[silent (batch) mode]'
  '(- *)'{-h,--help}'[print this help message]'
  '-i[use this shada file]:shada:_files -g "*.shada"'
  '-n[no swap file, use memory only]'
  '-o-[open N windows (default: one per file)]::N'
  '-O-[open N vertical windows (default: one per file)]::N'
  '-p-[open N tab pages (default: one per file)]::N'
  '-R[read-only (view) mode]'
  '(- *)'{-v,--version}'[print version information]'
  '-V[verbose \[level\]\[file\]]'
  '(- *)--api-info[write msgpack-encoded API metadata to stdout]'
  '--clean["Factory defaults" (skip user config and plugins, shada)]'
  '--embed[use stdin/stdout as a msgpack-rpc channel]'
  '--headless[dont start a user interface]'
  '--listen[serve RPC API from this address]:address'
  '--remote[\[-subcommand\] Execute commands remotely on a server]'
  '--server[connect to this Nvim server]:address'
  '--startuptime[write startup timing messages to <file>]:file:_files'
  '*:filename:_files'
)

_arguments -s $arguments
