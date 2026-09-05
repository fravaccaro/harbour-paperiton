---
layout: default
title: Uploading
parent: Using Paperiton
nav_order: 4
---

# Uploading

Three ways into the archive:

* **From the app** — the upload page opens a file picker.
* **From other apps** — Paperiton appears in the Sailfish OS share menu; several files at once are fine.
* **From the camera** — capture a document directly; the picture is uploaded like any other file.

## What the server can take

Only file kinds Paperless-ngx accepts without external converters are offered: **PDF**, **PNG**, **JPEG**, **TIFF**, **GIF** and **WebP** pictures, and **plain text**. The picker lists only those kinds, other apps offer Paperiton only for them, and a file of another kind is turned down with the reason instead of being sent.

## Following the upload

An upload shows a notification with a progress bar and ends as one summary rather than a message per file. After the server accepts a file, the app follows the consumer task until the document actually exists, then names the document it created so it can be opened from the queue.

## The task queue

The tasks page shows the task queue of the server — what is being consumed, what succeeded, and what failed with the reason the server gave. Failures can be acknowledged from the app.
