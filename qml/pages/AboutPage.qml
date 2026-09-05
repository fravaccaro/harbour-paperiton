import Opal.About 1.0 as A
import QtQuick 2.0
import Sailfish.Silica 1.0 as S

A.AboutPageBase {
    id: page

    allowedOrientations: S.Orientation.All
    appName: "Paperiton"
    appIcon: Qt.resolvedUrl("../../appicon.png")
    appVersion: Qt.application.version
    description: qsTr("A client for the documents of a Paperless-ngx server: search, " + "filters, previews, uploads from the device or the camera, " + "metadata, notes and the task queue.")
    authors: ["fravaccaro"]
    homepageUrl: "https://fravaccaro.github.io/paperiton/"
    sourcesUrl: "https://github.com/fravaccaro/harbour-paperiton"
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
            text: qsTr("If you want to provide feedback or report an issue, please use GitHub.")
            buttons: [
                A.InfoButton {
                    text: qsTr("Report an issue")
                    onClicked: openOrCopyUrl("https://github.com/fravaccaro/harbour-paperiton/issues", text)
                }
            ]
        },
        A.InfoSection {
            title: qsTr("Translations")
            text: qsTr("Credits for existing translations and how to contribute.")
            buttons: [
                A.InfoButton {
                    text: qsTr("Translations")
                    onClicked: pageStack.push(Qt.resolvedUrl("TranslationsPage.qml"))
                }
            ]
        },
        A.InfoSection {
            title: "Paperless-ngx"
            text: qsTr("Paperless-ngx is a separate project and is not affiliated with " + "this app.")
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
