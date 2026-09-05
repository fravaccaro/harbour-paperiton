---
layout: default
title: Building
parent: Developers
nav_order: 2
---

# Building

## With the Sailfish SDK

With the [Sailfish SDK](https://docs.sailfishos.org/Tools/Sailfish_SDK/Installation/) installed:

```bash
sfdk config target SailfishOS-4.6.0.13-aarch64
sfdk build
```

Deploy to a connected device:

```bash
sfdk config device "My Phone"
sfdk deploy --sdk
```

## Continuous integration

RPMs are built by the GitHub Actions workflow in `.github/workflows/build.yml` on every push to `main`, and attached to GitHub releases when one is published.

The documentation site is built by `.github/workflows/pages.yml` (Jekyll with the just-the-docs theme, configured in `_config.yml`) and deployed to GitHub Pages.

## Packaging notes

`sfdk check` reports one error, `Import 'Sailfish.Office 1.0' is not allowed`. That import is the viewer of the Documents application, without which a document in the private cache directory cannot be shown at all, so the package is meant for Chum and OpenRepos rather than the Jolla Store.

The spec file excludes automatic `Provides:` for the bundled Opal QML modules - Harbour forbids an application package from providing QML modules.
