# Battle Chess

A dark medieval 3D chess game with gruesome animated battle sequences when pieces capture each other. Built in Godot 4 with HTML5 export.

## Features

- **36 unique battle animations** — every attacker/defender matchup has its own kill choreography
- **AI opponent** — 4 difficulty levels (Peasant → Grandmaster) with minimax alpha-beta search
- **Local multiplayer** — hot-seat play on the same screen
- **Online multiplayer** — WebSocket-based with lobby system
- **NC-17 gore** — blood particles, dismemberment, dark medieval aesthetic
- **Web playable** — HTML5 export for browser play

## Piece Archetypes

| Piece | Design |
|-------|--------|
| Pawn | Armored foot soldier with sword & buckler |
| Rook | Stone golem with rune carvings |
| Knight | Mounted warrior on armored warhorse |
| Bishop | Dark-robed sorcerer with staff |
| Queen | Dual-blade warrior queen |
| King | Greatsword monarch with crown & cape |

## Tech Stack

- **Engine:** Godot 4.4 (GDScript)
- **3D Models:** AI-generated via Hunyuan3D
- **Export:** HTML5 (WebGL)
- **Multiplayer:** WebSocket (Supabase Realtime)

## Running

1. Open `project.godot` in Godot 4.4+
2. Press F5 to run
3. Select game mode from the menu

## Building for Web

1. Install Godot HTML5 export templates
2. Project → Export → Web preset
3. Export to `export/web/`
