---
layout: default
title: Files and permissions
parent: Using Paperiton
nav_order: 5
---

# Files and permissions

## Where documents live on the phone

Nothing is stored permanently. A document you open is downloaded into the app's private cache directory, which no other application can read; `documents/` and `captures/` inside it are emptied when the app starts and when it quits, and signing out removes the whole cache.

The one exception is **Save on device**, which keeps a copy of the archived PDF in `~/Downloads` - the only place another application can pick a document up from.

## Permissions

Sailjail, the Sailfish OS sandbox, hides every common directory from the app unless a permission names it. Paperiton asks for:

| Permission | Why |
|---|---|
| `Internet` | Talking to the Paperless-ngx API |
| `Downloads` | "Save on device", and reading files that arrived from elsewhere |
| `Documents`, `Pictures` | Reading files kept there for upload |
| `RemovableMedia` | Files on a memory card |
| `Camera` | Scanning documents |
| `Secrets` | The API token in Sailfish Secrets |
| `WebView` | Signing in through the web interface of the server |

Without the permission for the directory a file sits in, a file picked or shared from there cannot be read at all. The file picker reads those directories itself, so the media index - and the `MediaIndexing` permission it would need - is not involved.

## Backup

The app's settings (server URL, user name, TLS preference) are declared for the Sailfish OS backup via `X-HarbourBackup`. The API token lives in Sailfish Secrets and is not part of backups; sign in again after a restore.
