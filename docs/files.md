---
layout: default
title: Files and permissions
parent: Using Paperiton
nav_order: 5
---

# Files and permissions

## Where documents live on the phone

**Open** downloads the file into `~/Downloads/Paperiton` under the name the server keeps for it (for example the archived PDF name). If that name is already there, it is overwritten. Pictures are then shown inside Paperiton; PDFs and other files are handed to the system viewer.

**Download**, from a row's context menu or the pulley menu when documents are selected, writes the same files into the same folder without opening them. While files arrive, a progress notification is shown; each successful file then gets its own entry in the events view, from which it can be opened (Gallery for pictures, the system handler for PDFs) or shared, without bringing Paperiton to the front.

Thumbnails and camera captures still use the app's private cache. Signing out clears that cache (and leftover `documents/` folders from older versions); `Downloads/Paperiton` is never emptied by the app.

## Permissions

Sailjail, the Sailfish OS sandbox, hides every common directory from the app unless a permission names it. Paperiton asks for:

| Permission | Why |
|---|---|
| `Internet` | Talking to the Paperless-ngx API |
| `Downloads` | Opening documents, and reading files that arrived from elsewhere |
| `Documents`, `Pictures` | Reading files kept there for upload |
| `RemovableMedia` | Files on a memory card |
| `Camera` | Scanning documents |
| `Secrets` | The API token in Sailfish Secrets |
| `WebView` | Signing in through the web interface of the server |

Without the permission for the directory a file sits in, a file picked or shared from there cannot be read at all. The file picker reads those directories itself, so the media index - and the `MediaIndexing` permission it would need - is not involved.

## Backup

The app's settings (server URL, user name, TLS preference) are declared for the Sailfish OS backup via `X-HarbourBackup`. The API token lives in Sailfish Secrets and is not part of backups; sign in again after a restore.
