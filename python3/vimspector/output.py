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

from vimspector import utils

import vim


BUFFER_MAP = {
  'console': 'Console',
  'stdout': 'Console'
}


def CategoryToBuffer( category ):
  return BUFFER_MAP.get( category, category )


class OutputView( object ):
  def __init__( self, connection, window ):
    self._window = window
    self._connection = connection
    self._buffers = {}

    for b in set( BUFFER_MAP.values() ):
      self._CreateBuffer( b )

    self.ShowOutput( 'Console' )

  def OnOutput( self, event ):
    category = CategoryToBuffer( event.get( 'category' ) or 'output' )
    if category not in self._buffers:
      self._CreateBuffer( category )

    buf = self._buffers[ category ]
    with utils.ModifiableScratchBuffer( buf ):
      utils.AppendToBuffer( buf, event[ 'output' ].splitlines() )

    # Scroll the buffer
    with utils.RestoreCurrentWindow():
      with utils.RestoreCurrentBuffer( self._window ):
        self.ShowOutput( category )
        vim.command( 'normal G' )

  def ConnectionClosed( self ):
    self._connection = None

  def Reset( self ):
    self.Clear()

  def Clear( self ):
    for buf in self._buffers:
      vim.command( 'bwipeout! {0}'.format( self._buffers[ buf ].name ) )

    self._buffers.clear()

  def ShowOutput( self, category ):
    vim.current.window = self._window
    vim.command( 'bu {0}'.format( self._buffers[ category ].name ) )

  def Evaluate( self, frame, expression ):
    if not frame:
      return

    console = self._buffers[ 'Console' ]
    utils.AppendToBuffer( console, expression )

    def print_result( message ):
      utils.AppendToBuffer( console, message[ 'body' ][ 'result' ] )

    self._connection.DoRequest( print_result, {
      'command': 'evaluate',
      'arguments': {
        'expression': expression,
        'context': 'repl',
        'frameId': frame[ 'id' ],
      }
    } )

  def _CreateBuffer( self, category ):
    with utils.RestoreCurrentWindow():
      vim.current.window = self._window

      with utils.RestoreCurrentBuffer( self._window ):
        vim.command( 'enew' )
        self._buffers[ category ] = vim.current.buffer

        if category == 'Console':
          utils.SetUpPromptBuffer( self._buffers[ category ],
                                   'vimspector.Console',
                                   '> ',
                                   'vimspector#EvaluateConsole',
                                   hidden = True )
        else:
          utils.SetUpHiddenBuffer( self._buffers[ category ],
                                   'vimspector.Output:{0}'.format( category ) )

        vim.command( "nnoremenu WinBar.{0} "
                     ":call vimspector#ShowOutput( '{0}' )<CR>".format(
                       utils.Escape( category ) ) )
