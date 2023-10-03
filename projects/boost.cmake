# boost
# xpbuild:b2
set(VER 1.83.0)
string(REPLACE "." "_" VER_ ${VER}) # 1_83_0
xpProOption(boost DBG)
set(REPO https://github.com/boostorg/boost)
set(PRO_BOOST
  NAME boost
  WEB "boost" http://www.boost.org/ "Boost website"
  LICENSE "open" http://www.boost.org/users/license.html "Boost Software License"
  DESC "libraries that give C++ a boost"
  REPO "repo" ${REPO} "boost repo on github"
  GRAPH GRAPH_NODE boost
  BUILD_DEPS zlib bzip2
  VER ${VER}
  GIT_ORIGIN ${REPO}
  GIT_TAG boost-${VER} # what to 'git checkout'
  DLURL https://boostorg.jfrog.io/artifactory/main/release/${VER}/source/boost_${VER_}.tar.bz2
  DLMD5 406f0b870182b4eb17a23a9d8fce967d
  DEPS_FUNC build_boost
  SUBPRO boostinstall
#  SUBPRO boostbeast boostdll boostgil boostinstall boostinterprocess boostprogram_options boostprogram_optionshpp boostunits #boostgraph boostregex
  )
function(build_boost)
  if(NOT (XP_DEFAULT OR XP_PRO_BOOST))
    return()
  endif()
  xpBuildDeps(depTgts ${PRO_BOOST})
  list(APPEND boost_TARGETS ${depTgts})
  xpGetArgValue(${PRO_BOOST} ARG NAME VALUE NAME)
  xpGetArgValue(${PRO_BOOST} ARG VER VALUE VER)
  set(FIND_DEPS "xpFindPkg(PKGS bzip2 zlib) # iostream dependencies\n")
  set(FIND_DEPS "${FIND_DEPS}set(boostVer ${VER}) # for xpboost.cmake\n")
  set(TARGETS_FILE xpboost.cmake)
  string(TOUPPER ${NAME} PRJ)
  set(USE_VARS "set(${PRJ}_LIBRARIES \${Boost_LIBRARIES}) # from xpboost.cmake\n")
  set(USE_VARS "${USE_VARS}list(APPEND reqVars ${PRJ}_LIBRARIES)\n")
  configure_file(${MODULES_DIR}/usexp.cmake.in
    ${STAGE_DIR}/share/cmake/usexp-${NAME}-config.cmake
    @ONLY NEWLINE_STYLE LF
    )
  ExternalProject_Get_Property(boost SOURCE_DIR)
  build_boostb2(PRO boost BOOTSTRAP ${SOURCE_DIR}/tools/build
    B2PATH b2path TARGETS boost_TARGETS
    )
  build_boostlibs(PRO boost B2PATH ${b2path} TARGETS boost_TARGETS)
  if(ARGN)
    set(${ARGN} "${boost_TARGETS}" PARENT_SCOPE)
  endif()
endfunction()
####################
function(build_boostb2)
  # @param[in] PRO - project id (boost, boostold)
  # @param[in] BOOTSTRAP - path to bootstrap.[bat|sh]
  # @param[out] B2PATH - location of built b2
  # @param[out] TARGETS - external project target name
  set(oneValueArgs PRO BOOTSTRAP B2PATH TARGETS)
  cmake_parse_arguments(bb "" "${oneValueArgs}" "" ${ARGN})
  if(NOT DEFINED bb_PRO OR NOT DEFINED bb_BOOTSTRAP)
    message(FATAL_ERROR "boost.cmake: build_boostb2: required inputs not set")
  endif()
  if(DEFINED bb_TARGETS)
    string(TOUPPER ${bb_PRO} PRO)
    xpGetArgValue(${PRO_${PRO}} ARG SUBPRO VALUES subs)
    list(REMOVE_ITEM subs unknown)
    foreach(sub ${subs})
      xpListAppendIfDne(${bb_TARGETS} ${bb_PRO}_${sub})
    endforeach()
    xpListAppendIfDne(${bb_TARGETS} ${bb_PRO}.build)
    set(${bb_TARGETS} "${${bb_TARGETS}}" PARENT_SCOPE)
  endif()
  get_property(base_DIR DIRECTORY PROPERTY "EP_BASE")
  set(boostbld_DIR ${base_DIR}/bld.${bb_PRO})
  if(DEFINED bb_B2PATH)
    set(${bb_B2PATH} ${boostbld_DIR}/bin/b2${CMAKE_EXECUTABLE_SUFFIX} PARENT_SCOPE)
  endif()
  if(TARGET ${bb_PRO}.build)
    return()
  endif()
  if(MSVC)
    set(XP_CONFIGURE <SOURCE_DIR>/bootstrap.bat)
    set(boost_b2 <SOURCE_DIR>/b2${CMAKE_EXECUTABLE_SUFFIX} toolset=msvc)
  else()
    set(XP_CONFIGURE <SOURCE_DIR>/bootstrap.sh)
    # NOTE: specifying the toolset (clang) here gives output similar to this:
    #   [ 20%] Performing configure step for 'boost.build'
    #   Bootstrapping the build engine with toolset clang... engine/bin.linuxx86_64/b2
    # But there are still warnings:
    #   [ 23%] Performing install step for 'boost.build'
    #   warning: No toolsets are configured.
    #   warning: Configuring default toolset "gcc".
    #   warning: If the default is wrong, your build may not work correctly.
    #   warning: Use the "toolset=xxxxx" option to override our guess.
    #   warning: For more configuration options, please consult
    #   warning: http://boost.org/boost-build2/doc/html/bbv2/advanced/configuration.html
    # So, even though we specify the toolset to be clang, it still uses the default gcc.
    # Apparently, we would also need to have a user-config.jam if we cared that b2 was built
    # with clang instaed of gcc?
    if(CMAKE_COMPILER_IS_GNUCXX)
      list(APPEND XP_CONFIGURE --with-toolset=gcc)
    elseif("${CMAKE_CXX_COMPILER_ID}" MATCHES "Clang") # LLVM/Apple Clang
      list(APPEND XP_CONFIGURE --with-toolset=clang)
    else()
      message(FATAL_ERROR "boost.cmake: compiler support lacking: ${CMAKE_CXX_COMPILER_ID}")
    endif()
    set(boost_b2 <SOURCE_DIR>/b2 --ignore-site-config)
  endif()
  ExternalProject_Add(${bb_PRO}.build DEPENDS ${bb_PRO}
    DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR}
    SOURCE_DIR ${bb_BOOTSTRAP}
    CONFIGURE_COMMAND ${XP_CONFIGURE}
    BUILD_COMMAND "" BUILD_IN_SOURCE 1 # bootstrap fails if we don't build in source
    # BUILD_IN_SOURCE NOTE: introduces the following files on MSW...
    #       tools/build/bootstrap.log
    #       tools/build/v2/b2.exe
    #       tools/build/v2/bin/
    #       tools/build/v2/bjam.exe
    #       tools/build/v2/engine/bin.ntx86/
    #       tools/build/v2/engine/bootstrap/
    INSTALL_COMMAND ${boost_b2} install --prefix=${boostbld_DIR} INSTALL_DIR ${NULL_DIR}
    )
  set_property(TARGET ${bb_PRO}.build PROPERTY FOLDER ${bld_folder})
endfunction()
####################
function(stringToList stringlist lvalue)
  if(NOT "${stringlist}" STREQUAL "")
    string(STRIP ${stringlist} stringlist) # remove leading and trailing spaces
    string(REPLACE " -" ";-" listlist ${stringlist})
    foreach(item ${listlist})
      list(APPEND templist ${lvalue}="${item}")
    endforeach()
    set(${lvalue} "${templist}" PARENT_SCOPE)
  endif()
endfunction()
####################
function(userConfigJam jamFile)
  ExternalProject_Get_Property(${bl_PRO} TMP_DIR)
  set(cfgFile ${TMP_DIR}/user-config.jam)
  # TRICKY: need zlib, bzip2 include directories at cmake-time (before they're built)
  # so can't use xpGetPkgVar, xpFindPkg, etc - this complicates having multiple versions
  # of zlib and bzip2 (boost will have to choose a version here)
  xpGetArgValue(${PRO_ZLIB} ARG VER VALUE zlibVer)
  xpGetArgValue(${PRO_BZIP2} ARG VER VALUE bzip2Ver)
  set(zlibInc ${STAGE_DIR}/include/zlib_${zlibVer}/zlib)
  set(bzip2Inc ${STAGE_DIR}/include/bzip2_${bzip2Ver}/bzip2)
  if(WIN32)
    set(prefix lib)
  endif()
  include(${STAGE_DIR}/share/cmake/xpopts.cmake)
  xpSetPostfix()
  set(zlibName ${prefix}z${CMAKE_RELEASE_POSTFIX})
  set(bzip2Name bz2${CMAKE_RELEASE_POSTFIX})
  file(WRITE ${cfgFile}
    "using zlib : ${zlibVer} : <search>${STAGE_DIR}/lib <name>${zlibName} <include>${zlibInc} ;\n"
    "using bzip2 : ${bzip2Ver} : <search>${STAGE_DIR}/lib <name>${bzip2Name} <include>${bzip2Inc} ;\n"
    )
  # Boost.Python build
  # find_package(PythonInterp)
  # find_package(PythonLibs)
  find_package(Python3 COMPONENTS Interpreter Development)
  # find_package(pybind11 CONFIG)
  if(Python3_Interpreter_FOUND AND Python3_FOUND)
    if(XP_BUILD_VERBOSE)
      message(STATUS "Python3_EXECUTABLE: ${Python3_EXECUTABLE}")
      message(STATUS "Python3_VERSION: ${Python3_VERSION}")
      message(STATUS "Python3_INCLUDE_DIRS: ${Python3_INCLUDE_DIRS}")
      message(STATUS "Python3_LIBRARIES: ${Python3_LIBRARIES}")
    endif()
    Message(STATUS "Python Libs: ${Python3_LIBRARIES}")
    # get_filename_component(PYTHON_LIB_DIR ${Python3_LIBRARIES} DIRECTORY)
    Message(STATUS "Dir: ${Python3_LIBRARY_DIRS}; Python Libs: ${Python3_LIBRARIES}")
    file(APPEND ${cfgFile}
      "using python\n"
      "  : ${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}\n"
      "  : \"${Python3_EXECUTABLE}\"\n"
      "  : \"${Python3_INCLUDE_DIRS}\"\n"
      "  : \"${Python3_LIBRARY_DIRS}\"\n"
      "  : <python-debugging>off ;"
      )
  else()
    message(FATAL_ERROR "Unable to build boost.python, required python not found")
  endif()
  set(${jamFile} "${cfgFile}" PARENT_SCOPE)
endfunction()
####################
function(build_boostlibs)
  # @param[in] PRO - project id (boost, boostold)
  # @param[in] B2PATH - path to b2
  # @param[in/out] TARGETS - input deps, output list of all targets
  set(oneValueArgs PRO B2PATH TARGETS)
  cmake_parse_arguments(bl "" "${oneValueArgs}" "" ${ARGN})
  if(NOT DEFINED bl_PRO OR NOT DEFINED bl_B2PATH)
    message(FATAL_ERROR "boost.cmake: build_boostlibs: required inputs not set")
  endif()
  if(DEFINED bl_TARGETS)
    set(${bl_PRO}_DEPENDS ${${bl_TARGETS}})
  endif()
  if(XP_BUILD_DEBUG_ALL AND XP_BUILD_RELEASE)
    set(boost_VARIANT "debug,release")
  elseif(XP_PRO_BOOST_BUILD_DBG AND XP_BUILD_RELEASE)
    set(boost_VARIANT "debug,release")
  elseif(XP_BUILD_RELEASE)
    set(boost_VARIANT "release")
  # NOTE: currently externpro doesn't support building *only* Debug
  elseif(XP_BUILD_DEBUG) # so this elseif is "just in case..."
    set(boost_VARIANT "debug")
  endif()
  if(MSVC)
    if(DEFINED MSVC_TOOLSET_VERSION)
      math(EXPR major ${MSVC_TOOLSET_VERSION}/10)
      math(EXPR minor ${MSVC_TOOLSET_VERSION}%10)
      set(boost_TOOLSET msvc-${major}.${minor})
    else()
      message(FATAL_ERROR "boost.cmake: MSVC toolset version unknown")
    endif()
    if(XP_BUILD_STATIC)
      set(boost_RUNTIME_LINK static)
    else()
      set(boost_RUNTIME_LINK shared)
    endif()
  else()
    if(CMAKE_COMPILER_IS_GNUCXX)
      set(boost_TOOLSET gcc)
    elseif("${CMAKE_CXX_COMPILER_ID}" MATCHES "Clang") # LLVM/Apple Clang
      set(boost_TOOLSET clang)
    else()
      message(FATAL_ERROR "boost.cmake: compiler support lacking: ${CMAKE_CXX_COMPILER_ID}")
    endif()
    include(${MODULES_DIR}/flags.cmake) # populates CMAKE_*_FLAGS
    if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
      # clang: warning: argument unused during compilation: '-arch x86_64'
      xpStringRemoveIfExists(CMAKE_CXX_FLAGS "-arch x86_64")
      xpStringRemoveIfExists(CMAKE_C_FLAGS "-arch x86_64")
      xpStringRemoveIfExists(CMAKE_EXE_LINKER_FLAGS "-arch x86_64")
    endif()
    stringToList("${CMAKE_CXX_FLAGS}" cxxflags)
    stringToList("${CMAKE_C_FLAGS}" cflags)
    stringToList("${CMAKE_EXE_LINKER_FLAGS}" linkflags)
    set(boost_FLAGS "${cxxflags}" "${cflags}" "${linkflags}")
    set(boost_RUNTIME_LINK static)
  endif()
  set(boost_BUILD ${bl_B2PATH}
    --ignore-site-config --layout=versioned link=static threading=multi
    address-model=${BUILD_PLATFORM} variant=${boost_VARIANT}
    runtime-link=${boost_RUNTIME_LINK} toolset=${boost_TOOLSET} ${boost_FLAGS}
    --debug-configuration
    )
  # libraries with build issues
  set(exclude_libs locale math mpi)
  # libraries excluded until there's an argument to use them
  list(APPEND exclude_libs context contract coroutine fiber graph_parallel stacktrace type_erasure wave)
  foreach(lib ${exclude_libs})
    list(APPEND boost_BUILD --without-${lib})
  endforeach()
  set(boost_INSTALL install --libdir=${STAGE_DIR}/lib --includedir=${STAGE_DIR}/include --cmakedir=${STAGE_DIR}/share/cmake/tgt-boost)
  addproject_boost(${bl_PRO}_bld)
  list(APPEND ${bl_PRO}_DEPENDS ${bl_PRO}_bld) # serialize the build
  if(DEFINED bl_TARGETS)
    xpListAppendIfDne(${bl_TARGETS} "${${bl_PRO}_DEPENDS}")
    set(${bl_TARGETS} "${${bl_TARGETS}}" PARENT_SCOPE)
  endif()
endfunction()
####################
function(addproject_boost XP_TARGET)
  if(NOT TARGET ${XP_TARGET})
    get_property(baseDir DIRECTORY PROPERTY "EP_BASE")
    if(UNIX) # TODO hopefully this conditional will be only temporary
      list(APPEND boost_BUILD --build-dir=${baseDir}/Build/${XP_TARGET})
      # non-critical errors on MSW, that cause automated build server to report FAILURE:
      # * libs\regex\build\has_icu_test.cpp(12):
      #   fatal error C1083: Cannot open include file: 'unicode/uversion.h': No such file or directory
      # * libs\math\config\has_gcc_visibility.cpp(7):
      #   fatal error C1189: #error :  "This is a GCC specific test case".
      # reported here: http://permalink.gmane.org/gmane.comp.lib.boost.user/75695
      # if we build boost (on MSW) within source tree, the errors don't happen
    endif()
    userConfigJam(USER_CONFIG_JAM_FILE)
    set(boost_STAGE stage --stagedir=${baseDir}/Build/${XP_TARGET}/stage)
    ExternalProject_Get_Property(${bl_PRO} SOURCE_DIR)
    ExternalProject_Add(${XP_TARGET} DEPENDS ${${bl_PRO}_DEPENDS}
      DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR}
      SOURCE_DIR ${SOURCE_DIR}
      CONFIGURE_COMMAND ${CMAKE_COMMAND} -E copy ${USER_CONFIG_JAM_FILE} ${SOURCE_DIR}/tools/build/src/
      BUILD_COMMAND ${boost_BUILD} ${boost_STAGE} BUILD_IN_SOURCE 1 # <BINARY_DIR>==<SOURCE_DIR>
      INSTALL_COMMAND ${boost_BUILD} ${boost_INSTALL} INSTALL_DIR ${NULL_DIR}
      )
    set_property(TARGET ${XP_TARGET} PROPERTY FOLDER ${bld_folder})
    if(XP_BUILD_VERBOSE)
      message(STATUS "target ${XP_TARGET}")
      xpVerboseListing("[BUILD]" "${boost_BUILD}")
      xpVerboseListing("[STAGE]" "${boost_STAGE}")
      xpVerboseListing("[INSTALL]" "${boost_INSTALL}")
      xpVerboseListing("[DEPENDS]" "${${bl_PRO}_DEPENDS}")
    else()
      message(STATUS "target ${XP_TARGET}")
    endif()
  endif()
endfunction()
