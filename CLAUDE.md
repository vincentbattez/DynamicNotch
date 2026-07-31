## Contrainte matérielle : notch physique MacBook

L'écran des MacBook possède un **notch physique** — une encoche en haut au centre de l'écran qui masque une petite zone. Toute interface ou logique d'affichage doit en tenir compte :

- Ne jamais afficher de contenu critique derrière le notch (zone centrale en haut).
- Les coordonnées et calculs de mise en page doivent compenser l'espace occupé par le notch.
- Cette app s'intègre intentionnellement avec le notch ; les changements visuels ou de positionnement doivent toujours être validés en tenant compte de sa présence réelle à l'écran.

## Rebuild & relance automatique

À **chaque changement de code**, rebuild et relance l'application pour que je puisse valider le résultat en conditions réelles.

```sh
# Tuer l'instance en cours, rebuild Debug, puis relancer
killall DynamicNotch 2>/dev/null; \
xcodebuild -project DynamicNotch.xcodeproj -scheme DynamicNotch -configuration Debug \
  -derivedDataPath build build CODE_SIGNING_ALLOWED=NO \
&& open build/Build/Products/Debug/DynamicNotch.app
```

## Agent skills

### Issue tracker

Issues live in Linear — team `Vincentbattez` (`VIN-*`), project `DynamicNotch`. New work is also mirrored as a Things 3 task via the `things3` skill — the root of a work item only, never its children. Read `docs/agents/issue-tracker.md` before creating any issue.

### Triage labels

Default triage vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context (`CONTEXT.md` + `docs/adr/` at the repo root). See `docs/agents/domain.md`.
