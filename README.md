# pgpdf-test

Self-contained test harness for [pgpdf](https://github.com/Florents-Tselai/pgpdf),
a Postgres extension that exposes a `pdf` data type backed by poppler.

Builds Postgres 18 from source into `./pg-install/`, compiles the extension
against it, runs the cluster on `:55432` as the current user. Nothing touches
the system Postgres (if any).

The layout doubles as a template for developing other Postgres extensions:
swap the `pgpdf/` submodule for your own and adjust the poppler-glib check
in `check-deps.sh`.

## Prereqs

Just the things needed to compile Postgres + a poppler-linked extension:

- Linux (Arch, Debian/Ubuntu, Fedora/RHEL, or Alpine)
- gcc, make, git, curl, pkg-config, bison, flex
- readline + zlib headers
- poppler with glib bindings

`./check-deps.sh` probes for all of these and prints the install command for
your distro if anything is missing.

## Run

```sh
./check-deps.sh                       # tells you what to install (no sudo)
./build.sh                            # downloads + builds PG 18, builds pgpdf
./start-pg.sh                         # starts the local cluster on :55432
./smoke-test.sh                       # sanity check on a public PDF
./run-pdf.sh test-pdfs/your-file.pdf  # extract text from any PDF
```

`run-pdf.sh` prints metadata to stdout and writes the full extracted text to
a `.pgpdf.txt` sibling of the input.

Cleanup:

```sh
./stop-pg.sh
rm -rf pg-build pg-install pgdata pg.log
```

## Layout

| Path | What |
| --- | --- |
| `pgpdf/` | Submodule, [Florents-Tselai/pgpdf](https://github.com/Florents-Tselai/pgpdf) pinned |
| `check-deps.sh` | Cross-distro dep probe |
| `build-pg.sh` | Download + configure + build Postgres 18.3 into `./pg-install/` |
| `build.sh` | Drives `build-pg.sh`, then builds pgpdf into the same prefix |
| `start-pg.sh` / `stop-pg.sh` | Cluster in `./pgdata/`, port 55432, socket in `/tmp` |
| `smoke-test.sh` | Loads the extension, runs it on a public PDF |
| `run-pdf.sh <path>` | Run any PDF through pgpdf, dump metadata + full text |
| `test-pdfs/` | Drop input PDFs here (gitignored except `.gitkeep`) |

First `./build.sh` takes a few minutes (Postgres compile). Subsequent runs
are seconds — `build-pg.sh` is idempotent and only `make clean && make` the
extension itself.
