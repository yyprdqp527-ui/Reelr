// Contenu textuel des documents légaux (Politique de confidentialité et
// Conditions Générales d'Utilisation et de Vente) affichés directement
// dans l'application via LegalDocumentScreen.
//
// Version française uniquement pour l'instant. La version anglaise
// (legalPrivacyPolicyEn / legalTermsEn) reste à rédiger avant le
// lancement dans les pays non francophones.

const String legalPrivacyPolicyFr = '''
# Politique de confidentialité — Reelr

**Dernière mise à jour : 17 juin 2026**

## Qui sommes-nous

Reelr est édité par Anne-Gaëlle Daval, exerçant sous le statut de micro-entreprise individuelle, sous le nom commercial Room79 (SIRET : 10628633900010), domiciliée 79 Rue du Président Édouard Herriot, 69002 Lyon, France.

Contact : hello@myreelr.app

Dans ce document, « nous », « notre » désignent l'Éditeur de Reelr. « Vous » désigne l'utilisateur de l'application.

## Ce que fait Reelr, en deux phrases

Reelr est une application mobile qui vous permet d'enregistrer des vidéos que vous partagez depuis YouTube, Instagram, TikTok, Facebook, Twitch ou d'autres plateformes, et de les classer automatiquement par catégorie grâce à un service d'intelligence artificielle. Reelr ne crée aucun compte utilisateur : toutes vos données sont stockées localement sur votre appareil.

## Aucun compte, aucune inscription

Reelr ne vous demande ni email, ni mot de passe, ni nom, ni numéro de téléphone, ni aucune autre information d'identification pour fonctionner. Il n'existe pas de système de connexion. En conséquence, nous ne collectons et ne stockons sur nos serveurs aucune donnée d'identification vous concernant.

## Données stockées localement sur votre appareil

Lorsque vous partagez une vidéo vers Reelr, l'application enregistre dans une base de données locale (présente uniquement sur votre téléphone, jamais transmise à nos serveurs de façon permanente) :

- l'URL de la vidéo partagée ;
- le titre, la description, la chaîne ou le compte d'origine, et la miniature de la vidéo, lorsque ces informations sont disponibles publiquement (récupérées automatiquement depuis la page de la vidéo, via les standards oEmbed et Open Graph) ;
- la catégorie attribuée à la vidéo (déterminée automatiquement ou choisie par vous) ;
- la date d'ajout et l'ordre de vos catégories personnalisées.

Ces données restent sur votre appareil. Elles sont supprimées automatiquement si vous désinstallez l'application. Nous n'avons pas accès à cette base de données locale et ne pouvons pas la consulter, la copier ou la restaurer pour vous : sa gestion vous appartient entièrement.

## Traitement par intelligence artificielle pour la classification automatique

Pour classer automatiquement une vidéo que vous partagez, Reelr transmet certaines métadonnées de cette vidéo (titre, description, éventuels tags, plateforme d'origine, et un court extrait de transcription lorsqu'il est disponible) à un service tiers d'intelligence artificielle, Claude, développé par Anthropic.

Ce transfert ne passe jamais directement entre votre téléphone et Anthropic : il est systématiquement relayé par un serveur intermédiaire que nous exploitons (un « Cloudflare Worker »), dont le rôle est de protéger nos clés d'accès techniques et de limiter les abus. Ce serveur intermédiaire ne conserve, ne journalise et n'enregistre aucune des données qui transitent par lui : il les relaie et les efface immédiatement après usage.

Les métadonnées transmises ne comprennent jamais votre nom, votre email, ou tout autre identifiant personnel : elles concernent uniquement le contenu public de la vidéo partagée (son titre, sa description, etc.). Anthropic traite ces données pour générer une suggestion de catégorie, conformément à sa propre politique de confidentialité, disponible sur anthropic.com/privacy.

Si l'enrichissement automatique échoue (panne temporaire, absence de connexion), Reelr utilise un classement de secours fondé sur une reconnaissance de mots-clés effectuée localement sur votre appareil, sans transmission à un tiers.

## Récupération de métadonnées depuis les plateformes vidéo

Pour afficher correctement le titre, la miniature et la description d'une vidéo que vous partagez, Reelr interroge directement la page publique de cette vidéo sur la plateforme d'origine (YouTube, Instagram, TikTok, Facebook, Twitch, etc.), via les standards publics oEmbed et Open Graph. Cette interrogation se fait au moment du partage, à partir de l'URL que vous avez vous-même choisi de partager. Nous n'avons accès à aucune autre information de votre compte sur ces plateformes, et Reelr ne se connecte à aucun compte tiers en votre nom.

## Abonnement et paiement

Reelr propose un abonnement payant donnant accès à un usage illimité de l'application (au-delà d'un nombre de vidéos disponible gratuitement). Les achats et le renouvellement de cet abonnement sont intégralement gérés par Apple via l'App Store et le système de paiement intégré (In-App Purchase / StoreKit). Nous ne recevons, ne traitons et ne stockons aucune information de paiement (numéro de carte bancaire, identité de facturation) : ces données sont gérées exclusivement par Apple, conformément à sa propre politique de confidentialité.

Nous pouvons recevoir d'Apple une confirmation technique du statut de votre abonnement (actif/inactif) afin de déverrouiller les fonctionnalités correspondantes dans l'application, mais cette information n'est pas associée à une identité nominative de notre côté.

## Données techniques minimales

Comme toute application mobile, Reelr peut générer des journaux techniques de diagnostic (rapports de plantage, par exemple) si vous y consentez via les réglages de votre appareil iOS. Ces journaux sont anonymisés autant que possible et ne sont utilisés que pour corriger des bugs.

## Vos droits

Conformément au Règlement Général sur la Protection des Données (RGPD), vous disposez d'un droit d'accès, de rectification, d'effacement et de portabilité sur vos données personnelles. Dans la mesure où Reelr ne collecte pas de données nominatives sur nos serveurs (voir « Aucun compte, aucune inscription » ci-dessus), l'exercice de ces droits porte principalement sur les données stockées localement sur votre appareil, que vous contrôlez directement :

- Suppression : désinstaller l'application supprime intégralement et immédiatement toutes les données enregistrées par Reelr sur votre appareil.
- Accès et portabilité : vos données sont visibles directement dans l'application, à tout moment.

Pour toute question relative à vos droits ou à ce document, vous pouvez nous contacter à hello@myreelr.app. Vous disposez également du droit d'introduire une réclamation auprès de la Commission Nationale de l'Informatique et des Libertés (CNIL), autorité de contrôle française, sur cnil.fr.

## Protection des mineurs

Reelr ne s'adresse pas spécifiquement aux enfants et ne collecte sciemment aucune information identifiante les concernant, conformément à l'absence générale de collecte de données nominatives décrite dans ce document.

## Transferts internationaux de données

Les métadonnées de vidéos transmises à Anthropic dans le cadre de la classification automatique (voir ci-dessus) peuvent être traitées sur des serveurs situés hors de l'Union européenne. Anthropic propose des garanties contractuelles encadrant ces transferts conformément au RGPD. Aucune autre donnée personnelle nominative n'est transférée hors de l'Union européenne, puisqu'aucune telle donnée n'est collectée par ailleurs.

## Modifications de ce document

Nous pouvons mettre à jour cette politique de confidentialité, notamment pour refléter une évolution technique de l'application. Toute modification substantielle sera annoncée via une mise à jour de cette page, avec indication de la date de dernière modification en haut de ce document.

## Contact

Pour toute question relative à cette politique de confidentialité ou à vos données : hello@myreelr.app
''';

const String legalTermsFr = '''
# Conditions Générales d'Utilisation et de Vente — Reelr

**Dernière mise à jour : 17 juin 2026**

## Article 1 — Identification de l'éditeur

L'application Reelr (« l'Application ») est éditée par Anne-Gaëlle Daval, exerçant en tant que micro-entrepreneur individuel sous le nom commercial Room79, immatriculée sous le numéro SIRET 10628633900010, domiciliée 79 Rue du Président Édouard Herriot, 69002 Lyon, France.

Contact : hello@myreelr.app

Ci-après désignée « l'Éditeur ».

## Article 2 — Objet

Les présentes Conditions Générales d'Utilisation et de Vente (« CGU/CGV ») régissent l'accès et l'utilisation de l'Application Reelr, ainsi que les conditions de souscription à l'abonnement payant qu'elle propose. Elles s'appliquent à tout utilisateur (« Vous », « l'Utilisateur ») téléchargeant ou utilisant l'Application, disponible sur l'App Store d'Apple.

L'utilisation de l'Application implique l'acceptation pleine et entière des présentes CGU/CGV.

## Article 3 — Description du service

Reelr permet d'enregistrer des vidéos partagées depuis des plateformes tierces (YouTube, Instagram, TikTok, Facebook, Twitch, et d'autres) et de les classer automatiquement par catégorie grâce à un service de classification par intelligence artificielle. L'Application ne nécessite pas de création de compte ; les données sont stockées localement sur l'appareil de l'Utilisateur, conformément à la Politique de confidentialité accessible dans l'Application.

## Article 4 — Accès gratuit et abonnement payant

### 4.1 Palier gratuit

L'Application est accessible gratuitement jusqu'à un volume de 50 vidéos enregistrées. Au-delà de ce seuil, l'accès à l'enregistrement de nouvelles vidéos est conditionné à la souscription de l'abonnement décrit à l'article 4.2. Ce seuil peut être modifié à tout moment par l'Éditeur ; les modifications futures n'affectent pas les vidéos déjà enregistrées par l'Utilisateur.

### 4.2 Abonnement payant

L'Éditeur propose un abonnement annuel au tarif de 29,99 € TTC par an (« l'Abonnement »), donnant accès à un usage illimité de l'Application. Le tarif applicable est celui affiché sur la fiche de l'Application sur l'App Store au moment de la souscription, et peut varier selon le pays ou la devise locale en fonction de la politique de tarification d'Apple.

### 4.3 Modalités de paiement

L'achat, le renouvellement et la gestion de l'Abonnement sont intégralement pris en charge par Apple via son système de paiement intégré (In-App Purchase). L'Éditeur ne reçoit, ne traite et ne conserve aucune donnée bancaire de l'Utilisateur.

### 4.4 Renouvellement automatique

L'Abonnement est à renouvellement automatique : sauf résiliation par l'Utilisateur au moins 24 heures avant la fin de la période en cours, l'Abonnement est automatiquement renouvelé pour une durée identique, et le montant correspondant est prélevé sur le moyen de paiement associé au compte Apple de l'Utilisateur.

### 4.5 Résiliation

L'Utilisateur peut résilier son Abonnement à tout moment depuis les réglages de son compte Apple (Réglages > [Nom] > Abonnements, ou via le lien correspondant disponible dans l'Application). La résiliation prend effet à la fin de la période d'abonnement en cours ; aucun remboursement au prorata n'est effectué pour la période déjà engagée, sauf disposition légale contraire.

### 4.6 Droit de rétractation

Conformément à l'article L221-18 du Code de la consommation, l'Utilisateur consommateur dispose en principe d'un délai de 14 jours pour exercer son droit de rétractation sur un achat à distance.

Toutefois, conformément à l'article L221-28 13° du Code de la consommation, ce droit de rétractation ne peut être exercé pour la fourniture d'un contenu numérique non fourni sur un support matériel dont l'exécution a commencé après accord préalable exprès de l'Utilisateur et renoncement exprès à son droit de rétractation.

En souscrivant à l'Abonnement et en accédant immédiatement aux fonctionnalités correspondantes, l'Utilisateur reconnaît et accepte expressément que l'exécution du service commence immédiatement et renonce, de ce fait, à son droit de rétractation.

## Article 5 — Obligations de l'Utilisateur

L'Utilisateur s'engage à utiliser l'Application conformément à sa destination et à ne pas porter atteinte aux droits des tiers, notamment en matière de propriété intellectuelle, lors du partage de contenus vidéo. L'Éditeur n'héberge aucune vidéo : l'Application se limite à enregistrer des liens (URL) vers des contenus hébergés par des plateformes tierces, sous l'entière responsabilité de l'Utilisateur quant à la licéité de leur partage et de leur consultation.

## Article 6 — Propriété intellectuelle

L'Application, son code source, son interface, ses éléments graphiques et sa marque sont la propriété exclusive de l'Éditeur, à l'exception des contenus tiers (vidéos, métadonnées, miniatures) qui restent la propriété de leurs ayants droit respectifs. Aucune disposition des présentes CGU/CGV ne saurait être interprétée comme cédant à l'Utilisateur un quelconque droit de propriété intellectuelle sur l'Application.

## Article 7 — Disponibilité et évolution du service

L'Éditeur s'efforce d'assurer la disponibilité et le bon fonctionnement de l'Application, sans garantie de continuité absolue, notamment en cas de maintenance, de panne, ou d'indisponibilité d'un service tiers nécessaire au fonctionnement de l'Application (plateformes vidéo, service de classification par intelligence artificielle). L'Éditeur se réserve le droit de faire évoluer, modifier ou interrompre tout ou partie des fonctionnalités de l'Application, sous réserve d'en informer les Utilisateurs abonnés dans un délai raisonnable lorsque cela affecte significativement le service rendu.

## Article 8 — Limitation de responsabilité

L'Éditeur ne saurait être tenu responsable des contenus tiers accessibles via les liens enregistrés dans l'Application, ni des suggestions de classification générées automatiquement par le service d'intelligence artificielle, lesquelles sont fournies à titre indicatif et peuvent comporter des inexactitudes. L'Utilisateur reste seul responsable de l'organisation finale de ses contenus.

Dans les limites permises par la loi applicable, la responsabilité de l'Éditeur, en cas de manquement avéré à ses obligations, est limitée au montant effectivement payé par l'Utilisateur au titre de l'Abonnement au cours des douze derniers mois.

## Article 9 — Protection des données personnelles

Le traitement des données personnelles dans le cadre de l'utilisation de l'Application est décrit dans la Politique de confidentialité, accessible depuis l'Application, qui fait partie intégrante des présentes CGU/CGV.

## Article 10 — Modification des CGU/CGV

L'Éditeur peut modifier les présentes CGU/CGV à tout moment, notamment pour refléter une évolution réglementaire ou fonctionnelle. Les Utilisateurs abonnés seront informés de toute modification substantielle par un moyen approprié (notification dans l'Application, email, ou mise à jour visible de ce document) avant son entrée en vigueur.

## Article 11 — Droit applicable et litiges

Les présentes CGU/CGV sont soumises au droit français. En cas de litige, et après tentative de résolution amiable auprès de l'Éditeur à l'adresse hello@myreelr.app, l'Utilisateur consommateur peut recourir gratuitement à un médiateur de la consommation conformément aux articles L611-1 et suivants du Code de la consommation, ou porter le litige devant les juridictions compétentes.

## Article 12 — Contact

Pour toute question relative aux présentes CGU/CGV : hello@myreelr.app
''';
