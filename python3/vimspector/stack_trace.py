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

    utils.SetUpScratchBuffer( self._buf, 'vimspector.StackTrace' )
    vim.current.buffer = self._buf
    vim.command( 'nnoremap <buffer> <CR> :call vimspector#GoToFrame()<CR>' )

    self._line_to_frame = {}

  def Clear( self ):
    with utils.ModifiableScratchBuffer( self._buf ):
      self._buf[:] = None

  def ConnectionClosed( self ):
    self.Clear()
    self._connection = None

  def Reset( self ):
    self.Clear()
    # TODO: delete the buffer ?

  def LoadStackTrace( self, thread_id ):
    self._connection.DoRequest( self._PrintStackTrace, {
      'command': 'stackTrace',
      'arguments': {
        'threadId': thread_id,
      }
    } )

  def GoToFrame( self ):
    if vim.current.buffer != self._buf:
      return

    current_line = vim.current.window.cursor[ 0 ]
    if current_line not in self._line_to_frame:
      return

    self._session.SetCurrentFrame( self._line_to_frame[ current_line ] )

  def _PrintStackTrace( self, message ):
    with utils.ModifiableScratchBuffer( self._buf ):
      self._buf[:] = None
      self._buf.append( 'Stack trace' )

      stackFrames = message[ 'body' ][ 'stackFrames' ]

      for frame in stackFrames:
        source = frame[ 'source' ] or { 'name': '<unknown>' }
        self._buf.append(
          '{0}: {1}@{2}:{3}'.format( frame[ 'id' ],
                                     frame[ 'name' ],
                                     source[ 'name' ],
                                     frame[ 'line' ] ) )
        self._line_to_frame[ len( self._buf ) ] = frame

    self._session.SetCurrentFrame( stackFrames[ 0 ] )
