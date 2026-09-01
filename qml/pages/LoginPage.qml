import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property bool tokenMode: false
    property bool signingIn: false
    property string errorMessage

    property var providers: []
    property bool passwordSignIn: true
    property bool optionsKnown: false

    allowedOrientations: Orientation.All

    function detectOptions() {
        page.optionsKnown = false
        Paperless.detectSignInOptions(serverField.text)
    }

    function signIn() {
        errorMessage = ""
        signingIn = true
        if (tokenMode)
            Paperless.loginWithToken(serverField.text, tokenField.text)
        else
            Paperless.login(serverField.text, usernameField.text, passwordField.text)
    }

    function openInBrowser() {
        var url = Settings.normalizeServerUrl(serverField.text)
        if (url !== "")
            Qt.openUrlExternally(url)
    }

    function signInWithWebView() {
        var url = Settings.normalizeServerUrl(serverField.text)
        if (url !== "")
            pageStack.push(Qt.resolvedUrl("WebLoginPage.qml"), { serverUrl: url })
    }

    Component.onCompleted: {
        if (serverField.text.trim() !== "")
            page.detectOptions()
    }

    Connections {
        target: Paperless

        onSignInOptionsDetected: {
            page.providers = providers
            page.passwordSignIn = passwordSignIn
            page.optionsKnown = true
            if (!passwordSignIn)
                page.tokenMode = true
        }

        onLoginSucceeded: {
            page.signingIn = false
            pageStack.replaceAbove(null, Qt.resolvedUrl("DocumentsPage.qml"))
            app.takePendingShare()
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
                    page.detectOptions()
                    if (page.tokenMode)
                        tokenField.focus = true
                    else
                        usernameField.focus = true
                }
                onActiveFocusChanged: {
                    if (!activeFocus && text.trim() !== "")
                        page.detectOptions()
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.providers.length > 0
                wrapMode: Text.WordWrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("This server signs in with %1.").arg(page.providers.join(", "))
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.optionsKnown && (page.providers.length > 0 || !page.passwordSignIn
                                               || page.tokenMode)
                enabled: serverField.text.trim() !== ""
                text: qsTr("Sign in with the web interface")
                onClicked: page.signInWithWebView()
            }

            TextField {
                id: usernameField
                width: parent.width
                visible: !page.tokenMode && page.passwordSignIn
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
                visible: !page.tokenMode && page.passwordSignIn
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

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.tokenMode
                enabled: serverField.text.trim() !== ""
                text: qsTr("Open the web interface")
                onClicked: page.openInBrowser()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.tokenMode
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Sign in there the way you normally do, also with single sign-on or "
                           + "two-factor authentication, then copy the API token from your profile.")
            }

            TextSwitch {
                text: qsTr("Use an API token")
                description: qsTr("Create one in the Paperless web interface under My Profile.")
                visible: page.passwordSignIn
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
                visible: page.passwordSignIn || page.tokenMode
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
