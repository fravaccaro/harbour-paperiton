---
layout: default
title: Signing in
parent: Using Paperiton
nav_order: 1
---

# Signing in

On the start page, enter the URL of your Paperless-ngx server, then pick one of three ways in:

* **User name and password** - the app asks the server for a token and stores that; the password itself is never kept.
* **API token** - paste a token created under *Settings → My profile* in the Paperless-ngx web interface.
* **Web sign-in** - the web interface of the server opens inside the app. Use this when your server sits behind single sign-on or asks for a second factor; whatever the web interface accepts works here.

However you sign in, the resulting API token is stored in **Sailfish Secrets**, not in a plain file.

## Self-signed certificates

If the server presents a certificate the phone does not trust, the app shows the details and lets you accept it explicitly. The choice is remembered for that server.

## Signing out

Signing out (from the settings page) removes the token from Sailfish Secrets, empties the private cache and returns to the sign-in page.
