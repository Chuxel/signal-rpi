# signal-rpi

Build [Signal Desktop](https://github.com/signalapp/Signal-Desktop) for Linux arm64 (aarch64) — useful for Raspberry Pi OS / Debian systems where no official package is provided.

## Prerequisites

Install the following on your Debian/Ubuntu-based arm64 system:

```bash
sudo apt-get update
sudo apt-get install -y \
  git curl build-essential python3 gcc g++ make \
  ruby ruby-dev
```

### Node.js

The build requires a specific Node.js version (currently **24.x** — check `.nvmrc` in the Signal source for the exact version). The recommended way to manage this is [nvm](https://github.com/nvm-sh/nvm):

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
# Restart your shell, then:
nvm install 24
```

### fpm (packaging tool)

electron-builder uses [fpm](https://github.com/jordansissel/fpm) to create `.deb` packages, but it only bundles an x86 binary. The script will attempt to install fpm automatically via `gem`, but you can install it ahead of time:

```bash
sudo gem install fpm --no-document
```

## Usage

### Build the latest release

```bash
./build-signal.sh
```

### Build a specific version

```bash
SIGNAL_VERSION=v8.14.0 ./build-signal.sh
```

### Output

On success, the `.deb` package will be in the `Signal-Desktop-<version>/release/` directory:

```
Signal-Desktop-v8.14.0/release/signal-desktop_8.14.0_arm64.deb
```

Install it with:

```bash
sudo dpkg -i Signal-Desktop-v8.14.0/release/signal-desktop_8.14.0_arm64.deb
sudo apt-get install -f  # fix any missing dependencies
```

## How it works

1. Fetches the latest release tag from the Signal Desktop GitHub repo (or uses `SIGNAL_VERSION` if set)
2. Shallow-clones the source at that tag
3. Installs/verifies the correct Node.js and pnpm versions
4. Runs `pnpm install` and `pnpm run generate` to build assets
5. Uses electron-builder with the system `fpm` to package a `.deb` for the current architecture

## Notes

- The build process is resource-intensive. On a Raspberry Pi 4 (4 GB+), expect it to take 30+ minutes.
- Requires several GB of disk space for dependencies and build artifacts.
- Only tested on Debian/Ubuntu-based arm64 systems (Raspberry Pi OS 64-bit, Ubuntu 22.04+).
- The script also supports `x86_64` and `armv7l` architectures, though official x64 packages already exist.

## License

See [LICENSE](LICENSE).
