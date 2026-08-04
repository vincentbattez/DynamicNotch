## Contrainte matérielle : notch physique MacBook

L'écran des MacBook possède un **notch physique** — une encoche en haut au centre de l'écran qui masque une petite zone. Toute interface ou logique d'affichage doit en tenir compte :

- Ne jamais afficher de contenu critique derrière le notch (zone centrale en haut).
- Les coordonnées et calculs de mise en page doivent compenser l'espace occupé par le notch.
- Cette app s'intègre intentionnellement avec le notch ; les changements visuels ou de positionnement doivent toujours être validés en tenant compte de sa présence réelle à l'écran.

## Rebuild & relance automatique

À **chaque changement de code**, rebuild et relance l'application pour que je puisse valider le résultat en conditions réelles.

```sh
mise run dev   # kill l'instance en cours, rebuild Debug, relance
```

Toutes les commandes du projet passent par mise (`mise tasks ls`) : `build`,
`dev`, `test`, `test:ui`, `ci`, `clean`. Ne pas ré-écrire les invocations
`xcodebuild` à la main — les tasks portent déjà le bon `-derivedDataPath`, les
flags de signature et la liste des tests skippés
(`scripts/lib/skipped-tests.txt`).

## Agent skills

### Issue tracker

Issues live in Linear — team `Vincentbattez` (`VIN-*`), project `DynamicNotch`. New work is also mirrored as a Things 3 task via the `things3` skill — the root of a work item only, never its children. Read `docs/agents/issue-tracker.md` before creating any issue.

### Triage labels

Default triage vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context (`CONTEXT.md` + `docs/adr/` at the repo root). See `docs/agents/domain.md`.
