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
import json
import os
import functools

from collections import defaultdict

from vimspector import ( code,
                         debug_adapter_connection,
                         stack_trace,
                         utils,
                         variables )

SIGN_ID_OFFSET = 10005000


class DebugSession( object ):
  def __init__( self ):
    self._logger = logging.getLogger( __name__ )
    utils.SetUpLogging( self._logger )

    self._connection = None

    self._uiTab = None
    self._outputBuffer = None # TODO: Need something less terrible here
    self._stackTraceView = None
    self._variablesView = None

    self._next_sign_id = SIGN_ID_OFFSET

    # TODO: Move to code view and consolidate into user-requested-breakpoints,
    # and actual breakpoints ?
    self._breakpoints = defaultdict( dict )
    self._configuration = None

    vim.command( 'sign define vimspectorBP text==> texthl=Error' )
    vim.command( 'sign define vimspectorBPDisabled text=!> texthl=Warning' )

  def ToggleBreakpoint( self ):
    # TODO: Move this to the code view. Problem is that CodeView doesn't exist
    # until we have initialised.
    line, column = vim.current.window.cursor
    file_name = vim.current.buffer.name

    if not file_name:
      return

    if line in self._breakpoints[ file_name ]:
      bp = self._breakpoints[ file_name ][ line ]
      if bp[ 'state' ] == 'ENABLED':
        bp[ 'state' ] = 'DISABLED'
      else:
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0}'.format( bp[ 'sign_id' ] ) )
        del self._breakpoints[ file_name ][ line ]
    else:
      self._breakpoints[ file_name ][ line ] = {
        'state': 'ENABLED',
        # 'condition': ...,
        # 'hitCondition': ...,
        # 'logMessage': ...
      }

    if self._connection:
      self._SendBreakpoints()
    else:
      self._ShowBreakpoints()


  def Start( self, configuration = None ):
    launch_config_file = utils.PathToConfigFile( '.vimspector.json' )

    if not launch_config_file:
      utils.UserMessage( 'Unable to find .vimspector.json. You need to tell '
                         'vimspector how to launch your application' )
      return

    with open( launch_config_file, 'r' ) as f:
      launch_config = json.load( f )

    if not configuration:
      if len( launch_config ) == 1:
        configuration = next( iter( launch_config.keys() ) )
      else:
        configuration = utils.SelectFromList( 'Which launch configuration?',
                                              list( launch_config.keys() ) )

    if not configuration:
      return

    self._configuration = launch_config[ configuration ]

    def start():
      self._StartDebugAdapter()
      self._Initialise()

      if not self._uiTab:
        self._SetUpUI()
      else:
        vim.current.tabpage = self._uiTab
        self._stackTraceView._connection = self._connection
        self._variablesView._connection = self._connection

    if self._connection:
      self._StopDebugAdapter( start )
      return

    start()

  def Restart( self ):
    # TODO: There is a restart message but isn't always supported.
    self.Start()

  def OnChannelData( self, data ):
    if self._connection:
      self._connection.OnData( data )

  def OnChannelClosed( self ):
    self._connection = None

  def Stop( self ):
    self._StopDebugAdapter()

  def Reset( self ):
    if self._connection:
      self._StopDebugAdapter( lambda: self._Reset() )
    else:
      self._Reset()

  def _Reset( self ):
    self._RemoveBreakpoints()

    if self._uiTab:
      self._stackTraceView.Reset()
      self._variablesView.Reset()
      vim.current.tabpage = self._uiTab
      vim.command( 'tabclose' )

    vim.eval( 'vimspector#internal#job#Reset()' )
    vim.eval( 'vimspector#internal#state#Reset()' )

  def StepOver( self ):
    if self._stackTraceView.GetCurrentThreadId() is None:
      return

    self._connection.DoRequest( None, {
      'command': 'next',
      'arguments': {
        'threadId': self._stackTraceView.GetCurrentThreadId()
      },
    } )

  def StepInto( self ):
    if self._stackTraceView.GetCurrentThreadId() is None:
      return

    self._connection.DoRequest( None, {
      'command': 'stepIn',
      'arguments': {
        'threadId': self._stackTraceView.GetCurrentThreadId()
      },
    } )

  def StepOut( self ):
    if self._stackTraceView.GetCurrentThreadId() is None:
      return

    self._connection.DoRequest( None, {
      'command': 'stepOut',
      'arguments': {
        'threadId': self._stackTraceView.GetCurrentThreadId()
      },
    } )

  def Continue( self ):
    self._stackTraceView.Continue()

  def Pause( self ):
    self._stackTraceView.Pause()

  def ExpandVariable( self ):
    self._variablesView.ExpandVariable()

  def AddWatch( self, expression ):
    self._variablesView.AddWatch( self._stackTraceView.GetCurrentFrame(),
                                  expression )

  def DeleteWatch( self ):
    self._variablesView.DeleteWatch()

  def ShowBalloon( self, winnr, expression ):
    if self._stackTraceView.GetCurrentFrame() is None:
      return

    if winnr == int( self._codeView._window.number ):
      self._variablesView.ShowBalloon( self._stackTraceView.GetCurrentFrame(),
                                       expression )
    else:
      self._logger.debug( 'Winnr {0} is not the code window {1}'.format(
        winnr,
        self._codeView._window.number ) )

  def ExpandFrameOrThread( self ):
    self._stackTraceView.ExpandFrameOrThread()

  def _SetUpUI( self ):
    vim.command( 'tabnew' )
    self._uiTab = vim.current.tabpage

    # Code window
    self._codeView = code.CodeView( vim.current.window )

    # Call stack
    vim.command( 'vspl' )
    vim.command( 'enew' )
    self._stackTraceView = stack_trace.StackTraceView( self,
                                                       self._connection,
                                                       vim.current.buffer )

    with utils.TemporaryVimOption( 'eadirection', 'ver' ):
      with utils.TemporaryVimOption( 'equalalways', 1 ):
        # Output/logging
        vim.command( 'spl' )
        vim.command( 'enew' )
        self._outputBuffer = vim.current.buffer
        utils.SetUpScratchBuffer( self._outputBuffer, 'vimspector.Console' )

        # Variables
        vim.command( 'spl' )
        vim.command( 'enew' )
        self._variablesView = variables.VariablesView( self._connection,
                                                       vim.current.buffer )

  def ClearCurrentFrame( self ):
    self.SetCurrentFrame( None )

  def SetCurrentFrame( self, frame ):
    self._codeView.SetCurrentFrame( frame )

    if frame:
      self._variablesView.LoadScopes( frame )
      self._variablesView.EvaluateWatches()
    else:
      self._stackTraceView.Clear()
      self._variablesView.Clear()

  def _StartDebugAdapter( self ):
    self._logger.info( 'Starting debug adapter with: {0}'.format( json.dumps(
      self._configuration[ 'adapter' ] ) ) )

    channel_send_func = vim.bindeval(
      "vimspector#internal#job#StartDebugSession( {0} )".format(
        json.dumps( self._configuration[ 'adapter' ] ) ) )

    self._connection = debug_adapter_connection.DebugAdapterConnection(
      self,
      channel_send_func )

    self._logger.info( 'Debug Adapter Started' )

  def _StopDebugAdapter( self, callback = None ):
    def handler( message ):
      vim.eval( 'vimspector#internal#job#StopDebugSession()' )
      self._connection.Reset()
      self._connection = None
      self._stackTraceView.ConnectionClosed()
      self._variablesView.ConnectionClosed()
      if callback:
        callback()

    self._connection.DoRequest( handler, {
      'command': 'disconnect',
      'arguments': {
        'terminateDebugee': True
      },
    } )


  def _SelectProcess( self, adapter_config, launch_config ):
    atttach_config = adapter_config[ 'attach' ]
    if atttach_config[ 'pidSelect' ] == 'ask':
      pid = utils.AskForInput( 'Enter PID to attach to: ' )
      launch_config[ atttach_config[ 'pidProperty' ] ] = pid
      return

    raise ValueError( 'Unrecognised pidSelect {0}'.format(
      atttach_config[ 'pidSelect' ] ) )


  def _Initialise( self ):
    adapter_config = self._configuration[ 'adapter' ]
    launch_config = self._configuration[ 'configuration' ]

    if 'attach' in adapter_config:
      self._SelectProcess( adapter_config, launch_config )

    self._connection.DoRequest( None, {
      'command': 'initialize',
      'arguments': {
        'adapterID': adapter_config.get( 'name', 'adapter' ),
        'linesStartAt1': True,
        'columnsStartAt1': True,
        'pathFormat': 'path',
      },
    } )

    # FIXME: name is mandatory. Forcefully add it (we should really use the
    # _actual_ name, but that isn't actually remembered at this point)
    if 'name' not in launch_config:
      launch_config[ 'name' ] = 'test'

    self._connection.DoRequest( None, {
      'command': launch_config[ 'request' ],
      'arguments': launch_config
    } )

  def _UpdateBreakpoints( self, source, message ):
    self._codeView.AddBreakpoints( source, message[ 'body' ][ 'breakpoints' ] )
    self._codeView.ShowBreakpoints()

  def OnEvent_initialized( self, message ):
    self._codeView.ClearBreakpoints()
    self._SendBreakpoints()

  def OnEvent_thread( self, message ):
    if message[ 'body' ][ 'reason' ] == 'started':
      pass
    elif message[ 'body' ][ 'reason' ] == 'exited':
      pass

    self._stackTraceView.OnThreadEvent( message[ 'body' ] )

  def OnEvent_breakpoint( self, message ):
    reason = message[ 'body' ][ 'reason' ]
    bp = message[ 'body' ][ 'breakpoint' ]
    if reason == 'changed':
      self._codeView.UpdateBreakpoint( bp )
    elif reason == 'new':
      self._codeView.AddBreakpoints( None, bp )
    else:
      utils.UserMessage(
        'Unrecognised breakpoint event (undocumented): {0}'.format( reason ),
        persist = True )

  def Clear( self ):
    self._codeView.Clear()
    self._stackTraceView.Clear()
    self._variablesView.Clear()

  def OnEvent_terminated( self, message ):
    utils.UserMessage( "The program was terminated because: {0}".format(
      message.get( 'body', {} ).get( 'reason', "No specific reason" ) ) )

    self.Clear()

  def _RemoveBreakpoints( self ):
    for file_name, line_breakpoints in self._breakpoints.items():
      for line, bp in line_breakpoints.items():
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0}'.format( bp[ 'sign_id' ] ) )
          del bp[ 'sign_id' ]

  def _SendBreakpoints( self ):
    for file_name, line_breakpoints in self._breakpoints.items():
      breakpoints = []
      lines = []
      for line, bp in line_breakpoints.items():
        if bp[ 'state' ] != 'ENABLED':
          continue

        if 'sign_id' in bp:
          vim.command( 'sign unplace {0}'.format( bp[ 'sign_id' ] ) )
          del bp[ 'sign_id' ]

        breakpoints.append( { 'line': line } )
        lines.append( line )

      source = {
        'name': os.path.basename( file_name ),
        'path': file_name,
      }

      self._connection.DoRequest(
        functools.partial( self._UpdateBreakpoints, source ),
        {
          'command': 'setBreakpoints',
          'arguments': {
            'source': source,
            'breakpoints': breakpoints
          },
          'lines':  lines,
          'sourceModified': False, # TODO: We can actually check this
        }
      )

    self._connection.DoRequest( None, {
      'command': 'configurationDone',
    } )

  def _ShowBreakpoints( self ):
    for file_name, line_breakpoints in self._breakpoints.items():
      for line, bp in line_breakpoints.items():
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0}'.format( bp[ 'sign_id' ] ) )
        else:
          bp[ 'sign_id' ] = self._next_sign_id
          self._next_sign_id += 1

        vim.command(
          'sign place {0} line={1} name={2} file={3}'.format(
            bp[ 'sign_id' ] ,
            line,
            'vimspectorBP' if bp[ 'state' ] == 'ENABLED'
                           else 'vimspectorBPDisabled',
            file_name ) )

  def OnEvent_output( self, message ):
    with utils.ModifiableScratchBuffer( self._outputBuffer ):
      t = [ message[ 'body' ][ 'category' ] + ':' + '-' * 20 ]
      t += message[ 'body' ][ 'output' ].splitlines()
      self._outputBuffer.append( t, 0 )

  def OnEvent_stopped( self, message ):
    event = message[ 'body' ]

    utils.UserMessage( 'Paused in thread {0} due to {1}'.format(
      event.get( 'threadId', '<unknown>' ),
      event.get( 'description', event[ 'reason' ] ) ) )

    self._stackTraceView.OnStopped( event )
