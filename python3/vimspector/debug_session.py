# vimspector - A multi-language debugging system for Vim
# Copyright 2018 Ben Jackson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import logging
import vim

from vimspector import ( code,
                         debug_adapter_connection,
                         stack_trace,
                         utils,
                         variables )

_logger = logging.getLogger( __name__ )


class DebugSession( object ):
  def __init__( self, channel_send_func ):
    utils.SetUpLogging()

    self._connection = debug_adapter_connection.DebugAdapterConnection(
      self,
      channel_send_func )

    self._uiTab = None
    self._threadsBuffer = None
    self._outputBuffer = None

    self._currentThread = None
    self._currentFrame = None

    self._SetUpUI()

  def _SetUpUI( self ):
    vim.command( 'tabnew' )
    self._uiTab = vim.current.tabpage

    # Code window
    self._codeView = code.CodeView( vim.current.window )

    # Threads
    vim.command( '50vspl' )
    vim.command( 'enew' )
    self._threadsBuffer = vim.current.buffer
    utils.SetUpScratchBuffer( self._threadsBuffer )

    with utils.TemporaryVimOption( 'eadirection', 'ver' ):
      with utils.TemporaryVimOption( 'equalalways', 1 ):
        # Call stack
        vim.command( 'spl' )
        vim.command( 'enew' )
        self._stackTraceView = stack_trace.StackTraceView( self,
                                                           self._connection,
                                                           vim.current.buffer )

        # Output/logging
        vim.command( 'spl' )
        vim.command( 'enew' )
        self._outputBuffer = vim.current.buffer
        utils.SetUpScratchBuffer( self._outputBuffer )

        # Variables
        vim.command( 'spl' )
        vim.command( 'enew' )
        self._variablesView = variables.VariablesView( self._connection,
                                                       vim.current.buffer )


  def SetCurrentFrame( self, frame ):
    self._currentFrame = frame
    self._codeView.SetCurrentFrame( frame )
    self._variablesView.LoadScopes( frame )


  def OnChannelData( self, data ):
    self._connection.OnData( data )

  def Start( self ):
    self._Initialise()

  def Stop( self ):
    self._codeView.Clear()

    self._connection.DoRequest( None, {
      'command': 'disconnect',
      'arguments': {
        'terminateDebugee': True
      },
    } )

  def StepOver( self ):
    self._connection.DoRequest( None, {
      'command': 'next',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def StepInto( self ):
    self._connection.DoRequest( None, {
      'command': 'stepIn',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def StepOut( self ):
    self._connection.DoRequest( None, {
      'command': 'stepOut',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def Continue( self ):
    self._connection.DoRequest( None, {
      'command': 'continue',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def Pause( self ):
    self._connection.DoRequest( None, {
      'command': 'pause',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def ExpandVariable( self ):
    self._variablesView.ExpandVariable()

  def GoToFrame( self ):
    self._stackTraceView.GoToFrame()

  def _Initialise( self ):
    def handler( message ) :
      self._connection.DoRequest( None, {
        'command': 'launch',

        'arguments': {
          "target": "/Users/Ben/.vim/bundle/vimspector/support/test/cpp/"
                     "simple_c_program/test",
          "args": [],
          "cwd": "/Users/ben",
          "stopOnEntry": True,
          'lldbmipath':
          '/Users/ben/.vscode/extensions/ms-vscode.cpptools-0.17.1/'
              'debugAdapters/lldb/bin/lldb-mi',
        }
      } )


    self._connection.DoRequest( handler, {
      'command': 'initialize',
      'arguments': {
        'adapterID': 'cppdbg',  # Apparently only MS debugger cares
        'linesStartAt1': True,
        'columnsStartAt1': True,
        'pathFormat': 'path',
      },
    } )

  def OnEvent_initialized( self, message ):
    self._connection.DoRequest( None, {
      'command': 'setFunctionBreakpoints',
      'arguments': {
        'breakpoints': [
          { 'name': 'main' }
        ]
      },
    } )

    self._connection.DoRequest( None, {
      'command': 'configurationDone',
    } )

  def OnEvent_output( self, message ):
    with utils.ModifiableScratchBuffer( self._outputBuffer ):
      t = [ message[ 'body' ][ 'category' ] + ':' + '-' * 20 ]
      t += message[ 'body' ][ 'output' ].splitlines()
      self._outputBuffer.append( t, 0 )

  def OnEvent_stopped( self, message ):
    self._currentThread = message[ 'body' ][ 'threadId' ]

    def threads_printer( message ):
      with utils.ModifiableScratchBuffer( self._threadsBuffer ):
        self._threadsBuffer[:] = None
        self._threadsBuffer.append( 'Threads: ' )

        for thread in message[ 'body' ][ 'threads' ]:
          self._threadsBuffer.append(
            'Thread {0}: {1}'.format( thread[ 'id' ], thread[ 'name' ] ) )

    self._connection.DoRequest( threads_printer, {
      'command': 'threads',
    } )

    self._stackTraceView.LoadStackTrace( self._currentThread )
