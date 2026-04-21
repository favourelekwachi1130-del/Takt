Takt (PresentationTimer) — web hosting for takt-app.org
======================================================

Cloudflare: see CLOUDFLARE-PAGES.txt for a full click-path (Pages + custom domain + checks).

1) Apple App Site Association (Universal Links)
   - Upload the file at:
     .well-known/apple-app-site-association
   - It must be served at:
     https://takt-app.org/.well-known/apple-app-site-association
   - Edit the JSON first: replace TEAM_ID with your Apple Developer Team ID (10 characters).
     Find it in developer.apple.com → Membership, or Xcode → Signing & Capabilities.
   - Serve with Content-Type: application/json (many hosts do this by default for extensionless JSON).
   - No file extension on apple-app-site-association.

2) Fallback page (Safari / reviewers without the app)
   - Upload the "import" folder so this URL works:
     https://takt-app.org/import/
   - Open import/index.html and replace APPSTORE_NUMERIC_ID with your App Store app id from App Store Connect.
   - When someone opens a shared link in the browser, they see install instructions and an App Store button.

3) DNS
   - Point takt-app.org (and optionally www.takt-app.org) at your static host or CDN.

4) Xcode
   - Associated Domains are already enabled in PresentationTimer.entitlements for applinks:takt-app.org and www.
   - After AASA is live, install the app from a development/ad-hoc build and tap a shared https://takt-app.org/import?p=... link to verify the app opens.

5) Optional
   - Redirect www.takt-app.org → takt-app.org for a single canonical host (share URLs use takt-app.org without www).
