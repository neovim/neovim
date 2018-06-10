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
                         output,
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
    self._stackTraceView = None
    self._variablesView = None
    self._outputView = None

    self._next_sign_id = SIGN_ID_OFFSET

    # FIXME: This needs redesigning. There are a number of problems:
    #  - breakpoints don't have to be line-wisw (e.g. method/exception)
    #  - when the server moves/changes a breakpoint, this is not updated,
    #    leading to them getting out of sync
    #  - the split of responsibility between this object and the CodeView is
    #    messy and ill-defined.
    self._line_breakpoints = defaultdict( list )
    self._func_breakpoints = []
    self._configuration = None

    vim.command( 'sign define vimspectorBP text==> texthl=Error' )
    vim.command( 'sign define vimspectorBPDisabled text=!> texthl=Warning' )

  def ToggleBreakpoint( self ):
    line, column = vim.current.window.cursor
    file_name = vim.current.buffer.name

    if not file_name:
      return

    found_bp = False
    for index, bp in enumerate( self._line_breakpoints[ file_name]  ):
      if bp[ 'line' ] == line:
        found_bp = True
        if bp[ 'state' ] == 'ENABLED':
          bp[ 'state' ] = 'DISABLED'
        else:
          if 'sign_id' in bp:
            vim.command( 'sign unplace {0}'.format( bp[ 'sign_id' ] ) )
          del self._line_breakpoints[ file_name ][ index ]

    if not found_bp:
      self._line_breakpoints[ file_name ].append( {
        'state': 'ENABLED',
        'line': line,
        # 'sign_id': <filled in when placed>,
        #
        # Used by other breakpoint types:
        # 'condition': ...,
        # 'hitCondition': ...,
        # 'logMessage': ...
      } )

    self._UpdateUIBreakpoints()

  def _UpdateUIBreakpoints( self ):
    if self._connection:
      self._SendBreakpoints()
    else:
      self._ShowBreakpoints()

  def AddFunctionBreakpoint( self, function ):
    self._func_breakpoints.append( {
        'state': 'ENABLED',
        'function': function,
    } )

    # TODO: We don't really have aanything to update here, but if we're going to
    # have a UI list of them we should update that at this point
    self._UpdateUIBreakpoints()

  def Start( self, configuration = None ):
    self._configuration = None
    self._adapter = None

    launch_config_file = utils.PathToConfigFile( '.vimspector.json' )

    if not launch_config_file:
      utils.UserMessage( 'Unable to find .vimspector.json. You need to tell '
                         'vimspector how to launch your application' )
      return

    with open( launch_config_file, 'r' ) as f:
      database = json.load( f )

    launch_config = database.get( 'configurations' )
    adapters = database.get( 'adapters' )

    if not configuration:
      if len( launch_config ) == 1:
        configuration = next( iter( launch_config.keys() ) )
      else:
        configuration = utils.SelectFromList( 'Which launch configuration?',
                                              list( launch_config.keys() ) )

    if not configuration:
      return

    adapter = launch_config[ configuration ].get( 'adapter' )
    if isinstance( adapter, str ):
      adapter = adapters.get( adapter )

    self._StartWithConfiguration( launch_config[ configuration ],
                                  adapter )

  def _StartWithConfiguration( self, configuration, adapter ):
    self._configuration = configuration
    self._adapter = adapter

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
    # FIXME: For some reason this doesn't work when run from the WinBar. It just
    # beeps and doesn't display the config selector. One option is to just not
    # display the selector and restart with the same opitons.
    self._StartWithConfiguration( self._configuration, self._adapter )

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
      self._outputView.Reset()
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

  def EvaluateConsole( self, expression ):
    self._outputView.Evaluate( self._stackTraceView.GetCurrentFrame(),
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

  def ShowOutput( self, category ):
    self._outputView.ShowOutput( category )

  def _SetUpUI( self ):
    vim.command( 'tabnew' )
    self._uiTab = vim.current.tabpage

    # Code window
    self._codeView = code.CodeView( vim.current.window )

    # Call stack
    with utils.TemporaryVimOptions( { 'splitright':  False,
                                      'equalalways': False, } ):
      vim.command( 'topleft 50vspl' )
      vim.command( 'enew' )
      self._stackTraceView = stack_trace.StackTraceView( self,
                                                         self._connection,
                                                         vim.current.buffer )

    with utils.TemporaryVimOptions( { 'splitbelow':  False,
                                      'eadirection': 'ver',
                                      'equalalways': True } ):
      # Watches
      vim.command( 'spl' )
      vim.command( 'enew' )
      watch_win = vim.current.window

      # Variables
      vim.command( 'spl' )
      vim.command( 'enew' )
      vars_win = vim.current.window

      self._variablesView = variables.VariablesView( self._connection,
                                                     vars_win,
                                                     watch_win )


    with utils.TemporaryVimOption( 'splitbelow', True ):
      vim.current.window = self._codeView._window

      # Output/logging
      vim.command( '10spl' )
      vim.command( 'enew' )
      self._outputView = output.OutputView( self._connection,
                                            vim.current.window )

  def ClearCurrentFrame( self ):
    self.SetCurrentFrame( None )

  def SetCurrentFrame( self, frame ):
    if not self._codeView.SetCurrentFrame( frame ):
      return False

    if frame:
      self._variablesView.LoadScopes( frame )
      self._variablesView.EvaluateWatches()
    else:
      self._stackTraceView.Clear()
      self._variablesView.Clear()

    return True

  def _StartDebugAdapter( self ):
    self._logger.info( 'Starting debug adapter with: {0}'.format( json.dumps(
      self._adapter ) ) )

    channel_send_func = vim.bindeval(
      "vimspector#internal#job#StartDebugSession( {0} )".format(
        json.dumps( self._adapter ) ) )

    self._connection = debug_adapter_connection.DebugAdapterConnection(
      self,
      channel_send_func )

    self._logger.info( 'Debug Adapter Started' )

    vim.command( 'augroup vimspector_cleanup' )
    vim.command(   'autocmd!' )
    vim.command(   'autocmd VimLeavePre * py3 _vimspector_session.CloseDown()' )
    vim.command( 'augroup END' )

  def CloseDown( self ):
    state = { 'done': False }

    def handler( self ):
      state[ 'done' ] = True

    self._connection.DoRequest( handler, {
      'command': 'disconnect',
      'arguments': {
        'terminateDebugee': True
      },
    } )

    tries = 0
    while not state[ 'done' ] and tries < 10:
      tries = tries + 1
      vim.eval( 'vimspector#internal#job#ForceRead()' )

    vim.eval( 'vimspector#internal#job#StopDebugSession()' )

  def _StopDebugAdapter( self, callback = None ):
    def handler( message ):
      vim.eval( 'vimspector#internal#job#StopDebugSession()' )

      vim.command( 'au! vimspector_cleanup' )

      self._connection.Reset()
      self._connection = None
      self._stackTraceView.ConnectionClosed()
      self._variablesView.ConnectionClosed()
      self._outputView.ConnectionClosed()
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
    elif atttach_config[ 'pidSelect' ] == 'none':
      return

    raise ValueError( 'Unrecognised pidSelect {0}'.format(
      atttach_config[ 'pidSelect' ] ) )


  def _Initialise( self ):
    adapter_config = self._adapter
    launch_config = self._configuration[ 'configuration' ]

    if launch_config.get( 'request' ) == "attach":
      self._SelectProcess( adapter_config, launch_config )

    self._connection.DoRequest( None, {
      'command': 'initialize',
      'arguments': {
        'adapterID': adapter_config.get( 'name', 'adapter' ),
        'clientID': 'vimspector',
        'clientName': 'vimspector',
        'linesStartAt1': True,
        'columnsStartAt1': True,
        'locale': 'en_GB',
        'pathFormat': 'path',
        'supportsVariableType': True,
        'supportsVariablePaging': False,
        'supportsRunInTerminalRequest': True
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
    if 'body' not in message:
      return
    self._codeView.AddBreakpoints( source, message[ 'body' ][ 'breakpoints' ] )
    self._codeView.ShowBreakpoints()

  def OnEvent_initialized( self, message ):
    self._SendBreakpoints()
    self._connection.DoRequest(
      lambda msg: self._stackTraceView.LoadThreads( True ),
      {
        'command': 'configurationDone',
      }
    )

  def OnEvent_thread( self, message ):
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
    for breakpoints in self._line_breakpoints.values():
      for bp in breakpoints:
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0}'.format( bp[ 'sign_id' ] ) )
          del bp[ 'sign_id' ]

  def _SendBreakpoints( self ):
    self._codeView.ClearBreakpoints()

    for file_name, line_breakpoints in self._line_breakpoints.items():
      breakpoints = []
      for bp in line_breakpoints:
        if bp[ 'state' ] != 'ENABLED':
          continue

        if 'sign_id' in bp:
          vim.command( 'sign unplace {0}'.format( bp[ 'sign_id' ] ) )
          del bp[ 'sign_id' ]

        breakpoints.append( { 'line': bp[ 'line' ] } )

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
            'breakpoints': breakpoints,
          },
          'sourceModified': False, # TODO: We can actually check this
        }
      )

    self._connection.DoRequest(
      functools.partial( self._UpdateBreakpoints, None ),
      {
        'command': 'setFunctionBreakpoints',
        'arguments': {
          'breakpoints': [
            { 'name': bp[ 'function' ] }
            for bp in self._func_breakpoints if bp[ 'state' ] == 'ENABLED'
          ],
        }
      }
    )

  def _ShowBreakpoints( self ):
    for file_name, line_breakpoints in self._line_breakpoints.items():
      for bp in line_breakpoints:
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0}'.format( bp[ 'sign_id' ] ) )
        else:
          bp[ 'sign_id' ] = self._next_sign_id
          self._next_sign_id += 1

        vim.command(
          'sign place {0} line={1} name={2} file={3}'.format(
            bp[ 'sign_id' ] ,
            bp[ 'line' ],
            'vimspectorBP' if bp[ 'state' ] == 'ENABLED'
                           else 'vimspectorBPDisabled',
            file_name ) )

  def OnEvent_output( self, message ):
    if self._outputView:
      self._outputView.OnOutput( message[ 'body' ] )

  def OnEvent_stopped( self, message ):
    event = message[ 'body' ]

    utils.UserMessage( 'Paused in thread {0} due to {1}'.format(
      event.get( 'threadId', '<unknown>' ),
      event.get( 'description', event.get( 'reason', '' ) ) ) )

    self._stackTraceView.OnStopped( event )
