if exists('g:loaded_node_provider')
  finish
endif

let s:NodeHandler = {
\ 'stdout_buffered': v:true,
\ 'result': ''
\ }
function! s:NodeHandler.on_exit(job_id, data, event) abort
  let bin_dir = join(get(self, 'stdout', []), '')
  let entry_point = bin_dir . self.entry_point
  let self.result = filereadable(entry_point) ? entry_point : ''
endfunction

function! provider#node#Detect() abort
  let minver = '6.0.0'
  if exists('g:node_host_prog')
    return [expand(g:node_host_prog, v:true), '']
  endif
  if !executable('node')
    return ['', 'node not found (or not executable)']
  endif
  if !v:lua.vim.provider.node.is_minimum_version(v:null, minver)
    return ['', printf('node version %s not found', minver)]
  endif

  let npm_opts = {}
  if executable('npm')
    let npm_opts = deepcopy(s:NodeHandler)
    let npm_opts.entry_point = '/neovim/bin/cli.js'
    let npm_opts.job_id = jobstart('npm --loglevel silent root -g', npm_opts)
  endif

  " npm returns the directory faster, so let's check that first
  if !empty(npm_opts)
    let result = jobwait([npm_opts.job_id])
    if result[0] == 0 && npm_opts.result != ''
      return [npm_opts.result, '']
    endif
  endif

  let yarn_opts = {}
  if executable('yarn')
    let yarn_opts = deepcopy(s:NodeHandler)
    let yarn_opts.entry_point = '/node_modules/neovim/bin/cli.js'
    " `yarn global dir` is slow (> 250ms), try the default path first
    " https://github.com/yarnpkg/yarn/issues/2049#issuecomment-263183768
    let yarn_config_dir = has('win32') ? '/AppData/Local/Yarn/Data' : '/.config/yarn'
    let yarn_default_path = $HOME . yarn_config_dir . '/global/' . yarn_opts.entry_point
    if filereadable(yarn_default_path)
      return [yarn_default_path, '']
    endif
    let yarn_opts.job_id = jobstart('yarn global dir', yarn_opts)
  endif

  if !empty(yarn_opts)
    let result = jobwait([yarn_opts.job_id])
    if result[0] == 0 && yarn_opts.result != ''
      return [yarn_opts.result, '']
    endif
  endif

  let pnpm_opts = {}
  if executable('pnpm')
    let pnpm_opts = deepcopy(s:NodeHandler)
    let pnpm_opts.entry_point = '/neovim/bin/cli.js'
    let pnpm_opts.job_id = jobstart('pnpm --loglevel silent root -g', pnpm_opts)
  endif

  if !empty(pnpm_opts)
    let result = jobwait([pnpm_opts.job_id])
    if result[0] == 0 && pnpm_opts.result != ''
      return [pnpm_opts.result, '']
    endif
  endif

  return v:lua.vim.provider.node.detect()
endfunction

function! provider#node#Require(host) abort
  return v:lua.vim.provider.node.require(a:host)
endfunction

function! provider#node#Call(method, args) abort
  return v:lua.vim.provider.node.call(a:method, a:args)
endfunction

let s:err = ''
let [s:prog, s:_] = provider#node#Detect()
let g:loaded_node_provider = empty(s:prog) ? 1 : 2
call v:lua.vim.provider.node.start()
