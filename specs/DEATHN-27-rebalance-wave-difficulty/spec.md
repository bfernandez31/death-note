# Quick Implementation: Rebalance wave difficulty by spawn density and load legible game font

**Feature Branch**: `DEATHN-27-rebalance-wave-difficulty`
**Created**: 2026-05-18
**Mode**: Quick Implementation (bypassing formal specification)

## Description

## Contexte

La table de difficulté actuelle (DEATHN-19) scale **deux variables en parallèle** sur les vagues : `spawn_delay` qui diminue et `fall_speed` qui augmente, les deux dérivées du WPM cible via `deriveWaveTiming()`.

Mathématiquement, la cible WPM est respectée. **En pratique, l'expérience est cassée** dès la vague 8 environ.

## Comportement attendu

### Modèle de difficulté à deux leviers

**Levier 1 — temps de chute base** (gouverne la lisibilité)
```
time_on_screen_base(wave) = clamp(6.0 - 0.15 × (wave - 1), 2.5, 6.0)
```

**Levier 2 — nombre de zombies par burst** (gouverne la densité)
```
zombies_per_burst(wave) = ceil(wave / 4)
```

**Délai entre bursts**
```
spawn_delay_entre_bursts(wave) = (72 × zombies_per_burst) / target_wpm
```

### Target WPM par vague
La table garde la progression actuelle jusqu'à la vague 15 (15 WPM → 100 WPM). Au-delà :
```
target_wpm(wave) = min(100 + (wave - 15) × 5, 250)
```

### Cap sur le multiplicateur Runner
Plafonner le multiplicateur runner à 1.3×.

### Police de jeu lisible
Charger une police TTF dédiée pour tous les textes en jeu.

## Implementation Notes

This feature is being implemented via quick-impl workflow, bypassing formal specification and planning phases.

**Quick-impl is suitable for**:
- Bug fixes (typos, minor logic corrections)
- UI tweaks (colors, spacing, text changes)
- Simple refactoring (renaming, file organization)
- Documentation updates

**For complex features**, use the full workflow: INBOX → SPECIFY → PLAN → BUILD

## Implementation

Implementation will be done directly by Claude Code based on the description above.
