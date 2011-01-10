include (AddCompilerFlag)
include (MacroEnsureVersion)

macro(_my_find _list _value _ret)
   list(FIND ${_list} "${_value}" _found)
   if(_found EQUAL -1)
      set(${_ret} FALSE)
   else(_found EQUAL -1)
      set(${_ret} TRUE)
   endif(_found EQUAL -1)
endmacro(_my_find)

macro(OptimizeForArchitecture)
   set(TARGET_ARCHITECTURE "auto" CACHE STRING "CPU architecture to optimize for. Using an incorrect setting here can result in crashes of the resulting binary because of invalid instructions used.\nSetting the value to \"auto\" will try to optimize for the architecture where cmake is called.\nOther supported values are: \"generic\", \"core\", \"merom\" (65nm Core2), \"penryn\" (45nm Core2), \"nehalem\", \"westmere\", \"sandy-bridge\", \"atom\", \"k8\", \"k8-sse3\", \"barcelona\", \"istanbul\", \"magny-cours\".")
   set(_force)
   if(NOT _last_target_arch STREQUAL "${TARGET_ARCHITECTURE}")
      message(STATUS "${TARGET_ARCHITECTURE} changed")
      set(_force FORCE)
   endif(NOT _last_target_arch STREQUAL "${TARGET_ARCHITECTURE}")
   set(_last_target_arch "${TARGET_ARCHITECTURE}" CACHE STRING "" FORCE)
   mark_as_advanced(_last_target_arch)
   string(TOLOWER "${TARGET_ARCHITECTURE}" TARGET_ARCHITECTURE)

   set(_march_flag_list)
   set(_available_vector_units_list)

   if(TARGET_ARCHITECTURE STREQUAL "auto")
      set(TARGET_ARCHITECTURE "generic")
      set(_vendor_id)
      set(_cpu_family)
      set(_cpu_model)
      if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
         file(READ "/proc/cpuinfo" _cpuinfo)
         string(REGEX REPLACE ".*vendor_id[ \t]*:[ \t]+([a-zA-Z0-9_-]+).*" "\\1" _vendor_id "${_cpuinfo}")
         string(REGEX REPLACE ".*cpu family[ \t]*:[ \t]+([a-zA-Z0-9_-]+).*" "\\1" _cpu_family "${_cpuinfo}")
         string(REGEX REPLACE ".*model[ \t]*:[ \t]+([a-zA-Z0-9_-]+).*" "\\1" _cpu_model "${_cpuinfo}")
      elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
         exec_program("/usr/sbin/sysctl -n machdep.cpu.vendor" OUTPUT_VARIABLE _vendor_id)
         exec_program("/usr/sbin/sysctl -n machdep.cpu.model"  OUTPUT_VARIABLE _cpu_model)
         exec_program("/usr/sbin/sysctl -n machdep.cpu.family" OUTPUT_VARIABLE _cpu_family)
      elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
         get_filename_component(_vendor_id "[HKEY_LOCAL_MACHINE\\Hardware\\Description\\System\\CentralProcessor\\0;VendorIdentifier]" NAME CACHE)
         get_filename_component(_cpu_id "[HKEY_LOCAL_MACHINE\\Hardware\\Description\\System\\CentralProcessor\\0;Identifier]" NAME CACHE)
         mark_as_advanced(_vendor_id _cpu_id)
         string(REGEX REPLACE ".* Family ([0-9]+) .*" "\\1" _cpu_family "${_cpu_id}")
         string(REGEX REPLACE ".* Model ([0-9]+) .*" "\\1" _cpu_model "${_cpu_id}")
      endif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
      if(_vendor_id STREQUAL "GenuineIntel")
         if(_cpu_family EQUAL 6)
            # Any recent Intel CPU except NetBurst
            if(_cpu_model EQUAL 46)     # Xeon 7500 series
               set(TARGET_ARCHITECTURE "westmere")
            elseif(_cpu_model EQUAL 45) # Xeon TNG
               set(TARGET_ARCHITECTURE "sandybridge")
            elseif(_cpu_model EQUAL 44) # Xeon 5600 series
               set(TARGET_ARCHITECTURE "westmere")
            elseif(_cpu_model EQUAL 42) # Core TNG
               set(TARGET_ARCHITECTURE "sandybridge")
            elseif(_cpu_model EQUAL 37) # Core i7/i5/i3
               set(TARGET_ARCHITECTURE "westmere")
            elseif(_cpu_model EQUAL 31) # Core i7/i5
               set(TARGET_ARCHITECTURE "westmere")
            elseif(_cpu_model EQUAL 30) # Core i7/i5
               set(TARGET_ARCHITECTURE "westmere")
            elseif(_cpu_model EQUAL 29)
               set(TARGET_ARCHITECTURE "penryn")
            elseif(_cpu_model EQUAL 28)
               set(TARGET_ARCHITECTURE "atom")
            elseif(_cpu_model EQUAL 26)
               set(TARGET_ARCHITECTURE "nehalem")
            elseif(_cpu_model EQUAL 23)
               set(TARGET_ARCHITECTURE "penryn")
            elseif(_cpu_model EQUAL 15)
               set(TARGET_ARCHITECTURE "merom")
            elseif(_cpu_model EQUAL 14)
               set(TARGET_ARCHITECTURE "core")
            elseif(_cpu_model LESS 14)
               message(WARNING "Your CPU (family ${_cpu_family}, model ${_cpu_model}) is not known. Auto-detection of optimization flags failed and will use the generic CPU settings with SSE2.")
               set(TARGET_ARCHITECTURE "generic")
            else()
               message(WARNING "Your CPU (family ${_cpu_family}, model ${_cpu_model}) is not known. Auto-detection of optimization flags failed and will use the 65nm Core 2 CPU settings.")
               set(TARGET_ARCHITECTURE "merom")
            endif()
         elseif(_cpu_family EQUAL 7) # Itanium (not supported)
            message(WARNING "Your CPU (Itanium: family ${_cpu_family}, model ${_cpu_model}) is not supported by OptimizeForArchitecture.cmake.")
         elseif(_cpu_family EQUAL 15) # NetBurst
            list(APPEND _available_vector_units_list "sse" "sse2")
            if(_cpu_model GREATER 2) # Not sure whether this must be 3 or even 4 instead
               list(APPEND _available_vector_units_list "sse" "sse2" "sse3")
            endif(_cpu_model GREATER 2)
         endif(_cpu_family EQUAL 6)
      elseif(_vendor_id STREQUAL "AuthenticAMD")
         if(_cpu_family EQUAL 16)
            set(TARGET_ARCHITECTURE "barcelona")
         elseif(_cpu_family EQUAL 15)
            set(TARGET_ARCHITECTURE "k8")
            if(_cpu_model GREATER 64) # I don't know the right number to put here. This is just a guess from the hardware I have access to
               set(TARGET_ARCHITECTURE "k8-sse3")
            endif(_cpu_model GREATER 64)
         endif(_cpu_family EQUAL 16)
      endif(_vendor_id STREQUAL "GenuineIntel")
   endif(TARGET_ARCHITECTURE STREQUAL "auto")

   if(TARGET_ARCHITECTURE STREQUAL "core")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3")
   elseif(TARGET_ARCHITECTURE STREQUAL "merom")
      list(APPEND _march_flag_list "merom")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3" "ssse3")
   elseif(TARGET_ARCHITECTURE STREQUAL "penryn")
      list(APPEND _march_flag_list "penryn")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3" "ssse3" "sse4.1")
   elseif(TARGET_ARCHITECTURE STREQUAL "nehalem")
      list(APPEND _march_flag_list "nehalem")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3" "ssse3" "sse4.1" "sse4.2")
   elseif(TARGET_ARCHITECTURE STREQUAL "westmere")
      list(APPEND _march_flag_list "westmere")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3" "ssse3" "sse4.1" "sse4.2")
   elseif(TARGET_ARCHITECTURE STREQUAL "sandy-bridge")
      list(APPEND _march_flag_list "sandybridge")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3" "ssse3" "sse4.1" "sse4.2" "avx")
   elseif(TARGET_ARCHITECTURE STREQUAL "atom")
      list(APPEND _march_flag_list "atom")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3" "ssse3")
   elseif(TARGET_ARCHITECTURE STREQUAL "k8")
      list(APPEND _march_flag_list "k8")
      list(APPEND _available_vector_units_list "sse" "sse2")
   elseif(TARGET_ARCHITECTURE STREQUAL "k8-sse3")
      list(APPEND _march_flag_list "k8-sse3")
      list(APPEND _march_flag_list "k8")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3")
   elseif(TARGET_ARCHITECTURE STREQUAL "barcelona")
      list(APPEND _march_flag_list "barcelona")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3" "sse4a")
   elseif(TARGET_ARCHITECTURE STREQUAL "istanbul")
      list(APPEND _march_flag_list "istanbul")
      list(APPEND _march_flag_list "barcelona")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3" "sse4a")
   elseif(TARGET_ARCHITECTURE STREQUAL "magny-cours")
      list(APPEND _march_flag_list "magnycours")
      list(APPEND _march_flag_list "istanbul")
      list(APPEND _march_flag_list "barcelona")
      list(APPEND _march_flag_list "core2")
      list(APPEND _available_vector_units_list "sse" "sse2" "sse3" "sse4a")
   elseif(TARGET_ARCHITECTURE STREQUAL "generic")
      list(APPEND _march_flag_list "generic")
   else(TARGET_ARCHITECTURE STREQUAL "core")
      message(FATAL_ERROR "Unknown target architecture: \"${TARGET_ARCHITECTURE}\". Please set TARGET_ARCHITECTURE to a supported value.")
   endif(TARGET_ARCHITECTURE STREQUAL "core")

   set(_disable_vector_unit_list)
   set(_enable_vector_unit_list)
   _my_find(_available_vector_units_list "sse2" SSE2_FOUND)
   _my_find(_available_vector_units_list "sse3" SSE3_FOUND)
   _my_find(_available_vector_units_list "ssse3" SSSE3_FOUND)
   _my_find(_available_vector_units_list "sse4.1" SSE4_1_FOUND)
   _my_find(_available_vector_units_list "sse4.2" SSE4_2_FOUND)
   _my_find(_available_vector_units_list "sse4a" SSE4a_FOUND)
   _my_find(_available_vector_units_list "avx" AVX_FOUND)
   set(USE_SSE2   ${SSE2_FOUND}   CACHE BOOL "Use SSE2. If SSE2 instructions are not enabled the SSE implementation will be disabled." ${_force})
   set(USE_SSE3   ${SSE3_FOUND}   CACHE BOOL "Use SSE3. If SSE3 instructions are not enabled they will be emulated." ${_force})
   set(USE_SSSE3  ${SSSE3_FOUND}  CACHE BOOL "Use SSSE3. If SSSE3 instructions are not enabled they will be emulated." ${_force})
   set(USE_SSE4_1 ${SSE4_1_FOUND} CACHE BOOL "Use SSE4.1. If SSE4.1 instructions are not enabled they will be emulated." ${_force})
   set(USE_SSE4_2 ${SSE4_2_FOUND} CACHE BOOL "Use SSE4.2. If SSE4.2 instructions are not enabled they will be emulated." ${_force})
   set(USE_SSE4a  ${SSE4a_FOUND}  CACHE BOOL "Use SSE4a. If SSE4a instructions are not enabled they will be emulated." ${_force})
   set(USE_AVX    ${AVX_FOUND}  CACHE BOOL "Use AVX. This will double some of the vector sizes relative to SSE." ${_force})
   mark_as_advanced(USE_SSE2 USE_SSE3 USE_SSSE3 USE_SSE4_1 USE_SSE4_2 USE_SSE4a USE_AVX)
   if(USE_SSE2)
      list(APPEND _enable_vector_unit_list "sse2")
   else(USE_SSE2)
      list(APPEND _disable_vector_unit_list "sse2")
   endif(USE_SSE2)
   if(USE_SSE3)
      list(APPEND _enable_vector_unit_list "sse3")
   else(USE_SSE3)
      list(APPEND _disable_vector_unit_list "sse3")
   endif(USE_SSE3)
   if(USE_SSSE3)
      list(APPEND _enable_vector_unit_list "ssse3")
   else(USE_SSSE3)
      list(APPEND _disable_vector_unit_list "ssse3")
   endif(USE_SSSE3)
   if(USE_SSE4_1)
      list(APPEND _enable_vector_unit_list "sse4.1")
   else(USE_SSE4_1)
      list(APPEND _disable_vector_unit_list "sse4.1")
   endif(USE_SSE4_1)
   if(USE_SSE4_2)
      list(APPEND _enable_vector_unit_list "sse4.2")
   else(USE_SSE4_2)
      list(APPEND _disable_vector_unit_list "sse4.2")
   endif(USE_SSE4_2)
   if(USE_SSE4a)
      list(APPEND _enable_vector_unit_list "sse4a")
   else(USE_SSE4a)
      list(APPEND _disable_vector_unit_list "sse4a")
   endif(USE_SSE4a)
   if(USE_AVX)
      list(APPEND _enable_vector_unit_list "avx")
   else(USE_AVX)
      list(APPEND _disable_vector_unit_list "avx")
   endif(USE_AVX)
   if(CMAKE_C_COMPILER MATCHES "cl(.exe)?$") # MSVC
      # MSVC on 32 bit can select only /arch:SSE2
      # MSVC on 64 bit cannot select anything
      if(NOT CMAKE_CL_64)
         _my_find(_enable_vector_unit_list "sse2")
         AddCompilerFlag("/arch:SSE2")
      endif(NOT CMAKE_CL_64)
      foreach(_flag ${_enable_vector_unit_list})
         string(TOUPPER "${_flag}" _flag)
         string(REPLACE "." "_" _flag "__${_flag}__")
         add_definitions("-D${_flag}")
      endforeach(_flag)
   elseif(CMAKE_CXX_COMPILER MATCHES "/(icpc|icc)$") # ICC
      _my_find(_available_vector_units_list "avx"    _found)
      if(_found)
         AddCompilerFlag("-xAVX")
      else(_found)
         _my_find(_available_vector_units_list "sse4.2" _found)
         if(_found)
            AddCompilerFlag("-xSSE4.2")
         else(_found)
            _my_find(_available_vector_units_list "sse4.1" _found)
            if(_found)
               AddCompilerFlag("-xSSE4.1")
            else(_found)
               _my_find(_available_vector_units_list "ssse3"  _found)
               if(_found)
                  AddCompilerFlag("-xSSSE3")
               else(_found)
                  _my_find(_available_vector_units_list "sse3"   _found)
                  if(_found)
                     # If the target host is an AMD machine then we still want to use -xSSE2 because the binary would refuse to run at all otherwise
                     _my_find(_march_flag_list "barcelona" _found)
                     if(NOT _found)
                        _my_find(_march_flag_list "k8-sse3" _found)
                     endif(NOT _found)
                     if(_found)
                        AddCompilerFlag("-xSSE2")
                     else(_found)
                        AddCompilerFlag("-xSSE3")
                     endif(_found)
                  else(_found)
                     _my_find(_available_vector_units_list "sse2"   _found)
                     if(_found)
                        AddCompilerFlag("-xSSE2")
                     endif(_found)
                  endif(_found)
               endif(_found)
            endif(_found)
         endif(_found)
      endif(_found)
   else(CMAKE_C_COMPILER MATCHES "cl(.exe)?$")
      foreach(_flag ${_march_flag_list})
         AddCompilerFlag("-march=${_flag}" _good)
         if(_good)
            break()
         endif(_good)
      endforeach(_flag)
      foreach(_flag ${_enable_vector_unit_list})
         AddCompilerFlag("-m${_flag}")
      endforeach(_flag)
      foreach(_flag ${_disable_vector_unit_list})
         AddCompilerFlag("-mno-${_flag}")
      endforeach(_flag)
      # Not really target architecture specific, but GCC 4.5.[01] fail at inlining some functions,
      # creating functions with a single instructions, thus a large overhead. This is a good
      # (because central) place to fix the problem
      if(CMAKE_COMPILER_IS_GNUCXX)
         exec_program(${CMAKE_C_COMPILER} ARGS -dumpversion OUTPUT_VARIABLE _gcc_version)
         macro_ensure_version("4.5.0" "${_gcc_version}" GCC_4_5_0)
         if(GCC_4_5_0)
            macro_ensure_version("4.5.2" "${_gcc_version}" GCC_4_5_2)
            if(NOT GCC_4_5_2)
               AddCompilerFlag("--param early-inlining-insns=12")
            endif(NOT GCC_4_5_2)
         endif(GCC_4_5_0)
      endif(CMAKE_COMPILER_IS_GNUCXX)
   endif(CMAKE_C_COMPILER MATCHES "cl(.exe)?$")
endmacro(OptimizeForArchitecture)
