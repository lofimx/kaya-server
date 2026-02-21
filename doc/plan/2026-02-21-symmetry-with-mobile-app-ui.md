# Symmetry with Mobile App UI

## Context

The web UI needs to match the mobile app (kaya-flutter) navigation patterns. The profile avatar, logout, and add-button are currently positioned differently from the mobile app. This change reorganizes navigation so the web and mobile experiences are consistent.

## Changes

### 1. Create generic profile icon — `app/views/shared/icons/_profile_icon.html.erb`

New partial with a GNOME HIG symbolic person icon SVG (20x20, `currentColor`). Used as fallback when user has no avatar.

### 2. Restructure app header — `app/views/shared/_app_header.html.erb`

**Hamburger menu**: Add "Account" link below "Everything" in `.hamburger-dropdown`:
- Icon: user's avatar (20x20, circular) if attached, otherwise `_profile_icon` partial
- Links to `account_path`
- Active state when `current_page?(account_path)`

**Add button**: Move out of `.header-left` to the right side of `.header-container`. Hide entirely if `content_for?(:hide_add_button)` is set.

**Remove `nav-links`**: Delete the entire `<nav class="nav-links">` block (Log Out button + profile avatar link). This block is only used in the app header; the public header (`_header.html.erb`) has its own separate `nav-links` for logged-out users and is unaffected (logged-in users are redirected away from public pages).

Result: header becomes `[hamburger] ........... [add-button]` (or just `[hamburger]` on Account page).

### 3. Switch Account page to app layout — `app/views/accounts/show.html.erb`

- Add `<% content_for :app_layout, true %>` at top
- Add `<% content_for :hide_add_button, true %>` to suppress add-button
- Add a new `account-section` at the bottom with:
  - `<h2>Log Out</h2>`
  - `<p>End your session in this browser.</p>`
  - `button_to "Log Out", session_path, method: :delete`

### 4. Simplify public header — `app/views/shared/_header.html.erb`

Remove the authenticated branch entirely (the `if authenticated?` block with Log Out + avatar). Authenticated users are already redirected away from all pages that use this header. Keep only the `else` branch (Log In + Sign Up).

### 5. CSS adjustments — `app/assets/stylesheets/application.css`

- Add `.hamburger-avatar` styles: 20x20 circular image for the avatar in the menu item
- Ensure `.header-container` positions add-button on the right when `nav-links` is removed (flexbox `space-between` is already set)
- No changes needed for `.account-page` padding — it already accounts for the fixed header height

## Files modified

| File | Action |
|------|--------|
| `app/views/shared/icons/_profile_icon.html.erb` | Create (new generic person SVG) |
| `app/views/shared/_app_header.html.erb` | Restructure (menu items, move add-button, remove nav-links) |
| `app/views/shared/_header.html.erb` | Simplify (remove authenticated branch) |
| `app/views/accounts/show.html.erb` | Add app_layout, hide_add_button, logout section |
| `app/assets/stylesheets/application.css` | Add hamburger-avatar styles |
