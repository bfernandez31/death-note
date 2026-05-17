# DEATHN-25: New design

## Description

Il faudrait revoir le design pour changer. 

Direction artistique — CRT violet/magenta
Palette principale :

Phosphore principal (fg) : #d48aff (violet clair magenta)
Phosphore sombre (dim) : #3a1a5a (violet profond pour les éléments inactifs)
Fond (bg) : #08020a (noir tirant légèrement vers le violet)
Glow : #d48aff (même que fg, utilisé pour box-shadow et text-shadow)
Accent (lettres correctes) : #f0c8ff (lavande très clair, presque blanc)
Warn (lettre à taper / cible / combo hot) : #ffb13a (ambre pour contraste chaud)
Err (erreur / game over) : #ff5a8a (rose-rouge, harmonise avec le violet)


Effets CRT (essentiels pour le rendu violet)
Glow violet partout sur les titres, plus subtil sur le HUD
Bezel : double bordure sombre autour de l'écran 
Scanlines : lignes horizontales semi-transparentes en repeating-linear-gradient, mix-blend-mode multiply
Vignette radiale aux coins en radial-gradient
Flicker : overlay magenta très subtil qui clignote toutes les 7s à 2-3% d'opacité
Fond du screen : radial-gradient du violet très sombre vers le noir
Pas de gradients colorés modernes, pas d'arrondis web, tout doit sentir le tube cathodique. Le violet doit donner une ambiance "vaporwave/synthwave arcade" plutôt que phosphore Apple
