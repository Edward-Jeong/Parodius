# Neon Night Courier

An original, family-friendly comic side-scrolling shooter built with Godot 4.

## Run on Windows

```powershell
.\.tools\Godot_v4.7-stable_win64.exe --editor --path .
```

Press **F6/F5** in the editor, or run:

```powershell
.\.tools\Godot_v4.7-stable_win64.exe --path .
```

Controls:

- Use the arrow keys or WASD to move during PC testing, including diagonal movement.
- Drag with mouse or touch to move.
- Auto-fire is always enabled.
- Press Space or tap the paw button when the special meter is full.
- Press P/Escape or tap pause.
- Development only: F9 advances the current level time by 30 seconds.

## Test on iPhone without a Mac

The `main` branch is automatically exported to Web and deployed with GitHub
Pages. Open the Pages URL in iPhone Safari, rotate to landscape, tap once to
unlock browser audio, and test touch dragging.

Each endless level lasts three minutes before its final boss, with a mid-boss
at 1:30. Defeating the final boss increases the difficulty and starts the next
level. Losing all three health points ends the run.

Expected URL after Pages is enabled:

https://edward-jeong.github.io/Parodius/

## iOS build

Godot's iOS export requires macOS with Xcode. Keep development on Windows, then use a cloud Mac for the first device build, TestFlight validation, signing, and App Store upload.

1. Install the matching Godot 4.7 export templates on the cloud Mac.
2. Open this project and install the iOS export preset.
3. Set the unique bundle identifier and Apple development team.
4. Export the Xcode project.
5. Build on a real iPhone, then archive and upload through Xcode.

Official guide: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html

## Asset policy

All current visible art was generated specifically for this original project. Source mockup and prompts are documented under `docs/`. Do not add ROMs, sprites, music, names, or other material from existing commercial games.
