# Home Page - Apps Section

## Summary

Add "Get The Apps" section to the home page between the hero and features sections. This section showcases all the platforms Save Button is available on.

## Sections

### 1. Mobile Apps
- Blurb: "Available for iPhone, iPad, Android phones, and Android tablets."
- Two store buttons: App Store and Play Store (linked with standard badge PNGs)

### 2. Browser Extensions
- Blurb: "Save Button works on most browsers. If your browser is not listed, try installing from the Chromium link."
- 8 browser icons in a grid: Firefox, Chrome, Edge, Safari, Chromium, Vivaldi, Brave, Arc
- Each icon has the browser name as a caption, linking to the appropriate extension store URL
- Standard PNG icons sourced from the web, stored in `public/icons/browsers/`

### 3. Desktop Apps
- Icons for Windows, macOS, and Linux with name captions
- Each has "(Coming Soon)" on a new line under the caption
- Standard OS PNG icons stored in `public/icons/platforms/`

### 4. Server
- Blurb: "Grab an account with savebutton.com or, if you're a big nerd, host the backup service yourself."
- Two options side-by-side with "- or -" between them:
  - Save Button icon (`yellow-floppy3.svg`) with "Sign Up" CTA button (links to `new_registration_path`)
  - Kaya icon (`old-kaya-icon.svg`) with "Self-Host" text (links to GitHub repo)

## Files Modified

1. `app/views/pages/home.html.erb` - Add the `#apps` section content
2. `app/assets/stylesheets/application.css` - Add CSS for the apps section
3. `public/icons/browsers/` - Add browser PNG icons (Firefox, Chrome, Edge, Safari, Chromium, Vivaldi, Brave, Arc)
4. `public/icons/platforms/` - Add platform PNG icons (App Store badge, Play Store badge, Windows, macOS, Linux)

## Design Approach

- Follow existing GNOME HIG patterns from the codebase
- Use the same card/grid style as the features section
- Use standard CSS custom properties from the existing theme
- SVG icons for Save Button and Kaya are already in `doc/design/` and will be inlined or referenced from `public/`
- Browser and platform icons are standard PNGs sourced from the web, kept small (64x64 or similar)
- Responsive: grid collapses on mobile (4 cols -> 2 cols -> 1 col)

## Progress Log

### Icons Downloaded (complete)
- **Browser icons** in `public/icons/browsers/` — all valid PNGs:
  - `firefox.png` (64x64) — from `alrra/browser-logos` GitHub repo, `main` branch, path `src/firefox/firefox_64x64.png`
  - `chrome.png` (64x64) — same repo, `src/chrome/chrome_64x64.png`
  - `edge.png` (64x64) — same repo, `src/edge/edge_64x64.png`
  - `safari.png` (64x64) — same repo, `src/safari/safari_64x64.png`
  - `chromium.png` (64x64) — same repo, `src/chromium/chromium_64x64.png`
  - `vivaldi.png` (64x64) — same repo, `src/vivaldi/vivaldi_64x64.png`
  - `brave.png` (64x64) — same repo, `src/brave/brave_64x64.png`
  - `arc.png` (120x100) — from Wikimedia Commons, `Arc_(browser)_logo.svg` thumbnail at 120px
- **Store badges** in `public/icons/platforms/`:
  - `app-store.svg` — from `developer.apple.com/assets/elements/badges/download-on-the-app-store.svg`
  - `play-store.png` (200x60) — from Wikimedia `Google_Play_Store_badge_EN.svg` thumbnail at 200px

### Desktop OS Icons Downloaded (complete)
- Used Wikimedia API `action=query` with `iiprop=url&iiurlwidth=64` to get correct `thumburl`, then curl'd those
- `windows.png` (120x120) — from Wikimedia `Windows_logo_-_2021.svg`
- `macos.png` (120x148) — from Wikimedia `Apple_logo_black.svg`
- `linux.png` (120x143) — from Wikimedia `Tux.svg`

### Server Section SVGs Copied (complete)
- `public/icons/save-button.svg` — copied from `doc/design/yellow-floppy3.svg`
- `public/icons/kaya.svg` — copied from `doc/design/old-kaya-icon.svg`

### ALL ICONS COMPLETE — remaining work:
- Build the `#apps` section HTML in `app/views/pages/home.html.erb`
- Add CSS for the apps section in `app/assets/stylesheets/application.css`
- Add responsive breakpoints for the apps section
