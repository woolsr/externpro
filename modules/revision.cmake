# generate a Revision.hpp file, Revision INTERFACE library
#  expected usage is to call xpGenerateRevision() cmake function, which includes this file so
#  it runs at cmake-time -- at cmake-time it creates a Revision_hpp target, which runs as a
#  cmake script at build-time -- a Revision INTERFACE library is also created
# @param[in] xpSourceDir : source directory to run git commands from
# @param[in] xpRelBranch : name of release branch (revision shows differently if on release branch)
# http://stackoverflow.com/questions/3780667/use-cmake-to-get-build-time-svn-revision
if(NOT DEFINED xpSourceDir)
  message(FATAL_ERROR "xpSourceDir must be set before including revision.cmake")
endif()
if(NOT DEFINED xpRelBranch)
  message(FATAL_ERROR "xpRelBranch must be set before including revision.cmake")
endif()
include(FindGit)
if(NOT GIT_FOUND AND NOT UNIX)
  find_program(GIT_EXECUTABLE
    NAMES git.exe HINTS $ENV{SystemDrive}/cygwin/bin
    DOC "git command line client (cygwin)"
    )
  if(GIT_EXECUTABLE)
    find_package(Git)
  endif()
endif()
if(GIT_FOUND AND EXISTS "${xpSourceDir}/.git")
  # xpRelBranch (release branch): date yyyymmdd-gitdescribe (20120518-gitdescribe)
  # other branches: user-branch-gitdescribe (smanders-padawan-gitdescribe)
  execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY ${xpSourceDir}
    OUTPUT_VARIABLE refsBranchName
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  string(REPLACE "remotes/origin/" "" branchName ${refsBranchName}) # submodules need this
  if(${branchName} STREQUAL ${xpRelBranch})
    string(TIMESTAMP ymd %Y%m%d)
    set(revisionPrefix "${ymd}")
  elseif(UNIX)
    set(revisionPrefix "$ENV{USER}-${branchName}")
  else()
    set(revisionPrefix "$ENV{USERNAME}-${branchName}")
  endif()
  # 'git describe' favors annotated tags (created with the -a or -s flag)
  # execute 'git describe --tags' command to find lightweight tag
  execute_process(COMMAND ${GIT_EXECUTABLE} describe --tags
    WORKING_DIRECTORY ${xpSourceDir}
    OUTPUT_VARIABLE gitDescribe
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE gitErr
    )
  if(gitErr) # no tags found...
    set(gitDescribe "notag")
  endif()
  set(xpRevision "${revisionPrefix}-${gitDescribe}")
else()
  set(xpRevision "Unknown-revision")
  message(AUTHOR_WARNING "Not a git repository? Using revision: ${xpRevision}.")
endif()
# write a txt file with only the revision, so other cmake can get it:
#  file(READ ${CMAKE_BINARY_DIR}/revision.txt revNum)
#  string(STRIP ${revNum} revNum)
set(revision_txt_file ${CMAKE_BINARY_DIR}/revision.txt)
file(WRITE ${revision_txt_file}
  "${xpRevision}\n"
  )
# write a file with the SCM_REV_NUM define
set(revision_h_file ${CMAKE_BINARY_DIR}/Revision/revision.h.txt)
file(WRITE ${revision_h_file}
  "#define SCM_REV_NUM \"${xpRevision}\"\n"
  )
# copy the file to the final header only if the revision changes
# reduces needless rebuilds
set(Revision_hpp_file ${CMAKE_BINARY_DIR}/Revision/Revision.hpp)
execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different
  ${revision_h_file} ${Revision_hpp_file}
  )
file(REMOVE ${revision_h_file})
################################################################################
# do the following at cmake-time so the Revision_hpp target exists at build-time
if(NOT TARGET Revision_hpp AND DEFINED CMAKE_SYSTEM_NAME)
  add_custom_command(OUTPUT ${revision_h_file}
    COMMAND ${CMAKE_COMMAND}
      -DxpSourceDir:FILEPATH="${xpSourceDir}"
      -DxpRelBranch:STRING="${xpRelBranch}"
      -P ${CMAKE_CURRENT_LIST_FILE}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Generating Revision.hpp..."
    )
  add_custom_target(Revision_hpp ALL
    DEPENDS ${revision_h_file}
    SOURCES ${CMAKE_CURRENT_LIST_FILE}
    )
  set_property(TARGET Revision_hpp PROPERTY FOLDER CMakeTargets)
  set_source_files_properties(${revision_h_file} PROPERTIES SYMBOLIC "true")
endif()
if(NOT TARGET Revision AND DEFINED CMAKE_SYSTEM_NAME)
  set(lib_name Revision)
  add_library(${lib_name} INTERFACE ${Revision_hpp_file})
  add_dependencies(${lib_name} Revision_hpp)
  target_include_directories(${lib_name} INTERFACE ${CMAKE_BINARY_DIR}/${lib_name})
  set_property(TARGET ${lib_name} PROPERTY FOLDER CMakeTargets)
endif()
