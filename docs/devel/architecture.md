---
layout: default
title: Architecture
parent: Developers
nav_order: 1
---

# Architecture

## Source map

| Part | Purpose |
|---|---|
| `src/paperless/config.*` | Server URL, user name and TLS preference in `~/.config/org.frapps/harbour-paperiton/settings.conf` |
| `src/paperless/secretsstore.*` | The API token in Sailfish Secrets, with migration of tokens written by version 0.1 |
| `src/paperless/api.*` | `QNetworkAccessManager` wrapper: token header, redirect retries, timeouts, downloads, uploads, permission probe |
| `src/paperless/documentlistmodel.*` | Paginated list model for `/api/documents/` |
| `src/paperless/lookupmodel.*` | Tags, correspondents and document types by id |
| `src/paperless/customfieldsmodel.*` | The custom fields defined on the server |
| `src/paperless/savedviewmodel.*` | Saved views, translated into query parameters |
| `src/paperless/uploadqueue.*` | Multipart uploads and polling of the consumer task |
| `src/paperless/filetypes.h` | The file kinds Paperless can consume, shared by picker, share target and upload queue |
| `src/paperless/tasklistmodel.*` | `/api/tasks/` and acknowledging failures |
| `src/paperless/thumbimageprovider.*` | `image://paperless/thumb/<id>` and `image://paperless/preview/<id>` |
| `qml/pages/*` | Silica UI |

## Networking rules

Networking lives in C++ because the Paperless endpoints for thumbnails and previews need an `Authorization: Token …` header, which QML's `Image` cannot send.

All API paths keep their **trailing slash**: Django redirects slash-less URLs and the redirect drops the authorization header.

## Sandbox layout

Sailjail gives the app three private directories, named after the `OrganizationName` and `ApplicationName` of the desktop file:

* `~/.config/org.frapps/harbour-paperiton` - settings
* `~/.cache/org.frapps/harbour-paperiton` - thumbnails, downloaded documents, camera captures and the web view profile
* the matching `~/.local/share` directory - unused

No other application can read these paths, so documents are shown by `qml/pages/PdfViewPage.qml`, which wraps the viewer of the Documents application, and by `qml/pages/ImageViewPage.qml`. When that viewer is missing, the app falls back to a copy in `~/Downloads`. `documents/` and `captures/` are removed when the app starts and when it quits, and signing out removes the whole cache.
