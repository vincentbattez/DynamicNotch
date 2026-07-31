# Les Commands passent par un dossier frère de l'Inbox, pas par l'Inbox

Un process externe qui veut **agir** sur le notch (démarrer un Local timer, demain en arrêter un)
dépose un **Command drop** dans `~/Library/Application Support/DynamicNotch/commands/` — dossier
frère de l'Inbox, même écriture atomique, mais contrat et politique distincts. L'Inbox reste
réservée aux Notifications.

## Pourquoi

Parce que le raisonnement d'[ADR-0001](./0001-inbox-sole-entry-point.md) **s'inverse** ici. Sa
justification centrale est la durabilité app-fermée : un Drop arrivé pendant que l'app dormait est
ingéré au lancement suivant, et c'est un gain. Pour une Command, c'est un défaut : un timer dérivé
d'un événement de calendrier, ingéré une heure après coup, ne serait pas « en retard » — il serait
**faux**. Les deux canaux ont besoin de politiques de péremption opposées, donc de dossiers
distincts.

S'y ajoute une raison de contrat : `NotificationInboxMonitor` parse *tout* `*.json` de l'Inbox
comme un `NotificationPayload` et met en quarantaine ce qui échoue. Y glisser des Commands
imposerait de transformer le payload en union discriminée — or ADR-0001 qualifie lui-même ce
contrat de « difficile à inverser », et chaque script existant en dépend. Le dossier frère laisse
le contrat Notification rigoureusement intact.

## Conséquences

- **`endsAt` est absolu, jamais une durée.** La péremption devient une propriété de la donnée
  plutôt qu'une politique à inventer : à l'ingestion, `endsAt` déjà passé ⇒ la Command est
  supprimée sans effet ni trace. Le CLI accepte `--duration` par ergonomie mais le résout en
  `endsAt` **avant** d'écrire, pour que le décalage émission→ingestion n'entache jamais le résultat.
- **Deux monitors, un seul mécanisme de drop.** Le package local est renommé
  `NotificationContract` → `DynamicNotchContract` : il héberge désormais deux contrats de données
  qui partagent l'écriture atomique et la résolution de chemin. Garder l'ancien nom aurait installé
  un mensonge durable dans l'API partagée par l'app et le CLI.
- **Le silence reste la règle, sauf conflit.** Conformément à ADR-0001, une Command ne produit
  aucun accusé de réception : succès = « fichier déposé ». Une exception assumée : quand un Clock
  timer tourne, la Command timer ne démarre rien et l'app pousse une **Notification** de niveau
  `warning` — sans quoi l'appelant verrait un exit 0 et un notch vide, sans aucun moyen de
  comprendre.
- **Pas d'URL scheme, pour l'instant.** Il aurait l'avantage de lancer l'app si elle est fermée,
  mais l'app démarre au login et le file-drop évite d'ajouter un second canal d'entrée à maintenir.
  Décision explicitement **réversible** : c'est le contrat de Command qui compte, pas son transport.
