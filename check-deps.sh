#!/usr/bin/env bash
# Probe build-time deps. Exits 0 if all present, else lists what's missing
# and prints a distro-specific install hint. No sudo here — copy/paste.
#
# What we need: enough to build Postgres from source AND to compile the
# pgpdf extension against it. The Postgres install itself goes under
# ./pg-install/, so no system Postgres is required.
set -euo pipefail

missing=()
need_cmd()  { command -v "$1" >/dev/null 2>&1 || missing+=("$2"); }
need_pkg()  { pkg-config --exists "$1" 2>/dev/null   || missing+=("$2"); }
need_file() { [[ -e "$1" ]]                          || missing+=("$2"); }

# Compilers + buildchain
need_cmd  gcc        "gcc"
need_cmd  make       "make"
need_cmd  git        "git"
need_cmd  curl       "curl"
need_cmd  pkg-config "pkg-config"
need_cmd  bison      "bison"
need_cmd  flex       "flex"

# Postgres source build deps (header probes — most reliable cross-distro)
need_file /usr/include/readline/readline.h "readline-dev"
need_file /usr/include/zlib.h              "zlib-dev"

# pgpdf needs poppler with glib bindings.
need_pkg  poppler-glib "poppler-glib-dev"

# OCR preprocess (optional path): ocrmypdf shells out to tesseract +
# ghostscript. uv (for ocrmypdf itself) is bootstrapped by ocr-pdf.sh, so
# we don't probe it here.
need_cmd  tesseract  "tesseract"
need_cmd  gs         "ghostscript"

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "All deps present."
  echo "  gcc          : $(gcc -dumpversion)"
  echo "  bison/flex   : $(bison --version | head -1), $(flex --version)"
  echo "  poppler-glib : $(pkg-config --modversion poppler-glib)"
  exit 0
fi

mapfile -t missing < <(printf '%s\n' "${missing[@]}" | awk '!seen[$0]++')
echo "Missing: ${missing[*]}" >&2

ID=""; ID_LIKE=""
[[ -r /etc/os-release ]] && . /etc/os-release || true
family="${ID:-unknown}"
case " $ID $ID_LIKE " in
  *" debian "*|*" ubuntu "*)  family=debian ;;
  *" arch "*)                 family=arch ;;
  *" fedora "*|*" rhel "*|*" centos "*) family=fedora ;;
  *" alpine "*)               family=alpine ;;
esac

echo >&2
echo "Detected distro family: $family" >&2
case "$family" in
  arch)
    declare -A m=(
      [gcc]=gcc [make]=make [git]=git [curl]=curl [pkg-config]=pkgconf
      [bison]=bison [flex]=flex
      [readline-dev]=readline [zlib-dev]=zlib
      [poppler-glib-dev]=poppler-glib
      [tesseract]="tesseract tesseract-data-eng"
      [ghostscript]=ghostscript
    )
    pkgs=(); for k in "${missing[@]}"; do pkgs+=("${m[$k]:-$k}"); done
    mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | awk '!seen[$0]++')
    echo "  sudo pacman -S --needed ${pkgs[*]}" ;;
  debian)
    declare -A m=(
      [gcc]=build-essential [make]=build-essential [git]=git [curl]=curl
      [pkg-config]=pkg-config [bison]=bison [flex]=flex
      [readline-dev]=libreadline-dev [zlib-dev]=zlib1g-dev
      [poppler-glib-dev]=libpoppler-glib-dev
      [tesseract]=tesseract-ocr
      [ghostscript]=ghostscript
    )
    pkgs=(); for k in "${missing[@]}"; do pkgs+=("${m[$k]:-$k}"); done
    mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | awk '!seen[$0]++')
    echo "  sudo apt-get install -y ${pkgs[*]}" ;;
  fedora)
    declare -A m=(
      [gcc]=gcc [make]=make [git]=git [curl]=curl
      [pkg-config]=pkgconf-pkg-config [bison]=bison [flex]=flex
      [readline-dev]=readline-devel [zlib-dev]=zlib-devel
      [poppler-glib-dev]=poppler-glib-devel
      [tesseract]=tesseract
      [ghostscript]=ghostscript
    )
    pkgs=(); for k in "${missing[@]}"; do pkgs+=("${m[$k]:-$k}"); done
    mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | awk '!seen[$0]++')
    echo "  sudo dnf install -y ${pkgs[*]}" ;;
  alpine)
    declare -A m=(
      [gcc]=build-base [make]=build-base [git]=git [curl]=curl
      [pkg-config]=pkgconf [bison]=bison [flex]=flex
      [readline-dev]=readline-dev [zlib-dev]=zlib-dev
      [poppler-glib-dev]=poppler-dev
      [tesseract]="tesseract-ocr tesseract-ocr-data-eng"
      [ghostscript]=ghostscript
    )
    pkgs=(); for k in "${missing[@]}"; do pkgs+=("${m[$k]:-$k}"); done
    mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | awk '!seen[$0]++')
    echo "  sudo apk add ${pkgs[*]}" ;;
  *)
    echo "  (unknown distro — install equivalents for: ${missing[*]})" >&2 ;;
esac
exit 1
