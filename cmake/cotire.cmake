# - cotire (compile time reducer)
#
# See the cotire manual for usage hints.
#
#=============================================================================
# Copyright 2012-2017 Sascha Kratky
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#=============================================================================

if(__COTIRE_INCLUDED)
	return()
endif()
set(__COTIRE_INCLUDED TRUE)

# call cmake_minimum_required, but prevent modification of the CMake policy stack in include mode
# cmake_minimum_required also sets the policy version as a side effect, which we have to avoid
if (NOT CMAKE_SCRIPT_MODE_FILE)
	cmake_policy(PUSH)
endif()
cmake_minimum_required(VERSION 2.8.12)
if (NOT CMAKE_SCRIPT_MODE_FILE)
	cmake_policy(POP)
endif()

set (COTIRE_CMAKE_MODULE_FILE "${CMAKE_CURRENT_LIST_FILE}")
set (COTIRE_CMAKE_MODULE_VERSION "1.7.10")

# activate select policies
if (POLICY CMP0025)
	# Compiler id for Apple Clang is now AppleClang
	cmake_policy(SET CMP0025 NEW)
endif()

if (POLICY CMP0026)
	# disallow use of the LOCATION target property
	cmake_policy(SET CMP0026 NEW)
endif()

if (POLICY CMP0038)
	# targets may not link directly to themselves
	cmake_policy(SET CMP0038 NEW)
endif()

if (POLICY CMP0039)
	# utility targets may not have link dependencies
	cmake_policy(SET CMP0039 NEW)
endif()

if (POLICY CMP0040)
	# target in the TARGET signature of add_custom_command() must exist
	cmake_policy(SET CMP0040 NEW)
endif()

if (POLICY CMP0045)
	# error on non-existent target in get_target_property
	cmake_policy(SET CMP0045 NEW)
endif()

if (POLICY CMP0046)
	# error on non-existent dependency in add_dependencies
	cmake_policy(SET CMP0046 NEW)
endif()

if (POLICY CMP0049)
	# do not expand variables in target source entries
	cmake_policy(SET CMP0049 NEW)
endif()

if (POLICY CMP0050)
	# disallow add_custom_command SOURCE signatures
	cmake_policy(SET CMP0050 NEW)
endif()

if (POLICY CMP0051)
	# include TARGET_OBJECTS expressions in a target's SOURCES property
	cmake_policy(SET CMP0051 NEW)
endif()

if (POLICY CMP0053)
	# simplify variable reference and escape sequence evaluation
	cmake_policy(SET CMP0053 NEW)
endif()

if (POLICY CMP0054)
	# only interpret if() arguments as variables or keywords when unquoted
	cmake_policy(SET CMP0054 NEW)
endif()

if (POLICY CMP0055)
	# strict checking for break() command
	cmake_policy(SET CMP0055 NEW)
endif()

include(CMakeParseArguments)
include(ProcessorCount)

function (cotire_get_configuration_types _configsVar)
	set (_configs "")
	if (CMAKE_CONFIGURATION_TYPES)
		list (APPEND _configs ${CMAKE_CONFIGURATION_TYPES})
	endif()
	if (CMAKE_BUILD_TYPE)
		list (APPEND _configs "${CMAKE_BUILD_TYPE}")
	endif()
	if (_configs)
		list (REMOVE_DUPLICATES _configs)
		set (${_configsVar} ${_configs} PARENT_SCOPE)
	else()
		set (${_configsVar} "None" PARENT_SCOPE)
	endif()
endfunction()

function (cotire_get_source_file_extension _sourceFile _extVar)
	# get_filename_component returns extension from first occurrence of . in file name
	# this function computes the extension from last occurrence of . in file name
	string (FIND "${_sourceFile}" "." _index REVERSE)
	if (_index GREATER -1)
		math (EXPR _index "${_index} + 1")
		string (SUBSTRING "${_sourceFile}" ${_index} -1 _sourceExt)
	else()
		set (_sourceExt "")
	endif()
	set (${_extVar} "${_sourceExt}" PARENT_SCOPE)
endfunction()

macro (cotire_check_is_path_relative_to _path _isRelativeVar)
	set (${_isRelativeVar} FALSE)
	if (IS_ABSOLUTE "${_path}")
		foreach (_dir ${ARGN})
			file (RELATIVE_PATH _relPath "${_dir}" "${_path}")
			if (NOT _relPath OR (NOT IS_ABSOLUTE "${_relPath}" AND NOT "${_relPath}" MATCHES "^\\.\\."))
				set (${_isRelativeVar} TRUE)
				break()
			endif()
		endforeach()
	endif()
endmacro()

function (cotire_filter_language_source_files _language _target _sourceFilesVar _excludedSourceFilesVar _cotiredSourceFilesVar)
	if (CMAKE_${_language}_SOURCE_FILE_EXTENSIONS)
		set (_languageExtensions "${CMAKE_${_language}_SOURCE_FILE_EXTENSIONS}")
	else()
		set (_languageExtensions "")
	endif()
	if (CMAKE_${_language}_IGNORE_EXTENSIONS)
		set (_ignoreExtensions "${CMAKE_${_language}_IGNORE_EXTENSIONS}")
	else()
		set (_ignoreExtensions "")
	endif()
	if (COTIRE_UNITY_SOURCE_EXCLUDE_EXTENSIONS)
		set (_excludeExtensions "${COTIRE_UNITY_SOURCE_EXCLUDE_EXTENSIONS}")
	else()
		set (_excludeExtensions "")
	endif()
	if (COTIRE_DEBUG AND _languageExtensions)
		message (STATUS "${_language} source file extensions: ${_languageExtensions}")
	endif()
	if (COTIRE_DEBUG AND _ignoreExtensions)
		message (STATUS "${_language} ignore extensions: ${_ignoreExtensions}")
	endif()
	if (COTIRE_DEBUG AND _excludeExtensions)
		message (STATUS "${_language} exclude extensions: ${_excludeExtensions}")
	endif()
	if (CMAKE_VERSION VERSION_LESS "3.1.0")
		set (_allSourceFiles ${ARGN})
	else()
		# as of CMake 3.1 target sources may contain generator expressions
		# since we cannot obtain required property information about source files added
		# through generator expressions at configure time, we filter them out
		string (GENEX_STRIP "${ARGN}" _allSourceFiles)
	endif()
	set (_filteredSourceFiles "")
	set (_excludedSourceFiles "")
	foreach (_sourceFile ${_allSourceFiles})
		get_source_file_property(_sourceIsHeaderOnly "${_sourceFile}" HEADER_FILE_ONLY)
		get_source_file_property(_sourceIsExternal "${_sourceFile}" EXTERNAL_OBJECT)
		get_source_file_property(_sourceIsSymbolic "${_sourceFile}" SYMBOLIC)
		if (NOT _sourceIsHeaderOnly AND NOT _sourceIsExternal AND NOT _sourceIsSymbolic)
			cotire_get_source_file_extension("${_sourceFile}" _sourceExt)
			if (_sourceExt)
				list (FIND _ignoreExtensions "${_sourceExt}" _ignoreIndex)
				if (_ignoreIndex LESS 0)
					list (FIND _excludeExtensions "${_sourceExt}" _excludeIndex)
					if (_excludeIndex GREATER -1)
						list (APPEND _excludedSourceFiles "${_sourceFile}")
					else()
						list (FIND _languageExtensions "${_sourceExt}" _sourceIndex)
						if (_sourceIndex GREATER -1)
							# consider source file unless it is excluded explicitly
							get_source_file_property(_sourceIsExcluded "${_sourceFile}" COTIRE_EXCLUDED)
							if (_sourceIsExcluded)
								list (APPEND _excludedSourceFiles "${_sourceFile}")
							else()
								list (APPEND _filteredSourceFiles "${_sourceFile}")
							endif()
						else()
							get_source_file_property(_sourceLanguage "${_sourceFile}" LANGUAGE)
							if ("${_sourceLanguage}" STREQUAL "${_language}")
								# add to excluded sources, if file is not ignored and has correct language without having the correct extension
								list (APPEND _excludedSourceFiles "${_sourceFile}")
							endif()
						endif()
					endif()
				endif()
			endif()
		endif()
	endforeach()
	# separate filtered source files from already cotired ones
	# the COTIRE_TARGET property of a source file may be set while a target is being processed by cotire
	set (_sourceFiles "")
	set (_cotiredSourceFiles "")
	foreach (_sourceFile ${_filteredSourceFiles})
		get_source_file_property(_sourceIsCotired "${_sourceFile}" COTIRE_TARGET)
		if (_sourceIsCotired)
			list (APPEND _cotiredSourceFiles "${_sourceFile}")
		else()
			get_source_file_property(_sourceCompileFlags "${_sourceFile}" COMPILE_FLAGS)
			if (_sourceCompileFlags)
				# add to excluded sources, if file has custom compile flags
				list (APPEND _excludedSourceFiles "${_sourceFile}")
			else()
				list (APPEND _sourceFiles "${_sourceFile}")
			endif()
		endif()
	endforeach()
	if (COTIRE_DEBUG)
		if (_sourceFiles)
			message (STATUS "Filtered ${_target} ${_language} sources: ${_sourceFiles}")
		endif()
		if (_excludedSourceFiles)
			message (STATUS "Excluded ${_target} ${_language} sources: ${_excludedSourceFiles}")
		endif()
		if (_cotiredSourceFiles)
			message (STATUS "Cotired ${_target} ${_language} sources: ${_cotiredSourceFiles}")
		endif()
	endif()
	set (${_sourceFilesVar} ${_sourceFiles} PARENT_SCOPE)
	set (${_excludedSourceFilesVar} ${_excludedSourceFiles} PARENT_SCOPE)
	set (${_cotiredSourceFilesVar} ${_cotiredSourceFiles} PARENT_SCOPE)
endfunction()

function (cotire_get_objects_with_property_on _filteredObjectsVar _property _type)
	set (_filteredObjects "")
	foreach (_object ${ARGN})
		get_property(_isSet ${_type} "${_object}" PROPERTY ${_property} SET)
		if (_isSet)
			get_property(_propertyValue ${_type} "${_object}" PROPERTY ${_property})
			if (_propertyValue)
				list (APPEND _filteredObjects "${_object}")
			endif()
		endif()
	endforeach()
	set (${_filteredObjectsVar} ${_filteredObjects} PARENT_SCOPE)
endfunction()

function (cotire_get_objects_with_property_off _filteredObjectsVar _property _type)
	set (_filteredObjects "")
	foreach (_object ${ARGN})
		get_property(_isSet ${_type} "${_object}" PROPERTY ${_property} SET)
		if (_isSet)
			get_property(_propertyValue ${_type} "${_object}" PROPERTY ${_property})
			if (NOT _propertyValue)
				list (APPEND _filteredObjects "${_object}")
			endif()
		endif()
	endforeach()
	set (${_filteredObjectsVar} ${_filteredObjects} PARENT_SCOPE)
endfunction()

function (cotire_get_source_file_property_values _valuesVar _property)
	set (_values "")
	foreach (_sourceFile ${ARGN})
		get_source_file_property(_propertyValue "${_sourceFile}" ${_property})
		if (_propertyValue)
			list (APPEND _values "${_propertyValue}")
		endif()
	endforeach()
	set (${_valuesVar} ${_values} PARENT_SCOPE)
endfunction()

function (cotire_resolve_config_properties _configurations _propertiesVar)
	set (_properties "")
	foreach (_property ${ARGN})
		if ("${_property}" MATCHES "<CONFIG>")
			foreach (_config ${_configurations})
				string (TOUPPER "${_config}" _upperConfig)
				string (REPLACE "<CONFIG>" "${_upperConfig}" _configProperty "${_property}")
				list (APPEND _properties ${_configProperty})
			endforeach()
		else()
			list (APPEND _properties ${_property})
		endif()
	endforeach()
	set (${_propertiesVar} ${_properties} PARENT_SCOPE)
endfunction()

function (cotire_copy_set_properties _configurations _type _source _target)
	cotire_resolve_config_properties("${_configurations}" _properties ${ARGN})
	foreach (_property ${_properties})
		get_property(_isSet ${_type} ${_source} PROPERTY ${_property} SET)
		if (_isSet)
			get_property(_propertyValue ${_type} ${_source} PROPERTY ${_property})
			set_property(${_type} ${_target} PROPERTY ${_property} "${_propertyValue}")
		endif()
	endforeach()
endfunction()

function (cotire_get_target_usage_requirements _target _config _targetRequirementsVar)
	set (_targetRequirements "")
	get_target_property(_librariesToProcess ${_target} LINK_LIBRARIES)
	while (_librariesToProcess)
		# remove from head
		list (GET _librariesToProcess 0 _library)
		list (REMOVE_AT _librariesToProcess 0)
		if (_library MATCHES "^\\$<\\$<CONFIG:${_config}>:([A-Za-z0-9_:-]+)>$")
			set (_library "${CMAKE_MATCH_1}")
		elseif (_config STREQUAL "None" AND _library MATCHES "^\\$<\\$<CONFIG:>:([A-Za-z0-9_:-]+)>$")
			set (_library "${CMAKE_MATCH_1}")
		endif()
		if (TARGET ${_library})
			list (FIND _targetRequirements ${_library} _index)
			if (_index LESS 0)
				list (APPEND _targetRequirements ${_library})
				# BFS traversal of transitive libraries
				get_target_property(_libraries ${_library} INTERFACE_LINK_LIBRARIES)
				if (_libraries)
					list (APPEND _librariesToProcess ${_libraries})
					list (REMOVE_DUPLICATES _librariesToProcess)
				endif()
			endif()
		endif()
	endwhile()
	set (${_targetRequirementsVar} ${_targetRequirements} PARENT_SCOPE)
endfunction()

function (cotire_filter_compile_flags _language _flagFilter _matchedOptionsVar _unmatchedOptionsVar)
	if (WIN32 AND CMAKE_${_language}_COMPILER_ID MATCHES "MSVC|Intel")
		set (_flagPrefix "[/-]")
	else()
		set (_flagPrefix "--?")
	endif()
	set (_optionFlag "")
	set (_matchedOptions "")
	set (_unmatchedOptions "")
	foreach (_compileFlag ${ARGN})
		if (_compileFlag)
			if (_optionFlag AND NOT "${_compileFlag}" MATCHES "^${_flagPrefix}")
				# option with separate argument
				list (APPEND _matchedOptions "${_compileFlag}")
				set (_optionFlag "")
			elseif ("${_compileFlag}" MATCHES "^(${_flagPrefix})(${_flagFilter})$")
				# remember option
				set (_optionFlag "${CMAKE_MATCH_2}")
			elseif ("${_compileFlag}" MATCHES "^(${_flagPrefix})(${_flagFilter})(.+)$")
				# option with joined argument
				list (APPEND _matchedOptions "${CMAKE_MATCH_3}")
				set (_optionFlag "")
			else()
				# flush remembered option
				if (_optionFlag)
					list (APPEND _matchedOptions "${_optionFlag}")
					set (_optionFlag "")
				endif()
				# add to unfiltered options
				list (APPEND _unmatchedOptions "${_compileFlag}")
			endif()
		endif()
	endforeach()
	if (_optionFlag)
		list (APPEND _matchedOptions "${_optionFlag}")
	endif()
	if (COTIRE_DEBUG AND _matchedOptions)
		message (STATUS "Filter ${_flagFilter} matched: ${_matchedOptions}")
	endif()
	if (COTIRE_DEBUG AND _unmatchedOptions)
		message (STATUS "Filter ${_flagFilter} unmatched: ${_unmatchedOptions}")
	endif()
	set (${_matchedOptionsVar} ${_matchedOptions} PARENT_SCOPE)
	set (${_unmatchedOptionsVar} ${_unmatchedOptions} PARENT_SCOPE)
endfunction()

function (cotire_is_target_supported _target _isSupportedVar)
	if (NOT TARGET "${_target}")
		set (${_isSupportedVar} FALSE PARENT_SCOPE)
		return()
	endif()
	get_target_property(_imported ${_target} IMPORTED)
	if (_imported)
		set (${_isSupportedVar} FALSE PARENT_SCOPE)
		return()
	endif()
	get_target_property(_targetType ${_target} TYPE)
	if (NOT _targetType MATCHES "EXECUTABLE|(STATIC|SHARED|MODULE|OBJECT)_LIBRARY")
		set (${_isSupportedVar} FALSE PARENT_SCOPE)
		return()
	endif()
	set (${_isSupportedVar} TRUE PARENT_SCOPE)
endfunction()

function (cotire_get_target_compile_flags _config _language _target _flagsVar)
	string (TOUPPER "${_config}" _upperConfig)
	# collect options from CMake language variables
	set (_compileFlags "")
	if (CMAKE_${_language}_FLAGS)
		set (_compileFlags "${_compileFlags} ${CMAKE_${_language}_FLAGS}")
	endif()
	if (CMAKE_${_language}_FLAGS_${_upperConfig})
		set (_compileFlags "${_compileFlags} ${CMAKE_${_language}_FLAGS_${_upperConfig}}")
	endif()
	if (_target)
		# add target compile flags
		get_target_property(_targetflags ${_target} COMPILE_FLAGS)
		if (_targetflags)
			set (_compileFlags "${_compileFlags} ${_targetflags}")
		endif()
	endif()
	if (UNIX)
		separate_arguments(_compileFlags UNIX_COMMAND "${_compileFlags}")
	elseif(WIN32)
		separate_arguments(_compileFlags WINDOWS_COMMAND "${_compileFlags}")
	else()
		separate_arguments(_compileFlags)
	endif()
	# target compile options
	if (_target)
		get_target_property(_targetOptions ${_target} COMPILE_OPTIONS)
		if (_targetOptions)
			list (APPEND _compileFlags ${_targetOptions})
		endif()
	endif()
	# interface compile options from linked library targets
	if (_target)
		set (_linkedTargets "")
		cotire_get_target_usage_requirements(${_target} ${_config} _linkedTargets)
		foreach (_linkedTarget ${_linkedTargets})
			get_target_property(_targetOptions ${_linkedTarget} INTERFACE_COMPILE_OPTIONS)
			if (_targetOptions)
				list (APPEND _compileFlags ${_targetOptions})
			endif()
		endforeach()
	endif()
	# handle language standard properties
	if (CMAKE_${_language}_STANDARD_DEFAULT)
		# used compiler supports language standard levels
		if (_target)
			get_target_property(_targetLanguageStandard ${_target} ${_language}_STANDARD)
			if (_targetLanguageStandard)
				set (_type "EXTENSION")
				get_property(_isSet TARGET ${_target} PROPERTY ${_language}_EXTENSIONS SET)
				if (_isSet)
					get_target_property(_targetUseLanguageExtensions ${_target} ${_language}_EXTENSIONS)
					if (NOT _targetUseLanguageExtensions)
						set (_type "STANDARD")
					endif()
				endif()
				if (CMAKE_${_language}${_targetLanguageStandard}_${_type}_COMPILE_OPTION)
					list (APPEND _compileFlags "${CMAKE_${_language}${_targetLanguageStandard}_${_type}_COMPILE_OPTION}")
				endif()
			endif()
		endif()
	endif()
	# handle the POSITION_INDEPENDENT_CODE target property
	if (_target)
		get_target_property(_targetPIC ${_target} POSITION_INDEPENDENT_CODE)
		if (_targetPIC)
			get_target_property(_targetType ${_target} TYPE)
			if (_targetType STREQUAL "EXECUTABLE" AND CMAKE_${_language}_COMPILE_OPTIONS_PIE)
				list (APPEND _compileFlags "${CMAKE_${_language}_COMPILE_OPTIONS_PIE}")
			elseif (CMAKE_${_language}_COMPILE_OPTIONS_PIC)
				list (APPEND _compileFlags "${CMAKE_${_language}_COMPILE_OPTIONS_PIC}")
			endif()
		endif()
	endif()
	# handle visibility target properties
	if (_target)
		get_target_property(_targetVisibility ${_target} ${_language}_VISIBILITY_PRESET)
		if (_targetVisibility AND CMAKE_${_language}_COMPILE_OPTIONS_VISIBILITY)
			list (APPEND _compileFlags "${CMAKE_${_language}_COMPILE_OPTIONS_VISIBILITY}${_targetVisibility}")
		endif()
		get_target_property(_targetVisibilityInlines ${_target} VISIBILITY_INLINES_HIDDEN)
		if (_targetVisibilityInlines AND CMAKE_${_language}_COMPILE_OPTIONS_VISIBILITY_INLINES_HIDDEN)
			list (APPEND _compileFlags "${CMAKE_${_language}_COMPILE_OPTIONS_VISIBILITY_INLINES_HIDDEN}")
		endif()
	endif()
	# platform specific flags
	if (APPLE)
		get_target_property(_architectures ${_target} OSX_ARCHITECTURES_${_upperConfig})
		if (NOT _architectures)
			get_target_property(_architectures ${_target} OSX_ARCHITECTURES)
		endif()
		if (_architectures)
			foreach (_arch ${_architectures})
				list (APPEND _compileFlags "-arch" "${_arch}")
			endforeach()
		endif()
		if (CMAKE_OSX_SYSROOT)
			if (CMAKE_${_language}_SYSROOT_FLAG)
				list (APPEND _compileFlags "${CMAKE_${_language}_SYSROOT_FLAG}" "${CMAKE_OSX_SYSROOT}")
			else()
				list (APPEND _compileFlags "-isysroot" "${CMAKE_OSX_SYSROOT}")
			endif()
		endif()
		if (CMAKE_OSX_DEPLOYMENT_TARGET)
			if (CMAKE_${_language}_OSX_DEPLOYMENT_TARGET_FLAG)
				list (APPEND _compileFlags "${CMAKE_${_language}_OSX_DEPLOYMENT_TARGET_FLAG}${CMAKE_OSX_DEPLOYMENT_TARGET}")
			else()
				list (APPEND _compileFlags "-mmacosx-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}")
			endif()
		endif()
	endif()
	if (COTIRE_DEBUG AND _compileFlags)
		message (STATUS "Target ${_target} compile flags: ${_compileFlags}")
	endif()
	set (${_flagsVar} ${_compileFlags} PARENT_SCOPE)
endfunction()

function (cotire_get_target_include_directories _config _language _target _includeDirsVar _systemIncludeDirsVar)
	set (_includeDirs "")
	set (_systemIncludeDirs "")
	# default include dirs
	if (CMAKE_INCLUDE_CURRENT_DIR)
		list (APPEND _includeDirs "${CMAKE_CURRENT_BINARY_DIR}")
		list (APPEND _includeDirs "${CMAKE_CURRENT_SOURCE_DIR}")
	endif()
	set (_targetFlags "")
	cotire_get_target_compile_flags("${_config}" "${_language}" "${_target}" _targetFlags)
	# parse additional include directories from target compile flags
	if (CMAKE_INCLUDE_FLAG_${_language})
		string (STRIP "${CMAKE_INCLUDE_FLAG_${_language}}" _includeFlag)
		string (REGEX REPLACE "^[-/]+" "" _includeFlag "${_includeFlag}")
		if (_includeFlag)
			set (_dirs "")
			cotire_filter_compile_flags("${_language}" "${_includeFlag}" _dirs _ignore ${_targetFlags})
			if (_dirs)
				list (APPEND _includeDirs ${_dirs})
			endif()
		endif()
	endif()
	# parse additional system include directories from target compile flags
	if (CMAKE_INCLUDE_SYSTEM_FLAG_${_language})
		string (STRIP "${CMAKE_INCLUDE_SYSTEM_FLAG_${_language}}" _includeFlag)
		string (REGEX REPLACE "^[-/]+" "" _includeFlag "${_includeFlag}")
		if (_includeFlag)
			set (_dirs "")
			cotire_filter_compile_flags("${_language}" "${_includeFlag}" _dirs _ignore ${_targetFlags})
			if (_dirs)
				list (APPEND _systemIncludeDirs ${_dirs})
			endif()
		endif()
	endif()
	# target include directories
	get_directory_property(_dirs DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" INCLUDE_DIRECTORIES)
	if (_target)
		get_target_property(_targetDirs ${_target} INCLUDE_DIRECTORIES)
		if (_targetDirs)
			list (APPEND _dirs ${_targetDirs})
		endif()
		get_target_property(_targetDirs ${_target} INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)
		if (_targetDirs)
			list (APPEND _systemIncludeDirs ${_targetDirs})
		endif()
	endif()
	# interface include directories from linked library targets
	if (_target)
		set (_linkedTargets "")
		cotire_get_target_usage_requirements(${_target} ${_config} _linkedTargets)
		foreach (_linkedTarget ${_linkedTargets})
			get_target_property(_linkedTargetType ${_linkedTarget} TYPE)
			if (CMAKE_INCLUDE_CURRENT_DIR_IN_INTERFACE AND NOT CMAKE_VERSION VERSION_LESS "3.4.0" AND
				_linkedTargetType MATCHES "(STATIC|SHARED|MODULE|OBJECT)_LIBRARY")
				# CMAKE_INCLUDE_CURRENT_DIR_IN_INTERFACE refers to CMAKE_CURRENT_BINARY_DIR and CMAKE_CURRENT_SOURCE_DIR
				# at the time, when the target was created. These correspond to the target properties BINARY_DIR and SOURCE_DIR
				# which are only available with CMake 3.4 or later.
				get_target_property(_targetDirs ${_linkedTarget} BINARY_DIR)
				if (_targetDirs)
					list (APPEND _dirs ${_targetDirs})
				endif()
				get_target_property(_targetDirs ${_linkedTarget} SOURCE_DIR)
				if (_targetDirs)
					list (APPEND _dirs ${_targetDirs})
				endif()
			endif()
			get_target_property(_targetDirs ${_linkedTarget} INTERFACE_INCLUDE_DIRECTORIES)
			if (_targetDirs)
				list (APPEND _dirs ${_targetDirs})
			endif()
			get_target_property(_targetDirs ${_linkedTarget} INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)
			if (_targetDirs)
				list (APPEND _systemIncludeDirs ${_targetDirs})
			endif()
		endforeach()
	endif()
	if (dirs)
		list (REMOVE_DUPLICATES _dirs)
	endif()
	list (LENGTH _includeDirs _projectInsertIndex)
	foreach (_dir ${_dirs})
		if (CMAKE_INCLUDE_DIRECTORIES_PROJECT_BEFORE)
			cotire_check_is_path_relative_to("${_dir}" _isRelative "${CMAKE_SOURCE_DIR}" "${CMAKE_BINARY_DIR}")
			if (_isRelative)
				list (LENGTH _includeDirs _len)
				if (_len EQUAL _projectInsertIndex)
					list (APPEND _includeDirs "${_dir}")
				else()
					list (INSERT _includeDirs _projectInsertIndex "${_dir}")
				endif()
				math (EXPR _projectInsertIndex "${_projectInsertIndex} + 1")
			else()
				list (APPEND _includeDirs "${_dir}")
			endif()
		else()
			list (APPEND _includeDirs "${_dir}")
		endif()
	endforeach()
	list (REMOVE_DUPLICATES _includeDirs)
	list (REMOVE_DUPLICATES _systemIncludeDirs)
	if (CMAKE_${_language}_IMPLICIT_INCLUDE_DIRECTORIES)
		list (REMOVE_ITEM _includeDirs ${CMAKE_${_language}_IMPLICIT_INCLUDE_DIRECTORIES})
	endif()
	if (WIN32 AND NOT MINGW)
		# convert Windows paths in include directories to CMake paths
		if (_includeDirs)
			set (_paths "")
			foreach (_dir ${_includeDirs})
				file (TO_CMAKE_PATH "${_dir}" _path)
				list (APPEND _paths "${_path}")
			endforeach()
			set (_includeDirs ${_paths})
		endif()
		if (_systemIncludeDirs)
			set (_paths "")
			foreach (_dir ${_systemIncludeDirs})
				file (TO_CMAKE_PATH "${_dir}" _path)
				list (APPEND _paths "${_path}")
			endforeach()
			set (_systemIncludeDirs ${_paths})
		endif()
	endif()
	if (COTIRE_DEBUG AND _includeDirs)
		message (STATUS "Target ${_target} include dirs: ${_includeDirs}")
	endif()
	set (${_includeDirsVar} ${_includeDirs} PARENT_SCOPE)
	if (COTIRE_DEBUG AND _systemIncludeDirs)
		message (STATUS "Target ${_target} system include dirs: ${_systemIncludeDirs}")
	endif()
	set (${_systemIncludeDirsVar} ${_systemIncludeDirs} PARENT_SCOPE)
endfunction()

function (cotire_get_target_export_symbol _target _exportSymbolVar)
	set (_exportSymbol "")
	get_target_property(_targetType ${_target} TYPE)
	get_target_property(_enableExports ${_target} ENABLE_EXPORTS)
	if (_targetType MATCHES "(SHARED|MODULE)_LIBRARY" OR
		(_targetType STREQUAL "EXECUTABLE" AND _enableExports))
		get_target_property(_exportSymbol ${_target} DEFINE_SYMBOL)
		if (NOT _exportSymbol)
			set (_exportSymbol "${_target}_EXPORTS")
		endif()
		string (MAKE_C_IDENTIFIER "${_exportSymbol}" _exportSymbol)
	endif()
	set (${_exportSymbolVar} ${_exportSymbol} PARENT_SCOPE)
endfunction()

function (cotire_get_target_compile_definitions _config _language _target _definitionsVar)
	string (TOUPPER "${_config}" _upperConfig)
	set (_configDefinitions "")
	# CMAKE_INTDIR for multi-configuration build systems
	if (NOT "${CMAKE_CFG_INTDIR}" STREQUAL ".")
		list (APPEND _configDefinitions "CMAKE_INTDIR=\"${_config}\"")
	endif()
	# target export define symbol
	cotire_get_target_export_symbol("${_target}" _defineSymbol)
	if (_defineSymbol)
		list (APPEND _configDefinitions "${_defineSymbol}")
	endif()
	# directory compile definitions
	get_directory_property(_definitions DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" COMPILE_DEFINITIONS)
	if (_definitions)
		list (APPEND _configDefinitions ${_definitions})
	endif()
	get_directory_property(_definitions DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" COMPILE_DEFINITIONS_${_upperConfig})
	if (_definitions)
		list (APPEND _configDefinitions ${_definitions})
	endif()
	# target compile definitions
	get_target_property(_definitions ${_target} COMPILE_DEFINITIONS)
	if (_definitions)
		list (APPEND _configDefinitions ${_definitions})
	endif()
	get_target_property(_definitions ${_target} COMPILE_DEFINITIONS_${_upperConfig})
	if (_definitions)
		list (APPEND _configDefinitions ${_definitions})
	endif()
	# interface compile definitions from linked library targets
	set (_linkedTargets "")
	cotire_get_target_usage_requirements(${_target} ${_config} _linkedTargets)
	foreach (_linkedTarget ${_linkedTargets})
		get_target_property(_definitions ${_linkedTarget} INTERFACE_COMPILE_DEFINITIONS)
		if (_definitions)
			list (APPEND _configDefinitions ${_definitions})
		endif()
	endforeach()
	# parse additional compile definitions from target compile flags
	# and don't look at directory compile definitions, which we already handled
	set (_targetFlags "")
	cotire_get_target_compile_flags("${_config}" "${_language}" "${_target}" _targetFlags)
	cotire_filter_compile_flags("${_language}" "D" _definitions _ignore ${_targetFlags})
	if (_definitions)
		list (APPEND _configDefinitions ${_definitions})
	endif()
	list (REMOVE_DUPLICATES _configDefinitions)
	if (COTIRE_DEBUG AND _configDefinitions)
		message (STATUS "Target ${_target} compile definitions: ${_configDefinitions}")
	endif()
	set (${_definitionsVar} ${_configDefinitions} PARENT_SCOPE)
endfunction()

function (cotire_get_target_compiler_flags _config _language _target _compilerFlagsVar)
	# parse target compile flags omitting compile definitions and include directives
	set (_targetFlags "")
	cotire_get_target_compile_flags("${_config}" "${_language}" "${_target}" _targetFlags)
	set (_flagFilter "D")
	if (CMAKE_INCLUDE_FLAG_${_language})
		string (STRIP "${CMAKE_INCLUDE_FLAG_${_language}}" _includeFlag)
		string (REGEX REPLACE "^[-/]+" "" _includeFlag "${_includeFlag}")
		if (_includeFlag)
			set (_flagFilter "${_flagFilter}|${_includeFlag}")
		endif()
	endif()
	if (CMAKE_INCLUDE_SYSTEM_FLAG_${_language})
		string (STRIP "${CMAKE_INCLUDE_SYSTEM_FLAG_${_language}}" _includeFlag)
		string (REGEX REPLACE "^[-/]+" "" _includeFlag "${_includeFlag}")
		if (_includeFlag)
			set (_flagFilter "${_flagFilter}|${_includeFlag}")
		endif()
	endif()
	set (_compilerFlags "")
	cotire_filter_compile_flags("${_language}" "${_flagFilter}" _ignore _compilerFlags ${_targetFlags})
	if (COTIRE_DEBUG AND _compilerFlags)
		message (STATUS "Target ${_target} compiler flags: ${_compilerFlags}")
	endif()
	set (${_compilerFlagsVar} ${_compilerFlags} PARENT_SCOPE)
endfunction()

function (cotire_add_sys_root_paths _pathsVar)
	if (APPLE)
		if (CMAKE_OSX_SYSROOT AND CMAKE_${_language}_HAS_ISYSROOT)
			foreach (_path IN LISTS ${_pathsVar})
				if (IS_ABSOLUTE "${_path}")
					get_filename_component(_path "${CMAKE_OSX_SYSROOT}/${_path}" ABSOLUTE)
					if (EXISTS "${_path}")
						list (APPEND ${_pathsVar} "${_path}")
					endif()
				endif()
			endforeach()
		endif()
	endif()
	set (${_pathsVar} ${${_pathsVar}} PARENT_SCOPE)
endfunction()

function (cotire_get_source_extra_properties _sourceFile _pattern _resultVar)
	set (_extraProperties ${ARGN})
	set (_result "")
	if (_extraProperties)
		list (FIND _extraProperties "${_sourceFile}" _index)
		if (_index GREATER -1)
			math (EXPR _index "${_index} + 1")
			list (LENGTH _extraProperties _len)
			math (EXPR _len "${_len} - 1")
			foreach (_index RANGE ${_index} ${_len})
				list (GET _extraProperties ${_index} _value)
				if (_value MATCHES "${_pattern}")
					list (APPEND _result "${_value}")
				else()
					break()
				endif()
			endforeach()
		endif()
	endif()
	set (${_resultVar} ${_result} PARENT_SCOPE)
endfunction()

function (cotire_get_source_compile_definitions _config _language _sourceFile _definitionsVar)
	set (_compileDefinitions "")
	if (NOT CMAKE_SCRIPT_MODE_FILE)
		string (TOUPPER "${_config}" _upperConfig)
		get_source_file_property(_definitions "${_sourceFile}" COMPILE_DEFINITIONS)
		if (_definitions)
			list (APPEND _compileDefinitions ${_definitions})
		endif()
		get_source_file_property(_definitions "${_sourceFile}" COMPILE_DEFINITIONS_${_upperConfig})
		if (_definitions)
			list (APPEND _compileDefinitions ${_definitions})
		endif()
	endif()
	cotire_get_source_extra_properties("${_sourceFile}" "^[a-zA-Z0-9_]+(=.*)?$" _definitions ${ARGN})
	if (_definitions)
		list (APPEND _compileDefinitions ${_definitions})
	endif()
	if (COTIRE_DEBUG AND _compileDefinitions)
		message (STATUS "Source ${_sourceFile} compile definitions: ${_compileDefinitions}")
	endif()
	set (${_definitionsVar} ${_compileDefinitions} PARENT_SCOPE)
endfunction()

function (cotire_get_source_files_compile_definitions _config _language _definitionsVar)
	set (_configDefinitions "")
	foreach (_sourceFile ${ARGN})
		cotire_get_source_compile_definitions("${_config}" "${_language}" "${_sourceFile}" _sourceDefinitions)
		if (_sourceDefinitions)
			list (APPEND _configDefinitions "${_sourceFile}" ${_sourceDefinitions} "-")
		endif()
	endforeach()
	set (${_definitionsVar} ${_configDefinitions} PARENT_SCOPE)
endfunction()

function (cotire_get_source_undefs _sourceFile _property _sourceUndefsVar)
	set (_sourceUndefs "")
	if (NOT CMAKE_SCRIPT_MODE_FILE)
		get_source_file_property(_undefs "${_sourceFile}" ${_property})
		if (_undefs)
			list (APPEND _sourceUndefs ${_undefs})
		endif()
	endif()
	cotire_get_source_extra_properties("${_sourceFile}" "^[a-zA-Z0-9_]+$" _undefs ${ARGN})
	if (_undefs)
		list (APPEND _sourceUndefs ${_undefs})
	endif()
	if (COTIRE_DEBUG AND _sourceUndefs)
		message (STATUS "Source ${_sourceFile} ${_property} undefs: ${_sourceUndefs}")
	endif()
	set (${_sourceUndefsVar} ${_sourceUndefs} PARENT_SCOPE)
endfunction()

function (cotire_get_source_files_undefs _property _sourceUndefsVar)
	set (_sourceUndefs "")
	foreach (_sourceFile ${ARGN})
		cotire_get_source_undefs("${_sourceFile}" ${_property} _undefs)
		if (_undefs)
			list (APPEND _sourceUndefs "${_sourceFile}" ${_undefs} "-")
		endif()
	endforeach()
	set (${_sourceUndefsVar} ${_sourceUndefs} PARENT_SCOPE)
endfunction()

macro (cotire_set_cmd_to_prologue _cmdVar)
	set (${_cmdVar} "${CMAKE_COMMAND}")
	if (COTIRE_DEBUG)
		list (APPEND ${_cmdVar} "--warn-uninitialized")
	endif()
	list (APPEND ${_cmdVar} "-DCOTIRE_BUILD_TYPE:STRING=$<CONFIGURATION>")
	if (XCODE)
		list (APPEND ${_cmdVar} "-DXCODE:BOOL=TRUE")
	endif()
	if (COTIRE_VERBOSE)
		list (APPEND ${_cmdVar} "-DCOTIRE_VERBOSE:BOOL=ON")
	elseif("${CMAKE_GENERATOR}" MATCHES "Makefiles")
		list (APPEND ${_cmdVar} "-DCOTIRE_VERBOSE:BOOL=$(VERBOSE)")
	endif()
endmacro()

function (cotire_init_compile_cmd _cmdVar _language _compilerLauncher _compilerExe _compilerArg1)
	if (NOT _compilerLauncher)
		set (_compilerLauncher ${CMAKE_${_language}_COMPILER_LAUNCHER})
	endif()
	if (NOT _compilerExe)
		set (_compilerExe "${CMAKE_${_language}_COMPILER}")
	endif()
	if (NOT _compilerArg1)
		set (_compilerArg1 ${CMAKE_${_language}_COMPILER_ARG1})
	endif()
	string (STRIP "${_compilerArg1}" _compilerArg1)
	if ("${CMAKE_GENERATOR}" MATCHES "Make|Ninja")
		# compiler launcher is only supported for Makefile and Ninja
		set (${_cmdVar} ${_compilerLauncher} "${_compilerExe}" ${_compilerArg1} PARENT_SCOPE)
	else()
		set (${_cmdVar} "${_compilerExe}" ${_compilerArg1} PARENT_SCOPE)
	endif()
endfunction()

macro (cotire_add_definitions_to_cmd _cmdVar _language)
	foreach (_definition ${ARGN})
		if (WIN32 AND CMAKE_${_language}_COMPILER_ID MATCHES "MSVC|Intel")
			list (APPEND ${_cmdVar} "/D${_definition}")
		else()
			list (APPEND ${_cmdVar} "-D${_definition}")
		endif()
	endforeach()
endmacro()

function (cotire_add_includes_to_cmd _cmdVar _language _includesVar _systemIncludesVar)
	set (_includeDirs ${${_includesVar}} ${${_systemIncludesVar}})
	if (_includeDirs)
		list (REMOVE_DUPLICATES _includeDirs)
		foreach (_include ${_includeDirs})
			if (WIN32 AND CMAKE_${_language}_COMPILER_ID MATCHES "MSVC|Intel")
				file (TO_NATIVE_PATH "${_include}" _include)
				list (APPEND ${_cmdVar} "${CMAKE_INCLUDE_FLAG_${_language}}${CMAKE_INCLUDE_FLAG_SEP_${_language}}${_include}")
			else()
				set (_index -1)
				if ("${CMAKE_INCLUDE_SYSTEM_FLAG_${_language}}" MATCHES ".+")
					list (FIND ${_systemIncludesVar} "${_include}" _index)
				endif()
				if (_index GREATER -1)
					list (APPEND ${_cmdVar} "${CMAKE_INCLUDE_SYSTEM_FLAG_${_language}}${CMAKE_INCLUDE_FLAG_SEP_${_language}}${_include}")
				else()
					list (APPEND ${_cmdVar} "${CMAKE_INCLUDE_FLAG_${_language}}${CMAKE_INCLUDE_FLAG_SEP_${_language}}${_include}")
				endif()
			endif()
		endforeach()
	endif()
	set (${_cmdVar} ${${_cmdVar}} PARENT_SCOPE)
endfunction()

function (cotire_add_frameworks_to_cmd _cmdVar _language _includesVar _systemIncludesVar)
	if (APPLE)
		set (_frameworkDirs "")
		foreach (_include ${${_includesVar}})
			if (IS_ABSOLUTE "${_include}" AND _include MATCHES "\\.framework$")
				get_filename_component(_frameworkDir "${_include}" DIRECTORY)
				list (APPEND _frameworkDirs "${_frameworkDir}")
			endif()
		endforeach()
		set (_systemFrameworkDirs "")
		foreach (_include ${${_systemIncludesVar}})
			if (IS_ABSOLUTE "${_include}" AND _include MATCHES "\\.framework$")
				get_filename_component(_frameworkDir "${_include}" DIRECTORY)
				list (APPEND _systemFrameworkDirs "${_frameworkDir}")
			endif()
		endforeach()
		if (_systemFrameworkDirs)
			list (APPEND _frameworkDirs ${_systemFrameworkDirs})
		endif()
		if (_frameworkDirs)
			list (REMOVE_DUPLICATES _frameworkDirs)
			foreach (_frameworkDir ${_frameworkDirs})
				set (_index -1)
				if ("${CMAKE_${_language}_SYSTEM_FRAMEWORK_SEARCH_FLAG}" MATCHES ".+")
					list (FIND _systemFrameworkDirs "${_frameworkDir}" _index)
				endif()
				if (_index GREATER -1)
					list (APPEND ${_cmdVar} "${CMAKE_${_language}_SYSTEM_FRAMEWORK_SEARCH_FLAG}${_frameworkDir}")
				else()
					list (APPEND ${_cmdVar} "${CMAKE_${_language}_FRAMEWORK_SEARCH_FLAG}${_frameworkDir}")
				endif()
			endforeach()
		endif()
	endif()
	set (${_cmdVar} ${${_cmdVar}} PARENT_SCOPE)
endfunction()

macro (cotire_add_compile_flags_to_cmd _cmdVar)
	foreach (_flag ${ARGN})
		list (APPEND ${_cmdVar} "${_flag}")
	endforeach()
endmacro()

function (cotire_check_file_up_to_date _fileIsUpToDateVar _file)
	if (EXISTS "${_file}")
		set (_triggerFile "")
		foreach (_dependencyFile ${ARGN})
			if (EXISTS "${_dependencyFile}")
				# IS_NEWER_THAN returns TRUE if both files have the same timestamp
				# thus we do the comparison in both directions to exclude ties
				if ("${_dependencyFile}" IS_NEWER_THAN "${_file}" AND
					NOT "${_file}" IS_NEWER_THAN "${_dependencyFile}")
					set (_triggerFile "${_dependencyFile}")
					break()
				endif()
			endif()
		endforeach()
		if (_triggerFile)
			if (COTIRE_VERBOSE)
				get_filename_component(_fileName "${_file}" NAME)
				message (STATUS "${_fileName} update triggered by ${_triggerFile} change.")
			endif()
			set (${_fileIsUpToDateVar} FALSE PARENT_SCOPE)
		else()
			if (COTIRE_VERBOSE)
				get_filename_component(_fileName "${_file}" NAME)
				message (STATUS "${_fileName} is up-to-date.")
			endif()
			set (${_fileIsUpToDateVar} TRUE PARENT_SCOPE)
		endif()
	else()
		if (COTIRE_VERBOSE)
			get_filename_component(_fileName "${_file}" NAME)
			message (STATUS "${_fileName} does not exist yet.")
		endif()
		set (${_fileIsUpToDateVar} FALSE PARENT_SCOPE)
	endif()
endfunction()

macro (cotire_find_closest_relative_path _headerFile _includeDirs _relPathVar)
	set (${_relPathVar} "")
	foreach (_includeDir ${_includeDirs})
		if (IS_DIRECTORY "${_includeDir}")
			file (RELATIVE_PATH _relPath "${_includeDir}" "${_headerFile}")
			if (NOT IS_ABSOLUTE "${_relPath}" AND NOT "${_relPath}" MATCHES "^\\.\\.")
				string (LENGTH "${${_relPathVar}}" _closestLen)
				string (LENGTH "${_relPath}" _relLen)
				if (_closestLen EQUAL 0 OR _relLen LESS _closestLen)
					set (${_relPathVar} "${_relPath}")
				endif()
			endif()
		elseif ("${_includeDir}" STREQUAL "${_headerFile}")
			# if path matches exactly, return short non-empty string
			set (${_relPathVar} "1")
			break()
		endif()
	endforeach()
endmacro()

macro (cotire_check_header_file_location _headerFile _insideIncludeDirs _outsideIncludeDirs _headerIsInside)
	# check header path against ignored and honored include directories
	cotire_find_closest_relative_path("${_headerFile}" "${_insideIncludeDirs}" _insideRelPath)
	if (_insideRelPath)
		# header is inside, but could be become outside if there is a shorter outside match
		cotire_find_closest_relative_path("${_headerFile}" "${_outsideIncludeDirs}" _outsideRelPath)
		if (_outsideRelPath)
			string (LENGTH "${_insideRelPath}" _insideRelPathLen)
			string (LENGTH "${_outsideRelPath}" _outsideRelPathLen)
			if (_outsideRelPathLen LESS _insideRelPathLen)
				set (${_headerIsInside} FALSE)
			else()
				set (${_headerIsInside} TRUE)
			endif()
		else()
			set (${_headerIsInside} TRUE)
		endif()
	else()
		# header is outside
		set (${_headerIsInside} FALSE)
	endif()
endmacro()

macro (cotire_check_ignore_header_file_path _headerFile _headerIsIgnoredVar)
	if (NOT EXISTS "${_headerFile}")
		set (${_headerIsIgnoredVar} TRUE)
	elseif (IS_DIRECTORY "${_headerFile}")
		set (${_headerIsIgnoredVar} TRUE)
	elseif ("${_headerFile}" MATCHES "\\.\\.|[_-]fixed" AND "${_headerFile}" MATCHES "\\.h$")
		# heuristic: ignore C headers with embedded parent directory references or "-fixed" or "_fixed" in path
		# these often stem from using GCC #include_next tricks, which may break the precompiled header compilation
		# with the error message "error: no include path in which to search for header.h"
		set (${_headerIsIgnoredVar} TRUE)
	else()
		set (${_headerIsIgnoredVar} FALSE)
	endif()
endmacro()

macro (cotire_check_ignore_header_file_ext _headerFile _ignoreExtensionsVar _headerIsIgnoredVar)
	# check header file extension
	cotire_get_source_file_extension("${_headerFile}" _headerFileExt)
	set (${_headerIsIgnoredVar} FALSE)
	if (_headerFileExt)
		list (FIND ${_ignoreExtensionsVar} "${_headerFileExt}" _index)
		if (_index GREATER -1)
			set (${_headerIsIgnoredVar} TRUE)
		endif()
	endif()
endmacro()

macro (cotire_parse_line _line _headerFileVar _headerDepthVar)
	if (MSVC)
		# cl.exe /showIncludes output looks different depending on the language pack used, e.g.:
		# English: "Note: including file:   C:\directory\file"
		# German: "Hinweis: Einlesen der Datei:   C:\directory\file"
		# We use a very general regular expression, relying on the presence of the : characters
		if (_line MATCHES "( +)([a-zA-Z]:[^:]+)$")
			# Visual Studio compiler output
			string (LENGTH "${CMAKE_MATCH_1}" ${_headerDepthVar})
			get_filename_component(${_headerFileVar} "${CMAKE_MATCH_2}" ABSOLUTE)
		else()
			set (${_headerFileVar} "")
			set (${_headerDepthVar} 0)
		endif()
	else()
		if (_line MATCHES "^(\\.+) (.*)$")
			# GCC like output
			string (LENGTH "${CMAKE_MATCH_1}" ${_headerDepthVar})
			if (IS_ABSOLUTE "${CMAKE_MATCH_2}")
				set (${_headerFileVar} "${CMAKE_MATCH_2}")
			else()
				get_filename_component(${_headerFileVar} "${CMAKE_MATCH_2}" REALPATH)
			endif()
		else()
			set (${_headerFileVar} "")
			set (${_headerDepthVar} 0)
		endif()
	endif()
endmacro()

function (cotire_parse_includes _language _scanOutput _ignoredIncludeDirs _honoredIncludeDirs _ignoredExtensions _selectedIncludesVar _unparsedLinesVar)
	if (WIN32)
		# prevent CMake macro invocation errors due to backslash characters in Windows paths
		string (REPLACE "\\" "/" _scanOutput "${_scanOutput}")
	endif()
	# canonize slashes
	string (REPLACE "//" "/" _scanOutput "${_scanOutput}")
	# prevent semicolon from being interpreted as a line separator
	string (REPLACE ";" "\\;" _scanOutput "${_scanOutput}")
	# then separate lines
	string (REGEX REPLACE "\n" ";" _scanOutput "${_scanOutput}")
	list (LENGTH _scanOutput _len)
	# remove duplicate lines to speed up parsing
	list (REMOVE_DUPLICATES _scanOutput)
	list (LENGTH _scanOutput _uniqueLen)
	if (COTIRE_VERBOSE OR COTIRE_DEBUG)
		message (STATUS "Scanning ${_uniqueLen} unique lines of ${_len} for includes")
		if (_ignoredExtensions)
			message (STATUS "Ignored extensions: ${_ignoredExtensions}")
		endif()
		if (_ignoredIncludeDirs)
			message (STATUS "Ignored paths: ${_ignoredIncludeDirs}")
		endif()
		if (_honoredIncludeDirs)
			message (STATUS "Included paths: ${_honoredIncludeDirs}")
		endif()
	endif()
	set (_sourceFiles ${ARGN})
	set (_selectedIncludes "")
	set (_unparsedLines "")
	# stack keeps track of inside/outside project status of processed header files
	set (_headerIsInsideStack "")
	foreach (_line IN LISTS _scanOutput)
		if (_line)
			cotire_parse_line("${_line}" _headerFile _headerDepth)
			if (_headerFile)
				cotire_check_header_file_location("${_headerFile}" "${_ignoredIncludeDirs}" "${_honoredIncludeDirs}" _headerIsInside)
				if (COTIRE_DEBUG)
					message (STATUS "${_headerDepth}: ${_headerFile} ${_headerIsInside}")
				endif()
				# update stack
				list (LENGTH _headerIsInsideStack _stackLen)
				if (_headerDepth GREATER _stackLen)
					math (EXPR _stackLen "${_stackLen} + 1")
					foreach (_index RANGE ${_stackLen} ${_headerDepth})
						list (APPEND _headerIsInsideStack ${_headerIsInside})
					endforeach()
				else()
					foreach (_index RANGE ${_headerDepth} ${_stackLen})
						list (REMOVE_AT _headerIsInsideStack -1)
					endforeach()
					list (APPEND _headerIsInsideStack ${_headerIsInside})
				endif()
				if (COTIRE_DEBUG)
					message (STATUS "${_headerIsInsideStack}")
				endif()
				# header is a candidate if it is outside project
				if (NOT _headerIsInside)
					# get parent header file's inside/outside status
					if (_headerDepth GREATER 1)
						math (EXPR _index "${_headerDepth} - 2")
						list (GET _headerIsInsideStack ${_index} _parentHeaderIsInside)
					else()
						set (_parentHeaderIsInside TRUE)
					endif()
					# select header file if parent header file is inside project
					# (e.g., a project header file that includes a standard header file)
					if (_parentHeaderIsInside)
						cotire_check_ignore_header_file_path("${_headerFile}" _headerIsIgnored)
						if (NOT _headerIsIgnored)
							cotire_check_ignore_header_file_ext("${_headerFile}" _ignoredExtensions _headerIsIgnored)
							if (NOT _headerIsIgnored)
								list (APPEND _selectedIncludes "${_headerFile}")
							else()
								# fix header's inside status on stack, it is ignored by extension now
								list (REMOVE_AT _headerIsInsideStack -1)
								list (APPEND _headerIsInsideStack TRUE)
							endif()
						endif()
						if (COTIRE_DEBUG)
							message (STATUS "${_headerFile} ${_ignoredExtensions} ${_headerIsIgnored}")
						endif()
					endif()
				endif()
			else()
				if (MSVC)
					# for cl.exe do not keep unparsed lines which solely consist of a source file name
					string (FIND "${_sourceFiles}" "${_line}" _index)
					if (_index LESS 0)
						list (APPEND _unparsedLines "${_line}")
					endif()
				else()
					list (APPEND _unparsedLines "${_line}")
				endif()
			endif()
		endif()
	endforeach()
	list (REMOVE_DUPLICATES _selectedIncludes)
	set (${_selectedIncludesVar} ${_selectedIncludes} PARENT_SCOPE)
	set (${_unparsedLinesVar} ${_unparsedLines} PARENT_SCOPE)
endfunction()

function (cotire_scan_includes _includesVar)
	set(_options "")
	set(_oneValueArgs COMPILER_ID COMPILER_EXECUTABLE COMPILER_ARG1 COMPILER_VERSION LANGUAGE UNPARSED_LINES SCAN_RESULT)
	set(_multiValueArgs COMPILE_DEFINITIONS COMPILE_FLAGS INCLUDE_DIRECTORIES SYSTEM_INCLUDE_DIRECTORIES
		IGNORE_PATH INCLUDE_PATH IGNORE_EXTENSIONS INCLUDE_PRIORITY_PATH COMPILER_LAUNCHER)
	cmake_parse_arguments(_option "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})
	set (_sourceFiles ${_option_UNPARSED_ARGUMENTS})
	if (NOT _option_LANGUAGE)
		set (_option_LANGUAGE "CXX")
	endif()
	if (NOT _option_COMPILER_ID)
		set (_option_COMPILER_ID "${CMAKE_${_option_LANGUAGE}_ID}")
	endif()
	if (NOT _option_COMPILER_VERSION)
		set (_option_COMPILER_VERSION "${CMAKE_${_option_LANGUAGE}_COMPILER_VERSION}")
	endif()
	cotire_init_compile_cmd(_cmd "${_option_LANGUAGE}" "${_option_COMPILER_LAUNCHER}" "${_option_COMPILER_EXECUTABLE}" "${_option_COMPILER_ARG1}")
	cotire_add_definitions_to_cmd(_cmd "${_option_LANGUAGE}" ${_option_COMPILE_DEFINITIONS})
	cotire_add_compile_flags_to_cmd(_cmd ${_option_COMPILE_FLAGS})
	cotire_add_includes_to_cmd(_cmd "${_option_LANGUAGE}" _option_INCLUDE_DIRECTORIES _option_SYSTEM_INCLUDE_DIRECTORIES)
	cotire_add_frameworks_to_cmd(_cmd "${_option_LANGUAGE}" _option_INCLUDE_DIRECTORIES _option_SYSTEM_INCLUDE_DIRECTORIES)
	cotire_add_makedep_flags("${_option_LANGUAGE}" "${_option_COMPILER_ID}" "${_option_COMPILER_VERSION}" _cmd)
	# only consider existing source files for scanning
	set (_existingSourceFiles "")
	foreach (_sourceFile ${_sourceFiles})
		if (EXISTS "${_sourceFile}")
			list (APPEND _existingSourceFiles "${_sourceFile}")
		endif()
	endforeach()
	if (NOT _existingSourceFiles)
		set (${_includesVar} "" PARENT_SCOPE)
		return()
	endif()
	list (APPEND _cmd ${_existingSourceFiles})
	if (COTIRE_VERBOSE)
		message (STATUS "execute_process: ${_cmd}")
	endif()
	if (_option_COMPILER_ID MATCHES "MSVC")
		# cl.exe messes with the output streams unless the environment variable VS_UNICODE_OUTPUT is cleared
		unset (ENV{VS_UNICODE_OUTPUT})
	endif()
	execute_process(
		COMMAND ${_cmd}
		WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
		RESULT_VARIABLE _result
		OUTPUT_QUIET
		ERROR_VARIABLE _output)
	if (_result)
		message (STATUS "Result ${_result} scanning includes of ${_existingSourceFiles}.")
	endif()
	cotire_parse_includes(
		"${_option_LANGUAGE}" "${_output}"
		"${_option_IGNORE_PATH}" "${_option_INCLUDE_PATH}"
		"${_option_IGNORE_EXTENSIONS}"
		_includes _unparsedLines
		${_sourceFiles})
	if (_option_INCLUDE_PRIORITY_PATH)
		set (_sortedIncludes "")
		foreach (_priorityPath ${_option_INCLUDE_PRIORITY_PATH})
			foreach (_include ${_includes})
				string (FIND ${_include} ${_priorityPath} _position)
				if (_position GREATER -1)
					list (APPEND _sortedIncludes ${_include})
				endif()
			endforeach()
		endforeach()
		if (_sortedIncludes)
			list (INSERT _includes 0 ${_sortedIncludes})
			list (REMOVE_DUPLICATES _includes)
		endif()
	endif()
	set (${_includesVar} ${_includes} PARENT_SCOPE)
	if (_option_UNPARSED_LINES)
		set (${_option_UNPARSED_LINES} ${_unparsedLines} PARENT_SCOPE)
	endif()
	if (_option_SCAN_RESULT)
		set (${_option_SCAN_RESULT} ${_result} PARENT_SCOPE)
	endif()
endfunction()

macro (cotire_append_undefs _contentsVar)
	set (_undefs ${ARGN})
	if (_undefs)
		list (REMOVE_DUPLICATES _undefs)
		foreach (_definition ${_undefs})
			list (APPEND ${_contentsVar} "#undef ${_definition}")
		endforeach()
	endif()
endmacro()

macro (cotire_comment_str _language _commentText _commentVar)
	if ("${_language}" STREQUAL "CMAKE")
		set (${_commentVar} "# ${_commentText}")
	else()
		set (${_commentVar} "/* ${_commentText} */")
	endif()
endmacro()

function (cotire_write_file _language _file _contents _force)
	get_filename_component(_moduleName "${COTIRE_CMAKE_MODULE_FILE}" NAME)
	cotire_comment_str("${_language}" "${_moduleName} ${COTIRE_CMAKE_MODULE_VERSION} generated file" _header1)
	cotire_comment_str("${_language}" "${_file}" _header2)
	set (_contents "${_header1}\n${_header2}\n${_contents}")
	if (COTIRE_DEBUG)
		message (STATUS "${_contents}")
	endif()
	if (_force OR NOT EXISTS "${_file}")
		file (WRITE "${_file}" "${_contents}")
	else()
		file (READ "${_file}" _oldContents)
		if (NOT "${_oldContents}" STREQUAL "${_contents}")
			file (WRITE "${_file}" "${_contents}")
		else()
			if (COTIRE_DEBUG)
				message (STATUS "${_file} unchanged")
			endif()
		endif()
	endif()
endfunction()

function (cotire_generate_unity_source _unityFile)
	set(_options "")
	set(_oneValueArgs LANGUAGE)
	set(_multiValueArgs
		DEPENDS SOURCES_COMPILE_DEFINITIONS
		PRE_UNDEFS SOURCES_PRE_UNDEFS POST_UNDEFS SOURCES_POST_UNDEFS PROLOGUE EPILOGUE)
	cmake_parse_arguments(_option "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})
	if (_option_DEPENDS)
		cotire_check_file_up_to_date(_unityFileIsUpToDate "${_unityFile}" ${_option_DEPENDS})
		if (_unityFileIsUpToDate)
			return()
		endif()
	endif()
	set (_sourceFiles ${_option_UNPARSED_ARGUMENTS})
	if (NOT _option_PRE_UNDEFS)
		set (_option_PRE_UNDEFS "")
	endif()
	if (NOT _option_SOURCES_PRE_UNDEFS)
		set (_option_SOURCES_PRE_UNDEFS "")
	endif()
	if (NOT _option_POST_UNDEFS)
		set (_option_POST_UNDEFS "")
	endif()
	if (NOT _option_SOURCES_POST_UNDEFS)
		set (_option_SOURCES_POST_UNDEFS "")
	endif()
	set (_contents "")
	if (_option_PROLOGUE)
		list (APPEND _contents ${_option_PROLOGUE})
	endif()
	if (_option_LANGUAGE AND _sourceFiles)
		if ("${_option_LANGUAGE}" STREQUAL "CXX")
			list (APPEND _contents "#ifdef __cplusplus")
		elseif ("${_option_LANGUAGE}" STREQUAL "C")
			list (APPEND _contents "#ifndef __cplusplus")
		endif()
	endif()
	set (_compileUndefinitions "")
	foreach (_sourceFile ${_sourceFiles})
		cotire_get_source_compile_definitions(
			"${_option_CONFIGURATION}" "${_option_LANGUAGE}" "${_sourceFile}" _compileDefinitions
			${_option_SOURCES_COMPILE_DEFINITIONS})
		cotire_get_source_undefs("${_sourceFile}" COTIRE_UNITY_SOURCE_PRE_UNDEFS _sourcePreUndefs ${_option_SOURCES_PRE_UNDEFS})
		cotire_get_source_undefs("${_sourceFile}" COTIRE_UNITY_SOURCE_POST_UNDEFS _sourcePostUndefs ${_option_SOURCES_POST_UNDEFS})
		if (_option_PRE_UNDEFS)
			list (APPEND _compileUndefinitions ${_option_PRE_UNDEFS})
		endif()
		if (_sourcePreUndefs)
			list (APPEND _compileUndefinitions ${_sourcePreUndefs})
		endif()
		if (_compileUndefinitions)
			cotire_append_undefs(_contents ${_compileUndefinitions})
			set (_compileUndefinitions "")
		endif()
		if (_sourcePostUndefs)
			list (APPEND _compileUndefinitions ${_sourcePostUndefs})
		endif()
		if (_option_POST_UNDEFS)
			list (APPEND _compileUndefinitions ${_option_POST_UNDEFS})
		endif()
		foreach (_definition ${_compileDefinitions})
			if (_definition MATCHES "^([a-zA-Z0-9_]+)=(.+)$")
				list (APPEND _contents "#define ${CMAKE_MATCH_1} ${CMAKE_MATCH_2}")
				list (INSERT _compileUndefinitions 0 "${CMAKE_MATCH_1}")
			else()
				list (APPEND _contents "#define ${_definition}")
				list (INSERT _compileUndefinitions 0 "${_definition}")
			endif()
		endforeach()
		# use absolute path as source file location
		get_filename_component(_sourceFileLocation "${_sourceFile}" ABSOLUTE)
		if (WIN32)
			file (TO_NATIVE_PATH "${_sourceFileLocation}" _sourceFileLocation)
		endif()
		list (APPEND _contents "#include \"${_sourceFileLocation}\"")
	endforeach()
	if (_compileUndefinitions)
		cotire_append_undefs(_contents ${_compileUndefinitions})
		set (_compileUndefinitions "")
	endif()
	if (_option_LANGUAGE AND _sourceFiles)
		list (APPEND _contents "#endif")
	endif()
	if (_option_EPILOGUE)
		list (APPEND _contents ${_option_EPILOGUE})
	endif()
	list (APPEND _contents "")
	string (REPLACE ";" "\n" _contents "${_contents}")
	if (COTIRE_VERBOSE)
		message ("${_contents}")
	endif()
	cotire_write_file("${_option_LANGUAGE}" "${_unityFile}" "${_contents}" TRUE)
endfunction()

function (cotire_generate_prefix_header _prefixFile)
	set(_options "")
	set(_oneValueArgs LANGUAGE COMPILER_EXECUTABLE COMPILER_ARG1 COMPILER_ID COMPILER_VERSION)
	set(_multiValueArgs DEPENDS COMPILE_DEFINITIONS COMPILE_FLAGS
		INCLUDE_DIRECTORIES SYSTEM_INCLUDE_DIRECTORIES IGNORE_PATH INCLUDE_PATH
		IGNORE_EXTENSIONS INCLUDE_PRIORITY_PATH COMPILER_LAUNCHER)
	cmake_parse_arguments(_option "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})
	if (NOT _option_COMPILER_ID)
		set (_option_COMPILER_ID "${CMAKE_${_option_LANGUAGE}_ID}")
	endif()
	if (NOT _option_COMPILER_VERSION)
		set (_option_COMPILER_VERSION "${CMAKE_${_option_LANGUAGE}_COMPILER_VERSION}")
	endif()
	if (_option_DEPENDS)
		cotire_check_file_up_to_date(_prefixFileIsUpToDate "${_prefixFile}" ${_option_DEPENDS})
		if (_prefixFileIsUpToDate)
			# create empty log file
			set (_unparsedLinesFile "${_prefixFile}.log")
			file (WRITE "${_unparsedLinesFile}" "")
			return()
		endif()
	endif()
	set (_prologue "")
	set (_epilogue "")
	if (_option_COMPILER_ID MATCHES "Clang")
		set (_prologue "#pragma clang system_header")
	elseif (_option_COMPILER_ID MATCHES "GNU")
		set (_prologue "#pragma GCC system_header")
	elseif (_option_COMPILER_ID MATCHES "MSVC")
		set (_prologue "#pragma warning(push, 0)")
		set (_epilogue "#pragma warning(pop)")
	elseif (_option_COMPILER_ID MATCHES "Intel")
		# Intel compiler requires hdrstop pragma to stop generating PCH file
		set (_epilogue "#pragma hdrstop")
	endif()
	set (_sourceFiles ${_option_UNPARSED_ARGUMENTS})
	cotire_scan_includes(_selectedHeaders ${_sourceFiles}
		LANGUAGE "${_option_LANGUAGE}"
		COMPILER_LAUNCHER "${_option_COMPILER_LAUNCHER}"
		COMPILER_EXECUTABLE "${_option_COMPILER_EXECUTABLE}"
		COMPILER_ARG1 "${_option_COMPILER_ARG1}"
		COMPILER_ID "${_option_COMPILER_ID}"
		COMPILER_VERSION "${_option_COMPILER_VERSION}"
		COMPILE_DEFINITIONS ${_option_COMPILE_DEFINITIONS}
		COMPILE_FLAGS ${_option_COMPILE_FLAGS}
		INCLUDE_DIRECTORIES ${_option_INCLUDE_DIRECTORIES}
		SYSTEM_INCLUDE_DIRECTORIES ${_option_SYSTEM_INCLUDE_DIRECTORIES}
		IGNORE_PATH ${_option_IGNORE_PATH}
		INCLUDE_PATH ${_option_INCLUDE_PATH}
		IGNORE_EXTENSIONS ${_option_IGNORE_EXTENSIONS}
		INCLUDE_PRIORITY_PATH ${_option_INCLUDE_PRIORITY_PATH}
		UNPARSED_LINES _unparsedLines
		SCAN_RESULT _scanResult)
	cotire_generate_unity_source("${_prefixFile}"
		PROLOGUE ${_prologue} EPILOGUE ${_epilogue} LANGUAGE "${_option_LANGUAGE}" ${_selectedHeaders})
	set (_unparsedLinesFile "${_prefixFile}.log")
	if (_unparsedLines)
		if (COTIRE_VERBOSE OR _scanResult OR NOT _selectedHeaders)
			list (LENGTH _unparsedLines _skippedLineCount)
			message (STATUS "${_skippedLineCount} line(s) skipped, see ${_unparsedLinesFile}")
		endif()
		string (REPLACE ";" "\n" _unparsedLines "${_unparsedLines}")
	endif()
	file (WRITE "${_unparsedLinesFile}" "${_unparsedLines}")
endfunction()

function (cotire_add_makedep_flags _language _compilerID _compilerVersion _flagsVar)
	set (_flags ${${_flagsVar}})
	if (_compilerID MATCHES "MSVC")
		# cl.exe options used
		# /nologo suppresses display of sign-on banner
		# /TC treat all files named on the command line as C source files
		# /TP treat all files named on the command line as C++ source files
		# /EP preprocess to stdout without #line directives
		# /showIncludes list include files
		set (_sourceFileTypeC "/TC")
		set (_sourceFileTypeCXX "/TP")
		if (_flags)
			# append to list
			list (APPEND _flags /nologo "${_sourceFileType${_language}}" /EP /showIncludes)
		else()
			# return as a flag string
			set (_flags "${_sourceFileType${_language}} /EP /showIncludes")
		endif()
	elseif (_compilerID MATCHES "GNU")
		# GCC options used
		# -H print the name of each header file used
		# -E invoke preprocessor
		# -fdirectives-only do not expand macros, requires GCC >= 4.3
		if (_flags)
			# append to list
			list (APPEND _flags -H -E)
			if (NOT "${_compilerVersion}" VERSION_LESS "4.3.0")
				list (APPEND _flags "-fdirectives-only")
			endif()
		else()
			# return as a flag string
			set (_flags "-H -E")
			if (NOT "${_compilerVersion}" VERSION_LESS "4.3.0")
				set (_flags "${_flags} -fdirectives-only")
			endif()
		endif()
	elseif (_compilerID MATCHES "Clang")
		# Clang options used
		# -H print the name of each header file used
		# -E invoke preprocessor
		# -fno-color-diagnostics don't prints diagnostics in color
		if (_flags)
			# append to list
			list (APPEND _flags -H -E -fno-color-diagnostics)
		else()
			# return as a flag string
			set (_flags "-H -E -fno-color-diagnostics")
		endif()
	elseif (_compilerID MATCHES "Intel")
		if (WIN32)
			# Windows Intel options used
			# /nologo do not display compiler version information
			# /QH display the include file order
			# /EP preprocess to stdout, omitting #line directives
			# /TC process all source or unrecognized file types as C source files
			# /TP process all source or unrecognized file types as C++ source files
			set (_sourceFileTypeC "/TC")
			set (_sourceFileTypeCXX "/TP")
			if (_flags)
				# append to list
				list (APPEND _flags /nologo "${_sourceFileType${_language}}" /EP /QH)
			else()
				# return as a flag string
				set (_flags "${_sourceFileType${_language}} /EP /QH")
			endif()
		else()
			# Linux / Mac OS X Intel options used
			# -H print the name of each header file used
			# -EP preprocess to stdout, omitting #line directives
			# -Kc++ process all source or unrecognized file types as C++ source files
			if (_flags)
				# append to list
				if ("${_language}" STREQUAL "CXX")
					list (APPEND _flags -Kc++)
				endif()
				list (APPEND _flags -H -EP)
			else()
				# return as a flag string
				if ("${_language}" STREQUAL "CXX")
					set (_flags "-Kc++ ")
				endif()
				set (_flags "${_flags}-H -EP")
			endif()
		endif()
	else()
		message (FATAL_ERROR "cotire: unsupported ${_language} compiler ${_compilerID} version ${_compilerVersion}.")
	endif()
	set (${_flagsVar} ${_flags} PARENT_SCOPE)
endfunction()

function (cotire_add_pch_compilation_flags _language _compilerID _compilerVersion _prefixFile _pchFile _hostFile _flagsVar)
	set (_flags ${${_flagsVar}})
	if (_compilerID MATCHES "MSVC")
		file (TO_NATIVE_PATH "${_prefixFile}" _prefixFileNative)
		file (TO_NATIVE_PATH "${_pchFile}" _pchFileNative)
		file (TO_NATIVE_PATH "${_hostFile}" _hostFileNative)
		# cl.exe options used
		# /Yc creates a precompiled header file
		# /Fp specifies precompiled header binary file name
		# /FI forces inclusion of file
		# /TC treat all files named on the command line as C source files
		# /TP treat all files named on the command line as C++ source files
		# /Zs syntax check only
		# /Zm precompiled header memory allocation scaling factor
		set (_sourceFileTypeC "/TC")
		set (_sourceFileTypeCXX "/TP")
		if (_flags)
			# append to list
			list (APPEND _flags /nologo "${_sourceFileType${_language}}"
				"/Yc${_prefixFileNative}" "/Fp${_pchFileNative}" "/FI${_prefixFileNative}" /Zs "${_hostFileNative}")
			if (COTIRE_PCH_MEMORY_SCALING_FACTOR)
				list (APPEND _flags "/Zm${COTIRE_PCH_MEMORY_SCALING_FACTOR}")
			endif()
		else()
			# return as a flag string
			set (_flags "/Yc\"${_prefixFileNative}\" /Fp\"${_pchFileNative}\" /FI\"${_prefixFileNative}\"")
			if (COTIRE_PCH_MEMORY_SCALING_FACTOR)
				set (_flags "${_flags} /Zm${COTIRE_PCH_MEMORY_SCALING_FACTOR}")
			endif()
		endif()
	elseif (_compilerID MATCHES "GNU|Clang")
		# GCC / Clang options used
		# -x specify the source language
		# -c compile but do not link
		# -o place output in file
		# note that we cannot use -w to suppress all warnings upon pre-compiling, because turning off a warning may
		# alter compile flags as a side effect (e.g., -Wwrite-string implies -fconst-strings)
		set (_xLanguage_C "c-header")
		set (_xLanguage_CXX "c++-header")
		if (_flags)
			# append to list
			list (APPEND _flags "-x" "${_xLanguage_${_language}}" "-c" "${_prefixFile}" -o "${_pchFile}")
		else()
			# return as a flag string
			set (_flags "-x ${_xLanguage_${_language}} -c \"${_prefixFile}\" -o \"${_pchFile}\"")
		endif()
	elseif (_compilerID MATCHES "Intel")
		if (WIN32)
			file (TO_NATIVE_PATH "${_prefixFile}" _prefixFileNative)
			file (TO_NATIVE_PATH "${_pchFile}" _pchFileNative)
			file (TO_NATIVE_PATH "${_hostFile}" _hostFileNative)
			# Windows Intel options used
			# /nologo do not display compiler version information
			# /Yc create a precompiled header (PCH) file
			# /Fp specify a path or file name for precompiled header files
			# /FI tells the preprocessor to include a specified file name as the header file
			# /TC process all source or unrecognized file types as C source files
			# /TP process all source or unrecognized file types as C++ source files
			# /Zs syntax check only
			# /Wpch-messages enable diagnostics related to pre-compiled headers (requires Intel XE 2013 Update 2)
			set (_sourceFileTypeC "/TC")
			set (_sourceFileTypeCXX "/TP")
			if (_flags)
				# append to list
				list (APPEND _flags /nologo "${_sourceFileType${_language}}"
					"/Yc" "/Fp${_pchFileNative}" "/FI${_prefixFileNative}" /Zs "${_hostFileNative}")
				if (NOT "${_compilerVersion}" VERSION_LESS "13.1.0")
					list (APPEND _flags "/Wpch-messages")
				endif()
			else()
				# return as a flag string
				set (_flags "/Yc /Fp\"${_pchFileNative}\" /FI\"${_prefixFileNative}\"")
				if (NOT "${_compilerVersion}" VERSION_LESS "13.1.0")
					set (_flags "${_flags} /Wpch-messages")
				endif()
			endif()
		else()
			# Linux / Mac OS X Intel options used
			# -pch-dir location for precompiled header files
			# -pch-create name of the precompiled header (PCH) to create
			# -Kc++ process all source or unrecognized file types as C++ source files
			# -fsyntax-only check only for correct syntax
			# -Wpch-messages enable diagnostics related to pre-compiled headers (requires Intel XE 2013 Update 2)
			get_filename_component(_pchDir "${_pchFile}" DIRECTORY)
			get_filename_component(_pchName "${_pchFile}" NAME)
			set (_xLanguage_C "c-header")
			set (_xLanguage_CXX "c++-header")
			set (_pchSuppressMessages FALSE)
			if ("${CMAKE_${_language}_FLAGS}" MATCHES ".*-Wno-pch-messages.*")
				set(_pchSuppressMessages TRUE)
			endif()
			if (_flags)
				# append to list
				if ("${_language}" STREQUAL "CXX")
					list (APPEND _flags -Kc++)
				endif()
				list (APPEND _flags "-include" "${_prefixFile}" "-pch-dir" "${_pchDir}" "-pch-create" "${_pchName}" "-fsyntax-only" "${_hostFile}")
				if (NOT "${_compilerVersion}" VERSION_LESS "13.1.0")
					if (NOT _pchSuppressMessages)
						list (APPEND _flags "-Wpch-messages")
					endif()
				endif()
			else()
				# return as a flag string
				set (_flags "-include \"${_prefixFile}\" -pch-dir \"${_pchDir}\" -pch-create \"${_pchName}\"")
				if (NOT "${_compilerVersion}" VERSION_LESS "13.1.0")
					if (NOT _pchSuppressMessages)
						set (_flags "${_flags} -Wpch-messages")
					endif()
				endif()
			endif()
		endif()
	else()
		message (FATAL_ERROR "cotire: unsupported ${_language} compiler ${_compilerID} version ${_compilerVersion}.")
	endif()
	set (${_flagsVar} ${_flags} PARENT_SCOPE)
endfunction()

function (cotire_add_prefix_pch_inclusion_flags _language _compilerID _compilerVersion _prefixFile _pchFile _flagsVar)
	set (_flags ${${_flagsVar}})
	if (_compilerID MATCHES "MSVC")
		file (TO_NATIVE_PATH "${_prefixFile}" _prefixFileNative)
		# cl.exe options used
		# /Yu uses a precompiled header file during build
		# /Fp specifies precompiled header binary file name
		# /FI forces inclusion of file
		# /Zm precompiled header memory allocation scaling factor
		if (_pchFile)
			file (TO_NATIVE_PATH "${_pchFile}" _pchFileNative)
			if (_flags)
				# append to list
				list (APPEND _flags "/Yu${_prefixFileNative}" "/Fp${_pchFileNative}" "/FI${_prefixFileNative}")
				if (COTIRE_PCH_MEMORY_SCALING_FACTOR)
					list (APPEND _flags "/Zm${COTIRE_PCH_MEMORY_SCALING_FACTOR}")
				endif()
			else()
				# return as a flag string
				set (_flags "/Yu\"${_prefixFileNative}\" /Fp\"${_pchFileNative}\" /FI\"${_prefixFileNative}\"")
				if (COTIRE_PCH_MEMORY_SCALING_FACTOR)
					set (_flags "${_flags} /Zm${COTIRE_PCH_MEMORY_SCALING_FACTOR}")
				endif()
			endif()
		else()
			# no precompiled header, force inclusion of prefix header
			if (_flags)
				# append to list
				list (APPEND _flags "/FI${_prefixFileNative}")
			else()
				# return as a flag string
				set (_flags "/FI\"${_prefixFileNative}\"")
			endif()
		endif()
	elseif (_compilerID MATCHES "GNU")
		# GCC options used
		# -include process include file as the first line of the primary source file
		# -Winvalid-pch warns if precompiled header is found but cannot be used
		# note: ccache requires the -include flag to be used in order to process precompiled header correctly
		if (_flags)
			# append to list
			list (APPEND _flags "-Winvalid-pch" "-include" "${_prefixFile}")
		else()
			# return as a flag string
			set (_flags "-Winvalid-pch -include \"${_prefixFile}\"")
		endif()
	elseif (_compilerID MATCHES "Clang")
		# Clang options used
		# -include process include file as the first line of the primary source file
		# -include-pch include precompiled header file
		# -Qunused-arguments don't emit warning for unused driver arguments
		# note: ccache requires the -include flag to be used in order to process precompiled header correctly
		if (_flags)
			# append to list
			list (APPEND _flags "-Qunused-arguments" "-include" "${_prefixFile}")
		else()
			# return as a flag string
			set (_flags "-Qunused-arguments -include \"${_prefixFile}\"")
		endif()
	elseif (_compilerID MATCHES "Intel")
		if (WIN32)
			file (TO_NATIVE_PATH "${_prefixFile}" _prefixFileNative)
			# Windows Intel options used
			# /Yu use a precompiled header (PCH) file
			# /Fp specify a path or file name for precompiled header files
			# /FI tells the preprocessor to include a specified file name as the header file
			# /Wpch-messages enable diagnostics related to pre-compiled headers (requires Intel XE 2013 Update 2)
			if (_pchFile)
				file (TO_NATIVE_PATH "${_pchFile}" _pchFileNative)
				if (_flags)
					# append to list
					list (APPEND _flags "/Yu" "/Fp${_pchFileNative}" "/FI${_prefixFileNative}")
					if (NOT "${_compilerVersion}" VERSION_LESS "13.1.0")
						list (APPEND _flags "/Wpch-messages")
					endif()
				else()
					# return as a flag string
					set (_flags "/Yu /Fp\"${_pchFileNative}\" /FI\"${_prefixFileNative}\"")
					if (NOT "${_compilerVersion}" VERSION_LESS "13.1.0")
						set (_flags "${_flags} /Wpch-messages")
					endif()
				endif()
			else()
				# no precompiled header, force inclusion of prefix header
				if (_flags)
					# append to list
					list (APPEND _flags "/FI${_prefixFileNative}")
				else()
					# return as a flag string
					set (_flags "/FI\"${_prefixFileNative}\"")
				endif()
			endif()
		else()
			# Linux / Mac OS X Intel options used
			# -pch-dir location for precompiled header files
			# -pch-use name of the precompiled header (PCH) to use
			# -include process include file as the first line of the primary source file
			# -Wpch-messages enable diagnostics related to pre-compiled headers (requires Intel XE 2013 Update 2)
			if (_pchFile)
				get_filename_component(_pchDir "${_pchFile}" DIRECTORY)
				get_filename_component(_pchName "${_pchFile}" NAME)
				set (_pchSuppressMessages FALSE)
				if ("${CMAKE_${_language}_FLAGS}" MATCHES ".*-Wno-pch-messages.*")
					set(_pchSuppressMessages TRUE)
				endif()
				if (_flags)
					# append to list
					list (APPEND _flags "-include" "${_prefixFile}" "-pch-dir" "${_pchDir}" "-pch-use" "${_pchName}")
					if (NOT "${_compilerVersion}" VERSION_LESS "13.1.0")
						if (NOT _pchSuppressMessages)
							list (APPEND _flags "-Wpch-messages")
						endif()
					endif()
				else()
					# return as a flag string
					set (_flags "-include \"${_prefixFile}\" -pch-dir \"${_pchDir}\" -pch-use \"${_pchName}\"")
					if (NOT "${_compilerVersion}" VERSION_LESS "13.1.0")
						if (NOT _pchSuppressMessages)
							set (_flags "${_flags} -Wpch-messages")
						endif()
					endif()
				endif()
			else()
				# no precompiled header, force inclusion of prefix header
				if (_flags)
					# append to list
					list (APPEND _flags "-include" "${_prefixFile}")
				else()
					# return as a flag string
					set (_flags "-include \"${_prefixFile}\"")
				endif()
			endif()
		endif()
	else()
		message (FATAL_ERROR "cotire: unsupported ${_language} compiler ${_compilerID} version ${_compilerVersion}.")
	endif()
	set (${_flagsVar} ${_flags} PARENT_SCOPE)
endfunction()

function (cotire_precompile_prefix_header _prefixFile _pchFile _hostFile)
	set(_options "")
	set(_oneValueArgs COMPILER_EXECUTABLE COMPILER_ARG1 COMPILER_ID COMPILER_VERSION LANGUAGE)
	set(_multiValueArgs COMPILE_DEFINITIONS COMPILE_FLAGS INCLUDE_DIRECTORIES SYSTEM_INCLUDE_DIRECTORIES SYS COMPILER_LAUNCHER)
	cmake_parse_arguments(_option "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})
	if (NOT _option_LANGUAGE)
		set (_option_LANGUAGE "CXX")
	endif()
	if (NOT _option_COMPILER_ID)
		set (_option_COMPILER_ID "${CMAKE_${_option_LANGUAGE}_ID}")
	endif()
	if (NOT _option_COMPILER_VERSION)
		set (_option_COMPILER_VERSION "${CMAKE_${_option_LANGUAGE}_COMPILER_VERSION}")
	endif()
	cotire_init_compile_cmd(_cmd "${_option_LANGUAGE}" "${_option_COMPILER_LAUNCHER}" "${_option_COMPILER_EXECUTABLE}" "${_option_COMPILER_ARG1}")
	cotire_add_definitions_to_cmd(_cmd "${_option_LANGUAGE}" ${_option_COMPILE_DEFINITIONS})
	cotire_add_compile_flags_to_cmd(_cmd ${_option_COMPILE_FLAGS})
	cotire_add_includes_to_cmd(_cmd "${_option_LANGUAGE}" _option_INCLUDE_DIRECTORIES _option_SYSTEM_INCLUDE_DIRECTORIES)
	cotire_add_frameworks_to_cmd(_cmd "${_option_LANGUAGE}" _option_INCLUDE_DIRECTORIES _option_SYSTEM_INCLUDE_DIRECTORIES)
	cotire_add_pch_compilation_flags(
		"${_option_LANGUAGE}" "${_option_COMPILER_ID}" "${_option_COMPILER_VERSION}"
		"${_prefixFile}" "${_pchFile}" "${_hostFile}" _cmd)
	if (COTIRE_VERBOSE)
		message (STATUS "execute_process: ${_cmd}")
	endif()
	if (_option_COMPILER_ID MATCHES "MSVC")
		# cl.exe messes with the output streams unless the environment variable VS_UNICODE_OUTPUT is cleared
		unset (ENV{VS_UNICODE_OUTPUT})
	elseif (_option_COMPILER_ID MATCHES "GNU|Clang")
		if (_option_COMPILER_LAUNCHER MATCHES "ccache" OR
			_option_COMPILER_EXECUTABLE MATCHES "ccache")
			# Newer versions of Clang and GCC seem to embed a compilation timestamp into the precompiled header binary,
			# which results in "file has been modified since the precompiled header was built" errors if ccache is used.
			# We work around the problem by disabling ccache upon pre-compiling the prefix header.
			set (ENV{CCACHE_DISABLE} "true")
		endif()
	endif()
	execute_process(
		COMMAND ${_cmd}
		WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
		RESULT_VARIABLE _result)
	if (_result)
		message (FATAL_ERROR "cotire: error ${_result} precompiling ${_prefixFile}.")
	endif()
endfunction()

function (cotire_check_precompiled_header_support _language _target _msgVar)
	set (_unsupportedCompiler
		"Precompiled headers not supported for ${_language} compiler ${CMAKE_${_language}_COMPILER_ID}")
	if (CMAKE_${_language}_COMPILER_ID MATCHES "MSVC")
		# supported since Visual Studio C++ 6.0
		# and CMake does not support an earlier version
		set (${_msgVar} "" PARENT_SCOPE)
	elseif (CMAKE_${_language}_COMPILER_ID MATCHES "GNU")
		# GCC PCH support requires version >= 3.4
		if ("${CMAKE_${_language}_COMPILER_VERSION}" VERSION_LESS "3.4.0")
			set (${_msgVar} "${_unsupportedCompiler} version ${CMAKE_${_language}_COMPILER_VERSION}." PARENT_SCOPE)
		else()
			set (${_msgVar} "" PARENT_SCOPE)
		endif()
	elseif (CMAKE_${_language}_COMPILER_ID MATCHES "Clang")
		# all Clang versions have PCH support
		set (${_msgVar} "" PARENT_SCOPE)
	elseif (CMAKE_${_language}_COMPILER_ID MATCHES "Intel")
		# Intel PCH support requires version >= 8.0.0
		if ("${CMAKE_${_language}_COMPILER_VERSION}" VERSION_LESS "8.0.0")
			set (${_msgVar} "${_unsupportedCompiler} version ${CMAKE_${_language}_COMPILER_VERSION}." PARENT_SCOPE)
		else()
			set (${_msgVar} "" PARENT_SCOPE)
		endif()
	else()
		set (${_msgVar} "${_unsupportedCompiler}." PARENT_SCOPE)
	endif()
	get_target_property(_launcher ${_target} ${_language}_COMPILER_LAUNCHER)
	if (CMAKE_${_language}_COMPILER MATCHES "ccache" OR _launcher MATCHES "ccache")
		if (DEFINED ENV{CCACHE_SLOPPINESS})
			if (NOT "$ENV{CCACHE_SLOPPINESS}" MATCHES "pch_defines" OR NOT "$ENV{CCACHE_SLOPPINESS}" MATCHES "time_macros")
				set (${_msgVar}
					"ccache requires the environment variable CCACHE_SLOPPINESS to be set to \"pch_defines,time_macros\"."
					PARENT_SCOPE)
			endif()
		else()
			if (_launcher MATCHES "ccache")
				get_filename_component(_ccacheExe "${_launcher}" REALPATH)
			else()
				get_filename_component(_ccacheExe "${CMAKE_${_language}_COMPILER}" REALPATH)
			endif()
			execute_process(
				COMMAND "${_ccacheExe}" "--print-config"
				WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
				RESULT_VARIABLE _result
				OUTPUT_VARIABLE _ccacheConfig OUTPUT_STRIP_TRAILING_WHITESPACE
				ERROR_QUIET)
			if (_result OR NOT
				_ccacheConfig MATCHES "sloppiness.*=.*time_macros" OR NOT
				_ccacheConfig MATCHES "sloppiness.*=.*pch_defines")
				set (${_msgVar}
					"ccache requires configuration setting \"sloppiness\" to be set to \"pch_defines,time_macros\"."
					PARENT_SCOPE)
			endif()
		endif()
	endif()
	if (APPLE)
		# PCH compilation not supported by GCC / Clang for multi-architecture builds (e.g., i386, x86_64)
		cotire_get_configuration_types(_configs)
		foreach (_config ${_configs})
			set (_targetFlags "")
			cotire_get_target_compile_flags("${_config}" "${_language}" "${_target}" _targetFlags)
			cotire_filter_compile_flags("${_language}" "arch" _architectures _ignore ${_targetFlags})
			list (LENGTH _architectures _numberOfArchitectures)
			if (_numberOfArchitectures GREATER 1)
				string (REPLACE ";" ", " _architectureStr "${_architectures}")
				set (${_msgVar}
					"Precompiled headers not supported on Darwin for multi-architecture builds (${_architectureStr})."
					PARENT_SCOPE)
				break()
			endif()
		endforeach()
	endif()
endfunction()

macro (cotire_get_intermediate_dir _cotireDir)
	# ${CMAKE_CFG_INTDIR} may reference a build-time variable when using a generator which supports configuration types
	get_filename_component(${_cotireDir} "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_CFG_INTDIR}/${COTIRE_INTDIR}" ABSOLUTE)
endmacro()

macro (cotire_setup_file_extension_variables)
	set (_unityFileExt_C ".c")
	set (_unityFileExt_CXX ".cxx")
	set (_prefixFileExt_C ".h")
	set (_prefixFileExt_CXX ".hxx")
	set (_prefixSourceFileExt_C ".c")
	set (_prefixSourceFileExt_CXX ".cxx")
endmacro()

function (cotire_make_single_unity_source_file_path _language _target _unityFileVar)
	cotire_setup_file_extension_variables()
	if (NOT DEFINED _unityFileExt_${_language})
		set (${_unityFileVar} "" PARENT_SCOPE)
		return()
	endif()
	set (_unityFileBaseName "${_target}_${_language}${COTIRE_UNITY_SOURCE_FILENAME_SUFFIX}")
	set (_unityFileName "${_unityFileBaseName}${_unityFileExt_${_language}}")
	cotire_get_intermediate_dir(_baseDir)
	set (_unityFile "${_baseDir}/${_unityFileName}")
	set (${_unityFileVar} "${_unityFile}" PARENT_SCOPE)
endfunction()

function (cotire_make_unity_source_file_paths _language _target _maxIncludes _unityFilesVar)
	cotire_setup_file_extension_variables()
	if (NOT DEFINED _unityFileExt_${_language})
		set (${_unityFileVar} "" PARENT_SCOPE)
		return()
	endif()
	set (_unityFileBaseName "${_target}_${_language}${COTIRE_UNITY_SOURCE_FILENAME_SUFFIX}")
	cotire_get_intermediate_dir(_baseDir)
	set (_startIndex 0)
	set (_index 0)
	set (_unityFiles "")
	set (_sourceFiles ${ARGN})
	foreach (_sourceFile ${_sourceFiles})
		get_source_file_property(_startNew "${_sourceFile}" COTIRE_START_NEW_UNITY_SOURCE)
		math (EXPR _unityFileCount "${_index} - ${_startIndex}")
		if (_startNew OR (_maxIncludes GREATER 0 AND NOT _unityFileCount LESS _maxIncludes))
			if (_index GREATER 0)
				# start new unity file segment
				math (EXPR _endIndex "${_index} - 1")
				set (_unityFileName "${_unityFileBaseName}_${_startIndex}_${_endIndex}${_unityFileExt_${_language}}")
				list (APPEND _unityFiles "${_baseDir}/${_unityFileName}")
			endif()
			set (_startIndex ${_index})
		endif()
		math (EXPR _index "${_index} + 1")
	endforeach()
	list (LENGTH _sourceFiles _numberOfSources)
	if (_startIndex EQUAL 0)
		# there is only a single unity file
		cotire_make_single_unity_source_file_path(${_language} ${_target} _unityFiles)
	elseif (_startIndex LESS _numberOfSources)
		# end with final unity file segment
		math (EXPR _endIndex "${_index} - 1")
		set (_unityFileName "${_unityFileBaseName}_${_startIndex}_${_endIndex}${_unityFileExt_${_language}}")
		list (APPEND _unityFiles "${_baseDir}/${_unityFileName}")
	endif()
	set (${_unityFilesVar} ${_unityFiles} PARENT_SCOPE)
	if (COTIRE_DEBUG AND _unityFiles)
		message (STATUS "unity files: ${_unityFiles}")
	endif()
endfunction()

function (cotire_unity_to_prefix_file_path _language _target _unityFile _prefixFileVar)
	cotire_setup_file_extension_variables()
	if (NOT DEFINED _unityFileExt_${_language})
		set (${_prefixFileVar} "" PARENT_SCOPE)
		return()
	endif()
	set (_unityFileBaseName "${_target}_${_language}${COTIRE_UNITY_SOURCE_FILENAME_SUFFIX}")
	set (_prefixFileBaseName "${_target}_${_language}${COTIRE_PREFIX_HEADER_FILENAME_SUFFIX}")
	string (REPLACE "${_unityFileBaseName}" "${_prefixFileBaseName}" _prefixFile "${_unityFile}")
	string (REGEX REPLACE "${_unityFileExt_${_language}}$" "${_prefixFileExt_${_language}}" _prefixFile "${_prefixFile}")
	set (${_prefixFileVar} "${_prefixFile}" PARENT_SCOPE)
endfunction()

function (cotire_prefix_header_to_source_file_path _language _prefixHeaderFile _prefixSourceFileVar)
	cotire_setup_file_extension_variables()
	if (NOT DEFINED _prefixSourceFileExt_${_language})
		set (${_prefixSourceFileVar} "" PARENT_SCOPE)
		return()
	endif()
	string (REGEX REPLACE "${_prefixFileExt_${_language}}$" "${_prefixSourceFileExt_${_language}}" _prefixSourceFile "${_prefixHeaderFile}")
	set (${_prefixSourceFileVar} "${_prefixSourceFile}" PARENT_SCOPE)
endfunction()

function (cotire_make_prefix_file_name _language _target _prefixFileBaseNameVar _prefixFileNameVar)
	cotire_setup_file_extension_variables()
	if (NOT _language)
		set (_prefixFileBaseName "${_target}${COTIRE_PREFIX_HEADER_FILENAME_SUFFIX}")
		set (_prefixFileName "${_prefixFileBaseName}${_prefixFileExt_C}")
	elseif (DEFINED _prefixFileExt_${_language})
		set (_prefixFileBaseName "${_target}_${_language}${COTIRE_PREFIX_HEADER_FILENAME_SUFFIX}")
		set (_prefixFileName "${_prefixFileBaseName}${_prefixFileExt_${_language}}")
	else()
		set (_prefixFileBaseName "")
		set (_prefixFileName "")
	endif()
	set (${_prefixFileBaseNameVar} "${_prefixFileBaseName}" PARENT_SCOPE)
	set (${_prefixFileNameVar} "${_prefixFileName}" PARENT_SCOPE)
endfunction()

function (cotire_make_prefix_file_path _language _target _prefixFileVar)
	cotire_make_prefix_file_name("${_language}" "${_target}" _prefixFileBaseName _prefixFileName)
	set (${_prefixFileVar} "" PARENT_SCOPE)
	if (_prefixFileName)
		if (NOT _language)
			set (_language "C")
		endif()
		if (CMAKE_${_language}_COMPILER_ID MATCHES "GNU|Clang|Intel|MSVC")
			cotire_get_intermediate_dir(_baseDir)
			set (${_prefixFileVar} "${_baseDir}/${_prefixFileName}" PARENT_SCOPE)
		endif()
	endif()
endfunction()

function (cotire_make_pch_file_path _language _target _pchFileVar)
	cotire_make_prefix_file_name("${_language}" "${_target}" _prefixFileBaseName _prefixFileName)
	set (${_pchFileVar} "" PARENT_SCOPE)
	if (_prefixFileBaseName AND _prefixFileName)
		cotire_check_precompiled_header_support("${_language}" "${_target}" _msg)
		if (NOT _msg)
			if (XCODE)
				# For Xcode, we completely hand off the compilation of the prefix header to the IDE
				return()
			endif()
			cotire_get_intermediate_dir(_baseDir)
			if (CMAKE_${_language}_COMPILER_ID MATCHES "MSVC")
				# MSVC uses the extension .pch added to the prefix header base name
				set (${_pchFileVar} "${_baseDir}/${_prefixFileBaseName}.pch" PARENT_SCOPE)
			elseif (CMAKE_${_language}_COMPILER_ID MATCHES "Clang")
				# Clang looks for a precompiled header corresponding to the prefix header with the extension .pch appended
				set (${_pchFileVar} "${_baseDir}/${_prefixFileName}.pch" PARENT_SCOPE)
			elseif (CMAKE_${_language}_COMPILER_ID MATCHES "GNU")
				# GCC looks for a precompiled header corresponding to the prefix header with the extension .gch appended
				set (${_pchFileVar} "${_baseDir}/${_prefixFileName}.gch" PARENT_SCOPE)
			elseif (CMAKE_${_language}_COMPILER_ID MATCHES "Intel")
				# Intel uses the extension .pchi added to the prefix header base name
				set (${_pchFileVar} "${_baseDir}/${_prefixFileBaseName}.pchi" PARENT_SCOPE)
			endif()
		endif()
	endif()
endfunction()

function (cotire_select_unity_source_files _unityFile _sourcesVar)
	set (_sourceFiles ${ARGN})
	if (_sourceFiles AND "${_unityFile}" MATCHES "${COTIRE_UNITY_SOURCE_FILENAME_SUFFIX}_([0-9]+)_([0-9]+)")
		set (_startIndex ${CMAKE_MATCH_1})
		set (_endIndex ${CMAKE_MATCH_2})
		list (LENGTH _sourceFiles _numberOfSources)
		if (NOT _startIndex LESS _numberOfSources)
			math (EXPR _startIndex "${_numberOfSources} - 1")
		endif()
		if (NOT _endIndex LESS _numberOfSources)
			math (EXPR _endIndex "${_numberOfSources} - 1")
		endif()
		set (_files "")
		foreach (_index RANGE ${_startIndex} ${_endIndex})
			list (GET _sourceFiles ${_index} _file)
			list (APPEND _files "${_file}")
		endforeach()
	else()
		set (_files ${_sourceFiles})
	endif()
	set (${_sourcesVar} ${_files} PARENT_SCOPE)
endfunction()

function (cotire_get_unity_source_dependencies _language _target _dependencySourcesVar)
	set (_dependencySources "")
	# depend on target's generated source files
	get_target_property(_targetSourceFiles ${_target} SOURCES)
	cotire_get_objects_with_property_on(_generatedSources GENERATED SOURCE ${_targetSourceFiles})
	if (_generatedSources)
		# but omit all generated source files that have the COTIRE_EXCLUDED property set to true
		cotire_get_objects_with_property_on(_excludedGeneratedSources COTIRE_EXCLUDED SOURCE ${_generatedSources})
		if (_excludedGeneratedSources)
			list (REMOVE_ITEM _generatedSources ${_excludedGeneratedSources})
		endif()
		# and omit all generated source files that have the COTIRE_DEPENDENCY property set to false explicitly
		cotire_get_objects_with_property_off(_excludedNonDependencySources COTIRE_DEPENDENCY SOURCE ${_generatedSources})
		if (_excludedNonDependencySources)
			list (REMOVE_ITEM _generatedSources ${_excludedNonDependencySources})
		endif()
		if (_generatedSources)
			list (APPEND _dependencySources ${_generatedSources})
		endif()
	endif()
	if (COTIRE_DEBUG AND _dependencySources)
		message (STATUS "${_language} ${_target} unity source dependencies: ${_dependencySources}")
	endif()
	set (${_dependencySourcesVar} ${_dependencySources} PARENT_SCOPE)
endfunction()

function (cotire_get_prefix_header_dependencies _language _target _dependencySourcesVar)
	set (_dependencySources "")
	# depend on target source files marked with custom COTIRE_DEPENDENCY property
	get_target_property(_targetSourceFiles ${_target} SOURCES)
	cotire_get_objects_with_property_on(_dependencySources COTIRE_DEPENDENCY SOURCE ${_targetSourceFiles})
	if (COTIRE_DEBUG AND _dependencySources)
		message (STATUS "${_language} ${_target} prefix header dependencies: ${_dependencySources}")
	endif()
	set (${_dependencySourcesVar} ${_dependencySources} PARENT_SCOPE)
endfunction()

function (cotire_generate_target_script _language _configurations _target _targetScriptVar _targetConfigScriptVar)
	set (_targetSources ${ARGN})
	cotire_get_prefix_header_dependencies(${_language} ${_target} COTIRE_TARGET_PREFIX_DEPENDS ${_targetSources})
	cotire_get_unity_source_dependencies(${_language} ${_target} COTIRE_TARGET_UNITY_DEPENDS ${_targetSources})
	# set up variables to be configured
	set (COTIRE_TARGET_LANGUAGE "${_language}")
	get_target_property(COTIRE_TARGET_IGNORE_PATH ${_target} COTIRE_PREFIX_HEADER_IGNORE_PATH)
	cotire_add_sys_root_paths(COTIRE_TARGET_IGNORE_PATH)
	get_target_property(COTIRE_TARGET_INCLUDE_PATH ${_target} COTIRE_PREFIX_HEADER_INCLUDE_PATH)
	cotire_add_sys_root_paths(COTIRE_TARGET_INCLUDE_PATH)
	get_target_property(COTIRE_TARGET_PRE_UNDEFS ${_target} COTIRE_UNITY_SOURCE_PRE_UNDEFS)
	get_target_property(COTIRE_TARGET_POST_UNDEFS ${_target} COTIRE_UNITY_SOURCE_POST_UNDEFS)
	get_target_property(COTIRE_TARGET_MAXIMUM_NUMBER_OF_INCLUDES ${_target} COTIRE_UNITY_SOURCE_MAXIMUM_NUMBER_OF_INCLUDES)
	get_target_property(COTIRE_TARGET_INCLUDE_PRIORITY_PATH ${_target} COTIRE_PREFIX_HEADER_INCLUDE_PRIORITY_PATH)
	cotire_get_source_files_undefs(COTIRE_UNITY_SOURCE_PRE_UNDEFS COTIRE_TARGET_SOURCES_PRE_UNDEFS ${_targetSources})
	cotire_get_source_files_undefs(COTIRE_UNITY_SOURCE_POST_UNDEFS COTIRE_TARGET_SOURCES_POST_UNDEFS ${_targetSources})
	set (COTIRE_TARGET_CONFIGURATION_TYPES "${_configurations}")
	foreach (_config ${_configurations})
		string (TOUPPER "${_config}" _upperConfig)
		cotire_get_target_include_directories(
			"${_config}" "${_language}" "${_target}" COTIRE_TARGET_INCLUDE_DIRECTORIES_${_upperConfig} COTIRE_TARGET_SYSTEM_INCLUDE_DIRECTORIES_${_upperConfig})
		cotire_get_target_compile_definitions(
			"${_config}" "${_language}" "${_target}" COTIRE_TARGET_COMPILE_DEFINITIONS_${_upperConfig})
		cotire_get_target_compiler_flags(
			"${_config}" "${_language}" "${_target}" COTIRE_TARGET_COMPILE_FLAGS_${_upperConfig})
		cotire_get_source_files_compile_definitions(
			"${_config}" "${_language}" COTIRE_TARGET_SOURCES_COMPILE_DEFINITIONS_${_upperConfig} ${_targetSources})
	endforeach()
	get_target_property(COTIRE_TARGET_${_language}_COMPILER_LAUNCHER ${_target} ${_language}_COMPILER_LAUNCHER)
	# set up COTIRE_TARGET_SOURCES
	set (COTIRE_TARGET_SOURCES "")
	foreach (_sourceFile ${_targetSources})
		get_source_file_property(_generated "${_sourceFile}" GENERATED)
		if (_generated)
			# use absolute paths for generated files only, retrieving the LOCATION property is an expensive operation
			get_source_file_property(_sourceLocation "${_sourceFile}" LOCATION)
			list (APPEND COTIRE_TARGET_SOURCES "${_sourceLocation}")
		else()
			list (APPEND COTIRE_TARGET_SOURCES "${_sourceFile}")
		endif()
	endforeach()
	# copy variable definitions to cotire target script
	get_cmake_property(_vars VARIABLES)
	string (REGEX MATCHALL "COTIRE_[A-Za-z0-9_]+" _matchVars "${_vars}")
	# omit COTIRE_*_INIT variables
	string (REGEX MATCHALL "COTIRE_[A-Za-z0-9_]+_INIT" _initVars "${_matchVars}")
	if (_initVars)
		list (REMOVE_ITEM _matchVars ${_initVars})
	endif()
	# omit COTIRE_VERBOSE which is passed as a CMake define on command line
	list (REMOVE_ITEM _matchVars COTIRE_VERBOSE)
	set (_contents "")
	set (_contentsHasGeneratorExpressions FALSE)
	foreach (_var IN LISTS _matchVars ITEMS
		XCODE MSVC CMAKE_GENERATOR CMAKE_BUILD_TYPE CMAKE_CONFIGURATION_TYPES
		CMAKE_${_language}_COMPILER_ID CMAKE_${_language}_COMPILER_VERSION
		CMAKE_${_language}_COMPILER_LAUNCHER CMAKE_${_language}_COMPILER CMAKE_${_language}_COMPILER_ARG1
		CMAKE_INCLUDE_FLAG_${_language} CMAKE_INCLUDE_FLAG_SEP_${_language}
		CMAKE_INCLUDE_SYSTEM_FLAG_${_language}
		CMAKE_${_language}_FRAMEWORK_SEARCH_FLAG
		CMAKE_${_language}_SYSTEM_FRAMEWORK_SEARCH_FLAG
		CMAKE_${_language}_SOURCE_FILE_EXTENSIONS)
		if (DEFINED ${_var})
			string (REPLACE "\"" "\\\"" _value "${${_var}}")
			set (_contents "${_contents}set (${_var} \"${_value}\")\n")
			if (NOT _contentsHasGeneratorExpressions)
				if ("${_value}" MATCHES "\\$<.*>")
					set (_contentsHasGeneratorExpressions TRUE)
				endif()
			endif()
		endif()
	endforeach()
	# generate target script file
	get_filename_component(_moduleName "${COTIRE_CMAKE_MODULE_FILE}" NAME)
	set (_targetCotireScript "${CMAKE_CURRENT_BINARY_DIR}/${_target}_${_language}_${_moduleName}")
	cotire_write_file("CMAKE" "${_targetCotireScript}" "${_contents}" FALSE)
	if (_contentsHasGeneratorExpressions)
		# use file(GENERATE ...) to expand generator expressions in the target script at CMake generate-time
		set (_configNameOrNoneGeneratorExpression "$<$<CONFIG:>:None>$<$<NOT:$<CONFIG:>>:$<CONFIGURATION>>")
		set (_targetCotireConfigScript "${CMAKE_CURRENT_BINARY_DIR}/${_target}_${_language}_${_configNameOrNoneGeneratorExpression}_${_moduleName}")
		file (GENERATE OUTPUT "${_targetCotireConfigScript}" INPUT "${_targetCotireScript}")
	else()
		set (_targetCotireConfigScript "${_targetCotireScript}")
	endif()
	set (${_targetScriptVar} "${_targetCotireScript}" PARENT_SCOPE)
	set (${_targetConfigScriptVar} "${_targetCotireConfigScript}" PARENT_SCOPE)
endfunction()

function (cotire_setup_pch_file_compilation _language _target _targetScript _prefixFile _pchFile _hostFile)
	set (_sourceFiles ${ARGN})
	if (CMAKE_${_language}_COMPILER_ID MATCHES "MSVC|Intel")
		# for Visual Studio and Intel, we attach the precompiled header compilation to the host file
		# the remaining files include the precompiled header, see cotire_setup_pch_file_inclusion
		if (_sourceFiles)
			set (_flags "")
			cotire_add_pch_compilation_flags(
				"${_language}" "${CMAKE_${_language}_COMPILER_ID}" "${CMAKE_${_language}_COMPILER_VERSION}"
				"${_prefixFile}" "${_pchFile}" "${_hostFile}" _flags)
			set_property (SOURCE ${_hostFile} APPEND_STRING PROPERTY COMPILE_FLAGS " ${_flags} ")
			set_property (SOURCE ${_hostFile} APPEND PROPERTY OBJECT_OUTPUTS "${_pchFile}")
			# make object file generated from host file depend on prefix header
			set_property (SOURCE ${_hostFile} APPEND PROPERTY OBJECT_DEPENDS "${_prefixFile}")
			# mark host file as cotired to prevent it from being used in another cotired target
			set_property (SOURCE ${_hostFile} PROPERTY COTIRE_TARGET "${_target}")
		endif()
	elseif ("${CMAKE_GENERATOR}" MATCHES "Make|Ninja")
		# for makefile based generator, we add a custom command to precompile the prefix header
		if (_targetScript)
			cotire_set_cmd_to_prologue(_cmds)
			list (APPEND _cmds -P "${COTIRE_CMAKE_MODULE_FILE}" "precompile" "${_targetScript}" "${_prefixFile}" "${_pchFile}" "${_hostFile}")
			if (MSVC_IDE)
				file (TO_NATIVE_PATH "${_pchFile}" _pchFileLogPath)
			else()
				file (RELATIVE_PATH _pchFileLogPath "${CMAKE_BINARY_DIR}" "${_pchFile}")
			endif()
			# make precompiled header compilation depend on the actual compiler executable used to force
			# re-compilation when the compiler executable is updated. This prevents "created by a different GCC executable"
			# warnings when the precompiled header is included.
			get_filename_component(_realCompilerExe "${CMAKE_${_language}_COMPILER}" ABSOLUTE)
			if (COTIRE_DEBUG)
				message (STATUS "add_custom_command: OUTPUT ${_pchFile} ${_cmds} DEPENDS ${_prefixFile} ${_realCompilerExe} IMPLICIT_DEPENDS ${_language} ${_prefixFile}")
			endif()
			set_property (SOURCE "${_pchFile}" PROPERTY GENERATED TRUE)
			add_custom_command(
				OUTPUT "${_pchFile}"
				COMMAND ${_cmds}
				DEPENDS "${_prefixFile}" "${_realCompilerExe}"
				IMPLICIT_DEPENDS ${_language} "${_prefixFile}"
				WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
				COMMENT "Building ${_language} precompiled header ${_pchFileLogPath}"
				VERBATIM)
		endif()
	endif()
endfunction()

function (cotire_setup_pch_file_inclusion _language _target _wholeTarget _prefixFile _pchFile _hostFile)
	if (CMAKE_${_language}_COMPILER_ID MATCHES "MSVC|Intel")
		# for Visual Studio and Intel, we include the precompiled header in all but the host file
		# the host file does the precompiled header compilation, see cotire_setup_pch_file_compilation
		set (_sourceFiles ${ARGN})
		list (LENGTH _sourceFiles _numberOfSourceFiles)
		if (_numberOfSourceFiles GREATER 0)
			# mark sources as cotired to prevent them from being used in another cotired target
			set_source_files_properties(${_sourceFiles} PROPERTIES COTIRE_TARGET "${_target}")
			set (_flags "")
			cotire_add_prefix_pch_inclusion_flags(
				"${_language}" "${CMAKE_${_language}_COMPILER_ID}" "${CMAKE_${_language}_COMPILER_VERSION}"
				"${_prefixFile}" "${_pchFile}" _flags)
			set_property (SOURCE ${_sourceFiles} APPEND_STRING PROPERTY COMPILE_FLAGS " ${_flags} ")
			# make object files generated from source files depend on precompiled header
			set_property (SOURCE ${_sourceFiles} APPEND PROPERTY OBJECT_DEPENDS "${_pchFile}")
		endif()
	elseif ("${CMAKE_GENERATOR}" MATCHES "Make|Ninja")
		set (_sourceFiles ${_hostFile} ${ARGN})
		if (NOT _wholeTarget)
			# for makefile based generator, we force the inclusion of the prefix header for a subset
			# of the source files, if this is a multi-language target or has excluded files
			set (_flags "")
			cotire_add_prefix_pch_inclusion_flags(
				"${_language}" "${CMAKE_${_language}_COMPILER_ID}" "${CMAKE_${_language}_COMPILER_VERSION}"
				"${_prefixFile}" "${_pchFile}" _flags)
			set_property (SOURCE ${_sourceFiles} APPEND_STRING PROPERTY COMPILE_FLAGS " ${_flags} ")
			# mark sources as cotired to prevent them from being used in another cotired target
			set_source_files_properties(${_sourceFiles} PROPERTIES COTIRE_TARGET "${_target}")
		endif()
		# make object files generated from source files depend on precompiled header
		set_property (SOURCE ${_sourceFiles} APPEND PROPERTY OBJECT_DEPENDS "${_pchFile}")
	endif()
endfunction()

function (cotire_setup_prefix_file_inclusion _language _target _prefixFile)
	set (_sourceFiles ${ARGN})
	# force the inclusion of the prefix header for the given source files
	set (_flags "")
	set (_pchFile "")
	cotire_add_prefix_pch_inclusion_flags(
		"${_language}" "${CMAKE_${_language}_COMPILER_ID}" "${CMAKE_${_language}_COMPILER_VERSION}"
		"${_prefixFile}" "${_pchFile}" _flags)
	set_property (SOURCE ${_sourceFiles} APPEND_STRING PROPERTY COMPILE_FLAGS " ${_flags} ")
	# mark sources as cotired to prevent them from being used in another cotired target
	set_source_files_properties(${_sourceFiles} PROPERTIES COTIRE_TARGET "${_target}")
	# make object files generated from source files depend on prefix header
	set_property (SOURCE ${_sourceFiles} APPEND PROPERTY OBJECT_DEPENDS "${_prefixFile}")
endfunction()

function (cotire_get_first_set_property_value _propertyValueVar _type _object)
	set (_properties ${ARGN})
	foreach (_property ${_properties})
		get_property(_propertyValue ${_type} "${_object}" PROPERTY ${_property})
		if (_propertyValue)
			set (${_propertyValueVar} ${_propertyValue} PARENT_SCOPE)
			return()
		endif()
	endforeach()
	set (${_propertyValueVar} "" PARENT_SCOPE)
endfunction()

function (cotire_setup_combine_command _language _targetScript _joinedFile _cmdsVar)
	set (_files ${ARGN})
	set (_filesPaths "")
	foreach (_file ${_files})
		get_filename_component(_filePath "${_file}" ABSOLUTE)
		list (APPEND _filesPaths "${_filePath}")
	endforeach()
	cotire_set_cmd_to_prologue(_prefixCmd)
	list (APPEND _prefixCmd -P "${COTIRE_CMAKE_MODULE_FILE}" "combine")
	if (_targetScript)
		list (APPEND _prefixCmd "${_targetScript}")
	endif()
	list (APPEND _prefixCmd "${_joinedFile}" ${_filesPaths})
	if (COTIRE_DEBUG)
		message (STATUS "add_custom_command: OUTPUT ${_joinedFile} COMMAND ${_prefixCmd} DEPENDS ${_files}")
	endif()
	set_property (SOURCE "${_joinedFile}" PROPERTY GENERATED TRUE)
	if (MSVC_IDE)
		file (TO_NATIVE_PATH "${_joinedFile}" _joinedFileLogPath)
	else()
		file (RELATIVE_PATH _joinedFileLogPath "${CMAKE_BINARY_DIR}" "${_joinedFile}")
	endif()
	get_filename_component(_joinedFileBaseName "${_joinedFile}" NAME_WE)
	get_filename_component(_joinedFileExt "${_joinedFile}" EXT)
	if (_language AND _joinedFileBaseName MATCHES "${COTIRE_UNITY_SOURCE_FILENAME_SUFFIX}$")
		set (_comment "Generating ${_language} unity source ${_joinedFileLogPath}")
	elseif (_language AND _joinedFileBaseName MATCHES "${COTIRE_PREFIX_HEADER_FILENAME_SUFFIX}$")
		if (_joinedFileExt MATCHES "^\\.c")
			set (_comment "Generating ${_language} prefix source ${_joinedFileLogPath}")
		else()
			set (_comment "Generating ${_language} prefix header ${_joinedFileLogPath}")
		endif()
	else()
		set (_comment "Generating ${_joinedFileLogPath}")
	endif()
	add_custom_command(
		OUTPUT "${_joinedFile}"
		COMMAND ${_prefixCmd}
		DEPENDS ${_files}
		COMMENT "${_comment}"
		WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
		VERBATIM)
	list (APPEND ${_cmdsVar} COMMAND ${_prefixCmd})
	set (${_cmdsVar} ${${_cmdsVar}} PARENT_SCOPE)
endfunction()

function (cotire_setup_target_pch_usage _languages _target _wholeTarget)
	if (XCODE)
		# for Xcode, we attach a pre-build action to generate the unity sources and prefix headers
		set (_prefixFiles "")
		foreach (_language ${_languages})
			get_property(_prefixFile TARGET ${_target} PROPERTY COTIRE_${_language}_PREFIX_HEADER)
			if (_prefixFile)
				list (APPEND _prefixFiles "${_prefixFile}")
			endif()
		endforeach()
		set (_cmds ${ARGN})
		list (LENGTH _prefixFiles _numberOfPrefixFiles)
		if (_numberOfPrefixFiles GREATER 1)
			# we also generate a generic, single prefix header which includes all language specific prefix headers
			set (_language "")
			set (_targetScript "")
			cotire_make_prefix_file_path("${_language}" ${_target} _prefixHeader)
			cotire_setup_combine_command("${_language}" "${_targetScript}" "${_prefixHeader}" _cmds ${_prefixFiles})
		else()
			set (_prefixHeader "${_prefixFiles}")
		endif()
		if (COTIRE_DEBUG)
			message (STATUS "add_custom_command: TARGET ${_target} PRE_BUILD ${_cmds}")
		endif()
		# because CMake PRE_BUILD command does not support dependencies,
		# we check dependencies explicity in cotire script mode when the pre-build action is run
		add_custom_command(
			TARGET "${_target}"
			PRE_BUILD ${_cmds}
			WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
			COMMENT "Updating target ${_target} prefix headers"
			VERBATIM)
		# make Xcode precompile the generated prefix header with ProcessPCH and ProcessPCH++
		set_target_properties(${_target} PROPERTIES XCODE_ATTRIBUTE_GCC_PRECOMPILE_PREFIX_HEADER "YES")
		set_target_properties(${_target} PROPERTIES XCODE_ATTRIBUTE_GCC_PREFIX_HEADER "${_prefixHeader}")
	elseif ("${CMAKE_GENERATOR}" MATCHES "Make|Ninja")
		# for makefile based generator, we force inclusion of the prefix header for all target source files
		# if this is a single-language target without any excluded files
		if (_wholeTarget)
			set (_language "${_languages}")
			# for Visual Studio and Intel, precompiled header inclusion is always done on the source file level
			# see cotire_setup_pch_file_inclusion
			if (NOT CMAKE_${_language}_COMPILER_ID MATCHES "MSVC|Intel")
				get_property(_prefixFile TARGET ${_target} PROPERTY COTIRE_${_language}_PREFIX_HEADER)
				if (_prefixFile)
					get_property(_pchFile TARGET ${_target} PROPERTY COTIRE_${_language}_PRECOMPILED_HEADER)
					set (_options COMPILE_OPTIONS)
					cotire_add_prefix_pch_inclusion_flags(
						"${_language}" "${CMAKE_${_language}_COMPILER_ID}" "${CMAKE_${_language}_COMPILER_VERSION}"
						"${_prefixFile}" "${_pchFile}" _options)
					set_property(TARGET ${_target} APPEND PROPERTY ${_options})
				endif()
			endif()
		endif()
	endif()
endfunction()

function (cotire_setup_unity_generation_commands _language _target _targetScript _targetConfigScript _unityFiles _cmdsVar)
	set (_dependencySources "")
	cotire_get_unity_source_dependencies(${_language} ${_target} _dependencySources ${ARGN})
	foreach (_unityFile ${_unityFiles})
		set_property (SOURCE "${_unityFile}" PROPERTY GENERATED TRUE)
		# set up compiled unity source dependencies via OBJECT_DEPENDS
		# this ensures that missing source files are generated before the unity file is compiled
		if (COTIRE_DEBUG AND _dependencySources)
			message (STATUS "${_unityFile} OBJECT_DEPENDS ${_dependencySources}")
		endif()
		if (_dependencySources)
			# the OBJECT_DEPENDS property requires a list of full paths
			set (_objectDependsPaths "")
			foreach (_sourceFile ${_dependencySources})
				get_source_file_property(_sourceLocation "${_sourceFile}" LOCATION)
				list (APPEND _objectDependsPaths "${_sourceLocation}")
			endforeach()
			set_property (SOURCE "${_unityFile}" PROPERTY OBJECT_DEPENDS ${_objectDependsPaths})
		endif()
		if (WIN32 AND CMAKE_${_language}_COMPILER_ID MATCHES "MSVC|Intel")
			# unity file compilation results in potentially huge object file, thus use /bigobj by default unter MSVC and Windows Intel
			set_property (SOURCE "${_unityFile}" APPEND_STRING PROPERTY COMPILE_FLAGS "/bigobj")
		endif()
		cotire_set_cmd_to_prologue(_unityCmd)
		list (APPEND _unityCmd -P "${COTIRE_CMAKE_MODULE_FILE}" "unity" "${_targetConfigScript}" "${_unityFile}")
		if (CMAKE_VERSION VERSION_LESS "3.1.0")
			set (_unityCmdDepends "${_targetScript}")
		else()
			# CMake 3.1.0 supports generator expressions in arguments to DEPENDS
			set (_unityCmdDepends "${_targetConfigScript}")
		endif()
		if (MSVC_IDE)
			file (TO_NATIVE_PATH "${_unityFile}" _unityFileLogPath)
		else()
			file (RELATIVE_PATH _unityFileLogPath "${CMAKE_BINARY_DIR}" "${_unityFile}")
		endif()
		if (COTIRE_DEBUG)
			message (STATUS "add_custom_command: OUTPUT ${_unityFile} COMMAND ${_unityCmd} DEPENDS ${_unityCmdDepends}")
		endif()
		add_custom_command(
			OUTPUT "${_unityFile}"
			COMMAND ${_unityCmd}
			DEPENDS ${_unityCmdDepends}
			COMMENT "Generating ${_language} unity source ${_unityFileLogPath}"
			WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
			VERBATIM)
		list (APPEND ${_cmdsVar} COMMAND ${_unityCmd})
	endforeach()
	set (${_cmdsVar} ${${_cmdsVar}} PARENT_SCOPE)
endfunction()

function (cotire_setup_prefix_generation_command _language _target _targetScript _prefixFile _unityFiles _cmdsVar)
	set (_sourceFiles ${ARGN})
	set (_dependencySources "")
	cotire_get_prefix_header_dependencies(${_language} ${_target} _dependencySources ${_sourceFiles})
	cotire_set_cmd_to_prologue(_prefixCmd)
	list (APPEND _prefixCmd -P "${COTIRE_CMAKE_MODULE_FILE}" "prefix" "${_targetScript}" "${_prefixFile}" ${_unityFiles})
	set_property (SOURCE "${_prefixFile}" PROPERTY GENERATED TRUE)
	# make prefix header generation depend on the actual compiler executable used to force
	# re-generation when the compiler executable is updated. This prevents "file not found"
	# errors for compiler version specific system header files.
	get_filename_component(_realCompilerExe "${CMAKE_${_language}_COMPILER}" ABSOLUTE)
	if (COTIRE_DEBUG)
		message (STATUS "add_custom_command: OUTPUT ${_prefixFile} COMMAND ${_prefixCmd} DEPENDS ${_unityFile} ${_dependencySources} ${_realCompilerExe}")
	endif()
	if (MSVC_IDE)
		file (TO_NATIVE_PATH "${_prefixFile}" _prefixFileLogPath)
	else()
		file (RELATIVE_PATH _prefixFileLogPath "${CMAKE_BINARY_DIR}" "${_prefixFile}")
	endif()
	get_filename_component(_prefixFileExt "${_prefixFile}" EXT)
	if (_prefixFileExt MATCHES "^\\.c")
		set (_comment "Generating ${_language} prefix source ${_prefixFileLogPath}")
	else()
		set (_comment "Generating ${_language} prefix header ${_prefixFileLogPath}")
	endif()
	# prevent pre-processing errors upon generating the prefix header when a target's generated include file does not yet exist
	# we do not add a file-level dependency for the target's generated files though, because we only want to depend on their existence
	# thus we make the prefix header generation depend on a custom helper target which triggers the generation of the files
	set (_preTargetName "${_target}${COTIRE_PCH_TARGET_SUFFIX}_pre")
	if (TARGET ${_preTargetName})
		# custom helper target has already been generated while processing a different language
		list (APPEND _dependencySources ${_preTargetName})
	else()
		get_target_property(_targetSourceFiles ${_target} SOURCES)
		cotire_get_objects_with_property_on(_generatedSources GENERATED SOURCE ${_targetSourceFiles})
		if (_generatedSources)
			add_custom_target("${_preTargetName}" DEPENDS ${_generatedSources})
			cotire_init_target("${_preTargetName}")
			list (APPEND _dependencySources ${_preTargetName})
		endif()
	endif()
	add_custom_command(
		OUTPUT "${_prefixFile}" "${_prefixFile}.log"
		COMMAND ${_prefixCmd}
		DEPENDS ${_unityFiles} ${_dependencySources} "${_realCompilerExe}"
		COMMENT "${_comment}"
		WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
		VERBATIM)
	list (APPEND ${_cmdsVar} COMMAND ${_prefixCmd})
	set (${_cmdsVar} ${${_cmdsVar}} PARENT_SCOPE)
endfunction()

function (cotire_setup_prefix_generation_from_unity_command _language _target _targetScript _prefixFile _unityFiles _cmdsVar)
	set (_sourceFiles ${ARGN})
	if (CMAKE_${_language}_COMPILER_ID MATCHES "GNU|Clang")
		# GNU and Clang require indirect compilation of the prefix header to make them honor the system_header pragma
		cotire_prefix_header_to_source_file_path(${_language} "${_prefixFile}" _prefixSourceFile)
	else()
		set (_prefixSourceFile "${_prefixFile}")
	endif()
	cotire_setup_prefix_generation_command(
		${_language} ${_target} "${_targetScript}"
		"${_prefixSourceFile}" "${_unityFiles}" ${_cmdsVar} ${_sourceFiles})
	if (CMAKE_${_language}_COMPILER_ID MATCHES "GNU|Clang")
		# set up generation of a prefix source file which includes the prefix header
		cotire_setup_combine_command(${_language} "${_targetScript}" "${_prefixFile}" _cmds ${_prefixSourceFile})
	endif()
	set (${_cmdsVar} ${${_cmdsVar}} PARENT_SCOPE)
endfunction()

function (cotire_setup_prefix_generation_from_provided_command _language _target _targetScript _prefixFile _cmdsVar)
	set (_prefixHeaderFiles ${ARGN})
	if (CMAKE_${_language}_COMPILER_ID MATCHES "GNU|Clang")
		# GNU and Clang require indirect compilation of the prefix header to make them honor the system_header pragma
		cotire_prefix_header_to_source_file_path(${_language} "${_prefixFile}" _prefixSourceFile)
	else()
		set (_prefixSourceFile "${_prefixFile}")
	endif()
	cotire_setup_combine_command(${_language} "${_targetScript}" "${_prefixSourceFile}" _cmds ${_prefixHeaderFiles})
	if (CMAKE_${_language}_COMPILER_ID MATCHES "GNU|Clang")
		# set up generation of a prefix source file which includes the prefix header
		cotire_setup_combine_command(${_language} "${_targetScript}" "${_prefixFile}" _cmds ${_prefixSourceFile})
	endif()
	set (${_cmdsVar} ${${_cmdsVar}} PARENT_SCOPE)
endfunction()

function (cotire_init_cotire_target_properties _target)
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_ENABLE_PRECOMPILED_HEADER SET)
	if (NOT _isSet)
		set_property(TARGET ${_target} PROPERTY COTIRE_ENABLE_PRECOMPILED_HEADER TRUE)
	endif()
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_ADD_UNITY_BUILD SET)
	if (NOT _isSet)
		set_property(TARGET ${_target} PROPERTY COTIRE_ADD_UNITY_BUILD TRUE)
	endif()
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_ADD_CLEAN SET)
	if (NOT _isSet)
		set_property(TARGET ${_target} PROPERTY COTIRE_ADD_CLEAN FALSE)
	endif()
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_PREFIX_HEADER_IGNORE_PATH SET)
	if (NOT _isSet)
		set_property(TARGET ${_target} PROPERTY COTIRE_PREFIX_HEADER_IGNORE_PATH "${CMAKE_SOURCE_DIR}")
		cotire_check_is_path_relative_to("${CMAKE_BINARY_DIR}" _isRelative "${CMAKE_SOURCE_DIR}")
		if (NOT _isRelative)
			set_property(TARGET ${_target} APPEND PROPERTY COTIRE_PREFIX_HEADER_IGNORE_PATH "${CMAKE_BINARY_DIR}")
		endif()
	endif()
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_PREFIX_HEADER_INCLUDE_PATH SET)
	if (NOT _isSet)
		set_property(TARGET ${_target} PROPERTY COTIRE_PREFIX_HEADER_INCLUDE_PATH "")
	endif()
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_PREFIX_HEADER_INCLUDE_PRIORITY_PATH SET)
	if (NOT _isSet)
		set_property(TARGET ${_target} PROPERTY COTIRE_PREFIX_HEADER_INCLUDE_PRIORITY_PATH "")
	endif()
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_UNITY_SOURCE_PRE_UNDEFS SET)
	if (NOT _isSet)
		set_property(TARGET ${_target} PROPERTY COTIRE_UNITY_SOURCE_PRE_UNDEFS "")
	endif()
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_UNITY_SOURCE_POST_UNDEFS SET)
	if (NOT _isSet)
		set_property(TARGET ${_target} PROPERTY COTIRE_UNITY_SOURCE_POST_UNDEFS "")
	endif()
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_UNITY_LINK_LIBRARIES_INIT SET)
	if (NOT _isSet)
		set_property(TARGET ${_target} PROPERTY COTIRE_UNITY_LINK_LIBRARIES_INIT "COPY_UNITY")
	endif()
	get_property(_isSet TARGET ${_target} PROPERTY COTIRE_UNITY_SOURCE_MAXIMUM_NUMBER_OF_INCLUDES SET)
	if (NOT _isSet)
		if (COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES)
			set_property(TARGET ${_target} PROPERTY COTIRE_UNITY_SOURCE_MAXIMUM_NUMBER_OF_INCLUDES "${COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES}")
		else()
			set_property(TARGET ${_target} PROPERTY COTIRE_UNITY_SOURCE_MAXIMUM_NUMBER_OF_INCLUDES "")
		endif()
	endif()
endfunction()

function (cotire_make_target_message _target _languages _disableMsg _targetMsgVar)
	get_target_property(_targetUsePCH ${_target} COTIRE_ENABLE_PRECOMPILED_HEADER)
	get_target_property(_targetAddSCU ${_target} COTIRE_ADD_UNITY_BUILD)
	string (REPLACE ";" " " _languagesStr "${_languages}")
	math (EXPR _numberOfExcludedFiles "${ARGC} - 4")
	if (_numberOfExcludedFiles EQUAL 0)
		set (_excludedStr "")
	elseif (COTIRE_VERBOSE OR _numberOfExcludedFiles LESS 4)
		string (REPLACE ";" ", " _excludedStr "excluding ${ARGN}")
	else()
		set (_excludedStr "excluding ${_numberOfExcludedFiles} files")
	endif()
	set (_targetMsg "")
	if (NOT _languages)
		set (_targetMsg "Target ${_target} cannot be cotired.")
		if (_disableMsg)
			set (_targetMsg "${_targetMsg} ${_disableMsg}")
		endif()
	elseif (NOT _targetUsePCH AND NOT _targetAddSCU)
		set (_targetMsg "${_languagesStr} target ${_target} cotired without unity build and precompiled header.")
		if (_disableMsg)
			set (_targetMsg "${_targetMsg} ${_disableMsg}")
		endif()
	elseif (NOT _targetUsePCH)
		if (_excludedStr)
			set (_targetMsg "${_languagesStr} target ${_target} cotired without precompiled header ${_excludedStr}.")
		else()
			set (_targetMsg "${_languagesStr} target ${_target} cotired without precompiled header.")
		endif()
		if (_disableMsg)
			set (_targetMsg "${_targetMsg} ${_disableMsg}")
		endif()
	elseif (NOT _targetAddSCU)
		if (_excludedStr)
			set (_targetMsg "${_languagesStr} target ${_target} cotired without unity build ${_excludedStr}.")
		else()
			set (_targetMsg "${_languagesStr} target ${_target} cotired without unity build.")
		endif()
	else()
		if (_excludedStr)
			set (_targetMsg "${_languagesStr} target ${_target} cotired ${_excludedStr}.")
		else()
			set (_targetMsg "${_languagesStr} target ${_target} cotired.")
		endif()
	endif()
	set (${_targetMsgVar} "${_targetMsg}" PARENT_SCOPE)
endfunction()

function (cotire_choose_target_languages _target _targetLanguagesVar _wholeTargetVar)
	set (_languages ${ARGN})
	set (_allSourceFiles "")
	set (_allExcludedSourceFiles "")
	set (_allCotiredSourceFiles "")
	set (_targetLanguages "")
	set (_pchEligibleTargetLanguages "")
	get_target_property(_targetType ${_target} TYPE)
	get_target_property(_targetSourceFiles ${_target} SOURCES)
	get_target_property(_targetUsePCH ${_target} COTIRE_ENABLE_PRECOMPILED_HEADER)
	get_target_property(_targetAddSCU ${_target} COTIRE_ADD_UNITY_BUILD)
	set (_disableMsg "")
	foreach (_language ${_languages})
		get_target_property(_prefixHeader ${_target} COTIRE_${_language}_PREFIX_HEADER)
		get_target_property(_unityBuildFile ${_target} COTIRE_${_language}_UNITY_SOURCE)
		if (_prefixHeader OR _unityBuildFile)
			message (STATUS "cotire: target ${_target} has already been cotired.")
			set (${_targetLanguagesVar} "" PARENT_SCOPE)
			return()
		endif()
		if (_targetUsePCH AND "${_language}" MATCHES "^C|CXX$" AND DEFINED CMAKE_${_language}_COMPILER_ID)
			if (CMAKE_${_language}_COMPILER_ID)
				cotire_check_precompiled_header_support("${_language}" "${_target}" _disableMsg)
				if (_disableMsg)
					set (_targetUsePCH FALSE)
				endif()
			endif()
		endif()
		set (_sourceFiles "")
		set (_excludedSources "")
		set (_cotiredSources "")
		cotire_filter_language_source_files(${_language} ${_target} _sourceFiles _excludedSources _cotiredSources ${_targetSourceFiles})
		if (_sourceFiles OR _excludedSources OR _cotiredSources)
			list (APPEND _targetLanguages ${_language})
		endif()
		if (_sourceFiles)
			list (APPEND _allSourceFiles ${_sourceFiles})
		endif()
		list (LENGTH _sourceFiles _numberOfSources)
		if (NOT _numberOfSources LESS ${COTIRE_MINIMUM_NUMBER_OF_TARGET_SOURCES})
			list (APPEND _pchEligibleTargetLanguages ${_language})
		endif()
		if (_excludedSources)
			list (APPEND _allExcludedSourceFiles ${_excludedSources})
		endif()
		if (_cotiredSources)
			list (APPEND _allCotiredSourceFiles ${_cotiredSources})
		endif()
	endforeach()
	set (_targetMsgLevel STATUS)
	if (NOT _targetLanguages)
		string (REPLACE ";" " or " _languagesStr "${_languages}")
		set (_disableMsg "No ${_languagesStr} source files.")
		set (_targetUsePCH FALSE)
		set (_targetAddSCU FALSE)
	endif()
	if (_targetUsePCH)
		if (_allCotiredSourceFiles)
			cotire_get_source_file_property_values(_cotireTargets COTIRE_TARGET ${_allCotiredSourceFiles})
			list (REMOVE_DUPLICATES _cotireTargets)
			string (REPLACE ";" ", " _cotireTargetsStr "${_cotireTargets}")
			set (_disableMsg "Target sources already include a precompiled header for target(s) ${_cotireTargets}.")
			set (_disableMsg "${_disableMsg} Set target property COTIRE_ENABLE_PRECOMPILED_HEADER to FALSE for targets ${_target},")
			set (_disableMsg "${_disableMsg} ${_cotireTargetsStr} to get a workable build system.")
			set (_targetMsgLevel SEND_ERROR)
			set (_targetUsePCH FALSE)
		elseif (NOT _pchEligibleTargetLanguages)
			set (_disableMsg "Too few applicable sources.")
			set (_targetUsePCH FALSE)
		elseif (XCODE AND _allExcludedSourceFiles)
			# for Xcode, we cannot apply the precompiled header to individual sources, only to the whole target
			set (_disableMsg "Exclusion of source files not supported for generator Xcode.")
			set (_targetUsePCH FALSE)
		elseif (XCODE AND "${_targetType}" STREQUAL "OBJECT_LIBRARY")
			# for Xcode, we cannot apply the required PRE_BUILD action to generate the prefix header to an OBJECT_LIBRARY target
			set (_disableMsg "Required PRE_BUILD action not supported for OBJECT_LIBRARY targets for generator Xcode.")
			set (_targetUsePCH FALSE)
		endif()
	endif()
	set_property(TARGET ${_target} PROPERTY COTIRE_ENABLE_PRECOMPILED_HEADER ${_targetUsePCH})
	set_property(TARGET ${_target} PROPERTY COTIRE_ADD_UNITY_BUILD ${_targetAddSCU})
	cotire_make_target_message(${_target} "${_targetLanguages}" "${_disableMsg}" _targetMsg ${_allExcludedSourceFiles})
	if (_targetMsg)
		if (NOT DEFINED COTIREMSG_${_target})
			set (COTIREMSG_${_target} "")
		endif()
		if (COTIRE_VERBOSE OR NOT "${_targetMsgLevel}" STREQUAL "STATUS" OR
			NOT "${COTIREMSG_${_target}}" STREQUAL "${_targetMsg}")
			# cache message to avoid redundant messages on re-configure
			set (COTIREMSG_${_target} "${_targetMsg}" CACHE INTERNAL "${_target} cotire message.")
			message (${_targetMsgLevel} "${_targetMsg}")
		endif()
	endif()
	list (LENGTH _targetLanguages _numberOfLanguages)
	if (_numberOfLanguages GREATER 1 OR _allExcludedSourceFiles)
		set (${_wholeTargetVar} FALSE PARENT_SCOPE)
	else()
		set (${_wholeTargetVar} TRUE PARENT_SCOPE)
	endif()
	set (${_targetLanguagesVar} ${_targetLanguages} PARENT_SCOPE)
endfunction()

function (cotire_compute_unity_max_number_of_includes _target _maxIncludesVar)
	set (_sourceFiles ${ARGN})
	get_target_property(_maxIncludes ${_target} COTIRE_UNITY_SOURCE_MAXIMUM_NUMBER_OF_INCLUDES)
	if (_maxIncludes MATCHES "(-j|--parallel|--jobs) ?([0-9]*)")
		set (_numberOfThreads "${CMAKE_MATCH_2}")
		if (NOT _numberOfThreads)
			# use all available cores
			ProcessorCount(_numberOfThreads)
		endif()
		list (LENGTH _sourceFiles _numberOfSources)
		math (EXPR _maxIncludes "(${_numberOfSources} + ${_numberOfThreads} - 1) / ${_numberOfThreads}")
	elseif (NOT _maxIncludes MATCHES "[0-9]+")
		set (_maxIncludes 0)
	endif()
	if (COTIRE_DEBUG)
		message (STATUS "${_target} unity source max includes: ${_maxIncludes}")
	endif()
	set (${_maxIncludesVar} ${_maxIncludes} PARENT_SCOPE)
endfunction()

function (cotire_process_target_language _language _configurations _target _wholeTarget _cmdsVar)
	set (${_cmdsVar} "" PARENT_SCOPE)
	get_target_property(_targetSourceFiles ${_target} SOURCES)
	set (_sourceFiles "")
	set (_excludedSources "")
	set (_cotiredSources "")
	cotire_filter_language_source_files(${_language} ${_target} _sourceFiles _excludedSources _cotiredSources ${_targetSourceFiles})
	if (NOT _sourceFiles AND NOT _cotiredSources)
		return()
	endif()
	set (_cmds "")
	# check for user provided unity source file list
	get_property(_unitySourceFiles TARGET ${_target} PROPERTY COTIRE_${_language}_UNITY_SOURCE_INIT)
	if (NOT _unitySourceFiles)
		set (_unitySourceFiles ${_sourceFiles} ${_cotiredSources})
	endif()
	cotire_generate_target_script(
		${_language} "${_configurations}" ${_target} _targetScript _targetConfigScript ${_unitySourceFiles})
	# set up unity files for parallel compilation
	cotire_compute_unity_max_number_of_includes(${_target} _maxIncludes ${_unitySourceFiles})
	cotire_make_unity_source_file_paths(${_language} ${_target} ${_maxIncludes} _unityFiles ${_unitySourceFiles})
	list (LENGTH _unityFiles _numberOfUnityFiles)
	if (_numberOfUnityFiles EQUAL 0)
		return()
	elseif (_numberOfUnityFiles GREATER 1)
		cotire_setup_unity_generation_commands(
			${_language} ${_target} "${_targetScript}" "${_targetConfigScript}" "${_unityFiles}" _cmds ${_unitySourceFiles})
	endif()
	# set up single unity file for prefix header generation
	cotire_make_single_unity_source_file_path(${_language} ${_target} _unityFile)
	cotire_setup_unity_generation_commands(
		${_language} ${_target} "${_targetScript}" "${_targetConfigScript}" "${_unityFile}" _cmds ${_unitySourceFiles})
	cotire_make_prefix_file_path(${_language} ${_target} _prefixFile)
	# set up prefix header
	if (_prefixFile)
		# check for user provided prefix header files
		get_property(_prefixHeaderFiles TARGET ${_target} PROPERTY COTIRE_${_language}_PREFIX_HEADER_INIT)
		if (_prefixHeaderFiles)
			cotire_setup_prefix_generation_from_provided_command(
				${_language} ${_target} "${_targetConfigScript}" "${_prefixFile}" _cmds ${_prefixHeaderFiles})
		else()
			cotire_setup_prefix_generation_from_unity_command(
				${_language} ${_target} "${_targetConfigScript}" "${_prefixFile}" "${_unityFile}" _cmds ${_unitySourceFiles})
		endif()
		# check if selected language has enough sources at all
		list (LENGTH _sourceFiles _numberOfSources)
		if (_numberOfSources LESS ${COTIRE_MINIMUM_NUMBER_OF_TARGET_SOURCES})
			set (_targetUsePCH FALSE)
		else()
			get_target_property(_targetUsePCH ${_target} COTIRE_ENABLE_PRECOMPILED_HEADER)
		endif()
		if (_targetUsePCH)
			cotire_make_pch_file_path(${_language} ${_target} _pchFile)
			if (_pchFile)
				# first file in _sourceFiles is passed as the host file
				cotire_setup_pch_file_compilation(
					${_language} ${_target} "${_targetConfigScript}" "${_prefixFile}" "${_pchFile}" ${_sourceFiles})
				cotire_setup_pch_file_inclusion(
					${_language} ${_target} ${_wholeTarget} "${_prefixFile}" "${_pchFile}" ${_sourceFiles})
			endif()
		elseif (_prefixHeaderFiles)
			# user provided prefix header must be included unconditionally
			cotire_setup_prefix_file_inclusion(${_language} ${_target} "${_prefixFile}" ${_sourceFiles})
		endif()
	endif()
	# mark target as cotired for language
	set_property(TARGET ${_target} PROPERTY COTIRE_${_language}_UNITY_SOURCE "${_unityFiles}")
	if (_prefixFile)
		set_property(TARGET ${_target} PROPERTY COTIRE_${_language}_PREFIX_HEADER "${_prefixFile}")
		if (_targetUsePCH AND _pchFile)
			set_property(TARGET ${_target} PROPERTY COTIRE_${_language}_PRECOMPILED_HEADER "${_pchFile}")
		endif()
	endif()
	set (${_cmdsVar} ${_cmds} PARENT_SCOPE)
endfunction()

function (cotire_setup_clean_target _target)
	set (_cleanTargetName "${_target}${COTIRE_CLEAN_TARGET_SUFFIX}")
	if (NOT TARGET "${_cleanTargetName}")
		cotire_set_cmd_to_prologue(_cmds)
		get_filename_component(_outputDir "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_CFG_INTDIR}" ABSOLUTE)
		list (APPEND _cmds -P "${COTIRE_CMAKE_MODULE_FILE}" "cleanup" "${_outputDir}" "${COTIRE_INTDIR}" "${_target}")
		add_custom_target(${_cleanTargetName}
			COMMAND ${_cmds}
			WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
			COMMENT "Cleaning up target ${_target} cotire generated files"
			VERBATIM)
		cotire_init_target("${_cleanTargetName}")
	endif()
endfunction()

function (cotire_setup_pch_target _languages _configurations _target)
	if ("${CMAKE_GENERATOR}" MATCHES "Make|Ninja")
		# for makefile based generators, we add a custom target to trigger the generation of the cotire related files
		set (_dependsFiles "")
		foreach (_language ${_languages})
			set (_props COTIRE_${_language}_PREFIX_HEADER COTIRE_${_language}_UNITY_SOURCE)
			if (NOT CMAKE_${_language}_COMPILER_ID MATCHES "MSVC|Intel")
				# Visual Studio and Intel only create precompiled header as a side effect
				list (INSERT _props 0 COTIRE_${_language}_PRECOMPILED_HEADER)
			endif()
			cotire_get_first_set_property_value(_dependsFile TARGET ${_target} ${_props})
			if (_dependsFile)
				list (APPEND _dependsFiles "${_dependsFile}")
			endif()
		endforeach()
		if (_dependsFiles)
			set (_pchTargetName "${_target}${COTIRE_PCH_TARGET_SUFFIX}")
			add_custom_target("${_pchTargetName}" DEPENDS ${_dependsFiles})
			cotire_init_target("${_pchTargetName}")
			cotire_add_to_pch_all_target(${_pchTargetName})
		endif()
	else()
		# for other generators, we add the "clean all" target to clean up the precompiled header
		cotire_setup_clean_all_target()
	endif()
endfunction()

function (cotire_filter_object_libraries _target _objectLibrariesVar)
	set (_objectLibraries "")
	foreach (_source ${ARGN})
		if (_source MATCHES "^\\$<TARGET_OBJECTS:.+>$")
			list (APPEND _objectLibraries "${_source}")
		endif()
	endforeach()
	set (${_objectLibrariesVar} ${_objectLibraries} PARENT_SCOPE)
endfunction()

function (cotire_collect_unity_target_sources _target _languages _unityTargetSourcesVar)
	get_target_property(_targetSourceFiles ${_target} SOURCES)
	set (_unityTargetSources ${_targetSourceFiles})
	foreach (_language ${_languages})
		get_property(_unityFiles TARGET ${_target} PROPERTY COTIRE_${_language}_UNITY_SOURCE)
		if (_unityFiles)
			# remove source files that are included in the unity source
			set (_sourceFiles "")
			set (_excludedSources "")
			set (_cotiredSources "")
			cotire_filter_language_source_files(${_language} ${_target} _sourceFiles _excludedSources _cotiredSources ${_targetSourceFiles})
			if (_sourceFiles OR _cotiredSources)
				list (REMOVE_ITEM _unityTargetSources ${_sourceFiles} ${_cotiredSources})
			endif()
			# add unity source files instead
			list (APPEND _unityTargetSources ${_unityFiles})
		endif()
	endforeach()
	get_target_property(_linkLibrariesStrategy ${_target} COTIRE_UNITY_LINK_LIBRARIES_INIT)
	if ("${_linkLibrariesStrategy}" MATCHES "^COPY_UNITY$")
		cotire_filter_object_libraries(${_target} _objectLibraries ${_targetSourceFiles})
		if (_objectLibraries)
			cotire_map_libraries("${_linkLibrariesStrategy}" _unityObjectLibraries ${_objectLibraries})
			list (REMOVE_ITEM _unityTargetSources ${_objectLibraries})
			list (APPEND _unityTargetSources ${_unityObjectLibraries})
		endif()
	endif()
	set (${_unityTargetSourcesVar} ${_unityTargetSources} PARENT_SCOPE)
endfunction()

function (cotire_setup_unity_target_pch_usage _languages _target)
	foreach (_language ${_languages})
		get_property(_unityFiles TARGET ${_target} PROPERTY COTIRE_${_language}_UNITY_SOURCE)
		if (_unityFiles)
			get_property(_userPrefixFile TARGET ${_target} PROPERTY COTIRE_${_language}_PREFIX_HEADER_INIT)
			get_property(_prefixFile TARGET ${_target} PROPERTY COTIRE_${_language}_PREFIX_HEADER)
			if (_userPrefixFile AND _prefixFile)
				# user provided prefix header must be included unconditionally by unity sources
				cotire_setup_prefix_file_inclusion(${_language} ${_target} "${_prefixFile}" ${_unityFiles})
			endif()
		endif()
	endforeach()
endfunction()

function (cotire_setup_unity_build_target _languages _configurations _target)
	get_target_property(_unityTargetName ${_target} COTIRE_UNITY_TARGET_NAME)
	if (NOT _unityTargetName)
		set (_unityTargetName "${_target}${COTIRE_UNITY_BUILD_TARGET_SUFFIX}")
	endif()
	# determine unity target sub type
	get_target_property(_targetType ${_target} TYPE)
	if ("${_targetType}" STREQUAL "EXECUTABLE")
		set (_unityTargetSubType "")
	elseif (_targetType MATCHES "(STATIC|SHARED|MODULE|OBJECT)_LIBRARY")
		set (_unityTargetSubType "${CMAKE_MATCH_1}")
	else()
		message (WARNING "cotire: target ${_target} has unknown target type ${_targetType}.")
		return()
	endif()
	# determine unity target sources
	set (_unityTargetSources "")
	cotire_collect_unity_target_sources(${_target} "${_languages}" _unityTargetSources)
	# handle automatic Qt processing
	get_target_property(_targetAutoMoc ${_target} AUTOMOC)
	get_target_property(_targetAutoUic ${_target} AUTOUIC)
	get_target_property(_targetAutoRcc ${_target} AUTORCC)
	if (_targetAutoMoc OR _targetAutoUic OR _targetAutoRcc)
		# if the original target sources are subject to CMake's automatic Qt processing,
		# also include implicitly generated <targetname>_automoc.cpp file
		if (CMAKE_VERSION VERSION_LESS "3.8.0")
			list (APPEND _unityTargetSources "${_target}_automoc.cpp")
			set_property (SOURCE "${_target}_automoc.cpp" PROPERTY GENERATED TRUE)
		else()
			list (APPEND _unityTargetSources "${_target}_autogen/moc_compilation.cpp")
			set_property (SOURCE "${_target}_autogen/moc_compilation.cpp" PROPERTY GENERATED TRUE)
		endif()
	endif()
	# prevent AUTOMOC, AUTOUIC and AUTORCC properties from being set when the unity target is created
	set (CMAKE_AUTOMOC OFF)
	set (CMAKE_AUTOUIC OFF)
	set (CMAKE_AUTORCC OFF)
	if (COTIRE_DEBUG)
		message (STATUS "add target ${_targetType} ${_unityTargetName} ${_unityTargetSubType} EXCLUDE_FROM_ALL ${_unityTargetSources}")
	endif()
	# generate unity target
	if ("${_targetType}" STREQUAL "EXECUTABLE")
		add_executable(${_unityTargetName} ${_unityTargetSubType} EXCLUDE_FROM_ALL ${_unityTargetSources})
	else()
		add_library(${_unityTargetName} ${_unityTargetSubType} EXCLUDE_FROM_ALL ${_unityTargetSources})
	endif()
	if ("${CMAKE_GENERATOR}" MATCHES "Visual Studio")
		# depend on original target's automoc target, if it exists
		if (TARGET ${_target}_automoc)
			add_dependencies(${_unityTargetName} ${_target}_automoc)
		endif()
	else()
		if (_targetAutoMoc OR _targetAutoUic OR _targetAutoRcc)
			# depend on the original target's implicity generated <targetname>_automoc target
			if (CMAKE_VERSION VERSION_LESS "3.8.0")
				add_dependencies(${_unityTargetName} ${_target}_automoc)
			else()
				add_dependencies(${_unityTargetName} ${_target}_autogen)
			endif()
		endif()
	endif()
	# copy output location properties
	set (_outputDirProperties
		ARCHIVE_OUTPUT_DIRECTORY ARCHIVE_OUTPUT_DIRECTORY_<CONFIG>
		LIBRARY_OUTPUT_DIRECTORY LIBRARY_OUTPUT_DIRECTORY_<CONFIG>
		RUNTIME_OUTPUT_DIRECTORY RUNTIME_OUTPUT_DIRECTORY_<CONFIG>)
	if (COTIRE_UNITY_OUTPUT_DIRECTORY)
		set (_setDefaultOutputDir TRUE)
		if (IS_ABSOLUTE "${COTIRE_UNITY_OUTPUT_DIRECTORY}")
			set (_outputDir "${COTIRE_UNITY_OUTPUT_DIRECTORY}")
		else()
			# append relative COTIRE_UNITY_OUTPUT_DIRECTORY to target's actual output directory
			cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName} ${_outputDirProperties})
			cotire_resolve_config_properties("${_configurations}" _properties ${_outputDirProperties})
			foreach (_property ${_properties})
				get_property(_outputDir TARGET ${_target} PROPERTY ${_property})
				if (_outputDir)
					get_filename_component(_outputDir "${_outputDir}/${COTIRE_UNITY_OUTPUT_DIRECTORY}" ABSOLUTE)
					set_property(TARGET ${_unityTargetName} PROPERTY ${_property} "${_outputDir}")
					set (_setDefaultOutputDir FALSE)
				endif()
			endforeach()
			if (_setDefaultOutputDir)
				get_filename_component(_outputDir "${CMAKE_CURRENT_BINARY_DIR}/${COTIRE_UNITY_OUTPUT_DIRECTORY}" ABSOLUTE)
			endif()
		endif()
		if (_setDefaultOutputDir)
			set_target_properties(${_unityTargetName} PROPERTIES
				ARCHIVE_OUTPUT_DIRECTORY "${_outputDir}"
				LIBRARY_OUTPUT_DIRECTORY "${_outputDir}"
				RUNTIME_OUTPUT_DIRECTORY "${_outputDir}")
		endif()
	else()
		cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
			${_outputDirProperties})
	endif()
	# copy output name
	cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
		ARCHIVE_OUTPUT_NAME ARCHIVE_OUTPUT_NAME_<CONFIG>
		LIBRARY_OUTPUT_NAME LIBRARY_OUTPUT_NAME_<CONFIG>
		OUTPUT_NAME OUTPUT_NAME_<CONFIG>
		RUNTIME_OUTPUT_NAME RUNTIME_OUTPUT_NAME_<CONFIG>
		PREFIX <CONFIG>_POSTFIX SUFFIX
		IMPORT_PREFIX IMPORT_SUFFIX)
	# copy compile stuff
	cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
		COMPILE_DEFINITIONS COMPILE_DEFINITIONS_<CONFIG>
		COMPILE_FLAGS COMPILE_OPTIONS
		Fortran_FORMAT Fortran_MODULE_DIRECTORY
		INCLUDE_DIRECTORIES
		INTERPROCEDURAL_OPTIMIZATION INTERPROCEDURAL_OPTIMIZATION_<CONFIG>
		POSITION_INDEPENDENT_CODE
		C_COMPILER_LAUNCHER CXX_COMPILER_LAUNCHER
		C_INCLUDE_WHAT_YOU_USE CXX_INCLUDE_WHAT_YOU_USE
		C_VISIBILITY_PRESET CXX_VISIBILITY_PRESET VISIBILITY_INLINES_HIDDEN
		C_CLANG_TIDY CXX_CLANG_TIDY)
	# copy compile features
	cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
		C_EXTENSIONS C_STANDARD C_STANDARD_REQUIRED
		CXX_EXTENSIONS CXX_STANDARD CXX_STANDARD_REQUIRED
		COMPILE_FEATURES)
	# copy interface stuff
	cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
		COMPATIBLE_INTERFACE_BOOL COMPATIBLE_INTERFACE_NUMBER_MAX COMPATIBLE_INTERFACE_NUMBER_MIN
		COMPATIBLE_INTERFACE_STRING
		INTERFACE_COMPILE_DEFINITIONS INTERFACE_COMPILE_FEATURES INTERFACE_COMPILE_OPTIONS
		INTERFACE_INCLUDE_DIRECTORIES INTERFACE_SOURCES
		INTERFACE_POSITION_INDEPENDENT_CODE INTERFACE_SYSTEM_INCLUDE_DIRECTORIES
		INTERFACE_AUTOUIC_OPTIONS NO_SYSTEM_FROM_IMPORTED)
	# copy link stuff
	cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
		BUILD_WITH_INSTALL_RPATH INSTALL_RPATH INSTALL_RPATH_USE_LINK_PATH SKIP_BUILD_RPATH
		LINKER_LANGUAGE LINK_DEPENDS LINK_DEPENDS_NO_SHARED
		LINK_FLAGS LINK_FLAGS_<CONFIG>
		LINK_INTERFACE_LIBRARIES LINK_INTERFACE_LIBRARIES_<CONFIG>
		LINK_INTERFACE_MULTIPLICITY LINK_INTERFACE_MULTIPLICITY_<CONFIG>
		LINK_SEARCH_START_STATIC LINK_SEARCH_END_STATIC
		STATIC_LIBRARY_FLAGS STATIC_LIBRARY_FLAGS_<CONFIG>
		NO_SONAME SOVERSION VERSION
		LINK_WHAT_YOU_USE BUILD_RPATH)
	# copy cmake stuff
	cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
		IMPLICIT_DEPENDS_INCLUDE_TRANSFORM RULE_LAUNCH_COMPILE RULE_LAUNCH_CUSTOM RULE_LAUNCH_LINK)
	# copy Apple platform specific stuff
	cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
		BUNDLE BUNDLE_EXTENSION FRAMEWORK FRAMEWORK_VERSION INSTALL_NAME_DIR
		MACOSX_BUNDLE MACOSX_BUNDLE_INFO_PLIST MACOSX_FRAMEWORK_INFO_PLIST MACOSX_RPATH
		OSX_ARCHITECTURES OSX_ARCHITECTURES_<CONFIG> PRIVATE_HEADER PUBLIC_HEADER RESOURCE XCTEST
		IOS_INSTALL_COMBINED XCODE_EXPLICIT_FILE_TYPE XCODE_PRODUCT_TYPE)
	# copy Windows platform specific stuff
	cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
		GNUtoMS
		COMPILE_PDB_NAME COMPILE_PDB_NAME_<CONFIG>
		COMPILE_PDB_OUTPUT_DIRECTORY COMPILE_PDB_OUTPUT_DIRECTORY_<CONFIG>
		PDB_NAME PDB_NAME_<CONFIG> PDB_OUTPUT_DIRECTORY PDB_OUTPUT_DIRECTORY_<CONFIG>
		VS_DESKTOP_EXTENSIONS_VERSION VS_DOTNET_REFERENCES VS_DOTNET_TARGET_FRAMEWORK_VERSION
		VS_GLOBAL_KEYWORD VS_GLOBAL_PROJECT_TYPES VS_GLOBAL_ROOTNAMESPACE
		VS_IOT_EXTENSIONS_VERSION VS_IOT_STARTUP_TASK
		VS_KEYWORD VS_MOBILE_EXTENSIONS_VERSION
		VS_SCC_AUXPATH VS_SCC_LOCALPATH VS_SCC_PROJECTNAME VS_SCC_PROVIDER
		VS_WINDOWS_TARGET_PLATFORM_MIN_VERSION
		VS_WINRT_COMPONENT VS_WINRT_EXTENSIONS VS_WINRT_REFERENCES
		WIN32_EXECUTABLE WINDOWS_EXPORT_ALL_SYMBOLS
		DEPLOYMENT_REMOTE_DIRECTORY VS_CONFIGURATION_TYPE
		VS_SDK_REFERENCES VS_USER_PROPS VS_DEBUGGER_WORKING_DIRECTORY)
	# copy Android platform specific stuff
	cotire_copy_set_properties("${_configurations}" TARGET ${_target} ${_unityTargetName}
		ANDROID_API ANDROID_API_MIN ANDROID_GUI
		ANDROID_ANT_ADDITIONAL_OPTIONS ANDROID_ARCH ANDROID_ASSETS_DIRECTORIES
		ANDROID_JAR_DEPENDENCIES ANDROID_JAR_DIRECTORIES ANDROID_JAVA_SOURCE_DIR
		ANDROID_NATIVE_LIB_DEPENDENCIES ANDROID_NATIVE_LIB_DIRECTORIES
		ANDROID_PROCESS_MAX ANDROID_PROGUARD ANDROID_PROGUARD_CONFIG_PATH
		ANDROID_SECURE_PROPS_PATH ANDROID_SKIP_ANT_STEP ANDROID_STL_TYPE)
	# use output name from original target
	get_target_property(_targetOutputName ${_unityTargetName} OUTPUT_NAME)
	if (NOT _targetOutputName)
		set_property(TARGET ${_unityTargetName} PROPERTY OUTPUT_NAME "${_target}")
	endif()
	# use export symbol from original target
	cotire_get_target_export_symbol("${_target}" _defineSymbol)
	if (_defineSymbol)
		set_property(TARGET ${_unityTargetName} PROPERTY DEFINE_SYMBOL "${_defineSymbol}")
		if ("${_targetType}" STREQUAL "EXECUTABLE")
			set_property(TARGET ${_unityTargetName} PROPERTY ENABLE_EXPORTS TRUE)
		endif()
	endif()
	cotire_init_target(${_unityTargetName})
	cotire_add_to_unity_all_target(${_unityTargetName})
	set_property(TARGET ${_target} PROPERTY COTIRE_UNITY_TARGET_NAME "${_unityTargetName}")
endfunction(cotire_setup_unity_build_target)

function (cotire_target _target)
	set(_options "")
	set(_oneValueArgs "")
	set(_multiValueArgs LANGUAGES CONFIGURATIONS)
	cmake_parse_arguments(_option "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})
	if (NOT _option_LANGUAGES)
		get_property (_option_LANGUAGES GLOBAL PROPERTY ENABLED_LANGUAGES)
	endif()
	if (NOT _option_CONFIGURATIONS)
		cotire_get_configuration_types(_option_CONFIGURATIONS)
	endif()
	# check if cotire can be applied to target at all
	cotire_is_target_supported(${_target} _isSupported)
	if (NOT _isSupported)
		get_target_property(_imported ${_target} IMPORTED)
		get_target_property(_targetType ${_target} TYPE)
		if (_imported)
			message (WARNING "cotire: imported ${_targetType} target ${_target} cannot be cotired.")
		else()
			message (STATUS "cotire: ${_targetType} target ${_target} cannot be cotired.")
		endif()
		return()
	endif()
	# resolve alias
	get_target_property(_aliasName ${_target} ALIASED_TARGET)
	if (_aliasName)
		if (COTIRE_DEBUG)
			message (STATUS "${_target} is an alias. Applying cotire to aliased target ${_aliasName} instead.")
		endif()
		set (_target ${_aliasName})
	endif()
	# check if target needs to be cotired for build type
	# when using configuration types, the test is performed at build time
	cotire_init_cotire_target_properties(${_target})
	if (NOT CMAKE_CONFIGURATION_TYPES)
		if (CMAKE_BUILD_TYPE)
			list (FIND _option_CONFIGURATIONS "${CMAKE_BUILD_TYPE}" _index)
		else()
			list (FIND _option_CONFIGURATIONS "None" _index)
		endif()
		if (_index EQUAL -1)
			if (COTIRE_DEBUG)
				message (STATUS "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} not cotired (${_option_CONFIGURATIONS})")
			endif()
			return()
		endif()
	endif()
	# when not using configuration types, immediately create cotire intermediate dir
	if (NOT CMAKE_CONFIGURATION_TYPES)
		cotire_get_intermediate_dir(_baseDir)
		file (MAKE_DIRECTORY "${_baseDir}")
	endif()
	# choose languages that apply to the target
	cotire_choose_target_languages("${_target}" _targetLanguages _wholeTarget ${_option_LANGUAGES})
	if (NOT _targetLanguages)
		return()
	endif()
	set (_cmds "")
	foreach (_language ${_targetLanguages})
		cotire_process_target_language("${_language}" "${_option_CONFIGURATIONS}" ${_target} ${_wholeTarget} _cmd)
		if (_cmd)
			list (APPEND _cmds ${_cmd})
		endif()
	endforeach()
	get_target_property(_targetAddSCU ${_target} COTIRE_ADD_UNITY_BUILD)
	if (_targetAddSCU)
		cotire_setup_unity_build_target("${_targetLanguages}" "${_option_CONFIGURATIONS}" ${_target})
	endif()
	get_target_property(_targetUsePCH ${_target} COTIRE_ENABLE_PRECOMPILED_HEADER)
	if (_targetUsePCH)
		cotire_setup_target_pch_usage("${_targetLanguages}" ${_target} ${_wholeTarget} ${_cmds})
		cotire_setup_pch_target("${_targetLanguages}" "${_option_CONFIGURATIONS}" ${_target})
		if (_targetAddSCU)
			cotire_setup_unity_target_pch_usage("${_targetLanguages}" ${_target})
		endif()
	endif()
	get_target_property(_targetAddCleanTarget ${_target} COTIRE_ADD_CLEAN)
	if (_targetAddCleanTarget)
		cotire_setup_clean_target(${_target})
	endif()
endfunction(cotire_target)

function (cotire_map_libraries _strategy _mappedLibrariesVar)
	set (_mappedLibraries "")
	foreach (_library ${ARGN})
		if (_library MATCHES "^\\$<LINK_ONLY:(.+)>$")
			set (_libraryName "${CMAKE_MATCH_1}")
			set (_linkOnly TRUE)
			set (_objectLibrary FALSE)
		elseif (_library MATCHES "^\\$<TARGET_OBJECTS:(.+)>$")
			set (_libraryName "${CMAKE_MATCH_1}")
			set (_linkOnly FALSE)
			set (_objectLibrary TRUE)
		else()
			set (_libraryName "${_library}")
			set (_linkOnly FALSE)
			set (_objectLibrary FALSE)
		endif()
		if ("${_strategy}" MATCHES "COPY_UNITY")
			cotire_is_target_supported(${_libraryName} _isSupported)
			if (_isSupported)
				# use target's corresponding unity target, if available
				get_target_property(_libraryUnityTargetName ${_libraryName} COTIRE_UNITY_TARGET_NAME)
				if (TARGET "${_libraryUnityTargetName}")
					if (_linkOnly)
						list (APPEND _mappedLibraries "$<LINK_ONLY:${_libraryUnityTargetName}>")
					elseif (_objectLibrary)
						list (APPEND _mappedLibraries "$<TARGET_OBJECTS:${_libraryUnityTargetName}>")
					else()
						list (APPEND _mappedLibraries "${_libraryUnityTargetName}")
					endif()
				else()
					list (APPEND _mappedLibraries "${_library}")
				endif()
			else()
				list (APPEND _mappedLibraries "${_library}")
			endif()
		else()
			list (APPEND _mappedLibraries "${_library}")
		endif()
	endforeach()
	list (REMOVE_DUPLICATES _mappedLibraries)
	set (${_mappedLibrariesVar} ${_mappedLibraries} PARENT_SCOPE)
endfunction()

function (cotire_target_link_libraries _target)
	cotire_is_target_supported(${_target} _isSupported)
	if (NOT _isSupported)
		return()
	endif()
	get_target_property(_unityTargetName ${_target} COTIRE_UNITY_TARGET_NAME)
	if (TARGET "${_unityTargetName}")
		get_target_property(_linkLibrariesStrategy ${_target} COTIRE_UNITY_LINK_LIBRARIES_INIT)
		if (COTIRE_DEBUG)
			message (STATUS "unity target ${_unityTargetName} link strategy: ${_linkLibrariesStrategy}")
		endif()
		if ("${_linkLibrariesStrategy}" MATCHES "^(COPY|COPY_UNITY)$")
			get_target_property(_linkLibraries ${_target} LINK_LIBRARIES)
			if (_linkLibraries)
				cotire_map_libraries("${_linkLibrariesStrategy}" _unityLinkLibraries ${_linkLibraries})
				set_target_properties(${_unityTargetName} PROPERTIES LINK_LIBRARIES "${_unityLinkLibraries}")
				if (COTIRE_DEBUG)
					message (STATUS "unity target ${_unityTargetName} link libraries: ${_unityLinkLibraries}")
				endif()
			endif()
			get_target_property(_interfaceLinkLibraries ${_target} INTERFACE_LINK_LIBRARIES)
			if (_interfaceLinkLibraries)
				cotire_map_libraries("${_linkLibrariesStrategy}" _unityLinkInterfaceLibraries ${_interfaceLinkLibraries})
				set_target_properties(${_unityTargetName} PROPERTIES INTERFACE_LINK_LIBRARIES "${_unityLinkInterfaceLibraries}")
				if (COTIRE_DEBUG)
					message (STATUS "unity target ${_unityTargetName} interface link libraries: ${_unityLinkInterfaceLibraries}")
				endif()
			endif()
		endif()
	endif()
endfunction(cotire_target_link_libraries)

function (cotire_cleanup _binaryDir _cotireIntermediateDirName _targetName)
	if (_targetName)
		file (GLOB_RECURSE _cotireFiles "${_binaryDir}/${_targetName}*.*")
	else()
		file (GLOB_RECURSE _cotireFiles "${_binaryDir}/*.*")
	endif()
	# filter files in intermediate directory
	set (_filesToRemove "")
	foreach (_file ${_cotireFiles})
		get_filename_component(_dir "${_file}" DIRECTORY)
		get_filename_component(_dirName "${_dir}" NAME)
		if ("${_dirName}" STREQUAL "${_cotireIntermediateDirName}")
			list (APPEND _filesToRemove "${_file}")
		endif()
	endforeach()
	if (_filesToRemove)
		if (COTIRE_VERBOSE)
			message (STATUS "cleaning up ${_filesToRemove}")
		endif()
		file (REMOVE ${_filesToRemove})
	endif()
endfunction()

function (cotire_init_target _targetName)
	if (COTIRE_TARGETS_FOLDER)
		set_target_properties(${_targetName} PROPERTIES FOLDER "${COTIRE_TARGETS_FOLDER}")
	endif()
	set_target_properties(${_targetName} PROPERTIES EXCLUDE_FROM_ALL TRUE)
	if (MSVC_IDE)
		set_target_properties(${_targetName} PROPERTIES EXCLUDE_FROM_DEFAULT_BUILD TRUE)
	endif()
endfunction()

function (cotire_add_to_pch_all_target _pchTargetName)
	set (_targetName "${COTIRE_PCH_ALL_TARGET_NAME}")
	if (NOT TARGET "${_targetName}")
		add_custom_target("${_targetName}"
			WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
			VERBATIM)
		cotire_init_target("${_targetName}")
	endif()
	cotire_setup_clean_all_target()
	add_dependencies(${_targetName} ${_pchTargetName})
endfunction()

function (cotire_add_to_unity_all_target _unityTargetName)
	set (_targetName "${COTIRE_UNITY_BUILD_ALL_TARGET_NAME}")
	if (NOT TARGET "${_targetName}")
		add_custom_target("${_targetName}"
			WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
			VERBATIM)
		cotire_init_target("${_targetName}")
	endif()
	cotire_setup_clean_all_target()
	add_dependencies(${_targetName} ${_unityTargetName})
endfunction()

function (cotire_setup_clean_all_target)
	set (_targetName "${COTIRE_CLEAN_ALL_TARGET_NAME}")
	if (NOT TARGET "${_targetName}")
		cotire_set_cmd_to_prologue(_cmds)
		list (APPEND _cmds -P "${COTIRE_CMAKE_MODULE_FILE}" "cleanup" "${CMAKE_BINARY_DIR}" "${COTIRE_INTDIR}")
		add_custom_target(${_targetName}
			COMMAND ${_cmds}
			WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
			COMMENT "Cleaning up all cotire generated files"
			VERBATIM)
		cotire_init_target("${_targetName}")
	endif()
endfunction()

function (cotire)
	set(_options "")
	set(_oneValueArgs "")
	set(_multiValueArgs LANGUAGES CONFIGURATIONS)
	cmake_parse_arguments(_option "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})
	set (_targets ${_option_UNPARSED_ARGUMENTS})
	foreach (_target ${_targets})
		if (TARGET ${_target})
			cotire_target(${_target} LANGUAGES ${_option_LANGUAGES} CONFIGURATIONS ${_option_CONFIGURATIONS})
		else()
			message (WARNING "cotire: ${_target} is not a target.")
		endif()
	endforeach()
	foreach (_target ${_targets})
		if (TARGET ${_target})
			cotire_target_link_libraries(${_target})
		endif()
	endforeach()
endfunction()

if (CMAKE_SCRIPT_MODE_FILE)

	# cotire is being run in script mode
	# locate -P on command args
	set (COTIRE_ARGC -1)
	foreach (_index RANGE ${CMAKE_ARGC})
		if (COTIRE_ARGC GREATER -1)
			set (COTIRE_ARGV${COTIRE_ARGC} "${CMAKE_ARGV${_index}}")
			math (EXPR COTIRE_ARGC "${COTIRE_ARGC} + 1")
		elseif ("${CMAKE_ARGV${_index}}" STREQUAL "-P")
			set (COTIRE_ARGC 0)
		endif()
	endforeach()

	# include target script if available
	if ("${COTIRE_ARGV2}" MATCHES "\\.cmake$")
		# the included target scripts sets up additional variables relating to the target (e.g., COTIRE_TARGET_SOURCES)
		include("${COTIRE_ARGV2}")
	endif()

	if (COTIRE_DEBUG)
		message (STATUS "${COTIRE_ARGV0} ${COTIRE_ARGV1} ${COTIRE_ARGV2} ${COTIRE_ARGV3} ${COTIRE_ARGV4} ${COTIRE_ARGV5}")
	endif()

	if (NOT COTIRE_BUILD_TYPE)
		set (COTIRE_BUILD_TYPE "None")
	endif()
	string (TOUPPER "${COTIRE_BUILD_TYPE}" _upperConfig)
	set (_includeDirs ${COTIRE_TARGET_INCLUDE_DIRECTORIES_${_upperConfig}})
	set (_systemIncludeDirs ${COTIRE_TARGET_SYSTEM_INCLUDE_DIRECTORIES_${_upperConfig}})
	set (_compileDefinitions ${COTIRE_TARGET_COMPILE_DEFINITIONS_${_upperConfig}})
	set (_compileFlags ${COTIRE_TARGET_COMPILE_FLAGS_${_upperConfig}})
	# check if target has been cotired for actual build type COTIRE_BUILD_TYPE
	list (FIND COTIRE_TARGET_CONFIGURATION_TYPES "${COTIRE_BUILD_TYPE}" _index)
	if (_index GREATER -1)
		set (_sources ${COTIRE_TARGET_SOURCES})
		set (_sourcesDefinitions ${COTIRE_TARGET_SOURCES_COMPILE_DEFINITIONS_${_upperConfig}})
	else()
		if (COTIRE_DEBUG)
			message (STATUS "COTIRE_BUILD_TYPE=${COTIRE_BUILD_TYPE} not cotired (${COTIRE_TARGET_CONFIGURATION_TYPES})")
		endif()
		set (_sources "")
		set (_sourcesDefinitions "")
	endif()
	set (_targetPreUndefs ${COTIRE_TARGET_PRE_UNDEFS})
	set (_targetPostUndefs ${COTIRE_TARGET_POST_UNDEFS})
	set (_sourcesPreUndefs ${COTIRE_TARGET_SOURCES_PRE_UNDEFS})
	set (_sourcesPostUndefs ${COTIRE_TARGET_SOURCES_POST_UNDEFS})

	if ("${COTIRE_ARGV1}" STREQUAL "unity")

		if (XCODE)
			# executing pre-build action under Xcode, check dependency on target script
			set (_dependsOption DEPENDS "${COTIRE_ARGV2}")
		else()
			# executing custom command, no need to re-check for dependencies
			set (_dependsOption "")
		endif()

		cotire_select_unity_source_files("${COTIRE_ARGV3}" _sources ${_sources})

		cotire_generate_unity_source(
			"${COTIRE_ARGV3}" ${_sources}
			LANGUAGE "${COTIRE_TARGET_LANGUAGE}"
			SOURCES_COMPILE_DEFINITIONS ${_sourcesDefinitions}
			PRE_UNDEFS ${_targetPreUndefs}
			POST_UNDEFS ${_targetPostUndefs}
			SOURCES_PRE_UNDEFS ${_sourcesPreUndefs}
			SOURCES_POST_UNDEFS ${_sourcesPostUndefs}
			${_dependsOption})

	elseif ("${COTIRE_ARGV1}" STREQUAL "prefix")

		if (XCODE)
			# executing pre-build action under Xcode, check dependency on unity file and prefix dependencies
			set (_dependsOption DEPENDS "${COTIRE_ARGV4}" ${COTIRE_TARGET_PREFIX_DEPENDS})
		else()
			# executing custom command, no need to re-check for dependencies
			set (_dependsOption "")
		endif()

		set (_files "")
		foreach (_index RANGE 4 ${COTIRE_ARGC})
			if (COTIRE_ARGV${_index})
				list (APPEND _files "${COTIRE_ARGV${_index}}")
			endif()
		endforeach()

		cotire_generate_prefix_header(
			"${COTIRE_ARGV3}" ${_files}
			COMPILER_LAUNCHER "${COTIRE_TARGET_${COTIRE_TARGET_LANGUAGE}_COMPILER_LAUNCHER}"
			COMPILER_EXECUTABLE "${CMAKE_${COTIRE_TARGET_LANGUAGE}_COMPILER}"
			COMPILER_ARG1 ${CMAKE_${COTIRE_TARGET_LANGUAGE}_COMPILER_ARG1}
			COMPILER_ID "${CMAKE_${COTIRE_TARGET_LANGUAGE}_COMPILER_ID}"
			COMPILER_VERSION "${CMAKE_${COTIRE_TARGET_LANGUAGE}_COMPILER_VERSION}"
			LANGUAGE "${COTIRE_TARGET_LANGUAGE}"
			IGNORE_PATH "${COTIRE_TARGET_IGNORE_PATH};${COTIRE_ADDITIONAL_PREFIX_HEADER_IGNORE_PATH}"
			INCLUDE_PATH ${COTIRE_TARGET_INCLUDE_PATH}
			IGNORE_EXTENSIONS "${CMAKE_${COTIRE_TARGET_LANGUAGE}_SOURCE_FILE_EXTENSIONS};${COTIRE_ADDITIONAL_PREFIX_HEADER_IGNORE_EXTENSIONS}"
			INCLUDE_PRIORITY_PATH ${COTIRE_TARGET_INCLUDE_PRIORITY_PATH}
			INCLUDE_DIRECTORIES ${_includeDirs}
			SYSTEM_INCLUDE_DIRECTORIES ${_systemIncludeDirs}
			COMPILE_DEFINITIONS ${_compileDefinitions}
			COMPILE_FLAGS ${_compileFlags}
			${_dependsOption})

	elseif ("${COTIRE_ARGV1}" STREQUAL "precompile")

		set (_files "")
		foreach (_index RANGE 5 ${COTIRE_ARGC})
			if (COTIRE_ARGV${_index})
				list (APPEND _files "${COTIRE_ARGV${_index}}")
			endif()
		endforeach()

		cotire_precompile_prefix_header(
			"${COTIRE_ARGV3}" "${COTIRE_ARGV4}" "${COTIRE_ARGV5}"
			COMPILER_LAUNCHER "${COTIRE_TARGET_${COTIRE_TARGET_LANGUAGE}_COMPILER_LAUNCHER}"
			COMPILER_EXECUTABLE "${CMAKE_${COTIRE_TARGET_LANGUAGE}_COMPILER}"
			COMPILER_ARG1 ${CMAKE_${COTIRE_TARGET_LANGUAGE}_COMPILER_ARG1}
			COMPILER_ID "${CMAKE_${COTIRE_TARGET_LANGUAGE}_COMPILER_ID}"
			COMPILER_VERSION "${CMAKE_${COTIRE_TARGET_LANGUAGE}_COMPILER_VERSION}"
			LANGUAGE "${COTIRE_TARGET_LANGUAGE}"
			INCLUDE_DIRECTORIES ${_includeDirs}
			SYSTEM_INCLUDE_DIRECTORIES ${_systemIncludeDirs}
			COMPILE_DEFINITIONS ${_compileDefinitions}
			COMPILE_FLAGS ${_compileFlags})

	elseif ("${COTIRE_ARGV1}" STREQUAL "combine")

		if (COTIRE_TARGET_LANGUAGE)
			set (_combinedFile "${COTIRE_ARGV3}")
			set (_startIndex 4)
		else()
			set (_combinedFile "${COTIRE_ARGV2}")
			set (_startIndex 3)
		endif()
		set (_files "")
		foreach (_index RANGE ${_startIndex} ${COTIRE_ARGC})
			if (COTIRE_ARGV${_index})
				list (APPEND _files "${COTIRE_ARGV${_index}}")
			endif()
		endforeach()

		if (XCODE)
			# executing pre-build action under Xcode, check dependency on files to be combined
			set (_dependsOption DEPENDS ${_files})
		else()
			# executing custom command, no need to re-check for dependencies
			set (_dependsOption "")
		endif()

		if (COTIRE_TARGET_LANGUAGE)
			cotire_generate_unity_source(
				"${_combinedFile}" ${_files}
				LANGUAGE "${COTIRE_TARGET_LANGUAGE}"
				${_dependsOption})
		else()
			cotire_generate_unity_source("${_combinedFile}" ${_files} ${_dependsOption})
		endif()

	elseif ("${COTIRE_ARGV1}" STREQUAL "cleanup")

		cotire_cleanup("${COTIRE_ARGV2}" "${COTIRE_ARGV3}" "${COTIRE_ARGV4}")

	else()
		message (FATAL_ERROR "cotire: unknown command \"${COTIRE_ARGV1}\".")
	endif()

else()

	# cotire is being run in include mode
	# set up all variable and property definitions

	if (NOT DEFINED COTIRE_DEBUG_INIT)
		if (DEFINED COTIRE_DEBUG)
			set (COTIRE_DEBUG_INIT ${COTIRE_DEBUG})
		else()
			set (COTIRE_DEBUG_INIT FALSE)
		endif()
	endif()
	option (COTIRE_DEBUG "Enable cotire debugging output?" ${COTIRE_DEBUG_INIT})

	if (NOT DEFINED COTIRE_VERBOSE_INIT)
		if (DEFINED COTIRE_VERBOSE)
			set (COTIRE_VERBOSE_INIT ${COTIRE_VERBOSE})
		else()
			set (COTIRE_VERBOSE_INIT FALSE)
		endif()
	endif()
	option (COTIRE_VERBOSE "Enable cotire verbose output?" ${COTIRE_VERBOSE_INIT})

	set (COTIRE_ADDITIONAL_PREFIX_HEADER_IGNORE_EXTENSIONS "inc;inl;ipp" CACHE STRING
		"Ignore headers with the listed file extensions from the generated prefix header.")

	set (COTIRE_ADDITIONAL_PREFIX_HEADER_IGNORE_PATH "" CACHE STRING
		"Ignore headers from these directories when generating the prefix header.")

	set (COTIRE_UNITY_SOURCE_EXCLUDE_EXTENSIONS "m;mm" CACHE STRING
		"Ignore sources with the listed file extensions from the generated unity source.")

	set (COTIRE_MINIMUM_NUMBER_OF_TARGET_SOURCES "3" CACHE STRING
		"Minimum number of sources in target required to enable use of precompiled header.")

	if (NOT DEFINED COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES_INIT)
		if (DEFINED COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES)
			set (COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES_INIT ${COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES})
		elseif ("${CMAKE_GENERATOR}" MATCHES "JOM|Ninja|Visual Studio")
			# enable parallelization for generators that run multiple jobs by default
			set (COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES_INIT "-j")
		else()
			set (COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES_INIT "0")
		endif()
	endif()
	set (COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES "${COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES_INIT}" CACHE STRING
		"Maximum number of source files to include in a single unity source file.")

	if (NOT COTIRE_PREFIX_HEADER_FILENAME_SUFFIX)
		set (COTIRE_PREFIX_HEADER_FILENAME_SUFFIX "_prefix")
	endif()
	if (NOT COTIRE_UNITY_SOURCE_FILENAME_SUFFIX)
		set (COTIRE_UNITY_SOURCE_FILENAME_SUFFIX "_unity")
	endif()
	if (NOT COTIRE_INTDIR)
		set (COTIRE_INTDIR "cotire")
	endif()
	if (NOT COTIRE_PCH_ALL_TARGET_NAME)
		set (COTIRE_PCH_ALL_TARGET_NAME "all_pch")
	endif()
	if (NOT COTIRE_UNITY_BUILD_ALL_TARGET_NAME)
		set (COTIRE_UNITY_BUILD_ALL_TARGET_NAME "all_unity")
	endif()
	if (NOT COTIRE_CLEAN_ALL_TARGET_NAME)
		set (COTIRE_CLEAN_ALL_TARGET_NAME "clean_cotire")
	endif()
	if (NOT COTIRE_CLEAN_TARGET_SUFFIX)
		set (COTIRE_CLEAN_TARGET_SUFFIX "_clean_cotire")
	endif()
	if (NOT COTIRE_PCH_TARGET_SUFFIX)
		set (COTIRE_PCH_TARGET_SUFFIX "_pch")
	endif()
	if (MSVC)
		# MSVC default PCH memory scaling factor of 100 percent (75 MB) is too small for template heavy C++ code
		# use a bigger default factor of 170 percent (128 MB)
		if (NOT DEFINED COTIRE_PCH_MEMORY_SCALING_FACTOR)
			set (COTIRE_PCH_MEMORY_SCALING_FACTOR "170")
		endif()
	endif()
	if (NOT COTIRE_UNITY_BUILD_TARGET_SUFFIX)
		set (COTIRE_UNITY_BUILD_TARGET_SUFFIX "_unity")
	endif()
	if (NOT DEFINED COTIRE_TARGETS_FOLDER)
		set (COTIRE_TARGETS_FOLDER "cotire")
	endif()
	if (NOT DEFINED COTIRE_UNITY_OUTPUT_DIRECTORY)
		if ("${CMAKE_GENERATOR}" MATCHES "Ninja")
			# generated Ninja build files do not work if the unity target produces the same output file as the cotired target
			set (COTIRE_UNITY_OUTPUT_DIRECTORY "unity")
		else()
			set (COTIRE_UNITY_OUTPUT_DIRECTORY "")
		endif()
	endif()

	# define cotire cache variables

	define_property(
		CACHED_VARIABLE PROPERTY "COTIRE_ADDITIONAL_PREFIX_HEADER_IGNORE_PATH"
		BRIEF_DOCS "Ignore headers from these directories when generating the prefix header."
		FULL_DOCS
			"The variable can be set to a semicolon separated list of include directories."
			"If a header file is found in one of these directories or sub-directories, it will be excluded from the generated prefix header."
			"If not defined, defaults to empty list."
	)

	define_property(
		CACHED_VARIABLE PROPERTY "COTIRE_ADDITIONAL_PREFIX_HEADER_IGNORE_EXTENSIONS"
		BRIEF_DOCS "Ignore includes with the listed file extensions from the generated prefix header."
		FULL_DOCS
			"The variable can be set to a semicolon separated list of file extensions."
			"If a header file extension matches one in the list, it will be excluded from the generated prefix header."
			"Includes with an extension in CMAKE_<LANG>_SOURCE_FILE_EXTENSIONS are always ignored."
			"If not defined, defaults to inc;inl;ipp."
	)

	define_property(
		CACHED_VARIABLE PROPERTY "COTIRE_UNITY_SOURCE_EXCLUDE_EXTENSIONS"
		BRIEF_DOCS "Exclude sources with the listed file extensions from the generated unity source."
		FULL_DOCS
			"The variable can be set to a semicolon separated list of file extensions."
			"If a source file extension matches one in the list, it will be excluded from the generated unity source file."
			"Source files with an extension in CMAKE_<LANG>_IGNORE_EXTENSIONS are always excluded."
			"If not defined, defaults to m;mm."
	)

	define_property(
		CACHED_VARIABLE PROPERTY "COTIRE_MINIMUM_NUMBER_OF_TARGET_SOURCES"
		BRIEF_DOCS "Minimum number of sources in target required to enable use of precompiled header."
		FULL_DOCS
			"The variable can be set to an integer > 0."
			"If a target contains less than that number of source files, cotire will not enable the use of the precompiled header for the target."
			"If not defined, defaults to 3."
	)

	define_property(
		CACHED_VARIABLE PROPERTY "COTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES"
		BRIEF_DOCS "Maximum number of source files to include in a single unity source file."
		FULL_DOCS
			"This may be set to an integer >= 0."
			"If 0, cotire will only create a single unity source file."
			"If a target contains more than that number of source files, cotire will create multiple unity source files for it."
			"Can be set to \"-j\" to optimize the count of unity source files for the number of available processor cores."
			"Can be set to \"-j jobs\" to optimize the number of unity source files for the given number of simultaneous jobs."
			"Is used to initialize the target property COTIRE_UNITY_SOURCE_MAXIMUM_NUMBER_OF_INCLUDES."
			"Defaults to \"-j\" for the generators Visual Studio, JOM or Ninja. Defaults to 0 otherwise."
	)

	# define cotire directory properties

	define_property(
		DIRECTORY PROPERTY "COTIRE_ENABLE_PRECOMPILED_HEADER"
		BRIEF_DOCS "Modify build command of cotired targets added in this directory to make use of the generated precompiled header."
		FULL_DOCS
			"See target property COTIRE_ENABLE_PRECOMPILED_HEADER."
	)

	define_property(
		DIRECTORY PROPERTY "COTIRE_ADD_UNITY_BUILD"
		BRIEF_DOCS "Add a new target that performs a unity build for cotired targets added in this directory."
		FULL_DOCS
			"See target property COTIRE_ADD_UNITY_BUILD."
	)

	define_property(
		DIRECTORY PROPERTY "COTIRE_ADD_CLEAN"
		BRIEF_DOCS "Add a new target that cleans all cotire generated files for cotired targets added in this directory."
		FULL_DOCS
			"See target property COTIRE_ADD_CLEAN."
	)

	define_property(
		DIRECTORY PROPERTY "COTIRE_PREFIX_HEADER_IGNORE_PATH"
		BRIEF_DOCS "Ignore headers from these directories when generating the prefix header."
		FULL_DOCS
			"See target property COTIRE_PREFIX_HEADER_IGNORE_PATH."
	)

	define_property(
		DIRECTORY PROPERTY "COTIRE_PREFIX_HEADER_INCLUDE_PATH"
		BRIEF_DOCS "Honor headers from these directories when generating the prefix header."
		FULL_DOCS
			"See target property COTIRE_PREFIX_HEADER_INCLUDE_PATH."
	)

	define_property(
		DIRECTORY PROPERTY "COTIRE_PREFIX_HEADER_INCLUDE_PRIORITY_PATH"
		BRIEF_DOCS "Header paths matching one of these directories are put at the top of the prefix header."
		FULL_DOCS
			"See target property COTIRE_PREFIX_HEADER_INCLUDE_PRIORITY_PATH."
	)

	define_property(
		DIRECTORY PROPERTY "COTIRE_UNITY_SOURCE_PRE_UNDEFS"
		BRIEF_DOCS "Preprocessor undefs to place in the generated unity source file before the inclusion of each source file."
		FULL_DOCS
			"See target property COTIRE_UNITY_SOURCE_PRE_UNDEFS."
	)

	define_property(
		DIRECTORY PROPERTY "COTIRE_UNITY_SOURCE_POST_UNDEFS"
		BRIEF_DOCS "Preprocessor undefs to place in the generated unity source file after the inclusion of each source file."
		FULL_DOCS
			"See target property COTIRE_UNITY_SOURCE_POST_UNDEFS."
	)

	define_property(
		DIRECTORY PROPERTY "COTIRE_UNITY_SOURCE_MAXIMUM_NUMBER_OF_INCLUDES"
		BRIEF_DOCS "Maximum number of source files to include in a single unity source file."
		FULL_DOCS
			"See target property COTIRE_UNITY_SOURCE_MAXIMUM_NUMBER_OF_INCLUDES."
	)

	define_property(
		DIRECTORY PROPERTY "COTIRE_UNITY_LINK_LIBRARIES_INIT"
		BRIEF_DOCS "Define strategy for setting up the unity target's link libraries."
		FULL_DOCS
			"See target property COTIRE_UNITY_LINK_LIBRARIES_INIT."
	)

	# define cotire target properties

	define_property(
		TARGET PROPERTY "COTIRE_ENABLE_PRECOMPILED_HEADER" INHERITED
		BRIEF_DOCS "Modify this target's build command to make use of the generated precompiled header."
		FULL_DOCS
			"If this property is set to TRUE, cotire will modify the build command to make use of the generated precompiled header."
			"Irrespective of the value of this property, cotire will setup custom commands to generate the unity source and prefix header for the target."
			"For makefile based generators cotire will also set up a custom target to manually invoke the generation of the precompiled header."
			"The target name will be set to this target's name with the suffix _pch appended."
			"Inherited from directory."
			"Defaults to TRUE."
	)

	define_property(
		TARGET PROPERTY "COTIRE_ADD_UNITY_BUILD" INHERITED
		BRIEF_DOCS "Add a new target that performs a unity build for this target."
		FULL_DOCS
			"If this property is set to TRUE, cotire creates a new target of the same type that uses the generated unity source file instead of the target sources."
			"Most of the relevant target properties will be copied from this target to the new unity build target."
			"Target dependencies and linked libraries have to be manually set up for the new unity build target."
			"The unity target name will be set to this target's name with the suffix _unity appended."
			"Inherited from directory."
			"Defaults to TRUE."
	)

	define_property(
		TARGET PROPERTY "COTIRE_ADD_CLEAN" INHERITED
		BRIEF_DOCS "Add a new target that cleans all cotire generated files for this target."
		FULL_DOCS
			"If this property is set to TRUE, cotire creates a new target that clean all files (unity source, prefix header, precompiled header)."
			"The clean target name will be set to this target's name with the suffix _clean_cotire appended."
			"Inherited from directory."
			"Defaults to FALSE."
	)

	define_property(
		TARGET PROPERTY "COTIRE_PREFIX_HEADER_IGNORE_PATH" INHERITED
		BRIEF_DOCS "Ignore headers from these directories when generating the prefix header."
		FULL_DOCS
			"The property can be set to a list of directories."
			"If a header file is found in one of these directories or sub-directories, it will be excluded from the generated prefix header."
			"Inherited from directory."
			"If not set, this property is initialized to \${CMAKE_SOURCE_DIR};\${CMAKE_BINARY_DIR}."
	)

	define_property(
		TARGET PROPERTY "COTIRE_PREFIX_HEADER_INCLUDE_PATH" INHERITED
		BRIEF_DOCS "Honor headers from these directories when generating the prefix header."
		FULL_DOCS
			"The property can be set to a list of directories."
			"If a header file is found in one of these directories or sub-directories, it will be included in the generated prefix header."
			"If a header file is both selected by COTIRE_PREFIX_HEADER_IGNORE_PATH and COTIRE_PREFIX_HEADER_INCLUDE_PATH,"
			"the option which yields the closer relative path match wins."
			"Inherited from directory."
			"If not set, this property is initialized to the empty list."
	)

	define_property(
		TARGET PROPERTY "COTIRE_PREFIX_HEADER_INCLUDE_PRIORITY_PATH" INHERITED
		BRIEF_DOCS "Header paths matching one of these directories are put at the top of prefix header."
		FULL_DOCS
			"The property can be set to a list of directories."
			"Header file paths matching one of these directories will be inserted at the beginning of the generated prefix header."
			"Header files are sorted according to the order of the directories in the property."
			"If not set, this property is initialized to the empty list."
	)

	define_property(
		TARGET PROPERTY "COTIRE_UNITY_SOURCE_PRE_UNDEFS" INHERITED
		BRIEF_DOCS "Preprocessor undefs to place in the generated unity source file before the inclusion of each target source file."
		FULL_DOCS
			"This may be set to a semicolon-separated list of preprocessor symbols."
			"cotire will add corresponding #undef directives to the generated unit source file before each target source file."
			"Inherited from directory."
			"Defaults to empty string."
	)

	define_property(
		TARGET PROPERTY "COTIRE_UNITY_SOURCE_POST_UNDEFS" INHERITED
		BRIEF_DOCS "Preprocessor undefs to place in the generated unity source file after the inclusion of each target source file."
		FULL_DOCS
			"This may be set to a semicolon-separated list of preprocessor symbols."
			"cotire will add corresponding #undef directives to the generated unit source file after each target source file."
			"Inherited from directory."
			"Defaults to empty string."
	)

	define_property(
		TARGET PROPERTY "COTIRE_UNITY_SOURCE_MAXIMUM_NUMBER_OF_INCLUDES" INHERITED
		BRIEF_DOCS "Maximum number of source files to include in a single unity source file."
		FULL_DOCS
			"This may be set to an integer > 0."
			"If a target contains more than that number of source files, cotire will create multiple unity build files for it."
			"If not set, cotire will only create a single unity source file."
			"Inherited from directory."
			"Defaults to empty."
	)

	define_property(
		TARGET PROPERTY "COTIRE_<LANG>_UNITY_SOURCE_INIT"
		BRIEF_DOCS "User provided unity source file to be used instead of the automatically generated one."
		FULL_DOCS
			"If set, cotire will only add the given file(s) to the generated unity source file."
			"If not set, cotire will add all the target source files to the generated unity source file."
			"The property can be set to a user provided unity source file."
			"Defaults to empty."
	)

	define_property(
		TARGET PROPERTY "COTIRE_<LANG>_PREFIX_HEADER_INIT"
		BRIEF_DOCS "User provided prefix header file to be used instead of the automatically generated one."
		FULL_DOCS
			"If set, cotire will add the given header file(s) to the generated prefix header file."
			"If not set, cotire will generate a prefix header by tracking the header files included by the unity source file."
			"The property can be set to a user provided prefix header file (e.g., stdafx.h)."
			"Defaults to empty."
	)

	define_property(
		TARGET PROPERTY "COTIRE_UNITY_LINK_LIBRARIES_INIT" INHERITED
		BRIEF_DOCS "Define strategy for setting up unity target's link libraries."
		FULL_DOCS
			"If this property is empty or set to NONE, the generated unity target's link libraries have to be set up manually."
			"If this property is set to COPY, the unity target's link libraries will be copied from this target."
			"If this property is set to COPY_UNITY, the unity target's link libraries will be copied from this target with considering existing unity targets."
			"Inherited from directory."
			"Defaults to empty."
	)

	define_property(
		TARGET PROPERTY "COTIRE_<LANG>_UNITY_SOURCE"
		BRIEF_DOCS "Read-only property. The generated <LANG> unity source file(s)."
		FULL_DOCS
			"cotire sets this property to the path of the generated <LANG> single computation unit source file for the target."
			"Defaults to empty string."
	)

	define_property(
		TARGET PROPERTY "COTIRE_<LANG>_PREFIX_HEADER"
		BRIEF_DOCS "Read-only property. The generated <LANG> prefix header file."
		FULL_DOCS
			"cotire sets this property to the full path of the generated <LANG> language prefix header for the target."
			"Defaults to empty string."
	)

	define_property(
		TARGET PROPERTY "COTIRE_<LANG>_PRECOMPILED_HEADER"
		BRIEF_DOCS "Read-only property. The generated <LANG> precompiled header file."
		FULL_DOCS
			"cotire sets this property to the full path of the generated <LANG> language precompiled header binary for the target."
			"Defaults to empty string."
	)

	define_property(
		TARGET PROPERTY "COTIRE_UNITY_TARGET_NAME"
		BRIEF_DOCS "The name of the generated unity build target corresponding to this target."
		FULL_DOCS
			"This property can be set to the desired name of the unity target that will be created by cotire."
			"If not set, the unity target name will be set to this target's name with the suffix _unity appended."
			"After this target has been processed by cotire, the property is set to the actual name of the generated unity target."
			"Defaults to empty string."
	)

	# define cotire source properties

	define_property(
		SOURCE PROPERTY "COTIRE_EXCLUDED"
		BRIEF_DOCS "Do not modify source file's build command."
		FULL_DOCS
			"If this property is set to TRUE, the source file's build command will not be modified to make use of the precompiled header."
			"The source file will also be excluded from the generated unity source file."
			"Source files that have their COMPILE_FLAGS property set will be excluded by default."
			"Defaults to FALSE."
	)

	define_property(
		SOURCE PROPERTY "COTIRE_DEPENDENCY"
		BRIEF_DOCS "Add this source file to dependencies of the automatically generated prefix header file."
		FULL_DOCS
			"If this property is set to TRUE, the source file is added to dependencies of the generated prefix header file."
			"If the file is modified, cotire will re-generate the prefix header source upon build."
			"Defaults to FALSE."
	)

	define_property(
		SOURCE PROPERTY "COTIRE_UNITY_SOURCE_PRE_UNDEFS"
		BRIEF_DOCS "Preprocessor undefs to place in the generated unity source file before the inclusion of this source file."
		FULL_DOCS
			"This may be set to a semicolon-separated list of preprocessor symbols."
			"cotire will add corresponding #undef directives to the generated unit source file before this file is included."
			"Defaults to empty string."
	)

	define_property(
		SOURCE PROPERTY "COTIRE_UNITY_SOURCE_POST_UNDEFS"
		BRIEF_DOCS "Preprocessor undefs to place in the generated unity source file after the inclusion of this source file."
		FULL_DOCS
			"This may be set to a semicolon-separated list of preprocessor symbols."
			"cotire will add corresponding #undef directives to the generated unit source file after this file is included."
			"Defaults to empty string."
	)

	define_property(
		SOURCE PROPERTY "COTIRE_START_NEW_UNITY_SOURCE"
		BRIEF_DOCS "Start a new unity source file which includes this source file as the first one."
		FULL_DOCS
			"If this property is set to TRUE, cotire will complete the current unity file and start a new one."
			"The new unity source file will include this source file as the first one."
			"This property essentially works as a separator for unity source files."
			"Defaults to FALSE."
	)

	define_property(
		SOURCE PROPERTY "COTIRE_TARGET"
		BRIEF_DOCS "Read-only property. Mark this source file as cotired for the given target."
		FULL_DOCS
			"cotire sets this property to the name of target, that the source file's build command has been altered for."
			"Defaults to empty string."
	)

	message (STATUS "cotire ${COTIRE_CMAKE_MODULE_VERSION} loaded.")

endif()
