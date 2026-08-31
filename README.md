# Utsuu

![Visitors](https://visitor-badge.laobi.icu/badge?page_id=gamesense1337.Utsuu)
[![Crystal](https://img.shields.io/badge/Crystal-1.12%2B-black?logo=crystal)](https://crystal-lang.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-2ea44f)](https://crystal-lang.org/install/)
[![License](https://img.shields.io/badge/License-MIT-238636)](LICENSE)

Utsuu is a compact, self hosted image host written in Crystal. It runs a small HTTP server with a simple upload page, stores accepted images locally, and returns a direct UUID based URL for each upload.

It is intentionally lightweight and easy to extend. The project does not provide public hosting, user accounts, persistent cloud storage, or production security controls by default.

## Features

- Supports **PNG**, **JPG**, **GIF**, and **WEBP** uploads.
- Enforces a **10 MB** server side upload limit.
- Generates a unique UUID filename for every accepted upload.
- Returns direct image URLs through both the upload page and the JSON API.
- Serves uploaded images with the appropriate MIME type and cache headers.
- Rejects unsupported file extensions and basic path traversal attempts.
- Uses only Crystal's standard library; no third-party shards are required.

## How It Works

Utsuu listens on port `3000` and exposes two routes:

1. `GET /` renders the upload page.
2. `POST /upload` accepts a multipart form containing a `file` field, validates the extension and size, then writes the image to `images/` with a UUID filename.
3. `GET /images/<UUID>.<extension>` serves the stored image and applies a one week cache policy.

Successful uploads return JSON in this format:

```json
{
  "Url": "http://localhost:3000/images/2f4107a5-627d-4a6f-a15a-7ee1cf5fb976.png"
}
```

## Requirements

- [Crystal **1.12** or newer](https://crystal-lang.org/install/)
- On Windows, the Crystal **MSVC** package requires Visual Studio Build Tools with **Desktop development with C++** and a Windows SDK.
- An editor is optional, but [Visual Studio Code](https://code.visualstudio.com/) with the [Crystal Language extension](https://marketplace.visualstudio.com/items?itemName=crystal-lang-tools.crystal-lang) is recommended.

## Installation

Clone the repository:

```bash
git clone https://github.com/gamesense1337/Utsuu.git
cd Utsuu
```

Build and start the server:

```bash
shards build
```

On Windows:

```powershell
.\bin\Utsuu.exe
```

On Linux or macOS:

```bash
./bin/Utsuu
```

Open `http://localhost:3000` in your browser. `localhost` makes the host available only on your own machine.

## Building From Source

The project has no external dependencies, so `shards build` is enough for a release build. For a quick development run without keeping the output binary:

```bash
crystal run src/Main.cr
```

The resulting executable is written to `bin/Utsuu` on Linux/macOS or `bin\Utsuu.exe` on Windows.

## Project Layout

```text
Utsuu/
├── src/Main.cr      # HTTP server, upload handler, image serving, and web UI
├── images/          # Created automatically; uploaded images are excluded from Git
├── shard.yml        # Crystal project definition
├── README.md
└── LICENSE
```

## Public Deployment

For a public image host, place the application behind Caddy, nginx, or another HTTPS reverse proxy. Add rate limiting, image signature validation and decoding, content moderation, malware scanning, upload expiration, a database or object store, and authentication before accepting untrusted public uploads.

## Acknowledgements

- [Crystal](https://crystal-lang.org/) for the language and standard HTTP library.
- [Crystal Language Tools](https://marketplace.visualstudio.com/items?itemName=crystal-lang-tools.crystal-lang) for Visual Studio Code support.

## Disclaimer

Utsuu is provided as a self hosted code example. The user deploying it is responsible for their infrastructure, uploaded content, access controls, and any security measures required for their use case.

## License

This project is licensed under the [MIT License](LICENSE).
