# vimspector - A multi-language debugging system for Vim
# Copyright 2019 Ben Jackson
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

from collections import defaultdict

import abc
import vim
import os
import logging

import json
from vimspector import utils


class ServerBreakpointHandler( object ):
  @abc.abstractmethod
  def ClearBreakpoints( self ):
    pass

  @abc.abstractmethod
  def AddBreakpoints( self, source, message ):
    pass


class ProjectBreakpoints( object ):
  def __init__( self ):
    self._connection = None
    self._logger = logging.getLogger( __name__ )
    utils.SetUpLogging( self._logger )

    # These are the user-entered breakpoints.
    self._line_breakpoints = defaultdict( list )
    self._func_breakpoints = []
    self._exception_breakpoints = None
    self._configured_breakpoints = {}

    # FIXME: Remove this. Remove breakpoints nonesense from code.py
    self._breakpoints_handler = None
    self._server_capabilities = {}

    self._next_sign_id = 1

    # TODO: Change to sign_define ?
    vim.command( 'sign define vimspectorBP text==> texthl=Error' )
    vim.command( 'sign define vimspectorBPDisabled text=!> texthl=Warning' )


  def ConnectionUp( self, connection ):
    self._connection = connection


  def SetServerCapabilities( self, server_capabilities ):
    self._server_capabilities = server_capabilities


  def ConnectionClosed( self ):
    self._breakpoints_handler = None
    self._server_capabilities = {}
    self._connection = None
    self.UpdateUI()

    # NOTE: we don't reset self._exception_breakpoints because we don't want to
    # re-ask the user every time for the sane info.

    # FIXME: If the adapter type changes, we should probably forget this ?


  def ListBreakpoints( self ):
    # FIXME: Handling of breakpoints is a mess, split between _codeView and this
    # object. This makes no sense and should be centralised so that we don't
    # have this duplication and bug factory.
    qf = []
    if self._connection and self._codeView:
      qf = self._codeView.BreakpointsAsQuickFix()
    else:
      for file_name, breakpoints in self._line_breakpoints.items():
        for bp in breakpoints:
          self._SignToLine( file_name, bp )
          qf.append( {
            'filename': file_name,
            'lnum': bp[ 'line' ],
            'col': 1,
            'type': 'L',
            'valid': 1 if bp[ 'state' ] == 'ENABLED' else 0,
            'text': "Line breakpoint - {}".format(
              bp[ 'state' ] )
          } )
      # I think this shows that the qf list is not right for this.
      for bp in self._func_breakpoints:
        qf.append( {
          'filename': '',
          'lnum': 1,
          'col': 1,
          'type': 'F',
          'valid': 1,
          'text': "Function breakpoint: {}".format( bp[ 'function' ] ),
        } )

    vim.eval( 'setqflist( {} )'.format( json.dumps( qf ) ) )

  def ClearBreakpoints( self ):
    # These are the user-entered breakpoints.
    for file_name, breakpoints in self._line_breakpoints.items():
      for bp in breakpoints:
        self._SignToLine( file_name, bp )
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0} group=VimspectorBP'.format(
            bp[ 'sign_id' ] ) )

    self._line_breakpoints = defaultdict( list )
    self._func_breakpoints = []

    self.UpdateUI()

  def ToggleBreakpoint( self ):
    line, column = vim.current.window.cursor
    file_name = vim.current.buffer.name

    if not file_name:
      return

    found_bp = False
    action = 'New'
    for index, bp in enumerate( self._line_breakpoints[ file_name ] ):
      self._SignToLine( file_name, bp )
      if bp[ 'line' ] == line:
        found_bp = True
        if bp[ 'state' ] == 'ENABLED' and not self._connection:
          bp[ 'state' ] = 'DISABLED'
          action = 'Disable'
        else:
          if 'sign_id' in bp:
            vim.command( 'sign unplace {0} group=VimspectorBP'.format(
              bp[ 'sign_id' ] ) )
          del self._line_breakpoints[ file_name ][ index ]
          action = 'Delete'
        break

    self._logger.debug( "Toggle found bp at {}:{} ? {} ({})".format(
      file_name,
      line,
      found_bp,
      action ) )

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

    self.UpdateUI()

  def AddFunctionBreakpoint( self, function ):
    self._func_breakpoints.append( {
        'state': 'ENABLED',
        'function': function,
    } )

    # TODO: We don't really have aanything to update here, but if we're going to
    # have a UI list of them we should update that at this point
    self.UpdateUI()


  def UpdateUI( self ):
    if self._connection:
      self.SendBreakpoints()
    else:
      self._ShowBreakpoints()


  def SetBreakpointsHandler( self, handler ):
    # FIXME: Remove this temporary compat .layer
    self._breakpoints_handler = handler


  def SetConfiguredBreakpoints( self, configured_breakpoints ):
    self._configured_breakpoints = configured_breakpoints


  def SendBreakpoints( self, doneHandler = None ):
    assert self._breakpoints_handler is not None

    # Clear any existing breakpoints prior to sending new ones
    self._breakpoints_handler.ClearBreakpoints()

    awaiting = 0

    def response_handler( source, msg ):
      if msg:
        self._breakpoints_handler.AddBreakpoints( source, msg )
      nonlocal awaiting
      awaiting = awaiting - 1
      if awaiting == 0 and doneHandler:
        doneHandler()


    # TODO: add the _configured_breakpoints to line_breakpoints
    # TODO: the line numbers might have changed since pressing the F9 key!

    for file_name, line_breakpoints in self._line_breakpoints.items():
      breakpoints = []
      for bp in line_breakpoints:
        self._SignToLine( file_name, bp )
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0} group=VimspectorBP'.format(
            bp[ 'sign_id' ] ) )
          del bp[ 'sign_id' ]

        if bp[ 'state' ] != 'ENABLED':
          continue

        breakpoints.append( { 'line': bp[ 'line' ] } )

      source = {
        'name': os.path.basename( file_name ),
        'path': file_name,
      }

      awaiting = awaiting + 1
      self._connection.DoRequest(
        lambda msg: response_handler( source, msg ),
        {
          'command': 'setBreakpoints',
          'arguments': {
            'source': source,
            'breakpoints': breakpoints,
          },
          'sourceModified': False, # TODO: We can actually check this
        }
      )

    # TODO: Add the _configured_breakpoints to function breakpoints

    if self._server_capabilities.get( 'supportsFunctionBreakpoints' ):
      awaiting = awaiting + 1
      self._connection.DoRequest(
        lambda msg: response_handler( None, msg ),
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

    if self._exception_breakpoints is None:
      self._SetUpExceptionBreakpoints( self._configured_breakpoints )

    if self._exception_breakpoints:
      awaiting = awaiting + 1
      self._connection.DoRequest(
        lambda msg: response_handler( None, None ),
        {
          'command': 'setExceptionBreakpoints',
          'arguments': self._exception_breakpoints
        }
      )

    if awaiting == 0 and doneHandler:
      doneHandler()


  def _SetUpExceptionBreakpoints( self, configured_breakpoints ):
    exception_breakpoint_filters = self._server_capabilities.get(
        'exceptionBreakpointFilters',
        [] )

    if exception_breakpoint_filters or not self._server_capabilities.get(
      'supportsConfigurationDoneRequest' ):
      # Note the supportsConfigurationDoneRequest part: prior to there being a
      # configuration done request, the "exception breakpoints" request was the
      # indication that configuraiton was done (and its response is used to
      # trigger requesting threads etc.). See the note in
      # debug_session.py:_Initialise for more detials
      exception_filters = []
      configured_filter_options = configured_breakpoints.get( 'exception', {} )
      if exception_breakpoint_filters:
        for f in exception_breakpoint_filters:
          default_value = 'Y' if f.get( 'default' ) else 'N'

          if f[ 'filter' ] in configured_filter_options:
            result = configured_filter_options[ f[ 'filter' ] ]

            if isinstance( result, bool ):
              result = 'Y' if result else 'N'

            if not isinstance( result, str ) or result not in ( 'Y', 'N', '' ):
              raise ValueError(
                f"Invalid value for exception breakpoint filter '{f}': "
                f"'{result}'. Must be boolean, 'Y', 'N' or '' (default)" )
          else:
            result = utils.AskForInput(
              "{}: Break on {} (Y/N/default: {})? ".format( f[ 'filter' ],
                                                            f[ 'label' ],
                                                            default_value ),
              default_value )

          if result == 'Y':
            exception_filters.append( f[ 'filter' ] )
          elif not result and f.get( 'default' ):
            exception_filters.append( f[ 'filter' ] )

      self._exception_breakpoints = {
        'filters': exception_filters
      }

      if self._server_capabilities.get( 'supportsExceptionOptions' ):
        # TODO: There are more elaborate exception breakpoint options here, but
        # we don't support them. It doesn't seem like any of the servers really
        # pay any attention to them anyway.
        self._exception_breakpoints[ 'exceptionOptions' ] = []

  def _ShowBreakpoints( self ):
    for file_name, line_breakpoints in self._line_breakpoints.items():
      for bp in line_breakpoints:
        self._SignToLine( file_name, bp )
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0} group=VimspectorBP '.format(
            bp[ 'sign_id' ] ) )
        else:
          bp[ 'sign_id' ] = self._next_sign_id
          self._next_sign_id += 1

        vim.command(
          'sign place {0} group=VimspectorBP line={1} name={2} file={3}'.format(
            bp[ 'sign_id' ] ,
            bp[ 'line' ],
            'vimspectorBP' if bp[ 'state' ] == 'ENABLED'
                           else 'vimspectorBPDisabled',
            file_name ) )


  def _SignToLine( self, file_name, bp ):
    if 'sign_id' not in bp:
      return bp[ 'line' ]

    signs = vim.eval( "sign_getplaced( '{}', {} )".format(
      utils.Escape( file_name ),
      json.dumps( { 'id': file_name, 'group': 'VimspectorBP', } ) ) )

    if len( signs ) == 1 and len( signs[ 0 ][ 'signs' ] ) == 1:
      bp[ 'line' ] = int( signs[ 0 ][ 'signs' ][ 0 ][ 'lnum' ] )

    return bp[ 'line' ]
