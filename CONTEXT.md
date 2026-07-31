# DynamicNotch

Une app macOS qui s'intègre au notch physique du MacBook. Ce glossaire fixe le vocabulaire
des deux canaux par lesquels des process externes s'adressent au notch : les **Notifications**
(résumés ambiants et durables, sans vol de focus) et les **Commands** (impératifs périssables
qui pilotent une surface, comme le Timer).

## Language

### Notifications

**Notification**:
Une notification **de DynamicNotch** : l'entité que l'app ingère, garde en liste et affiche
sur le notch. C'est le système de notification de l'application elle-même.
_Avoid_: « alert », « item » seul, et surtout « notification » employé pour la notif système.

**Native notification**:
La notification **système macOS** (Centre de notifications), qu'on **oppose** délibérément :
elle vole le focus, disparaît, ne s'agrège pas par source, ne survit pas à la fermeture de l'app.
_Avoid_: « system notification », « notification » sans qualificatif.

**Payload**:
Le JSON qu'un script externe pousse pour créer une Notification : `title`, `summary`, `level`,
`source`, `icon`. La forme « sur le fil » d'une Notification à naître.
_Avoid_: appeler ça une « notification », « message », « event ».

**Source**:
Le canal de coalescence d'une Notification. Ce n'est pas une simple étiquette d'origine :
deux Payloads de la même `source` ne coexistent pas — le nouveau remplace l'existant. Une
Notification sans source n'est jamais fusionnée.
_Avoid_: « sender », « origin », « channel » (en surface), « author ».

**Level**:
La sévérité d'une Notification : `info` < `success` < `warning` < `error`. Pilote la teinte et
l'icône par défaut.
_Avoid_: « severity » (dans le code/UI), « priority » (réservé à la cohabitation des live activities).

**Coalescence**:
La règle par laquelle un nouveau Drop **remplace** l'existant au lieu de coexister avec lui :
pour une Notification, quand la Source est déjà présente (elle repasse non-lue et remonte en
tête) ; pour un Local timer, quand un timer tourne déjà (le nouveau prend sa place).
_Avoid_: « merge », « dedup », « grouping ».

### Ingestion

**Inbox**:
Le dossier surveillé où les Drops de Notifications atterrissent. Le seul canal d'entrée pour
une Notification : même le CLI y écrit plutôt que d'ouvrir un canal direct. Il a un dossier
frère pour les Commands (voir **Command drop**).
_Avoid_: « queue », « spool », « mailbox ».

**Drop**:
Une unité déposée dans l'Inbox — un fichier portant un Payload. « Déposer » (to drop) est le
geste d'un script qui notifie.
_Avoid_: « file », « message », « entry ».

**Drain**:
L'ingestion, au lancement de l'app, des Drops arrivés pendant qu'elle était fermée. Le Drain
ne déclenche **pas** de bannière (juste la mise à jour du badge).
_Avoid_: « flush », « replay », « catch-up ».

### Surfaces sur le notch

**Badge**:
La surface ambiante au repos : cloche + compteur de non-lues, teinté par la plus haute sévérité
non-lue. Visible ssi il existe au moins une Notification non-lue (et la feature est activée).
_Avoid_: « indicator », « counter » seul, « pill ».

**Arrival banner**:
La bannière transitoire (~3 s) affichée à l'arrivée d'une nouvelle Notification (app active),
avant de retomber sur le Badge. Le garant qu'on ne rate jamais un push.
_Avoid_: « toast », « popup », « alert ».

### Commandes

**Command**:
Un impératif qu'un process externe adresse à une surface du notch (« démarre un timer qui finit
à 14 h »). S'oppose terme à terme à la Notification : celle-ci **informe** et **dure**, la Command
**agit** et **périt**. Une Command n'apparaît jamais dans la liste des Notifications.
_Avoid_: « event », « action », « message », « notification » (c'est l'inverse).

**Command drop**:
Une Command déposée sous forme de fichier dans le dossier `commands/`, frère de l'Inbox, par la
même écriture atomique que les Drops. Le geste externe reste « déposer » ; c'est la destination
qui distingue une Command d'une Notification.
_Avoid_: « job », « task », « request ».

**Expiry**:
La date de fin (`endsAt`) qu'une Command porte **en absolu**, et qui la rend auto-invalidante :
ingérée après cet instant, elle est écartée sans effet ni trace. C'est ce qui fait d'une Command
une chose périssable là où une Notification arrivée en retard reste utile.
_Avoid_: « TTL », « timeout », « deadline », « staleness ».

### Timer

**Local timer**:
Le compte à rebours **de DynamicNotch**, celui que l'app démarre et pilote elle-même — depuis le
notch ou via une Command.
_Avoid_: « timer » sans qualificatif, « countdown », « in-app timer ».

**Clock timer**:
Le compte à rebours de l'app **Horloge** de macOS, que DynamicNotch se contente d'observer et de
refléter. Il **prime** sur le Local timer : tant qu'il tourne, une Command timer ne démarre rien.
_Avoid_: « system timer » (dans le glossaire ; le code utilise `.system`), « native timer ».

**Label**:
Le nom que porte un Local timer (« Fixer bug Léa »). Purement descriptif : il ne coalesce rien,
n'a pas de valeur par défaut, et son absence est le cas normal — un Local timer sans Label
s'affiche exactement comme avant son existence.
_Avoid_: « title », « name », « goal », « source » (réservé à la Coalescence des Notifications).
