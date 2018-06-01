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
from functools import partial

from vimspector import utils


class VariablesView( object ):
  def __init__( self, connection, buf ):
    vim.current.buffer = buf

    self._buf = buf
    self._connection = connection

    # Allows us to hit <CR> to expand/collapse variables
    self._line_to_variable = {}
    vim.command(
      'nnoremap <buffer> <CR> :call vimspector#ExpandVariable()<CR>' )

    # This is actually the tree (scopes are alwyas the root)
    #  it's just a list of DAP scope dicts, with one magic key (_variables)
    #  _variables is a list of DAP variable with the same magic key
    #
    # If _variables is present, then we have requested and should display the
    # children. Otherwise, we haven't or shouldn't.
    self._scopes = []

    # This is similar to scopes, but the top level is an "expression" (request)
    # containing a special '_result' key which is the response. The response
    # structure con contain _variables and is handled identically to the scopes
    # above. It also has a special _line key which is where we printed it (last)
    self._watches = []

    # Allows us to delete manual watches
    vim.command(
      'nnoremap <buffer> <DEL> :call vimspector#DeleteWatch()<CR>' )

    utils.SetUpScratchBuffer( self._buf, 'vimspector.Variables' )

    has_balloon      = int( vim.eval( "has( 'balloon_eval' )" ) )
    has_balloon_term = int( vim.eval( "has( 'balloon_eval_term' )" ) )

    self._oldoptions = {}
    if has_balloon or has_balloon_term:
      self._oldoptions = {
        'balloonexpr': vim.options[ 'balloonexpr' ],
        'balloondelay': vim.options[ 'balloondelay' ],
      }
      vim.options[ 'balloonexpr' ] = 'vimspector#internal#balloon#BalloonExpr()'
      vim.options[ 'balloondelay' ] = 250

    if has_balloon:
      self._oldoptions[ 'ballooneval' ] = vim.options[ 'ballooneval' ]
      vim.options[ 'ballooneval' ] = True

    if has_balloon_term:
      self._oldoptions[ 'balloonevalterm' ] = vim.options[ 'balloonevalterm' ]
      vim.options[ 'balloonevalterm' ] = True


  def Clear( self ):
    with utils.ModifiableScratchBuffer( self._buf ):
      self._buf[:] = None

  def ConnectionClosed( self ):
    self.Clear()
    self._connection = None

  def Reset( self ):
    for k, v in self._oldoptions.items():
      vim.options[ k ] = v

    # TODO: delete the buffer?

  def LoadScopes( self, frame ):
    def scopes_consumer( message ):
      self._scopes = []
      for scope in message[ 'body' ][ 'scopes' ]:
        self._scopes.append( scope )
        self._connection.DoRequest( partial( self._ConsumeVariables, scope ), {
          'command': 'variables',
          'arguments': {
            'variablesReference': scope[ 'variablesReference' ]
          },
        } )

      self._DrawScopesAndWatches()

    self._connection.DoRequest( scopes_consumer, {
      'command': 'scopes',
      'arguments': {
        'frameId': frame[ 'id' ]
      },
    } )

  def AddWatch( self, frame, expression ):
    watch = {
        'expression': expression,
        'frameId': frame[ 'id' ],
        'context': 'watch',
    }
    self._watches.append( watch )
    self.EvaluateWatches()

  def DeleteWatch( self ):
    if vim.current.window.buffer != self._buf:
      return

    current_line = vim.current.window.cursor[ 0 ]

    for index, watch in enumerate( self._watches ):
      if '_line' in watch and watch[ '_line' ] == current_line:
        del self._watches[ index ]
        self._DrawScopesAndWatches()
        return

  def EvaluateWatches( self ):
    for watch in self._watches:
      self._connection.DoRequest( partial( self._UpdateWatchExpression,
                                           watch ), {
        'command': 'evaluate',
        'arguments': watch,
      } )

  def _UpdateWatchExpression( self, watch, message ):
    watch[ '_result' ] = message[ 'body' ]
    self._DrawScopesAndWatches()

  def ExpandVariable( self ):
    if vim.current.window.buffer != self._buf:
      return

    current_line = vim.current.window.cursor[ 0 ]
    if current_line not in self._line_to_variable:
      return

    variable = self._line_to_variable[ current_line ]

    if '_variables' in variable:
      # Collapse
      del variable[ '_variables' ]
      self._DrawScopesAndWatches()
      return

    # Expand. (only if there is anything to expand)
    if 'variablesReference' not in variable:
      return
    if variable[ 'variablesReference' ] <= 0:
      return

    self._connection.DoRequest( partial( self._ConsumeVariables, variable ), {
      'command': 'variables',
      'arguments': {
        'variablesReference': variable[ 'variablesReference' ]
      },
    } )

  def _DrawVariables( self, variables, indent ):
    for variable in variables:
      self._line_to_variable[ len( self._buf ) + 1 ] = variable
      self._buf.append(
        '{indent}{icon} {name} ({type_}): {value}'.format(
          indent = ' ' * indent,
          icon = '+' if ( variable[ 'variablesReference' ] > 0 and
                          '_variables' not in variable ) else '-',
          name = variable[ 'name' ],
          type_ = variable.get( 'type', '<unknown type>' ),
          value = variable.get( 'value', '<unknown value>' ) ).split( '\n' ) )

      if '_variables' in variable:
        self._DrawVariables( variable[ '_variables' ], indent + 2 )

  def _DrawScopesAndWatches( self ):
    self._line_to_variable = {}
    with utils.RestoreCursorPosition():
      with utils.ModifiableScratchBuffer( self._buf ):
        self._buf[:] = None
        for scope in self._scopes:
          self._DrawScope( 0, scope )

        self._buf.append( 'Watches: ----' )
        for watch in self._watches:
          self._buf.append( 'Expression: ' + watch[ 'expression' ] )
          watch[ '_line' ] = len( self._buf )
          self._DrawWatchResult( 2, watch )

  def _DrawScope( self, indent, scope ):
    icon = '+' if ( scope[ 'variablesReference' ] > 0 and
                    '_variables' not in scope ) else '-'

    self._line_to_variable[ len( self._buf ) + 1 ] = scope
    self._buf.append( '{0}{1} Scope: {2}'.format( ' ' * indent,
                                                   icon,
                                                   scope[ 'name' ] ) )

    if '_variables' in scope:
      indent += 2
      self._DrawVariables( scope[ '_variables' ], indent )

  def _DrawWatchResult( self, indent, watch ):
    if '_result' not in watch:
      return

    result = watch[ '_result' ]
    self._line_to_variable[ len( self._buf ) + 1 ] = result

    icon = '+' if ( result[ 'variablesReference' ] > 0 and
                    '_variables' not in result ) else '-'

    line =  '{0}{1} Result: {2} '.format( ' ' * indent,
                                          icon,
                                          result[ 'result' ] )
    self._buf.append( line.split( '\n' ) )

    if '_variables' in result:
      indent = 4
      self._DrawVariables( result[ '_variables' ], indent )

  def _ConsumeVariables( self, parent, message ):
    for variable in message[ 'body' ][ 'variables' ]:
      if '_variables' not in parent:
        parent[ '_variables' ] = []

      parent[ '_variables' ].append( variable )

    self._DrawScopesAndWatches()

  def ShowBalloon( self, frame, expression ):
    if not self._connection:
      return

    def handler( message ):
      vim.eval( "balloon_show( '{0}' )".format(
        message[ 'body' ][ 'result' ] ) )

    self._connection.DoRequest( handler, {
      'command': 'evaluate',
      'arguments': {
        'expression': expression,
        'frameId': frame[ 'id' ],
        'context': 'hover',
      }
    } )
