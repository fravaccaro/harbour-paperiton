import QtQuick 2.0
import Sailfish.Silica 1.0

// Signing in is accepted from the header, and the waiting for the server
// happens on the page the accept leads to. This one stays underneath it, which
// is what lets the form come back as it was typed when the server says no.
Dialog {
    id: page

    property bool tokenMode: false
    property bool signingIn: false
    property bool signedIn: false
    property string errorMessage

    property var providers: []
    property bool passwordSignIn: true
    property bool optionsKnown: false

    allowedOrientations: Orientation.All

    canAccept: !page.signingIn && serverField.text.trim() !== ""
               && (page.tokenMode
                   ? tokenField.text.trim() !== ""
                   : usernameField.text.trim() !== "" && passwordField.text !== "")
    acceptDestination: Qt.resolvedUrl("StartPage.qml")
    acceptDestinationAction: PageStackAction.Push

    onAccepted: page.signIn()

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

    // The server can answer while the waiting page is still animating in, and
    // the stack refuses to be changed in the middle of that, so the answer is
    // acted on once it is idle: the archive takes over the stack, or this form
    // comes back with what went wrong.
    function settle() {
        if (pageStack.busy) {
            settleAgain.restart()
            return
        }

        if (page.signedIn) {
            pageStack.replaceAbove(null, Qt.resolvedUrl("DocumentsPage.qml"))
            app.takePendingUpload()
            return
        }

        pageStack.pop(page)
    }

    Timer {
        id: settleAgain
        interval: 100
        onTriggered: page.settle()
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
            page.signedIn = true
            page.settle()
        }

        onLoginFailed: {
            page.signingIn = false
            page.signedIn = false
            page.errorMessage = error
            page.settle()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: qsTr("Sign in")
                acceptText: qsTr("Sign in")
                cancelText: ""
            }

                    Item {
                        height: appicon.height + Theme.paddingMedium
                        width: parent.width

                        Image {
                            id: appicon

                            anchors.horizontalCenter: parent.horizontalCenter
                            source: "../../appicon.png"
                        }

                    }
                    
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
                EnterKey.onClicked: {
                    focus = false
                    if (page.canAccept)
                        page.accept()
                }
            }

            TextField {
                id: tokenField
                width: parent.width
                visible: page.tokenMode
                label: qsTr("API token")
                placeholderText: qsTr("API token")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    focus = false
                    if (page.canAccept)
                        page.accept()
                }
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
        }

        VerticalScrollDecorator {}
    }
}
