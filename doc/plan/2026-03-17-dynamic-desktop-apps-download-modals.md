# Dynamic Desktop Apps Download Modals

## Goal

Replace static desktop platform links with modal dialogs that present download options for each OS, pulling the latest release assets directly from GitHub as a CDN.

## Decisions

- **AUR**: Link to AUR page (`https://aur.archlinux.org/packages/savebutton`)
- **Ebuild**: Link to `.ebuild` file download from GitHub (no overlay hosting)
- **deps.tar.xz**: Not offered — build artifact only
- **Distro logos**: Official SVGs, any open license
- **Cache**: Background job refreshes GitHub release data periodically
- **Windows**: Fully functional (not "Coming Soon")

## Implementation

### 1. GitHub Release Cache Model

`app/models/releases/github_release.rb` — Fetches latest release from GitHub API, extracts asset download URLs by file extension/pattern, stores in `Rails.cache`.

### 2. Background Job

`app/jobs/releases/refresh_github_releases_job.rb` — Periodic job to refresh cached release data. Runs on a schedule (e.g., hourly).

### 3. Stimulus Controller

`app/javascript/controllers/download_modal_controller.js` — Opens/closes modal, shows correct OS panel based on `data-platform` value.

### 4. Modal Partial

`app/views/shared/_download_modal.html.erb` — Three panels:

**Windows:** x86 Windows Installer → `.msi`
**macOS:** Intel (x86) → `x86_64.dmg`, Apple Silicon → `arm64.dmg`
**Linux:** Arch (AUR page), Debian/Ubuntu (`.deb`), Gentoo (`.ebuild`), Flatpak (`.flatpak`), Fedora (`.rpm`), Ubuntu/Snap (`.snap`)

### 5. CSS & Icons

- Modal styles in `application.css` following existing `add-modal` pattern
- Distro SVG logos in `public/icons/platforms/`

### 6. Tests

- Unit test for `Releases::GithubRelease`
- Unit test for the refresh job

## Files

| File | Action |
|------|--------|
| `app/models/releases/github_release.rb` | Create |
| `app/jobs/releases/refresh_github_releases_job.rb` | Create |
| `app/javascript/controllers/download_modal_controller.js` | Create |
| `app/views/shared/_download_modal.html.erb` | Create |
| `app/views/shared/_apps_content.html.erb` | Modify |
| `app/assets/stylesheets/application.css` | Modify |
| `public/icons/platforms/*.svg` | Create |
| `config/locales/en.yml` | Modify |
| `test/models/releases/github_release_test.rb` | Create |
| `test/jobs/releases/refresh_github_releases_job_test.rb` | Create |
