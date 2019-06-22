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
import logging
from collections import namedtuple
from functools import partial

from vimspector import utils

View = namedtuple( 'View', [ 'win', 'lines', 'draw' ] )


class VariablesView( object ):
  def __init__( self, connection, variables_win, watches_win ):
    self._logger = logging.getLogger( __name__ )
    utils.SetUpLogging( self._logger )

    self._vars = View( variables_win, {}, self._DrawScopes )
    self._watch = View( watches_win, {}, self._DrawWatches )
    self._connection = connection

    # Allows us to hit <CR> to expand/collapse variables
    vim.current.window = self._vars.win
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

    # Allows us to hit <CR> to expand/collapse variables
    vim.current.window = self._watch.win
    vim.command(
      'nnoremap <buffer> <CR> :call vimspector#ExpandVariable()<CR>' )
    vim.command(
      'nnoremap <buffer> <DEL> :call vimspector#DeleteWatch()<CR>' )

    utils.SetUpScratchBuffer( self._vars.win.buffer, 'vimspector.Variables' )
    utils.SetUpPromptBuffer( self._watch.win.buffer,
                             'vimspector.Watches',
                             'Expression: ',
                             'vimspector#AddWatchPrompt' )

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

    self._is_term = not bool( int( vim.eval( "has( 'gui_running' )" ) ) )

  def Clear( self ):
    with utils.ModifiableScratchBuffer( self._vars.win.buffer ):
      utils.ClearBuffer( self._vars.win.buffer )
    with utils.ModifiableScratchBuffer( self._watch.win.buffer ):
      utils.ClearBuffer( self._watch.win.buffer )

  def ConnectionUp( self, connection ):
    self._connection = connection

  def ConnectionClosed( self ):
    self.Clear()
    self._connection = None

  def Reset( self ):
    for k, v in self._oldoptions.items():
      vim.options[ k ] = v

  def LoadScopes( self, frame ):
    def scopes_consumer( message ):
      old_scopes = self._scopes
      self._scopes = []

      for i, scope in enumerate( message[ 'body' ][ 'scopes' ] ):
        if ( i < len( old_scopes ) and
             old_scopes[ i ][ 'name' ] == scope[ 'name' ] ):
          scope[ '_expanded' ] = old_scopes[ i ].get( '_expanded', False )
          scope[ '_old_variables' ] = old_scopes[ i ].get( '_variables', [] )
        elif not scope.get( 'expensive' ):
          # Expand any non-expensive scope unless manually collapsed
          scope[ '_expanded' ] = True

        self._scopes.append( scope )
        if scope[ '_expanded' ]:
          self._connection.DoRequest( partial( self._ConsumeVariables,
                                               self._DrawScopes,
                                               scope ), {
            'command': 'variables',
            'arguments': {
              'variablesReference': scope[ 'variablesReference' ]
            },
          } )

      self._DrawScopes()

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
    if vim.current.window != self._watch.win:
      utils.UserMessage( 'Not a watch window' )
      return

    current_line = vim.current.window.cursor[ 0 ]

    for index, watch in enumerate( self._watches ):
      if '_line' in watch and watch[ '_line' ] == current_line:
        del self._watches[ index ]
        utils.UserMessage( 'Deleted' )
        self._DrawWatches()
        return

    utils.UserMessage( 'No watch found' )

  def EvaluateWatches( self ):
    for watch in self._watches:
      self._connection.DoRequest( partial( self._UpdateWatchExpression,
                                           watch ), {
        'command': 'evaluate',
        'arguments': watch,
      } )

  def _UpdateWatchExpression( self, watch, message ):
    old_result = None
    if '_result' in watch:
      old_result = watch[ '_result' ]

    result = message[ 'body' ]
    watch[ '_result' ] = result

    if old_result:
      if '_expanded' in old_result:
        result[ '_expanded' ] = old_result[ '_expanded' ]
      result[ '_old_variables' ] = old_result.get( '_variables', [] )

    if ( result.get( 'variablesReference', 0 ) > 0 and
         result.get( '_expanded', False ) ):
      self._connection.DoRequest( partial( self._ConsumeVariables,
                                           self._watch.draw,
                                           result ), {
        'command': 'variables',
        'arguments': {
          'variablesReference': result[ 'variablesReference' ]
        },
      } )

    self._DrawWatches()

  def ExpandVariable( self ):
    if vim.current.window == self._vars.win:
      view = self._vars
    elif vim.current.window == self._watch.win:
      view = self._watch
    else:
      return

    current_line = vim.current.window.cursor[ 0 ]
    if current_line not in view.lines:
      return

    variable = view.lines[ current_line ]

    if '_variables' in variable:
      # Collapse
      del variable[ '_variables' ]
      variable[ '_expanded' ] = False
      view.draw()
      return

    if variable.get( 'variablesReference', 0 ) <= 0:
      return

    variable[ '_expanded' ] = True
    self._connection.DoRequest( partial( self._ConsumeVariables,
                                         view.draw,
                                         variable ), {
      'command': 'variables',
      'arguments': {
        'variablesReference': variable[ 'variablesReference' ]
      },
    } )

  def _DrawVariables( self, view,  variables, indent ):
    for variable in variables:
      line = utils.AppendToBuffer(
        view.win.buffer,
        '{indent}{icon} {name} ({type_}): {value}'.format(
          indent = ' ' * indent,
          icon = '+' if ( variable.get( 'variablesReference', 0 ) > 0 and
                          '_variables' not in variable ) else '-',
          name = variable[ 'name' ],
          type_ = variable.get( 'type', '<unknown type>' ),
          value = variable.get( 'value', '<unknown value>' ) ).split( '\n' ) )
      view.lines[ line ] = variable

      if '_variables' in variable:
        self._DrawVariables( view, variable[ '_variables' ], indent + 2 )

  def _DrawScopes( self ):
    # FIXME: The drawing is dumb and draws from scratch every time. This is
    # simple and works and makes sure the line-map is always correct.
    # However it is really inefficient, and makes it so that expanded results
    # are collapsed on every step.
    self._vars.lines.clear()
    with utils.RestoreCursorPosition():
      with utils.ModifiableScratchBuffer( self._vars.win.buffer ):
        utils.ClearBuffer( self._vars.win.buffer )
        for scope in self._scopes:
          self._DrawScope( 0, scope )

  def _DrawWatches( self ):
    # FIXME: The drawing is dumb and draws from scratch every time. This is
    # simple and works and makes sure the line-map is always correct.
    # However it is really inefficient, and makes it so that expanded results
    # are collapsed on every step.
    self._watch.lines.clear()
    with utils.RestoreCursorPosition():
      with utils.ModifiableScratchBuffer( self._watch.win.buffer ):
        utils.ClearBuffer( self._watch.win.buffer )
        utils.AppendToBuffer( self._watch.win.buffer, 'Watches: ----' )
        for watch in self._watches:
          line = utils.AppendToBuffer( self._watch.win.buffer,
                                       'Expression: ' + watch[ 'expression' ] )
          watch[ '_line' ] = line
          self._DrawWatchResult( 2, watch )

  def _DrawScope( self, indent, scope ):
    icon = '+' if ( scope.get( 'variablesReference', 0 ) > 0 and
                    '_variables' not in scope ) else '-'

    line = utils.AppendToBuffer( self._vars.win.buffer,
                                 '{0}{1} Scope: {2}'.format( ' ' * indent,
                                                             icon,
                                                             scope[ 'name' ] ) )
    self._vars.lines[ line ] = scope

    if '_variables' in scope:
      indent += 2
      self._DrawVariables( self._vars, scope[ '_variables' ], indent )

  def _DrawWatchResult( self, indent, watch ):
    if '_result' not in watch:
      return

    result = watch[ '_result' ]

    icon = '+' if ( result.get( 'variablesReference', 0 ) > 0 and
                    '_variables' not in result ) else '-'

    result_str = result[ 'result' ]
    if result_str is None:
      result_str = 'null'

    line =  '{0}{1} Result: {2} '.format( ' ' * indent, icon, result_str )
    line = utils.AppendToBuffer( self._watch.win.buffer, line.split( '\n' ) )
    self._watch.lines[ line ] = result

    if '_variables' in result:
      indent = 4
      self._DrawVariables( self._watch, result[ '_variables' ], indent )

  def _ConsumeVariables( self, draw, parent, message ):
    for variable in message[ 'body' ][ 'variables' ]:
      if '_variables' not in parent:
        parent[ '_variables' ] = []

      parent[ '_variables' ].append( variable )

      # If the variable was previously expanded, expand it again
      for index, v in enumerate( parent.get( '_old_variables', [] ) ):
        if v[ 'name' ] == variable[ 'name' ]:
          if ( v.get( '_expanded', False ) and
               variable.get( 'variablesReference', 0 ) > 0 ):

            variable[ '_expanded' ] = True
            variable[ '_old_variables' ] = v.get( '_variables', [] )

            self._connection.DoRequest( partial( self._ConsumeVariables,
                                                 draw,
                                                 variable ), {
              'command': 'variables',
              'arguments': {
                'variablesReference': variable[ 'variablesReference' ]
              },
            } )

          break

    if '_old_variables' in parent:
      del parent[ '_old_variables' ]

    draw()

  def ShowBalloon( self, frame, expression ):
    if not self._connection:
      return

    def handler( message ):
      # TODO: this result count be expandable, but we have no way to allow the
      # user to interact with the balloon to expand it.
      body = message[ 'body' ]
      result = body[ 'result' ]
      if result is None:
        result = 'null'
      display = [
        'Type: ' + body.get( 'type', '<unknown>' ),
        'Value: ' + result
      ]
      utils.DisplayBaloon( self._is_term, display )

    def failure_handler( reason, message ):
      display = [ reason ]
      utils.DisplayBaloon( self._is_term, display )


    self._connection.DoRequest( handler, {
      'command': 'evaluate',
      'arguments': {
        'expression': expression,
        'frameId': frame[ 'id' ],
        'context': 'hover',
      }
    }, failure_handler )
