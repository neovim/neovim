# Returns a list of all files that has been changed in current branch compared
# to master branch. This includes unstaged, staged and committed files.
function(get_changed_files outvar)
  execute_process(
    COMMAND git branch --show-current
    OUTPUT_VARIABLE current_branch
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  execute_process(
    COMMAND git merge-base master HEAD
    OUTPUT_VARIABLE ancestor_commit
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  # Changed files that have been committed
  execute_process(
    COMMAND git diff --diff-filter=d --name-only ${ancestor_commit}...${current_branch}
    OUTPUT_VARIABLE committed_files
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  separate_arguments(committed_files NATIVE_COMMAND ${committed_files})

  # Unstaged files
  execute_process(
    COMMAND git diff --diff-filter=d --name-only
    OUTPUT_VARIABLE unstaged_files
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  separate_arguments(unstaged_files NATIVE_COMMAND ${unstaged_files})

  # Staged files
  execute_process(
    COMMAND git diff --diff-filter=d --cached --name-only
    OUTPUT_VARIABLE staged_files
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  separate_arguments(staged_files NATIVE_COMMAND ${staged_files})

  set(files ${committed_files} ${unstaged_files} ${staged_files})
  list(REMOVE_DUPLICATES files)

  set(${outvar} "${files}" PARENT_SCOPE)
endfunction()

get_changed_files(changed_files)

if(LANG STREQUAL c)
  list(FILTER changed_files INCLUDE REGEX "\\.[ch]$")
  list(FILTER changed_files INCLUDE REGEX "^src/nvim/")

  if(changed_files)
    if(FORMAT_PRG)
      execute_process(COMMAND ${FORMAT_PRG} -c "src/uncrustify.cfg" --replace --no-backup ${changed_files})
    else()
      message(STATUS "Uncrustify not found. Skip formatting C files.")
    endif()
  endif()
elseif(LANG STREQUAL lua)
  list(FILTER changed_files INCLUDE REGEX "\\.lua$")
  list(FILTER changed_files INCLUDE REGEX "^runtime/")

  if(changed_files)
    if(FORMAT_PRG)
      execute_process(COMMAND ${FORMAT_PRG} ${changed_files})
    else()
      message(STATUS "Stylua not found. Skip formatting lua files.")
    endif()
  endif()
endif()
