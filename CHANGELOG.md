# Changelog

All notable changes to SaveGuard will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0-mvp] - 2026-01-05

### 🎉 Initial MVP Release

> **Note:** This is an experimental MVP release intended for early adopters and testing. Production-ready v1.0.0 will include additional features and stability improvements.

**Core Features:**
- ✅ Save Queue with retry logic and exponential backoff
- ✅ Snapshot System (current + previous) for rollback
- ✅ Session Lock using MemoryStore (with DataStore fallback)
- ✅ BindToClose Handler for graceful server shutdown
- ✅ Loaded-flag Protection prevents saving unloaded data
- ✅ Autosave every 60 seconds
- ✅ Drop-in Public API (SaveGuard)

**Modules Implemented:**
- `Init.luau` - Public API
- `Config.luau` - Configuration
- `Types.luau` - Type definitions
- `DataManager.luau` - Orchestration layer
- `SaveQueue.luau` - Retry logic with exponential backoff
- `Snapshot.luau` - Rollback system
- `SessionLock.luau` - Multi-server write protection
- `BindToClose.luau` - Graceful shutdown handler

**Testing:**
- ✅ 61/61 automated tests passing (100%)
  - 54 unit tests
  - 7 integration tests
- ✅ High test coverage across all core modules

**Documentation:**
- ✅ Comprehensive README.md with Quick Start
- ✅ Full API Reference
- ✅ Installation guide
- ✅ Configuration guide
- ✅ FAQ section
- ✅ BasicUsage.server.luau example
- ✅ AdvancedUsage.server.luau example

**Safety Guarantees:**
- 🔒 No save if load failed (Loaded-flag protection)
- 🔒 Automatic retry on DataStore errors (up to 3 attempts)
- 🔒 Snapshot system prevents data wipes
- 🔒 Session Lock prevents fast rejoin conflicts
- 🔒 BindToClose ensures saves complete on shutdown

**Known Limitations (MVP):**
- Scenario tests require manual testing in production
- Multi-server race condition tests need published place
- No teleport support (planned for v1.0.0)
- No UI/dashboard (planned for v2.0)
- Demo place not included (examples provided instead)

---

## [Unreleased]

### Planned for v2.0
- [ ] UI Dashboard for monitoring saves
- [ ] Analytics integration
- [ ] Configurable snapshot history (>2)
- [ ] Advanced merge strategies for UpdateAsync
- [ ] External webhook notifications
- [ ] Performance profiling tools

---

**Legend:**
- ✅ Completed
- 🔒 Security/Safety feature
- 📦 New module
- 🐛 Bug fix
- ⚡ Performance improvement
- 📝 Documentation

