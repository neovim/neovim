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

import vim

from vimspector import utils


class StackTraceView( object ):
  def __init__( self, session, connection, buf ):
    self._buf = buf
    self._session = session
    self._connection = connection

    self._currentThread = None
    self._currentFrame = None

    self._threads = []

    utils.SetUpScratchBuffer( self._buf, 'vimspector.StackTrace' )
    vim.current.buffer = self._buf
    vim.command( 'nnoremap <buffer> <CR> :call vimspector#GoToFrame()<CR>' )

    self._line_to_frame = {}
    self._line_to_thread = {}


  def GetCurrentThreadId( self ):
    return self._currentThread

  def GetCurrentFrame( self ):
    return self._currentFrame

  def Clear( self ):
    self._currentFrame = None
    self._currentThread = None
    self._threads = []
    with utils.ModifiableScratchBuffer( self._buf ):
      self._buf[:] = None

  def ConnectionClosed( self ):
    self.Clear()
    self._connection = None

  def Reset( self ):
    self.Clear()
    # TODO: delete the buffer ?

  def LoadThreads( self, infer_current_frame ):
    def consume_threads( message ):
      self._threads.clear()

      for thread in message[ 'body' ][ 'threads' ]:
        self._threads.append( thread )

        if infer_current_frame and thread[ 'id' ] == self._currentThread:
          self._LoadStackTrace( thread, True )
        elif infer_current_frame and not self._currentThread:
          self._currentThread = thread[ 'id' ]
          self._LoadStackTrace( thread, True )

      self._DrawThreads()

    self._connection.DoRequest( consume_threads, {
      'command': 'threads',
    } )

  def _DrawThreads( self ):
    self._line_to_frame.clear()
    self._line_to_thread.clear()

    with utils.ModifiableScratchBuffer( self._buf ):
      self._buf[:] = None

      for thread in self._threads:
        icon = '+' if '_frames' not in thread else '-'

        self._buf.append( '{0} Thread: {1}'.format( icon, thread[ 'name' ] ) )
        self._line_to_thread[ len( self._buf ) ] = thread

        self._DrawStackTrace( thread )

  def _LoadStackTrace( self, thread, infer_current_frame ):
    def consume_stacktrace( message ):
      thread[ '_frames' ] = message[ 'body' ][ 'stackFrames' ]
      if infer_current_frame:
        for frame in thread[ '_frames' ]:
          if frame[ 'source' ]:
            self._JumpToFrame( frame )
            break

      self._DrawThreads()

    self._connection.DoRequest( consume_stacktrace, {
      'command': 'stackTrace',
      'arguments': {
        'threadId': thread[ 'id' ],
      }
    } )

  def ExpandFrameOrThread( self ):
    if vim.current.buffer != self._buf:
      return

    current_line = vim.current.window.cursor[ 0 ]

    if current_line in self._line_to_frame:
      self._JumpToFrame( self._line_to_frame[ current_line ] )
    elif current_line in self._line_to_thread:
      thread = self._line_to_thread[ current_line ]
      if '_frames' in thread:
        del thread[ '_frames' ]
        with utils.RestoreCursorPosition():
          self._DrawThreads()
      else:
        self._LoadStackTrace( thread, False )

  def _JumpToFrame( self, frame ):
    self._currentFrame = frame
    self._session.SetCurrentFrame( self._currentFrame )

  def OnStopped( self, event ):
    if 'threadId' in event:
      self._currentThread = event[ 'threadId' ]
    elif event.get( 'allThreadsStopped', False ) and self._threads:
      self._currentThread = self._threads[ 0 ][ 'id' ]

    if self._currentThread:
      for thread in self._threads:
        if thread[ 'id' ] == self._currentThread:
          self._LoadStackTrace( thread, True )
          return

    self.LoadThreads( True )

  def OnThreadEvent( self, event ):
    if event[ 'reason' ] == 'started' and self._currentThread is None:
      self.LoadThreads( True )

  def Continue( self ):
    if not self._currentThread:
      utils.UserMessage( 'No current thread', persist = True )
      return

    self._session._connection.DoRequest( None, {
      'command': 'continue',
      'arguments': {
        'threadId': self._currentThread,
      },
    } )

    self._session.ClearCurrentFrame()
    self.LoadThreads( True )

  def Pause( self ):
    if not self._currentThread:
      utils.UserMessage( 'No current thread', persist = True )
      return

    self._session._connection.DoRequest( None, {
      'command': 'pause',
      'arguments': {
        'threadId': self._currentThread,
      },
    } )

  def _DrawStackTrace( self, thread ):
    if '_frames' not in thread:
      return

    stackFrames = thread[ '_frames' ]

    for frame in stackFrames:
      if frame[ 'source' ]:
        source = frame[ 'source' ]
      else:
        source = { 'name': '<unknown>' }

      self._buf.append(
        '  {0}: {1}@{2}:{3}'.format( frame[ 'id' ],
                                     frame[ 'name' ],
                                     source[ 'name' ],
                                     frame[ 'line' ] ) )
      self._line_to_frame[ len( self._buf ) ] = frame
