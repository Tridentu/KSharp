macro(ksharp_generate_cpp FILENAME)
    get_filename_component(BASE_NAME ${FILENAME} NAME_WE)
    set(HEADER_OUT "${CMAKE_CURRENT_BINARY_DIR/${BASE_NAME}.h")
    set(SOURCE_OUT "${CMAKE_CURRENT_BINARY_DIR/${BASE_NAME}.cpp")

    add_custom_command(
        OUTPUT ${HEADER_OUT} ${SOURCE_OUT}
        COMMAND ksharp ${CMAKE_CURRENT_SOURCE_DIR}/${FILENAME}
        DEPENDS ${FILENAME} ksharp
        COMMENT "Transpiling K# source: ${FILENAME}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )

    list(APPEND KSHARP_GENERATED_SOURCES ${SOURCE_OUT})
    include_directories(${CMAKE_CURRENT_BINARY_DIR})
endmacro()
