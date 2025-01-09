#############################################################################
#Copyright (c) 2023,                                          
#                                                                         
#Distributed under the terms of the GNU General Public License v3.                 
#                                                                         
#The full license is in the file LICENSE, distributed with this software. 
#############################################################################

cmake_minimum_required(VERSION 3.24)
project(xeus-r)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")
set(XEUS_R_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)
set(CMAKE_VERBOSE_MAKEFILE ON)

# Versioning
# ===========

file(STRINGS "${XEUS_R_INCLUDE_DIR}/xeus-r/xeus_r_config.hpp" version_defines
     REGEX "#define XEUS_R_VERSION_(MAJOR|MINOR|PATCH)")
foreach (ver ${version_defines})
    if (ver MATCHES "#define XEUS_R_VERSION_(MAJOR|MINOR|PATCH) +([^ ]+)$")
        set(XEUS_R_VERSION_${CMAKE_MATCH_1} "${CMAKE_MATCH_2}" CACHE INTERNAL "")
    endif ()
endforeach ()
set(${PROJECT_NAME}_VERSION
    ${XEUS_R_VERSION_MAJOR}.${XEUS_R_VERSION_MINOR}.${XEUS_R_VERSION_PATCH})
message(STATUS "Building xeus-r v${${PROJECT_NAME}_VERSION}")

# Build options
# =============

option(XEUS_R_BUILD_STATIC "Build xeus-r static library" ON)
option(XEUS_R_BUILD_SHARED "Split xr build into executable and library" ON)
option(XEUS_R_BUILD_EXECUTABLE "Build the xr executable" ON)

option(XEUS_R_USE_SHARED_XEUS "Link xr  with the xeus shared library (instead of the static library)" ON)
option(XEUS_R_USE_SHARED_XEUS_R "Link xr  with the xeus-r shared library (instead of the static library)" ON)
option(XEUS_R_EMSCRIPTEN_WASM_BUILD "Build for wasm with emscripten" OFF)

if(EMSCRIPTEN)
    add_compile_definitions(XEUS_R_EMSCRIPTEN_WASM_BUILD)
    message("Build with emscripten")
    set(XEUS_R_BUILD_STATIC ON)
    set(XEUS_R_BUILD_SHARED OFF)
    set(XEUS_R_BUILD_EXECUTABLE OFF)
    set(XEUS_R_USE_SHARED_XEUS OFF)
    set(XEUS_R_USE_SHARED_XEUS_R OFF)
    # ENV (https://github.com/emscripten-core/emscripten/commit/6d9681ad04f60b41ef6345ab06c29bbc9eeb84e0)
    set(EMSCRIPTEN_FEATURES "${EMSCRIPTEN_FEATURES} -s \"EXTRA_EXPORTED_RUNTIME_METHODS=[ENV']\"")
endif()

# Dependencies
# ============
set(xeus_REQUIRED_VERSION 5.0.0)
set(xeus_zmq_REQUIRED_VERSION 3.0.0)

if (NOT TARGET xeus AND NOT TARGET xeus-static)
    find_package(xeus ${xeus_REQUIRED_VERSION} REQUIRED)
endif ()
find_package(R REQUIRED)

message(STATUS "R_HOME           = ${R_HOME}")
message(STATUS "R_INCLUDE_DIR    = ${R_INCLUDE_DIR}")
message(STATUS "R_LDFLAGS        = ${R_LDFLAGS}")
message(STATUS "R_LIBRARY_BASE   = ${R_LIBRARY_BASE}")
message(STATUS "R_LIBRARY_BLAS   = ${R_LIBRARY_BLAS}")
message(STATUS "R_LIBRARY_LAPACK = ${R_LIBRARY_LAPACK}")
message(STATUS "R_VERSION_MAJOR = ${R_VERSION_MAJOR}")
message(STATUS "R_VERSION_MINOR = ${R_VERSION_MINOR}")

# Configuration
# =============

include(GNUInstallDirs)

if (NOT DEFINED XR_KERNELSPEC_PATH)
    set(XR_KERNELSPEC_PATH "${CMAKE_INSTALL_FULL_BINDIR}/")
endif ()

get_filename_component(XEUS_R_LD_LIBRARY_PATH "${R_LIBRARY_BASE}" DIRECTORY)

if (MSVC)
configure_file (
    "${CMAKE_CURRENT_SOURCE_DIR}/share/jupyter/kernels/xr/kernel-win.json.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/share/jupyter/kernels/xr/kernel.json"
)
else ()
configure_file (
    "${CMAKE_CURRENT_SOURCE_DIR}/share/jupyter/kernels/xr/kernel.json.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/share/jupyter/kernels/xr/kernel.json"
)
endif ()

# Source files
# ============

set(XEUS_R_HEADERS
    include/xeus-r/xeus_r_config.hpp
    include/xeus-r/xinterpreter.hpp
)

set(XEUS_R_SRC
    src/xinterpreter.cpp
    src/routines.cpp
)

if(EMSCRIPTEN)
    list(APPEND XEUS_R_SRC src/xinterpreter_wasm.cpp)
endif()

set(XEUS_R_MAIN_SRC
    src/main.cpp
)

# Targets and link - Macros
# =========================

include(CheckCXXCompilerFlag)

string(TOUPPER "${CMAKE_BUILD_TYPE}" U_CMAKE_BUILD_TYPE)

set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib; ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")

macro(xeus_r_set_common_options target_name)
    if (MSVC)
        target_compile_options(${target_name} PUBLIC /wd4251 /wd4141)
        target_compile_options(${target_name} PUBLIC /wd4018 /wd4267 /wd4715 /wd4146 /wd4129)
    endif ()

    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR
        CMAKE_CXX_COMPILER_ID MATCHES "GNU" OR
        CMAKE_CXX_COMPILER_ID MATCHES "Intel")

        if (EMSCRIPTEN)
            target_compile_options(${target_name} PRIVATE -fPIC)
        else ()
            target_compile_options(${target_name} PUBLIC -Wunused-parameter -Wextra -Wreorder)
        endif()

        # C++17 flag
        CHECK_CXX_COMPILER_FLAG("-std=c++17" HAS_CPP_17_FLAG)
        if (HAS_CPP_17_FLAG)
            target_compile_features(${target_name} PRIVATE cxx_std_17)
        else ()
            message(FATAL_ERROR "Unsupported compiler -- xeus-r requires C++17 support!")
        endif ()
    endif ()

    if (APPLE)
        set_target_properties(${target_name} PROPERTIES
            MACOSX_RPATH ON
        )
    else ()
        set_target_properties(${target_name} PROPERTIES
            BUILD_WITH_INSTALL_RPATH 1
            SKIP_BUILD_RPATH FALSE
        )
    endif ()

    set_target_properties(${target_name} PROPERTIES
        INSTALL_RPATH_USE_LINK_PATH TRUE
    )
endmacro()

# Common macro kernels (xr)
macro(xeus_r_set_kernel_options target_name)
    if (XEUS_R_USE_SHARED_XEUS_R)
        target_link_libraries(${target_name} PRIVATE xeus-r)
        if(CMAKE_DL_LIBS)
            target_link_libraries(${target_name} PRIVATE ${CMAKE_DL_LIBS} util)
        endif()
    else ()
        target_link_libraries(${target_name} PRIVATE xeus-r-static)
    endif()

    if(NOT EMSCRIPTEN)
        target_link_options(${target_name} PRIVATE "-Wl,-v")
        find_package(Threads) 
        target_link_libraries(${target_name} PRIVATE ${CMAKE_THREAD_LIBS_INIT})
    endif()
    
endmacro()

# Common macro for shared and static library
macro(xeus_r_create_target target_name linkage output_name)
    string(TOUPPER "${linkage}" linkage_upper)

    if (NOT ${linkage_upper} MATCHES "^(SHARED|STATIC)$")
        message(FATAL_ERROR "Invalid library linkage: ${linkage}")
    endif ()

    add_library(${target_name} ${linkage_upper} ${XEUS_R_SRC} ${XEUS_R_HEADERS})
    xeus_r_set_common_options(${target_name})

    set_target_properties(${target_name} PROPERTIES
                          PUBLIC_HEADER "${XEUS_R_HEADERS}"
                          PREFIX ""
                          VERSION ${${PROJECT_NAME}_VERSION}
                          SOVERSION ${XEUS_R_VERSION_MAJOR}
                          OUTPUT_NAME "lib${output_name}")

    target_compile_definitions(${target_name} PUBLIC "XEUS_R_EXPORTS")

    target_compile_features(${target_name} PRIVATE cxx_std_17)

    message(STATUS "🍅🍅🍅 XEUS_R_INCLUDE_DIR: ${XEUS_R_INCLUDE_DIR}")

    target_include_directories(${target_name}
                               PUBLIC
                               $<BUILD_INTERFACE:${XEUS_R_INCLUDE_DIR}>
                               $<INSTALL_INTERFACE:include>
                               ${R_INCLUDE_DIR})

    if (XEUS_R_USE_SHARED_XEUS)
        set(XEUS_R_XEUS_TARGET xeus)
    else ()
        set(XEUS_R_XEUS_TARGET xeus-static)
    endif ()

    if (EMSCRIPTEN)
        target_link_libraries(${target_name} PUBLIC ${XEUS_R_XEUS_TARGET} PRIVATE ${R_LIBRARY_BASE} ${R_LIBRARY_BLAS} ${R_LDFLAGS})
    else ()
        target_link_libraries(${target_name} PUBLIC ${XEUS_R_XEUS_TARGET} PRIVATE ${R_LIBRARY_BASE})
    endif ()

    if (WIN32 OR CYGWIN)
        #
    elseif (APPLE)
        target_link_libraries(${target_name} PRIVATE "-undefined dynamic_lookup")
    endif ()

    if(NOT EMSCRIPTEN)
        find_package(Threads) # TODO: add Threads as a dependence of xeus-static?
        target_link_libraries(${target_name} PRIVATE ${CMAKE_THREAD_LIBS_INIT})
    endif()

    # MSVC compilers don't support C99 _Complex type
    # https://learn.microsoft.com/en-us/cpp/c-runtime-library/complex-math-support?view=msvc-170
    if (MSVC)
        target_compile_definitions(${target_name} PRIVATE "R_LEGACY_RCOMPLEX")
    endif ()
endmacro()

# xeus-r
# ===========

set(XEUS_R_TARGETS "")

if (XEUS_R_BUILD_SHARED)
    # Build libraries
    xeus_r_create_target(xeus-r SHARED xeus-r)
    list(APPEND XEUS_R_TARGETS xeus-r)
endif ()

if (XEUS_R_BUILD_STATIC)
    # On Windows, a static library should use a different output name
    # to avoid the conflict with the import library of a shared one.
    if (CMAKE_HOST_WIN32)
        xeus_r_create_target(xeus-r-static STATIC xeus-r-static)
    else ()
        xeus_r_create_target(xeus-r-static STATIC xeus-r)
    endif ()
    list(APPEND XEUS_R_TARGETS xeus-r-static)
endif ()

# xr
# =======
if (XEUS_R_BUILD_EXECUTABLE)
    find_package(xeus-zmq 1.0.3 REQUIRED)
    add_executable(xr ${XEUS_R_MAIN_SRC})
    target_compile_features(xr PRIVATE cxx_std_17)
    xeus_r_set_common_options(xr)
    xeus_r_set_kernel_options(xr)
    target_link_libraries(xr PRIVATE xeus xeus-zmq)
endif()

set(ZLIB_LIBRARY "/home/ihuicatl/Repos/Xeus/r-lite/host-env/lib/libz.a")
set(ZLIB_INCLUDE_DIR "/home/ihuicatl/Repos/Xeus/r-lite/host-env/include")
set(PNG_LIBRARY "/home/ihuicatl/Repos/Xeus/r-lite/host-env/lib/libpng16.a")
set(PNG_PNG_INCLUDE_DIR "/home/ihuicatl/Repos/Xeus/r-lite/host-env/include")


if(EMSCRIPTEN)
    include(WasmBuildLocalOptions)
    find_package(xeus-lite REQUIRED)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GLIB REQUIRED glib-2.0)
    pkg_check_modules(GIO REQUIRED gio-2.0)
    # pkg_check_modules(PANGO REQUIRED pango)
    # pkg_check_modules(PANGOCAIRO REQUIRED pangocairo)
    # pkg_check_modules(PANGOFT2 REQUIRED pangoft2)
    # pkg_check_modules(FONTCONFIG REQUIRED fontconfig)
    # pkg_check_modules(HARFBUZZ REQUIRED harfbuzz)
    # find_package(PNG REQUIRED)

    pkg_check_modules(GIO REQUIRED gio-2.0)
    set(GIO_LIBRARY "/home/ihuicatl/Repos/Xeus/r-lite/host-env/lib/libgio-2.0.a")

    add_executable(xr src/main_emscripten_kernel.cpp)
    target_link_libraries(xr PRIVATE xeus-lite
        ${R_HOME}/library/grDevices/libs/cairo.so
        ${R_HOME}/library/grDevices/libs/grDevices.so
        ${R_HOME}/library/graphics/libs/graphics.so
        ${R_HOME}/library/grid/libs/grid.so
        ${R_HOME}/library/methods/libs/methods.so
        ${R_HOME}/library/parallel/libs/parallel.so
        ${R_HOME}/library/splines/libs/splines.so
        ${R_HOME}/library/stats/libs/stats.so
        ${R_HOME}/library/tools/libs/tools.so
        ${R_HOME}/library/utils/libs/utils.so
        ${R_HOME}/library/fastmap/libs/fastmap.so # External packages from here down
        ${R_HOME}/library/digest/libs/digest.so
        ${R_HOME}/library/lattice/libs/lattice.so
        ${R_HOME}/library/magrittr/libs/magrittr.so
        ${R_HOME}/library/MASS/libs/MASS.so
        ${R_HOME}/library/isoband/libs/isoband.so
        ${R_HOME}/library/utf8/libs/utf8.so
        ${R_HOME}/library/fansi/libs/fansi.so
        ${R_HOME}/library/base64enc/libs/base64enc.so
        ${R_HOME}/library/farver/libs/farver.so
        ${R_HOME}/library/colorspace/libs/colorspace.so
        ${R_HOME}/library/cli/libs/cli.so
        ${R_HOME}/library/glue/libs/glue.so
        ${R_HOME}/library/jsonlite/libs/jsonlite.so
        ${R_HOME}/library/rlang/libs/rlang.so
        ${R_HOME}/library/nlme/libs/nlme.so
        ${R_HOME}/library/Matrix/libs/Matrix.so
        ${R_HOME}/library/ellipsis/libs/ellipsis.so
        ${R_HOME}/library/mgcv/libs/mgcv.so
        ${R_HOME}/library/htmltools/libs/htmltools.so
        ${R_HOME}/library/vctrs/libs/vctrs.so
        ${R_HOME}/library/tibble/libs/tibble.so
        # ${R_HOME}/library/dplyr/libs/dplyr.so
        ${GIO_LIBRARY}
    )

    #  -lpng -ltiff -lglib-2.0 -lgobject-2.0 -lxml2 -lgio-2.0 -lffi -lpangocairo-1.0 -lfontconfig -lpangoft2-1.0 -lpango-1.0 -lharfbuzz" 
    target_link_options(xr
        PUBLIC "SHELL: --pre-js ../pre.js"
        PUBLIC "SHELL: -g"
        PUBLIC "SHELL: -s ERROR_ON_WASM_CHANGES_AFTER_LINK=1"
        PUBLIC "SHELL: -s ERROR_ON_UNDEFINED_SYMBOLS=1"
    )
    xeus_r_set_kernel_options(xr)
    xeus_wasm_compile_options(xr)
    xeus_wasm_link_options(xr "web,worker")
endif()


# Installation
# ============
include(CMakePackageConfigHelpers)

set(XEUS_R_CMAKECONFIG_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}" CACHE STRING "install path for xeus-rConfig.cmake")

# Install xeus-r and xeus-r-static
if (XEUS_R_BUILD_SHARED)
    install(TARGETS ${XEUS_R_TARGETS}
            EXPORT ${PROJECT_NAME}-targets
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
            PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/xeus-r)

    # Makes the project importable from the build directory
    export(EXPORT ${PROJECT_NAME}-targets
           FILE "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Targets.cmake")
endif ()

# Install xr
if (XEUS_R_BUILD_EXECUTABLE)
    install(TARGETS xr
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

if (XEUS_R_BUILD_EXECUTABLE OR EMSCRIPTEN)
    # Configuration and data directories for jupyter and xeus-r
    set(XJUPYTER_DATA_DIR "share/jupyter"    CACHE STRING "Jupyter data directory")

    # Install xr Jupyter kernelspec
    set(KERNELSPEC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/share/jupyter/kernels)
    install(DIRECTORY ${KERNELSPEC_DIR}
            DESTINATION ${XJUPYTER_DATA_DIR}
            PATTERN "*.in" EXCLUDE)


    # Extra path for installing Jupyter kernelspec
    if (XEXTRA_JUPYTER_DATA_DIR)
        install(DIRECTORY ${KERNELSPEC_DIR}
                DESTINATION ${XEXTRA_JUPYTER_DATA_DIR}
                PATTERN "*.in" EXCLUDE)
    endif ()
endif ()

# Configure 'xeus-rConfig.cmake' for a build tree
set(XEUS_R_CONFIG_CODE "####### Expanded from \@XEUS_R_CONFIG_CODE\@ #######\n")
set(XEUS_R_CONFIG_CODE "${XEUS_R_CONFIG_CODE}set(CMAKE_MODULE_PATH \"${CMAKE_CURRENT_SOURCE_DIR}/cmake;\${CMAKE_MODULE_PATH}\")\n")
set(XEUS_R_CONFIG_CODE "${XEUS_R_CONFIG_CODE}##################################################")
configure_package_config_file(${PROJECT_NAME}Config.cmake.in
                              "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
                              INSTALL_DESTINATION ${PROJECT_BINARY_DIR})

# Configure 'xeus-rConfig.cmake.in for an install tree
set(XEUS_R_CONFIG_CODE "")
configure_package_config_file(${PROJECT_NAME}Config.cmake.in
                              "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${PROJECT_NAME}Config.cmake"
                              INSTALL_DESTINATION ${XEUS_R_CMAKECONFIG_INSTALL_DIR})

write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
                                 VERSION ${${PROJECT_NAME}_VERSION}
                                 COMPATIBILITY AnyNewerVersion)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${PROJECT_NAME}Config.cmake
              ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
              DESTINATION ${XEUS_R_CMAKECONFIG_INSTALL_DIR})

if (XEUS_R_BUILD_SHARED)
    install(EXPORT ${PROJECT_NAME}-targets
            FILE ${PROJECT_NAME}Targets.cmake
            DESTINATION ${XEUS_R_CMAKECONFIG_INSTALL_DIR})
endif ()

if(EMSCRIPTEN)
    install(FILES
            "$<TARGET_FILE_DIR:xr>/xr.js"
            "$<TARGET_FILE_DIR:xr>/xr.wasm"
            DESTINATION ${CMAKE_INSTALL_BINDIR})
endif ()
