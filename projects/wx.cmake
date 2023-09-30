# wx
# xpbuild:msw_cmake-scratch,linux_configure-make
set(VER 3.2.2.1)
xpProOption(wx DBG_MSVC)
set(REPO https://github.com/wxWidgets/wxWidgets)
set(FORK https://github.com/smanders/wxWidgets)
set(PRO_WX
  NAME wx
  WEB "wxWidgets" http://wxwidgets.org/ "wxWidgets website"
  LICENSE "open" http://www.wxwidgets.org/about/newlicen.htm "wxWindows License: essentially LGPL with an exception"
  DESC "Cross-Platform GUI Library"
  REPO "repo" ${REPO} "wxWidgets repo on github"
  GRAPH GRAPH_NODE wx
  VER ${VER}
  GIT_ORIGIN ${FORK}
  GIT_UPSTREAM ${REPO}
  GIT_TAG xp${VER} # what to 'git checkout'
  GIT_REF v${VER}_220421 # patch from REF to TAG
  DLURL ${REPO}/releases/download/v${VER}/wxWidgets-${VER}.tar.bz2
  DLMD5 45bd5f56a06e7c4ca7caf6c0b4d5d506
  DEPS_FUNC build_wx
  DEPS_VARS WX_INCDIR WX_SRCDIR
  SUBPRO wxcmake
  )
if(UNIX AND NOT ${CMAKE_SYSTEM_NAME} STREQUAL Darwin)
  set(GTK_VER_RECORDED FALSE CACHE BOOL "gtk version not recorded" FORCE)
  set_property(CACHE GTK_VER_RECORDED PROPERTY TYPE INTERNAL)
endif()
########################################
function(wxFindDeps)
  if(UNIX AND NOT ${CMAKE_SYSTEM_NAME} STREQUAL Darwin)
    # TODO: detect package required to build on rhel:
    #   yum install libSM-devel.x86_64
    find_package(PkgConfig)
    #####
    # gtk
    if(NOT GTK2_FOUND)
      pkg_check_modules(GTK3 gtk+-3.0)
    endif()
    if(GTK3_FOUND)
      set(GTK_VER 3)
      if(NOT GTK_VER_RECORDED)
        file(APPEND ${XP_INFOFILE} "gtk3 version: ${GTK3_VERSION}\n")
        set(GTK_VER_RECORDED TRUE CACHE BOOL "gtk version recorded" FORCE)
        set_property(CACHE GTK_VER_RECORDED PROPERTY TYPE INTERNAL)
      endif()
    else()
      pkg_check_modules(GTK2 gtk+-2.0)
      if(GTK2_FOUND)
        set(GTK_VER 2)
        if(NOT GTK_VER_RECORDED)
          file(APPEND ${XP_INFOFILE} "gtk2 version: ${GTK2_VERSION}\n")
          set(GTK_VER_RECORDED TRUE CACHE BOOL "gtk version recorded" FORCE)
          set_property(CACHE GTK_VER_RECORDED PROPERTY TYPE INTERNAL)
        endif()
      else()
        message(FATAL_ERROR "\n"
          "gtk development not found -- wxWidgets can't be built. install on linux:\n"
          "  apt install libgtk2.0-dev or libgtk-3-dev\n"
          "  yum install gtk2-devel.x86_64 or gtk3-devel.x86_64\n"
          )
      endif()
    endif()
    set(GTK_VER ${GTK_VER} PARENT_SCOPE)
    ########
    # OpenGL
    find_package(OpenGL)
    if(NOT OPENGL_FOUND OR NOT OPENGL_GLU_FOUND)
      message(FATAL_ERROR "\n"
        "OpenGL or GLU not found -- wxWidgets can't be built. install on linux:\n"
        "  apt install libglu1-mesa-dev\n"
        "  yum install mesa-libGL-devel.x86_64 mesa-libGLU-devel.x86_64\n"
        )
    endif()
  endif()
endfunction()
########################################
function(build_wx)
  if(NOT (XP_DEFAULT OR XP_PRO_WX))
    return()
  endif()
  wxFindDeps() # sets GTK_VER
  set(NAME wxwidgets)
  xpGetArgValue(${PRO_WX} ARG VER VALUE VER)
  set(FIND_DEPS "# http://docs.wxwidgets.org/trunk/page_libs.html\n")
  set(FIND_DEPS "${FIND_DEPS}# TRICKY: reverse dependency order (base should be last)\n")
  set(FIND_DEPS "${FIND_DEPS}set(wx_all_libs aui propgrid richtext adv gl html core net xml base)\n")
  set(TARGETS_FILE tgt-${NAME}/${NAME}-targets.cmake)
  string(TOUPPER ${NAME} PRJ)
  set(USE_VARS "if(NOT DEFINED wx_libs)\n")
  set(USE_VARS "${USE_VARS}  set(wx_libs \${wx_all_libs})\n")
  set(USE_VARS "${USE_VARS}endif()\n")
  set(USE_VARS "${USE_VARS}set(${PRJ}_LIBRARIES wx_libs)\n")
  set(USE_VARS "${USE_VARS}list(TRANSFORM ${PRJ}_LIBRARIES PREPEND wx::) # prepend NAMESPACE\n")
  set(USE_VARS "${USE_VARS}list(APPEND reqVars ${PRJ}_LIBRARIES)\n")
  configure_file(${MODULES_DIR}/usexp.cmake.in
    ${STAGE_DIR}/share/cmake/usexp-${NAME}-config.cmake
    @ONLY NEWLINE_STYLE LF
    )
  string(REGEX REPLACE "([0-9])\\.([0-9])\\.([0-9])?"
    "include/wx-\\1.\\2" wxIncDir ${VER}
    )
  if(MSVC)
    set(XP_CONFIGURE
      -DCMAKE_INSTALL_INCLUDEDIR=${wxIncDir}
      -DCMAKE_INSTALL_LIBDIR=lib
      -DXP_INSTALL_CMAKEDIR=share/cmake/tgt-${NAME}
      )
    xpCmakeBuild(wx wx_wxcmake "${XP_CONFIGURE}")
    set(config msvc)
    list(APPEND wxtargets wx_${config})
  else()
    xpGetConfigureFlags(CXX wx_CONFIGURE_FLAGS)
    if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
      # http://forums.wxwidgets.org/viewtopic.php?f=19&t=37432
      set(XP_CONFIGURE_BASE <SOURCE_DIR>/configure --with-osx_cocoa
        --with-macosx-version-min=10.7
        --enable-universal_binary=i386,x86_64
        )
      execute_process(
        COMMAND xcrun --sdk macosx --show-sdk-path
        OUTPUT_VARIABLE sdkPath
        OUTPUT_STRIP_TRAILING_WHITESPACE
        )
      if(sdkPath)
        list(APPEND XP_CONFIGURE_BASE --with-macosx-sdk=${sdkPath})
      endif()
    else()
      set(XP_CONFIGURE_BASE <SOURCE_DIR>/configure --with-gtk=${GTK_VER})
    endif()
    if(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
      list(APPEND XP_CONFIGURE_BASE CXX=clang++)
    endif()
    if(${CMAKE_C_COMPILER_ID} MATCHES "Clang")
      list(APPEND XP_CONFIGURE_BASE CC=clang)
    endif()
    execute_process(COMMAND uname --machine
      OUTPUT_VARIABLE unameMachine
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_VARIABLE unameErr
      )
    if(DEFINED unameMachine AND NOT unameErr AND unameMachine MATCHES "^aarch")
      list(APPEND XP_CONFIGURE_BASE --build=aarch64-unknown-linux-gnu --enable-arm-neon)
    endif()
    list(APPEND XP_CONFIGURE_BASE ${wx_CONFIGURE_FLAGS} --with-opengl
      --with-libjpeg=builtin --with-libpng=builtin --with-libtiff=builtin
      --with-expat=builtin --with-regex=builtin --with-zlib=builtin
      #TODO: --without-subdirs (what does this option do? saw it used in wx forums)
      --disable-shared --disable-precomp-headers --without-libnotify
      # NOTE: without-libnotify so we can build externpro on a system that has libnotify
      # and use the built externpro installer on a system that doesn't have it
      --enable-display --enable-std_string --enable-std_iostreams --enable-std_containers
      )
    set(XP_CONFIGURE_Install --prefix=<INSTALL_DIR> --includedir=<INSTALL_DIR>/include
      --bindir=<INSTALL_DIR>/bin --libdir=<INSTALL_DIR>/lib
      )
    set(XP_CONFIGURE_Release ${XP_CONFIGURE_BASE})
    set(XP_CONFIGURE_Debug ${XP_CONFIGURE_BASE}
      --enable-debug --enable-debug_flag --enable-debug_info --enable-debug_gdb
      )
    # release version of wx is all we need
    # http://wxwidgets.blogspot.com/2009/09/debug-build-changes-in-wx3.html
    set(BUILD_CONFIGS Release)
    foreach(cfg ${BUILD_CONFIGS})
      set(XP_CONFIGURE_CMD ${XP_CONFIGURE_${cfg}} ${XP_CONFIGURE_Install})
      addproject_wx(${cfg})
    endforeach()
    list(GET BUILD_CONFIGS 0 config)
  endif()
  ExternalProject_Get_Property(wx SOURCE_DIR)
  ExternalProject_Get_Property(wx_${config} BINARY_DIR)
  set(wxSOURCE_DIR ${SOURCE_DIR})
  set(wxBINARY_DIR ${BINARY_DIR})
  if(NOT MSVC)
    set(wxTARGETS ${wxSOURCE_DIR}/build/cmake/wxwidgets-targets.cmake)
  endif()
  set(wxWINUNDEF ${wxSOURCE_DIR}/include/wx/msw/winundef.h)
  set(TIFF_HDRS "src/tiff/libtiff/*.h")
  if(NOT TARGET wx_stage_hdrs)
    ExternalProject_Add(wx_stage_hdrs DEPENDS ${wxtargets}
      DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR} BINARY_DIR ${NULL_DIR}
      SOURCE_DIR ${wxSOURCE_DIR}  INSTALL_DIR ${STAGE_DIR}/${wxIncDir}
      PATCH_COMMAND ${CMAKE_COMMAND} -Dsrc:STRING=${wxTARGETS}
        -Ddst:STRING=${STAGE_DIR}/share/cmake/tgt-${NAME}/
        -P ${MODULES_DIR}/cmscopyfiles.cmake
      CONFIGURE_COMMAND ${CMAKE_COMMAND} -Dsrc:STRING=${wxWINUNDEF}
        -Ddst:STRING=<INSTALL_DIR>/externpro/
        -P ${MODULES_DIR}/cmscopyfiles.cmake
      BUILD_COMMAND ${CMAKE_COMMAND} -Dsrc:STRING=${wxSOURCE_DIR}/${TIFF_HDRS}
        -Ddst:STRING=<INSTALL_DIR>/wx/tiff/
        -P ${MODULES_DIR}/cmscopyfiles.cmake
      # TRICKY: copy tiffconf.h from BINARY_DIR on Linux
      INSTALL_COMMAND ${CMAKE_COMMAND} -Dsrc:STRING=${wxBINARY_DIR}/${TIFF_HDRS}
        -Ddst:STRING=<INSTALL_DIR>/wx/tiff/
        -P ${MODULES_DIR}/cmscopyfiles.cmake
      )
    set_property(TARGET wx_stage_hdrs PROPERTY FOLDER ${bld_folder})
  endif()
  xpListAppendIfDne(wxtargets wx_stage_hdrs)
  if(ARGN)
    set(${ARGN} "${wxtargets}" PARENT_SCOPE)
    set(WX_INCDIR ${wxIncDir} PARENT_SCOPE)
    set(WX_SRCDIR ${wxSOURCE_DIR} PARENT_SCOPE)
  endif()
endfunction()
####################
macro(addproject_wx cfg)
  set(XP_TARGET wx_${cfg})
  ExternalProject_Get_Property(wx SOURCE_DIR)
  set(wxSOURCE_DIR ${SOURCE_DIR})
  if(NOT TARGET ${XP_TARGET})
    if(XP_BUILD_VERBOSE)
      message(STATUS "target ${XP_TARGET}")
      xpVerboseListing("[CONFIGURE]" "${XP_CONFIGURE_CMD}")
    else()
      message(STATUS "target ${XP_TARGET}")
    endif()
    ExternalProject_Add(${XP_TARGET} DEPENDS wx wx_wxcmake
      DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR} SOURCE_DIR ${wxSOURCE_DIR}
      CONFIGURE_COMMAND ${XP_CONFIGURE_CMD}
      BUILD_COMMAND   # use default
      INSTALL_COMMAND # use default
      )
    ExternalProject_Add_Step(${XP_TARGET} postinstall_${XP_TARGET}
      COMMAND ${CMAKE_COMMAND} -E copy_directory
        <INSTALL_DIR>/lib ${STAGE_DIR}/lib
      # NOTE: copying the include directory here would be duplicated
      # if we ever again build more BUILD_CONFIGS than just Release
      COMMAND ${CMAKE_COMMAND} -E copy_directory
        <INSTALL_DIR>/include ${STAGE_DIR}/include
      DEPENDEES install
      )
    set_property(TARGET ${XP_TARGET} PROPERTY FOLDER ${bld_folder})
  endif()
  if(NOT TARGET ${XP_TARGET}_wxconfig)
    ExternalProject_Add(${XP_TARGET}_wxconfig DEPENDS ${XP_TARGET}
      DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR} SOURCE_DIR ${wxSOURCE_DIR}
      CONFIGURE_COMMAND ${XP_CONFIGURE_${cfg}}
      BUILD_COMMAND ${CMAKE_COMMAND} -DcfgDir:STRING=<BINARY_DIR>/lib/wx/config
        -DstgDir:STRING=${STAGE_DIR} -P ${MODULES_DIR}/cmswxconfig.cmake
      INSTALL_COMMAND "" INSTALL_DIR ${NULL_DIR}
      )
    set_property(TARGET ${XP_TARGET}_wxconfig PROPERTY FOLDER ${bld_folder})
  endif()
  list(APPEND wxtargets ${XP_TARGET} ${XP_TARGET}_wxconfig)
endmacro()
