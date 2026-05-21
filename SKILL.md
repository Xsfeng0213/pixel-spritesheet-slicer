---
name: pixel-spritesheet-slicer
description: Use when the user provides one complete pixel-art character sprite sheet or 2D game action sheet and wants Codex to analyze, classify, slice/cut, export transparent individual action frames, build a manifest, or fix animation frame fragments/misaligned actions.
---

# Pixel Spritesheet Slicer

## Overview

Turn one large action sprite sheet into classified, transparent frame PNGs that a game/web preview can play reliably. Prefer this workflow whenever browser-side slicing causes duplicate characters, edge fragments, or actions that do not match the button labels.

## Workflow

1. Copy or reference the source sheet with an absolute path. If working in a project, place a copy under `assets/`.
2. Visually inspect the whole sheet first. If coordinates are hard to read, create a temporary grid overlay or contact sheet.
3. Identify action groups by pose, not by row alone: idle, walk/run, jump, attack, magic, block, hit, knockdown, feed, sleep, happy, level, etc.
4. Create a cut plan JSON with explicit rectangles for each frame. Do not trust a uniform grid if rows contain uneven spacing or large effects.
5. Run `scripts/export-action-frames.ps1` to create `assets/frames/<action>/<NN>.png` and `assets/frames/manifest.json`.
6. Run `scripts/check-frame-margins.ps1`, then generate a contact sheet with `scripts/make-contact-sheet.ps1`.
7. Inspect the contact sheet. Tighten bad crop rectangles and rerun until no frame has adjacent sprites, cut-off bodies, or unrelated effects.
8. Wire the app to load `manifest.json` and draw pre-cut PNG frames. Do not reintroduce live sheet slicing in the browser.

## Cut Plan Format

Use JSON:

```json
{
  "source": "assets/character-spritesheet.png",
  "padding": 8,
  "actions": {
    "idle": {
      "speed": 260,
      "frames": [
        { "left": 0, "top": 0, "width": 110, "height": 125, "keepDistance": 70 }
      ]
    },
    "attack": {
      "speed": 90,
      "once": true,
      "effect": "slash",
      "frames": [
        { "left": 230, "top": 600, "width": 150, "height": 125, "keepDistance": 95 }
      ]
    }
  }
}
```

Frame fields:
- `left`, `top`, `width`, `height`: source rectangle in pixels.
- `keepDistance`: keep connected components close to the main component; raise for sword arcs, hearts, Zzz, or spell effects.
- `keepAll`: set to `true` only for a crop where every visible component belongs to the action.
- Action fields copied to the manifest: `speed`, `once`, `effect`, `className`.

## Commands

```powershell
powershell -ExecutionPolicy Bypass -File "<skill>\scripts\export-action-frames.ps1" `
  -SourcePath "assets\character-spritesheet.png" `
  -PlanPath "tmp\cut-plan.json" `
  -OutputDir "assets\frames"

powershell -ExecutionPolicy Bypass -File "<skill>\scripts\check-frame-margins.ps1" `
  -FramesRoot "assets\frames"

powershell -ExecutionPolicy Bypass -File "<skill>\scripts\make-contact-sheet.ps1" `
  -FramesRoot "assets\frames" `
  -OutputPath "tmp\frame-contact.png"
```

## Quality Rules

- Produce independent transparent PNGs, not CSS background-position slices.
- Keep full limbs unless the source pose intentionally hides them.
- Preserve small semantic effects only when they belong to the frame: hearts, anger marks, Zzz, slash arcs, magic circles.
- Remove unrelated edge fragments even if automated tests pass.
- Validate with both automated margin checks and human visual inspection before telling the user to try it.

## Common Mistakes

- **Uniform grid over-trust**: generated sheets often have uneven spacing; use explicit rectangles for problem actions.
- **Largest component trap**: a spell effect may be larger than the character; use `keepDistance` or `keepAll`.
- **Over-wide crops**: sword arcs and dust can pull in neighboring sprites; shrink the rectangle before increasing cleanup thresholds.
- **Stale frames**: rerun export after plan edits and ensure the app reads the regenerated `manifest.json`.
