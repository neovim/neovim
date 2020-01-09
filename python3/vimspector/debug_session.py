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

import glob
import json
import logging
import os
import shlex
import subprocess
import traceback
import vim

from vimspector import ( breakpoints,
                         code,
                         debug_adapter_connection,
                         install,
                         output,
                         stack_trace,
                         utils,
                         variables )

VIMSPECTOR_HOME = os.path.abspath( os.path.join( os.path.dirname( __file__ ),
                                                 '..',
                                                 '..' ) )

# cache of what the user entered for any option we ask them
USER_CHOICES = {}


class DebugSession( object ):
  def __init__( self ):
    self._logger = logging.getLogger( __name__ )
    utils.SetUpLogging( self._logger )

    self._logger.info( "**** INITIALISING NEW VIMSPECTOR SESSION ****" )
    self._logger.info( 'VIMSPECTOR_HOME = %s', VIMSPECTOR_HOME )
    self._logger.info( 'gadgetDir = %s',
                       install.GetGadgetDir( VIMSPECTOR_HOME,
                                             install.GetOS() ) )

    self._uiTab = None
    self._stackTraceView = None
    self._variablesView = None
    self._outputView = None
    self._breakpoints = breakpoints.ProjectBreakpoints()

    self._run_on_server_exit = None

    self._ResetServerState()

  def _ResetServerState( self ):
    self._connection = None
    self._configuration = None
    self._init_complete = False
    self._launch_complete = False
    self._on_init_complete_handlers = []
    self._server_capabilities = {}

  def Start( self, launch_variables = {} ):
    self._logger.info( "User requested start debug session with %s",
                       launch_variables )
    self._configuration = None
    self._adapter = None

    current_file = utils.GetBufferFilepath( vim.current.buffer )

    launch_config_file = utils.PathToConfigFile(
      '.vimspector.json',
      os.path.dirname( current_file ) )

    if not launch_config_file:
      utils.UserMessage( 'Unable to find .vimspector.json. You need to tell '
                         'vimspector how to launch your application.' )
      return

    with open( launch_config_file, 'r' ) as f:
      database = json.load( f )

    configurations = database.get( 'configurations' )
    adapters = {}

    glob.glob( install.GetGadgetDir( VIMSPECTOR_HOME, install.GetOS() ) )
    for gadget_config_file in PathsToAllGadgetConfigs( VIMSPECTOR_HOME,
                                                       current_file ):
      self._logger.debug( f'Reading gadget config: {gadget_config_file}' )
      if gadget_config_file and os.path.exists( gadget_config_file ):
        with open( gadget_config_file, 'r' ) as f:
          adapters.update( json.load( f ).get( 'adapters' ) or {} )

    adapters.update( database.get( 'adapters' ) or {} )

    if 'configuration' in launch_variables:
      configuration_name = launch_variables.pop( 'configuration' )
    elif len( configurations ) == 1:
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
    #
    # Additional vars as defined by VSCode:
    #
    # ${workspaceFolder} - the path of the folder opened in VS Code
    # ${workspaceFolderBasename} - the name of the folder opened in VS Code
    #                              without any slashes (/)
    # ${file} - the current opened file
    # ${relativeFile} - the current opened file relative to workspaceFolder
    # ${fileBasename} - the current opened file's basename
    # ${fileBasenameNoExtension} - the current opened file's basename with no
    #                              file extension
    # ${fileDirname} - the current opened file's dirname
    # ${fileExtname} - the current opened file's extension
    # ${cwd} - the task runner's current working directory on startup
    # ${lineNumber} - the current selected line number in the active file
    # ${selectedText} - the current selected text in the active file
    # ${execPath} - the path to the running VS Code executable

    def relpath( p, relative_to ):
      if not p:
        return ''
      return os.path.relpath( p, relative_to )

    def splitext( p ):
      if not p:
        return [ '', '' ]
      return os.path.splitext( p )

    self._variables = {
      'dollar': '$', # HACK. Hote '$$' also works.
      'workspaceRoot': self._workspace_root,
      'workspaceFolder': self._workspace_root,
      'gadgetDir': install.GetGadgetDir( VIMSPECTOR_HOME, install.GetOS() ),
      'file': current_file,
      'relativeFile': relpath( current_file, self._workspace_root ),
      'fileBasename': os.path.basename( current_file ),
      'fileBasenameNoExtension':
        splitext( os.path.basename( current_file ) )[ 0 ],
      'fileDirname': os.path.dirname( current_file ),
      'fileExtname': splitext( os.path.basename( current_file ) )[ 1 ],
      # NOTE: this is the window-local cwd for the current window, *not* Vim's
      # working directory.
      'cwd': os.getcwd(),
    }
    self._variables.update(
      utils.ParseVariables( adapter.get( 'variables', {} ),
                            self._variables,
                            USER_CHOICES ) )
    self._variables.update(
      utils.ParseVariables( configuration.get( 'variables', {} ),
                            self._variables,
                            USER_CHOICES ) )

    # Pretend that vars passed to the launch command were typed in by the user
    # (they may have been in theory)
    # TODO: Is it right that we do this _after_ ParseVariables, rather than
    # before ?
    USER_CHOICES.update( launch_variables )
    self._variables.update( launch_variables )

    utils.ExpandReferencesInDict( configuration,
                                  self._variables,
                                  USER_CHOICES )
    utils.ExpandReferencesInDict( adapter,
                                  self._variables,
                                  USER_CHOICES )

    if not adapter:
      utils.UserMessage( 'No adapter configured for {}'.format(
        configuration_name ), persist=True )
      return

    self._StartWithConfiguration( configuration, adapter )

  def _StartWithConfiguration( self, configuration, adapter ):
    def start():
      self._configuration = configuration
      self._adapter = adapter

      self._logger.info( 'Configuration: %s',
                         json.dumps( self._configuration ) )
      self._logger.info( 'Adapter: %s',
                         json.dumps( self._adapter ) )

      if not self._uiTab:
        self._SetUpUI()
      else:
        vim.current.tabpage = self._uiTab

      self._StartDebugAdapter()
      self._Initialise()

      self._stackTraceView.ConnectionUp( self._connection )
      self._variablesView.ConnectionUp( self._connection )
      self._outputView.ConnectionUp( self._connection )
      self._breakpoints.ConnectionUp( self._connection )

      class Handler( breakpoints.ServerBreakpointHandler ):
        def __init__( self, codeView ):
          self.codeView = codeView

        def ClearBreakpoints( self ):
          self.codeView.ClearBreakpoints()

        def AddBreakpoints( self, source, message ):
          if 'body' not in message:
            return
          self.codeView.AddBreakpoints( source,
                                        message[ 'body' ][ 'breakpoints' ] )

      self._breakpoints.SetBreakpointsHandler( Handler( self._codeView ) )

    if self._connection:
      self._logger.debug( "_StopDebugAdapter with callback: start" )
      self._StopDebugAdapter( start )
      return

    start()

  def Restart( self ):
    # TODO: There is a restart message but isn't always supported.
    # FIXME: For some reason this doesn't work when run from the WinBar. It just
    # beeps and doesn't display the config selector. One option is to just not
    # display the selector and restart with the same opitons.
    if not self._configuration or not self._adapter:
      return self.Start()

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
    self._logger.debug( "Stop debug adapter with no callback" )
    self._StopDebugAdapter()

  def Reset( self ):
    if self._connection:
      self._logger.debug( "Stop debug adapter with callback : self._Reset()" )
      self._StopDebugAdapter( lambda: self._Reset() )
    else:
      self._Reset()

  def _Reset( self ):
    self._logger.info( "Debugging complete." )
    if self._uiTab:
      self._logger.debug( "Clearing down UI with stack_trace: %s",
                          traceback.format_stack() )
      vim.current.tabpage = self._uiTab
      self._stackTraceView.Reset()
      self._variablesView.Reset()
      self._outputView.Reset()
      self._codeView.Reset()
      vim.command( 'tabclose!' )
      self._stackTraceView = None
      self._variablesView = None
      self._outputView = None
      self._codeView = None
      self._uiTab = None

    # make sure that we're displaying signs in any still-open buffers
    self._breakpoints.UpdateUI()

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
    """Proxy: ballonexpr -> variables.ShowBallon"""
    frame = self._stackTraceView.GetCurrentFrame()
    # Check if RIP is in a frame
    if frame is None:
      self._logger.debug( 'Balloon: Not in a stack frame' )
      return ''

    # Check if cursor in code window
    if winnr != int( self._codeView._window.number ):
      self._logger.debug( 'Winnr %s is not the code window %s',
                          winnr,
                          self._codeView._window.number )
      return ''

    # Return variable aware function
    return self._variablesView.ShowBalloon( frame, expression )

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
      self._variablesView.SetSyntax( self._codeView.current_syntax )
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

    self._logger.info( 'Starting debug adapter with: %s',
                       json.dumps( self._adapter ) )

    self._init_complete = False
    self._on_init_complete_handlers = []
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

    vim.vars[ '_vimspector_adapter_spec' ] = self._adapter
    channel_send_func = vim.bindeval(
        "vimspector#internal#{}#StartDebugSession( "
        "  g:_vimspector_adapter_spec "
        ")".format( self._connection_type ) )

    if channel_send_func is None:
      self._logger.error( "Unable to start debug server" )
    else:
      self._connection = debug_adapter_connection.DebugAdapterConnection(
        self,
        channel_send_func )

      self._logger.info( 'Debug Adapter Started' )

  def _StopDebugAdapter( self, callback = None ):
    def handler( *args ):
      if callback:
        self._logger.debug( "Setting server exit handler before disconnect" )
        assert not self._run_on_server_exit
        self._run_on_server_exit = callback

      vim.eval( 'vimspector#internal#{}#StopDebugSession()'.format(
        self._connection_type ) )

    arguments = {}
    if self._server_capabilities.get( 'supportTerminateDebuggee' ):
      arguments[ 'terminateDebugee' ] = True

    self._connection.DoRequest( handler, {
      'command': 'disconnect',
      'arguments': arguments,
    }, failure_handler = handler, timeout = 5000 )

    # TODO: Use the 'tarminate' request if supportsTerminateRequest set

  
  def _PrepareAttach( self, adapter_config, launch_config ):
    atttach_config = adapter_config.get( 'attach' )

    if not atttach_config:
      return

    if 'remote' in atttach_config:
      # FIXME: We almost want this to feed-back variables to be expanded later,
      # e.g. expand variables when we use them, not all at once. This would
      # remove the whole %PID% hack.
      remote = atttach_config[ 'remote' ]
      ssh = self._GetSSHCommand( remote )

      # FIXME: Why does this not use self._GetCommands ?
      cmd = ssh + remote[ 'pidCommand' ]

      self._logger.debug( 'Getting PID: %s', cmd )
      pid = subprocess.check_output( cmd ).decode( 'utf-8' ).strip()
      self._logger.debug( 'Got PID: %s', pid )

      if not pid:
        # FIXME: We should raise an exception here or something
        utils.UserMessage( 'Unable to get PID', persist = True )
        return

      if 'initCompleteCommand' in remote:
        initcmd = ssh + remote[ 'initCompleteCommand' ][ : ]
        for index, item in enumerate( initcmd ):
          initcmd[ index ] = item.replace( '%PID%', pid )

        self._on_init_complete_handlers.append(
          lambda: subprocess.check_call( initcmd ) )

      commands = self._GetCommands( remote, 'attach' )

      for command in commands:
        cmd = ssh + command[ : ]

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
      ssh = self._GetSSHCommand( remote )
      commands = self._GetCommands( remote, 'run' )

      for index, command in enumerate( commands ):
        cmd = ssh + command[ : ]
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
        self._outputView.RunJobWithOutput( 'Remote{}'.format( index ),
                                           full_cmd )


  def _GetSSHCommand( self, remote ):
    ssh = [ 'ssh' ] + remote.get( 'ssh', {} ).get( 'args', [] )
    if 'account' in remote:
      ssh.append( remote[ 'account' ] + '@' + remote[ 'host' ] )
    else:
      ssh.append( remote[ 'host' ] )

    return ssh


  def _GetCommands( self, remote, pfx ):
    commands = remote.get( pfx + 'Commands', None )

    if isinstance( commands, list ):
      return commands
    elif commands is not None:
      raise ValueError( "Invalid commands; must be list" )

    command = remote[ pfx + 'Command' ]

    if isinstance( command, str ):
      command = shlex.split( command )

    if not isinstance( command, list ):
      raise ValueError( "Invalid command; must be list/string" )

    if not command:
      raise ValueError( 'Could not determine commands for ' + pfx )

    return [ command ]

  def _Initialise( self ):
    # For a good explaination as to why this sequence is the way it is, see
    # https://github.com/microsoft/vscode/issues/4902#issuecomment-368583522
    #
    # In short, we do what VSCode does:
    # 1. Send the initialize request and wait for the reply
    # 2a. When we recieve the initialize reply, send the launch/attach request
    # 2b. When we receive the initialized notification, send the breakpoints
    #    - if supportsConfigurationDoneRequest, send it
    #    - else, send the empty exception breakpoints request
    # 3. When we have recieved both the receive the launch/attach reply *and*
    #    the connfiguration done reply (or, if we didn't send one, a response to
    #    the empty exception breakpoints request), we request threads
    # 4. The threads response triggers things like scopes and triggers setting
    #    the current frame.
    #
    def handle_initialize_response( msg ):
      self._server_capabilities = msg.get( 'body' ) or {}
      self._breakpoints.SetServerCapabilities( self._server_capabilities )
      self._Launch()

    self._connection.DoRequest( handle_initialize_response, {
      'command': 'initialize',
      'arguments': {
        'adapterID': self._adapter.get( 'name', 'adapter' ),
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
    launch_config = {}
    launch_config.update( self._adapter.get( 'configuration', {} ) )
    launch_config.update( self._configuration[ 'configuration' ] )

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
    # As it turns out this is due to a bug in gdbserver which means that
    # attachment doesn't work due to sending the signal to the process group
    # leader rather than the process. The workaround is to manually SIGTRAP the
    # PID.
    #
    if self._launch_complete and self._init_complete:
      for h in self._on_init_complete_handlers:
        h()
      self._on_init_complete_handlers = []

      self._stackTraceView.LoadThreads( True )


  def OnEvent_capabilities( self, msg ):
    self._server_capabilities.update(
      ( msg.get( 'body' ) or {} ).get( 'capabilities' ) or {} )


  def OnEvent_initialized( self, message ):
    def onBreakpointsDone():
      if self._server_capabilities.get( 'supportsConfigurationDoneRequest' ):
        self._connection.DoRequest(
          lambda msg: self._OnInitializeComplete(),
          {
            'command': 'configurationDone',
          }
        )
      else:
        self._OnInitializeComplete()

    self._codeView.ClearBreakpoints()
    self._breakpoints.SetConfiguredBreakpoints(
      self._configuration.get( 'breakpoints', {} ) )
    self._breakpoints.SendBreakpoints( onBreakpointsDone )

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

    if not params.get( 'cwd' ) :
      params[ 'cwd' ] = self._workspace_root
      self._logger.debug( 'Defaulting working directory to %s',
                          params[ 'cwd' ] )

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
    self._logger.info( "The server has terminated with status %s",
                       status )
    self.Clear()

    self._connection.Reset()
    self._stackTraceView.ConnectionClosed()
    self._variablesView.ConnectionClosed()
    self._outputView.ConnectionClosed()
    self._breakpoints.ConnectionClosed()

    self._ResetServerState()

    if self._run_on_server_exit:
      self._logger.debug( "Running server exit handler" )
      self._run_on_server_exit()
    else:
      self._logger.debug( "No server exit handler" )

  def OnEvent_terminated( self, message ):
    # We will handle this when the server actually exists
    utils.UserMessage( "Debugging was terminated by the server." )

  def OnEvent_output( self, message ):
    if self._outputView:
      self._outputView.OnOutput( message[ 'body' ] )

  def OnEvent_stopped( self, message ):
    event = message[ 'body' ]
    reason = event.get( 'reason' ) or '<protocol error>'
    description = event.get( 'description' )
    text = event.get( 'text' )

    if description:
      explanation = description + '(' + reason + ')'
    else:
      explanation = reason

    if text:
      explanation += ': ' + text

    msg = 'Paused in thread {0} due to {1}'.format(
      event.get( 'threadId', '<unknown>' ),
      explanation )
    utils.UserMessage( msg, persist = True )

    if self._outputView:
      self._outputView.Print( 'server', msg )

    self._stackTraceView.OnStopped( event )

  def ListBreakpoints( self ):
    return self._breakpoints.ListBreakpoints()

  def ToggleBreakpoint( self ):
    return self._breakpoints.ToggleBreakpoint()

  def ClearBreakpoints( self ):
    if self._connection:
      self._codeView.ClearBreakpoints()

    return self._breakpoints.ClearBreakpoints()

  def AddFunctionBreakpoint( self, function ):
    return self._breakpoints.AddFunctionBreakpoint( function )


def PathsToAllGadgetConfigs( vimspector_base, current_file ):
  yield install.GetGadgetConfigFile( vimspector_base )
  for p in sorted( glob.glob(
    os.path.join( install.GetGadgetConfigDir( vimspector_base ),
                  '*.json' ) ) ):
    yield p

  yield utils.PathToConfigFile( '.gadgets.json',
                                os.path.dirname( current_file ) )
