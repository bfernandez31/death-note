# Quick Implementation: Copy of Modes Survie, Arcade et Simulation avec systeme de vies

**Feature Branch**: `DEATHN-30-copy-of-modes`
**Created**: 2026-05-19
**Mode**: Quick Implementation (bypassing formal specification)

## Description

## Contexte

Le jeu propose aujourd'hui un mode de jeu unique basé sur les vagues progressives (WPM croissant) et un "mode bot" pour observer le jeu en auto-pilote. On veut séparer clairement deux expériences de jeu.

## Besoin

### 1. Renommer "Bot" en "Simulation"
Le mode bot existant est renommé **Simulation** partout (menu, écrans, libellés). Aucun changement de comportement, juste le nom.

### 2. Mode Survie (sans pouvoirs)
Le mode de jeu actuel devient le **mode Survie pur** :
- Mêmes vagues, même progression WPM, mêmes spawns qu'aujourd'hui
- **Aucun pouvoir** disponible
- **Pas de système de vies** : une seule erreur (zombie qui touche le bas) = game over, comme aujourd'hui
- C'est le mode "hardcore / leaderboard" : la jauge de skill brute du joueur

### 3. Mode Arcade (avec vies et pouvoirs actuels bombe freeze shield)
Nouveau mode qui réutilise **exactement les mêmes vagues** que la Survie (mêmes WPM, mêmes spawns, mêmes timings) mais ajoute :
- **Système de vies** : le joueur démarre avec **3 cœurs**
- Un zombie qui atteint le bas retire **1 cœur** (au lieu de game over)
- Game over quand les 3 cœurs sont consommés
- **Récupération d'un cœur à chaque boss vaincu** (cap à définir, a priori 3 max)
- Les pouvoirs actuels seront disponibles dans ce mode 

L'idée : grâce aux vies et aux pouvoirs, le joueur peut aller plus loin que ce que la Survie permet avec les mêmes vagues.

## Critères d'acceptation

- [ ] Le menu principal propose 4 modes : Survie, Arcade, Simulation, Zen
- [ ] Le mode Bot est intégralement renommé Simulation (menu et tous les écrans concernés)
- [ ] Le mode Survie conserve le comportement actuel (1 erreur = game over, pas de cœurs)
- [ ] Le mode Arcade utilise les mêmes vagues que la Survie (même WaveConfig)
- [ ] En Arcade, 3 cœurs sont affichés à l'écran et décrémentés à chaque zombie qui passe
- [ ] En Arcade, vaincre un boss restaure 1 cœur (avec un cap maximum)
- [ ] Le high score reste séparé par mode (un best Survie, un best Arcade)

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
