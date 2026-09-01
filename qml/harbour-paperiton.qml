import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow {
    id: app

    initialPage: Paperless.authenticated ? documentsPage : loginPage
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    Component {
        id: documentsPage
        DocumentsPage {}
    }

    Component {
        id: loginPage
        LoginPage {}
    }

    Connections {
        target: Paperless
        onAuthenticatedChanged: {
            if (!Paperless.authenticated)
                pageStack.replaceAbove(null, loginPage)
        }
    }
}
