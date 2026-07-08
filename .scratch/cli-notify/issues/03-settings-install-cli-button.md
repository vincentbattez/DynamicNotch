Status: ready-for-agent

# Slice 3 — Bouton Réglages « Installer l'outil CLI »

## What to build

Embarquer le binaire `dynamicnotch` (slice 2) dans le bundle de l'app, et ajouter un bouton dans
`NotificationsSettingsView` (ou l'écran Réglages pertinent) qui installe le CLI sur le `PATH` via un
symlink `/usr/local/bin/dynamicnotch`. Voir `docs/cli-notify-feature-spec.md` §5.

### Embarquement

- Build phase : copier le produit `dynamicnotch` dans `DynamicNotch.app/Contents/…` (p. ex.
  `Contents/MacOS/` ou `Contents/Helpers/`) et le signer avec l'app.

### Bouton d'installation

- Libellé « Installer l'outil CLI » (localisé — voir plus bas).
- Action : créer/écraser un symlink `/usr/local/bin/dynamicnotch` → chemin du binaire **dans le bundle**
  (le symlink pointe dans le bundle ⇒ suit les updates de l'app).
- Si `/usr/local/bin` non-writable (fréquent Apple Silicon, dossier parfois absent) : escalade via
  `osascript … "do shell script … with administrator privileges"` (app **non-sandboxée** ⇒ autorisé),
  **un seul prompt**.
- **Idempotent** : ré-appui recrée/écrase un symlink périmé sans erreur.
- Message de résultat clair (succès / échec / permission refusée).

### Vérification Gatekeeper (à ne pas zapper)

- Vérifier qu'un binaire signé embarqué, lancé depuis `/usr/local/bin` via symlink en Terminal,
  s'exécute **sans blocage Gatekeeper/quarantine**. En pratique OK pour une app déjà installée, mais
  **valider empiriquement** — c'est le point qui casse en silence à la 1re install réelle.

### Localisation

- Libellé du bouton + messages de résultat : ajoutés au catalogue de localisation (**en/es/ru/zh-Hans**),
  cohérent avec les autres libellés Réglages (slice 6 de la feature Notifications).

## Acceptance criteria

- [ ] Le binaire `dynamicnotch` est embarqué dans le bundle et signé avec l'app.
- [ ] Un bouton « Installer l'outil CLI » apparaît dans les Réglages.
- [ ] Appui ⇒ symlink `/usr/local/bin/dynamicnotch` créé et pointant dans le bundle ; `dynamicnotch
      notify …` fonctionne depuis n'importe quel dossier ensuite.
- [ ] `/usr/local/bin` non-writable ⇒ un prompt admin unique ; refus ⇒ message d'échec clair, pas de crash.
- [ ] Ré-appui idempotent (répare un symlink périmé).
- [ ] Vérif Gatekeeper effectuée et notée (le binaire lancé via symlink s'exécute sans blocage).
- [ ] Libellés/messages localisés en/es/ru/zh-Hans.
- [ ] App compile ; tests verts (`CODE_SIGNING_ALLOWED=NO`).

## Blocked by

Slice 2 (binaire `dynamicnotch` à embarquer).
