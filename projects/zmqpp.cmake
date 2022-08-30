# zmqpp
xpProOption(zmqpp DBG)
set(VER 21.07.09)
set(TAG ba4230d5d03d29ced9ca788e3bd1095477db08ae) # 2021.07.09 commit, head of develop branch
set(REPO github.com/zeromq/zmqpp)
set(FORK github.com/smanders/zmqpp)
set(PRO_ZMQPP
  NAME zmqpp
  WEB "zmqpp" https://zeromq.github.io/zmqpp/ "zmqpp website"
  LICENSE "open" https://${REPO}/blob/develop/LICENSE "Mozilla Public License 2.0"
  DESC "high-level binding for libzmq"
  REPO "repo" https://${REPO} "zeromq/zmqpp repo on github"
  GRAPH BUILD_DEPS libzmq
  VER ${VER}
  GIT_ORIGIN https://${FORK}.git
  GIT_UPSTREAM https://${REPO}.git
  GIT_TRACKING_BRANCH develop
  GIT_TAG xp${VER} # what to 'git checkout'
  GIT_REF ${TAG} # create patch from this tag to 'git checkout'
  DLURL https://${REPO}/archive/${TAG}.tar.gz
  DLMD5 67f4fc63461790f0acf76f4f762dd05b
  DLNAME zmqpp-${VER}.tar.gz
  PATCH ${PATCH_DIR}/zmqpp.patch
  DIFF https://${FORK}/compare/zeromq:
  )
########################################
function(build_zmqpp)
  if(NOT (XP_DEFAULT OR XP_PRO_ZMQPP))
    return()
  endif()
  xpBuildDeps(depTgts ${PRO_ZMQPP})
  xpGetArgValue(${PRO_ZMQPP} ARG NAME VALUE NAME)
  xpGetArgValue(${PRO_ZMQPP} ARG VER VALUE VER)
  set(XP_CONFIGURE
    -DCMAKE_INSTALL_INCLUDEDIR=include/${NAME}_${VER}
    -DCMAKE_INSTALL_LIBDIR=lib
    -DXP_NAMESPACE:STRING=xpro
    -DZMQPP_BUILD_SHARED:BOOL=false
    )
  set(FIND_DEPS "xpFindPkg(PKGS libzmq)\n")
  set(TARGETS_FILE lib/cmake/${NAME}-targets.cmake)
  set(LIBRARIES xpro::${NAME}-static)
  configure_file(${PRO_DIR}/use/usexp-template-lib-config.cmake
    ${STAGE_DIR}/share/cmake/usexp-${NAME}-config.cmake
    @ONLY NEWLINE_STYLE LF
    )
  xpCmakeBuild(${NAME} "${depTgts}" "${XP_CONFIGURE}")
endfunction()
