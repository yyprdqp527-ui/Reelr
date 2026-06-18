// Contenu textuel des documents légaux (Politique de confidentialité et
// Conditions Générales d'Utilisation et de Vente) affichés directement
// dans l'application via LegalDocumentScreen.
//
// Versions française et anglaise. Le contenu affiché est choisi
// dynamiquement dans settings_screen.dart selon la langue active
// de l'application (appState.locale).

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


const String legalPrivacyPolicyEn = '''
# Privacy Policy — Reelr

**Last updated: June 17, 2026**

## Who we are

Reelr is published by Anne-Gaëlle Daval, operating as an individual sole proprietor (micro-entreprise) under the trade name Room79 (SIRET: 10628633900010), based at 79 Rue du Président Édouard Herriot, 69002 Lyon, France.

Contact: hello@myreelr.app

In this document, "we", "our", and "us" refer to the publisher of Reelr. "You" refers to the user of the application.

## What Reelr does, in two sentences

Reelr is a mobile app that lets you save videos you share from YouTube, Instagram, TikTok, Facebook, Twitch, or other platforms, and automatically sorts them into categories using an artificial intelligence service. Reelr does not create any user account: all your data is stored locally on your device.

## No account, no sign-up

Reelr does not ask for an email address, password, name, phone number, or any other identifying information to work. There is no login system. As a result, we do not collect or store any identifying data about you on our servers.

## Data stored locally on your device

When you share a video to Reelr, the app saves the following in a local database (present only on your phone, never permanently transmitted to our servers):

- the URL of the shared video;
- the title, description, source channel or account, and thumbnail of the video, when this information is publicly available (automatically retrieved from the video's page via the oEmbed and Open Graph standards);
- the category assigned to the video (determined automatically or chosen by you);
- the date added and the order of your custom categories.

This data stays on your device. It is automatically deleted if you uninstall the app. We do not have access to this local database and cannot view, copy, or restore it on your behalf: you remain in full control of it.

## AI processing for automatic classification

To automatically classify a video you share, Reelr sends certain metadata about that video (title, description, any tags, source platform, and a short transcript excerpt when available) to a third-party AI service, Claude, developed by Anthropic.

This data never travels directly between your phone and Anthropic: it is always relayed through an intermediary server that we operate (a "Cloudflare Worker"), whose role is to protect our technical access keys and limit abuse. This intermediary server does not retain, log, or store any of the data that passes through it: it relays it and deletes it immediately after use.

The metadata sent never includes your name, email address, or any other personal identifier: it only concerns the public content of the shared video (its title, description, etc.). Anthropic processes this data to generate a category suggestion, in accordance with its own privacy policy, available at anthropic.com/privacy.

If automatic enrichment fails (temporary outage, no connection), Reelr falls back to keyword-based classification performed locally on your device, with no data sent to any third party.

## Retrieving metadata from video platforms

To correctly display the title, thumbnail, and description of a video you share, Reelr queries the public page of that video directly on its source platform (YouTube, Instagram, TikTok, Facebook, Twitch, etc.), using the public oEmbed and Open Graph standards. This query happens at the moment of sharing, based on the URL you chose to share. We do not have access to any other information from your account on these platforms, and Reelr does not log in to any third-party account on your behalf.

## Subscription and payment

Reelr offers a paid subscription giving access to unlimited use of the app (beyond a number of videos available for free). Purchases and renewal of this subscription are entirely handled by Apple through the App Store and its built-in payment system (In-App Purchase / StoreKit). We do not receive, process, or store any payment information (card number, billing identity): this data is managed exclusively by Apple, in accordance with its own privacy policy.

We may receive a technical confirmation from Apple of your subscription status (active/inactive) in order to unlock the corresponding features in the app, but this information is not associated with a named identity on our end.

## Minimal technical data

Like any mobile app, Reelr may generate technical diagnostic logs (such as crash reports) if you consent to this through your iOS device settings. These logs are anonymized as much as possible and are only used to fix bugs.

## Your rights

Depending on where you live, you may have rights to access, correct, delete, and port your personal data (for example, under the EU General Data Protection Regulation, GDPR). Since Reelr does not collect named data on our servers (see "No account, no sign-up" above), exercising these rights mainly concerns the data stored locally on your device, which you directly control:

- Deletion: uninstalling the app immediately and completely deletes all data saved by Reelr on your device.
- Access and portability: your data is visible directly within the app at any time.

For any question about your rights or this document, you can contact us at hello@myreelr.app. If you are located in the European Union, you also have the right to lodge a complaint with your local data protection authority.

## Children's privacy

Reelr is not specifically directed at children and does not knowingly collect any identifying information about them, consistent with the general absence of named data collection described in this document.

## International data transfers

Video metadata sent to Anthropic for automatic classification (see above) may be processed on servers located outside the European Union. Anthropic provides contractual safeguards governing these transfers in accordance with the GDPR. No other named personal data is transferred outside the European Union, since no such data is otherwise collected.

## Changes to this document

We may update this privacy policy from time to time, in particular to reflect technical changes to the app. Any substantial change will be announced through an update to this page, with the date of the last revision shown at the top of this document.

## Contact

For any question about this privacy policy or your data: hello@myreelr.app
''';

const String legalTermsEn = '''
# Terms of Use and Sale — Reelr

**Last updated: June 17, 2026**

## Article 1 — Publisher identification

The Reelr application ("the App") is published by Anne-Gaëlle Daval, operating as an individual sole proprietor under the trade name Room79, registered under SIRET number 10628633900010, based at 79 Rue du Président Édouard Herriot, 69002 Lyon, France.

Contact: hello@myreelr.app

Hereinafter referred to as "the Publisher".

## Article 2 — Purpose

These Terms of Use and Sale ("Terms") govern access to and use of the Reelr App, as well as the conditions for subscribing to the paid subscription it offers. They apply to any user ("You", "the User") downloading or using the App, available on Apple's App Store.

Using the App constitutes full and complete acceptance of these Terms.

## Article 3 — Description of the service

Reelr lets you save videos shared from third-party platforms (YouTube, Instagram, TikTok, Facebook, Twitch, and others) and automatically sorts them into categories using an AI-based classification service. The App does not require creating an account; data is stored locally on the User's device, in accordance with the Privacy Policy available within the App.

## Article 4 — Free tier and paid subscription

### 4.1 Free tier

The App is accessible free of charge for up to 50 saved videos. Beyond this threshold, saving new videos requires subscribing to the plan described in Article 4.2. This threshold may be changed at any time by the Publisher; future changes do not affect videos already saved by the User.

### 4.2 Paid subscription

The Publisher offers an annual subscription priced at €29.99 (or the equivalent amount in the User's local currency, as set by Apple's pricing tiers) per year ("the Subscription"), giving access to unlimited use of the App. The applicable price is the one shown on the App's listing on the App Store at the time of subscription, and may vary by country or local currency according to Apple's pricing policy.

### 4.3 Payment terms

The purchase, renewal, and management of the Subscription are entirely handled by Apple through its built-in payment system (In-App Purchase). The Publisher does not receive, process, or retain any banking data from the User.

### 4.4 Automatic renewal

The Subscription automatically renews: unless cancelled by the User at least 24 hours before the end of the current period, the Subscription is automatically renewed for an identical duration, and the corresponding amount is charged to the payment method associated with the User's Apple account.

### 4.5 Cancellation

The User may cancel their Subscription at any time from their Apple account settings (Settings > [Name] > Subscriptions, or via the corresponding link available in the App). Cancellation takes effect at the end of the current subscription period; no pro-rata refund is provided for the period already committed to, unless otherwise required by applicable law.

### 4.6 Right of withdrawal

Depending on your jurisdiction, you may have a statutory right to withdraw from a distance purchase within a certain period (for example, 14 days for consumers in the European Union under Article L221-18 of the French Consumer Code).

However, this right of withdrawal typically does not apply to digital content not supplied on a physical medium once its performance has begun with the User's prior express consent and express waiver of the right of withdrawal (for EU consumers, under Article L221-28 13° of the French Consumer Code).

By subscribing and immediately accessing the corresponding features, the User acknowledges and expressly agrees that performance of the service begins immediately and that they accordingly waive their right of withdrawal, to the extent permitted by applicable law.

## Article 5 — User obligations

The User agrees to use the App in accordance with its intended purpose and not to infringe the rights of third parties, particularly intellectual property rights, when sharing video content. The Publisher does not host any video: the App is limited to saving links (URLs) to content hosted by third-party platforms, with the User remaining fully responsible for the lawfulness of sharing and viewing such content.

## Article 6 — Intellectual property

The App, its source code, interface, graphic elements, and brand are the exclusive property of the Publisher, with the exception of third-party content (videos, metadata, thumbnails) which remains the property of their respective rights holders. Nothing in these Terms shall be construed as granting the User any intellectual property right over the App.

## Article 7 — Availability and evolution of the service

The Publisher strives to ensure the availability and proper functioning of the App, without guaranteeing absolute continuity, particularly in the event of maintenance, outages, or unavailability of a third-party service necessary for the App's operation (video platforms, AI classification service). The Publisher reserves the right to evolve, modify, or discontinue all or part of the App's features, subject to informing subscribed Users within a reasonable time when this significantly affects the service provided.

## Article 8 — Limitation of liability

The Publisher cannot be held liable for third-party content accessible via links saved in the App, nor for category suggestions automatically generated by the AI classification service, which are provided for guidance only and may contain inaccuracies. The User remains solely responsible for the final organization of their content.

To the extent permitted by applicable law, the Publisher's liability, in the event of a proven breach of its obligations, is limited to the amount actually paid by the User for the Subscription over the preceding twelve months.

## Article 9 — Personal data protection

The processing of personal data in connection with the use of the App is described in the Privacy Policy, available within the App, which forms an integral part of these Terms.

## Article 10 — Changes to these Terms

The Publisher may modify these Terms at any time, particularly to reflect regulatory or functional changes. Subscribed Users will be informed of any substantial change through an appropriate means (in-app notification, email, or a visible update to this document) before it takes effect.

## Article 11 — Governing law and disputes

These Terms are governed by French law. In the event of a dispute, and after attempting an amicable resolution with the Publisher at hello@myreelr.app, consumer Users may have access to free consumer mediation in accordance with Articles L611-1 et seq. of the French Consumer Code, or may bring the dispute before the competent courts.

## Article 12 — Contact

For any question regarding these Terms: hello@myreelr.app
''';
