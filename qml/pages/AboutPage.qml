import QtQuick 2.0
import Sailfish.Silica 1.0 as S
import Opal.About 1.0 as A

A.AboutPageBase {
    id: page

    readonly property string repository: "https://github.com/fravaccaro/harbour-paperiton"

    allowedOrientations: S.Orientation.All

    appName: "Paperiton"
    appIcon: Qt.resolvedUrl("../../appicon.png")
    appVersion: Qt.application.version
    description: qsTr("A client for the documents of a Paperless-ngx server: search, "
                      + "filters, previews, uploads from the device or the camera, "
                      + "metadata, notes and the task queue.")
    authors: ["fravaccaro"]
    sourcesUrl: page.repository
    translationsUrl: "https://explore.transifex.com/fravaccaro/paperiton"

    donations.text: donations.defaultTextCoffee
    donations.services: [
        A.DonationService {
            name: "Liberapay"
            url: "https://liberapay.com/fravaccaro"
        }
    ]

    extraSections: [
        A.InfoSection {
            title: qsTr("Feedback")
            text: qsTr("Questions, ideas and reports of what went wrong are welcome.")
            buttons: [
                A.InfoButton {
                    text: qsTr("Report an issue")
                    onClicked: openOrCopyUrl(page.repository + "/issues", text)
                }
            ]
        },
        A.InfoSection {
            title: qsTr("Translations")
            text: qsTr("Who translated the app, and how to add your own language.")
            buttons: [
                A.InfoButton {
                    text: qsTr("Translations")
                    onClicked: pageStack.push(Qt.resolvedUrl("TranslationsPage.qml"))
                }
            ]
        },
        A.InfoSection {
            title: "Paperless-ngx"
            text: qsTr("Paperless-ngx is a separate project and is not affiliated with "
                       + "this app.")
            buttons: [
                A.InfoButton {
                    text: qsTr("About Paperless-ngx")
                    onClicked: openOrCopyUrl("https://docs.paperless-ngx.com", text)
                }
            ]
        }
    ]

    licenses: A.License {
        spdxId: "GPL-3.0-or-later"
    }
}
