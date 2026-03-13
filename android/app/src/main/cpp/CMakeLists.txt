cmake_minimum_required(VERSION 3.10)
project(ncnn_bridge C CXX)

# Only build for ABIs where we have NCNN prebuilt library
set(NCNN_LIB "${CMAKE_CURRENT_SOURCE_DIR}/ncnn/${ANDROID_ABI}/libncnn.a")

if(EXISTS ${NCNN_LIB})
    add_library(ncnn STATIC IMPORTED)
    set_target_properties(ncnn PROPERTIES
        IMPORTED_LOCATION ${NCNN_LIB})

    # Bridge shared library
    add_library(ncnn_bridge SHARED ncnn_bridge.c)
    set_target_properties(ncnn_bridge PROPERTIES LINKER_LANGUAGE CXX)

    target_include_directories(ncnn_bridge PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/ncnn/include)

    target_link_libraries(ncnn_bridge
        ncnn
        android
        log
        -fopenmp
        -static-openmp)
else()
    # Create a stub library for unsupported ABIs
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/stub.c "")
    add_library(ncnn_bridge SHARED ${CMAKE_CURRENT_BINARY_DIR}/stub.c)
    target_link_libraries(ncnn_bridge android log)
endif()
