# MeTube Cookie Helper

This is a minimal Chrome/Edge Manifest V3 helper for no-volume deployments.

## Local install

1. Open `chrome://extensions` or `edge://extensions`.
2. Enable developer mode.
3. Choose "Load unpacked".
4. Select this `browser-extension` folder.
5. Open MeTube in a normal tab.
6. Click the extension button and choose "Authorize YouTube Cookies".

The extension reads YouTube cookies only after the button is clicked. It sends them to the active MeTube tab's `upload-cookies` endpoint with that tab's `metube_cookie_profile` token.

The MeTube server stores those cookies as an ephemeral profile under `TEMP_DIR/.metube-cookie-profiles`. Without a persistent Zeabur Volume, the profile is expected to disappear on restart or redeploy.
