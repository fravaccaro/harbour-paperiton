# Paperiton

A native [Paperless-ngx](https://docs.paperless-ngx.com/) client for Sailfish OS.

Paperiton talks to a Paperless-ngx server that you already run; it does not host
documents on the phone.

## Features

- Sign in with user name and password, with an API token, or through the web
  interface of the server, which also covers single sign-on and two-factor
  authentication; the token is kept in Sailfish Secrets
- Browse documents with infinite scrolling and thumbnails
- Full text search (`?query=`) with a debounced search field
- Filter by tag and by correspondent, and follow the saved views and the inbox
  of the server
- Document view with tags, correspondent, document type, archive serial number
  and the OCR text
- Edit title, correspondent, type, tags, date, archive serial number and custom
  fields; change tags, correspondent and type of several documents at once
- Read, write and delete notes
- Upload files from the device, from other apps through the share menu, and
  from the camera; the consumer task is followed until the document exists
- Watch the task queue of the server and acknowledge failures
- Open a document inside the app: it is downloaded into the private cache
  directory, which is emptied when the app closes and when you sign out.
  "Save on device" keeps a copy in `~/Downloads` or `~/Documents`, under a name
  you choose, and those are also the only places another application can read a
  document from
- Self-signed certificates can be accepted explicitly

## Requirements

- Sailfish OS 5.0 or newer (Sailfish Secrets is used for the API token)
- A reachable Paperless-ngx instance, API version 9 or newer

## Building

With the [Sailfish SDK](https://docs.sailfishos.org/Tools/Sailfish_SDK/Installation/):

```bash
sfdk config target SailfishOS-4.6.0.13-aarch64
sfdk cmake -B build -S .
sfdk cmake --build build
sfdk rpm
```

Deploy to a connected device:

```bash
sfdk config device "My Phone"
sfdk deploy --sdk
```

RPMs for armv7hl and aarch64 are also built by the GitHub Actions workflow in
`.github/workflows/build.yml`.

`sfdk check` reports one error, `Import 'Sailfish.Office 1.0' is not allowed`.
That import is the viewer of the Documents application, without which a
document in the private cache directory cannot be shown at all, so the package
is meant for Chum and OpenRepos rather than the Jolla Store.

## Architecture

| Part | Purpose |
|---|---|
| `src/paperless/config.*` | Server URL, user name and TLS preference in `~/.config/org.frapps.paperiton/harbour-paperiton/settings.conf` |
| `src/paperless/secretsstore.*` | The API token in Sailfish Secrets, with migration of tokens written by version 0.1 |
| `src/paperless/api.*` | `QNetworkAccessManager` wrapper: token header, redirect retries, timeouts, downloads, uploads, permission probe |
| `src/paperless/documentlistmodel.*` | Paginated list model for `/api/documents/` |
| `src/paperless/lookupmodel.*` | Tags, correspondents and document types by id |
| `src/paperless/customfieldsmodel.*` | The custom fields defined on the server |
| `src/paperless/savedviewmodel.*` | Saved views, translated into query parameters |
| `src/paperless/uploadqueue.*` | Multipart uploads and polling of the consumer task |
| `src/paperless/tasklistmodel.*` | `/api/tasks/` and acknowledging failures |
| `src/paperless/thumbimageprovider.*` | `image://paperless/thumb/<id>` and `image://paperless/preview/<id>` |
| `qml/pages/*` | Silica UI |

Networking lives in C++ because the Paperless endpoints for thumbnails and
previews need an `Authorization: Token …` header, which QML's `Image` cannot
send. All API paths keep their trailing slash: Django redirects slash-less URLs
and the redirect drops the authorization header.

Sailjail gives the app three private directories, named after the
`OrganizationName` and `ApplicationName` of the desktop file:
`~/.config/org.frapps.paperiton/harbour-paperiton` for the settings,
`~/.cache/org.frapps.paperiton/harbour-paperiton` for thumbnails, downloaded
documents, camera captures and the web view profile, and the matching
`~/.local/share` directory, which is unused. No other application can read
these paths, so documents are shown by `qml/pages/PdfViewPage.qml`, which wraps
the viewer of the Documents application, and by `qml/pages/ImageViewPage.qml`.
When that viewer is missing, the app falls back to a copy in `~/Downloads`.
`documents/` and `captures/` are removed when the app starts and when it quits,
and signing out removes the whole cache.

## Permissions

`Internet` for the API, `Downloads` and `Documents` for keeping a copy of a
document where another application can open it and for picking files to upload,
`Pictures` for pictures to upload, `Camera` for scanning, `Secrets` for the API
token and `WebView` for signing in through the web interface of the server.

## Licence

GPL-3.0-only
