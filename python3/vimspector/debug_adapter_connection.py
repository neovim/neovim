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
import contextlib
from functools import partial

_logger = logging.getLogger( __name__ )


def SetUpLogging():
  handler = logging.FileHandler( os.path.expanduser( '~/.vimspector.log' ) )
  _logger.setLevel( logging.DEBUG )
  handler.setFormatter(
    logging.Formatter( '%(asctime)s - %(levelname)s - %(message)s' ) )
  _logger.addHandler( handler )


def SetUpScratchBuffer( buf ):
  buf.options[ 'buftype' ] = 'nofile'
  buf.options[ 'swapfile' ] = False
  buf.options[ 'modifiable' ] = False
  buf.options[ 'modified' ] = False
  buf.options[ 'readonly' ] = True
  buf.options[ 'buflisted' ] = False
  buf.options[ 'bufhidden' ] = 'wipe'


@contextlib.contextmanager
def ModifiableScratchBuffer( buf ):
  buf.options[ 'modifiable' ] = True
  buf.options[ 'readonly' ] = False
  try:
    yield
  finally:
    buf.options[ 'modifiable' ] = False
    buf.options[ 'readonly' ] = True


@contextlib.contextmanager
def RestoreCursorPosition():
  current_pos = vim.current.window.cursor
  try:
    yield
  finally:
    vim.current.window.cursor = current_pos


class VariablesView( object ):
  def __init__( self, session, buf ):
    self._buf = buf
    self._session = session
    self._scopes = []
    self._line_to_variable = {}

    vim.current.buffer = buf
    vim.command(
      'nnoremap <buffer> <CR> :call vimspector#ExpandVariable()<CR>' )

    SetUpScratchBuffer( self._buf )

  def LoadScopes( self, frame ):
    def scopes_consumer( message ):
      self._scopes = []
      for scope in message[ 'body' ][ 'scopes' ]:
        self._scopes.append( scope )
        self._session._DoRequest( partial( self._ConsumeVariables, scope ), {
          'command': 'variables',
          'arguments': {
            'variablesReference': scope[ 'variablesReference' ]
          },
        } )

      self._DrawScopes()

    self._session._DoRequest( scopes_consumer, {
      'command': 'scopes',
      'arguments': {
        'frameId': frame[ 'id' ]
      },
    } )

  def ExpandVariable( self ):
    current_line = vim.current.window.cursor[ 0 ]
    if current_line not in self._line_to_variable:
      vim.command( 'echo "No variable found on that line"' )
      return

    variable = self._line_to_variable[ current_line ]
    if '_variables' in variable:
      del variable[ '_variables' ]
      self._DrawScopes()
    else:
      self._session._DoRequest( partial( self._ConsumeVariables, variable ), {
        'command': 'variables',
        'arguments': {
          'variablesReference': variable[ 'variablesReference' ]
        },
      } )

  def _DrawVariables( self, variables, indent ):
    for variable in variables:
      self._buf.append(
        '{indent}{icon} {name} ({type_}): {value}'.format(
          indent = ' ' * indent,
          icon = '+' if ( variable[ 'variablesReference' ] > 0 and
                          '_variables' not in variable ) else '-',
          name = variable[ 'name' ],
          type_ = variable.get( 'type', '<unknown type>' ),
          value = variable[ 'value' ] ) )
      self._line_to_variable[ len( self._buf ) ] = variable

      if '_variables' in variable:
        self._DrawVariables( variable[ '_variables' ], indent + 2 )

  def _DrawScopes( self ):
    with RestoreCursorPosition():
      with ModifiableScratchBuffer( self._buf ):
        self._buf[:] = None
        for scope in self._scopes:
          self._buf.append( 'Scope: ' + scope[ 'name' ] )
          if '_variables' in scope:
            indent = 2
            self._DrawVariables( scope[ '_variables' ], indent )


  def _ConsumeVariables( self, parent, message ):
    for variable in message[ 'body' ][ 'variables' ]:
      if '_variables' not in parent:
        parent[ '_variables' ] = []

      parent[ '_variables' ].append( variable )

    self._DrawScopes()


class DebugSession( object ):
  def __init__( self, channel_send_func ):
    SetUpLogging()

    self._connection = DebugAdapterConnection( self,
                                               channel_send_func )
    self._next_message_id = 0
    self._outstanding_requests = dict()

    self._uiTab = None
    self._codeWindow = None
    self._callStackBuffer = None
    self._threadsBuffer = None
    self._outputBuffer = None

    # TODO: How to hold/model this data
    self._currentThread = None
    self._currentFrame = None

    self._SetUpUI()


  def _SetUpUI( self ):
    vim.command( 'tabnew' )
    self._uiTab = vim.current.tabpage
    self._codeWindow = vim.current.window

    vim.command( 'nnoremenu WinBar.Continute :call vimspector#Continue()<CR>' )
    vim.command( 'nnoremenu WinBar.Next :call vimspector#StepOver()<CR>' )
    vim.command( 'nnoremenu WinBar.Step :call vimspector#StepInto()<CR>' )
    vim.command( 'nnoremenu WinBar.Finish :call vimspector#StepOut()<CR>' )
    vim.command( 'nnoremenu WinBar.Pause :call vimspector#Pause()<CR>' )

    vim.command( 'vspl' )
    vim.command( 'enew' )

    self._threadsBuffer = vim.current.buffer
    vim.command( 'spl' )
    vim.command( 'enew' )
    self._callStackBuffer = vim.current.buffer
    vim.command( 'spl' )
    vim.command( 'enew' )
    self._outputBuffer = vim.current.buffer
    vim.command( 'spl' )
    vim.command( 'enew' )
    self._variablesView = VariablesView( self, vim.current.buffer )

    SetUpScratchBuffer( self._threadsBuffer )
    SetUpScratchBuffer( self._callStackBuffer )
    SetUpScratchBuffer( self._outputBuffer )

  def _LoadFrame( self, frame ):
    vim.current.window = self._codeWindow
    buffer_number = vim.eval( 'bufnr( "{0}", 1 )'.format(
      frame[ 'source' ][ 'path' ]  ) )

    try:
      vim.command( 'bu {0}'.format( buffer_number ) )
    except vim.error as e:
      if 'E325' not in str( e ):
        raise

    self._codeWindow.cursor = ( frame[ 'line' ], frame[ 'column' ] )
    self._variablesView.LoadScopes( frame )

  def OnChannelData( self, data ):
    self._connection.OnData( data )

  def Start( self ):
    self._Initialise()

  def Stop( self ):
    self._DoRequest( None, {
      'command': 'disconnect',
      'arguments': {
        'terminateDebugee': True
      },
    } )

  def StepOver( self ):
    self._DoRequest( None, {
      'command': 'next',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def StepInto( self ):
    self._DoRequest( None, {
      'command': 'stepIn',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def StepOut( self ):
    self._DoRequest( None, {
      'command': 'stepOut',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def Continue( self ):
    self._DoRequest( None, {
      'command': 'continue',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def Pause( self ):
    self._DoRequest( None, {
      'command': 'pause',
      'arguments': {
        'threadId': self._currentThread
      },
    } )

  def ExpandVariable( self ):
    self._variablesView.ExpandVariable()

  def _DoRequest( self, handler, msg ):
    this_id = self._next_message_id
    self._next_message_id += 1

    msg[ 'seq' ] = this_id
    msg[ 'type' ] = 'request'

    self._outstanding_requests[ this_id ] = handler
    self._connection.SendMessage( msg )

  def _Initialise( self ):
    def handler( message ) :
      self._DoRequest( None, {
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


    self._DoRequest( handler, {
      'command': 'initialize',
      'arguments': {
        'adapterID': 'cppdbg',
        'linesStartAt1': True,
        'columnsStartAt1': True,
        'pathFormat': 'path',
      },
    } )

  def _OnEvent_initialized( self, message ):
    self._DoRequest( None, {
      'command': 'setFunctionBreakpoints',
      'arguments': {
        'breakpoints': [
          { 'name': 'main' }
        ]
      },
    } )

    self._DoRequest( None, {
      'command': 'configurationDone',
    } )


  def _OnEvent_output( self, message ):
    with ModifiableScratchBuffer( self._outputBuffer ):
      t = [ message[ 'body' ][ 'category' ] + ':' + '-' * 20 ]
      t += message[ 'body' ][ 'output' ].splitlines()
      self._outputBuffer.append( t, 0 )


  def _OnEvent_stopped( self, message ):
    self._currentThread = message[ 'body' ][ 'threadId' ]

    def threads_printer( message ):
      with ModifiableScratchBuffer( self._threadsBuffer ):
        self._threadsBuffer[:] = None
        self._threadsBuffer.append( 'Threads: ' )

        for thread in message[ 'body' ][ 'threads' ]:
          self._threadsBuffer.append(
            'Thread {0}: {1}'.format( thread[ 'id' ], thread[ 'name' ] ) )

    self._DoRequest( threads_printer, {
      'command': 'threads',
    } )

    def stacktrace_printer( message ):
      with ModifiableScratchBuffer( self._callStackBuffer ):
        self._callStackBuffer.options[ 'modifiable' ] = True
        self._callStackBuffer.options[ 'readonly' ] = False

        self._callStackBuffer[:] = None
        self._callStackBuffer.append( 'Backtrace: ' )

        stackFrames = message[ 'body' ][ 'stackFrames' ]

        if stackFrames:
          self._currentFrame = stackFrames[ 0 ]
        else:
          self._currentFrame = None

        for frame in stackFrames:
          self._callStackBuffer.append(
            '{0}: {1}@{2}:{3}'.format( frame[ 'id' ],
                                       frame[ 'name' ],
                                       frame[ 'source' ][ 'name' ],
                                       frame[ 'line' ] ) )

      self._LoadFrame( self._currentFrame )

    self._DoRequest( stacktrace_printer, {
      'command': 'stackTrace',
      'arguments': {
        'threadId': self._currentThread,
      }
    } )

  def OnMessageReceived( self, message ):
    if message[ 'type' ] == 'response':
      handler = self._outstanding_requests.pop( message[ 'request_seq' ] )

      if message[ 'success' ]:
        if handler:
          handler( message )
      else:
        raise RuntimeError( 'Request failed: {0}'.format(
          message[ 'message' ] ) )

    elif message[ 'type' ] == 'event':
      method = '_OnEvent_' + message[ 'event' ]
      if method in dir( self ) and getattr( self, method ):
        getattr( self, method )( message )


class DebugAdapterConnection( object ):
  def __init__( self, handler, send_func ):
    self._Write = send_func
    self._SetState( 'READ_HEADER' )
    self._buffer = bytes()
    self._handler = handler

  def _SetState( self, state ):
    self._state = state
    if state == 'READ_HEADER':
      self._headers = {}

  def SendMessage( self, msg ):
    msg = json.dumps( msg )
    data = 'Content-Length: {0}\r\n\r\n{1}'.format( len( msg ), msg )

    _logger.debug( 'Sending: {0}'.format( data ) )
    self._Write( data )

  def OnData( self, data ):
    data = bytes( data, 'utf-8' )
    _logger.debug( 'Received ({0}/{1}): {2},'.format( type( data ),
                                                      len( data ),
                                                      data ) )

    self._buffer += data

    while True:
      if self._state == 'READ_HEADER':
        data = self._ReadHeaders()

      if self._state == 'READ_BODY':
        self._ReadBody()
      else:
        break

      if self._state != 'READ_HEADER':
        # We ran out of data whilst reading the body. Await more data.
        break


  def _ReadHeaders( self ):
    headers = self._buffer.split( bytes( '\r\n\r\n', 'utf-8' ), 1 )

    if len( headers ) > 1:
      for header_line in headers[ 0 ].split( bytes( '\r\n', 'utf-8' ) ):
        if header_line.strip():
          key, value = str( header_line, 'utf-8' ).split( ':', 1 )
          self._headers[ key ] = value

      # Chomp (+4 for the 2 newlines which were the separator)
      # self._buffer = self._buffer[ len( headers[ 0 ] ) + 4 : ]
      self._buffer = headers[ 1 ]
      self._SetState( 'READ_BODY' )
      return

    # otherwise waiting for more data

  def _ReadBody( self ):
    content_length = int( self._headers[ 'Content-Length' ] )

    if len( self._buffer ) < content_length:
      # Need more data
      assert self._state == 'READ_BODY'
      return

    payload = str( self._buffer[ : content_length  ], 'utf-8' )
    self._buffer = self._buffer[ content_length : ]

    message = json.loads( payload )

    _logger.debug( 'Message received: {0}'.format( message ) )

    self._handler.OnMessageReceived( message )

    self._SetState( 'READ_HEADER' )
