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

_logger = logging.getLogger( __name__ )

SIGN_ID_OFFSET = 10000000


class CodeView( object  ):
  def __init__( self, window ):
    self._window = window

    self._next_sign_id = SIGN_ID_OFFSET
    self._signs = {
      'vimspectorPC': None,
    }


    vim.current.window = self._window

    vim.command( 'nnoremenu WinBar.Continute :call vimspector#Continue()<CR>' )
    vim.command( 'nnoremenu WinBar.Next :call vimspector#StepOver()<CR>' )
    vim.command( 'nnoremenu WinBar.Step :call vimspector#StepInto()<CR>' )
    vim.command( 'nnoremenu WinBar.Finish :call vimspector#StepOut()<CR>' )
    vim.command( 'nnoremenu WinBar.Pause :call vimspector#Pause()<CR>' )

    vim.command( 'sign define vimspectorPC text=>> texthl=Search' )


  def SetCurrentFrame( self, frame ):
    vim.current.window = self._window

    if self._signs[ 'vimspectorPC' ]:
      vim.command( 'sign unplace {0}'.format( self._signs[ 'vimspectorPC' ] ) )
      self._signs[ 'vimspectorPC' ] = None

    buffer_number = vim.eval( 'bufnr( "{0}", 1 )'.format(
      frame[ 'source' ][ 'path' ]  ) )

    try:
      vim.command( 'bu {0}'.format( buffer_number ) )
    except vim.error as e:
      if 'E325' not in str( e ):
        raise

    self._window.cursor = ( frame[ 'line' ], frame[ 'column' ] )

    self._signs[ 'vimspectorPC' ] = self._next_sign_id
    self._next_sign_id += 1

    vim.command( 'sign place {0} line={1} name=vimspectorPC file={2}'.format(
      self._signs[ 'vimspectorPC' ],
      frame[ 'line' ],
      frame[ 'source' ][ 'path' ] ) )


  def Clear( self ):
    if self._signs[ 'vimspectorPC' ]:
      vim.command( 'sign unplace {0}'.format( self._signs[ 'vimspectorPC' ] ) )
      self._signs[ 'vimspectorPC' ] = None
