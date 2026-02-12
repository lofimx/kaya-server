# Kaya

## Prerequisites

* Ruby 3.4.8
* Postgres 17
* Docker: https://get.docker.com (Debian)
  * `curl -fsSL https://get.docker.com -o install-docker.sh`
  * `sh install-docker.sh --dry-run`
  * `sudo sh install-docker.sh`

## Docker

```
# Build and run locally
docker compose up --build

# Or just build + push to Docker Hub
docker compose build
docker push deobald/kaya_server:latest
```

## TODO

* [x] avatar
* [x] sync API
* [x] basic fuzzy search
* [x] save a note/bookmark
* [x] pre-cache bookmarks in /cache
* [ ] per-user SQLite full-text search?
* [ ] PDF OCR with tesseract?
* [ ] email address verification

## License

AGPL-3.0

Icons are licensed Creative Commons Zero 1.0 Universal.
