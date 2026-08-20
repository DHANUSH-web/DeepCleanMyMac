# Resolve compilers to absolute paths. CMake 4+ rejects a bare "clang++"
# for OBJCXX even when that name is on PATH.
execute_process(COMMAND xcrun --find clang
  OUTPUT_VARIABLE _dcmm_clang OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND xcrun --find clang++
  OUTPUT_VARIABLE _dcmm_clangxx OUTPUT_STRIP_TRAILING_WHITESPACE)
set(CMAKE_C_COMPILER "${_dcmm_clang}" CACHE FILEPATH "C compiler")
set(CMAKE_CXX_COMPILER "${_dcmm_clangxx}" CACHE FILEPATH "C++ compiler")
set(CMAKE_OBJCXX_COMPILER "${_dcmm_clangxx}" CACHE FILEPATH "ObjC++ compiler")
