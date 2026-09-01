import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property bool tokenMode: false
    property bool signingIn: false
    property string errorMessage

    allowedOrientations: Orientation.All

    function signIn() {
        errorMessage = ""
        signingIn = true
        if (tokenMode)
            Paperless.loginWithToken(serverField.text, tokenField.text)
        else
            Paperless.login(serverField.text, usernameField.text, passwordField.text)
    }

    Connections {
        target: Paperless

        onLoginSucceeded: {
            page.signingIn = false
            pageStack.replaceAbove(null, Qt.resolvedUrl("DocumentsPage.qml"))
        }

        onLoginFailed: {
            page.signingIn = false
            page.errorMessage = error
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge
        enabled: !page.signingIn
        opacity: page.signingIn ? Theme.opacityLow : 1.0
        Behavior on opacity { FadeAnimation {} }

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("Sign in") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Paperiton connects to a Paperless-ngx server that you already run.")
            }

            TextField {
                id: serverField
                width: parent.width
                text: Settings.serverUrl
                label: qsTr("Server address")
                placeholderText: qsTr("https://paperless.example.org")
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: {
                    if (page.tokenMode)
                        tokenField.focus = true
                    else
                        usernameField.focus = true
                }
            }

            TextField {
                id: usernameField
                width: parent.width
                visible: !page.tokenMode
                text: Settings.username
                label: qsTr("User name")
                placeholderText: qsTr("User name")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: passwordField.focus = true
            }

            PasswordField {
                id: passwordField
                width: parent.width
                visible: !page.tokenMode
                label: qsTr("Password")
                placeholderText: qsTr("Password")
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: page.signIn()
            }

            TextField {
                id: tokenField
                width: parent.width
                visible: page.tokenMode
                label: qsTr("API token")
                placeholderText: qsTr("API token")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: page.signIn()
            }

            TextSwitch {
                text: qsTr("Use an API token")
                description: qsTr("Create one in the Paperless web interface under My Profile.")
                checked: page.tokenMode
                onClicked: page.tokenMode = checked
            }

            TextSwitch {
                text: qsTr("Ignore certificate errors")
                description: qsTr("Only for a server with a self-signed certificate on your own network.")
                checked: Settings.ignoreSslErrors
                onClicked: Settings.ignoreSslErrors = checked
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.errorMessage !== ""
                wrapMode: Text.WordWrap
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.errorMessage
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Sign in")
                enabled: serverField.text.trim() !== ""
                onClicked: page.signIn()
            }
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: page.signingIn
    }
}
