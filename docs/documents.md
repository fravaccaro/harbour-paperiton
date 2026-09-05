---
layout: default
title: Browsing and searching
parent: Using Paperiton
nav_order: 2
---

# Browsing and searching

The document list scrolls without pages: more documents are fetched as you approach the end. Each entry shows the thumbnail the server rendered, the title, and the filing date. Documents filed on the same day keep a fixed order, so refreshing never shows a document twice.

## Search

The search field runs a full text query (`?query=`) against the server, debounced so a request goes out only when you pause typing. It searches the OCR text as well as titles and metadata — the same search the web interface offers.

## Filters

From the filters page you can narrow the list:

* **by tag**
* **by correspondent**
* **saved views** — the views you defined on the server, translated into their query parameters
* **inbox** — documents carrying the inbox tags of the server

The pulley menu of the filters page also leads to the settings, the task queue, and the About page.
