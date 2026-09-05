---
layout: default
title: Using Paperiton
nav_order: 2
permalink: docs/guide
has_children: true
has_toc: true
---

# Using Paperiton

Paperiton is a native client for a [Paperless-ngx](https://docs.paperless-ngx.com/) server you already run. Everything lives on your server; the app keeps only a private cache on the phone.

## Requirements

* Sailfish OS 5.0 or newer (the API token is kept in Sailfish Secrets)
* A reachable Paperless-ngx instance, API version 9 or newer

## The pages

* **[Signing in](signin)** - user name and password, API token, or the web interface of the server (single sign-on and two-factor authentication included)
* **[Browsing and searching](documents)** - the document list, full text search, filters, saved views and the inbox
* **[Viewing and editing](editing)** - the document view, metadata editing, bulk editing and notes
* **[Uploading](upload)** - from the file picker, the share menu or the camera, and the task queue
* **[Files and permissions](files)** - where documents live on the phone and why the app asks for each permission

## Further help

* [Report an issue](https://github.com/fravaccaro/harbour-paperiton/issues)
