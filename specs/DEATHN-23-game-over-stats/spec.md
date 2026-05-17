# Quick Implementation: Game-over stats screen and high score persistence

**Feature Branch**: `DEATHN-23-game-over-stats`
**Created**: 2026-05-17
**Mode**: Quick Implementation (bypassing formal specification)

## Description

## Contexte

Vagues, boss, score, WPM live et accuracy sont en place. L'écran de game-over reste minimal et aucun high score n'est persisté.

## Comportement attendu

**1. Animation de transition vers game-over**
- Quand un zombie touche le sol : pause du jeu pendant 1 seconde
- Le zombie responsable est mis en évidence par une teinte rouge
- Aucune autre logique pendant cette seconde (pas de spawn, pas d'update)
- Après 1s, transition vers l'écran de stats

**2. Écran de stats**
- Fond `RAYWHITE` plein écran
- Centré horizontalement, espacé verticalement à partir de y=80, lignes séparées de 35px
- Lignes (font 24, couleur `DARKGRAY` sauf indication) :
  1. `GAME OVER` (font 48, `RED`)
  2. `Wave reached: 12`
  3. `Score: 47230`
  4. `Best: 52100` — ou `NEW HIGH SCORE!` en `GOLD` si score > best
  5. `Average WPM: 52`
  6. `Accuracy: 94%`
  7. `Kills: 87`
  8. `Press ENTER to restart` (font 18, `GRAY`, en bas)

**3. WPM moyen de session**
- `wpm_avg = (total_correct_chars / 5) / (session_duration_minutes)`
- `session_duration_minutes = (game_over_time - game_start_time) / 60`

**4. Kills**
- Compteur total de la partie (zombies normaux + boss), u32, reset au restart

**5. Persistance**
- Natif : fichier `highscore.dat` dans le répertoire de travail, structure binaire `{ score: u64, wave: u32, wpm: u32, accuracy: u8 }`. Si absent au boot, valeurs par défaut zéro
- Web (emscripten) : `localStorage` sous la clé `death-note.highscore` au format JSON
- Sauvegarde uniquement si score > best_score au moment du game-over
- Le `Best` affiché reflète la valeur après sauvegarde

**6. Restart**
- `ENTER` reset tous les compteurs (score, combo, kills, WPM stats, accuracy) et relance à la vague 1
- `best_score` n'est pas reset

## Critères d'acceptation

- L'écran de stats affiche les 7 lignes aux positions et couleurs indiquées
- Un nouveau record affiche `NEW HIGH SCORE!` en jaune doré
- Relancer le jeu après un record persisté affiche bien la valeur sauvegardée comme `Best:`
- Sur la build web, vider le `localStorage` puis recharger remet le best à 0
- Sur la build native, supprimer `highscore.dat` puis relancer remet le best à 0
- 600 caractères corrects en 60 secondes → average WPM = 120
- Le compteur kills correspond exactement aux zombies effectivement éliminés

## Hors scope

- Historique des N dernières parties
- Leaderboard global
- Partage du score
- Animation de game-over plus élaborée

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
