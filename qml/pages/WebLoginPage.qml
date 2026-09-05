import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0

// Signs in through the web interface of the server, so that single sign-on and
// two-factor authentication work, and asks Paperless for an API token once the
// session exists.
Page {
    // The web view turns an injected script into the body of a function, so a
    // script that does not return says nothing back, whatever it evaluates to.
    // Both of these answer with "token:", "none:" or "failed:" and a reason.

    id: page

    property string serverUrl
    property bool minting: false
    property bool done: false
    property string errorMessage
    // The account already has a token in almost every case, and taking that one
    // leaves tokens used elsewhere alone.
    readonly property string readScript: "return (function() {" + "  try {" + "    var request = new XMLHttpRequest();" + "    request.open('GET', '/api/profile/', false);" + "    request.setRequestHeader('Accept', 'application/json');" + "    request.send();" + "    if (request.status !== 200) return 'failed:' + request.status;" + "    var token = JSON.parse(request.responseText).auth_token;" + "    return token ? 'token:' + token : 'none:';" + "  } catch (error) {" + "    return 'failed:' + error;" + "  }" + "})()"
    // For an account that has none yet. This one replaces any earlier token,
    // which is why it is only asked for when there is nothing to replace.
    readonly property string createScript: "return (function() {" + "  try {" + "    var match = document.cookie.match(/(^|;)\\s*csrftoken\\s*=\\s*([^;]+)/);" + "    var request = new XMLHttpRequest();" + "    request.open('POST', '/api/profile/generate_auth_token/', false);" + "    if (match) request.setRequestHeader('X-CSRFToken', match[2]);" + "    request.setRequestHeader('Accept', 'application/json');" + "    request.send();" + "    if (request.status !== 200) return 'failed:' + request.status;" + "    var token = JSON.parse(request.responseText);" + "    if (typeof token !== 'string') token = token.token || '';" + "    return token ? 'token:' + token : 'none:';" + "  } catch (error) {" + "    return 'failed:' + error;" + "  }" + "})()"

    function signedIn(url) {
        var path = url.toString().substring(page.serverUrl.length);
        return url.toString().indexOf(page.serverUrl) === 0 && path.indexOf("/accounts/") !== 0;
    }

    function collectToken() {
        if (page.minting || page.done)
            return ;

        page.minting = true;
        webview.runJavaScript(page.readScript, page.tokenRead, page.scriptFailed);
    }

    function tokenRead(result) {
        var answer = String(result);
        if (answer.indexOf("none:") === 0) {
            webview.runJavaScript(page.createScript, page.tokenReceived, page.scriptFailed);
            return ;
        }
        page.tokenReceived(answer);
    }

    function tokenReceived(result) {
        var answer = String(result);
        page.minting = false;
        if (answer.indexOf("token:") === 0) {
            page.done = true;
            Paperless.loginWithToken(page.serverUrl, answer.substring(6));
            return ;
        }
        if (answer.indexOf("none:") === 0) {
            page.errorMessage = qsTr("The server did not return an API token.");
            return ;
        }
        page.errorMessage = qsTr("The server refused to create a token (%1).").arg(answer.replace("failed:", ""));
    }

    function scriptFailed(error) {
        page.minting = false;
        page.errorMessage = qsTr("The server could not be asked for a token.");
        console.warn("token script failed:", error);
    }

    allowedOrientations: Orientation.All

    Connections {
        target: Paperless
        onLoginSucceeded: {
            pageStack.replaceAbove(null, Qt.resolvedUrl("DocumentsPage.qml"));
            app.takePendingUpload();
        }
        onLoginFailed: {
            page.done = false;
            page.errorMessage = error;
        }
    }

    WebView {
        id: webview

        url: page.serverUrl + "/accounts/login/?next=/"
        active: true
        onUrlChanged: {
            if (page.signedIn(url))
                page.errorMessage = "";

        }
        onLoadingChanged: {
            if (!loading && page.signedIn(url))
                page.collectToken();

        }

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: footer.top
        }

    }

    // Once the session exists the server sends its own web interface, which is
    // written for a newer browser than this one and shows nothing but a blank
    // page here. There is nothing left to do in it anyway.
    Rectangle {
        anchors.fill: webview
        color: Theme.overlayBackgroundColor
        visible: page.signedIn(webview.url)
    }

    Column {
        id: footer

        spacing: Theme.paddingSmall

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSizeExtraSmall
            color: page.errorMessage !== "" ? Theme.errorColor : Theme.secondaryColor
            text: {
                if (page.errorMessage !== "")
                    return page.errorMessage;

                if (page.minting)
                    return qsTr("Asking the server for an API token…");

                return qsTr("Sign in as you would in a browser. Paperiton then takes the API token " + "of your account from the server.");
            }
        }

        Item {
            width: parent.width
            height: Theme.paddingMedium
        }

    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: page.minting
    }

}
