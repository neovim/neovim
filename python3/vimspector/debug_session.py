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
import subprocess

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

    self._uiTab = None
    self._stackTraceView = None
    self._variablesView = None
    self._outputView = None

    self._run_on_server_exit = None

    self._next_sign_id = SIGN_ID_OFFSET

    # FIXME: This needs redesigning. There are a number of problems:
    #  - breakpoints don't have to be line-wise (e.g. method/exception)
    #  - when the server moves/changes a breakpoint, this is not updated,
    #    leading to them getting out of sync
    #  - the split of responsibility between this object and the CodeView is
    #    messy and ill-defined.
    self._line_breakpoints = defaultdict( list )
    self._func_breakpoints = []

    self._ResetServerState()

    vim.command( 'sign define vimspectorBP text==> texthl=Error' )
    vim.command( 'sign define vimspectorBPDisabled text=!> texthl=Warning' )

  def _ResetServerState( self ):
    self._connection = None
    self._configuration = None
    self._init_complete = False
    self._launch_complete = False

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

  def Start( self, launch_variables = {} ):
    self._configuration = None
    self._adapter = None

    launch_config_file = utils.PathToConfigFile( '.vimspector.json' )

    if not launch_config_file:
      utils.UserMessage( 'Unable to find .vimspector.json. You need to tell '
                         'vimspector how to launch your application' )
      return

    with open( launch_config_file, 'r' ) as f:
      database = json.load( f )

    configurations = database.get( 'configurations' )
    adapters = database.get( 'adapters' )

    if len( configurations ) == 1:
      configuration_name = next( iter( configurations.keys() ) )
    else:
      configuration_name = utils.SelectFromList(
        'Which launch configuration?',
        sorted( list( configurations.keys() ) ) )

    if not configuration_name or configuration_name not in configurations:
      return

    self._workspace_root = os.path.dirname( launch_config_file )

    configuration = configurations[ configuration_name ]
    adapter = configuration.get( 'adapter' )
    if isinstance( adapter, str ):
      adapter = adapters.get( adapter )

    # TODO: Do we want some form of persistence ? e.g. self._staticVariables,
    # set from an api call like SetLaunchParam( 'var', 'value' ), perhaps also a
    # way to load .vimspector.local.json which just sets variables
    self._variables = {
      'dollar': '$', # HACK
      'workspaceRoot': self._workspace_root
    }
    self._variables.update( adapter.get( 'variables', {} ) )
    self._variables.update( configuration.get( 'variables', {} ) )
    self._variables.update( launch_variables )

    utils.ExpandReferencesInDict( configuration, self._variables )
    utils.ExpandReferencesInDict( adapter, self._variables )

    if not adapter:
      utils.UserMessage( 'No adapter configured for {}'.format(
        configuration_name ), persist=True  )
      return

    self._StartWithConfiguration( configuration, adapter )

  def _StartWithConfiguration( self, configuration, adapter ):
    def start():
      self._configuration = configuration
      self._adapter = adapter

      self._logger.info( 'Configuration: {0}'.format( json.dumps(
        self._configuration ) ) )
      self._logger.info( 'Adapter: {0}'.format( json.dumps(
        self._adapter ) ) )

      if not self._uiTab:
        self._SetUpUI()
      else:
        vim.current.tabpage = self._uiTab

      self._StartDebugAdapter()
      self._Initialise()

      self._stackTraceView.ConnectionUp( self._connection )
      self._variablesView.ConnectionUp( self._connection )
      self._outputView.ConnectionUp( self._connection )

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

  def OnServerStderr( self, data ):
    self._logger.info( "Server stderr: %s", data )
    if self._outputView:
      self._outputView.Print( 'server', data )


  def OnRequestTimeout( self, timer_id ):
    if self._connection:
      self._connection.OnRequestTimeout( timer_id )

  def OnChannelClosed( self ):
    # TODO: Not calld
    self._connection = None

  def Stop( self ):
    self._StopDebugAdapter()

  def Reset( self ):
    if self._connection:
      self._StopDebugAdapter( lambda: self._Reset() )
    else:
      self._Reset()

  def _Reset( self ):
    if self._uiTab:
      self._stackTraceView.Reset()
      self._variablesView.Reset()
      self._outputView.Reset()
      self._codeView.Reset()
      vim.current.tabpage = self._uiTab
      vim.command( 'tabclose!' )
      self._uiTab = None

    # make sure that we're displaying signs in any still-open buffers
    self._UpdateUIBreakpoints()

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
    if self._connection:
      self._stackTraceView.Continue()
    else:
      self.Start()

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
    if self._connection:
      utils.UserMessage( 'The connection is already created. Please try again',
                         persist = True )
      return

    self._logger.info( 'Starting debug adapter with: {0}'.format( json.dumps(
      self._adapter ) ) )

    self._init_complete = False
    self._launch_complete = False
    self._run_on_server_exit = None

    self._connection_type = 'job'
    if 'port' in self._adapter:
      self._connection_type = 'channel'

      if self._adapter[ 'port' ] == 'ask':
        port = utils.AskForInput( 'Enter port to connect to: ' )
        self._adapter[ 'port' ] = port

    # TODO: Do we actually need to copy and update or does Vim do that?
    env = os.environ.copy()
    if 'env' in self._adapter:
      env.update( self._adapter[ 'env' ] )
    self._adapter[ 'env' ] = env

    if 'cwd' not in self._adapter:
      self._adapter[ 'cwd' ] = os.getcwd()

    channel_send_func = vim.bindeval(
      "vimspector#internal#{}#StartDebugSession( {} )".format(
        self._connection_type,
        json.dumps( self._adapter ) ) )

    if channel_send_func is None:
      self._logger.error( "Unable to start debug server" )
    else:
      self._connection = debug_adapter_connection.DebugAdapterConnection(
        self,
        channel_send_func )

      self._logger.info( 'Debug Adapter Started' )

  def _StopDebugAdapter( self, callback = None ):
    def handler( *args ):
      vim.eval( 'vimspector#internal#{}#StopDebugSession()'.format(
        self._connection_type ) )

      if callback:
        assert not self._run_on_server_exit
        self._run_on_server_exit = callback

    self._connection.DoRequest( handler, {
      'command': 'disconnect',
      'arguments': {
        'terminateDebugee': True
      },
    }, failure_handler = handler, timeout = 5000 )

  def _PrepareAttach( self, adapter_config, launch_config ):

    atttach_config = adapter_config[ 'attach' ]

    if 'remote' in atttach_config:
      remote = atttach_config[ 'remote' ]
      ssh = [ 'ssh' ]

      if 'account' in remote:
        ssh.append( remote[ 'account' ] + '@' + remote[ 'host' ] )
      else:
        ssh.append( remote[ 'host' ] )

      cmd = ssh + remote[ 'pidCommand' ]

      self._logger.debug( 'Getting PID: %s', cmd )
      pid = subprocess.check_output( ssh + remote[ 'pidCommand' ] ).decode(
        'utf-8' ).strip()
      self._logger.debug( 'Got PID: %s', pid )

      cmd = ssh + remote[ 'attachCommand' ][:]

      for index, item in enumerate( cmd ):
        cmd[ index ] = item.replace( '%PID%', pid )

      self._logger.debug( 'Running remote app: %s', cmd )
      self._outputView.RunJobWithOutput( 'Remote', cmd )
    else:
      if atttach_config[ 'pidSelect' ] == 'ask':
        pid = utils.AskForInput( 'Enter PID to attach to: ' )
        launch_config[ atttach_config[ 'pidProperty' ] ] = pid
        return
      elif atttach_config[ 'pidSelect' ] == 'none':
        return

      raise ValueError( 'Unrecognised pidSelect {0}'.format(
        atttach_config[ 'pidSelect' ] ) )


  def _PrepareLaunch( self, command_line, adapter_config, launch_config ):
    run_config = adapter_config.get( 'launch', {} )

    if 'remote' in run_config:
      remote = run_config[ 'remote' ]
      ssh = [ 'ssh' ]
      if 'account' in remote:
        ssh.append( remote[ 'account' ] + '@' + remote[ 'host' ] )
      else:
        ssh.append( remote[ 'host' ] )

      cmd = ssh + remote[ 'runCommand' ][:]
      full_cmd = []
      for item in cmd:
        if isinstance( command_line, list ):
          if item == '%CMD%':
            full_cmd.extend( command_line )
          else:
            full_cmd.append( item )
        else:
          full_cmd.append( item.replace( '%CMD%', command_line ) )

      self._logger.debug( 'Running remote app: %s', full_cmd )
      self._outputView.RunJobWithOutput( 'Remote', full_cmd )


  def _Initialise( self ):
    adapter_config = self._adapter
    self._connection.DoRequest( lambda msg: self._Launch(), {
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


  def OnFailure( self, reason, message ):
    msg = "Request for '{}' failed: {}".format( message[ 'command' ],
                                                reason )
    self._outputView.Print( 'server', msg )

  def _Launch( self ):
    self._logger.debug( "LAUNCH!" )
    adapter_config = self._adapter
    launch_config = self._configuration[ 'configuration' ]

    request = self._configuration.get(
      'remote-request',
      launch_config.get( 'request', 'launch' ) )

    if request == "attach":
      self._PrepareAttach( adapter_config, launch_config )
    elif request == "launch":
      # FIXME: This cmdLine hack is not fun. 
      self._PrepareLaunch( self._configuration.get( 'remote-cmdLine', [] ),
                           adapter_config,
                           launch_config )

    # FIXME: name is mandatory. Forcefully add it (we should really use the
    # _actual_ name, but that isn't actually remembered at this point)
    if 'name' not in launch_config:
      launch_config[ 'name' ] = 'test'

    self._connection.DoRequest(
      lambda msg: self._OnLaunchComplete(),
      {
        'command': launch_config[ 'request' ],
        'arguments': launch_config
      }
    )


  def _UpdateBreakpoints( self, source, message ):
    if 'body' not in message:
      return
    self._codeView.AddBreakpoints( source, message[ 'body' ][ 'breakpoints' ] )
    self._codeView.ShowBreakpoints()

  def _OnLaunchComplete( self ):
    self._launch_complete = True
    self._LoadThreadsIfReady()

  def _OnInitializeComplete( self ):
    self._init_complete = True
    self._LoadThreadsIfReady()

  def _LoadThreadsIfReady( self ):
    # NOTE: You might think we should only load threads on a stopped event,
    # but the spec is clear:
    #
    #   After a successful launch or attach the development tool requests the
    #   baseline of currently existing threads with the threads request and
    #   then starts to listen for thread events to detect new or terminated
    #   threads.
    #
    # Of course, specs are basically guidelines. MS's own cpptools simply
    # doesn't respond top threads request when attaching via gdbserver. At
    # least it would apear that way.
    #
    if self._launch_complete and self._init_complete:
      self._stackTraceView.LoadThreads( True )

  def OnEvent_initialized( self, message ):
    self._SendBreakpoints()
    self._connection.DoRequest(
      lambda msg: self._OnInitializeComplete(),
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

  def OnRequest_runInTerminal( self, message ):
    params = message[ 'arguments' ]

    if 'cwd' not in params:
      params[ 'cwd' ] = self._workspace_root

    buffer_number = self._codeView.LaunchTerminal( params )

    response = {
      'processId': vim.eval( 'job_info( term_getjob( {} ) )'
                             '.process'.format( buffer_number ) )
    }

    self._connection.DoResponse( message, None, response )

  def OnEvent_exited( self, message ):
    utils.UserMessage( 'The debugee exited with status code: {}'.format(
      message[ 'body' ][ 'exitCode' ] ) )

  def OnEvent_process( self, message ):
    utils.UserMessage( 'The debugee was started: {}'.format(
      message[ 'body' ][ 'name' ] ) )

  def OnEvent_module( self, message ):
    pass

  def OnEvent_continued( self, message ):
    pass

  def Clear( self ):
    self._codeView.Clear()
    self._stackTraceView.Clear()
    self._variablesView.Clear()

  def OnServerExit( self, status ):
    self.Clear()

    self._connection.Reset()
    self._stackTraceView.ConnectionClosed()
    self._variablesView.ConnectionClosed()
    self._outputView.ConnectionClosed()

    self._ResetServerState()

    if self._run_on_server_exit:
      self._run_on_server_exit()

  def OnEvent_terminated( self, message ):
    # We will handle this when the server actually exists
    utils.UserMessage( "Debugging was terminated." )

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
    msg = 'Paused in thread {0} due to {1}'.format(
      event.get( 'threadId', '<unknown>' ),
      event.get( 'description', event.get( 'reason', '' ) ) )
    utils.UserMessage( msg, persist = True )

    if self._outputView:
      self._outputView.Print( 'server', msg )

    self._stackTraceView.OnStopped( event )
