import QtQuick 2.0
import Sailfish.Silica 1.0

// Signing in is accepted from the header, and the waiting for the server
// happens on the page the accept leads to. This one stays underneath it, which
// is what lets the form come back as it was typed when the server says no.
Dialog {
    id: page

    // The three ways in, one at a time: a user name and password, a token
    // pasted in, or the web interface of the server inside the app.
    property bool tokenMode: false
    property bool webMode: false
    property bool signingIn: false
    property bool signedIn: false
    property string errorMessage
    property var providers: []
    property bool passwordSignIn: true
    property bool optionsKnown: false

    function detectOptions() {
        page.optionsKnown = false;
        Paperless.detectSignInOptions(serverField.text);
    }

    function signIn() {
        errorMessage = "";
        signingIn = true;
        if (tokenMode)
            Paperless.loginWithToken(serverField.text, tokenField.text);
        else
            Paperless.login(serverField.text, usernameField.text, passwordField.text);
    }

    function openInBrowser() {
        var url = Settings.normalizeServerUrl(serverField.text);
        if (url !== "")
            Qt.openUrlExternally(url);

    }

    function signInWithWebView() {
        var url = Settings.normalizeServerUrl(serverField.text);
        if (url !== "")
            pageStack.push(Qt.resolvedUrl("WebLoginPage.qml"), {
            "serverUrl": url
        });

    }

    // The server can answer while the waiting page is still animating in, and
    // the stack refuses to be changed in the middle of that, so the answer is
    // acted on once it is idle: the archive takes over the stack, or this form
    // comes back with what went wrong.
    function settle() {
        if (pageStack.busy) {
            settleAgain.restart();
            return ;
        }
        if (page.signedIn) {
            pageStack.replaceAbove(null, Qt.resolvedUrl("DocumentsPage.qml"));
            app.takePendingUpload();
            return ;
        }
        pageStack.pop(page);
    }

    allowedOrientations: Orientation.All
    // The web interface signs in on its own page, so there the header has
    // nothing to accept.
    canAccept: !page.signingIn && !page.webMode && serverField.text.trim() !== "" && (page.tokenMode ? tokenField.text.trim() !== "" : usernameField.text.trim() !== "" && passwordField.text !== "")
    acceptDestination: Qt.resolvedUrl("StartPage.qml")
    acceptDestinationAction: PageStackAction.Push
    onAccepted: page.signIn()
    Component.onCompleted: {
        if (serverField.text.trim() !== "")
            page.detectOptions();

    }

    Timer {
        id: settleAgain

        interval: 100
        onTriggered: page.settle()
    }

    Connections {
        target: Paperless
        onSignInOptionsDetected: {
            page.providers = providers;
            page.passwordSignIn = passwordSignIn;
            page.optionsKnown = true;
            // A server that has turned password sign-in off leaves the token
            // and the web interface, so one of the two has to be chosen.
            if (!passwordSignIn && !page.webMode)
                page.tokenMode = true;

        }
        onLoginSucceeded: {
            page.signingIn = false;
            page.signedIn = true;
            page.settle();
        }
        onLoginFailed: {
            page.signingIn = false;
            page.signedIn = false;
            page.errorMessage = error;
            page.settle();
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
                title: "Paperiton"
                acceptText: qsTr("Sign in")
                cancelText: ""
            }

            Item {
                height: appicon.height + Theme.paddingMedium
                width: parent.width

                Image {
                    id: appicon

                    width: 256
                    height: width
                    fillMode: Image.PreserveAspectFit
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
                    page.detectOptions();
                    if (page.tokenMode)
                        tokenField.focus = true;
                    else if (!page.webMode && page.passwordSignIn)
                        usernameField.focus = true;
                    else
                        focus = false;
                }
                onActiveFocusChanged: {
                    if (!activeFocus && text.trim() !== "")
                        page.detectOptions();

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

            TextField {
                id: usernameField

                width: parent.width
                visible: !page.tokenMode && !page.webMode && page.passwordSignIn
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
                visible: !page.tokenMode && !page.webMode && page.passwordSignIn
                label: qsTr("Password")
                placeholderText: qsTr("Password")
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    focus = false;
                    if (page.canAccept)
                        page.accept();

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
                    focus = false;
                    if (page.canAccept)
                        page.accept();

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
                text: qsTr("Sign in there the way you normally do, also with single sign-on or " + "two-factor authentication, then copy the API token from your profile.")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.webMode
                enabled: serverField.text.trim() !== ""
                text: qsTr("Sign in via the web interface")
                onClicked: page.signInWithWebView()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.webMode
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("The server opens inside the app. Paperiton takes the API token of your " + "account once you are signed in.")
            }

            // Each switch shows the mode rather than keeping a state of its
            // own, so turning one on shows on the other as well. On a server
            // that has password sign-in turned off, the way in that is on
            // cannot be turned off, only exchanged for the other one.
            TextSwitch {
                text: qsTr("Use an API token")
                description: qsTr("Create one in the Paperless web interface under My Profile.")
                automaticCheck: false
                checked: page.tokenMode
                enabled: page.passwordSignIn || !page.tokenMode
                onClicked: {
                    page.tokenMode = !page.tokenMode;
                    if (page.tokenMode)
                        page.webMode = false;

                }
            }

            TextSwitch {
                text: qsTr("Use the web interface")
                description: qsTr("For single sign-on and two-factor authentication.")
                automaticCheck: false
                checked: page.webMode
                enabled: page.passwordSignIn || !page.webMode
                onClicked: {
                    page.webMode = !page.webMode;
                    if (page.webMode)
                        page.tokenMode = false;

                }
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

        VerticalScrollDecorator {
        }

    }

}
