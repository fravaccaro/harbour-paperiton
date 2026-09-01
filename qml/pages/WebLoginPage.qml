import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0

// Signs in through the web interface of the server, so that single sign-on and
// two-factor authentication work, and asks Paperless for an API token once the
// session exists.
Page {
    id: page

    property string serverUrl

    property bool minting: false
    property bool done: false
    property string errorMessage

    allowedOrientations: Orientation.All

    function signedIn(url) {
        var path = url.toString().substring(page.serverUrl.length)
        return url.toString().indexOf(page.serverUrl) === 0
                && path.indexOf("/accounts/") !== 0
    }

    function mintToken() {
        if (page.minting || page.done)
            return

        page.minting = true
        webview.runJavaScript(
                    "(function() {"
                    + "  try {"
                    + "    var match = document.cookie.match(/(^|;)\\s*csrftoken\\s*=\\s*([^;]+)/);"
                    + "    var request = new XMLHttpRequest();"
                    + "    request.open('POST', '/api/profile/generate_auth_token/', false);"
                    + "    if (match) request.setRequestHeader('X-CSRFToken', match[2]);"
                    + "    request.setRequestHeader('Accept', 'application/json');"
                    + "    request.send();"
                    + "    return request.status + ' ' + request.responseText;"
                    + "  } catch (error) {"
                    + "    return '0 ' + error;"
                    + "  }"
                    + "})()",
                    function(result) {
                        page.minting = false
                        page.handleResult(String(result))
                    })
    }

    function handleResult(result) {
        var separator = result.indexOf(" ")
        var status = parseInt(result.substring(0, separator), 10)
        var body = result.substring(separator + 1)

        if (status !== 200) {
            page.errorMessage = status === 0
                    ? qsTr("The server could not be asked for a token.")
                    : qsTr("The server refused to create a token (%1).").arg(status)
            return
        }

        var token = ""
        try {
            var parsed = JSON.parse(body)
            token = typeof parsed === "string" ? parsed : (parsed.token || "")
        } catch (error) {
            token = body.replace(/^"|"$/g, "")
        }

        if (token === "") {
            page.errorMessage = qsTr("The server did not return an API token.")
            return
        }

        page.done = true
        Paperless.loginWithToken(page.serverUrl, token)
    }

    Connections {
        target: Paperless

        onLoginSucceeded: {
            pageStack.replaceAbove(null, Qt.resolvedUrl("DocumentsPage.qml"))
            app.takePendingShare()
        }

        onLoginFailed: {
            page.done = false
            page.errorMessage = error
        }
    }

    WebView {
        id: webview

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: footer.top
        }
        url: page.serverUrl + "/accounts/login/?next=/"
        active: true

        onUrlChanged: {
            if (page.signedIn(url))
                page.errorMessage = ""
        }

        onLoadingChanged: {
            if (!loading && page.signedIn(url))
                page.mintToken()
        }
    }

    Column {
        id: footer

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        spacing: Theme.paddingSmall

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSizeExtraSmall
            color: page.errorMessage !== "" ? Theme.errorColor : Theme.secondaryColor
            text: {
                if (page.errorMessage !== "")
                    return page.errorMessage
                if (page.minting)
                    return qsTr("Asking the server for an API token…")
                return qsTr("Sign in as you would in a browser. Paperiton then asks the server for an "
                            + "API token, which replaces any token you created earlier.")
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
