#!/usr/bin/env bash
# Downloads the latest Signal Desktop release source and builds it for Linux
# on the current architecture.
set -euo pipefail

REPO="signalapp/Signal-Desktop"
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH="$(uname -m)"

# Map kernel arch to electron-builder arch names
case "$ARCH" in
  x86_64)  EB_ARCH="x64" ;;
  aarch64) EB_ARCH="arm64" ;;
  armv7l)  EB_ARCH="armv7l" ;;
  *)
    echo "ERROR: Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

echo "==> Architecture detected: $ARCH (electron-builder: $EB_ARCH)"

# ── 1. Resolve the latest release tag ──────────────────────────────────────
if [ -z "${SIGNAL_VERSION:-}" ]; then
  echo "==> Fetching latest release tag from GitHub..."
  SIGNAL_VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)"
fi
echo "==> Version: $SIGNAL_VERSION"

SRC_DIR="$WORK_DIR/Signal-Desktop-${SIGNAL_VERSION}"

# ── 2. Clone the source at the release tag ─────────────────────────────────
if [ ! -d "$SRC_DIR" ]; then
  echo "==> Cloning source for $SIGNAL_VERSION (shallow)..."
  git clone --depth 1 --branch "$SIGNAL_VERSION" \
    "https://github.com/$REPO.git" "$SRC_DIR"
else
  echo "==> Source directory already exists, skipping clone."
fi

cd "$SRC_DIR"

# ── 3. Ensure correct Node.js version (via nvm) ───────────────────────────
REQUIRED_NODE="$(cat .nvmrc 2>/dev/null || echo '24.15.0')"
echo "==> Required Node.js version: $REQUIRED_NODE"

# Source nvm if available
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
elif [ -s "/usr/share/nvm/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "/usr/share/nvm/nvm.sh"
fi

if command -v nvm &>/dev/null; then
  echo "==> Installing/activating Node.js $REQUIRED_NODE via nvm..."
  nvm install "$REQUIRED_NODE"
  nvm use "$REQUIRED_NODE"
elif command -v node &>/dev/null; then
  CURRENT_NODE="$(node -v)"
  echo "==> nvm not found. Current Node.js: $CURRENT_NODE (required: v$REQUIRED_NODE)"
  if [ "${CURRENT_NODE#v}" != "$REQUIRED_NODE" ]; then
    echo "WARNING: Node.js version mismatch. Install nvm or Node.js $REQUIRED_NODE."
    echo "         Continuing anyway – build may fail."
  fi
else
  echo "ERROR: Node.js is not installed. Install Node.js $REQUIRED_NODE." >&2
  echo "       Recommended: use nvm (https://github.com/nvm-sh/nvm)" >&2
  exit 1
fi

# ── 4. Ensure pnpm is available ────────────────────────────────────────────
REQUIRED_PNPM="$(grep '"packageManager"' package.json | grep -oP 'pnpm@\K[0-9.]+')"
echo "==> Required pnpm version: $REQUIRED_PNPM"

if ! command -v pnpm &>/dev/null; then
  echo "==> Installing pnpm globally..."
  npm install -g "pnpm@$REQUIRED_PNPM"
elif ! pnpm -v | grep -q "^${REQUIRED_PNPM%%.*}\."; then
  echo "==> Updating pnpm to $REQUIRED_PNPM..."
  npm install -g "pnpm@$REQUIRED_PNPM"
fi

# ── 5. Install dependencies ───────────────────────────────────────────────
echo "==> Installing dependencies (this may take a while)..."
pnpm install --frozen-lockfile

# ── 6. Generate assets ────────────────────────────────────────────────────
echo "==> Generating assets..."
pnpm run generate

# ── 7. Ensure fpm is available natively (electron-builder bundles x86 only) ─
if ! command -v fpm &>/dev/null; then
  echo "==> Installing fpm (native packaging tool)..."
  if command -v gem &>/dev/null; then
    gem install fpm --no-document
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y ruby ruby-dev build-essential
    sudo gem install fpm --no-document
  else
    echo "ERROR: Cannot install fpm. Install Ruby and run: gem install fpm" >&2
    exit 1
  fi
fi
echo "==> Using fpm: $(which fpm)"

# ── 8. Build for Linux on current architecture ────────────────────────────
echo "==> Building Signal Desktop for linux/$EB_ARCH..."

# USE_SYSTEM_FPM tells electron-builder to use the system fpm instead of its
# bundled x86-only copy
export USE_SYSTEM_FPM=true
export SIGNAL_ENV=production
pnpm run build:electron \
  --config.directories.output=release \
  --linux deb \
  --"$EB_ARCH"

echo ""
echo "=========================================="
echo " Build complete!"
echo " Output is in: $SRC_DIR/release/"
echo "=========================================="
ls -lh "$SRC_DIR/release/"*.deb 2>/dev/null || echo "(no .deb found – check release/ for output)"
