# Trap Runner

Мультиплеерный Deathrun для Roblox: один игрок — **Трапер** — бежит по параллельному коридору
за стеклом и включает ловушки, остальные — **Раннеры** — проходят полосу препятствий.
Трасса собирается заново каждый раунд. Весь текст в игре — на английском.

**Статус: Фаза 1 — игровой цикл и роли.** Трасса пока из 5 фиксированных сегментов-связок без ловушек.

## Быстрый старт

1. Установи [Rokit](https://github.com/rojo-rbx/rokit) и в папке проекта выполни `rokit install`
   (поставит Rojo, StyLua и Selene из `rokit.toml`).
2. Запусти `rojo serve`.
3. В Roblox Studio открой новый place (шаблон Baseplate подойдёт) и в плагине Rojo нажми **Connect**.
4. Проверь, что у `Workspace` включён **StreamingEnabled**: Rojo выставляет его из `default.project.json`,
   но если галочки нет — поставь вручную (сервер напишет предупреждение в Output).
5. **Test → Clients and Servers**, 3 игрока, **Start**.

Лимит 12 игроков задаётся в Game Settings → Places → Max Players (при публикации).

## Как проверить Фазу 1

В тесте с 3 клиентами:

| Сценарий | Что должно произойти |
|---|---|
| Двое встали в синий круг RUNNER, один в красный TRAPPER | 10 c «Next round in…», потом 15 c отсчёта: у каждого в HUD своя роль, далеко по оси X строится трасса |
| Конец отсчёта | Раннеры на стартовой площадке, Трапер в коридоре за стеклом; 3 c все заморожены, ворота исчезают, баннеры «RUN!» / «YOU ARE THE TRAPPER - stop them all!» |
| Раннеры добегают до финиша | В kill feed «Name finished #1 (0:42.3)», места 1-2-3 по порядку пересечения финиша |
| Раннер прыгает в пропасть | «Name fell into the void», он появляется в лобби, раунд идёт дальше |
| Все раннеры погибли | «TRAPPER WINS!» на экране итогов |
| Раннер стоит на месте 25 c | «Name was eliminated (AFK)», его переносит в лобби, раунд не зависает |
| Трапер закрыл окно клиента посреди раунда | Раунд сразу заканчивается, оставшиеся раннеры отмечены как «survived», победа Раннеров |
| В кругах меньше 2 игроков | На табло и в HUD: «Stand in a circle to play» |
| Игрок стоит вне кругов при старте отсчёта | Он не участвует и остаётся в лобби зрителем |

Правила выбора Трапера: случайный из круга TRAPPER; если там пусто — случайный из всех участников;
тот же игрок не становится Трапером два раунда подряд, если есть другие кандидаты (кроме случая, когда в круге
TRAPPER стоит только он сам).

Каждая трасса пишет в Output свой seed: `[Track] seed = 123456`. Технический лимит раунда (12 минут)
закрывает раунд без наград и пишет предупреждение с seed.

## Структура

```
default.project.json        Rojo: src/shared -> ReplicatedStorage.Shared,
                            src/server -> ServerScriptService.Server,
                            src/client -> StarterPlayer.StarterPlayerScripts.Client
src/
  shared/
    Types.luau              общие типы
    Remotes.luau            все RemoteEvent (только сервер -> клиент)
    GameState.luau          реплицируемое состояние: атрибуты папки ReplicatedStorage.GameState и игроков
    StatusText.luau         строки статуса для табло и HUD
    JumpMath.luau           лимиты прыжка из JumpPower/WalkSpeed/Gravity с запасом 15%
    Config/
      GameConfig.luau       таймеры, скорости, размеры лобби и трассы
      Segments.luau         библиотека сегментов (id, length, rise, difficulty, trapType, weight, minDifficultyTier)
  server/
    Main.server.luau
    Services/
      CharacterService.luau коллизии игроков, прыжок/скорость, телепорты
      LobbyService.luau     лобби, круги ролей, выбор Трапера, ожидание игроков, табло
      RoundService.luau     отсчёт, раунд, прогресс, финиш, AFK, итоги
    Track/
      TrackGenerator.luau   старт, сегменты, финиш, стекло и коридор Трапера
      SegmentKit.luau       общие кирпичики для сегментов
      Themes.luau
      Segments/             по модулю на сегмент
    Util/
      Build.luau            постройка из примитивов
      Assets.luau           поиск готовых моделей в ReplicatedStorage.Assets
  client/
    Main.client.luau
    Controllers/
      HUDController.luau    статус, баннер роли, отсчёт ворот, kill feed, итоги
      LobbyController.luau  подсказка, в каком круге стоит игрок
    Util/UI.luau
```

## Свои модели вместо плейсхолдеров

Положи модель в `ReplicatedStorage.Assets` (папку создаёт Rojo и не трогает её содержимое):

- `Lobby` — должна содержать части `RunnerCircle` и `TrapperCircle` (радиус берётся из атрибута `Radius`
  или из конфига), по желанию `Board` (табло рисуется на грани Front) и `SpawnLocation`.
- `Segment_<id>` (например, `Segment_JumpPlatforms`) — pivot модели в центре пола на входе, взгляд вперёд
  по трассе; длина и перепад высоты должны совпадать с `Config/Segments.luau`. Стекло и коридор Трапера
  генератор добавит сам.

Если модели нет или в ней не хватает обязательных частей — строится плейсхолдер из примитивов.

## Инструменты

- `stylua src` — форматирование, `selene src` — линтер.
- Для автодополнения и проверки типов в VS Code: расширение luau-lsp и
  `rojo sourcemap default.project.json --output sourcemap.json --watch`.

## Дальше по плану

- **Фаза 2** — генератор с seed, рост сложности, чекпоинт-ворота и проверка времени между ними, 4 темы.
- **Фаза 3** — первые 5 ловушек с кнопками в коридоре, телеграфы, урон на сервере, режим зрителя.
- **Фаза 4** — очки, ProfileStore, магазин, наборы и все способности, остальные ловушки.
- **Фаза 5** — монетизация, прогресс-бар, мобильный UI, звуки и эффекты.
