# Тести SaveGuard

## Unit & Integration тести (TestEZ)

Автозапуск **ВИМКНЕНО** для зручності scenario тестування.

### Як запустити вручну:

**Варіант 1: Через Command Bar в Studio**
```lua
require(game.ServerScriptService.Tests.RunTests)()
```

**Варіант 2: Відновити автозапуск**
```bash
git mv tests/init.server.disabled tests/init.server.luau
```

---

## Scenario тести

Запускаються автоматично при старті гри через:
- `tests/scenario/TestRunner.server.luau`
- `tests/scenario/GameSetup.server.luau`

Детальніше: `tests/scenario/TEST_RESULTS.md`

