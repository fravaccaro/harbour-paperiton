cmake_minimum_required(VERSION 3.5)
project(harbour-paperiton CXX)

find_package(Qt5 COMPONENTS Core Network Qml Gui Quick LinguistTools REQUIRED)

# The packaged version, so that the About page cannot drift from what was built.
# Building outside the spec still has to produce something, hence the fallback.
if(NOT APP_VERSION)
    set(APP_VERSION "0.0-devel")
endif()

include(FindPkgConfig)
pkg_search_module(SAILFISH sailfishapp REQUIRED)
pkg_search_module(SAILFISHSECRETS sailfishsecrets REQUIRED)

set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(harbour-paperiton
    src/main.cpp
    src/paperless/config.h
    src/paperless/config.cpp
    src/paperless/api.h
    src/paperless/api.cpp
    src/paperless/documentlistmodel.h
    src/paperless/documentlistmodel.cpp
    src/paperless/lookupmodel.h
    src/paperless/lookupmodel.cpp
    src/paperless/thumbimageprovider.h
    src/paperless/thumbimageprovider.cpp
    src/paperless/secretsstore.h
    src/paperless/secretsstore.cpp
    src/paperless/uploadqueue.h
    src/paperless/uploadqueue.cpp
    src/paperless/tasklistmodel.h
    src/paperless/tasklistmodel.cpp
    src/paperless/customfieldsmodel.h
    src/paperless/customfieldsmodel.cpp
    src/paperless/savedviewmodel.h
    src/paperless/savedviewmodel.cpp
    src/paperless/staleness.h
)

target_compile_definitions(harbour-paperiton PRIVATE
    $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>
    APP_VERSION="${APP_VERSION}"
)
target_include_directories(harbour-paperiton PRIVATE
    ${SAILFISH_INCLUDE_DIRS}
    ${SAILFISHSECRETS_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)
target_link_libraries(harbour-paperiton
    Qt5::Quick
    Qt5::Network
    ${SAILFISH_LDFLAGS}
    ${SAILFISHSECRETS_LDFLAGS}
)

FILE(GLOB TsFiles "${CMAKE_CURRENT_SOURCE_DIR}/translations/*.ts")
qt5_add_translation(QmFiles ${TsFiles})
add_custom_target(translations ALL DEPENDS ${QmFiles})

install(TARGETS harbour-paperiton RUNTIME DESTINATION bin)
install(DIRECTORY qml DESTINATION share/harbour-paperiton)
install(FILES ${QmFiles} DESTINATION share/harbour-paperiton/translations)
install(FILES harbour-paperiton.desktop DESTINATION share/applications)
install(FILES icons/86x86/harbour-paperiton.png   DESTINATION share/icons/hicolor/86x86/apps)
install(FILES icons/108x108/harbour-paperiton.png DESTINATION share/icons/hicolor/108x108/apps)
install(FILES icons/128x128/harbour-paperiton.png DESTINATION share/icons/hicolor/128x128/apps)
install(FILES icons/172x172/harbour-paperiton.png DESTINATION share/icons/hicolor/172x172/apps)

add_custom_target(distfiles
    SOURCES
        harbour-paperiton.desktop
        qml/harbour-paperiton.qml
        qml/cover/CoverPage.qml
        qml/cover/cover-tag.png
        qml/pages/AboutPage.qml
        qml/pages/BulkEditPage.qml
        qml/pages/CameraPage.qml
        qml/pages/DocumentEditPage.qml
        qml/pages/DocumentPage.qml
        qml/pages/DocumentsPage.qml
        qml/pages/FilterPage.qml
        qml/pages/ImageViewPage.qml
        qml/pages/LoginPage.qml
        qml/pages/LookupPickerPage.qml
        qml/pages/NotesPage.qml
        qml/pages/PdfViewPage.qml
        qml/pages/SavePage.qml
        qml/pages/SettingsPage.qml
        qml/pages/StartPage.qml
        qml/pages/TasksPage.qml
        qml/pages/UploadPage.qml
        qml/pages/WebLoginPage.qml
        rpm/harbour-paperiton.changes.in
        rpm/harbour-paperiton.changes.run.in
        rpm/harbour-paperiton.spec
        ${TsFiles})
