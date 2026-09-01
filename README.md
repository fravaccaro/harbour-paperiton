# Paperiton

A native [Paperless-ngx](https://docs.paperless-ngx.com/) client for Sailfish OS.

Paperiton talks to a Paperless-ngx server that you already run; it does not host
documents on the phone. Version 0.1 is a read-only client.

## Features

- Sign in with user name and password, or with an API token
- Browse documents with infinite scrolling and thumbnails
- Full text search (`?query=`) with a debounced search field
- Filter by tag and by correspondent
- Document view with tags, correspondent, document type, archive serial number
  and the OCR text
- Open a document in another app; the file is downloaded to `~/Downloads`
- Self-signed certificates can be accepted explicitly

## Requirements

- Sailfish OS 4.4 or newer (Sailjail)
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

## Architecture

| Part | Purpose |
|---|---|
| `src/paperless/config.*` | Server URL, user name, API token and TLS preference in `~/.config/org.fravaccaro/harbour-paperiton/settings.conf` |
| `src/paperless/api.*` | `QNetworkAccessManager` wrapper: token header, redirect retries, timeouts, downloads |
| `src/paperless/documentlistmodel.*` | Paginated list model for `/api/documents/` |
| `src/paperless/lookupmodel.*` | Tags, correspondents and document types by id |
| `src/paperless/thumbimageprovider.*` | `image://paperless/thumb/<id>` and `image://paperless/preview/<id>` |
| `qml/pages/*` | Silica UI |

Networking lives in C++ because the Paperless endpoints for thumbnails and
previews need an `Authorization: Token …` header, which QML's `Image` cannot
send. All API paths keep their trailing slash: Django redirects slash-less URLs
and the redirect drops the authorization header.

## Permissions

`Internet` for the API, `Downloads` for saving a document where another
application can open it.

## Licence

GPL-3.0-or-later
