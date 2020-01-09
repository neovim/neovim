" vimspector - A multi-language debugging system for Vim
" Copyright 2018 Ben Jackson
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"   http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.


" Boilerplate {{{
let s:save_cpo = &cpoptions
set cpoptions&vim
" }}}


call vimspector#internal#state#Reset()

function! vimspector#Launch() abort
  py3 _vimspector_session.Start()
endfunction

function! vimspector#LaunchWithSettings( settings ) abort
  py3 _vimspector_session.Start( launch_variables = vim.eval( 'a:settings' ) )
endfunction

function! vimspector#Reset() abort
  py3 _vimspector_session.Reset()
endfunction

function! vimspector#Restart() abort
  py3 _vimspector_session.Restart()
endfunction

function! vimspector#ClearBreakpoints() abort
  py3 _vimspector_session.ClearBreakpoints()
endfunction

function! vimspector#ToggleBreakpoint() abort
  py3 _vimspector_session.ToggleBreakpoint()
endfunction

function! vimspector#AddFunctionBreakpoint( function ) abort
  py3 _vimspector_session.AddFunctionBreakpoint( vim.eval( 'a:function' ) )
endfunction

function! vimspector#StepOver() abort
  py3 _vimspector_session.StepOver()
endfunction

function! vimspector#StepInto() abort
  py3 _vimspector_session.StepInto()
endfunction

function! vimspector#StepOut() abort
  py3 _vimspector_session.StepOut()
endfunction

function! vimspector#Continue() abort
  py3 _vimspector_session.Continue()
endfunction

function! vimspector#Pause() abort
  py3 _vimspector_session.Pause()
endfunction

function! vimspector#Stop() abort
  py3 _vimspector_session.Stop()
endfunction

function! vimspector#ExpandVariable() abort
  py3 _vimspector_session.ExpandVariable()
endfunction

function! vimspector#DeleteWatch() abort
  py3 _vimspector_session.DeleteWatch()
endfunction

function! vimspector#GoToFrame() abort
  py3 _vimspector_session.ExpandFrameOrThread()
endfunction

function! vimspector#AddWatch( expr ) abort
  py3 _vimspector_session.AddWatch( vim.eval( 'a:expr' ) )
endfunction

function! vimspector#AddWatchPrompt( expr ) abort
  stopinsert
  setlocal nomodified
  call vimspector#AddWatch( a:expr )
endfunction

function! vimspector#Evaluate( expr ) abort
  py3 _vimspector_session.ShowOutput( 'Console' )
  py3 _vimspector_session.EvaluateConsole( vim.eval( 'a:expr' ) )
endfunction

function! vimspector#EvaluateConsole( expr ) abort
  stopinsert
  setlocal nomodified
  py3 _vimspector_session.EvaluateConsole( vim.eval( 'a:expr' ) )
endfunction

function! vimspector#ShowOutput( category ) abort
  py3 _vimspector_session.ShowOutput( vim.eval( 'a:category' ) )
endfunction

function! vimspector#ListBreakpoints() abort
  py3 _vimspector_session.ListBreakpoints()
endfunction

function! vimspector#CompleteOutput( ArgLead, CmdLine, CursorPos ) abort
  let buffers = py3eval( '_vimspector_session.GetOutputBuffers()' )
  return join( buffers, "\n" )
endfunction

function! vimspector#CompleteExpr( ArgLead, CmdLine, CursorPos ) abort
  return []
endfunction

" Boilerplate {{{
let &cpoptions=s:save_cpo
unlet s:save_cpo
" }}}
