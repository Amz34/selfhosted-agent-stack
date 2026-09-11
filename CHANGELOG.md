# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-09-11

### Added
- `scripts/zram_setup.sh` — idempotent compressed-swap setup (zstd, priority 100).
- `scripts/resource_watchdog.sh` — RAM/swap/disk/load watchdog, silent when healthy.
- `scripts/chrome_reaper.sh` — reclaims leaked headless-browser memory trees safely.
- `tests/check_docs.py` + CI pipeline (shell syntax, shellcheck, Python compile, docs links).

### Changed
- README rewritten around measured production behaviour: resource envelope, real
  incident list, cost table, and an architecture diagram.

## [1.0.0] — 2026-08-20

### Added
- Initial release: build guide, Telegram bot patterns, and the operational scripts
  (`gateway_restart_cron.sh`, `telegram_webhook_watchdog.sh`, `whatsapp_healthcheck.sh`,
  `telegram_409_diagnose.py`, `gmail_toolbox.py`).
