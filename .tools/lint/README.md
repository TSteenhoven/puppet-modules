# Puppet-code, lintcontroles en hergebruik

<a id="puppet-lint-en-rubocop"></a>

## Doel en reikwijdte

Deze handleiding beschrijft hoe je Puppet-code voor de repository `puppet-modules` schrijft en controleert. Je vindt hier de codeafspraken, de dagelijkse werkwijze en de controles die daarbij helpen. Ook lees je hoe je die controles in een ander Puppet-project gebruikt en hoe je ze onderhoudt.

**Puppet-lint** is een extern controleprogramma dat Puppet-broncode leest en afwijkingen van codeafspraken meldt. Zo'n programma heet een linter; iedere afzonderlijke controle heet een check. Je start het met het commando `puppet-lint`. Het programma heeft standaardchecks en kan extra checks uit uitbreidingen laden.

Voor deze repository zijn zulke uitbreidingen en de bijbehorende configuratie verzameld in **`lint-project`**, ons eigen Ruby-pakket, ook wel een gem genoemd. Dit pakket gebruikt Puppet-lint als controleprogramma en voegt de `project_*`-checks toe voor onder meer parameters, documentatie, bestandsrechten en shellcommando's. Daarnaast installeert het twee externe lintplugins. Je blijft de controles starten met `puppet-lint`; de projectconfiguratie laadt onze uitbreiding en bepaalt samen met het gedeelde regelprofiel welke checks en opties actief zijn.

`lint-project` brengt ook de aanvullende validatie bij elkaar. Het installeert [RuboCop](#ruby-code-controleren) voor de eigen Ruby-code, waaronder de projectchecks en tooltests, en levert een gedeeld RuboCop-profiel mee. Voor [Puppet-parservalidatie](#puppet-manifests-valideren) installeert het de native parser en levert het `puppet-validate-junit`, dat per manifest de syntax controleert en een JUnit XML-testrapport maakt. Puppet-lint, RuboCop en parservalidatie hebben ieder hun eigen commando. De [tooltests](#tests-uitvoeren-en-uitbreiden) controleren de werking van de checks, automatische correcties en installatie vanuit andere projecten.

De codeafspraken in deze README vormen de norm. De configuratie bepaalt welke controles actief zijn; de implementatie bepaalt wat die controles feitelijk herkennen en automatisch kunnen corrigeren. Tests onderbouwen uitsluitend de scenario's die zij uitvoeren. De onderhouds- en werkafspraken staan in [`AGENTS.md`](../../AGENTS.md); dat bestand bevat geen tweede verzameling Puppet-normen.

Een groene lintscan bewijst geen volledige normnaleving, geldige catalogus of correct runtimegedrag. Bij ontbrekende automatische dekking blijft de norm gelden en is handmatige review vereist. Bij strijdigheid beschrijf je norm en waargenomen gedrag afzonderlijk en registreer je het conflict in de oplevering; pas de norm of implementatie niet aan als redactionele oplossing. Corrigeer een feitelijk onjuiste CLI-beschrijving alleen met uitvoerbewijs. Behoud onduidelijke normen letterlijk en markeer de precieze onzekerheid. Een niet-uitgevoerde verplichte controle of onopgelost normconflict verhindert de eindstatus `Afgerond`.

## Leeswijzer

Gebruik je de tooling voor het eerst, begin dan bij de snelstart voor [deze repository](#snelstart-in-deze-repository) of [je eigen Puppet-project](#snelstart-in-een-ander-puppet-project). Voor een wijziging volg je de [dagelijkse werkwijze](#werkwijze-bij-een-wijziging). De tabel verwijst naar de onderwerpen die je wijziging raakt; de vijf taakroutes eronder verbinden die naslag met de benodigde stappen. Je hoeft de overige gespecialiseerde naslag niet vooraf door te nemen. Komt tijdens je werk een nieuwe afhankelijkheid of integratie in beeld, neem dan de bijbehorende sectie erbij.

| Je taak | Lees hierbij |
| --- | --- |
| Een normaal Puppet-manifest aanpassen | [Basisopmaak](#basisopmaak), [parameters en resources](#parameters-en-resources) en [toelichtingen bij code](#toelichtingen-bij-code). |
| Puppet Strings aanpassen | [Puppet Strings](#puppet-strings), [lange regels](#lange-regels) en [waar de uitleg hoort](#waar-de-uitleg-hoort). |
| Resources of dependencies aanpassen | [Resources en afhankelijkheden](#resources-en-afhankelijkheden), [resource references](#resource-references) en [volgorde en meldingen](#volgorde-en-meldingen). |
| Bestanden, privileges of shellcommando's aanpassen | [Bestanden en beveiliging](#bestanden-en-beveiliging) en de [algemene beveiligingsreview](../../AGENTS.md#security-and-privacy). |
| Een shellscript, Bash-script, shelltemplate of bijbehorende runtime-dependency aanpassen | [Shellscripts](#shellscripts) en de [algemene shellconventies](../../AGENTS.md#shell-scripts), inclusief [native tools en dependencies](../../AGENTS.md#native-tools-and-dependencies). |
| Een monitoringcheck of registratie aanpassen | [Monitoringchecks](#monitoringchecks), [targets en monitoring](#targets-en-monitoring) en de [monitoringcontracten](../../AGENTS.md#monitoring-checks). |
| Systemd-integratie aanpassen | [Gedeelde services en systemd](#gedeelde-services-en-systemd), inclusief de beoordeling per service. |
| Een lintmelding oplossen | [Een melding oplossen](#een-melding-oplossen); zoek de checknaam in het [checkoverzicht](#beschikbare-projectchecks). |
| Autofix uitvoeren | [Automatisch corrigeren](#automatisch-corrigeren-autofix) en de voorwaarden bij de betrokken check. |
| Ruby-code controleren of veilig corrigeren | [RuboCop gebruiken](#ruby-code-controleren). |
| Rapporten maken of een CI-uitslag onderzoeken | [Puppet-manifests valideren](#puppet-manifests-valideren), [lintrapporten maken](#lintrapporten-maken), [tooltests uitvoeren](#tests-uitvoeren-en-uitbreiden) en [CI van deze repository](#ci-van-deze-repository). |
| Een bestaande lintcheck aanpassen | [Een check toevoegen of wijzigen](#een-check-toevoegen-of-wijzigen) en de bijbehorende [technische werking](#technische-werking-van-de-checks). |
| Een nieuwe lintcheck of autofix ontwikkelen | [Linter ontwikkelen en onderhouden](#linter-ontwikkelen-en-onderhouden), inclusief [veilige autofixes](#veilige-autofixes-ontwikkelen). |
| De centrale linter in een ander Puppet-project gebruiken | [Gedeelde tooling hergebruiken](#gedeelde-tooling-hergebruiken), [aanbevolen projectstructuur](#aanbevolen-projectstructuur) en [installatie](#installatie-in-je-project). |
| Validatie, linting, tests en artifacts in een project met `global-modules` inrichten | [Een eigen rapportmap kiezen](#rapportmap-kiezen), [eigen code controleren](#eigen-code-controleren), [eigen manifests valideren](#eigen-manifests-valideren), [eigen tooltests](#eigen-tooltests), [rapporten en artifacts](#rapporten-en-artifacts-in-je-project) en het [CI-voorbeeld](#controle-in-ci). |

### Puppet-code wijzigen

Begin met de scan uit [Snelstart in deze repository](#snelstart-in-deze-repository). Pas bij je wijziging de relevante [Puppet-coderegels en reviewcriteria](#puppet-coderegels-en-reviewcriteria) toe en sluit af met de [Eindcontrole](#eindcontrole).

### Een lintmelding oplossen

Zoek de checknaam op in het [Checkregister](#checkregister) en lees de gekoppelde regel. [Meldingen, severity en exitcodes](#meldingen-severity-en-exitcodes) legt de uitvoer en foutstatus uit; bij installatie- of configuratieproblemen helpt [Problemen oplossen](#problemen-oplossen).

### Een autofix beoordelen

Lees bij de betrokken [Puppet-coderegel](#puppet-coderegels-en-reviewcriteria) welke correcties zijn toegestaan en wanneer de check ze weigert. Volg daarna [Autofix en suppressions](#autofix-en-suppressions) voor het uitvoeren van de correctie, de diffreview en de hercontrole.

### Een ander project aansluiten

Richt eerst een eigen bundle en configuratie in met [Snelstart in een ander Puppet-project](#snelstart-in-een-ander-puppet-project). [Importeren en distribueren](#importeren-en-distribueren) werkt de drie installatieroutes uit; met [Rapportage en CI](#rapportage-en-ci) neem je de controles op in je eigen pipeline.

### De linter onderhouden

Volg [Linter ontwikkelen en testen](#linter-ontwikkelen-en-testen) voor wijzigingen aan de projectchecks of tooling. Werk de bijbehorende uitleg bij volgens het [Documentatiecontract voor maintainers](#documentatiecontract-voor-maintainers) en voer de [Eindcontrole](#eindcontrole) uit.

## Inhoudsopgave

- [Doel en reikwijdte](#doel-en-reikwijdte)
- [Leeswijzer](#leeswijzer)
  - [Puppet-code wijzigen](#puppet-code-wijzigen)
  - [Een lintmelding oplossen](#een-lintmelding-oplossen)
  - [Een autofix beoordelen](#een-autofix-beoordelen)
  - [Een ander project aansluiten](#een-ander-project-aansluiten)
  - [De linter onderhouden](#de-linter-onderhouden)
- [Inhoudsopgave](#inhoudsopgave)
- [Snelstart in deze repository](#snelstart-in-deze-repository)
  - [Werkwijze bij een wijziging](#werkwijze-bij-een-wijziging)
- [Snelstart in een ander Puppet-project](#snelstart-in-een-ander-puppet-project)
- [Installatie en compatibiliteit](#installatie-en-compatibiliteit)
  - [Benodigde omgeving](#benodigde-omgeving)
  - [Installatie](#installatie)
  - [Ruby op macOS](#ruby-op-macos)
  - [Gems installeren](#gems-installeren)
  - [Compatibiliteitslagen](#compatibiliteitslagen)
- [Configuratie, bestandsselectie en modulepad](#configuratie-bestandsselectie-en-modulepad)
  - [Werking van de controles](#werking-van-de-controles)
  - [Eigen lintconfiguratie](#eigen-lintconfiguratie)
  - [Aanroepen van modules controleren](#aanroepen-van-modules-controleren)
  - [Gecontroleerde configuratie- en selectiescenario’s](#gecontroleerde-configuratie--en-selectiescenarios)
- [Commando's en opties](#commandos-en-opties)
  - [Native opties](#native-opties)
  - [Reporterargumenten](#reporterargumenten)
  - [Omgevingsvariabelen](#omgevingsvariabelen)
- [Meldingen, severity en exitcodes](#meldingen-severity-en-exitcodes)
  - [Een melding oplossen](#een-melding-oplossen)
  - [Exitcodes van Puppet-lint](#exitcodes-van-puppet-lint)
  - [Exitcodes van puppet-lint-junit](#exitcodes-van-puppet-lint-junit)
  - [Exitcodes van puppet-validate-junit](#exitcodes-van-puppet-validate-junit)
  - [Overige validatiecommando's](#overige-validatiecommandos)
- [Checkregister](#checkregister)
  - [Beschikbare projectchecks](#beschikbare-projectchecks)
  - [Native checks in deze bundle](#native-checks-in-deze-bundle)
  - [Pluginchecks in deze bundle](#pluginchecks-in-deze-bundle)
- [Puppet-coderegels en reviewcriteria](#puppet-coderegels-en-reviewcriteria)
  - [Basisopmaak](#basisopmaak)
    - [Twee spaties per inspringniveau](#twee-spaties-per-inspringniveau)
    - [Resourcepijlen uitlijnen](#resourcepijlen-uitlijnen)
    - [Aanhalingstekens bij stringinhoud kiezen](#aanhalingstekens-bij-stringinhoud-kiezen)
    - [Selectors vóór resources berekenen](#selectors-vóór-resources-berekenen)
    - [Functionele resourcevolgorde beoordelen](#functionele-resourcevolgorde-beoordelen)
      - [Gedeelde dekking van basisopmaak](#gedeelde-dekking-van-basisopmaak)
  - [Inspringing](#inspringing)
    - [Verdieping bij Inspringing](#verdieping-bij-inspringing)
  - [Komma's](#kommas)
    - [Spatie na komma’s](#spatie-na-kommas)
    - [Meerregelige lijsten met een komma afsluiten](#meerregelige-lijsten-met-een-komma-afsluiten)
      - [Verdieping bij Meerregelige lijsten met een komma afsluiten](#verdieping-bij-meerregelige-lijsten-met-een-komma-afsluiten)
  - [Lange regels](#lange-regels)
    - [Verdieping bij Lange regels](#verdieping-bij-lange-regels)
    - [Alleen toegestane suppressions gebruiken](#alleen-toegestane-suppressions-gebruiken)
  - [Parameters en resources](#parameters-en-resources)
    - [Parameters en instellingen](#parameters-en-instellingen)
    - [Classes en defines bruikbaar ontwerpen](#classes-en-defines-bruikbaar-ontwerpen)
    - [Publieke parameters expliciet typeren](#publieke-parameters-expliciet-typeren)
    - [Parameters met defaultafhankelijkheden sorteren](#parameters-met-defaultafhankelijkheden-sorteren)
      - [Verdieping bij Parameters met defaultafhankelijkheden sorteren](#verdieping-bij-parameters-met-defaultafhankelijkheden-sorteren)
    - [Parameterblokken volledig uitlijnen](#parameterblokken-volledig-uitlijnen)
    - [Beveiligingsinstellingen met één waardekeuze modelleren](#beveiligingsinstellingen-met-één-waardekeuze-modelleren)
    - [Parameternamen op onderwerp kiezen](#parameternamen-op-onderwerp-kiezen)
    - [Voorwaarden en validatie](#voorwaarden-en-validatie)
    - [De grootste verwerking vóór de korte afhandeling plaatsen](#de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen)
      - [Verdieping bij De grootste verwerking vóór de korte afhandeling plaatsen](#verdieping-bij-de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen)
    - [Validatie om haar afhankelijke implementatie plaatsen](#validatie-om-haar-afhankelijke-implementatie-plaatsen)
    - [Ruwe en geërfde waarden in templates onderscheiden](#ruwe-en-geërfde-waarden-in-templates-onderscheiden)
    - [Optionele waarden alleen bij gebruik valideren](#optionele-waarden-alleen-bij-gebruik-valideren)
    - [Classcontroles hergebruiken](#classcontroles-hergebruiken)
      - [Verdieping bij Classcontroles hergebruiken](#verdieping-bij-classcontroles-hergebruiken)
    - [Parentclass als prerequisite controleren](#parentclass-als-prerequisite-controleren)
    - [Resources en afhankelijkheden](#resources-en-afhankelijkheden)
    - [Optionele resource-attributen vooraf bepalen](#optionele-resource-attributen-vooraf-bepalen)
    - [Arrays met concat combineren](#arrays-met-concat-combineren)
    - [Bestaande interfaces voor integratiewaarden gebruiken](#bestaande-interfaces-voor-integratiewaarden-gebruiken)
    - [Dependencies pas na een geslaagde controle koppelen](#dependencies-pas-na-een-geslaagde-controle-koppelen)
    - [Prerequisites van ordering onderscheiden](#prerequisites-van-ordering-onderscheiden)
    - [Gedeelde voorwaarden om resources groeperen](#gedeelde-voorwaarden-om-resources-groeperen)
    - [Aanroepen en publieke interfaces](#aanroepen-en-publieke-interfaces)
    - [Alle verplichte argumenten doorgeven](#alle-verplichte-argumenten-doorgeven)
      - [Verdieping bij Alle verplichte argumenten doorgeven](#verdieping-bij-alle-verplichte-argumenten-doorgeven)
    - [Overbodige parameterdoorgifte rechtstreeks schrijven](#overbodige-parameterdoorgifte-rechtstreeks-schrijven)
      - [Verdieping bij Overbodige parameterdoorgifte rechtstreeks schrijven](#verdieping-bij-overbodige-parameterdoorgifte-rechtstreeks-schrijven)
    - [Resource references](#resource-references)
    - [References van hetzelfde type samenvoegen](#references-van-hetzelfde-type-samenvoegen)
      - [Verdieping bij References van hetzelfde type samenvoegen](#verdieping-bij-references-van-hetzelfde-type-samenvoegen)
    - [Titels in resource references sorteren](#titels-in-resource-references-sorteren)
    - [Een overbodige buitenste dependency-array verwijderen](#een-overbodige-buitenste-dependency-array-verwijderen)
    - [Resourcelijsten hergebruiken](#resourcelijsten-hergebruiken)
      - [Verdieping bij Resourcelijsten hergebruiken](#verdieping-bij-resourcelijsten-hergebruiken)
    - [Resource-dependencies opbouwen](#resource-dependencies-opbouwen)
      - [Verdieping bij Resource-dependencies opbouwen](#verdieping-bij-resource-dependencies-opbouwen)
    - [Volgorde en meldingen](#volgorde-en-meldingen)
    - [Resources bij hun voorziening plaatsen](#resources-bij-hun-voorziening-plaatsen)
    - [Relaties en meldingen behouden](#relaties-en-meldingen-behouden)
    - [Instellingen bij hun eigenaar houden](#instellingen-bij-hun-eigenaar-houden)
  - [Commentaar en documentatie](#commentaar-en-documentatie)
    - [Toelichtingen bij code](#toelichtingen-bij-code)
    - [Toelichtingsblokken van eerdere code scheiden](#toelichtingsblokken-van-eerdere-code-scheiden)
      - [Verdieping bij Toelichtingsblokken van eerdere code scheiden](#verdieping-bij-toelichtingsblokken-van-eerdere-code-scheiden)
    - [Inhoud direct na een openingsaccolade beginnen](#inhoud-direct-na-een-openingsaccolade-beginnen)
    - [Een resource na een afgesloten blok toelichten](#een-resource-na-een-afgesloten-blok-toelichten)
    - [Bestaande implementatie-uitleg actueel houden](#bestaande-implementatie-uitleg-actueel-houden)
    - [Niet-zichtbare implementatiekeuzes toelichten](#niet-zichtbare-implementatiekeuzes-toelichten)
    - [Codecommentaar in Engelse zinnen schrijven](#codecommentaar-in-engelse-zinnen-schrijven)
    - [Voorwaarden toelichten](#voorwaarden-toelichten)
      - [Verdieping bij Voorwaarden toelichten](#verdieping-bij-voorwaarden-toelichten)
    - [Variabelen groeperen](#variabelen-groeperen)
    - [Een variabelegroep bij blokbegin toelichten](#een-variabelegroep-bij-blokbegin-toelichten)
    - [Een onafhankelijke groep na afhankelijke waarden beginnen](#een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen)
      - [Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen)
    - [Puppet Strings](#puppet-strings)
    - [Publieke declaraties bij de code documenteren](#publieke-declaraties-bij-de-code-documenteren)
      - [Verdieping bij Publieke declaraties bij de code documenteren](#verdieping-bij-publieke-declaraties-bij-de-code-documenteren)
    - [Strings API-markering](#strings-api-markering)
    - [Strings-summary op één regel](#strings-summary-op-één-regel)
    - [Strings-parametercontract](#strings-parametercontract)
    - [Uitvoerbare Strings-voorbeelden](#uitvoerbare-strings-voorbeelden)
      - [Verdieping bij Uitvoerbare Strings-voorbeelden](#verdieping-bij-uitvoerbare-strings-voorbeelden)
    - [Strings-regelbreedte](#strings-regelbreedte)
      - [Verdieping bij Strings-regelbreedte](#verdieping-bij-strings-regelbreedte)
    - [Strings-taginspringing](#strings-taginspringing)
    - [Strings-secties met commentregels scheiden](#strings-secties-met-commentregels-scheiden)
      - [Verdieping bij Strings-secties met commentregels scheiden](#verdieping-bij-strings-secties-met-commentregels-scheiden)
    - [Lengtesuppressions in Strings begrenzen](#lengtesuppressions-in-strings-begrenzen)
    - [Waar de uitleg hoort](#waar-de-uitleg-hoort)
    - [Interfacebeschrijvingen synchroniseren](#interfacebeschrijvingen-synchroniseren)
    - [Documentatie op haar aangewezen plaats onderhouden](#documentatie-op-haar-aangewezen-plaats-onderhouden)
    - [Uitvoerbare voorbeeldscenario’s onderhouden](#uitvoerbare-voorbeeldscenarios-onderhouden)
  - [Bestanden en beveiliging](#bestanden-en-beveiliging)
    - [Templates en bestandsbronnen](#templates-en-bestandsbronnen)
    - [Gegenereerde configuratie met ERB renderen](#gegenereerde-configuratie-met-erb-renderen)
    - [Puppet-fileservermounts expliciet kiezen](#puppet-fileservermounts-expliciet-kiezen)
      - [Verdieping bij Puppet-fileservermounts expliciet kiezen](#verdieping-bij-puppet-fileservermounts-expliciet-kiezen)
    - [Pakketten en mappen](#pakketten-en-mappen)
    - [APT-opties expliciet afsluiten](#apt-opties-expliciet-afsluiten)
      - [Verdieping bij APT-opties expliciet afsluiten](#verdieping-bij-apt-opties-expliciet-afsluiten)
    - [Gelijk ingestelde packageguards samenvoegen](#gelijk-ingestelde-packageguards-samenvoegen)
      - [Verdieping bij Gelijk ingestelde packageguards samenvoegen](#verdieping-bij-gelijk-ingestelde-packageguards-samenvoegen)
    - [Mappen en bestanden in gemengde bomen apart beheren](#mappen-en-bestanden-in-gemengde-bomen-apart-beheren)
    - [Recursieve bewerkingen tot module-eigendom beperken](#recursieve-bewerkingen-tot-module-eigendom-beperken)
    - [Eigenaars en rechten](#eigenaars-en-rechten)
      - [Verdieping bij Eigenaars en rechten](#verdieping-bij-eigenaars-en-rechten)
    - [Toegang via diensten en rapporten beoordelen](#toegang-via-diensten-en-rapporten-beoordelen)
    - [Privétoegang en uitvoerrechten onderbouwen](#privétoegang-en-uitvoerrechten-onderbouwen)
    - [Shellcommando's in Puppet](#shellcommandos-in-puppet)
      - [Verdieping bij Shellcommando's in Puppet](#verdieping-bij-shellcommandos-in-puppet)
    - [Dynamische tekst met passende uitvoer verwerken](#dynamische-tekst-met-passende-uitvoer-verwerken)
    - [SQL als volledige shellwaarde doorgeven](#sql-als-volledige-shellwaarde-doorgeven)
    - [Quoting per parserlaag toepassen](#quoting-per-parserlaag-toepassen)
    - [Shellsyntaxis tegen Puppet-interpolatie beschermen](#shellsyntaxis-tegen-puppet-interpolatie-beschermen)
    - [Afhankelijkheden, audit en transport](#afhankelijkheden-audit-en-transport)
    - [Lokale integraties en runtimeafhankelijkheden kiezen](#lokale-integraties-en-runtimeafhankelijkheden-kiezen)
    - [Audituitzonderingen onderbouwen](#audituitzonderingen-onderbouwen)
    - [Transportversleuteling behouden](#transportversleuteling-behouden)
    - [Een minder streng beveiligingsmodel toelichten](#een-minder-streng-beveiligingsmodel-toelichten)
  - [Gedeelde services en systemd](#gedeelde-services-en-systemd)
    - [Targets en monitoring](#targets-en-monitoring)
      - [Verdieping bij Targets en monitoring](#verdieping-bij-targets-en-monitoring)
    - [Monitoring via het centrale agentmodel registreren](#monitoring-via-het-centrale-agentmodel-registreren)
    - [Uiteindelijke systemd-units volledig reviewen](#uiteindelijke-systemd-units-volledig-reviewen)
    - [Gedeelde targets en service-integratie behouden](#gedeelde-targets-en-service-integratie-behouden)
    - [Servicebeveiliging](#servicebeveiliging)
    - [Beveiligingsopties op de uitvoerende service zetten](#beveiligingsopties-op-de-uitvoerende-service-zetten)
    - [Servicebeperkingen tegen alle uitvoerpaden beoordelen](#servicebeperkingen-tegen-alle-uitvoerpaden-beoordelen)
    - [Hardeningbesluiten per optie vastleggen](#hardeningbesluiten-per-optie-vastleggen)
    - [Umask per service expliciet kiezen](#umask-per-service-expliciet-kiezen)
    - [Wrapperdefaults voor alle afnemers beoordelen](#wrapperdefaults-voor-alle-afnemers-beoordelen)
  - [Shellscripts](#shellscripts)
    - [Shellbron en gegenereerde shell controleren](#shellbron-en-gegenereerde-shell-controleren)
    - [Runtime-tools op hun functie beoordelen](#runtime-tools-op-hun-functie-beoordelen)
    - [Puppet-waarden rechtstreeks in shelltemplates invoegen](#puppet-waarden-rechtstreeks-in-shelltemplates-invoegen)
    - [Daemonconfiguratie als invoerbron behouden](#daemonconfiguratie-als-invoerbron-behouden)
  - [Monitoringchecks](#monitoringchecks)
    - [Packages voor externe commando's](#packages-voor-externe-commandos)
    - [Invoer en configuratie](#invoer-en-configuratie)
    - [Optionele monitoringdefaults in het executable houden](#optionele-monitoringdefaults-in-het-executable-houden)
    - [Effectieve monitoringinvoer volgens het configuratiecontract valideren](#effectieve-monitoringinvoer-volgens-het-configuratiecontract-valideren)
    - [Agentplanning afzonderlijk afstemmen](#agentplanning-afzonderlijk-afstemmen)
    - [Uitvoer voor beheerders](#uitvoer-voor-beheerders)
    - [Een bruikbare eerste uitvoerregel schrijven](#een-bruikbare-eerste-uitvoerregel-schrijven)
    - [Status en technische tellers buiten de samenvatting houden](#status-en-technische-tellers-buiten-de-samenvatting-houden)
    - [Oorzaak en reikwijdte in de diagnose onderscheiden](#oorzaak-en-reikwijdte-in-de-diagnose-onderscheiden)
    - [De hoofdoorzaak vooraan in lange uitvoer zetten](#de-hoofdoorzaak-vooraan-in-lange-uitvoer-zetten)
    - [Lange uitvoer afsluiten met interpretatie](#lange-uitvoer-afsluiten-met-interpretatie)
    - [Veilige en begrensde uitvoer](#veilige-en-begrensde-uitvoer)
    - [Uitvoer alleen bij aantoonbare noodzaak normaliseren](#uitvoer-alleen-bij-aantoonbare-noodzaak-normaliseren)
    - [Pipes en lege regels in lange uitvoer veilig maken](#pipes-en-lege-regels-in-lange-uitvoer-veilig-maken)
    - [Eén afkapmechanisme per diagnoseblok gebruiken](#eén-afkapmechanisme-per-diagnoseblok-gebruiken)
    - [Interpretatie zichtbaar houden bij een UI-limiet](#interpretatie-zichtbaar-houden-bij-een-ui-limiet)
    - [Werkbegrenzing van tekstbegrenzing onderscheiden](#werkbegrenzing-van-tekstbegrenzing-onderscheiden)
    - [Perfdata en compatibiliteit](#perfdata-en-compatibiliteit)
    - [Perfdatakeys en eenheden stabiel vormgeven](#perfdatakeys-en-eenheden-stabiel-vormgeven)
    - [Counter-UOM alleen voor monotone tellers gebruiken](#counter-uom-alleen-voor-monotone-tellers-gebruiken)
    - [De externe monitoringinterface behouden](#de-externe-monitoringinterface-behouden)
- [Autofix en suppressions](#autofix-en-suppressions)
  - [Automatisch corrigeren (autofix)](#automatisch-corrigeren-autofix)
- [Parservalidatie en Ruby-controles](#parservalidatie-en-ruby-controles)
  - [Ruby-code controleren](#ruby-code-controleren)
  - [Puppet-manifests valideren](#puppet-manifests-valideren)
  - [Aanvullende validatie](#aanvullende-validatie)
  - [Eigen manifests valideren](#eigen-manifests-valideren)
  - [Ruby controleren in een ander project](#ruby-controleren-in-een-ander-project)
  - [Aanvullende tests](#aanvullende-tests)
- [Rapportage en CI](#rapportage-en-ci)
  - [Lintrapporten maken](#lintrapporten-maken)
  - [Rapportmap kiezen](#rapportmap-kiezen)
  - [CI van deze repository](#ci-van-deze-repository)
  - [Rapporten en artifacts in je project](#rapporten-en-artifacts-in-je-project)
  - [Controle in CI](#controle-in-ci)
    - [Rapporten tonen in GitLab](#rapporten-tonen-in-gitlab)
- [Importeren en distribueren](#importeren-en-distribueren)
  - [Gedeelde tooling hergebruiken](#gedeelde-tooling-hergebruiken)
  - [Benodigdheden](#benodigdheden)
  - [Aanbevolen projectstructuur](#aanbevolen-projectstructuur)
  - [Installatie in je project](#installatie-in-je-project)
  - [Eigen code controleren](#eigen-code-controleren)
  - [Een gem bouwen en versie uitbrengen](#een-gem-bouwen-en-versie-uitbrengen)
  - [Git-dependency uit de monorepo](#git-dependency-uit-de-monorepo)
  - [Gebouwd gempakket installeren](#gebouwd-gempakket-installeren)
- [Linter ontwikkelen en testen](#linter-ontwikkelen-en-testen)
  - [Een check toevoegen of wijzigen](#een-check-toevoegen-of-wijzigen)
  - [Technische werking van de checks](#technische-werking-van-de-checks)
    - [Omvang en validatiestructuur](#omvang-en-validatiestructuur)
    - [Classcontroles en vindbare afnemers](#classcontroles-en-vindbare-afnemers)
    - [References en relatiecontext](#references-en-relatiecontext)
    - [Voorbereiding van voorwaarden](#voorbereiding-van-voorwaarden)
    - [Hints voor variabelegroepen](#hints-voor-variabelegroepen)
    - [Backendselectie en wrappers](#backendselectie-en-wrappers)
  - [Veilige autofixes ontwikkelen](#veilige-autofixes-ontwikkelen)
  - [Tests uitvoeren en uitbreiden](#tests-uitvoeren-en-uitbreiden)
  - [Versies bijwerken](#versies-bijwerken)
  - [Eigen tooltests](#eigen-tooltests)
    - [Testselectie en uitvoeropties](#testselectie-en-uitvoeropties)
    - [JUnit-rapportage instellen](#junit-rapportage-instellen)
- [Documentatiecontract voor maintainers](#documentatiecontract-voor-maintainers)
- [Problemen oplossen](#problemen-oplossen)
- [Eindcontrole](#eindcontrole)

## Snelstart in deze repository

<a id="code-controleren"></a>

Voer de controles uit vanuit de hoofdmap van deze repository, met de [ontwikkelomgeving](#benodigde-omgeving) en [gems](#gems-installeren) ingericht. Lokaal en in CI gebruiken we hetzelfde commando, dat alleen de projectconfiguratie inleest:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** [ontwikkelbundle](#gems-installeren). **Invoer:** Gehele repository volgens rootconfiguratie. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Exitcode 0 bij volledige schone lintscan.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
```

Controleer vooraf of `.puppet-lint.rc` in de werkmap staat. De CLI slaat een ontbrekend configuratiebestand stilzwijgend over. De relatieve verwijzingen in dat bestand vereisen de repositoryroot als werkmap.

Een gerichte scan helpt tijdens het ontwikkelen. Gebruik hier `examples/site.pp` als bestaand voorbeeldpad en kies bij eigen werk vooraf het concrete gewijzigde manifest. De gerichte scan en correctie vervangen de volledige eindcontrole niet.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** examples/site.pp. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Diagnostics uitsluitend voor dit manifest; exitcode 0 bij schoon resultaat.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc examples/site.pp
```

Voer de correctiestap alleen uit als dit manifest tot de bedoelde wijzigingsscope behoort en de beschreven autofixvoorwaarden zijn beoordeeld.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** examples/site.pp. **Wijzigt bestanden:** Ondersteunde fixes in dat manifest. **Verwacht resultaat:** Diff beoordeeld en gewone hercontrole zonder resterende bevindingen.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix examples/site.pp
git diff -- examples/site.pp
bundle exec puppet-lint --no-config --config .puppet-lint.rc examples/site.pp
```

### Werkwijze bij een wijziging

1. Bekijk `git status --short` en lees de relevante code, modulemetadata en documentatie. Kies met de [leeswijzer](#leeswijzer) de codeafspraken voor je wijziging. De overige voorbereiding staat in [`AGENTS.md`](../../AGENTS.md#preparation).
2. Voer vóór het aanpassen een lintscan uit, zodat je weet welke meldingen al bestonden. Scan gewijzigde code opnieuw voordat je meldingen gaat corrigeren. Tijdens het ontwikkelen kun je de scan tot [één manifest](#werking-van-de-controles) beperken.
3. Gebruik een beschikbare [autofix](#automatisch-corrigeren-autofix) als die voor de betrokken code veilig en deterministisch is. Controleer daarvoor de voorwaarden bij de check. Beperk de correctie tot je wijziging en behoud gedrag, relaties en configuratie.
4. Scan de gecorrigeerde code opnieuw. De uitvoer van de fixrun kan nog meldingen over de oorspronkelijke regels bevatten.
5. Los de resterende meldingen handmatig op en herhaal de scan. Beoordeel ook het gedrag en de toepasselijke reviewcriteria; lint controleert alleen de automatisch vast te stellen eigenschappen.
6. Valideer ieder gewijzigd manifest afzonderlijk met de [Puppet-parser](#puppet-manifests-valideren). Controleer gewijzigd gedrag, templates, voorbeelden en metadata met de passende validators en tijdelijke synthetische invoer.
7. Voer bij linterontwikkeling de betrokken [tooltests](#tests-uitvoeren-en-uitbreiden) uit. Daarmee controleer je de toolwijziging; modulegedrag valideer je afzonderlijk.
8. Voer na alle correcties de volledige eindcontroles hieronder uit en voltooi de toepasselijke CI-controles. Ook na een geslaagde gerichte scan blijven de volledige lintscan en alle tooltests vereist.
9. Bekijk de uiteindelijke bestandsselectie en diff, inclusief de automatische correcties. Leg de validatie, reviewuitkomsten en eventuele beperkingen vast en laat de wijzigingen klaarstaan voor menselijke review en commit.

Gebruik voor de eindcontroles:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle; Ruby-controle wanneer toepasselijk. **Invoer:** Volledige eigen Puppet-/Ruby-code en tooltests. **Wijzigt bestanden:** Genegeerde JUnit-resultaten en toolcache. **Verwacht resultaat:** Alle controles afzonderlijk geslaagd; diff ter review.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec rubocop --config .rubocop.yml
bundle exec rake validate:puppet
bundle exec rake test
git diff --check
git diff --name-only
git diff
```

`rake test` ontdekt de tooltests recursief en voert ze allemaal uit. `test:lint` beperkt zich tot de lintertests. Zolang alleen de linter een testsuite heeft, leveren beide taken dezelfde selectie op. `git diff --check` zoekt whitespacefouten; de laatste twee commando's tonen de gewijzigde bestanden en hun inhoud.

Gebruik bij wijzigingen aan Ruby-code de [RuboCop-werkwijze](#ruby-code-controleren) voor de beginscan, correcties en hercontrole.

## Snelstart in een ander Puppet-project

Deze snelstart gebruikt een eigen project met `global-modules`. De modules en gem staan in die checkout; je Gemfile, lockfile, configuratie en eigen manifests staan in de consumerroot. Gebruik voor een bestaand project dezelfde indeling met de daar vastgelegde submodulerevisie, zoals uitgewerkt bij [path-import](#installatie-in-je-project).

**Werkmap:** Een nieuwe lege directory voor het consumerproject. **Shell:** POSIX shell met `set -e`. **Vereisten:** Git, nieuwste stabiele Ruby en Bundler, toegang tot de goedgekeurde Git- en gembron. **Invoer:** De hieronder aangemaakte `manifests/site.pp`. **Wijzigt bestanden:** Checkout `global-modules`, eigen Gemfile, lockfile, lintconfiguratie en synthetisch manifest. **Verwacht resultaat:** Installatie en een eerste volledige profielscan met exitcode 0.

```sh
set -e
git clone --recurse-submodules https://github.com/DevSysEngineer/puppet-modules.git global-modules
LINT_REVISION="$(git -C global-modules rev-parse HEAD)"
printf 'Gekozen bronrevisie: %s\n' "$LINT_REVISION"
cat > Gemfile <<'RUBY'
source 'https://rubygems.org'

gem 'lint-project', path: 'global-modules/.tools/lint', require: false
RUBY
cat > .puppet-lint.rc <<'CONFIG'
--ignore-paths=global-modules/*,./global-modules/*,vendor/*,./vendor/*
CONFIG
mkdir -p modules manifests
printf '%s\n' '$values = concat([1], [2])' > manifests/site.pp
gem install bundler
export BUNDLE_VERSION=system
bundle install
LINT_GEM="$(bundle info --path lint-project)"
export PROJECT_LINT_MODULEPATH="$PWD/global-modules:$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$LINT_GEM/lib/project_lint.rb" --config "$LINT_GEM/config/puppet-lint.rc" --config .puppet-lint.rc manifests
```

De resulterende indeling is:

```text
consumer/
├── Gemfile
├── Gemfile.lock
├── .puppet-lint.rc
├── global-modules/.tools/lint/lint-project.gemspec
├── modules/
└── manifests/site.pp
```

Het manifest is een **Volledig uitvoerbaar voorbeeld** voor het gedeelde lintprofiel plus de bovenstaande consumerconfiguratie. De path- en Git-integratietests controleren deze invoer en de tegenvariant `$values = [1] + [2]`, die `project_arrays` met warning en exitcode 1 oplevert. De Ruby-gem installeert geen Puppet-modules. De checkout is hier zowel de gembron als de plaats van eventuele Puppet-dependencies; een gebouwd pakket vereist die checkout niet.

Bewaar de gekozen bronrevisie en eigen lockfile in het versiebeheer van het consumerproject. Bij de aanbevolen Git-submodule legt de gitlink die revisie vast. Werk die revisie bewust bij en voer vervolgens `bundle update lint-project`, de eigen volledige lintscan, parservalidatie en toepasselijke Ruby-/toolcontroles uit. Een geslaagde synthetische scan bewijst nog niet dat alle eigen productiecode is geselecteerd.


## Installatie en compatibiliteit

### Benodigde omgeving

Je hebt Git, de nieuwste stabiele Ruby en de nieuwste stabiele Bundler nodig. Werk in een volledige checkout van deze repository, inclusief de verborgen bestanden en Git-submodules. De installatie hieronder haalt de submodules op en installeert de gems die de controles gebruiken.

Voer de commando's voor deze repository uit vanuit de hoofdmap. Het ontwikkelgereedschap staat onder `.tools`, apart van de Puppet-modules. De ontwikkelomgeving bepaalt niet welke Puppet- of OpenVox-versies op beheerde servers worden ondersteund; daarvoor gelden de modulemetadata en de [project-README](../../README.md#ondersteuning-en-compatibiliteit).

De controles passen geen catalogi toe en hebben geen productiegeheimen of verbindingen met beheerde servers nodig. De [testhandleiding](#tests-uitvoeren-en-uitbreiden) beschrijft welke controles bij de tooltests horen en hoe je synthetische testinvoer gebruikt.

### Installatie

Gebruik de nieuwste stabiele Ruby en Bundler. Richt op macOS eerst Ruby in met de onderstaande stappen. Heb je de nieuwste stabiele Ruby al actief, ga dan door met [de gems installeren](#gems-installeren).

### Ruby op macOS

De Ruby die macOS meelevert is te oud voor deze ontwikkelomgeving. De stappen hieronder gebruiken de nieuwste stabiele Ruby uit de [Homebrew-formule `ruby`](https://formulae.brew.sh/formula/ruby) en gaan uit van zsh. Gebruik je een Ruby-versiebeheerder zoals rbenv of mise, installeer en activeer de nieuwste stabiele Ruby daarmee en ga door naar [Gems installeren](#gems-installeren).

Controleer de [macOS-vereisten van Homebrew](https://docs.brew.sh/Installation#macos-requirements), waaronder de benodigde Command Line Tools voor Xcode. Installeer [Homebrew](https://brew.sh/) als `brew` nog niet beschikbaar is en volg ook de aanwijzingen voor de shellconfiguratie. Voer daarna dit blok uit in je huidige terminal:

**Werkmap:** Willekeurige werkmap op macOS. **Shell:** zsh. **Vereisten:** Homebrew en de genoemde macOS-vereisten. **Invoer:** Homebrew-formule ruby. **Wijzigt bestanden:** Ruby-installatie en PATH in deze shell. **Verwacht resultaat:** Homebrew-Ruby actief.

```sh
brew install ruby
export PATH="$(brew --prefix ruby)/bin:$PATH"
export PATH="$(ruby -r rubygems -e 'print Gem.bindir'):$PATH"
ruby --version
command -v ruby
```

De eerste `export` kiest Homebrew-Ruby. De tweede vraagt die Ruby waar gemcommando's worden geïnstalleerd en voegt ook die map aan PATH toe. Zo zijn de commando's beschikbaar die je straks met `gem install` installeert. Met `brew --prefix ruby` hoef je het installatiepad niet vast te leggen op Apple Silicon of Intel; de beschikbaarheid van Ruby voor jouw macOS-versie en architectuur volgt uit de Homebrew-formule.

Controleer in de uitvoer welke Ruby-versie actief is. `command -v ruby` moet naar Homebrew wijzen en niet naar `/usr/bin/ruby`.

Voor nieuwe zsh-terminals zet je dezelfde twee `export PATH=...`-regels, in dezelfde volgorde, in `~/.zshrc`. Plaats ze na eventuele Homebrew-initialisatie en behoud de `$(...)`-expressies letterlijk, zodat iedere nieuwe terminal de paden opnieuw bepaalt. Open daarna een nieuwe terminal en herhaal `ruby --version` en `command -v ruby`.

### Gems installeren

Voer dit uit vanuit de repositoryroot met de juiste Ruby actief. Haal ook de Git-submodules op, zodat de moduleverzameling compleet is.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Nieuwste stabiele Ruby, Git en netwerktoegang voor de bestaande dependencies. **Invoer:** Bestaande submodules, Gemfile en lockfile. **Wijzigt bestanden:** Submodulecheckouts en geminstallatie. **Verwacht resultaat:** Bundle met de gelockte dependencies geïnstalleerd.

```sh
git submodule update --init --recursive
gem install bundler
export BUNDLE_VERSION=system
bundle install
```

`gem install bundler` installeert de nieuwste stabiele Bundler. Met `BUNDLE_VERSION=system` gebruik je de geïnstalleerde versie, ook wanneer `BUNDLED WITH` in de lockfile een oudere versie noemt. Zet deze variabele ook in een nieuwe terminal voordat je de bundle gebruikt.

De [Gemfile](../../Gemfile) bevat geen vaste gemversies. [`Gemfile.lock`](../../Gemfile.lock) bewaart wel de geteste combinatie, zodat `bundle install` lokaal en in CI dezelfde gems installeert. Het ophalen van nieuwere versies staat apart onder [Versies bijwerken](#versies-bijwerken).

Krijg je een Bundler-fout met `/System/Library/Frameworks/Ruby.framework` of `/usr/bin/bundle` in de melding, dan gebruikt je terminal nog de macOS-installatie. Controleer eerst `ruby --version`, `command -v ruby` en `command -v bundle` en herstel de PATH-instelling hierboven. Bundler installeren met de oude systeem-Ruby of `sudo gem install` lost die versieverschillen niet op.

De root-Gemfile laadt de lokale gemspec onder `.tools/lint/`. Die beschrijft de runtime-afhankelijkheden: Puppet-lint, de twee externe lintplugins, RuboCop, OpenVox, `syslog` en de XML-library `builder`. De root-Gemfile voegt alleen het ontwikkelgereedschap toe: `metadata-json-lint`, Minitest, `minitest-reporters`, Rake en `rexml` voor het controleren van XML in de reportertests. Er is één lockfile voor lokaal ontwikkelen en CI. OpenVox levert de Puppet-parser voor structurele checks en rechtstreekse manifestvalidatie. Het installeert geen Puppet-agent op je beheerde servers. Alleen `gem install puppet-lint` is daarom niet genoeg voor de volledige projectcontrole.

### Compatibiliteitslagen

De [gemspec](lint-project.gemspec) en [rootlockfile](../../Gemfile.lock) zijn verschillende bronnen. Een permissieve gemspec is geen bewijs dat alle toegestane combinaties zijn uitgevoerd.

| Laag | Gecontroleerde gegevens | Betekenis en beperking |
| --- | --- | --- |
| Gedeclareerde runtime | `lint-project 0.1.9`, Ruby `>= 3.2`; builder `~> 3.3`, OpenVox `~> 8.29`, Puppet-lint `~> 5.1`, beide lintplugins `~> 3.0`, RuboCop `~> 1.91`, syslog `~> 0.4` | Dit zijn packagegrenzen, geen testmatrix. |
| Transitieve installatierestricties | De opgeloste `parallel 2.2.0` verlangt Ruby `>= 3.3`; beide lintplugins en onder meer `fast_gettext 4.1.1` verlangen Ruby `>= 3.2` | De huidige volledige oplossing kan dus niet op iedere Ruby vanaf 3.2 installeren. |
| Opgeloste runtime | Puppet-lint `5.1.1`, param-types `3.0.0`, trailing-comma `3.0.1`, OpenVox `8.29.0`, RuboCop `1.91.0`, builder `3.3.0`, syslog `0.4.0` | `bundle install` volgt de rootlockfile; consumers onderhouden hun eigen oplossing. |
| Opgeloste ontwikkelgems | metadata-json-lint `5.1.0`, Minitest `6.0.6`, minitest-reporters `1.8.0`, Rake `13.4.2`, rexml `3.4.4`; lockfile vermeldt Bundler `4.0.20` | Niet allemaal runtime-dependencies van de gedeelde gem. |
| Daadwerkelijk lokaal gecontroleerd | Ruby `4.0.6`, Bundler `4.0.20`, arm64-darwin25, met bovenstaande lockfile | De uitvoerbewijzen horen bij deze combinatie. Lockfile-platforms aarch64-linux, x86_64-linux en ruby zijn geen bewijs van uitvoering op die platforms. |
| Ontwikkelbeleid | Nieuwste stabiele Ruby en Bundler; geen versiepin in setup of runtimeconfiguratie | Versies in deze inventaris zijn waarnemingen, geen nieuwe installatiepins. |
| Featuregrens reporters | Beide executables zijn opgenomen in de gemspec van `0.1.3` | Dit is de gecontroleerde featuregrens, niet de huidige gemversie. |
| Puppet/OpenVox op beheerde hosts | Volgt modulemetadata en de root-README | De ontwikkelparser en gemcompatibiliteit veranderen geen module-supportclaim. |


## Configuratie, bestandsselectie en modulepad

### Werking van de controles

`--no-config` slaat de automatisch geladen optiebestanden over. Daarna leest `--config .puppet-lint.rc` expliciet de [projectconfiguratie](../../.puppet-lint.rc). Die laadt het [library-entrypoint](lib/project_lint.rb) met `--load` en leest het [gedeelde profiel](config/puppet-lint.rc) met de native `--config`-optie. Het gedeelde profiel kiest de uitvoeropmaak en laat ook waarschuwingen een foutcode opleveren. De rootconfiguratie voegt alleen de bestandsuitsluitingen van deze repository toe. De twee externe lintplugins worden via de bundle geladen.

De combinatie van beide opties voorkomt invloed van persoonlijke Puppet-lint-instellingen. Een gewone `bundle exec puppet-lint .` leest eerst `/etc/puppet-lint.rc`, daarna `~/.puppet-lint.rc` en ten slotte `.puppet-lint.rc` in de werkmap. Die instellingen worden samengevoegd. Daardoor kan een persoonlijke `--fix` of een eerder uitgeschakelde standaardcheck actief blijven. Alleen `--config` toevoegen voorkomt dat niet; alleen `--no-config` gebruiken laadt juist de projectinstellingen niet.

[Bundler-instellingen](#gems-installeren) bepalen welke gems worden gebruikt en waar die staan. Ze regelen niet welke optiebestanden Puppet-lint leest. Een ander project gebruikt [zijn eigen bundle](#installatie-in-je-project) en geeft de geïnstalleerde gem en configuratie expliciet aan de CLI door.

De afsluitende `.` selecteert de hele repository. Nieuwe manifests en bestanden in `examples/` worden automatisch gevonden; de CLI leest ook YAML. De vijf vendored Git-submodules en gems onder `vendor/bundle` zijn uitgesloten. ERB-templates met een YAML-extensie worden pas geldige YAML na renderen en vallen daarom buiten deze scan. Puppet-code in Strings of Markdown vraagt eveneens [afzonderlijke validatie](#aanvullende-validatie).

Voor een gerichte scan vervang je `.` door het manifestpad. Extra opties komen ná `--config .puppet-lint.rc`, zodat ze op de geladen projectchecks werken:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Eén manifest; normale profielscan. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Gericht resultaat.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc examples/site.pp
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Eén manifest, alleen project_resource_references. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Alleen diagnose voor de genoemde check.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --only-checks project_resource_references examples/site.pp
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Volledige lintselectie. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Actieve en genegeerde meldingen zichtbaar.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --show-ignored .
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Volledige lintselectie. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Native JSON en ongewijzigde lintstatus.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --json .
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Geen manifests; runtime-inventaris. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Alle geregistreerde checks, ook inactieve.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --list-checks
```

Met `--only-checks` onderzoek je één of meer genoemde checks; deze beperkte selectie vervangt de eindscan niet. `--show-ignored` toont meldingen die door lintmarkeringen zijn onderdrukt. JSON verandert alleen de uitvoervorm en gebruikt dezelfde controles en exitcodes.

`--list-checks` toont welke checks beschikbaar zijn, inclusief uitgeschakelde checks. De lijst bewijst dus niet dat iedere check draait. Gebruik bij twijfel de proef met [een bekende fout](#een-melding-oplossen).

### Eigen lintconfiguratie

Bewaar projectspecifieke bestandsuitsluitingen in je eigen `.puppet-lint.rc`. De gewone lintregels en uitvoerinstellingen komen uit het meegeleverde `config/puppet-lint.rc`. Voor de aanbevolen indeling sluit je de gedeelde modules en geïnstalleerde gems uit van de eigen stijlscan:

```text
--ignore-paths=global-modules/*,./global-modules/*,vendor/*,./vendor/*
```

Houd de modules die nodig zijn voor interfacecontrole beschikbaar, ook als hun code buiten de stijlscan valt. Voeg geen regeluitsluitingen toe om echte fouten te verbergen; de toegestane lokale suppressions staan bij de betreffende [codeafspraken](#naslag).

### Aanroepen van modules controleren

`PROJECT_LINT_MODULEPATH` bevat de bestaande, absolute modulemappen in dezelfde volgorde als Puppet gebruikt. Op macOS en Linux is de scheiding `:`; spaties zijn toegestaan, een `:` in een mapnaam niet. Een lege, relatieve of ontbrekende map geeft een fout. Zonder deze variabele zoekt de linter vanaf de huidige werkmap als moduleverzameling en slaat hij de vendored namen `concat`, `debconf`, `reboot`, `stdlib` en `timezone` over. Stel de variabele in externe projecten expliciet in.

De resolver gebruikt eerst declaraties uit de actuele lintinvoer. Daarna kiest hij de eerste modulemap met de gevraagde modulenaam en zoekt daar `example/manifests/init.pp` voor `example`, of `example/manifests/item.pp` voor `example::item`. Ontbreekt dat manifest, dan zoekt hij niet verder in een latere kopie van de module. Bestanden achter symlinks buiten de ingestelde modulemap worden niet gelezen.

Controleer environments met verschillende modulepaden apart. Eén samengevoegde lijst kan een andere moduleversie kiezen dan Puppet op de server. De linter leest geen `environment.conf`.

> [!CAUTION]
> Een niet-vindbare declaratie kan geen melding over ontbrekende parameters opleveren. Een geslaagde scan bewijst daarom niet dat Puppet de catalogus kan compileren. Controleer aanroepen ook met de eigen catalogusvalidatie.

Bij vindbare declaraties controleert `project_interface_calls` verplichte parameters, inclusief `Optional[...]` zonder default. Argumenttypen, onbekende parameters, functies, dynamische classnamen, `include`/`contain`, Hiera, overerving en splats worden daarmee niet volledig gevalideerd.

`project_parameter_passthrough` gebruikt dezelfde vindbare defined types om per gefilterde key de bronwaarde of brondefault met de ontvangende parameterdefault te vergelijken. De bron wordt in de actuele lintinvoer opgezocht. Een onbekende bron, ontvanger of default geeft geen filtermelding; de [regel voor parameterdoorgifte](#aanroepen-en-publieke-interfaces) beschrijft de verdere grenzen en reviewcriteria.

### Gecontroleerde configuratie- en selectiescenario’s

| Scenario | Feitelijke uitkomst | Uitvoeringsbewijs |
| --- | --- | --- |
| Systeem- en gebruikersopties bevatten fix of uitgeschakelde checks | Automatisch geladen opties kunnen blijven gelden; `--no-config` plus het expliciete profiel sluit die bron uit | `CliConfigurationTest#test_project_configuration_isolates_system_and_personal_options_before_scanning_or_fixing` |
| Load gevolgd door gedeeld en lokaal configbestand | Entrypoint registreert checks; gedeeld profiel stelt opties in; lokale opties worden daarna per optietype verwerkt | `ExternalProjectTest#test_installation_loads_all_checks_without_a_repository_checkout` en de native configuratietests |
| Herhaalde booleans, lijsten en uitvoerformaat | Fix/relative blijven aan; ignore_paths, top_scope_variables en log_format worden vervangen | `CliConfigurationTest#test_repeated_configurations_replace_lists_and_formats_but_accumulate_boolean_flags` |
| Rapportpad uit environment en CLI | Het laatste CLI-rapportpad gaat vóór CODECLIMATE_REPORT_FILE; relatieve paden gebruiken de werkmap | Native OptParser en de geïsoleerde uitvoerproef in de wijzigingsreview |
| Expliciete configuratie ontbreekt | Stilzwijgend overgeslagen; schoon resultaat kan 0 zijn zonder projectchecks | `CliConfigurationTest#test_native_config_option_silently_skips_a_missing_file_without_loading_project_checks` |
| Entrypoint ontbreekt | LoadError, exitcode 1, geen native JSON-rapport | `CliConfigurationTest#test_relative_load_paths_use_the_working_directory_not_the_configuration_directory` |
| Eén of meerdere concrete bestanden | Alle bestaande concrete invoerbestanden worden geselecteerd | `CliScopeTest#test_file_arguments_and_first_directory_selection_have_distinct_semantics` |
| Eén of meerdere directories | De eerste directory wordt recursief gescand; verdere argumenten worden genegeerd | Dezelfde selectietest; gebruik één gezamenlijke root of concrete bestanden |
| Uitsluiting of lege selectie | Linter: 0 en JSON `[]`; converter: 1 en ReportError | `CliScopeTest#test_zero_selected_files_succeeds_but_json_proves_the_empty_selection` en `PuppetJunitTest#test_invalid_or_empty_input_is_a_report_error_not_a_passing_scan` |
| Andere werkmap met relatieve load/config/invoer | Paden volgen de werkmap, niet de map van het optiebestand; corrigeer alle relatieve paden of gebruik absolute paden | Native CLI-test voor relatieve load en onafhankelijke consumerinstallaties |
| Dubbele modulenaam | De eerste modulemap overschaduwt de hele module; latere manifests vullen ontbrekende delen niet aan | `ExternalProjectTest#test_modulepath_order_shadows_entire_modules_and_keeps_dependencies_outside_style_scope` |
| Module beschikbaar maar uitgesloten van scan | Declaratieopzoeking kan haar lezen zonder de manifesten te linten | Dezelfde modulepadtest; ignore_paths en modulepath blijven afzonderlijke instellingen |
| Declaratie ontbreekt | Geen bewijs voor vereiste argumenten of ontvangende defaults; geen automatische interfacegarantie | `ExternalProjectTest` en `ExternalParameterPassthroughTest`; catalogusreview blijft verplicht |
| Modulepad ongeldig of symlink buiten modulemap | ArgumentError voor ongeldige roots; ontsnappende symlinks worden niet als declaratiebron gebruikt | `ExternalProjectTest#test_invalid_modulepaths_fail_even_without_calls` en `test_explicit_modulepath_resolves_vendored_names_and_refuses_escaping_symlinks` |

## Commando's en opties

De [native CLI-route](#werking-van-de-controles) en [consumerroute](#eigen-code-controleren) gebruiken dezelfde opties. Gerichte checkselectie is uitsluitend diagnose.

### Native opties

Deze tabel beschrijft de geïnstalleerde Puppet-lint 5.1.1. De defaults gelden voor beide expliciete projectroutes, tenzij de rij een verschil noemt. Een voorbeeld in de laatste kolom is een **Fragment** met aanvullende CLI-argumenten; voeg het toe aan de [volledige aanroep](#werking-van-de-controles), vóór de invoerpaden. De beschikbaarheid van een optie verandert het eindcontrole- en suppressiebeleid niet.

| Syntax | Doel | Default in het gebruikte profiel | Toegestane waarden | Herhalen/combineren | Wijzigt bestanden | Gebruik bij eindcontrole | Voorbeeld |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `--help`, `-h` | Native hulp tonen | Uit | Geen waarde | Stopt vóór de scan | Nee | Geen scanbewijs | `--help` |
| `--version` | Engineversie tonen | Uit | Geen waarde | Stopt vóór de scan | Nee | Alleen inventaris | `--version` |
| `--no-config` | Automatische systeem-, gebruikers- en werkmapconfiguratie overslaan | Expliciet in beide routes | Geen waarde | Expliciete `--config` blijft actief | Nee | Verplicht in de gedocumenteerde route | `--no-config` |
| `--config FILE`, `-c FILE` | Optiebestand laden | Rootconfiguratie of gedeeld en lokaal consumerprofiel | Bestandspad | Op volgorde; geneste configs direct bij het lezen | Nee, tenzij geladen opties muteren | Volledige profielen laden | `--config .puppet-lint.rc` |
| `--load FILE`, `-l FILE` | Ruby-checkbestand laden | Projectentrypoint | Bestaand Ruby-bestand | Iedere aanroep voert `load` uit | Voert Ruby-code uit; entrypoint zelf wijzigt geen bronnen | Gedocumenteerd entrypoint | `--load .tools/lint/lib/project_lint.rb` |
| `--load-from-puppet MODULEPATH` | Gemplugins uit Puppet-modulemappen laden | Geen | Met `:` gescheiden paden | Iedere aanroep doorloopt `*/lib/puppet-lint/plugins/*.rb` | Voert gevonden Ruby-code uit | Geen vervanging voor het projectentrypoint | `--load-from-puppet modules` |
| `--with-context` | Broncontext bij meldingen tonen | Uit | Geen waarde | Zet aan; geen resetoptie | Nee | Alleen lokale diagnose; broncontext kan gevoelig zijn | `--with-context` |
| `--with-filename` | Bestandsnaam tonen | Uit; CLI activeert dit bij meerdere bestanden | Geen waarde | `--log-format` gaat voor | Nee | Toegestaan | `--with-filename` |
| `--fail-on-warnings` | Actieve warnings laten falen | Aan | Geen waarde | Zet aan; geen resetoptie | Nee | Aan laten | `--fail-on-warnings` |
| `--error-level LEVEL` | Welke meldingen worden afgedrukt | `all` | `warning`, `error`, `all` | Laatste waarde geldt; verandert detectie niet | Nee | `all`; filter geen eindrapport weg | `--error-level all` |
| `--show-ignored` | Onderdrukte meldingen tonen | Uit | Geen waarde | Met gewone uitvoer of JSON | Nee | Aanvullende suppressiereview | `--show-ignored` |
| `--relative` | Modulelayout vanaf module-root beoordelen | Aan | Geen waarde | Zet aan; geen resetoptie | Nee | Aan laten | `--relative` |
| `--fix`, `-f` | Beschikbare native fixes schrijven | Uit | Geen waarde | Combineer alleen met bedoelde bestandsselectie | Ja, geselecteerde manifests | Verboden in CI-eindcontrole | `--fix` |
| `--log-format FORMAT` | Consoleformaat instellen | `%{path}:%{line}:%{column}: %{check}: %{kind}: %{message}` | Native placeholders hieronder | Laatste waarde; gaat voor `--with-filename` | Nee | Profiel behouden | `--log-format '%{check}: %{message}'` |
| `--json` | Native JSON naar stdout | Uit | Geen waarde | SARIF gaat voor wanneer beide aanstaan | Nee; shellredirectie kan een bestand schrijven | Voor de JUnit-pipe | `--json` |
| `--sarif` | Native SARIF naar stdout | Uit | Geen waarde | Gaat voor JSON | Nee; shellredirectie kan een bestand schrijven | Geen vervanging voor het voorgeschreven JUnit-artifact | `--sarif` |
| `--codeclimate-report-file FILE` | Native Code Climate-rapport opslaan | Geen, behalve bij `CODECLIMATE_REPORT_FILE` | Schrijfbaar bestandspad | Laatste CLI-waarde gaat voor environment | Ja, rapport | Geen vervanging voor JUnit | `--codeclimate-report-file /tmp/lint-report.json` |
| `--list-checks` | Alle geregistreerde checks tonen | Uit | Geen waarde | Bevat ook inactieve checks; stopt vóór scan | Nee | Alleen inventaris | `--list-checks` |
| `--only-checks CHECKS` | Alleen genoemde geregistreerde checks activeren | Geen beperking | Kommagescheiden namen uit [register](#checkregister) | Vervangt vorige selectie; onbekende namen worden niet afgekeurd | Nee, tenzij samen met fix | Uitsluitend diagnose | `--only-checks project_arrays,project_templates` |
| `--ignore-paths PATHS` | Bestanden uit stijlscan weren | Repository: rootconfig; gedeeld: native `vendor/**/*.pp` | Kommagescheiden globpatronen | Vervangt de lijst; bouwt niet op | Nee | Alleen projectselectie, geen foutverberging | `--ignore-paths 'vendor/*,global-modules/*'` |
| `--top-scope-variables VARS` | Toegestane topscopevariabelen instellen | Native lijst, niet gewijzigd door projectprofielen | Kommagescheiden variabelenamen | Vervangt vorige lijst | Nee | Alleen onderbouwde projectconfiguratie | `--top-scope-variables trusted,facts` |
| `--no-CHECK-check` | Bij parseropbouw bekende check uitzetten | Zie [register](#checkregister) | Native en pluginchecknamen | Zet genoemde check uit | Nee | Geen toestemming voor niet-toegestane suppressions | `--no-80chars-check` |
| `--CHECK-check` | Bij parseropbouw inactieve check activeren | Zie register | `80chars`, `quoted_booleans`, `code_on_top_scope`, `class_inherits_from_params_class` | Zet genoemde check aan | Nee | Gedeeld profiel bepaalt projectkeuze | `--class_inherits_from_params_class-check` |
| `PATH [PATH ...]` | Invoer selecteren | Geen | Eén directory of concrete bestanden | Eerste argument directory: overige argumenten worden genegeerd | Alleen met fix | Controleer de volledige bedoelde selectie | `examples/site.pp examples/web.pp` |

De placeholders voor `--log-format` zijn `%{filename}`, `%{path}`, `%{fullpath}`, `%{line}`, `%{column}`, `%{kind}`, `%{KIND}`, `%{check}` en `%{message}`. Het formatteken `%` is Ruby-formatteersyntax; een ongeldige placeholder kan de uitvoering afbreken. Gebruik voor eindcontrole het profiel.

De native parser bouwt check-specifieke schakelaars vóór `--load` wordt uitgevoerd. Daarom geeft `--no-project_arrays-check` in de ondersteunde route `invalid option` en exitcode 1. `--only-checks project_arrays` leest de registratie tijdens de verwerking en werkt wel. `--load-from-puppet` zoekt pluginbestanden en stelt **niet** `PROJECT_LINT_MODULEPATH` voor declaratieopzoeking in.

### Reporterargumenten

| Executable | Argumenten en invoer | Default en padbasis | Rapport en foutgedrag |
| --- | --- | --- | --- |
| `puppet-lint-junit` | Exact één rapportpad; native JSON-array via stdin | Geen default; relatief aan werkmap | Extensie wordt niet gecontroleerd. Bovenliggende map moet bestaan. Overschrijft het rapport; geldige warnings/errors worden XML-failures maar de converter zelf retourneert 0. |
| `puppet-validate-junit` | Eerst rapportpad eindigend op `.xml`, daarna concrete `.pp`-bestanden | Geen default; relatief aan werkmap | Maakt rapportmap aan; ontdubbelt genormaliseerde paden. Geen directories. Lege selectie geeft een XML-error en exitcode 1. |
| `rubocop` | `--config`, `--format progress --format junit --out FILE` | Eigen RuboCop-configuratie en expliciet rapportpad | Native formatter, geen afzonderlijke converter; zie [Ruby-controles](#ruby-code-controleren). |
| `rake test` / Minitest | `TEST=...`, `TESTOPTS=...` | Recursieve selectie van tooltests | Zie [testselectie](#testselectie-en-uitvoeropties) en [JUnit-initialisatie](#junit-rapportage-instellen). |

### Omgevingsvariabelen

Dit is de publieke interface die de projectcode leest of die de ondersteunde procedures gebruiken. Native Ruby- en Bundler-instellingen blijven hun eigen interfaces. Tijdelijke voorbeeldvariabelen zijn apart gemarkeerd; zij zijn geen extra geminstelling.

| Naam | Doel | Unset | Lege waarde | Default | Padbasis | Prioriteit tegenover CLI/configuratie |
| --- | --- | --- | --- | --- | --- | --- |
| `PROJECT_LINT_MODULEPATH` | Modulebronnen voor structurele analyse | Werkmap; vendored namen uitgesloten | Fout | `Dir.pwd` | Bestaande absolute mappen, `:` op macOS/Linux | Geen CLI-equivalent; leest geen `environment.conf` |
| `BUNDLE_VERSION` | Actieve Bundler kiezen | Native lockfile-/Bundlerkeuze | Blijft een lege settingswaarde; `bundle --version` gebruikt hier de actieve Bundler | Procedures: `system` | Geen pad | Kies geïnstalleerde Bundler; geen Ruby-versiepin |
| `BUNDLE_IGNORE_CONFIG` | Persoonlijke Bundlerconfiguratie isoleren | Native Bundlerconfig actief | Negeert configuratie eveneens: aanwezigheid telt | CI: `1` | Geen pad | Betreft Bundler, niet Puppet-lint-optiebestanden |
| `BUNDLE_FROZEN` | Lockfile onveranderd vereisen | Native Bundlerdefault | Boolean false; frozen wordt niet vereist | CI: `true` | Eigen lockfile | Installatie faalt als resolutie moet wijzigen |
| `BUNDLE_PATH` | Installatiemap gems | Native Bundlerdefault | Expliciet leeg basispad, geen fallback naar systeemgems; vermijd dit in installatieprocedures | CI: `vendor/bundle` | Projectroot | Bundlerinstelling, geen manifestselectie |
| `BUNDLE_GEMFILE` | Gemfile selecteren | Gemfile vanaf werkmap | Zelfde zoekgedrag als unset: zoek Gemfile/gems.rb omhoog vanaf de werkmap | Eigen root-Gemfile | Native Bundlerpad | Niet naar bronrepository instellen voor consumers |
| `PATH` | Ruby en executables vinden | Shellomgeving | Lege zoekcomponent kan de werkmap doorzoeken; correcte Ruby-keuze is niet gegarandeerd | Actieve shell | Absolute zoekmappen | Homebrew-Ruby vóór systeem-Ruby |
| `GITHUB_ACTION` | Native lintannotaties activeren | Geen annotaties | Aan: aanwezigheid is bepalend | CI levert waarde | Geen pad | Verandert niet de diagnostiektelling |
| `CODECLIMATE_REPORT_FILE` | Native Code Climate-rapport | Geen rapport | Poging tot schrijven naar leeg pad faalt | Geen | Werkmap | CLI `--codeclimate-report-file` gaat voor |
| `MINITEST_REPORTERS_REPORTS_DIR` | Minitest-rapportmap overschrijven | Pad uit testhelper | Schrijft TEST-*.xml in de werkmap; de relatieve lege override vervangt het helperpad | Repository: `.tools/lint/results` | Bij relatieve override: werkmap | Gaat vóór pad uit reporterinitialisatie; raakt lint/parser niet |
| `PROJECT_REPORT_DIR` (voorbeeldafspraak) | Rapportkeuze consumer | Voorbeeld-Ruby gebruikt `.tools/quality/results` | Wordt door `ENV.fetch` behouden; niet ondersteund als voorbeeldinvoer | `.tools/quality/results` | Consumerroot | Shell geeft pad expliciet aan reporters; geen geminterface |
| `LINT_GEM`, `LINT_SOURCE`, `LINT_REVISION`, `LINT_PACKAGE`, `CONSUMER_DIR` (tijdelijke voorbeeldvariabelen) | Paden en revisie in procedures benoemen | In ieder procedureblok eerst instellen | Niet toegestaan waar pad of revisie nodig is | In procedure bepaald | Zoals bij procedure vermeld | Geen door de gem gelezen instellingen |
| `lint_gem` (tijdelijke variabele in bestaande consumer- en CI-voorbeelden) | Bundlerlocatie bewaren | Voor gebruik instellen | Mislukte `bundle info` stopt procedure | `bundle info --path lint-project` | Absoluut gem-pad | Alleen shellargument |

Bundler 4.0.20 kiest gewone settings in de volgorde tijdelijke CLI-instelling, lokale configuratie, environment, globale configuratie en default. `BUNDLE_IGNORE_CONFIG` slaat lokale en globale configuratie over, ook als de environmentwaarde leeg is. `BUNDLE_GEMFILE` heeft de hierboven beschreven eigen zoekroute. Deze feiten zijn afzonderlijk van Puppet-lint-optieprioriteit; het gebruik van Bundler verandert geen lintprofiel.

De offline integratietests isoleren bovendien `RUBYOPT`, `RUBYLIB`, `BUNDLE_USER_HOME`, `GEM_HOME` en `GEM_PATH`. Alleen reeds geïnstalleerde Ruby-dependencies worden als lokale cache hergebruikt. Bij een nieuwe offline lockfile gebruiken deze synthetische tests `BUNDLE_LOCKFILE_CHECKSUMS=false`, omdat de lokale cache geen registrychecksums levert; dit is geen instelling in de consumerinstallatie of CI-voorbeelden.

## Meldingen, severity en exitcodes

### Een melding oplossen

Een lintmelding geeft het bestand, de regel, de kolom, de checknaam en de oorzaak. Zoek een `project_*`-check op in het [checkoverzicht](#beschikbare-projectchecks). De link leidt naar de codeafspraak en de voorwaarden voor correctie. Voor standaardchecks is er de [uitleg van Puppet-lint](https://puppetlabs.github.io/puppet-lint/#checks).

Lees de gemelde regel samen met het parameterblok, de resource of het commando waar hij bij hoort. Bepaal welke afwijking wordt gemeld en volg de [werkwijze](#werkwijze-bij-een-wijziging) om die te herstellen. `[review]` betekent dat inhoudelijke beoordeling nodig is of dat de constructie niet veilig automatisch kan worden gewijzigd. Ook zonder die markering kunnen reviewpunten gelden; het overzicht vermeldt de grenzen van iedere check.

Een waarschuwing laat de scan mislukken. Herstel de oorzaak volgens de codeafspraak. De toegestane uitzonderingen zijn beperkt tot [lange regels](#lange-regels) en de beschreven [Puppet-fileserverbronnen](#templates-en-bestandsbronnen); andere checks uitschakelen of alleen een gunstige selectie draaien levert geen volledige controle op.

Stopt de linter voordat hij code controleert, controleer dan de Ruby-installatie, bundle en werkmap volgens [Gems installeren](#gems-installeren). Een ontbrekende plugin kan wijzen op een onvolledige installatie van de gem of een verkeerd entrypoint. Met [`--list-checks`](#werking-van-de-controles) zie je of de projectchecks zijn geladen.

Om te controleren of ze ook draaien, maak je tijdelijk buiten de repository een manifest met `$values = [1] + [2]`. Scan het volledige pad met de projectaanroep. Verwacht een foutcode en `project_arrays` bij dat bestand. Vervang de inhoud door `$values = concat([1], [2])`; nu hoort de proef te slagen. Verwijder het tijdelijke bestand daarna.

### Exitcodes van Puppet-lint

De tabellen gelden voor de expliciete profielen met `--fail-on-warnings` en `--error-level all`. Een warning en een error zijn verschillende severities, maar leveren beide exitcode 1. `[review]` is uitsluitend meldingstekst. `fixed` en `ignored` zijn uitkomstsoorten; zij zijn geen actieve warning/error.

| Geval | Exitcode | Stdout | Stderr | Rapportgedrag |
| --- | --- | --- | --- | --- |
| Schoon bestand | 0 | Stil; met JSON `[[]]` | Leeg | Native uitvoer; JUnit alleen via converter |
| Actieve warning | 1 | Diagnostic met warning of native JSON | Gewoonlijk leeg | JSON bevat de warning |
| Actieve error | 1 | Diagnostic met error of native JSON | Syntax geeft bovendien parseradvies | JSON bevat de error |
| Ongeldige optie | 1 | `puppet-lint: invalid option: {optie}` plus hulpaanwijzing | Leeg voor InvalidOption | Geen geldige native JSON |
| Ontbrekende invoer of bestand | 1 | `no file specified` of `no file specified or specified file does not exist` plus hulpaanwijzing | Leeg | Geen geldige native JSON |
| Ontbrekend expliciet configbestand | 0 bij verder schone run | Geen waarschuwing over het ontbrekende bestand | Leeg | Overige opties draaien; dit bewijst geen geladen projectprofiel |
| Ongeldige configoptie | 1 | InvalidOption plus hulpaanwijzing | Leeg | Geen geldige native JSON |
| Ontbrekend `--load`-bestand | 1 | Geen lintdiagnostics | LoadError met bestandsnaam en stacktrace | Geen JSON-rapport |
| Ongeldig modulepad | 1 | Geen geslaagde lintuitslag | ArgumentError met `PROJECT_LINT_MODULEPATH` | Geen compleet JSON-rapport |
| Lege directory of volledig uitgesloten selectie | 0 | Stil; JSON `[]` | Leeg | Geen gecontroleerde manifests; converter maakt ReportError |
| Ongeldige native rapportbestemming | 1 | Eventueel reeds gemaakte JSON | Schrijffout, bijvoorbeeld EISDIR | Geen bruikbaar nieuw rapport op die bestemming |

`--error-level` filtert alleen de gepubliceerde meldingen, inclusief JSON. Het verandert de warning/error-exitstatus niet. Een warningrun met `--error-level error --json` kan dus `[[]]` afdrukken en toch met 1 eindigen. Gebruik deze filteroptie niet in eindrapporten. Zonder `--fail-on-warnings` zou een warningrun 0 kunnen geven; beide projectprofielen voorkomen dat.

Een ontbrekend configbestand is een vastgestelde native beperking. Daarom controleren de procedures het lokale bestand expliciet met `test -f`. Maak van de native nulcode geen bewijs dat alle regels zijn geladen. Fouten in Ruby-code of ongeldige waarden die niet als InvalidOption worden opgevangen kunnen met een stacktrace stoppen; zij worden niet vertaald naar een gezonde scan.

### Exitcodes van puppet-lint-junit

| Geval | Exitcode | Stdout | Stderr | Rapportgedrag |
| --- | --- | --- | --- | --- |
| Geldige JSON zonder actieve meldingen | 0 | `Puppet lint: no active findings.` | Leeg | Eén geslaagde testcase |
| Geldige JSON met warnings | 0 | Actieve diagnostics | Leeg | JUnit-failure per bestand/check |
| Geldige JSON met errors | 0 | Actieve diagnostics | Leeg | JUnit-failure per bestand/check |
| Ontbrekende/ongeldige JSON | 1 | Geen geslaagde scanmelding | `Invalid or missing Puppet-lint JSON; inspect the lint log.` | Parseerbare XML met ReportError als rapportpad schrijfbaar is |
| JSON `[]` | 1 | Geen geslaagde scanmelding | `No files were reported by Puppet-lint` | XML met ReportError |
| Ongeldige JSON-structuur of diagnosticvelden | 1 | Geen geslaagde scanmelding | `Expected native Puppet-lint JSON arrays` of `Invalid Puppet-lint diagnostic` | XML met ReportError |
| Geen of meerdere rapportargumenten | 1 | Leeg | Usage | Geen nieuw rapport |
| Laden gem/executable mislukt | 1 bij de gecontroleerde LoadError | Geen converteruitvoer | Ruby-/Bundlerfout | Geen nieuw rapport |
| Rapportpad onschrijfbaar of bovenliggende map ontbreekt | 1 | Geen complete conversie | `Cannot write Puppet-lint JUnit report: {fout}` | Geen bruikbaar nieuw rapport; oud bestand kan blijven bestaan als openen faalt |

De converter heeft geen lintconfiguratie, manifestselectie of warningbeleid: zulke combinaties zijn niet van toepassing omdat hij alleen stdin omzet. Exitcode 0 betekent geslaagde conversie, ook bij XML-failures. Bewaar de lintstatus met Bash `pipefail`; alleen het bestaan van XML is onvoldoende.

### Exitcodes van puppet-validate-junit

| Geval | Exitcode | Stdout | Stderr | Rapportgedrag |
| --- | --- | --- | --- | --- |
| Alle manifests syntactisch geldig | 0 | `passed` per pad en resultaattelling | Leeg | Eén geslaagde testcase per uniek pad |
| Native waarschuwing zonder niet-nul parserstatus | 0 | Native uitvoer bij resultaat | Leeg | Geslaagde testcase met system-out; geen eigen warningseverity |
| Parser eindigt niet-nul | 1 | `failure`, native diagnostic, telling | Native stderr is samengevoegd in resultaat | Failure; resterende bestanden worden ook gecontroleerd |
| Ontbrekend bestand, directory of verkeerde extensie | 1 | `error` en `Expected an existing .pp file: {pad}` | Leeg | Error per ongeldig pad |
| Geen manifests na geldig rapportargument | 1 | `No Puppet manifests selected.` in resultaat | Leeg | Error voor Manifest selection |
| Rapportargument ontbreekt of eindigt niet op `.xml` | 1 | Leeg | Usage | Geen nieuw rapport |
| Validator kan niet starten of eindigt door signaal | 1 | Error met start-/procesdiagnose | In resultaatafhandeling | XML-error als rapport schrijven mogelijk is |
| Rapportmap of bestand niet schrijfbaar | 1 | Geen complete resultaatreeks | `Cannot write Puppet validation JUnit report: {fout}` | Geen bruikbaar nieuw rapport |

Deze reporter heeft geen lintconfiguratie; het modulepad en `.puppet-lint.rc` zijn daarom niet van toepassing op zijn selectie. De native parser controleert syntax, geen catalogus. Een ontbrekende gem of executable kan al vóór de reporter met een Ruby-/Bundlerfout stoppen; dan is er geen rapport.

### Overige validatiecommando's

| Executable | Schoon | Bevinding of fout | Ongeldige invoer/configuratie | Rapportagefout en uitvoer |
| --- | --- | --- | --- | --- |
| `puppet parser validate` | 0, doorgaans stil | Syntaxfout: 1, native diagnostic | Ontbrekend bestand: 1; geen lintprofiel | Geen eigen XML; hiervoor bestaat puppet-validate-junit |
| `rubocop` | 0, console-overzicht | Offenses: 1; copseverity is niet de Puppet-severity | Ongeldige optie/configuratie: 2 | Foutstatus en native diagnostic; native JUnit-formatter schrijft alleen waar uitvoering dat bereikt |
| `rake test` | 0, testtelling en JUnit per klasse | Assertion/error: 1 | Taak-/laadfout: 1 | Reporter-/schrijffout: niet-nul; geen garantie op complete XML |

Controleer bij een uitvoerfout altijd de numerieke status én het rapport. Bestaande rapporten bewijzen geen geslaagde huidige run. De gedocumenteerde rapportcommando's vervangen hun eigen uitvoer; een mislukte start of mislukte opening kan een oud bestand laten staan.


## Checkregister

### Beschikbare projectchecks

De tabel beschrijft de automatische dekking en verwijst naar de volledige regel. **Voorwaardelijk** betekent dat de check alleen aantoonbaar geschikte constructies corrigeert; de voorwaarden staan bij die regel. **Geen** betekent dat de check geen autofix heeft. Beoordeel de genoemde reviewpunten wanneer je wijziging ze raakt, ook als de check geen melding geeft.

<!-- BEGIN PROJECT CHECK REGISTRY -->
| Check | Actief in repositoryprofiel | Actief in gedeeld profiel | Meldingsvarianten | Autofix | Regeluitleg |
| --- | --- | --- | --- | --- | --- |
| `project_parameter_order` | Ja | Ja | [Parameters met defaultafhankelijkheden sorteren](#parameters-met-defaultafhankelijkheden-sorteren) | Geen | [Parameters met defaultafhankelijkheden sorteren](#parameters-met-defaultafhankelijkheden-sorteren) |
| `project_parameter_alignment` | Ja | Ja | [Parameterblokken volledig uitlijnen](#parameterblokken-volledig-uitlijnen) | Per meldingsvariant: [Parameterblokken volledig uitlijnen](#parameterblokken-volledig-uitlijnen) | [Parameterblokken volledig uitlijnen](#parameterblokken-volledig-uitlijnen) |
| `project_documentation` | Ja | Ja | [Publieke declaraties bij de code documenteren](#publieke-declaraties-bij-de-code-documenteren), [Strings API-markering](#strings-api-markering), [Strings-summary op één regel](#strings-summary-op-één-regel), [Strings-parametercontract](#strings-parametercontract), [Uitvoerbare Strings-voorbeelden](#uitvoerbare-strings-voorbeelden) | Geen | [Publieke declaraties bij de code documenteren](#publieke-declaraties-bij-de-code-documenteren), [Strings API-markering](#strings-api-markering), [Strings-summary op één regel](#strings-summary-op-één-regel), [Strings-parametercontract](#strings-parametercontract), [Uitvoerbare Strings-voorbeelden](#uitvoerbare-strings-voorbeelden) |
| `project_documentation_layout` | Ja | Ja | [Lange regels](#lange-regels), [Strings-summary op één regel](#strings-summary-op-één-regel), [Uitvoerbare Strings-voorbeelden](#uitvoerbare-strings-voorbeelden), [Strings-regelbreedte](#strings-regelbreedte), [Strings-taginspringing](#strings-taginspringing), [Strings-secties met commentregels scheiden](#strings-secties-met-commentregels-scheiden), [Lengtesuppressions in Strings begrenzen](#lengtesuppressions-in-strings-begrenzen) | Per meldingsvariant: [Lange regels](#lange-regels), [Strings-summary op één regel](#strings-summary-op-één-regel), [Uitvoerbare Strings-voorbeelden](#uitvoerbare-strings-voorbeelden), [Strings-regelbreedte](#strings-regelbreedte), [Strings-taginspringing](#strings-taginspringing), [Strings-secties met commentregels scheiden](#strings-secties-met-commentregels-scheiden), [Lengtesuppressions in Strings begrenzen](#lengtesuppressions-in-strings-begrenzen) | [Lange regels](#lange-regels), [Strings-summary op één regel](#strings-summary-op-één-regel), [Uitvoerbare Strings-voorbeelden](#uitvoerbare-strings-voorbeelden), [Strings-regelbreedte](#strings-regelbreedte), [Strings-taginspringing](#strings-taginspringing), [Strings-secties met commentregels scheiden](#strings-secties-met-commentregels-scheiden), [Lengtesuppressions in Strings begrenzen](#lengtesuppressions-in-strings-begrenzen) |
| `project_layout` | Ja | Ja | [Inspringing](#inspringing), [Spatie na komma’s](#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](#inhoud-direct-na-een-openingsaccolade-beginnen) | Per meldingsvariant: [Inspringing](#inspringing), [Spatie na komma’s](#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](#inhoud-direct-na-een-openingsaccolade-beginnen) | [Inspringing](#inspringing), [Spatie na komma’s](#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](#inhoud-direct-na-een-openingsaccolade-beginnen) |
| `project_comment_spacing` | Ja | Ja | [Toelichtingsblokken van eerdere code scheiden](#toelichtingsblokken-van-eerdere-code-scheiden) | Per meldingsvariant: [Toelichtingsblokken van eerdere code scheiden](#toelichtingsblokken-van-eerdere-code-scheiden) | [Toelichtingsblokken van eerdere code scheiden](#toelichtingsblokken-van-eerdere-code-scheiden) |
| `project_resource_sections` | Ja | Ja | [Een resource na een afgesloten blok toelichten](#een-resource-na-een-afgesloten-blok-toelichten) | Geen | [Een resource na een afgesloten blok toelichten](#een-resource-na-een-afgesloten-blok-toelichten) |
| `project_resource_references` | Ja | Ja | [References van hetzelfde type samenvoegen](#references-van-hetzelfde-type-samenvoegen), [Titels in resource references sorteren](#titels-in-resource-references-sorteren), [Een overbodige buitenste dependency-array verwijderen](#een-overbodige-buitenste-dependency-array-verwijderen) | Per meldingsvariant: [References van hetzelfde type samenvoegen](#references-van-hetzelfde-type-samenvoegen), [Titels in resource references sorteren](#titels-in-resource-references-sorteren), [Een overbodige buitenste dependency-array verwijderen](#een-overbodige-buitenste-dependency-array-verwijderen) | [References van hetzelfde type samenvoegen](#references-van-hetzelfde-type-samenvoegen), [Titels in resource references sorteren](#titels-in-resource-references-sorteren), [Een overbodige buitenste dependency-array verwijderen](#een-overbodige-buitenste-dependency-array-verwijderen) |
| `project_if_sections` | Ja | Ja | [Voorwaarden toelichten](#voorwaarden-toelichten) | Geen | [Voorwaarden toelichten](#voorwaarden-toelichten) |
| `project_variable_sections` | Ja | Ja | [Een variabelegroep bij blokbegin toelichten](#een-variabelegroep-bij-blokbegin-toelichten), [Een onafhankelijke groep na afhankelijke waarden beginnen](#een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen) | Geen | [Een variabelegroep bij blokbegin toelichten](#een-variabelegroep-bij-blokbegin-toelichten), [Een onafhankelijke groep na afhankelijke waarden beginnen](#een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen) |
| `project_class_check_reuse` | Ja | Ja | [Classcontroles hergebruiken](#classcontroles-hergebruiken) | Geen | [Classcontroles hergebruiken](#classcontroles-hergebruiken) |
| `project_packages` | Ja | Ja | [APT-opties expliciet afsluiten](#apt-opties-expliciet-afsluiten) | Geen | [APT-opties expliciet afsluiten](#apt-opties-expliciet-afsluiten) |
| `project_guarded_packages` | Ja | Ja | [Gelijk ingestelde packageguards samenvoegen](#gelijk-ingestelde-packageguards-samenvoegen) | Per meldingsvariant: [Gelijk ingestelde packageguards samenvoegen](#gelijk-ingestelde-packageguards-samenvoegen) | [Gelijk ingestelde packageguards samenvoegen](#gelijk-ingestelde-packageguards-samenvoegen) |
| `project_resource_list_reuse` | Ja | Ja | [Resourcelijsten hergebruiken](#resourcelijsten-hergebruiken) | Per meldingsvariant: [Resourcelijsten hergebruiken](#resourcelijsten-hergebruiken) | [Resourcelijsten hergebruiken](#resourcelijsten-hergebruiken) |
| `project_resource_dependencies` | Ja | Ja | [Resource-dependencies opbouwen](#resource-dependencies-opbouwen) | Per meldingsvariant: [Resource-dependencies opbouwen](#resource-dependencies-opbouwen) | [Resource-dependencies opbouwen](#resource-dependencies-opbouwen) |
| `project_files` | Ja | Ja | [Optionele resource-attributen vooraf bepalen](#optionele-resource-attributen-vooraf-bepalen), [Eigenaars en rechten](#eigenaars-en-rechten) | Geen | [Optionele resource-attributen vooraf bepalen](#optionele-resource-attributen-vooraf-bepalen), [Eigenaars en rechten](#eigenaars-en-rechten) |
| `project_puppet_urls` | Ja | Ja | [Puppet-fileservermounts expliciet kiezen](#puppet-fileservermounts-expliciet-kiezen) | Geen | [Puppet-fileservermounts expliciet kiezen](#puppet-fileservermounts-expliciet-kiezen) |
| `project_arrays` | Ja | Ja | [Arrays met concat combineren](#arrays-met-concat-combineren) | Geen | [Arrays met concat combineren](#arrays-met-concat-combineren) |
| `project_templates` | Ja | Ja | [Gegenereerde configuratie met ERB renderen](#gegenereerde-configuratie-met-erb-renderen) | Geen | [Gegenereerde configuratie met ERB renderen](#gegenereerde-configuratie-met-erb-renderen) |
| `project_positive_flow` | Ja | Ja | [De grootste verwerking vóór de korte afhandeling plaatsen](#de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen), [Validatie om haar afhankelijke implementatie plaatsen](#validatie-om-haar-afhankelijke-implementatie-plaatsen) | Geen | [De grootste verwerking vóór de korte afhandeling plaatsen](#de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen), [Validatie om haar afhankelijke implementatie plaatsen](#validatie-om-haar-afhankelijke-implementatie-plaatsen) |
| `project_shell` | Ja | Ja | [Shellcommando's in Puppet](#shellcommandos-in-puppet) | Geen | [Shellcommando's in Puppet](#shellcommandos-in-puppet) |
| `project_interface_calls` | Ja | Ja | [Alle verplichte argumenten doorgeven](#alle-verplichte-argumenten-doorgeven) | Geen | [Alle verplichte argumenten doorgeven](#alle-verplichte-argumenten-doorgeven) |
| `project_parameter_passthrough` | Ja | Ja | [Overbodige parameterdoorgifte rechtstreeks schrijven](#overbodige-parameterdoorgifte-rechtstreeks-schrijven) | Geen | [Overbodige parameterdoorgifte rechtstreeks schrijven](#overbodige-parameterdoorgifte-rechtstreeks-schrijven) |
| `project_monitoring_backend` | Ja | Ja | [Targets en monitoring](#targets-en-monitoring) | Geen | [Targets en monitoring](#targets-en-monitoring) |
| `project_suppressions` | Ja | Ja | [Alleen toegestane suppressions gebruiken](#alleen-toegestane-suppressions-gebruiken) | Geen | [Alleen toegestane suppressions gebruiken](#alleen-toegestane-suppressions-gebruiken) |
<!-- END PROJECT CHECK REGISTRY -->

De registratie is vastgesteld via `require 'project_lint'`; activatie is afzonderlijk gecontroleerd met beide configuratieprofielen. `--list-checks` bewijst alleen beschikbaarheid. De inventaris gebruikt `lint-project 0.1.9`, `puppet-lint 5.1.1`, `puppet-lint-param-types 3.0.0` en `puppet-lint-trailing_comma-check 3.0.1` uit de rootlockfile. Nieuwe bundleversies vragen een nieuwe inventaris.

### Native checks in deze bundle

| Check | Bron | Actief in repositoryprofiel | Actief in gedeeld profiel |
| --- | --- | --- | --- |
| `arrow_on_right_operand_line` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `autoloader_layout` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `class_inherits_from_params_class` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `code_on_top_scope` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Nee | Nee |
| `inherits_across_namespaces` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `names_containing_dash` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `names_containing_uppercase` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `nested_classes_or_defines` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `parameter_order` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `right_to_left_relationship` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `variable_scope` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `slash_comments` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `star_comments` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `case_without_default` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `selector_inside_resource` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `documentation` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `unquoted_node_name` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `duplicate_params` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `ensure_first_param` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `ensure_not_symlink_target` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `file_mode` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `unquoted_file_mode` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `unquoted_resource_title` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `double_quoted_strings` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `only_variable_string` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `puppet_url_without_modules` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `quoted_booleans` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Nee | Nee |
| `single_quote_string_with_variables` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `variables_not_enclosed` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `variable_contains_dash` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `variable_is_lowercase` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `140chars` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `2sp_soft_tabs` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `80chars` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Nee | Nee |
| `arrow_alignment` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `hard_tabs` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `space_before_arrow` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `trailing_whitespace` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `legacy_facts` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |
| `top_scope_facts` | [puppet-lint 5.1.1](https://github.com/puppetlabs/puppet-lint) | Ja | Ja |

### Pluginchecks in deze bundle

| Check | Bron | Actief in repositoryprofiel | Actief in gedeeld profiel |
| --- | --- | --- | --- |
| `parameter_types` | [puppet-lint-param-types 3.0.0](https://github.com/voxpupuli/puppet-lint-param-types) | Ja | Ja |
| `trailing_comma` | [puppet-lint-trailing_comma-check 3.0.1](https://github.com/voxpupuli/puppet-lint-trailing_comma-check) | Ja | Ja |

De checks voor opmaak bewijzen niet dat commentaar inhoudelijk klopt. Voor systemd-hardening, transportbeveiliging, shellgedrag, monitoringdefaults, uitvoertijd en gedeelde checkexecutables bestaat hier geen volledige automatische lintcontrole. De betreffende naslagsecties en [`AGENTS.md`](../../AGENTS.md#monitoring-checks) beschrijven de review en functionele validatie.

## Puppet-coderegels en reviewcriteria

<a id="naslag"></a>

De afspraken hieronder vormen samen met [`.puppet-lint.rc`](../../.puppet-lint.rc) en de [projectchecks](lib/project_lint/checks/) de Puppet-codestandaard. Gebruik het overzicht om vanuit een lintmelding naar de betreffende afspraak te gaan. De secties bevatten ook handmatige reviewcriteria: een geslaagde scan bewijst geen correct functioneel gedrag, volledige documentatie of veilige serviceconfiguratie.

### Basisopmaak

<!-- lint-rule-group -->

#### Twee spaties per inspringniveau

**Norm**

Puppet-code gebruikt twee spaties per inspringniveau.

**Herkomst**

Projectspecificatie van upstream; [Puppet-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/style_guide.html). De geïnstalleerde native check bepaalt de hieronder beschreven dekking.

**Toepassingsgebied**

Inspringingstokens in Puppet-code; arrays volgen bovendien [Inspringing](#inspringing).

**Automatische controle**

`2sp_soft_tabs`

**Detectiegrenzen**

Controleert alleen of de lengte van een INDENT-token even is; vier spaties op een plaats waar twee nodig zijn worden daarmee niet bewezen. `hard_tabs` meldt afzonderlijk echte tabs.

**Meldingen en severity**

`two-space soft tabs not used`: `error` bij oneven lengte van een inspringingstoken.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de native 2sp_soft_tabs-check heeft geen fixmethode.

**Toegestane uitzonderingen**

Geen uitzondering voor oneven inspringing; de specifieke array- en resourcetitelindeling staat bij Inspringing.

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Fragment; controle `2sp_soft_tabs`; verwacht error.

<!-- lint-example: 2sp_soft_tabs error -->
```puppet
if $active {
   notice('Example')
}
```

**Correct voorbeeld**

Fragment; controle `2sp_soft_tabs`; verwacht geen melding.

<!-- lint-example: 2sp_soft_tabs clean -->
```puppet
if $active {
  notice('Example')
}
```

**Grensgevallen**

Controleert alleen of de lengte van een INDENT-token even is; vier spaties op een plaats waar twee nodig zijn worden daarmee niet bewezen. `hard_tabs` meldt afzonderlijk echte tabs. Geen uitzondering voor oneven inspringing; de specifieke array- en resourcetitelindeling staat bij Inspringing.

**Handmatige review**

Een even aantal spaties kan nog het verkeerde structurele niveau zijn; vergelijk ieder blok met zijn opening.

**Verificatie**

De gemarkeerde voorbeeldparen worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). Voor de beschreven quote- en pijlcorrecties controleert [guide_examples_test.rb](test/guide_examples_test.rb) exacte uitvoer, hercontrole en tweede run. Een even aantal spaties kan nog het verkeerde structurele niveau zijn; vergelijk ieder blok met zijn opening.

#### Resourcepijlen uitlijnen

**Norm**

Lijn de `=>`-pijlen binnen een resource uit, zodat de attributen en waarden goed te vergelijken zijn.

**Herkomst**

Projectspecificatie van upstream; [Puppet-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/style_guide.html). De geïnstalleerde native check bepaalt de hieronder beschreven dekking.

**Toepassingsgebied**

Resource-attributen en geneste groepen met pijlen op verschillende regels.

**Automatische controle**

`arrow_alignment`

**Detectiegrenzen**

Eenregelige resources en groepen met slechts één pijl worden overgeslagen. De gewenste kolom volgt uit de breedste attribuuttekst per groep; commenttokens worden voor de berekening verwijderd.

**Meldingen en severity**

`indentation of => is not properly aligned (expected in column {verwacht}, but found it in column {gevonden})`: `warning`; kolomnummers zijn variabel.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Past witruimte vóór => aan en kan een volgend attribuut op dezelfde regel naar een nieuwe regel brengen. Een berekende negatieve witruimtebreedte geeft NoFix. Beoordeel comments, nieuwe regels en samenloop met andere fixes vóór toepassing.

**Toegestane uitzonderingen**

Een eenregelige resource hoeft geen kunstmatige uitlijning tussen meerdere regels te krijgen.

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Fragment; controle `arrow_alignment`; verwacht warning.

<!-- lint-example: arrow_alignment warning -->
```puppet
notify { 'example':
  message => 'Example',
  withpath => false,
}
```

**Correct voorbeeld**

Fragment; controle `arrow_alignment`; verwacht geen melding.

<!-- lint-example: arrow_alignment clean -->
```puppet
notify { 'example':
  message  => 'Example',
  withpath => false,
}
```

**Grensgevallen**

Eenregelige resources en groepen met slechts één pijl worden overgeslagen. De gewenste kolom volgt uit de breedste attribuuttekst per groep; commenttokens worden voor de berekening verwijderd. Een eenregelige resource hoeft geen kunstmatige uitlijning tussen meerdere regels te krijgen.

**Handmatige review**

Controleer dat attribuutnamen, waarden, commentaar en resourcegrenzen gelijk blijven; een opgemaakte groep bewijst geen correcte resourcevolgorde.

**Verificatie**

De gemarkeerde voorbeeldparen worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). Voor de beschreven quote- en pijlcorrecties controleert [guide_examples_test.rb](test/guide_examples_test.rb) exacte uitvoer, hercontrole en tweede run. Controleer dat attribuutnamen, waarden, commentaar en resourcegrenzen gelijk blijven; een opgemaakte groep bewijst geen correcte resourcevolgorde.

#### Aanhalingstekens bij stringinhoud kiezen

**Norm**

Voor letterlijke strings gebruik je enkele aanhalingstekens; dubbele aanhalingstekens zijn bedoeld voor interpolatie of escapes.

**Herkomst**

Projectspecificatie van upstream; [Puppet-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/style_guide.html). De geïnstalleerde native check bepaalt de hieronder beschreven dekking.

**Toepassingsgebied**

Letterlijke strings, interpolaties en bekende escapetekens in Puppet.

**Automatische controle**

`double_quoted_strings`

**Detectiegrenzen**

Inspecteert STRING-tokens zonder herkenbare escapes; apostrofs, nieuwe regels, tabs, backslashes en bekende escapes worden ontzien. Interpolatietokens vallen buiten deze waarschuwing. De bronvorm van iedere escape blijft review.

**Meldingen en severity**

`double quoted string containing no variables`: `warning` bij een geselecteerde letterlijke dubbele string.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Zet het geselecteerde token om naar SSTRING. Alleen de gedetecteerde vorm zonder herkenbare escapes is bedoeld; genegeerde en syntaxfoute invoer krijgt geen CLI-correctie. Behoud de effectieve stringwaarde.

**Toegestane uitzonderingen**

Dubbele quotes blijven toegestaan voor interpolatie of escapes.

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Fragment; controle `double_quoted_strings`; verwacht warning.

<!-- lint-example: double_quoted_strings warning -->
```puppet
$label = "Example"
```

**Correct voorbeeld**

Fragment; controle `double_quoted_strings`; verwacht geen melding.

<!-- lint-example: double_quoted_strings clean -->
```puppet
$label = 'Example'
```

**Grensgevallen**

Inspecteert STRING-tokens zonder herkenbare escapes; apostrofs, nieuwe regels, tabs, backslashes en bekende escapes worden ontzien. Interpolatietokens vallen buiten deze waarschuwing. De bronvorm van iedere escape blijft review. Dubbele quotes blijven toegestaan voor interpolatie of escapes.

**Handmatige review**

Vergelijk de effectieve inhoud, interpolatie en escapes; controleer een string met apostrof handmatig wanneer de detectie haar overslaat.

**Verificatie**

De gemarkeerde voorbeeldparen worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). Voor de beschreven quote- en pijlcorrecties controleert [guide_examples_test.rb](test/guide_examples_test.rb) exacte uitvoer, hercontrole en tweede run. Vergelijk de effectieve inhoud, interpolatie en escapes; controleer een string met apostrof handmatig wanneer de detectie haar overslaat.

#### Selectors vóór resources berekenen

**Norm**

Bereken de uitkomst van een selector vóór de resource die deze gebruikt. Zo blijft in de resourcedeclaratie zichtbaar welke waarde wordt ingesteld.

**Herkomst**

Projectspecificatie van upstream; [Puppet-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/style_guide.html). De geïnstalleerde native check bepaalt de hieronder beschreven dekking.

**Toepassingsgebied**

Selectors die waarden voor resource-attributen leveren.

**Automatische controle**

`selector_inside_resource`

**Detectiegrenzen**

Herkent in resource_tokens alleen => gevolgd door een variabele en direct daarna ?. Andere expressievormen bewijzen geen afwezigheid van een selector.

**Meldingen en severity**

`selector inside resource block`: `warning` op de betreffende pijl.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de native check heeft geen autofix omdat verplaatsing de evaluatiecontext raakt.

**Toegestane uitzonderingen**

Geen uitzondering gedocumenteerd voor een selector in een resource.

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Fragment; controle `selector_inside_resource`; verwacht warning.

<!-- lint-example: selector_inside_resource warning -->
```puppet
notify { 'example': message => $active ? { true => 'Active', default => 'Inactive' } }
```

**Correct voorbeeld**

Fragment; controle `selector_inside_resource`; verwacht geen melding.

<!-- lint-example: selector_inside_resource clean -->
```puppet
$message = $active ? { true => 'Active', default => 'Inactive' }
notify { 'example': message => $message }
```

**Grensgevallen**

Herkent in resource_tokens alleen => gevolgd door een variabele en direct daarna ?. Andere expressievormen bewijzen geen afwezigheid van een selector. Geen uitzondering gedocumenteerd voor een selector in een resource.

**Handmatige review**

Controleer dat de voorbereide waarde vóór de resource beschikbaar is, binnen hetzelfde geldige pad wordt berekend en dezelfde selectorsemantiek houdt.

**Verificatie**

De gemarkeerde voorbeeldparen worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). Voor de beschreven quote- en pijlcorrecties controleert [guide_examples_test.rb](test/guide_examples_test.rb) exacte uitvoer, hercontrole en tweede run. Controleer dat de voorbereide waarde vóór de resource beschikbaar is, binnen hetzelfde geldige pad wordt berekend en dezelfde selectorsemantiek houdt.

#### Functionele resourcevolgorde beoordelen

**Norm**

Kies ook de volgorde van resources en gegenereerde configuratie bewust: de linter kan de opmaak controleren, maar bepaalt niet welke volgorde functioneel nodig is.

**Herkomst**

Projectregel

**Toepassingsgebied**

Resources en gegenereerde configuratie met evaluatie- of runtimeafhankelijkheden.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Opmaak bewijst geen catalogusrelatie of runtimevolgorde. Zie [Volgorde en meldingen](#volgorde-en-meldingen) voor de plaatsingscriteria.

**Meldingen en severity**

Geen lintmelding of severity voor functionele volgorde; dit vereist inhoudelijke review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze norm heeft geen autofix.

**Toegestane uitzonderingen**

De concrete plaatsingsuitzonderingen staan bij [Resources bij hun voorziening plaatsen](#resources-bij-hun-voorziening-plaatsen).

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Handmatig reviewscenario: configuratie verwijst naar een waarde die pas later op een ander uitvoerpad wordt voorbereid; keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: bereid de waarde op het geldige pad vóór gebruik voor en behoud de vereiste resource- en notificatierelaties.

**Grensgevallen**

Een juist uitgelijnde resource kan functioneel verkeerd geplaatst zijn. Een afhankelijkheidsrelatie bewijst niet dat een classvariabele al geëvalueerd is.

**Handmatige review**

Volg de voorbereiding en iedere afnemer door de relevante branches; controleer ook de gegenereerde configuratievolgorde.

**Verificatie**

Handmatige vergelijking van beide scenario’s: de correcte variant levert de waarde vóór gebruik op hetzelfde geldige pad. Lint is hiervoor geen bewijs.

##### Gedeelde dekking van basisopmaak

De standaardchecks en geïnstalleerde plugins controleren onder meer witruimte, aanhalingstekens, parameterdatatypen en afsluitende komma's. De projectchecks vullen deze controles aan. Bij [autofix](#automatisch-corrigeren-autofix) gelden voor beide dezelfde eisen aan behoud van gedrag.

De projectconfiguratie gebruikt alle standaard ingeschakelde checks en schakelt daarnaast `class_inherits_from_params_class` in. Ook nieuwe standaardchecks komen bij een update beschikbaar. De optionele checks voor 80 tekens, booleans tussen aanhalingstekens en code op hoofdniveau staan uit: dit project gebruikt een grens van 140 tekens en ondersteunt daemonstrings zoals `'true'` en uitvoerbare profielen. Bestaande stijlachterstand is geen reden om een check uit te schakelen of een module uit te zonderen.

### Inspringing

**Norm**

Bij een array over meerdere regels bepaalt de regel met `[` de inspringing. De elementen staan twee spaties verder naar rechts; een afsluitende `]` aan het begin van een regel staat op hetzelfde niveau als de openingsregel. Dat geldt ook als de array in een functieaanroep staat:

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Meerregelige arrayliterals in toekenningen, functieargumenten, geneste arrays en resourcetitels.

**Automatische controle**

`project_layout`

**Detectiegrenzen**

Datatypeparameters en indexeringen zijn geen arrays. Alleen elementen en sluitende haken aan het begin van een fysieke regel worden uitgelijnd; string-, heredoc- en commentaarinhoud blijft intact.

**Meldingen en severity**

`Use {aantal} leading spaces for the array element` en `Use {aantal} leading spaces for the closing array bracket`: `warning` bij afwijkende inspringing; `{aantal}` is variabel.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Corrigeert alleen witruimte vóór arraytokens. Geneste arrays worden als groep behandeld; een genegeerd bereik of niet meer veilig vindbaar tokenanker verhindert correctie.

**Toegestane uitzonderingen**

Meerdere elementen op één regel zijn toegestaan. Een resourcetitel direct na `file { [` krijgt het hieronder beschreven extra niveau.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_layout` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_layout warning -->
```puppet
$values = [
      'first',
]
```

**Correct voorbeeld**

Fragment; alleen de controle `project_layout` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_layout clean -->
```puppet
$values = [
  'first',
]
```

**Grensgevallen**

Meerdere elementen op één regel zijn toegestaan. Een resourcetitel direct na `file { [` krijgt het hieronder beschreven extra niveau. Datatypeparameters en indexeringen zijn geen arrays. Alleen elementen en sluitende haken aan het begin van een fysieke regel worden uitgelijnd; string-, heredoc- en commentaarinhoud blijft intact. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Inspringing](#verdieping-bij-inspringing).

**Handmatige review**

Vergelijk de inhoud en volgorde van de elementen en de resourcetitels vóór en na correctie; beoordeel de inhoudelijke plaats van comments afzonderlijk.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [array_layout_test.rb](test/array_layout_test.rb), [layout_autofix_test.rb](test/layout_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Inspringing

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_layout` gecontroleerd.

<!-- lint-example: project_layout clean -->
```puppet
$label = join([
  'first',
  'second',
], ' ')
```

Extra functiehaakjes, bijvoorbeeld in `Sensitive.new(join([`, voegen geen inspringniveau toe. De array volgt het omliggende codeblok. Alleen een array die als resourcetitel direct achter de accolade begint, zoals `file { [`, krijgt een extra niveau: de elementen staan vier spaties verder dan `file` en de afsluitende `]` twee spaties.

`project_layout` controleert het begin van array-elementen op een nieuwe regel en de afsluitende `]`. Meerdere elementen op één regel zijn toegestaan. Met `--fix` herstelt de check de inspringing, inclusief die van geneste arrays. Stringinhoud, heredocs en commentaar blijven behouden. Vierkante haken in datatypeparameters of indexeringen worden niet als arrays behandeld.

### Komma's

<!-- lint-rule-group -->

#### Spatie na komma’s

**Norm**

Zet één spatie na een komma wanneer het volgende element op dezelfde regel staat.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Kommatokens met een volgend code-element op dezelfde fysieke regel.

**Automatische controle**

`project_layout`

**Detectiegrenzen**

De projectcheck analyseert parameterlijsten; de plugin verzorgt resources en verzamelingen. Komma’s vóór een sluittoken vragen geen tussenruimte. Heredoc-einden vereisen handmatige plaatsing.

**Meldingen en severity**

`Use one space after a same-line comma`: `warning` bij afwijkende tussenruimte.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Herschrijft uitsluitend veilige witruimte tussen komma en volgend token; commentaar, genegeerde tokens of een ontbrekend tokenanker verhinderen veilige correctie.

**Toegestane uitzonderingen**

Komma’s vóór een sluittoken en een volgend element op een andere regel vereisen hier geen tussenruimte.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_layout` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_layout warning -->
```puppet
$values = [1,2]
```

**Correct voorbeeld**

Fragment; alleen de controle `project_layout` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_layout clean -->
```puppet
$values = [1, 2]
```

**Grensgevallen**

Een volgende ]/}/) wordt overgeslagen. Commentaar tussen komma en waarde krijgt geen verschuiving. Meerdere elementen op dezelfde regel blijven toegestaan.

**Handmatige review**

Controleer de scheiding van argumenten en plaats de komma bij een heredoc met de Puppet-parser als aanvullende controle.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [layout_autofix_test.rb](test/layout_autofix_test.rb), [cli_layout_test.rb](test/cli_layout_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Meerregelige lijsten met een komma afsluiten

**Norm**

Sluit een parameterlijst over meerdere regels af met een komma na de laatste parameter. Ook resources en verzamelingen over meerdere regels krijgen een afsluitende komma.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Meerregelige class-/defineparameters, resources, arrays en hashes.

**Automatische controle**

`project_layout`, `trailing_comma`

**Detectiegrenzen**

De projectcheck analyseert parameterlijsten; de plugin verzorgt resources en verzamelingen. Komma’s vóór een sluittoken vragen geen tussenruimte. Heredoc-einden vereisen handmatige plaatsing.

**Meldingen en severity**

`End a multiline parameter block with a trailing comma`: `warning` van project_layout. `missing trailing comma after last element`: `warning` van de plugin.

**Autofix**

Voorwaardelijk voor beide varianten.

**Autofixvoorwaarden**

Voegt een komma toe na het laatst herkende element. Een parameter met een detached heredoc-terminator wordt door de projectfix geweigerd; plaats de komma handmatig en valideer met de parser. De plugin volgt native tokenposities; controleer de resulterende syntax.

**Toegestane uitzonderingen**

Een eenregelige lijst verlangt geen kunstmatige meerregelige vorm. Een heredoc is geen uitzondering op de komma-eis, alleen op de veilige autofix.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_layout`; verwacht warning.

<!-- lint-example: project_layout warning -->
```puppet
class example (
  String $label
) {}
```

**Correct voorbeeld**

Fragment; alleen `project_layout`; verwacht geen melding.

<!-- lint-example: project_layout clean -->
```puppet
class example (
  String $label,
) {}
```

**Grensgevallen**

Eenregelige parameterlijst: toegestaan zonder eindkomma. Meerregelige parameter met heredoc: handmatig. Resources en verzamelingen vallen onder trailing_comma; project_layout behandelt parameters.

**Handmatige review**

Controleer de scheiding van argumenten en plaats de komma bij een heredoc met de Puppet-parser als aanvullende controle.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [layout_autofix_test.rb](test/layout_autofix_test.rb), [cli_layout_test.rb](test/cli_layout_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Meerregelige lijsten met een komma afsluiten

`project_layout` controleert de spaties en de laatste komma in parameterlijsten; de trailing-comma-plugin controleert resources en verzamelingen. Autofix herstelt de spaties alleen als er geen commentaar tussen de betrokken onderdelen staat. Bij een parameter die eindigt met een heredoc voeg je de laatste komma handmatig op de juiste plaats toe. De autofix kan daar niet veilig bepalen waar de parameter eindigt.

### Lange regels

**Norm**

Houd Puppet-code binnen 140 tekens per regel. Lange arrays en functieaanroepen kun je over meerdere regels verdelen. Laat je een regel bewust langer, voeg dan `# lint:ignore:140chars` toe achter de code. Zo blijft de uitzondering zichtbaar bij de review. De [verdieping bij deze regel](#verdieping-bij-lange-regels) toont de plaatsing bij een lange download-URL.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Fysieke Puppet-coderegels, codecommentaar en de apart behandelde Puppet Strings-blokken.

**Automatische controle**

`140chars`, `project_documentation_layout`

**Detectiegrenzen**

`140chars` slaat bepaalde URL- en template-regels over. De projectnorm verlangt daar toch een zichtbare markering; dat blijft review. Strings wordt apart beoordeeld.

**Meldingen en severity**

`line has more than 140 characters`: `warning` van `140chars`. `project_suppressions` meldt `Only targeted 140chars and puppet_url_without_modules suppressions are allowed; fix other lint violations`: `error`. Strings-varianten staan bij [Puppet Strings](#puppet-strings).

**Autofix**

Geen voor `140chars` en `project_suppressions`; Voorwaardelijk voor de afzonderlijke Strings-varianten

**Autofixvoorwaarden**

De lengtecheck breekt code niet af. Voor afbreekbare documentatie gelden uitsluitend de voorwaarden bij [Puppet Strings](#puppet-strings).

**Toegestane uitzonderingen**

Bewust lange code met een lokale markering; bij Strings uitsluitend ondeelbare letterlijke waarden. Alle plaatsingsvoorwaarden hieronder blijven gelden.

**Suppressions**

Alleen `# lint:ignore:140chars` achter de code of een minimaal blok met `# lint:endignore`; voor `puppet_url_without_modules` gelden de voorwaarden bij bestandsbronnen. Combineren is toegestaan; geen andere check uitschakelen.

**Onjuist voorbeeld**

Fragment; alleen de controle `140chars` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: 140chars warning -->
```puppet
$value = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
```

**Correct voorbeeld**

Fragment; alleen de controle `140chars` is voor dit voorbeeld bedoeld. De melding krijgt `ignored` en is zonder `--show-ignored` niet zichtbaar; de expliciete uitzondering voldoet aan het projectbeleid.

<!-- lint-example: 140chars ignored -->
```puppet
$value = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' # lint:ignore:140chars
```

**Grensgevallen**

Bewust lange code met een lokale markering; bij Strings uitsluitend ondeelbare letterlijke waarden. Alle plaatsingsvoorwaarden hieronder blijven gelden. `140chars` slaat bepaalde URL- en template-regels over. De projectnorm verlangt daar toch een zichtbare markering; dat blijft review. Strings wordt apart beoordeeld. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Lange regels](#verdieping-bij-lange-regels).

**Handmatige review**

Meet ook overgeslagen URL- en template-regels. Controleer dat de markering Puppet-commentaar is en dat een ignoreblok vóór de volgende gewone documentatieregel sluit.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [suppression_policy_test.rb](test/suppression_policy_test.rb), [documentation_suppressions_test.rb](test/documentation_suppressions_test.rb), [documentation_width_test.rb](test/documentation_width_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Lange regels

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_suppressions` gecontroleerd.

<!-- lint-example: project_suppressions clean -->
```puppet
$download_url = 'https://downloads.example.org/releases/application/stable/linux/amd64/packages/application-with-optional-components-and-offline-documentation.tar.gz' # lint:ignore:140chars
```

De markering hoort in Puppet-commentaar, buiten de waarde. Staat daar al een toelichting, zet de markering dan direct na `#` en vóór die toelichting. Heeft een string of heredoc over meerdere regels een lengte-uitzondering nodig, zet dan `# lint:ignore:140chars` vóór de waarde en `# lint:endignore` erna. Houd dat blok zo klein mogelijk. Binnen de string of heredoc zou de markering als inhoud worden verwerkt, bijvoorbeeld in een beheerd bestand of shellcommando. Daar is zij daarom niet toegestaan.

Gewoon codecommentaar volgt de afspraak van [één zin per fysieke regel](#toelichtingen-bij-code). Bij een bewust lange commentaarregel kun je een begrensd ignoreblok gebruiken.

Bij [Puppet Strings](#puppet-strings) verdeel je een beschrijving over meerdere commentregels. Een lange beschrijvende zin heeft dus geen lengte-uitzondering nodig. Alleen een letterlijke waarde die niet zonder betekenisverlies kan worden afgebroken mag langer blijven. Sluit het ignoreblok vóór de volgende gewone documentatieregel.

De standaardcheck `140chars` meldt lange regels, maar slaat bepaalde regels met URL's of `template(...)` over. Ook op die overgeslagen regels vraagt de projectafspraak een markering; controleer dat bij de review. `project_documentation_layout` controleert de lengte en uitzonderingen in Puppet Strings afzonderlijk. De standaardcheck heeft geen autofix; gewone Strings-tekst kan de documentatiecheck wel afbreken.

#### Alleen toegestane suppressions gebruiken

**Norm**

`project_suppressions` controleert welke checks via commentaar worden uitgezonderd. Alleen `140chars` en de beschreven uitzondering voor [Puppet-fileserverbronnen](#templates-en-bestandsbronnen) zijn toegestaan, eventueel samen. De noodzaak en begrenzing van de uitzondering beoordeel je zelf. Gebruik [`--show-ignored`](#werking-van-de-controles) om te zien welke meldingen door zulke markeringen worden onderdrukt. Neem je een codevoorbeeld uit documentatie over in een manifest, voeg dan daar een eigen markering toe aan bewust lange regels.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Lintcontrolemarkeringen in Puppet-commenttokens, niet gelijknamige tekst in string- of heredoc-inhoud.

**Automatische controle**

`project_suppressions`

**Detectiegrenzen**

De check controleert de genoemde suppressienamen. Noodzaak, exacte begrenzing en de norm op native overgeslagen URL/template-regels blijven handmatige review.

**Meldingen en severity**

`Only targeted 140chars and puppet_url_without_modules suppressions are allowed; fix other lint violations`: `error` bij een niet-toegestane suppressie.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de beleidscheck verwijdert geen markering; inhoudelijke fouten moeten worden hersteld.

**Toegestane uitzonderingen**

Alleen 140chars en de gerichte puppet_url_without_modules-uitzondering voor files-bronnen, eventueel samen. Zie de lengte- en mountregels voor hun voorwaarden.

**Suppressions**

Suppressie van project_suppressions is niet toegestaan. Toegestane syntax: # lint:ignore:140chars of # lint:ignore:puppet_url_without_modules, lokaal achter de relevante code of minimaal begrensd met # lint:endignore volgens de bijbehorende regel.

**Onjuist voorbeeld**

Fragment; alleen `project_suppressions`; verwacht error.

<!-- lint-example: project_suppressions error -->
```puppet
# lint:ignore:project_arrays
$values = [1] + [2]
# lint:endignore
```

**Correct voorbeeld**

Fragment; alleen `project_suppressions`; verwacht geen melding.

<!-- lint-example: project_suppressions clean -->
```puppet
$values = concat([1], [2])
```

**Grensgevallen**

De twee toegestane namen mogen worden gecombineerd. Iedere andere naam, brede uitschakeling of onderdrukking van deze beleidscheck is niet toegestaan. Een markering in stringinhoud is data en heft geen norm op.

**Handmatige review**

Controleer de noodzaak en begrenzing van elke markering, bekijk --show-ignored en voeg bij overgenomen codevoorbeelden de benodigde lokale markering in het echte manifest toe.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door guide_examples_test.rb. [suppression_policy_test.rb](test/suppression_policy_test.rb) controleert namen en commenttokens; [documentation_suppressions_test.rb](test/documentation_suppressions_test.rb) controleert de afzonderlijke documentatiegrenzen.

### Parameters en resources

<!-- lint-rule-group -->

#### Parameters en instellingen

<!-- lint-rule-group -->

#### Classes en defines bruikbaar ontwerpen

**Norm**

Ontwerp classes en defined types zo dat ze afzonderlijk en in combinatie bruikbaar zijn.

**Herkomst**

Projectregel

**Toepassingsgebied**

Classes en defined types die afzonderlijk en gecombineerd worden gebruikt.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Type- en aanroepchecks bewijzen geen bruikbaarheid van een modulecombinatie.

**Meldingen en severity**

Geen lintmelding of severity voor zelfstandige en gecombineerde bruikbaarheid.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze ontwerpnorm vereist inhoudelijke review.

**Toegestane uitzonderingen**

Geen uitzondering gedocumenteerd; verklaar noodzakelijke prerequisites in de interface.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Handmatig reviewscenario: een class werkt alleen door een ongedocumenteerde resource uit een andere module. Keur die verborgen prerequisite af.

**Correct voorbeeld**

Handmatig reviewscenario: beschrijf en lever de benodigde prerequisite en behoud de werking bij afzonderlijk en gecombineerd gebruik.

**Grensgevallen**

Een expliciete vereiste parentclass kan onderdeel van het contract zijn; een toevallige classdeclaratie is geen garantie.

**Handmatige review**

Controleer prerequisites, resource-eigendom en dubbele declaraties bij afzonderlijk gebruik en iedere geraakte combinatie.

**Verificatie**

Handmatige vergelijking van de beschreven scenario’s; controleer het interfacecontract en benodigde afhankelijkheden. Een groene lintscan is geen catalogusbewijs.

#### Publieke parameters expliciet typeren

**Norm**

Geef publieke parameters een expliciet datatype, met een ingebouwd Puppet-type of een passende typealias.

**Herkomst**

Projectspecificatie van upstream; [parameter-types-plugin](https://github.com/voxpupuli/puppet-lint-param-types).

**Toepassingsgebied**

Parameterlijsten van classes en defined types, met ingebouwde types en typealiases.

**Automatische controle**

`parameter_types`

**Detectiegrenzen**

De plugin herkent het begintoken van iedere parameter en slaat default-expressies met geneste haakjes over. De aanwezigheid van een type bewijst niet dat het type of de runtimewaarde juist is.

**Meldingen en severity**

`missing datatype for parameter {declaratie}::{parameter}`: `warning` bij een ongetypeerde parameter; namen zijn variabel.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de plugin kan het bedoelde type niet afleiden.

**Toegestane uitzonderingen**

Een passende typealias is toegestaan naast een ingebouwd Puppet-type; geen ongetypeerde uitzondering gedocumenteerd.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `parameter_types`; verwacht warning.

<!-- lint-example: parameter_types warning -->
```puppet
class example ($label) {}
```

**Correct voorbeeld**

Fragment; alleen `parameter_types`; verwacht geen melding.

<!-- lint-example: parameter_types clean -->
```puppet
class example (String $label) {}
```

**Grensgevallen**

Geneste datatypeparameters en defaults met arrays, hashes of functieaanroepen blijven afzonderlijke parameterconstructies. Een Optional-type zonder default levert geen waarde bij een ontbrekend argument.

**Handmatige review**

Vergelijk het gekozen type, undef-toelating en eventuele grenzen met de werkelijke publieke interface.

**Verificatie**

De gemarkeerde paren draaien in guide_examples_test.rb; [interface_contract_test.rb](test/interface_contract_test.rb), test_nested_parameter_types_and_multiline_defaults, controleert geneste types/defaults. Catalogusvalidatie blijft nodig voor typebetekenis.

#### Parameters met defaultafhankelijkheden sorteren

**Norm**

Voor de sortering gebruikt het project twee groepen. Eerst komen parameters zonder default en zonder buitenste `Optional[...]`. Daarna volgen de parameters met een default of `Optional[...]`. Sorteer beide groepen alfabetisch. Dit fragment laat de indeling zien:

`$label` staat hier in de tweede groep, maar blijft verplicht bij een aanroep: `Optional[String]` staat `undef` toe en levert zelf geen default. Voeg geen default toe om alleen de sortering te veranderen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Publieke class- en defined-typeparameters, hun getypeerde declaratieblokken en lokale defaultafhankelijkheden.

**Automatische controle**

`project_parameter_order`

**Detectiegrenzen**

`Optional` zonder default blijft vereist bij een aanroep. Uitlijning slaat ongetypeerde blokken over. Cyclische lokale defaults geven een uitvoerfout; de check lost de cyclus niet op. Betekenisvolle naamgeving en veilige configuratiekeuzes blijven review.

**Meldingen en severity**

`Put mandatory parameters first, then optional parameters; sort each group alphabetically subject to local default dependencies`, `A local default refers to a parameter that must be declared earlier` en `Explain the necessary default dependency in a trailing comment naming the dependent parameter`: `warning`.

**Autofix**

Geen voor alle drie meldingsvarianten.

**Autofixvoorwaarden**

Niet van toepassing: de check herschikt geen parameters; lokale defaults kunnen de evaluatievolgorde veranderen.

**Toegestane uitzonderingen**

Een lokale defaultafhankelijkheid doorbreekt de normale volgorde met de voorgeschreven toelichting; Optional zonder default blijft vereist bij een aanroep.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_parameter_order` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_parameter_order warning -->
```puppet
class example (String $zulu, String $alpha) {}
```

**Correct voorbeeld**

Fragment; alleen de controle `project_parameter_order` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_parameter_order clean -->
```puppet
class example (String $alpha, String $zulu) {}
```

**Grensgevallen**

Lokale defaultafhankelijkheid doorbreekt de alfabetische volgorde met de voorgeschreven trailing comment. Een buitenste `Optional` staat in groep twee zonder daardoor een default te krijgen. Gesplitste beveiligingsparameters alleen wegens compatibiliteit. `Optional` zonder default blijft vereist bij een aanroep. Uitlijning slaat ongetypeerde blokken over. Cyclische lokale defaults geven een uitvoerfout; de check lost de cyclus niet op. Betekenisvolle naamgeving en veilige configuratiekeuzes blijven review. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Parameters met defaultafhankelijkheden sorteren](#verdieping-bij-parameters-met-defaultafhankelijkheden-sorteren).

**Handmatige review**

Controleer beide sorteergroepen, iedere lokale defaultafhankelijkheid en de trailing comment met de afhankelijke $naam. Voeg geen default toe alleen om te sorteren.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [interface_contract_test.rb](test/interface_contract_test.rb), [layout_autofix_test.rb](test/layout_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Parameters met defaultafhankelijkheden sorteren

Voor de sortering gebruikt het project twee groepen. Eerst komen parameters zonder default en zonder buitenste `Optional[...]`. Daarna volgen de parameters met een default of `Optional[...]`. Sorteer beide groepen alfabetisch en lijn de typen, namen, `=`-tekens en defaults over het hele parameterblok uit. Dit fragment laat de indeling zien:

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_parameter_order, project_parameter_alignment` gecontroleerd. Omgeef het voor uitvoering met `class example (` en `) {}`.

<!-- lint-example: project_parameter_order, project_parameter_alignment clean parameters -->
```puppet
  String           $value,
  Optional[String] $label,
  Integer          $timeout = 30,
```

`$label` staat hier in de tweede groep, maar blijft verplicht bij een aanroep: `Optional[String]` staat `undef` toe en levert zelf geen default. Voeg geen default toe om alleen de sortering te veranderen.

Een default kan de normale volgorde doorbreken wanneer hij de waarde van een andere parameter gebruikt. Declareer die andere parameter dan eerder. Schuift hij daarmee vóór zijn normale alfabetische positie, leg de reden uit in commentaar achter die parameter en noem daarin de afhankelijke parameter met `$naam`.

`project_parameter_order` controleert de groepen, volgorde, defaultafhankelijkheden en die toelichting. De check sorteert niet automatisch. `project_parameter_alignment` kan de uitlijning herstellen wanneer de parameters op afzonderlijke regels staan en de tussenruimte geen commentaar bevat. Ook geneste typen en defaults over meerdere regels worden meegenomen. Meerdere parameters op één regel, onduidelijke tussenruimte en genegeerde delen vragen handmatige beoordeling.

#### Parameterblokken volledig uitlijnen

**Norm**

Lijn de typen, namen, `=`-tekens en defaults over het hele parameterblok uit.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Volledig getypeerde parameterblokken van classes en defined types, inclusief verplichte parameters en meerregelige types of defaults.

**Automatische controle**

`project_parameter_alignment`

**Detectiegrenzen**

`Optional` zonder default blijft vereist bij een aanroep. Uitlijning slaat ongetypeerde blokken over. Cyclische lokale defaults geven een uitvoerfout; de check lost de cyclus niet op. Betekenisvolle naamgeving en veilige configuratiekeuzes blijven review.

**Meldingen en severity**

`Align parameter names after the widest type across the complete parameter block`, `Align parameter equals signs across the complete parameter block` en `Use one space between the aligned equals sign and a same-line default`: `warning`.

**Autofix**

Voorwaardelijk voor alle drie meldingsvarianten.

**Autofixvoorwaarden**

Alle parameters moeten getypeerd zijn, op afzonderlijke regels staan en uitsluitend veilige witruimte tussen type, naam, `=` en default hebben. Geen commentaar of genegeerd bereik verplaatsen. Eerdere quote-/kommafixes worden in de actuele breedte meegenomen.

**Toegestane uitzonderingen**

Geen afwijkende uitlijningsnorm; niet veilig te corrigeren vormen vragen handmatige correctie.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_parameter_alignment`; verwacht warning.

<!-- lint-example: project_parameter_alignment warning -->
```puppet
class example (
  String $alpha,
  Optional[String] $label,
) {}
```

**Correct voorbeeld**

Fragment; alleen `project_parameter_alignment`; verwacht geen melding.

<!-- lint-example: project_parameter_alignment clean -->
```puppet
class example (
  String           $alpha,
  Optional[String] $label,
) {}
```

**Grensgevallen**

Ongetypeerde blokken worden overgeslagen. Meer parameters op één regel, commentaar tussen type/naam/=/default en genegeerde delen weigeren autofix. Geneste types en meerregelige defaults worden meegenomen. Eerdere quote- en kommafixes veranderen de opnieuw berekende breedte.

**Handmatige review**

Controleer type, parameternaam en default vóór en na witruimtecorrectie, en behoud comments op hun oorspronkelijke parameter.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [interface_contract_test.rb](test/interface_contract_test.rb), [layout_autofix_test.rb](test/layout_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Beveiligingsinstellingen met één waardekeuze modelleren

**Norm**

Biedt een beveiligingsinstelling een veilige standaardwaarde, een uitschakelmogelijkheid en een eigen waarde, gebruik dan één parameter met `Variant[Boolean, String]` of een passende beperkte scalarvariant. Daarbij kiest `true` de veilige standaardwaarde, laat `false` de instelling weg en levert een scalar de eigen waarde. Bereken de effectieve waarde eenmaal in een `*_correct`-variabele die de template gebruikt. Alleen wanneer compatibiliteit dat vereist, splits je dit in afzonderlijke enable/custom/value-parameters.

**Herkomst**

Projectregel

**Toepassingsgebied**

Instellingen met veilige standaard, uitschakeling en eigen scalarwaarde.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Parameters en instellingen](#parameters-en-instellingen).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Alleen een compatibiliteitsvereiste rechtvaardigt afzonderlijke enable/custom/value-parameters.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Alleen een compatibiliteitsvereiste rechtvaardigt afzonderlijke enable/custom/value-parameters.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Drie nieuwe parameters modelleren enable, default en custom zonder compatibiliteitsreden. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik één passende Variant; bereken eenmaal de *_correct-waarde en gebruik die in de template. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Alleen een compatibiliteitsvereiste rechtvaardigt afzonderlijke enable/custom/value-parameters.

**Handmatige review**

Controleer true als veilige standaard, false als weglaten en scalar als eigen waarde in iedere gerenderde variant.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer true als veilige standaard, false als weglaten en scalar als eigen waarde in iedere gerenderde variant. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Parameternamen op onderwerp kiezen

**Norm**

Kies namen in snake_case die beginnen met het onderwerp, gevolgd door de nadere aanduiding: bijvoorbeeld `bandwidth_max`, `p95_warning` of `secret_key_fallback`. Een naam die met een cijfer begint is alleen bruikbaar als dat op alle ondersteunde runtimes is getest.

**Herkomst**

Projectregel

**Toepassingsgebied**

Namen van publieke en lokale Puppet-parameters.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Parameters en instellingen](#parameters-en-instellingen).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een beginletter is niet als extra norm ingevoerd: de bestaande uitzondering voor een getest begincijfer blijft bestaan.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een beginletter is niet als extra norm ingevoerd: de bestaande uitzondering voor een getest begincijfer blijft bestaan.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een parameter heet maxBandwidth. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik een snake_case-naam die met het onderwerp begint, zoals bandwidth_max. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een beginletter is niet als extra norm ingevoerd: de bestaande uitzondering voor een getest begincijfer blijft bestaan.

**Handmatige review**

Controleer naamvolgorde en test een cijfer aan het begin op iedere ondersteunde runtime.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer naamvolgorde en test een cijfer aan het begin op iedere ondersteunde runtime. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Voorwaarden en validatie

<!-- lint-rule-group -->

#### De grootste verwerking vóór de korte afhandeling plaatsen

**Norm**

Zet de omvangrijkste verwerking in de eerste tak van een voorwaarde en de kortere afhandeling in de laatste `else`. Een korte foutmelding of terugvalwaarde komt zo na de code die het normale werk uitvoert. De voorwaarde mag daarvoor een ontkenning bevatten. Gelijke takken en een `if` zonder vervolgtak zijn toegestaan; voor `unless` geldt dezelfde volgorde.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

If/unless/elsif met een afzonderlijke vervolgtak.

**Automatische controle**

`project_positive_flow`

**Detectiegrenzen**

Structuur telt; tekstlengte en gewone functieargumenten tellen niet mee. Namespaced eigen functies, functiedeclaraties en parameterdefaults vallen buiten de validatieanalyse. Behoud prioriteit van overlappende elsif-voorwaarden.

**Meldingen en severity**

`Put the larger code branch first and keep shorter handling in the final else; preserve condition semantics and elsif priority`: `warning` bij een kleinere eerste tak dan een vervolgtak.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Gelijke takken en een if zonder vervolgtak zijn toegestaan. Uitsluitend diagnostische foutafhandeling blijft achteraan, ook wanneer voorbereiding en meldingen groter zijn.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_positive_flow` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_positive_flow warning -->
```puppet
if $active { notice('One') } else { notice('One'); notice('Two') }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_positive_flow` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_positive_flow clean -->
```puppet
if !$active { notice('One'); notice('Two') } else { notice('One') }
```

**Grensgevallen**

Gelijke takken en if zonder vervolgtak zijn toegestaan. Een uitsluitend diagnostische fouttak blijft achteraan, ook als voorbereiding en meldingen groter zijn. Een bestaande case mag de laatste default gebruiken. Structuur telt; tekstlengte en gewone functieargumenten tellen niet mee. Namespaced eigen functies, functiedeclaraties en parameterdefaults vallen buiten de validatieanalyse. Behoud prioriteit van overlappende elsif-voorwaarden. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij De grootste verwerking vóór de korte afhandeling plaatsen](#verdieping-bij-de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen).

**Handmatige review**

Vergelijk structurele verwerkingsomvang, behoud waarheidsvoorwaarden en prioriteit van overlappende elsif-voorwaarden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [branch_size_test.rb](test/branch_size_test.rb), [validation_flow_test.rb](test/validation_flow_test.rb), [cli_flow_test.rb](test/cli_flow_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij De grootste verwerking vóór de korte afhandeling plaatsen

`project_positive_flow` controleert zowel de omvang van takken als de plaats van validatiemeldingen. Bij `elsif` vergelijkt de check iedere tak met de grootste afzonderlijke vervolgtak. Een expliciet geneste `if` telt als geneste code. De [technische naslag](#omvang-en-validatiestructuur) beschrijft de telling en welke aanroepen als validatiemelding worden herkend.

De check heeft geen autofix: het omkeren van een voorwaarde of verplaatsen van code kan de evaluatievolgorde veranderen. Behoud bij `elsif` de prioriteit van overlappende voorwaarden. Test steeds het geldige en ongeldige pad, vooral bij `warning()`: een waarschuwing stopt Puppet niet vanzelf.

#### Validatie om haar afhankelijke implementatie plaatsen

**Norm**

Bij invoervalidatie omsluit de geldige tak de implementatie die van die invoer afhankelijk is. Bereken de benodigde waarden vooraf en zet de bijbehorende `warning()` of `fail()` in de afsluitende `else`. Zijn meerdere controles nodig voor dezelfde implementatie, nest die dan. Een bestaande `case` mag zijn foutafhandeling in de laatste `default`-tak houden.

Een fouttak mag meerdere meldingen bevatten en lokale variabelen voorbereiden die voor die meldingen worden gebruikt. Andere verwerking hoort in de geldige tak. Laat de fouttak ook achteraan staan wanneer de meldingen en hun voorbereiding samen groter zijn dan de geldige tak.

Na zo'n validatie volgt binnen dezelfde class of hetzelfde defined type geen implementatiecode meer. Dat geldt ook wanneer de validatie in een buitenste `if`, `case` of lambda-aanroep staat: code ná dat buitenste blok zou buiten de geldige tak vallen. Een volgende `else` of alternatieve `case`-tak vormt een ander uitvoerpad en mag wel volgen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Bodies van classes en defined types met directe warning()/fail()-validatie, inclusief omvattende if/case/lambdablokken.

**Automatische controle**

`project_positive_flow`

**Detectiegrenzen**

Structuur telt; tekstlengte en gewone functieargumenten tellen niet mee. Namespaced eigen functies, functiedeclaraties en parameterdefaults vallen buiten de validatieanalyse. Behoud prioriteit van overlappende elsif-voorwaarden.

**Meldingen en severity**

`Put validation warning() and fail() calls in the final else (or case default), with regular implementation in the valid branch`: `warning` bij onjuiste fouttakplaatsing. `Keep the remaining implementation inside the valid branch; no implementation may follow this validation or its enclosing blocks within the class or defined type`: `warning` bij volgende implementatie buiten het geldige pad.

**Autofix**

Geen voor beide varianten.

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een bestaande case mag de laatste default als fouttak houden. Een volgende else of alternatieve case-tak is een afzonderlijk uitvoerpad en mag volgen. Fouttakken mogen lokale waarden uitsluitend voor hun meldingen voorbereiden.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_positive_flow`; verwacht warning.

<!-- lint-example: project_positive_flow warning -->
```puppet
class example {
  if $active { notice('Active') } else { fail('Inactive') }
  notice('Outside the valid branch')
}
```

**Correct voorbeeld**

Fragment; alleen `project_positive_flow`; verwacht geen melding.

<!-- lint-example: project_positive_flow clean -->
```puppet
class example {
  if $active { notice('Active'); notice('Inside the valid branch') } else { fail('Inactive') }
}
```

**Grensgevallen**

Gelijke takken en if zonder vervolgtak zijn toegestaan. Een uitsluitend diagnostische fouttak blijft achteraan, ook als voorbereiding en meldingen groter zijn. Een bestaande case mag de laatste default gebruiken. Structuur telt; tekstlengte en gewone functieargumenten tellen niet mee. Namespaced eigen functies, functiedeclaraties en parameterdefaults vallen buiten de validatieanalyse. Behoud prioriteit van overlappende elsif-voorwaarden. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Omvang en validatiestructuur](#omvang-en-validatiestructuur).

**Handmatige review**

Loop geldig en ongeldig pad door tot het einde van de class/define, ook na omvattende blokken. Controleer dat warning Puppet niet vanzelf stopt en dat afhankelijke implementatie daarom binnen de geldige tak blijft.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [branch_size_test.rb](test/branch_size_test.rb), [validation_flow_test.rb](test/validation_flow_test.rb), [cli_flow_test.rb](test/cli_flow_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Ruwe en geërfde waarden in templates onderscheiden

**Norm**

Wanneer een instelling een waarde erft, mag de template de ruwe parameter gebruiken om te bepalen of een regel nodig is. Voor de inhoud van die regel gebruikt de template de berekende waarde.

**Herkomst**

Projectregel

**Toepassingsgebied**

Templates met conditionele directives en berekende geërfde instellingen.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Voorwaarden en validatie](#voorwaarden-en-validatie).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. De ruwe parameter mag de aanwezigheid bepalen; zij vervangt niet de berekende inhoud.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

De ruwe parameter mag de aanwezigheid bepalen; zij vervangt niet de berekende inhoud.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een directive wordt met de ruwe undef-parameter gevuld terwijl de effectieve waarde beschikbaar is. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik de ruwe parameter uitsluitend om te beslissen of de regel nodig is, en de berekende waarde voor haar inhoud. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

De ruwe parameter mag de aanwezigheid bepalen; zij vervangt niet de berekende inhoud.

**Handmatige review**

Vergelijk de aanwezigheid van de regel en haar inhoud afzonderlijk voor expliciete en geërfde invoer.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Vergelijk de aanwezigheid van de regel en haar inhoud afzonderlijk voor expliciete en geërfde invoer. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Optionele waarden alleen bij gebruik valideren

**Norm**

Valideer een optionele instelling alleen als die daadwerkelijk wordt gebruikt of in configuratie terechtkomt. Een niet-ingestelde optionele waarde is op zichzelf geen fout. Bewaar het resultaat in een variabele met één korte foutmelding of `undef`, maak de resources in de geldige tak en faal in de laatste `else`. Een losse `fail(...)` halverwege de opbouw van waarden of resources past niet in deze structuur.

**Herkomst**

Projectregel

**Toepassingsgebied**

Optionele invoer die wel of niet in resources of configuratie terechtkomt.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Voorwaarden en validatie](#voorwaarden-en-validatie).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Niet-ingesteld is op zichzelf geen fout; een losse fail halverwege resources of waarden is geen toegestane structuur.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Niet-ingesteld is op zichzelf geen fout; een losse fail halverwege resources of waarden is geen toegestane structuur.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een ongebruikte optionele undef-waarde veroorzaakt een fout. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Valideer alleen gebruikte waarden, bewaar één korte foutmelding of undef en plaats resources in de geldige tak. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Niet-ingesteld is op zichzelf geen fout; een losse fail halverwege resources of waarden is geen toegestane structuur.

**Handmatige review**

Volg beide gebruikspaden en controleer dat de foutmelding in de laatste else staat.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Volg beide gebruikspaden en controleer dat de foutmelding in de laatste else staat. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Classcontroles hergebruiken

**Norm**

Gebruik binnen een class of defined type één gedeelde variabele als dezelfde classcontrole vaker nodig is. Gebruik een eenmaal gelezen zuivere classcontrole rechtstreeks; controleer indirecte afnemers vóór verwijderen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Letterlijke defined(Class)-controles in iedere class-/definebody, lokale resultaatvariabelen en vindbare classafnemers.

**Automatische controle**

`project_class_check_reuse`

**Detectiegrenzen**

Dynamische namen, parameterdefaults en indirecte lookups worden niet bewezen. Parenthergebruik vereist een positieve omvattende if; or, negatie, else en andere declaraties bewijzen geen beschikbaarheid.

**Meldingen en severity**

`Evaluate repeated defined(Class[...]) checks once in a shared variable within this class or define; preserve evaluation order`: `warning` bij herhaling. `Inline a defined(Class[...]) result used only once; keep a shared variable only for repeated use and preserve evaluation order`: `warning` bij één lezing. `Remove an unused defined(Class[...]) variable; verify indirect consumers before changing it`: `warning` bij nul lezingen. `[review] Reuse {classvariabele} from the guarded class instead of repeating defined(Class[...]); verify variable availability and evaluation order`: `warning` bij gevonden parentresultaat; `{classvariabele}` is variabel.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een samengestelde voorwaarde mag een eigen betekenisvolle naam houden. Vindbaar gebruik vanuit andere manifests, statische ERB en inline_template telt mee.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_class_check_reuse` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_class_check_reuse warning -->
```puppet
class example { notice(defined(Class['optional'])); notice(defined(Class['optional'])) }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_class_check_reuse` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_class_check_reuse clean -->
```puppet
class example { $enabled = defined(Class['optional']); notice($enabled); notice($enabled) }
```

**Grensgevallen**

Een samengestelde voorwaarde mag een eigen betekenisvolle naam houden. Vindbaar gebruik vanuit andere manifests, statische ERB en inline_template telt mee. Dynamische namen, parameterdefaults en indirecte lookups worden niet bewezen. Parenthergebruik vereist een positieve omvattende if; or, negatie, else en andere declaraties bewijzen geen beschikbaarheid. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Classcontroles hergebruiken](#verdieping-bij-classcontroles-hergebruiken).

**Handmatige review**

Controleer parentdeclaratie, positieve guard, iedere toekenning en afnemer en het evaluatiemoment; een tussenliggende classdeclaratie kan defined veranderen.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [parent_class_checks_test.rb](test/parent_class_checks_test.rb), [class_consumers_test.rb](test/class_consumers_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Classcontroles hergebruiken

Levert die class al het resultaat van een classcontrole, gebruik dan binnen de geldige tak die variabele. Zo verwijst een Docker-define naar `$docker::monitoring_enable` in plaats van opnieuw `defined(Class['basic_settings::monitoring'])` te berekenen. Controleer dat de class de variabele op dat uitvoerpad invult en dat de afnemer dezelfde betekenis en evaluatievolgorde nodig heeft.

Gebruik binnen een class of defined type één gedeelde variabele als dezelfde classcontrole vaker nodig is. Dat geldt ook bij gebruik in verschillende geneste blokken. Wordt de uitkomst maar één keer gebruikt, neem de controle dan rechtstreeks in de expressie op. Een samengestelde voorwaarde mag wel een eigen naam hebben, zoals `$active = $ensure == present and defined(Class['basic_settings::monitoring'])`: die naam beschrijft wanneer het onderdeel actief is.

`project_class_check_reuse` telt letterlijke classcontroles en vindbaar gebruik van hun resultaat, ook vanuit andere manifests en templates. Binnen een positieve classcontrole meldt hij ook beschikbare classvariabelen voor hergebruik. De [technische naslag](#classcontroles-en-vindbare-afnemers) beschrijft de grenzen van deze analyse. Dynamische classnamen, parameterdefaults en indirecte lookups beoordeel je zelf.

Er is geen autofix voor samenvoegen of inlinen. `defined(...)` kijkt naar wat tijdens evaluatie al bekend is; een classdeclaratie tussen twee controles kan de uitkomst veranderen. Controleer daarom de [declaratievolgorde](#resources-en-afhankelijkheden) en behoud afnemers die de statische analyse niet vindt.

#### Parentclass als prerequisite controleren

**Norm**

Een defined type dat zijn parentclass nodig heeft, controleert eerst `defined(Class['...'])`. Plaats alle code die van die class afhangt in de geldige tak en geef een duidelijke fout als de class ontbreekt.

**Herkomst**

Projectregel

**Toepassingsgebied**

Defined types die een parentclass of haar variabelen nodig hebben.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Classcontroles hergebruiken](#classcontroles-hergebruiken).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een eindcatalogus met de class bewijst niet dat zij vóór de controle geëvalueerd was.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een eindcatalogus met de class bewijst niet dat zij vóór de controle geëvalueerd was.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een define leest een parentvariabele voordat de aanwezigheid van de class is gecontroleerd. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Controleer defined(Class[...]), plaats afhankelijke code in de geldige tak en geef bij ontbreken een duidelijke fout. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een eindcatalogus met de class bewijst niet dat zij vóór de controle geëvalueerd was.

**Handmatige review**

Valideer de aanwezigheid en afwezigheid en de daadwerkelijke evaluatievolgorde van parent en afnemer.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Valideer de aanwezigheid en afwezigheid en de daadwerkelijke evaluatievolgorde van parent en afnemer. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Resources en afhankelijkheden

<!-- lint-rule-group -->

#### Optionele resource-attributen vooraf bepalen

**Norm**

Gebruik één declaratie met vooraf berekende waarden wanneer resources alleen in optionele attributen verschillen. Een niet-ingesteld attribuut krijgt `undef`. Zorg daarbij dat `source` en `content` nooit tegelijk gevuld zijn. `project_files` controleert of die uitsluiting uit de code volgt; onopgeloste of overgeërfde waarden vragen een controle van de effectieve catalogus.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

File-resources waarvan optionele source/content-attributen vooraf worden berekend.

**Automatische controle**

`project_files`

**Detectiegrenzen**

Zichtbare lokale resourcedefaults worden meegenomen. Letterlijke undef en herkenbare wederzijdse guards kunnen uitsluiting bewijzen; onbekende, overgeërfde of overridende waarden vragen catalogusreview. Het samenvoegen van overige optionele resource-attributen wordt niet automatisch beoordeeld.

**Meldingen en severity**

`[review] Prove source and content cannot both resolve to non-undef values`: `warning` wanneer wederzijdse uitsluiting niet statisch bewezen is.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Niet-ingestelde attributen krijgen undef; dat is geen uitzondering op wederzijdse uitsluiting.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_files`; verwacht warning.

<!-- lint-example: project_files warning -->
```puppet
file { '/tmp/example': ensure => file, owner => 'root', group => 'root', mode => '0600', source => $source, content => $content }
```

**Correct voorbeeld**

Fragment; alleen `project_files`; verwacht geen melding.

<!-- lint-example: project_files clean -->
```puppet
file { '/tmp/example': ensure => file, owner => 'root', group => 'root', mode => '0600', source => undef, content => 'Example' }
```

**Grensgevallen**

Twee onbekende waarden leveren review op, ook met een vergelijkbare variabelenaam. Een aantoonbare guard kan uitsluiting bewijzen. Controleer zowel geldige als ongeldige branches en effectieve cataloguswaarden.

**Handmatige review**

Controleer per uitvoerpad welke optionele attributen ingevuld zijn en dat source/content nooit beide een niet-undef-waarde krijgen. Behoud resourceattributen en relaties bij samenvoegen.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](test/resource_contract_test.rb), [source_uri_test.rb](test/source_uri_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Arrays met concat combineren

**Norm**

Combineer arrays met `concat($base, $extra)` en behoud de elementvolgorde. `project_arrays` meldt `+` bij herkenbare arrays, maar berekent geen dynamische typen en heeft geen autofix. Gebruik een eenmalige tussenvariabele wanneer de naam betekenis toevoegt of de code duidelijker maakt.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Optelling van herkenbare arraywaarden in Puppet-expressies.

**Automatische controle**

`project_arrays`

**Detectiegrenzen**

De check herkent arrayliterals en gevolgde lokale arraywaarden, maar berekent geen willekeurige dynamische typen. Een niet-herkende array blijft onder de norm vallen.

**Meldingen en severity**

`Combine arrays with concat(...) while preserving element order`: `warning` bij + met een herkenbare array.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Getal- en hashoptelling blijven toegestaan; een eenmalige tussenvariabele mag betekenis toevoegen of de leesbaarheid verbeteren.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_arrays` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_arrays warning -->
```puppet
$values = [1] + [2]
```

**Correct voorbeeld**

Fragment; alleen de controle `project_arrays` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_arrays clean -->
```puppet
$values = concat([1], [2])
```

**Grensgevallen**

Getal + getal en hash + hash: toegestaan. Arrayliteral + arrayliteral: warning. Onopgeloste waarden: type handmatig bepalen. concat bewaart de elementvolgorde.

**Handmatige review**

Bepaal de effectieve typen van dynamische waarden en vergelijk de volledige elementvolgorde vóór en na vervanging door concat.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](test/resource_contract_test.rb), [source_uri_test.rb](test/source_uri_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Bestaande interfaces voor integratiewaarden gebruiken

**Norm**

Gebruik de bestaande interface om gegevens van een andere bouwsteen te verkrijgen. Een resource, alias, servicetitel of geaccepteerde API kan bijvoorbeeld het pad, de poort of de unitnaam leveren. Bouw die waarden niet zelfstandig opnieuw op; valideer de afspraak tussen beide onderdelen. Als een interface-uitbreiding is afgewezen, werk dan met de geaccepteerde interface of stabiele externe runtimemetadata, zonder alsnog ongedocumenteerde gemaksparameters toe te voegen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Paden, poorten, unitnamen en andere gegevens tussen lokale bouwstenen.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Resources en afhankelijkheden](#resources-en-afhankelijkheden).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een afgewezen interface-uitbreiding mag niet via ongedocumenteerde gemaksparameters alsnog worden toegevoegd.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een afgewezen interface-uitbreiding mag niet via ongedocumenteerde gemaksparameters alsnog worden toegevoegd.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een afnemer bouwt een servicetitel opnieuw op met ongedocumenteerde naamregels. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Lees de waarde via de geaccepteerde resource, alias, servicetitel of API. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een afgewezen interface-uitbreiding mag niet via ongedocumenteerde gemaksparameters alsnog worden toegevoegd.

**Handmatige review**

Vergelijk de contractafspraak tussen beide onderdelen en gebruik na een afgewezen uitbreiding uitsluitend de geaccepteerde route of stabiele externe runtimemetadata.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Vergelijk de contractafspraak tussen beide onderdelen en gebruik na een afgewezen uitbreiding uitsluitend de geaccepteerde route of stabiele externe runtimemetadata. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Dependencies pas na een geslaagde controle koppelen

**Norm**

`defined(...)` ziet alleen wat tijdens evaluatie al bekend is. Koppel een `require` daarom pas na een geslaagde controle aan een geaccepteerde resource of gedocumenteerd anker. Wordt de afhankelijkheid via wrappers geleverd, controleer dan eerst de directe resource, vervolgens de wrapper en daarna de parentwrapper. De eindcatalogus kan andere resources bevatten dan op dat eerdere evaluatiemoment zichtbaar waren.

**Herkomst**

Projectregel

**Toepassingsgebied**

Voorwaardelijke require-relaties met directe resources, wrappers en parentwrappers.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Resources en afhankelijkheden](#resources-en-afhankelijkheden).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een gedocumenteerd anker blijft toegestaan; een later gevulde eindcatalogus is geen bewijs voor vroegere defined-uitkomsten.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een gedocumenteerd anker blijft toegestaan; een later gevulde eindcatalogus is geen bewijs voor vroegere defined-uitkomsten.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een require wordt gekoppeld op basis van een pas later zichtbare wrapper. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Controleer eerst directe resource, dan wrapper en parentwrapper; koppel na succes aan een geaccepteerde resource of anker. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een gedocumenteerd anker blijft toegestaan; een later gevulde eindcatalogus is geen bewijs voor vroegere defined-uitkomsten.

**Handmatige review**

Traceer zichtbaarheid op het evaluatiemoment en onderscheid die van de uiteindelijke catalogus.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Traceer zichtbaarheid op het evaluatiemoment en onderscheid die van de uiteindelijke catalogus. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Prerequisites van ordering onderscheiden

**Norm**

Maak bij dependencies onderscheid tussen wat een operatie nodig heeft om te kunnen draaien en wat alleen de uitvoervolgorde bepaalt. Het weglaten van `require` schakelt de operatie niet uit. Controleer volgens de [prerequisitereview](../../AGENTS.md#prerequisite-review) wat er gebeurt met de prerequisite aanwezig en afwezig, inclusief de relevante declaratie- en evaluatievolgorde.

**Herkomst**

Projectregel

**Toepassingsgebied**

Operaties met vereiste of optionele runtimeprerequisites en resource-ordering.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Resources en afhankelijkheden](#resources-en-afhankelijkheden).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een weggelaten relatie schakelt niets uit; een declaratie alleen bewijst geen runtimebeschikbaarheid.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een weggelaten relatie schakelt niets uit; een declaratie alleen bewijst geen runtimebeschikbaarheid.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een operatie zonder beschikbare tool blijft actief omdat alleen require is weggelaten. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Lever de vereiste prerequisite of het gedocumenteerde gedrag voor afwezigheid en beoordeel ordering afzonderlijk. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een weggelaten relatie schakelt niets uit; een declaratie alleen bewijst geen runtimebeschikbaarheid.

**Handmatige review**

Controleer aanwezigheid, afwezigheid, declaratievolgorde en evaluatievolgorde volgens de gekoppelde prerequisitereview.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer aanwezigheid, afwezigheid, declaratievolgorde en evaluatievolgorde volgens de gekoppelde prerequisitereview. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Gedeelde voorwaarden om resources groeperen

**Norm**

Plaats resources die dezelfde voorwaarde delen in één buitenste voorwaarde. Hun eigen controles kunnen daarbinnen staan. Zo blijft zichtbaar welke verwerking volledig afhankelijk is van de beschikbaarheid of instelling die je controleert.

**Herkomst**

Projectregel

**Toepassingsgebied**

Resources met een gezamenlijke beschikbaarheids- of inschakelvoorwaarde.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Resources en afhankelijkheden](#resources-en-afhankelijkheden).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Resources met verschillende voorwaarden mogen die eigen controle behouden; de gedeelde buitenvoorwaarde vervangt haar niet.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Resources met verschillende voorwaarden mogen die eigen controle behouden; de gedeelde buitenvoorwaarde vervangt haar niet.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Dezelfde voorwaarde wordt rond iedere resource herhaald. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Plaats de gezamenlijke voorwaarde buiten de resources en houd hun eigen controles daarbinnen. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Resources met verschillende voorwaarden mogen die eigen controle behouden; de gedeelde buitenvoorwaarde vervangt haar niet.

**Handmatige review**

Volg alle afhankelijke verwerking en behoud iedere aanvullende lokale voorwaarde.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Volg alle afhankelijke verwerking en behoud iedere aanvullende lokale voorwaarde. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Aanroepen en publieke interfaces

<!-- lint-rule-group -->

#### Alle verplichte argumenten doorgeven

**Norm**

Geef bij een class- of defined-type-aanroep alle verplichte parameters mee. Ook een `Optional[...]` zonder default blijft een verplicht argument: het type staat `undef` toe, maar vult geen ontbrekende waarde in.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Class- en defined-type-resourceaanroepen met statisch gevonden declaraties en zonder splat.

**Automatische controle**

`project_interface_calls`

**Detectiegrenzen**

Onvindbare declaraties, dynamische namen, include/contain, splats, Hiera, types, onbekende parameters, overerving en containment worden niet volledig gecontroleerd. Het modulepad bepaalt de vindbare versie.

**Meldingen en severity**

`Public interface call omits required parameters: {namen}`: `warning`; de variabele lijst noemt ontbrekende verplichte parameters.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een parameter met een echte default hoeft niet expliciet mee; Optional zonder default blijft verplicht.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_interface_calls` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_interface_calls warning -->
```puppet
define example::item (String $value) {}
example::item { 'demo': }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_interface_calls` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_interface_calls clean -->
```puppet
define example::item (String $value) {}
example::item { 'demo': value => 'synthetic' }
```

**Grensgevallen**

Een vindbare Optional zonder default blijft vereist; een niet-vindbare declaratie kan geen melding over haar vereiste parameters geven. Een splat voorkomt volledige statische argumentcontrole.

**Handmatige review**

Controleer de gekozen moduleversie, alle vereiste argumenten en de eigen catalogusvalidatie, ook zonder lintmelding.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [interface_contract_test.rb](test/interface_contract_test.rb), [parameter_passthrough_test.rb](test/parameter_passthrough_test.rb), [parameter_filter_defaults_test.rb](test/parameter_filter_defaults_test.rb), [parameter_filter_predicate_test.rb](test/parameter_filter_predicate_test.rb), [parameter_filter_source_test.rb](test/parameter_filter_source_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Alle verplichte argumenten doorgeven

`project_interface_calls` meldt ontbrekende argumenten bij declaraties die de check statisch kan vinden. Binnen deze repository is de eigen moduleverzameling het standaardzoekpad. De [modulepadregels](#aanroepen-van-modules-controleren) beschrijven hoe de declaratie wordt gekozen en welke aanroepen buiten de analyse vallen.

Een geslaagde scan bewijst geen geldige catalogus. Argumenttypen, onbekende parameters, Hiera, overerving, defaults, containment en splats vragen afzonderlijke catalogusvalidatie. Dat geldt ook wanneer de linter een declaratie niet vindt. De check heeft geen autofix; de juiste argumentwaarde volgt uit de interface en het bedoelde gebruik.

#### Overbodige parameterdoorgifte rechtstreeks schrijven

**Norm**

Geef waarden rechtstreeks als benoemde attributen mee wanneer een hash alleen gelijknamige variabelen doorgeeft, zonder verdere verwerking. Schrijf bijvoorbeeld `retention_days => $retention_days` in de resource, in plaats van een hash met die combinatie te maken en die via `* => $settings` uit te pakken.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Hashes bij * => en eerdere eenduidige lokale hashtoekenningen; gefilterde keys bij vindbare ontvangende defined types.

**Automatische controle**

`project_parameter_passthrough`

**Detectiegrenzen**

Onbekende declaraties en splats verhinderen argumentcontrole. Filteranalyse sluit classes met automatische lookup, onbekende bronwaarden/defaults, dynamiek, gekwalificeerde bronvariabelen, resourcedefaults, overrides en overerving uit; alle onderstaande filtervoorwaarden blijven van toepassing.

**Meldingen en severity**

`[review] Pass same-named variables directly as resource attributes`: `warning` bij volledig gelijknamige ongefilterde doorgifte. `[review] Pass this key directly: its source value/default matches the receiving default; review effective values and other hash consumers`: `warning` per overbodig gefilterde key.

**Autofix**

Geen voor beide varianten.

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een filter blijft behouden voor keys waarvoor afwijkende invoer een andere eindwaarde moet krijgen. Gewone configuratiehashes vallen buiten de doorgifteregel; geen default toevoegen enkel om Optional te hersorteren.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_parameter_passthrough`; verwacht warning.

<!-- lint-example: project_parameter_passthrough warning -->
```puppet
example { 'synthetic': * => { 'label' => $label } }
```

**Correct voorbeeld**

Fragment; alleen `project_parameter_passthrough`; verwacht geen melding.

<!-- lint-example: project_parameter_passthrough clean -->
```puppet
example { 'synthetic': label => $label }
```

**Grensgevallen**

Een filter blijft behouden voor keys waarvoor afwijkende invoer een andere eindwaarde moet krijgen. Gewone configuratiehashes vallen buiten de doorgifteregel; geen default toevoegen enkel om Optional te hersorteren. Onbekende declaraties en splats verhinderen argumentcontrole. Filteranalyse sluit classes met automatische lookup, onbekende bronwaarden/defaults, dynamiek, gekwalificeerde bronvariabelen, resourcedefaults, overrides en overerving uit; alle onderstaande filtervoorwaarden blijven van toepassing. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Overbodige parameterdoorgifte rechtstreeks schrijven](#verdieping-bij-overbodige-parameterdoorgifte-rechtstreeks-schrijven).

**Handmatige review**

Vergelijk per key de effectieve bronwaarde en ontvangende default en valideer catalogi vóór rechtstreekse doorgifte. Behoud nuttige filters voor andere keys en controleer alle hashafnemers en hoofdlettergevoelige ontvangende waarden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [interface_contract_test.rb](test/interface_contract_test.rb), [parameter_passthrough_test.rb](test/parameter_passthrough_test.rb), [parameter_filter_defaults_test.rb](test/parameter_filter_defaults_test.rb), [parameter_filter_predicate_test.rb](test/parameter_filter_predicate_test.rb), [parameter_filter_source_test.rb](test/parameter_filter_source_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Overbodige parameterdoorgifte rechtstreeks schrijven

Geef waarden rechtstreeks als benoemde attributen mee wanneer een hash alleen gelijknamige variabelen doorgeeft, zonder verdere verwerking. Schrijf bijvoorbeeld `retention_days => $retention_days` in de resource, in plaats van een hash met die combinatie te maken en die via `* => $settings` uit te pakken.

Beoordeel een filter per hashkey. Zoek de bronwaarde of parameterdefault op en vergelijk die met de default van de ontvangende parameter. Geef die key rechtstreeks door wanneer het filter voor die key niets verandert aan de ontvangen waarde. Behoud het filter voor andere keys waarvoor het wel betekenis heeft. Gelijke parameternamen of gelijke parameterdefaults aan beide kanten zijn op zichzelf geen bewijs: een default kan worden overschreven en het filter kan die afwijkende invoer bewust uitsluiten. Dit geldt voor tekst, getallen, booleans, `undef`, arrays en hashes.

Bij een vaste lokale toekenning `$bron = 2` en ontvangende default `2` leveren zowel `$value != 2` als `$value == 2` dezelfde eindwaarde als rechtstreekse doorgifte. Heeft de bronparameter alleen default `2`, dan blijft afwijkende invoer mogelijk. `$value != 2` laat die afwijkende invoer door; `$value == 2` sluit haar juist uit. Ook `$value != 0` kan dan nuttig zijn: invoer `0` leidt door het filter tot de ontvangende default `2`.

`project_parameter_passthrough` meldt eenvoudige, ongefilterde doorgifte wanneer alle hashkeys overeenkomen met rechtstreeks gebruikte variabelenamen. Bij een filter controleert hij iedere key afzonderlijk. Hij volgt de bronvariabele via eerdere, eenduidige lokale toekenningen en verwijzingen naar andere variabelen, of leest de parameterdefault van de omringende class of het defined type. Vervolgens vergelijkt hij die waarde met de default van de parameter die de hashkey aanwijst. De namen van bronvariabele en ontvangende parameter mogen verschillen. Een melding staat op de betreffende hashkey; een nuttig filter voor een andere key houdt die melding niet tegen.

De filteranalyse herkent `.filter` met twee ongetypeerde lambdaparameters zonder defaults en uitsluitend `$value != <letterlijke waarde>` of `$value == <letterlijke waarde>`, ook met omgekeerde operanden of haakjes. Bij gelijke vaste bron- en doelwaarden zijn beide vergelijkingen overbodig voor die key. Bij gelijke parameterdefaults meldt de check alleen `!=` met diezelfde default, zodat filters voor afwijkende invoer behouden blijven. Tekst, getallen, booleans, `undef` en letterlijke arrays en hashes worden exact vergeleken, inclusief hun typen. Bij meerdere filters moet elke voorwaarde aan deze criteria voldoen; een aanvullende voorwaarde wordt niet genegeerd.

De check herkent een hash bij `* =>` en een eerdere, eenduidige hashtoekenning binnen dezelfde scope. Hij zoekt de bron in die scope en het ontvangende defined type in de huidige bron of via het [modulepad](#aanroepen-van-modules-controleren). Onbekende bronwaarden, ontvangers of defaults krijgen geen filtermelding. Verplichte parameters zonder default, dynamische berekeningen, gekwalificeerde bronvariabelen en niet-eenduidige toekenningen blijven buiten de analyse; Puppet-functies en Hiera worden niet uitgevoerd. Ontvangende classes blijven buiten de filteranalyse vanwege automatische parameterlookup. Zichtbare resourcedefaults, resource-overrides en overerving vereisen ook handmatige review. Gewone configuratiehashes vallen buiten deze regel.

Er is geen autofix. Controleer de effectieve waarden en evaluatievolgorde met catalogusvalidatie voordat je een gemelde key rechtstreeks doorgeeft. Beoordeel ook andere afnemers van dezelfde hash voordat je die key eruit verwijdert. Houd rekening met configuratie buiten het geanalyseerde bestand en met Puppet-vergelijkingen: een tekstvergelijking kan ook andere hoofdletters accepteren, terwijl die schrijfwijze voor de ontvanger verschil maakt.

#### Resource references

<!-- lint-rule-group -->

#### References van hetzelfde type samenvoegen

**Norm**

Schrijf references van hetzelfde resourcetype binnen één array als één reference met meerdere titels, ook wanneer er references van andere typen tussen staan. Sorteer de titels alfabetisch en zet de samengevoegde reference op de plaats van de eerste reference van dat type. Dit geldt ook voor classes en eigen defined types. Beoordeel buiten dependency-attributen en losse relatieketens eerst de gevolgen voor de arraystructuur, zoals hieronder beschreven.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

References van hetzelfde type in arrays en titellijsten; dependency-attributen en losse relatieketens voor veilige correctie.

**Automatische controle**

`project_resource_references`

**Detectiegrenzen**

Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend.

**Meldingen en severity**

`Merge references of the same resource type within the array and sort their titles alphabetically`: `warning` bij herhaalde references van hetzelfde type. Bij een resulterende enkele dependency-reference kan `; remove the outer array around the resulting single reference` volgen. Onveilige correcties krijgen ` [review] Verify relationship context, array shape, title order and comments before changing this expression`; severity blijft warning.

**Autofix**

Voorwaardelijk voor de samenvoegvariant; Geen voor de variant met [review].

**Autofixvoorwaarden**

Alle relatie-, titel-, tussenliggende-element-, commentaar-, heredoc- en concatvoorwaarden hieronder gelden per variant. De fix behoudt dubbele titels, typegrenzen, tussenliggende references en de eerste positie van het samengevoegde type.

**Toegestane uitzonderingen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_resource_references` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_resource_references warning -->
```puppet
notify { 'demo': require => [Package['zulu'], Package['alpha']] }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_resource_references` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_resource_references clean -->
```puppet
notify { 'demo': require => Package['alpha', 'zulu'] }
```

**Grensgevallen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn. Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij References van hetzelfde type samenvoegen](#verdieping-bij-references-van-hetzelfde-type-samenvoegen).

**Handmatige review**

Vergelijk per arraylaag elementvorm, titelvolgorde en comments. Beoordeel of het relatieresultaat wordt gebruikt en of het eerste concatargument aantoonbaar een array is.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [reference_merging_test.rb](test/reference_merging_test.rb), [reference_safety_test.rb](test/reference_safety_test.rb), [reference_wrappers_test.rb](test/reference_wrappers_test.rb), [reference_concat_test.rb](test/reference_concat_test.rb), [cross_check_autofix_test.rb](test/cross_check_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij References van hetzelfde type samenvoegen

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_resource_references` gecontroleerd.

<!-- lint-example: project_resource_references clean -->
```puppet
# Both packages are prerequisites for this notification.
notify { 'packages-ready':
  require => Package['alpha', 'zulu'],
}
```

Hier zou `require => [Package['zulu'], Package['alpha']]` dezelfde dependencies beschrijven, maar met onnodige herhaling. Ook een buitenste array zoals `[Package['alpha', 'zulu']]` is op deze plaats overbodig.

Zo wordt `require => [Package['zulu'], Service['nginx'], Package['alpha']]` geschreven als `require => [Package['alpha', 'zulu'], Service['nginx']]`. De service blijft als eigen reference aanwezig. Andere array-elementen onderbreken de controle op herhaalde resourcetypen niet. Voeg geen references uit afzonderlijke functieargumenten, verschillende arraylagen of kanten van een relatiepijl samen. Iedere geneste array wordt afzonderlijk gecontroleerd. Alleen de buitenste array rond één dependency-reference kan weg; meerdere elementen en geneste arraylagen blijven behouden.

`project_resource_references` meldt afzonderlijke references van hetzelfde type binnen een array, ongesorteerde letterlijke titels en overbodige buitenste arrays. Letterlijke titels worden hoofdlettergevoelig vergeleken op hun stringwaarde, zonder de aanhalingstekens mee te tellen. Dubbele titels blijven behouden. Datatypeparameters zoals `Enum[...]`, lokale typealiases en gewone indexeringen vallen buiten deze regel.

Autofix kan dit herstellen bij `require`, `before`, `notify` en `subscribe`, en bij losse relatieketens met `->`, `~>`, `<-` of `<~`. In die context beschrijven de references relaties tussen resources. Bij andere toepassingen kan dezelfde herschrijving de betekenis veranderen: een [reference met meerdere titels levert een array op](https://help.puppet.com/core/current/Content/PuppetCore/lang_data_resource_reference.htm), waardoor `[Package['a', 'b']]` een geneste array bevat en `[Package['a'], Package['b']]` niet. Bij variabelen, functieargumenten, indexeringen en een gebruikt resultaat van een relatie-expressie beoordeel je de gevolgen zelf.

Samenvoegen en sorteren gebeurt alleen automatisch bij letterlijke titels zonder commentaar in het te wijzigen gedeelte of bij een te verwijderen reference. Staan er andere elementen tussen de samen te voegen references, dan moeten ook die references met letterlijke titels zijn. Bij bijvoorbeeld een tussenliggende variabele, functieaanroep of geneste array volgt wel een melding, maar beoordeel je de samenvoeging zelf. Dat geldt ook voor dynamische titels en commentaar: behoud de toelichting bij de juiste resource en beoordeel welke waarden de expressies kunnen krijgen. De linter rekent die waarden niet uit.

Een buitenste array rond één reference kan ook bij een dynamische titel worden verwijderd: `require => [Package[$packages]]` wordt `require => Package[$packages]`. De reference zelf verandert dan niet. Bevat de te wijzigen array commentaar, een heredoc of genegeerde code, dan weigert de autofix ook deze correctie.

Deze relatiecontext omvat ook `concat(...)` dat rechtstreeks een dependency-attribuut of losse relatieketen voedt. Bij het eerste argument verdwijnt een wrapper alleen als de reference aantoonbaar een array oplevert: meerdere titels, een arrayliteral, een eerder voorbereide array of een parameter met type `Array`. Zo wordt `concat([Package[$packages]], $other)` veilig vereenvoudigd als `$packages` een bekende array is. Rond een enkele scalaire of onopgeloste titel blijft de eerste wrapper staan, omdat stdlib `concat()` daar een array vereist. Bij latere argumenten accepteert `concat()` ook een scalaire reference. Gewone functieargumenten en opgeslagen concatresultaten behouden hun arraystructuur.

#### Titels in resource references sorteren

**Norm**

Sorteer de titels van resource references alfabetisch. Vergelijk letterlijke titels hoofdlettergevoelig op hun stringwaarde, zonder de quotes mee te tellen; behoud dubbele titels.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

References van hetzelfde type in arrays en titellijsten; dependency-attributen en losse relatieketens voor veilige correctie.

**Automatische controle**

`project_resource_references`

**Detectiegrenzen**

Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend.

**Meldingen en severity**

`Sort resource reference titles alphabetically`: `warning` bij ongesorteerde letterlijke titels. Het wrapper- en [review]-suffix uit de [samenvoegregel](#references-van-hetzelfde-type-samenvoegen) kan worden toegevoegd.

**Autofix**

Voorwaardelijk voor sorteren in veilige relatiecontext; Geen voor de variant met [review].

**Autofixvoorwaarden**

Alle relatie-, titel-, tussenliggende-element-, commentaar-, heredoc- en concatvoorwaarden hieronder gelden per variant. De fix behoudt dubbele titels, typegrenzen, tussenliggende references en de eerste positie van het samengevoegde type.

**Toegestane uitzonderingen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_resource_references`; verwacht warning.

<!-- lint-example: project_resource_references warning -->
```puppet
notify { 'example': require => Package['zulu', 'alpha'] }
```

**Correct voorbeeld**

Fragment; alleen `project_resource_references`; verwacht geen melding.

<!-- lint-example: project_resource_references clean -->
```puppet
notify { 'example': require => Package['alpha', 'zulu'] }
```

**Grensgevallen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn. Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij References van hetzelfde type samenvoegen](#verdieping-bij-references-van-hetzelfde-type-samenvoegen).

**Handmatige review**

Controleer de effectieve titelwaarden, hoofdlettergevoelige volgorde, behouden dubbelen en betekenis van de arrayvorm. Pas de gemeenschappelijke fixvoorwaarden bij de samenvoegregel toe.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [reference_merging_test.rb](test/reference_merging_test.rb), [reference_safety_test.rb](test/reference_safety_test.rb), [reference_wrappers_test.rb](test/reference_wrappers_test.rb), [reference_concat_test.rb](test/reference_concat_test.rb), [cross_check_autofix_test.rb](test/cross_check_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Een overbodige buitenste dependency-array verwijderen

**Norm**

Bij een dependency-attribuut of een losse relatieketen laat je de buitenste array weg wanneer daarin nog maar één resource reference staat. Behoud meerdere elementen en geneste arraylagen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

References van hetzelfde type in arrays en titellijsten; dependency-attributen en losse relatieketens voor veilige correctie.

**Automatische controle**

`project_resource_references`

**Detectiegrenzen**

Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend.

**Meldingen en severity**

`Remove the outer array around a single resource reference`: `warning` bij een overbodige buitenste array. Onzekere context krijgt het [review]-suffix uit de [samenvoegregel](#references-van-hetzelfde-type-samenvoegen).

**Autofix**

Voorwaardelijk voor een veilige buitenste dependency-array; Geen voor de variant met [review].

**Autofixvoorwaarden**

Verwijdert alleen de wrapper en behoudt de reference. Een dynamische titel is daarvoor toegestaan. Commentaar, heredocs en genegeerde code weigeren de correctie. Binnen rechtstreeks voedende dependency-concat blijft de eerste wrapper bestaan tenzij de reference aantoonbaar een array oplevert; latere concatargumenten mogen scalair zijn. De volledige contextcriteria staan bij [References samenvoegen](#references-van-hetzelfde-type-samenvoegen).

**Toegestane uitzonderingen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_resource_references`; verwacht warning.

<!-- lint-example: project_resource_references warning -->
```puppet
notify { 'example': require => [Package['alpha']] }
```

**Correct voorbeeld**

Fragment; alleen `project_resource_references`; verwacht geen melding.

<!-- lint-example: project_resource_references clean -->
```puppet
notify { 'example': require => Package['alpha'] }
```

**Grensgevallen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn. Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij References van hetzelfde type samenvoegen](#verdieping-bij-references-van-hetzelfde-type-samenvoegen).

**Handmatige review**

Controleer gewone waarden, functieargumenten, opgeslagen concatresultaten, geneste arrays en gebruikte relatieresultaten apart. Bewijs voor het eerste concatargument dat het een array oplevert; verander de reference zelf niet.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [reference_merging_test.rb](test/reference_merging_test.rb), [reference_safety_test.rb](test/reference_safety_test.rb), [reference_wrappers_test.rb](test/reference_wrappers_test.rb), [reference_concat_test.rb](test/reference_concat_test.rb), [cross_check_autofix_test.rb](test/cross_check_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Resourcelijsten hergebruiken

**Norm**

Definieer een lijst met resourcetitels eenmaal wanneer declaraties of dependencies dezelfde set gebruiken. Dit geldt voor packages, bestanden, services, classes en eigen defined types. Gebruik bijvoorbeeld dezelfde `$configuration_files` in `file { $configuration_files: ... }` en `File[$configuration_files]`. Kies een naam die bij het doel past; de check schrijft geen variabelenaam voor.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Resourcedeclaraties, references en ensure_packages met minstens twee verschillende letterlijke titels van hetzelfde type binnen dezelfde class, define of topscope.

**Automatische controle**

`project_resource_list_reuse`

**Detectiegrenzen**

Gelijke sets, volledige uitbreidingen en overlap vanaf drie namen en 80% aan beide kanten worden onderscheiden. Onbekende expressies, parameterdefaults, andere functies en lambdascopes blijven buiten vergelijking.

**Meldingen en severity**

`Reuse the resource-title list in a shared variable; extend it with concat() for additional dependencies`: `warning`. Zonder veilige fix volgt ` [review] Verify overlap, scope, evaluation order and comments before extracting the list`; severity blijft warning.

**Autofix**

Voorwaardelijk voor exacte herhaling en duidelijke package-uitbreidingen; Geen voor de beschreven reviewgevallen

**Autofixvoorwaarden**

Uitsluitend één rechtstreeks gebruikte ensure_packages-lijst met dependencies na de aanroep in hetzelfde blok. Alle hieronder beschreven titel-, naam-, scope-, breedte-, commentaar- en uitbreidingsvoorwaarden zijn vereist.

**Toegestane uitzonderingen**

Kleine overlap, verschillende declaratiesets en kleinere dependency-subsets zijn geen reden om lijsten samen te voegen. Behoud aanvullende titels en hun bestaande eigenaar.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_resource_list_reuse` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_resource_list_reuse warning -->
```puppet
file { ['/a', '/b']: }
notify { 'demo': require => File['/a', '/b'] }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_resource_list_reuse` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_resource_list_reuse clean -->
```puppet
$paths = ['/a', '/b']
file { $paths: }
notify { 'demo': require => File[$paths] }
```

**Grensgevallen**

Kleine overlap, verschillende declaratiesets en kleinere dependency-subsets zijn geen reden om lijsten samen te voegen. Behoud aanvullende titels en hun bestaande eigenaar. Gelijke sets, volledige uitbreidingen en overlap vanaf drie namen en 80% aan beide kanten worden onderscheiden. Onbekende expressies, parameterdefaults, andere functies en lambdascopes blijven buiten vergelijking. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Resourcelijsten hergebruiken](#verdieping-bij-resourcelijsten-hergebruiken).

**Handmatige review**

Controleer dat gedeelde variabelen vóór alle afnemers bestaan, verschillen behouden blijven en resources met eigen attributen/levenscyclus niet worden gecombineerd.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_list_reuse_test.rb](test/resource_list_reuse_test.rb), [resource_list_reuse_fix_test.rb](test/resource_list_reuse_fix_test.rb), [package_list_extensions_test.rb](test/package_list_extensions_test.rb), [package_list_scope_test.rb](test/package_list_scope_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Resourcelijsten hergebruiken

Bij packages deel je de lijst ook tussen `ensure_packages()` en `Package[...]`, zodat een toevoeging of verwijdering niet op meerdere plaatsen hoeft te worden bijgehouden:

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_resource_list_reuse` gecontroleerd.

<!-- lint-example: project_resource_list_reuse clean -->
```puppet
# Install the tools shared by this feature's consumers.
$feature_packages = ['coreutils', 'grep', 'sed']

ensure_packages($feature_packages, {
  'ensure'          => 'installed',
  'install_options' => ['--no-install-recommends', '--no-install-suggests'],
})

# Include an additional package managed by the consuming deployment.
$feature_required_packages = concat(
  $feature_packages,
  ['curl'],
)

# Order the consumer after its package prerequisites.
notify { 'feature-ready':
  require => Package[$feature_required_packages],
}
```

Aanvullende dependencies blijven behouden in een afzonderlijk voorbereide lijst. Die uitbreiding declareert de extra resources niet: hun bestaande eigenaar blijft daarvoor verantwoordelijk. De [arrayconventie](#resources-en-afhankelijkheden) schrijft `concat(...)` voor; deze hergebruikcheck herkent ook hergebruik via `+`, maar schakelt de aparte melding van `project_arrays` niet uit. De [opbouw van dependencies](#resource-dependencies-opbouwen) houdt titels gescheiden van resource references.

`project_resource_list_reuse` vergelijkt binnen dezelfde class, hetzelfde defined type of dezelfde topscope bronnen met ten minste twee verschillende letterlijke titels van hetzelfde resourcetype. Een andere schrijfvolgorde maakt geen verschil. Identieke sets worden ook gemeld bij herhaalde declaraties, herhaalde references of meerdere `ensure_packages()`-aanroepen. Gelijke titels van verschillende resourcetypen worden niet gekoppeld. Datatypeparameters, lokale typealiases en gewone indexeringen vallen buiten de regel. Samenhangende herhalingen krijgen één melding bij de eerste bronlijst.

Tussen een declaratielijst of `ensure_packages()` en een afzonderlijke reference meldt de check ook een volledig herhaalde basisset met extra titels. Bij overige overlap is een melding beperkt tot minstens drie gemeenschappelijke titels die ten minste 80% van beide sets vormen. Zo'n melding vraagt altijd review: behoud de bedoelde verschillen en deel alleen de gemeenschappelijke basis. Enkele gemeenschappelijke titels, kleinere dependency-subsets en verschillende declaratiesets zijn geen reden om lijsten samen te voegen.

De analyse volgt eerdere, eenduidige lokale toekenningen, aliassen, `concat(...)`, arrayoptelling en letterlijke lijsten in selectors en `if`-expressies. Verwijzingen naar dezelfde bronlijst tellen als hergebruik. Statisch zichtbare namen naast dynamische waarden kunnen een reviewmelding opleveren; onbekende expressies worden niet uitgevoerd. Parameterdefaults, onopgeloste variabelen, andere functieaanroepen en afzonderlijke lambdascopes blijven buiten deze vergelijking. Bij references in gewone waarden en relatieketens volgt alleen een melding: de autofix beperkt zich tot `require`, `before`, `notify` en `subscribe` op resources.

De hergebruik-autofix beperkt zich tot één rechtstreeks aangeroepen, letterlijke `ensure_packages()`-lijst met passende package-dependencies in hetzelfde uitvoerblok, na de installatieaanroep. Er mag geen tweede installatielijst in die scope zijn. De namen moeten uniek zijn en bestaan uit letters, cijfers, `+`, `_`, `.`, `:` of `-`, beginnend met een letter of cijfer. Bij exacte herhaling zet de fix de lijst direct vóór de aanroep in `$required_packages` en vervangt alle passende references; `concat()` is dan niet nodig. Bij declaraties of alleen references beoordeel je de extractie handmatig, met behoud van hun eigen attributen en levenscyclus.

Een duidelijke uitbreiding mag eveneens worden gecorrigeerd: de installatie gebruikt dan `$packages` en na de aanroep volgt `$required_packages = concat($packages, ['extra'])`, verdeeld over meerdere regels. Iedere dependency bevat de volledige basislijst; er mag maximaal één verschillende uitbreidingsset zijn. Resources die alleen de basis nodig hebben gebruiken `$packages`. Overige resources en dependencyvariabelen blijven buiten `Package[...]`. Naamconflicten, ook met gekwalificeerde variabelen of parameters, verhinderen autofix; kies bij handmatige correctie contextnamen.

Bestaande lijstvariabelen met opnieuw uitgeschreven literals, gedeeltelijke overlap, meerdere verschillende uitbreidingen, conditionele waarden, gebruikte functieresultaten, overerving en complexe expressies krijgen geen hergebruik-autofix. Dat geldt ook voor commentaar in de te vervangen lijsten, lintmarkeringen binnen het wijzigingsbereik, een installatielijst over meerdere regels of een nieuwe declaratie langer dan 140 tekens. Commentaar buiten de lijsten blijft behouden; ontbreekt een toelichting boven de installatie, dan voegt de fix een feitelijke toelichting bij de gedeelde variabele toe. Bij twijfel blijft de hele groep staan met `[review]`.

Controleer bij handmatig hergebruik dat de variabele vóór alle afnemers beschikbaar is en dat voorwaarden, resourceattributen en relaties behouden blijven. Een melding bewijst geen beschikbaarheid van resources; volg daarvoor de [dependencyreview](#resources-en-afhankelijkheden) en bij monitoring de [packagegaranties](#packages-voor-externe-commandos).

#### Resource-dependencies opbouwen

**Norm**

Combineer eerst titels van hetzelfde resourcetype, maak daarna de resource reference en combineer die pas vervolgens met andere dependencies. Dit geldt ook voor `File[...]`, `Service[...]`, `Class[...]` en eigen defined types. Gebruik voor een uitbreiding een benoemde tussenvariabele, zodat de drie stappen afzonderlijk leesbaar blijven. Bij packages ziet dat er zo uit:

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Concat-aanroepen binnen references van packages, files, services, classes en eigen defined types, inclusief buitenste dependency-concats.

**Automatische controle**

`project_resource_dependencies`

**Detectiegrenzen**

Onbekende variabelen, parameterdefaults, conditionele waarden en references tussen titels krijgen geen extractiefix. Gewone concats en vooraf berekende titelvariabelen zijn toegestaan.

**Meldingen en severity**

`Prepare the extended title list in a variable before the resource reference; combine other dependencies separately`: `warning`. Onveilige gevallen krijgen ` [review] Verify variable contents, conditions, scope and comments before extracting the list`.

**Autofix**

Voorwaardelijk; Geen voor de genoemde reviewvarianten

**Autofixvoorwaarden**

Titels zijn aantoonbaar vaste strings via literals, eerdere eenduidige toekenningen of concat. Geen naamconflict, commentaar, lintmarkering, meerregelig argument of uitvoer buiten 140 tekens. Identieke expressies in hetzelfde blok delen voorbereiding.

**Toegestane uitzonderingen**

Bij gelijke titels volstaat één bestaande lijst; voeg geen concat toe zonder uitbreiding.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_resource_dependencies` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_resource_dependencies warning -->
```puppet
notify { 'demo': require => File[concat(['/a'], ['/b'])] }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_resource_dependencies` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_resource_dependencies clean -->
```puppet
$paths = concat(['/a'], ['/b'])
notify { 'demo': require => File[$paths] }
```

**Grensgevallen**

Bij gelijke titels volstaat één bestaande lijst; voeg geen concat toe zonder uitbreiding. Onbekende variabelen, parameterdefaults, conditionele waarden en references tussen titels krijgen geen extractiefix. Gewone concats en vooraf berekende titelvariabelen zijn toegestaan. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Resource-dependencies opbouwen](#verdieping-bij-resource-dependencies-opbouwen).

**Handmatige review**

Controleer dat titelvariabelen alleen titels bevatten, andere dependencies references blijven en extractie geen voorwaarde of evaluatiegrens passeert.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_dependencies_test.rb](test/resource_dependencies_test.rb), [cli_resource_list_reuse_test.rb](test/cli_resource_list_reuse_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Resource-dependencies opbouwen

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_resource_dependencies` gecontroleerd.

<!-- lint-example: project_resource_dependencies clean -->
```puppet
# Include the application package alongside the prepared backup tools.
$backup_required_packages = concat(
  $backup_packages,
  ['backup-server'],
)

# Combine package references with the separately prepared resource dependencies.
notify { 'backup-ready':
  require => concat(
    Package[$backup_required_packages],
    $backup_other_require,
  ),
}
```

`$backup_packages` bevat hier package-namen; `$backup_other_require` bevat andere resource references. Geef die laatste variabele nooit door als resourcetitel. Bij exact dezelfde packages volstaat `Package[$backup_packages]`; voeg geen `concat()` toe als er niets samen te voegen is. De [referencecheck](#resource-references) verwijdert aantoonbaar overbodige wrappers in dependency-concats, met behoud van de vereiste array als eerste argument.

`project_resource_dependencies` meldt `concat(...)` binnen resource references, zoals `Package[concat(...)]` of `File[concat(...)]`, ook binnen een buitenste dependency-concat. De check kan de binnenste expressie vóór de omringende resource of toekenning in een tussenvariabele plaatsen. Hij behoudt de volgorde van de concatargumenten en laat andere references op hun plaats. De naam volgt een bestaande lokale naam: `$backup_packages` levert `$backup_required_packages` op en `$configuration_files` levert `$configuration_required_files` op. Zonder bronvariabele gebruikt de fix `$required_titles`. Identieke expressies in hetzelfde blok delen die voorbereiding.

Deze autofix vereist aantoonbaar vaste titels als strings via literals, eerdere eenduidige lokale toekenningen of `concat()`. Onbekende variabelen, parameterdefaults, conditionele waarden, resource references tussen de titels, naamconflicten, commentaar of lintmarkeringen in het wijzigingsbereik krijgen uitsluitend een reviewmelding. De fix verplaatst geen onzekere expressie buiten haar voorwaarde. Meerregelige argumenten en uitvoer buiten de regelbreedte worden eveneens handmatig beoordeeld. Reeds voorbereide titelvariabelen en gewone `concat()`-aanroepen blijven toegestaan.

#### Volgorde en meldingen

<!-- lint-rule-group -->

#### Resources bij hun voorziening plaatsen

**Norm**

Groepeer resources en aanroepen van defined types bij het onderdeel dat ze beheren. Sluit nieuwe aanroepen aan op de bestaande indeling van het manifest. Aanvullende voorzieningen, zoals back-ups, monitoring en audit, volgen bij elkaar na de configuratie en service waarop ze betrekking hebben, binnen het geldige uitvoerpad en met behoud van hun eigen inschakelvoorwaarden.

Gedeelde voorbereiding en vereiste classes mogen eerder staan wanneer afnemers die nodig hebben. Een vroeg berekende instelvariabele is op zichzelf geen reden om ook de bijbehorende resourcedeclaratie naar het begin te halen. Vereist de evaluatievolgorde een andere plaats voor een gerelateerde aanroep, licht dan bij die aanroep de concrete afhankelijkheid toe en valideer die volgorde.

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe en verplaatste resources en defined-type-aanroepen binnen hun geldige uitvoerpad.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Gedeelde voorbereiding en vereiste classes mogen eerder staan. Een andere plaats voor een gerelateerde aanroep vereist de lokale technische toelichting en validatie uit de norm.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Gedeelde voorbereiding en vereiste classes mogen eerder staan. Een andere plaats voor een gerelateerde aanroep vereist de lokale technische toelichting en validatie uit de norm.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een monitoringregistratie staat vóór de serviceconfiguratie omdat haar instelvariabele vroeg wordt berekend. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Plaats de registratie bij de aanvullende voorzieningen na de configuratie en service; behoud haar inschakelvoorwaarde. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Gedeelde voorbereiding en vereiste classes mogen eerder staan. Een andere plaats voor een gerelateerde aanroep vereist de lokale technische toelichting en validatie uit de norm.

**Handmatige review**

Vergelijk iedere toegevoegde of verplaatste aanroep met de hele omringende implementatie en controleer de concrete evaluatieafhankelijkheid.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk iedere toegevoegde of verplaatste aanroep met de hele omringende implementatie en controleer de concrete evaluatieafhankelijkheid. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Relaties en meldingen behouden

**Norm**

Behoud de expliciete `require`-, `notify`- en `subscribe`-relaties tussen resources. Ontstaat een afhankelijkheidscyclus, zoek dan welke relatie of containment die veroorzaakt. Herstel de relatie daar, zodat Puppet de volgorde en herstarts kan blijven regelen. Een los `systemctl`-, `service`- of reloadcommando omzeilt die samenhang en is geen vervanging.

Soms is de afhankelijkheid van een volledige class te breed. Koppel de ordering dan waar nodig aan een kleinere, stabiele resource en behoud meldingen zoals `notify => Service['nginx']`.

**Herkomst**

Projectregel

**Toepassingsgebied**

Ordering, notificaties en containment bij afhankelijkheidscycli en te brede classrelaties.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een kleinere stabiele resource mag de te brede classordering vervangen; de noodzakelijke notify blijft behouden.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een kleinere stabiele resource mag de te brede classordering vervangen; de noodzakelijke notify blijft behouden.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een cyclus wordt omzeild met een los reloadcommando en de notify-relatie verdwijnt. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Herstel de veroorzakende relatie of containment; behoud de service-notificatie, zo nodig met een kleinere stabiele orderingresource. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een kleinere stabiele resource mag de te brede classordering vervangen; de noodzakelijke notify blijft behouden.

**Handmatige review**

Volg de cyclus door require, notify, subscribe en containment; controleer welke wijzigingen daadwerkelijk een herstart melden.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Volg de cyclus door require, notify, subscribe en containment; controleer welke wijzigingen daadwerkelijk een herstart melden. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Instellingen bij hun eigenaar houden

**Norm**

Houd instellingen die alleen voor een aanvullende voorziening nodig zijn bij die voorziening. Een bestand dat de daemon zelf configureert blijft bij de daemonconfiguratie staan.

Beoordeel deze indeling bij de review van het hele omliggende blok. De [sectiechecks](#toelichtingen-bij-code) controleren opmaak en toelichtingen; een geslaagde lintscan bewijst niet dat aanroepen inhoudelijk op de juiste plek staan. Verplaats ze niet automatisch op basis van hun naam, type of afstand tot een variabele: hun functie, voorwaarden en evaluatievolgorde bepalen welke plek klopt.

**Herkomst**

Projectregel

**Toepassingsgebied**

Daemonconfiguratie en instellingen van aanvullende voorzieningen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Namen, resourcetype en afstand tot een variabele bewijzen geen juiste plaats. De sectiechecks beoordelen alleen opmaak en toelichting.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Namen, resourcetype en afstand tot een variabele bewijzen geen juiste plaats. De sectiechecks beoordelen alleen opmaak en toelichting.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een daemonconfiguratiebestand verhuist naar de monitoringsectie alleen omdat monitoring het leest. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Laat daemonconfiguratie bij de daemon; groepeer uitsluitend monitoringinstellingen bij de registratie. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Namen, resourcetype en afstand tot een variabele bewijzen geen juiste plaats. De sectiechecks beoordelen alleen opmaak en toelichting.

**Handmatige review**

Stel per instelling vast welk onderdeel zij configureert; beoordeel functie, voorwaarden en evaluatievolgorde in het complete blok.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Stel per instelling vast welk onderdeel zij configureert; beoordeel functie, voorwaarden en evaluatievolgorde in het complete blok. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

### Commentaar en documentatie

<!-- lint-rule-group -->

#### Toelichtingen bij code

<!-- lint-rule-group -->

#### Toelichtingsblokken van eerdere code scheiden

**Norm**

Een zelfstandig toelichtingsblok begint na een lege regel wanneer er code aan voorafgaat. Aaneengesloten commentaarregels vormen samen één blok; commentaar achter code en lintmarkeringen vormen geen nieuwe toelichting. Direct na `{`, `[` of `(` is geen lege regel vóór het commentaar nodig.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Een zelfstandig toelichtingsblok begint na een lege regel wanneer er code aan voorafgaat. Aaneengesloten commentaarregels vormen samen één blok; commentaar achter code en lintmarkeringen vormen geen nieuwe toelichting. Direct na `{`, `[` of `(` is geen lege regel vóór het commentaar nodig.

**Automatische controle**

`project_comment_spacing`

**Detectiegrenzen**

Direct na {, [ of ( hoeft geen lege regel vóór commentaar. Een trailing comment of lintmarkering is geen zelfstandig toelichtingsblok. De inhoudelijke juistheid van de uitleg blijft review.

**Meldingen en severity**

`Put a blank line before a standalone explanatory comment block`: `warning` wanneer een zelfstandig toelichtingsblok direct op code volgt.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Voegt alleen een lege regel vóór bestaande uitleg toe; behoudt aaneengesloten comments, trailing comments en genegeerde delen.

**Toegestane uitzonderingen**

Direct na {, [ of ( hoeft geen lege regel vóór commentaar. Een trailing comment of lintmarkering is geen zelfstandig toelichtingsblok.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_comment_spacing` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_comment_spacing warning -->
```puppet
$value = 1
# Explain the next value.
$other = 2
```

**Correct voorbeeld**

Fragment; alleen de controle `project_comment_spacing` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_comment_spacing clean -->
```puppet
$value = 1

# Explain the next value.
$other = 2
```

**Grensgevallen**

Direct na {, [ of ( hoeft geen lege regel vóór commentaar. Een trailing comment of lintmarkering is geen zelfstandig toelichtingsblok.

**Handmatige review**

Vergelijk de toelichting met de direct betrokken verwerking en controleer dat scheiding en witruimte haar bij de juiste resource of het juiste blok houden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [comment_spacing_test.rb](test/comment_spacing_test.rb), [resource_sections_test.rb](test/resource_sections_test.rb), [brace_layout_test.rb](test/brace_layout_test.rb), [cli_sections_test.rb](test/cli_sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Toelichtingsblokken van eerdere code scheiden

`project_comment_spacing` kan de lege regel vóór een bestaand commentaarblok toevoegen. `project_layout` kan lege regels direct na `{` verwijderen en meldt daarbij de eerste lege regel, ook als die spaties of tabs bevat. Genegeerde delen blijven behouden. `project_resource_sections` controleert of de toelichting bij een nieuwe resource aanwezig is en heeft geen autofix.

#### Inhoud direct na een openingsaccolade beginnen

**Norm**

Na een openende `{` begint de inhoud direct op de volgende regel, ook als er achter de accolade commentaar staat. Dit geldt voor codeblokken en verzamelingen. Verderop in het blok mogen lege regels onderdelen scheiden. Bij `[` en `(` mag ook de eerste regel leeg zijn. Deze opmaakregels gaan over Puppet-code; tekens binnen strings, reguliere expressies, heredocs of commentaar behouden hun betekenis.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Na een openende `{` begint de inhoud direct op de volgende regel, ook als er achter de accolade commentaar staat. Dit geldt voor codeblokken en verzamelingen. Verderop in het blok mogen lege regels onderdelen scheiden. Bij `[` en `(` mag ook de eerste regel leeg zijn. Deze opmaakregels gaan over Puppet-code; tekens binnen strings, reguliere expressies, heredocs of commentaar behouden hun betekenis.

**Automatische controle**

`project_layout`

**Detectiegrenzen**

Na [ of ( mag de eerste regel leeg zijn. Tekens in strings, regex, heredocs en commentaar blijven data. Lege regels verder in het blok mogen onderdelen scheiden. De inhoudelijke juistheid van de uitleg blijft review.

**Meldingen en severity**

`Remove blank lines immediately after an opening brace`: `warning` op de eerste lege regel, ook met spaties of tabs.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Verwijdert uitsluitend lege tokens na een echte openingsaccolade; comments op de openingsregel blijven behouden en genegeerde bereiken worden niet gewijzigd.

**Toegestane uitzonderingen**

Na [ of ( mag de eerste regel leeg zijn. Tekens in strings, regex, heredocs en commentaar blijven data. Lege regels verder in het blok mogen onderdelen scheiden.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_layout`; verwacht warning.

<!-- lint-example: project_layout warning -->
```puppet
if $active {

  notice('Active')
}
```

**Correct voorbeeld**

Fragment; alleen `project_layout`; verwacht geen melding.

<!-- lint-example: project_layout clean -->
```puppet
if $active {
  notice('Active')
}
```

**Grensgevallen**

Na [ of ( mag de eerste regel leeg zijn. Tekens in strings, regex, heredocs en commentaar blijven data. Lege regels verder in het blok mogen onderdelen scheiden.

**Handmatige review**

Vergelijk de toelichting met de direct betrokken verwerking en controleer dat scheiding en witruimte haar bij de juiste resource of het juiste blok houden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [comment_spacing_test.rb](test/comment_spacing_test.rb), [resource_sections_test.rb](test/resource_sections_test.rb), [brace_layout_test.rb](test/brace_layout_test.rb), [cli_sections_test.rb](test/cli_sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Een resource na een afgesloten blok toelichten

**Norm**

Een resourcedeclaratie na een afgesloten `}` begint met een lege regel en een eigen toelichting direct boven de declaratie. Dat geldt ook voor defined types, resourcedefaults en overrides. Resources die met `->` of `~>` verbonden zijn blijven samen één keten.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Een resourcedeclaratie na een afgesloten `}` begint met een lege regel en een eigen toelichting direct boven de declaratie. Dat geldt ook voor defined types, resourcedefaults en overrides. Resources die met `->` of `~>` verbonden zijn blijven samen één keten.

**Automatische controle**

`project_resource_sections`

**Detectiegrenzen**

Dit omvat defined types, resourcedefaults en overrides. Resources verbonden met een relatiepijl blijven samen één keten. De inhoudelijke juistheid van de uitleg blijft review.

**Meldingen en severity**

`Start a resource declaration after a closed block with a blank line and a preceding explanatory comment`: `warning` bij ontbrekende eigen toelichting of scheiding.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de check verzint geen uitleg en verplaatst geen resources.

**Toegestane uitzonderingen**

Dit omvat defined types, resourcedefaults en overrides. Resources verbonden met een relatiepijl blijven samen één keten.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_resource_sections`; verwacht warning.

<!-- lint-example: project_resource_sections warning -->
```puppet
if $active { notice('Active') }
notify { 'example': }
```

**Correct voorbeeld**

Fragment; alleen `project_resource_sections`; verwacht geen melding.

<!-- lint-example: project_resource_sections clean -->
```puppet
if $active { notice('Active') }

# Report the independently configured state.
notify { 'example': }
```

**Grensgevallen**

Dit omvat defined types, resourcedefaults en overrides. Resources verbonden met een relatiepijl blijven samen één keten.

**Handmatige review**

Vergelijk de toelichting met de direct betrokken verwerking en controleer dat scheiding en witruimte haar bij de juiste resource of het juiste blok houden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [comment_spacing_test.rb](test/comment_spacing_test.rb), [resource_sections_test.rb](test/resource_sections_test.rb), [brace_layout_test.rb](test/brace_layout_test.rb), [cli_sections_test.rb](test/cli_sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Bestaande implementatie-uitleg actueel houden

**Norm**

Controleer bij de review of de uitleg nog klopt en of lange reeksen instellingen herkenbaar zijn gegroepeerd. Vergelijk de passage met goed gedocumenteerde bestaande code en verwijder verouderde, dubbele of overbodige uitleg. Projectbeleid hoort in de documentatie; implementatiecommentaar legt de lokale reden en gevolgen uit.

**Herkomst**

Projectregel

**Toepassingsgebied**

Bestaande toelichtingen in geraakte implementatieblokken.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Toelichtingen bij code](#toelichtingen-bij-code).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Het verwijderen van uitleg is alleen passend wanneer zij verouderd, dubbel of overbodig is; noodzakelijke lokale redenen blijven staan.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Het verwijderen van uitleg is alleen passend wanneer zij verouderd, dubbel of overbodig is; noodzakelijke lokale redenen blijven staan.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Commentaar beschrijft een verwijderde fallback en dupliceert projectbeleid. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Verwijder verouderde of overbodige uitleg en behoud lokale redenen en gevolgen; laat beleid in de documentatie. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Het verwijderen van uitleg is alleen passend wanneer zij verouderd, dubbel of overbodig is; noodzakelijke lokale redenen blijven staan.

**Handmatige review**

Vergelijk met de huidige code en goed gedocumenteerde voorbeelden en controleer herkenbare groepering van lange instellingenreeksen.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Vergelijk met de huidige code en goed gedocumenteerde voorbeelden en controleer herkenbare groepering van lange instellingenreeksen. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Niet-zichtbare implementatiekeuzes toelichten

**Norm**

Licht vooral de keuzes toe die niet uit de volgende regel blijken. Dat geldt bijvoorbeeld voor een resourcegroep, exec, afgeleide waarde, voorwaardelijke directive, gedelegeerde resource of opruimroute. Ook helpers en templatelogica verdienen uitleg wanneer de invoer, uitvoer of gevolgen voor exitcodes niet vanzelf spreken. Bij escaping, parsing, classificatie, samenvoegen van resultaten en terugvalgedrag helpt zo'n toelichting om een latere wijziging veilig te beoordelen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Resourcegroepen, execs, afgeleide waarden, directives, delegatie, opruimroutes, helpers en templatelogica.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Toelichtingen bij code](#toelichtingen-bij-code).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Vanzelfsprekende code verlangt geen overbodige herhaling; de norm richt zich op keuzes en gevolgen die niet direct zichtbaar zijn.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Vanzelfsprekende code verlangt geen overbodige herhaling; de norm richt zich op keuzes en gevolgen die niet direct zichtbaar zijn.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een complexe escaping- of terugvalstap heeft geen uitleg over haar gevolgen. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Beschrijf de reden en de relevante invoer, uitvoer of exitgevolgen wanneer die niet vanzelf spreken. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Vanzelfsprekende code verlangt geen overbodige herhaling; de norm richt zich op keuzes en gevolgen die niet direct zichtbaar zijn.

**Handmatige review**

Controleer iedere genoemde soort keuze en koppel de uitleg aan het lokale risico van parsing, classificatie of samenvoegen.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer iedere genoemde soort keuze en koppel de uitleg aan het lokale risico van parsing, classificatie of samenvoegen. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Codecommentaar in Engelse zinnen schrijven

**Norm**

Een toelichting vertelt waarom de code nodig is, welke beperking ermee wordt opgevangen of welk gevolg de lezer moet kennen. Schrijf codecommentaar in het Engels en houd iedere zin op één fysieke regel. Lijsten, voorbeelden en syntaxis mogen hun eigen regels krijgen. Voor [Puppet Strings](#puppet-strings) geldt een andere opmaak, met afgebroken documentatietekst. Werk willekeurige regelafbrekingen in geraakte codecomments weg.

**Herkomst**

Projectregel

**Toepassingsgebied**

Gewone codecomments buiten Puppet Strings.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Toelichtingen bij code](#toelichtingen-bij-code).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Lijsten, voorbeelden en syntaxis mogen eigen regels krijgen; Puppet Strings heeft afgebroken tekst volgens de aparte opmaak.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Lijsten, voorbeelden en syntaxis mogen eigen regels krijgen; Puppet Strings heeft afgebroken tekst volgens de aparte opmaak.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een Engelse zin wordt willekeurig over meerdere fysieke regels verdeeld. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Houd iedere zin op één fysieke regel en leg de reden, beperking of relevante gevolgen uit. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Lijsten, voorbeelden en syntaxis mogen eigen regels krijgen; Puppet Strings heeft afgebroken tekst volgens de aparte opmaak.

**Handmatige review**

Lees de volledige zin en werk willekeurige afbrekingen in geraakte comments weg.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Lees de volledige zin en werk willekeurige afbrekingen in geraakte comments weg. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Voorwaarden toelichten

**Norm**

Geef iedere `if` en `unless` een toelichting die de voorwaarde en de bijbehorende verwerking verklaart. Als direct ervoor variabelen worden berekend die de voorwaarde voorbereiden, staat die toelichting boven de eerste toekenning. De voorbereiding en de voorwaarde vormen dan samen één blok:

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

If/unless, geneste voorwaarden, toekenningsvormen en aaneengesloten voorbereiding inclusief transitieve invoer en elsif-condities.

**Automatische controle**

`project_if_sections`

**Detectiegrenzen**

Een ongerelateerde toekenning of andere opdracht onderbreekt de terugwaartse reeks. Bestaand commentaar wordt alleen op plaatsing beoordeeld; inhoud blijft review.

**Meldingen en severity**

`Explain the conditional above its preparatory variable assignments, or above the if/unless when there are none`: `warning` bij ontbrekende toelichting boven het vastgestelde begin.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Elsif deelt de ketentoelichting. Tussen uitleg en blok mag een lege regel staan. Een geneste if heeft wel een eigen toelichting nodig.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_if_sections` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_if_sections warning -->
```puppet
if $active { notice('Active') }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_if_sections` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_if_sections clean -->
```puppet
# Report the active state.
if $active { notice('Active') }
```

**Grensgevallen**

Elsif deelt de ketentoelichting. Tussen uitleg en blok mag een lege regel staan. Een geneste if heeft wel een eigen toelichting nodig. Een ongerelateerde toekenning of andere opdracht onderbreekt de terugwaartse reeks. Bestaand commentaar wordt alleen op plaatsing beoordeeld; inhoud blijft review. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Voorwaarden toelichten](#verdieping-bij-voorwaarden-toelichten).

**Handmatige review**

Controleer dat de uitleg alle voorbereide waarden en de feitelijke voorwaarde verklaart en niet alleen een vorig of buitenste blok beschrijft.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [if_sections_test.rb](test/if_sections_test.rb), [cli_sections_test.rb](test/cli_sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Voorwaarden toelichten

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_if_sections` gecontroleerd.

<!-- lint-example: project_if_sections clean -->
```puppet
# Register this target only when monitoring is enabled.
$active = $ensure == present and defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none'
if ($active) {
  notice('Register the active monitoring target')
}
```

Zonder voorbereiding staat de toelichting boven de voorwaarde zelf. Bij `$result = if ...` staat zij boven de toekenning en eventuele voorbereiding. Een `elsif` hoort bij dezelfde keten; een geneste voorwaarde krijgt een eigen toelichting. Er mag een lege regel tussen toelichting en blok staan. De [gewone commentaaropmaak](#toelichtingen-bij-code) regelt de scheiding met eerdere code.

`project_if_sections` volgt de aaneengesloten voorbereiding van de voorwaarde. Een losstaande toekenning of andere opdracht onderbreekt die reeks. De [technische analyse](#voorbereiding-van-voorwaarden) beschrijft hoe indirecte afhankelijkheden worden gevolgd.

De check schrijft of verplaatst geen commentaar. Beoordeel bij een melding of de toelichting zowel de voorbereiding als de voorwaarde uitlegt. Commentaar bij een eerder of bovenliggend blok vervangt die uitleg niet.

#### Variabelen groeperen

<!-- lint-rule-group -->

#### Een variabelegroep bij blokbegin toelichten

**Norm**

Groepeer variabelen op het doel waarvoor je ze berekent. Begin een codeblok dat na `{` meteen variabelen toekent met een toelichting binnen dat blok, direct boven de eerste toekenning. Dit geldt ook voor één variabele en voor korte `else`-, `elsif`- en `case`-takken, classes, defined types en lambdablokken. De toelichting boven de voorwaarde beschrijft waarom de tak wordt uitgevoerd; de uitleg binnen het blok beschrijft de variabelen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Toekenningen direct na { in classes, defines, lambdas, else-, elsif- en case-takken.

**Automatische controle**

`project_variable_sections`

**Detectiegrenzen**

Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope.

**Meldingen en severity**

`Explain the variable group immediately inside the opening brace`: `warning` bij ontbrekende inhoudelijke toelichting. Een eventuele groepeerhint blijft onderdeel van die warning; zie de gedeelde verdieping.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Ook één variabele verlangt de toelichting. De toelichting boven een voorwaarde vervangt die binnen haar tak niet.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_variable_sections` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_variable_sections warning -->
```puppet
if $active {
  $value = 1
}
```

**Correct voorbeeld**

Fragment; alleen de controle `project_variable_sections` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_variable_sections clean -->
```puppet
if $active {
  # Prepare the selected value.
  $value = 1
}
```

**Grensgevallen**

Onafhankelijke instellingen mogen samen één toelichting delen. Er is geen verplicht commentaar per variabele. Een resource, voorwaarde of andere opdracht beëindigt de reeks. Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen).

**Handmatige review**

Controleer per groep het doel en de werkelijk gebruikte variabelen. Beoordeel vóór samenvoegen of een eerste gebruik of andere uitvoering de verplaatsing verhindert.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [variable_openings_test.rb](test/variable_openings_test.rb), [variable_dependencies_test.rb](test/variable_dependencies_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Een onafhankelijke groep na afhankelijke waarden beginnen

**Norm**

Maak een nieuwe groep wanneer na onderling afhankelijke berekeningen een losstaande instelling volgt. De [verdieping bij deze regel](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen) laat dit zien met een genormaliseerde servernaam, een ge-escapete waarde en een label, gevolgd door afzonderlijke configuratie-instellingen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Reeds toegelichte aaneengesloten toekenningsreeksen met echte lokale afhankelijkheden.

**Automatische controle**

`project_variable_sections`

**Detectiegrenzen**

Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope.

**Meldingen en severity**

`Start unrelated assignments after a dependent variable group with a blank line and a preceding explanatory comment`: `warning` bij een onafhankelijke toekenning na een aantoonbaar afhankelijke groep. Een eventuele groepeerhint blijft warning.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Onafhankelijke instellingen mogen samen onder één toelichting. De check verlangt geen commentaar per variabele. Andere opdrachten beëindigen de reeks; buiten blokbegin worden alleen reeds toegelichte reeksen onderzocht.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_variable_sections`; verwacht warning.

<!-- lint-example: project_variable_sections warning -->
```puppet
# Prepare a related pair.
$a = 'a'
$b = $a
$c = 'c'
```

**Correct voorbeeld**

Fragment; alleen `project_variable_sections`; verwacht geen melding.

<!-- lint-example: project_variable_sections clean -->
```puppet
# Prepare a related pair.
$a = 'a'
$b = $a

# Configure the independent value.
$c = 'c'
```

**Grensgevallen**

Onafhankelijke instellingen mogen samen één toelichting delen. Er is geen verplicht commentaar per variabele. Een resource, voorwaarde of andere opdracht beëindigt de reeks. Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen).

**Handmatige review**

Controleer per groep het doel en de werkelijk gebruikte variabelen. Beoordeel vóór samenvoegen of een eerste gebruik of andere uitvoering de verplaatsing verhindert.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [variable_openings_test.rb](test/variable_openings_test.rb), [variable_dependencies_test.rb](test/variable_dependencies_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen

Maak een nieuwe groep wanneer na onderling afhankelijke berekeningen een losstaande instelling volgt. In dit voorbeeld horen de genormaliseerde servernaam, de ge-escapete waarde en het label bij elkaar. Het configuratiepad en de numerieke instellingen vormen de volgende groep:

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_variable_sections` gecontroleerd.

<!-- lint-example: project_variable_sections clean -->
```puppet
# Prepare arguments only for an active certificate check.
if $active {
  # Normalize the name for the command and its label.
  $server_name_correct = regsubst($server_name ? { undef => '', default => $server_name }, '\s+', ' ', 'G')
  $server_name_shell = stdlib::shell_escape($server_name_correct)
  $check_friendly = "Nginx TLS ${server_name_correct}"

  # Escape the configuration path and numeric settings before passing them to the check.
  $config_file_shell = stdlib::shell_escape($config_file)
  $detail_limit_shell = stdlib::shell_escape(String($detail_limit))
  $timeout_shell = stdlib::shell_escape(String($timeout))
  $validity_critical_shell = stdlib::shell_escape(String($validity_critical))
  $validity_warning_shell = stdlib::shell_escape(String($validity_warning))
}
```

`project_variable_sections` controleert de toelichting aan het begin van een blok en de grenzen tussen toegelichte groepen. Een leeg commentaar of alleen een lintmarkering telt niet als toelichting. Zodra een toekenning een eerder berekende variabele uit de groep gebruikt, zoekt de check naar de eerste volgende toekenning die onafhankelijk van die groep is. Die krijgt een eigen toelichting; alleen een lege regel is onvoldoende. Een later samengesteld commando maakt zo'n eerdere scheiding niet overbodig.

Onafhankelijke instellingen mogen samen onder één toelichting staan, zoals de numerieke instellingen in het voorbeeld. De check verlangt dus geen commentaar per variabele. Hij leidt samenhang af uit echte verwijzingen, ook in interpolatie. Een overeenkomstige naam, dezelfde functie of hetzelfde externe invoerveld is daarvoor geen bewijs.

Een resource, voorwaarde of andere opdracht beëindigt de onderzochte reeks. Buiten het begin van een blok onderzoekt de check alleen reeksen die al een toelichting hebben. De analyse houdt lokale lambdavariabelen en parameters gescheiden van variabelen buiten de lambda.

Bij een ontbrekende toelichting kan de melding wijzen op een latere groep met dezelfde buitenste functie. Gebruik die hint om te beoordelen of de waarden bij elkaar horen en of de volgorde van uitvoeren mag veranderen. De [technische naslag](#hints-voor-variabelegroepen) beschrijft wanneer de hint verschijnt. Er is geen autofix: de linter kan de inhoudelijke samenhang niet bepalen en verplaatst daarom geen code.

#### Puppet Strings

<!-- lint-rule-group -->

De volgende zelfstandige regels delen de Strings-parser. Inhoudelijke controles en opmaakcontroles zijn afzonderlijke checks; iedere regel vermeldt haar eigen varianten.

#### Publieke declaraties bij de code documenteren

**Norm**

Puppet Strings beschrijft de publieke interface bij de code. Zet de documentatie direct boven iedere publieke class en ieder publiek defined type. De lezer moet daarmee kunnen bepalen welke parameters nodig zijn en wat de declaratie op een host verandert.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types. API-markering van nieuwe functies blijft handmatig waar die niet wordt geanalyseerd.

**Automatische controle**

`project_documentation`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit.

**Meldingen en severity**

De inhoudscheck meldt ontbrekende summary, API-tag, voorbeeld en parameterbeschrijvingen afzonderlijk; de exacte warnings staan bij [Summary](#strings-summary-op-één-regel), [API](#strings-api-markering), [Voorbeeld](#uitvoerbare-strings-voorbeelden) en [Parameters](#strings-parametercontract).

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Geen uitzondering op de beschreven documentatieplicht; een detectiegrens heft haar niet op.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

De inhoudscheck betrekt ook niet als public gemarkeerde classes en defined types. Een functionele beschrijving voor een functie wordt niet door deze check bewezen.

**Handmatige review**

Vergelijk de documentatie met de publieke parameters en de daadwerkelijke gevolgen op een host; beoordeel ook een aanwezig maar onjuist contract.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). [interface_contract_test.rb](test/interface_contract_test.rb), `test_documentation_matches_each_declaration`, verifieert afzonderlijke declaraties. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

##### Verdieping bij Publieke declaraties bij de code documenteren

`project_documentation` controleert bij classes en defined types de summary, API-markering, voorbeeldtag en parameterbeschrijvingen. De check controleert aanwezigheid en volgorde, niet of de tekst het werkelijke gedrag volledig beschrijft. Ontbrekende uitleg of tags worden niet automatisch ingevuld.

#### Strings API-markering

**Norm**

Markeer nieuwe classes, defined types en functies met `@api public` of `@api private`.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types. API-markering van nieuwe functies blijft handmatig waar die niet wordt geanalyseerd.

**Automatische controle**

`project_documentation`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. Functies vallen buiten deze inhoudscheck.

**Meldingen en severity**

`Document the declaration with @api public or @api private`: `warning` wanneer niet precies één geldige API-regel aanwezig is.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Geen uitzondering op de beschreven documentatieplicht; een detectiegrens heft haar niet op.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Een dubbele API-tag geeft dezelfde warning. Een nieuwe functie zonder API-markering vraagt handmatige afkeur; dat ontbreken wordt hier niet automatisch gedetecteerd.

**Handmatige review**

Bepaal de bedoelde public/private-interface en controleer nieuwe classes, defines én functies.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). [interface_contract_test.rb](test/interface_contract_test.rb) controleert documentatie per declaratie; het bovenstaande fragment bewijst de API-variant. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Strings-summary op één regel

**Norm**

Begin met een korte `@summary` op één regel en zet verdere uitleg eronder.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation`, `project_documentation_layout`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. Summarytekst wordt niet automatisch ingekort.

**Meldingen en severity**

`Document the declaration with one non-empty @summary`: `warning` bij ontbrekende, lege of dubbele summary. `Keep @summary on one line; move additional explanation to the overview`: `warning` bij vervolgtekst in de summary. Lengtevarianten en hun suffix staan bij [Strings-regelbreedte](#strings-regelbreedte).

**Autofix**

Geen voor de inhoudsvariant en summaryvervolgtekst. Voor de lengtevariant bij een summary: Geen.

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Geen uitzondering op de beschreven documentatieplicht; een detectiegrens heft haar niet op.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Een lange summary wordt handmatig ingekort zonder betekenisverlies; nadere uitleg verhuist naar de overview. Een ingesprongen vervolgzin is geen tweede toegestane summaryregel.

**Handmatige review**

Controleer één korte summary en behoud noodzakelijke details in de overview.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). [documentation_structure_test.rb](test/documentation_structure_test.rb), `test_summary_requires_manual_shortening_without_deleting_text`, verifieert behoud en weigering. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Strings-parametercontract

**Norm**

Beschrijf iedere parameter eenmaal met `@param`, in dezelfde volgorde als de declaratie. Leg uit wat de waarde betekent, hoe de default tot stand komt en wat bijzondere waarden zoals `undef`, `true` en `false` doen. Neem ook relevante beperkingen, dependencies, gegenereerde resources, terugvalgedrag en gevolgen voor beveiliging of compatibiliteit op.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types. API-markering van nieuwe functies blijft handmatig waar die niet wordt geanalyseerd.

**Automatische controle**

`project_documentation`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. De check leest tagvolgorde en aanwezige tekst, geen defaultsemantiek.

**Meldingen en severity**

`Document every parameter exactly once, in declaration order`: `warning` bij een verschil tussen tagnamen en declaratievolgorde. `Give each @param a description of its contract and default meaning`: `warning` wanneer tekst op de tagregel en de eerstvolgende ingesprongen regel ontbreekt.

**Autofix**

Geen voor beide meldingsvarianten.

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Een korte beschrijving mag op de @param-regel staan; de [tagopmaak](#strings-taginspringing) bepaalt langere tekst.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example (String $label) {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @param label
#   Supplies the displayed label.
#
# @api public
class example (String $label) {}
```

**Grensgevallen**

Typeannotaties zoals @param [String] label worden herkend. Lege beschrijvingen, dubbelen en verkeerde volgorde vragen correctie; aanwezige maar onjuiste defaultuitleg blijft review.

**Handmatige review**

Vergelijk iedere parameter, default, undef/true/false-betekenis, dependency, gegenereerde resource, fallback en beveiligings- of compatibiliteitsgevolg met de implementatie.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). [documentation_scope_test.rb](test/documentation_scope_test.rb), beschrijvingsscenario’s, en [interface_contract_test.rb](test/interface_contract_test.rb) controleren aanwezigheid en volgorde. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Uitvoerbare Strings-voorbeelden

**Norm**

Een eenvoudig uitvoerbaar `@example` laat het normale gebruik zien. De titel staat achter de tag, de code op de ingesprongen commentregels eronder. Dit documentatieblok toont de opmaak:

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation`, `project_documentation_layout`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. De opmaakcheck herkent vervolgregels, maar bewijst geen syntactisch of functioneel juist voorbeeld.

**Meldingen en severity**

`Provide a Puppet Strings @example`: `warning` bij ontbrekende tag met niet-lege titel. `Put the example description on the @example line`: `warning` bij lege titel. `Put example code on indented comment lines below @example`: `warning` wanneer de eerstvolgende inhoud ontbreekt of een nieuwe tag is. Inspringing en breedte volgen de afzonderlijke opmaakregels.

**Autofix**

Geen voor deze drie varianten.

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Voorbeeldcode bewaart haar eigen verdere inspringing; zij wordt niet als gewone tekst afgebroken.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
# @summary Demonstrates the interface.
#
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Een lege titel, ontbrekende code, onjuiste eerste inspringing en code boven 140 tekens zijn verschillende scenario’s. Markdown- of code-inhoud wordt niet geherformuleerd.

**Handmatige review**

Werk het voorbeeld met prerequisites tijdelijk uit, valideer correcte en onjuiste invoer met parser en volledig profiel en beoordeel het normale gebruik.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). [documentation_examples_test.rb](test/documentation_examples_test.rb) controleert behoud van voorbeeldcode, breedte, handmatige inspringing en titel/body. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

##### Verdieping bij Uitvoerbare Strings-voorbeelden

Fragment; dit behouden documentatieblok toont de opmaak en is op zichzelf geen volledige declaratie.

Voor dit fragment wordt uitsluitend `project_documentation, project_documentation_layout` gecontroleerd. Voeg voor uitvoering `class example (Boolean $keyboard_enable = true) {}` toe na het blok.

<!-- lint-example: project_documentation, project_documentation_layout clean keyboard_class -->
```puppet
# @summary Manages local console configuration.
#
# This class manages console packages and configuration, using the host defaults
# when no explicit override is supplied.
#
# @example Enable keyboard configuration
#   class { 'example':
#     keyboard_enable => true,
#   }
#
# @param keyboard_enable
#   Controls keyboard package and configuration management.
#   `undef` uses the host default; `true` enables management and `false` disables it.
#
# @api public
```

#### Strings-regelbreedte

**Norm**

Breek gewone beschrijvingen af op logische plaatsen, bij voorkeur rond 120 tekens en uiterlijk bij 140 tekens. De inspringing en het commentteken tellen mee. Houd woorden, technische identifiers en inline code intact en behoud de alinea-indeling. Een ondeelbaar element tussen 120 en 140 tekens mag op zijn regel blijven staan. Voor langere letterlijke waarden geldt de uitzondering bij [Lange regels](#lange-regels).

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Voorbeeldcode wordt pas boven 140 tekens gemeld. Een ondeelbaar element tussen 120 en 140 blijft intact. Gewone tekst, summaries, voorbeeldtitels, Markdownstructuur en letterlijke waarden krijgen verschillende fixbehandeling.

**Meldingen en severity**

`Puppet Strings documentation exceeds the maximum 140-character line length`: `warning` boven 140 zonder geldige literaluitzondering. `Puppet Strings documentation exceeds the preferred 120-character line width`: `warning` voor afbreekbare niet-voorbeeldtekst boven 120. Het suffix is `Shorten @summary and move the full description into the overview`, `Keep the @example title on one line and shorten it manually` of `Wrap documentation across comment lines; preserve literal values and example code`. Onveilig herschrijven voegt ` [review] Adjust manually; this construct cannot be safely rewritten` toe. `[review]` blijft warning.

**Autofix**

| Variant en constructie | Classificatie |
| --- | --- |
| Maximum of preferred bij veilig afbreekbare gewone tekst | Voorwaardelijk |
| Maximum of preferred bij summary, voorbeeldtitel, codevoorbeeld of onveilige structuur | Geen |

**Autofixvoorwaarden**

Breekt alleen gewone tekst op woorden af; behoudt backticks, identifiers, whitespace in literals en alinea’s. Herkenbare @param-tekst kan onder de tag verhuizen. Lijsten, tabellen, codefences, ingesprongen code, harde Markdownregeleinden, ongebalanceerde delimiters, onleesbare tags en ondeelbare te brede output krijgen geen onveilige herschrijving.

**Toegestane uitzonderingen**

Ondeelbare elementen van 120–140 tekens blijven toegestaan; langere literals uitsluitend met de begrensde uitzondering bij Lange regels.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# @summary Demonstrates the interface.
#
# word word word word word word word word word word word word word word word word word word word word word word word word end.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# word word word word word word word word word word word word
# word word word word word word word word word word word word end.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

120 tekens: schoon. Afbreekbare tekst op 121 en 140: preferred-warning. 141: maximum-warning. Een ondeelbaar pad van 126 tekens blijft schoon; een lange URL verbergt omringende afbreekbare tekst niet. Unicode en geneste inspringing tellen mee. De afzonderlijke Markdown-weigeringscategorieën staan in de autofixvoorwaarden.

**Handmatige review**

Lees tekst en gerenderde Markdown na; behoud alle woorden en technische waarden en controleer de werkelijke regellengte inclusief # en inspringing.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). [documentation_width_test.rb](test/documentation_width_test.rb) controleert 120/121/140/141, identifiers, URL, Unicode en parametertekst; [documentation_markup_test.rb](test/documentation_markup_test.rb) controleert iedere genoemde structuurweigering en woord-/alineabehoud. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

##### Verdieping bij Strings-regelbreedte

`project_documentation_layout` controleert de opmaak boven classes, defined types, Puppet-functies en typedeclaraties. Afbreekbare tekst boven 120 tekens en documentatieregels boven 140 tekens geven een melding, ook als de standaardcheck een URL zou overslaan. Voorbeeldcode krijgt alleen boven 140 tekens een lengtemelding.

Met `--fix` kan de documentatiecheck gewone tekst afbreken en herkenbare tag-inspringing en sectiescheiding herstellen. Woorden, backtick-inhoud en alinea's blijven behouden. Summaries, voorbeeldtitels, voorbeeldcode en gestructureerde Markdown, zoals lijsten, tabellen en codeblokken, vragen waar nodig handmatige correctie. Een lange summary of voorbeeldtitel kort je zelf in. Bij onveilige of onduidelijke correcties blijft een melding met `[review]` staan.

> **Open normconflict (oplevering: Strings-breedte):** de behouden norm noemt circa 120 tekens een voorkeur en 140 het uiterste. De check meldt afbreekbare tekst op 121–140 tekens met warning, waardoor het profiel faalt. `test_preferred_width_is_distinguished_from_hard_maximum` en `test_exact_line_width_boundaries_include_the_comment_prefix` bevestigen dit verschil. Deze wijziging maakt de voorkeur niet verplicht en verandert de check niet; besluitvorming over de bedoelde grens blijft open.

#### Strings-taginspringing

**Norm**

Bij een lange parameterbeschrijving staat alleen de naam achter `@param`; de uitleg volgt met twee extra spaties, als `#   ...`. Een korte beschrijving mag achter de parameternaam blijven staan.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Herkenbare voortzettingstekst wordt onderscheiden van voorbeeldcode en gestructureerde Markdown. Een lange @param-tag zonder leesbare parameternaam wordt niet herschreven.

**Meldingen en severity**

`Puppet Strings continuation lines must be indented with two spaces`: `warning` bij afwijkende voortzettingsinspringing. Kan met sectiescheiding of breedte op dezelfde regel worden gecombineerd met `; `. Onveilige constructies houden het [review]-suffix uit de breedteregel.

**Autofix**

Voorwaardelijk voor gewone herkenbare vervolgtekst; Geen voor onveilig te herschrijven voorbeeldcode, summaryvervolg of gestructureerde inhoud.

**Autofixvoorwaarden**

Herstelt uitsluitend herkenbare tekstinspringing; behoudt verdere inspringing in codevoorbeelden en weigert samenvattingen of gestructureerde Markdown wanneer het herschrijven onveilig is.

**Toegestane uitzonderingen**

Korte parameterbeschrijvingen mogen achter de parameternaam blijven staan.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @param label
# Supplies the displayed label.
#
# @api public
class example (String $label) {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @param label
#   Supplies the displayed label.
#
# @api public
class example (String $label) {}
```

**Grensgevallen**

Korte inlinebeschrijving: toegestaan. Lange beschrijving: onder de tag. Verkeerd ingesprongen gewone vervolgtekst: fix. Eerste voorbeeldregel met afwijkende inspringing: handmatig; verdere voorbeeldcode blijft exact.

**Handmatige review**

Controleer het verschil tussen proza en voorbeeldcode en behoud de betekenisvolle code-inspringing.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). [documentation_structure_test.rb](test/documentation_structure_test.rb), `test_continuation_indentation_is_corrected_for_parameters_and_other_tags`; [documentation_examples_test.rb](test/documentation_examples_test.rb), inspringingsweigeringen. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Strings-secties met commentregels scheiden

**Norm**

Scheid secties en afzonderlijke parameters met een lege commentregel `#`, zodat het één documentatieblok blijft. Een volledig lege broncoderegel hoort daar niet tussen. Behoud binnen voorbeeldcode de verdere code-inspringing.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Een lege bronregel en whitespace-only comment worden anders behandeld dan een lege commentregel. Herkende sectieovergangen krijgen scheiding; gewone alinea’s behouden hun volgorde.

**Meldingen en severity**

`Separate Puppet Strings sections with a blank comment line (#)`: `warning` bij volledig lege bronregel, whitespace-only comment of ontbrekende sectiescheiding. De formatter kan dit met inspringings- en breedtemeldingen op dezelfde regel combineren.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Vervangt lege bronregels door # en voegt herkenbare sectiescheiding toe. Correctie met daarnaast onveilige inspringing of te brede ondeelbare output kan worden geweigerd; tekst en alinea’s blijven behouden.

**Toegestane uitzonderingen**

Lege commentregels bewaren één documentatieblok; betekenisvolle lege regels in voorbeeldcode blijven behouden.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Volledig lege bronregel: wordt #. Comment met alleen spaties: wordt #. Twee bestaande alinea’s: blijven gescheiden en in volgorde. Ontbrekende scheiding plus onveilige code-inspringing: handmatige review.

**Handmatige review**

Lees sectiegrenzen en alinea’s en controleer dat voorbeeldcode en letterlijke inhoud niet zijn samengevoegd.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). [documentation_structure_test.rb](test/documentation_structure_test.rb) controleert secties en lege bronregels; [documentation_markup_test.rb](test/documentation_markup_test.rb) controleert alinea’s en whitespace-only comments. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

##### Verdieping bij Strings-secties met commentregels scheiden

De [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm) beschrijft de algemene opbouw.

#### Lengtesuppressions in Strings begrenzen

**Norm**

Een overbodig `140chars`-blok rond uitsluitend gewone documentatie kan de autofix verwijderen. Een blok met een toelichtende reden, een gecombineerde uitzondering of een uitzondering die ook Puppet-code omvat vraagt handmatige begrenzing. Controleer na correctie de tekst en Markdown-opbouw en valideer de voorbeelden volgens [Aanvullende validatie](#aanvullende-validatie).

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Een suppression moet uitsluitend gewone documentatie beslaan om automatisch verwijderd te kunnen worden. Gemengde inhoud, toelichtende reden en gecombineerde checks worden niet stilzwijgend herschreven.

**Meldingen en severity**

`Do not disable the 140-character rule for normal Puppet Strings documentation; wrap the documentation instead`: `warning`. Bij handmatige begrenzing volgt ` [review] Narrow the suppression manually, preserving literal values and other checks`.

**Autofix**

Voorwaardelijk voor een verwijderbaar uitsluitend-documentatieblok; Geen voor niet veilig te begrenzen blokken.

**Autofixvoorwaarden**

Verwijdert uitsluitend een overbodig enkelvoudig 140chars-blok en breekt veilige gewone tekst af; behoudt redenen, gecombineerde checks, letterlijke waarden en Puppet-code.

**Toegestane uitzonderingen**

Een ondeelbare lange letterlijke waarde mag een minimaal begrensde 140chars-uitzondering krijgen; sluit vóór gewone documentatie.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# lint:ignore:140chars
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
# lint:endignore
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Uitsluitend gewone documentatie zonder reden: verwijderbaar. Reden achter de markering, meerdere checks, code in hetzelfde bereik of literalgrens: handmatig behouden en begrenzen.

**Handmatige review**

Controleer ieder teken van het suppressionbereik; verifieer dat gewone tekst weer wordt gecontroleerd en literals en andere checks behouden blijven.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](test/guide_examples_test.rb). [documentation_suppressions_test.rb](test/documentation_suppressions_test.rb) controleert verwijderbare en geweigerde suppressions en scopes. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Waar de uitleg hoort

<!-- lint-rule-group -->

#### Interfacebeschrijvingen synchroniseren

**Norm**

Werk bij een interfacewijziging de Puppet Strings en de geraakte voorbeelden mee bij. Vergelijk de beschreven defaults, relaties en gegenereerde configuratie met het manifest. Als monitoringgedrag voor beheerders verandert, kijk dan ook naar het checkoverzicht in de project-README.

**Herkomst**

Projectregel

**Toepassingsgebied**

Puppet Strings, voorbeelden en het beheerdergerichte checkoverzicht bij interfacewijzigingen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Het checkoverzicht verandert alleen wanneer het beheerdergerichte monitoringgedrag verandert.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Het checkoverzicht verandert alleen wanneer het beheerdergerichte monitoringgedrag verandert.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een parameterdefault verandert, maar Strings en het voorbeeld noemen de oude waarde. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Werk Strings en geraakte voorbeelden bij en pas bij gewijzigd monitoringgedrag het checkoverzicht aan. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Het checkoverzicht verandert alleen wanneer het beheerdergerichte monitoringgedrag verandert.

**Handmatige review**

Vergelijk defaults, relaties en gegenereerde configuratie afzonderlijk met het manifest.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk defaults, relaties en gegenereerde configuratie afzonderlijk met het manifest. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Documentatie op haar aangewezen plaats onderhouden

**Norm**

Gebruik de [documentatie-indeling in `AGENTS.md`](../../AGENTS.md#documentation) om te bepalen waar de uitleg thuishoort. Gebruikskeuzes horen in de gebruikershandleiding, parametercontracten in Puppet Strings en lokale implementatieredenen bij het script of de template. Maak geen handmatige `REFERENCE.md` of `docs/`-boom voor informatie die Puppet Strings kan genereren. Voeg een ADR alleen toe wanneer dat is gevraagd of al gebruikelijk is.

**Herkomst**

Projectregel

**Toepassingsgebied**

Gebruikskeuzes, parametercontracten en lokale implementatieredenen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een ADR wordt alleen toegevoegd op verzoek of wanneer dat al gebruikelijk is; dit wijzigt de inhoudelijke documentatieplicht niet.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een ADR wordt alleen toegevoegd op verzoek of wanneer dat al gebruikelijk is; dit wijzigt de inhoudelijke documentatieplicht niet.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een handmatig REFERENCE.md dupliceert de door Puppet Strings te genereren parameterbeschrijvingen. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Behoud parametercontracten bij de code, gebruikskeuzes in de gebruikershandleiding en lokale redenen bij script of template. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een ADR wordt alleen toegevoegd op verzoek of wanneer dat al gebruikelijk is; dit wijzigt de inhoudelijke documentatieplicht niet.

**Handmatige review**

Controleer de verantwoordelijkheden van iedere geraakte uitleg en voorkom een tweede handmatige contractbron.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer de verantwoordelijkheden van iedere geraakte uitleg en voorkom een tweede handmatige contractbron. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Uitvoerbare voorbeeldscenario’s onderhouden

**Norm**

Breid bij voorkeur een bestaand voorbeeldscenario uit. Toon daarin de benodigde parameters en zorg dat het voorbeeld met de genoemde voorwaarden uitvoerbaar is. De [project-README](../../README.md#gebruik-van-voorbeelden-en-parameterdocumentatie) beschrijft het gebruik van voorbeeldwaarden, `Sensitive(...)` en Hiera; voor synthetische gegevens gelden de [beveiligingsregels](../../AGENTS.md#security-and-privacy).

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe en bijgewerkte gebruiksvoorbeelden bij publieke interfaces.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Uitbreiden van een bestaand scenario is een voorkeur. De uitvoerbaarheid onder de vermelde voorwaarden en de beveiligingsafspraken blijven verplicht.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Uitbreiden van een bestaand scenario is een voorkeur. De uitvoerbaarheid onder de vermelde voorwaarden en de beveiligingsafspraken blijven verplicht.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een voorbeeld mist een verplicht argument en presenteert een geheim als gewone tekst. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Breid bij voorkeur het bestaande scenario uit, vermeld voorwaarden en vereiste argumenten en volg de beschreven Sensitive- en Hiera-afspraken. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Uitbreiden van een bestaand scenario is een voorkeur. De uitvoerbaarheid onder de vermelde voorwaarden en de beveiligingsafspraken blijven verplicht.

**Handmatige review**

Controleer alle genoemde prerequisites, argumenten en synthetische waarden; valideer het uitgewerkte voorbeeld volgens Aanvullende validatie.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer alle genoemde prerequisites, argumenten en synthetische waarden; valideer het uitgewerkte voorbeeld volgens Aanvullende validatie. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

### Bestanden en beveiliging

<!-- lint-rule-group -->

#### Templates en bestandsbronnen

<!-- lint-rule-group -->

#### Gegenereerde configuratie met ERB renderen

**Norm**

Gebruik ERB en `template(...)` voor gegenereerde configuratie. Bestanden die alleen in een klein optioneel onderdeel verschillen kunnen één template delen. Bij een ander formaat of een andere verantwoordelijkheid past een aparte template. `project_templates` meldt aanroepen van `epp` en `inline_epp`, maar kan de omzetting naar ERB niet automatisch uitvoeren.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Aanroepen van epp en inline_epp voor gegenereerde configuratie.

**Automatische controle**

`project_templates`

**Detectiegrenzen**

De AST-check herkent functieaanroepen, geen gelijknamige tekst of comments; inhoud, formaatkeuze en ERB-equivalentie blijven review.

**Meldingen en severity**

`Render generated configuration with template(...) and ERB`: `warning` bij een epp- of inline_epp-aanroep.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: omzetting van EPP naar ERB vereist beoordeling van syntax, invoer en gerenderde inhoud.

**Toegestane uitzonderingen**

Kleine optionele verschillen mogen één template delen; een ander formaat of andere verantwoordelijkheid kan een afzonderlijke template rechtvaardigen.

**Suppressions**

Suppressie niet toegestaan voor project_templates.

**Onjuist voorbeeld**

Fragment; alleen `project_templates`; verwacht warning.

<!-- lint-example: project_templates warning -->
```puppet
$content = epp('example/settings.epp')
```

**Correct voorbeeld**

Fragment; alleen `project_templates`; verwacht geen melding.

<!-- lint-example: project_templates clean -->
```puppet
$content = template('example/settings.erb')
```

**Grensgevallen**

De fragmenten bewijzen uitsluitend de gekozen functie. Render het echte bestand voor inhoudelijke equivalentie; een string met het woord epp is geen functieaanroep.

**Handmatige review**

Vergelijk alle gerenderde varianten en de lezer van de configuratie. Kies gedeelde of afzonderlijke templates op inhoud en verantwoordelijkheid.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [source_uri_test.rb](test/source_uri_test.rb), [resource_contract_test.rb](test/resource_contract_test.rb), [cli_diagnostics_test.rb](test/cli_diagnostics_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Puppet-fileservermounts expliciet kiezen

**Norm**

Een statisch modulebestand krijgt een bron onder `puppet:///modules/...`. Voor bestanden uit de Puppet-fileservermount `files` gebruik je `puppet:///files/...`. Richt die mount en de benodigde toegang eerst op de Puppet-server in.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Genoemde epp/inline_epp-aanroepen en strings vanaf puppet://, inclusief bronarrays en prefixen vóór interpolatie.

**Automatische controle**

`project_puppet_urls`, `puppet_url_without_modules`

**Detectiegrenzen**

Dynamische vervolgpaths worden niet berekend. De checks bewijzen geen bestandsinhoud, servermount, toegangsrechten of equivalentie van ERB en EPP.

**Meldingen en severity**

`puppet:// URL must use a modules/ or files/ mount`: `warning` bij afwijkend of ontbrekend prefix. Native `puppet_url_without_modules`: `puppet:// url without modules/ found`, `warning` buiten modules/.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een ingerichte en toegankelijke files-mount is toegestaan met de lokale bronmarkering; een expliciete servernaam verandert de mountregels niet.

**Suppressions**

Alleen voor de files-mount: `# lint:ignore:puppet_url_without_modules` achter de bronregel. Combineer zo nodig met de toegestane 140chars-markering. `project_puppet_urls` en `project_templates` mogen niet worden onderdrukt.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_puppet_urls` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_puppet_urls warning -->
```puppet
$source = 'puppet:///invalid/example/data'
```

**Correct voorbeeld**

Fragment; alleen de controle `project_puppet_urls` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_puppet_urls clean -->
```puppet
$source = 'puppet:///modules/example/data'
```

**Grensgevallen**

Een ingerichte en toegankelijke files-mount is toegestaan met de lokale bronmarkering. Een expliciete servernaam verandert de mountregels niet. Een afzonderlijk formaat of verantwoordelijkheid kan een eigen ERB-template rechtvaardigen. Dynamische vervolgpaths worden niet berekend. De checks bewijzen geen bestandsinhoud, servermount, toegangsrechten of equivalentie van ERB en EPP. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Puppet-fileservermounts expliciet kiezen](#verdieping-bij-puppet-fileservermounts-expliciet-kiezen).

**Handmatige review**

Controleer mountprefix inclusief slash, dynamische paden, Puppet-servertoegang en gerenderde inhoud onder de lezende gebruiker; accepteer puppet:/// in de invoervalidatie van de afnemer.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [source_uri_test.rb](test/source_uri_test.rb), [resource_contract_test.rb](test/resource_contract_test.rb), [cli_diagnostics_test.rb](test/cli_diagnostics_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Puppet-fileservermounts expliciet kiezen

Een statisch modulebestand krijgt een bron onder `puppet:///modules/...`. Voor bestanden uit de Puppet-fileservermount `files` gebruik je `puppet:///files/...`. Richt die mount en de benodigde toegang eerst op de Puppet-server in.

De standaardcheck `puppet_url_without_modules` meldt een `files`-bron omdat die buiten de modulemount staat. Markeer deze bewuste keuze op de bronregel, zodat de uitzondering alleen voor die regel geldt:

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_puppet_urls` gecontroleerd.

<!-- lint-example: project_puppet_urls clean -->
```puppet
file { '/tmp/example-app.tar.gz':
  ensure => file,
  owner  => 'root',
  group  => 'root',
  mode   => '0600',
  source => 'puppet:///files/example/app.tar.gz', # lint:ignore:puppet_url_without_modules
}
```

`project_puppet_urls` controleert ook op zo'n gemarkeerde regel of de mount `modules/` of `files/` is. Een onbekende of ontbrekende mount geeft een waarschuwing en laat de scan mislukken. De afsluitende `/` hoort bij de mountnaam: `files_backup/` is geen `files/`. Dezelfde controle geldt bij een URL met een expliciete servernaam.

De check bekijkt strings die met `puppet://` beginnen, ook in bronarrays en tot aan de eerste interpolatie. Hij berekent het dynamische vervolgpad niet en controleert geen bestandsinhoud, beschikbaarheid of fileserverrechten. Valideer die bij het werkelijke gebruik. Als een module zulke bronnen accepteert, hoort zijn invoervalidatie ook `puppet:///` toe te staan.

Er is geen autofix voor de bronkeuze. Een andere mount of template kan andere inhoud opleveren. Houd paden en titels voorspelbaar en controleer de gerenderde varianten bij de gebruiker die ze moet kunnen lezen. De aanvullende URL-check staat in [`puppet_urls.rb`](lib/project_lint/checks/puppet_urls.rb); hiervoor worden geen geïnstalleerde gems aangepast.

#### Pakketten en mappen

<!-- lint-rule-group -->

#### APT-opties expliciet afsluiten

**Norm**

Voorkom dat een APT-installatie onbedoeld aanbevolen of voorgestelde pakketten meeneemt. Laat `install_options` eindigen met `['--no-install-recommends', '--no-install-suggests']`, tenzij een concreet pakket een onderbouwde afwijking nodig heeft. Voeg deze opties met `concat(...)` achter de aangeleverde opties toe. `union(...)` verwijdert duplicaten en garandeert daardoor niet dat de voorgeschreven opties achteraan staan.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Package-resources voor APT/aptitude-installaties, inclusief zichtbare lokale defaults.

**Automatische controle**

`project_packages`

**Detectiegrenzen**

De check inspecteert package-resources, geen effectieve ensure_packages-aanroepen. Onopgeloste provider, overerving, overrides en niet-herkende samengestelde opties geven reviewvarianten. Bij een letterlijke lijst controleert de implementatie de aanwezigheid van beide vereiste flags in de laatste twee posities, zonder hun onderlinge volgorde af te dwingen.

**Meldingen en severity**

`APT package installation must disable recommends and suggests or have a tested central package exception`: `warning`. `[review] Resolve the package provider before checking APT installation options`, `[review] Resolve inherited or overridden APT package attributes in a catalog`, `[review] Verify effective APT installation options and any concrete package requirement for recommends or suggests`: elk `warning`.

**Autofix**

Geen voor alle vier meldingsvarianten.

**Autofixvoorwaarden**

Niet van toepassing: effectieve package-opties en concrete uitzonderingen vragen inhoudelijke review.

**Toegestane uitzonderingen**

Verwijderresources en expliciete niet-APT-providers vallen buiten de check. Een concrete package mag een onderbouwde afwijking nodig hebben; de check kan die beleidsuitzondering niet bewijzen.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_packages` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_packages warning -->
```puppet
package { 'synthetic': ensure => installed }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_packages` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_packages clean -->
```puppet
package { 'synthetic': ensure => installed, install_options => ['--no-install-recommends', '--no-install-suggests'] }
```

**Grensgevallen**

Verwijderresources en expliciete niet-APT-providers vallen buiten de optiecontrole. Een concrete package mag een onderbouwde afwijking nodig hebben; die beleidsuitzondering wordt niet automatisch bewezen. De optiecheck inspecteert geen effectieve ensure_packages-aanroepen. Onopgeloste providers, overerving en overrides vragen catalogusreview. Voor het samenvoegen van declaraties gelden daarnaast de afzonderlijke [voorwaarden voor packageguards](#gelijk-ingestelde-packageguards-samenvoegen). De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij APT-opties expliciet afsluiten](#verdieping-bij-apt-opties-expliciet-afsluiten).

**Handmatige review**

Controleer de effectieve provider en trailing APT-opties, inclusief overerving en overrides; onderbouw elke concrete package-uitzondering. Controleer ook de letterlijk getoonde volgorde uit de norm; een groene scan bewijst die volgorde niet.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](test/resource_contract_test.rb), [guarded_packages_test.rb](test/guarded_packages_test.rb), [guarded_packages_safety_test.rb](test/guarded_packages_safety_test.rb), [guarded_packages_fix_test.rb](test/guarded_packages_fix_test.rb), [external_guarded_packages_test.rb](test/external_guarded_packages_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij APT-opties expliciet afsluiten

`project_packages` controleert de opties met inbegrip van zichtbare lokale resourcedefaults. Verwijderresources en expliciet niet-APT-providers vallen buiten die controle. Bij een onopgeloste provider, overerving, overrides of samengestelde opties kan een `[review]`-melding volgen. Beoordeel dan de effectieve opties en de reden voor een eventuele pakketuitzondering. De check heeft geen autofix.

> **Open normconflict (oplevering: package-uitzondering):** de norm laat een onderbouwde concrete pakketuitzondering toe. De check geeft voor ontbrekende of afwijkende opties ook bij zo’n onderbouwing een warning; het profiel faalt en project_packages mag niet worden onderdrukt. De check heeft geen interface om die onderbouwing te erkennen. De norm en implementatie blijven ongewijzigd; erkenning van zo’n uitzondering bij directe resource-declaraties vraagt een afzonderlijk besluit.

> **Open normconflict (oplevering: APT-flagvolgorde):** de norm toont de afsluitende opties in de volgorde recommends, suggests. De check accepteert ook de omgekeerde volgorde. Een geïsoleerde volledige profielscan bevestigt voor beide volgorden exitcode 0 en voor een ontbrekende flag exitcode 1 met project_packages. De oorspronkelijke norm en de implementatie blijven behouden; de bedoelde onderlinge volgorde wordt niet als redactionele wijziging besloten.

#### Gelijk ingestelde packageguards samenvoegen

**Norm**

Voeg herhaalde package-declaraties met dezelfde instellingen samen met behoud van hun evaluatievolgorde, attributen en relaties. `project_guarded_packages` zoekt binnen iedere class en ieder defined type naar twee of meer `if !defined(Package['naam'])`-blokken met een gelijknamige package-resource. De expliciete attributen en waarden moeten overeenkomen; hun schrijfvolgorde telt niet mee. Iedere groep krijgt één melding bij de eerste guard, met de packagenamen in declaratievolgorde. Verschillende instellingen vormen afzonderlijke groepen. Afzonderlijke takken, lambda's, dynamische titels en enkele declaraties worden niet samengevoegd.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Gelijk ingestelde if !defined(Package)-guards binnen dezelfde class/define en hetzelfde uitvoerblok.

**Automatische controle**

`project_guarded_packages`

**Detectiegrenzen**

De optiecheck inspecteert geen effectieve ensure_packages-aanroepen. Onopgeloste providers, overerving en overrides vragen catalogusreview. De guardanalyse vergelijkt expliciete attributen; zij bewijst geen verborgen defaults, aliases of stdlib-beschikbaarheid.

**Meldingen en severity**

`Multiple guarded package declarations can be combined using ensure_packages(): {namen}`: `warning`, namen in declaratievolgorde. Onveilige groepen krijgen ` [review] Verify evaluation order, attributes, relationships and comments`; ook dit is warning.

**Autofix**

Voorwaardelijk voor aantoonbaar veilige groepen; Geen voor de variant met het [review]-suffix.

**Autofixvoorwaarden**

Alle hieronder beschreven guards, titels, expliciete ensure/attributen, scope, volgorde, breedte, comments en relatiebeperkingen zijn vereist. Stdlib moet in de Puppet-environment beschikbaar zijn. Conflicterende bestaande attributen blijven een bedoelde catalogusfout.

**Toegestane uitzonderingen**

Losse guards, verschillende branches, lambda’s, dynamische titels en verschillende expliciete instellingen worden niet samen gegroepeerd. Meerdere aanroepen kunnen noodzakelijk zijn om de evaluatievolgorde te behouden.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_guarded_packages`; verwacht warning.

<!-- lint-example: project_guarded_packages warning -->
```puppet
class example {
  if !defined(Package['alpha']) { package { 'alpha': ensure => installed } }
  if !defined(Package['zulu']) { package { 'zulu': ensure => installed } }
}
```

**Correct voorbeeld**

Fragment; alleen `project_guarded_packages`; verwacht geen melding.

<!-- lint-example: project_guarded_packages clean -->
```puppet
class example {
  ensure_packages(['alpha', 'zulu'], { 'ensure' => 'installed' })
}
```

**Grensgevallen**

Losse guards, verschillende branches en verschillende instellingen worden niet samengevoegd. De guardanalyse vergelijkt expliciete attributen; zij bewijst geen verborgen defaults, aliases of stdlib-beschikbaarheid. Beoordeel de installatieopties afzonderlijk volgens [APT-opties expliciet afsluiten](#apt-opties-expliciet-afsluiten), inclusief de concrete pakketuitzondering en de analysegrenzen voor providers, overerving, overrides en ensure_packages-aanroepen. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Gelijk ingestelde packageguards samenvoegen](#verdieping-bij-gelijk-ingestelde-packageguards-samenvoegen).

**Handmatige review**

Controleer stdlib-beschikbaarheid, bestaande packages en aliases, gelijke effectieve attributen en evaluatievolgorde. Behoud duplicate-resource-fouten bij conflicterende attributen; filter bestaande packages niet vooraf weg.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](test/resource_contract_test.rb), [guarded_packages_test.rb](test/guarded_packages_test.rb), [guarded_packages_safety_test.rb](test/guarded_packages_safety_test.rb), [guarded_packages_fix_test.rb](test/guarded_packages_fix_test.rb), [external_guarded_packages_test.rb](test/external_guarded_packages_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Gelijk ingestelde packageguards samenvoegen

Voeg herhaalde package-declaraties met dezelfde instellingen samen met behoud van hun evaluatievolgorde, attributen en relaties. `project_guarded_packages` zoekt binnen iedere class en ieder defined type naar twee of meer `if !defined(Package['naam'])`-blokken met een gelijknamige package-resource. De expliciete attributen en waarden moeten overeenkomen; hun schrijfvolgorde telt niet mee. Iedere groep krijgt één melding bij de eerste guard, met de packagenamen in declaratievolgorde. Verschillende instellingen vormen afzonderlijke groepen. Afzonderlijke takken, lambda's, dynamische titels en enkele declaraties worden niet samengevoegd.

De autofix vervangt de guards door een rechtstreekse `ensure_packages()`-aanroep. Die functie controleert bestaande packages ook op de opgegeven attributen. Bij conflicterende instellingen is een duplicate-resource-fout gewenst: zo wordt een inconsistente declaratie zichtbaar. Filter bestaande packages daarom niet vooraf uit de lijst.

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_guarded_packages` gecontroleerd.

<!-- lint-example: project_guarded_packages clean -->
```puppet
# Install system tools with consistent package settings.
ensure_packages(
  [
    'coreutils',
    'findutils',
  ],
  {
    'ensure'          => 'installed',
    'install_options' => ['--no-install-recommends', '--no-install-suggests'],
  },
)
```

Deze aanroep vereist `puppetlabs-stdlib` in de Puppet environment; de Ruby-gem installeert geen Puppet-modules. Controleer die dependency vóór het toepassen van de fix, ook in een afnemend project. De APT-opties in het voorbeeld blijven expliciet; `project_packages` controleert resource-declaraties en bepaalt niet de effectieve opties van functieaanroepen.

Autofix geldt alleen voor opeenvolgende, gewone declaraties met verschillende letterlijke packagenamen, expliciet `ensure => installed` en gelijke letterlijke attributen. Namen bestaan daarbij uit letters, cijfers, `+`, `_`, `.`, `:` of `-` en beginnen met een letter of cijfer. Een guard bevat uitsluitend de package-resource en heeft geen `else`. De omzetting behoudt de volgorde en de plaats van de eerste guard. Een gebruikt expressieresultaat, `require`, `before`, `notify`, `subscribe`, `alias`, `name`, overerving, zichtbare defaults, overrides of collectors verhindert autofix. Dat geldt ook voor tussenliggende opdrachten, commentaar in het te vervangen gedeelte, lintmarkeringen, heredocs, meerregelige attribuutwaarden en uitvoer die niet binnen de bestaande regelbreedte past. Bij twijfel blijft de hele groep staan met een `[review]`-melding; er wordt geen deel van de groep gecorrigeerd.

De check vergelijkt expliciete instellingen. Identieke dynamische expressies en groepen met aanvullende logica kunnen een reviewmelding opleveren, maar krijgen geen autofix. Beoordeel daarbij de effectieve waarden, defaults buiten het bestand, bestaande resource-aliases en het evaluatiemoment. Controleer een handmatige samenvoeging met tijdelijke catalogi: ontbrekende packages worden toegevoegd, passende bestaande declaraties worden hergebruikt en conflicterende attributen veroorzaken een fout. Behoud bij niet-opeenvolgende groepen de evaluatievolgorde; meerdere aanroepen kunnen nodig zijn. Een lintmelding bewijst op zichzelf niet dat alle overige voorwaarden voor samenvoegen zijn vervuld.

#### Mappen en bestanden in gemengde bomen apart beheren

**Norm**

Bij een gemengde boom beheer je mappen en gewone bestanden apart, zodat bestanden geen onnodige uitvoerrechten krijgen. Voor geëxporteerde applicatiebomen zijn `0750` voor mappen en `0640` voor bestanden het uitgangspunt, tenzij de applicatie aantoonbaar andere rechten nodig heeft. Een private boom zonder uitvoerbare bestanden mag recursief `0600` gebruiken; Puppet voegt dan de zoekrechten voor mappen toe. De inhoud van de boom en de gevolgen van opschonen blijven onderdeel van de handmatige review.

**Herkomst**

Projectregel

**Toepassingsgebied**

Geëxporteerde applicatiebomen, private recursieve bomen en verschillende uitvoerrechten.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Pakketten en mappen](#pakketten-en-mappen).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Aantoonbare applicatiebehoeften kunnen andere rechten vereisen. Een private boom zonder uitvoerbare bestanden mag recursief 0600 gebruiken; Puppet voegt zoekrechten aan mappen toe.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Aantoonbare applicatiebehoeften kunnen andere rechten vereisen. Een private boom zonder uitvoerbare bestanden mag recursief 0600 gebruiken; Puppet voegt zoekrechten aan mappen toe.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een gemengde applicatieboom geeft alle gewone bestanden 0750. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Beheer mappen en bestanden apart, met de genoemde uitgangspunten 0750 en 0640. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Aantoonbare applicatiebehoeften kunnen andere rechten vereisen. Een private boom zonder uitvoerbare bestanden mag recursief 0600 gebruiken; Puppet voegt zoekrechten aan mappen toe.

**Handmatige review**

Inventariseer executable-inhoud en applicatiebehoeften; controleer ook het effect van recursief opschonen.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Inventariseer executable-inhoud en applicatiebehoeften; controleer ook het effect van recursief opschonen. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Recursieve bewerkingen tot module-eigendom beperken

**Norm**

Recursieve bestandsbewerkingen vragen een andere afweging: welke inhoud is volledig eigendom van de module? Gebruik purge, force en recurse alleen voor zulke mappen. Houd `replace => false` op bestanden waarvan een installer of eenmalige initialisatie de inhoud bepaalt.

**Herkomst**

Projectregel

**Toepassingsgebied**

Mappen met purge, force of recurse en bestanden met installer-inhoud.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Pakketten en mappen](#pakketten-en-mappen).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Bestanden waarvan een installer de inhoud bepaalt blijven beschermd met replace => false.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Bestanden waarvan een installer de inhoud bepaalt blijven beschermd met replace => false.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Purge verwijdert inhoud die door de deployment wordt beheerd. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Beperk recursieve bewerkingen tot volledig module-eigendom en houd replace => false voor installer- of eenmalig geïnitialiseerde inhoud. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Bestanden waarvan een installer de inhoud bepaalt blijven beschermd met replace => false.

**Handmatige review**

Bepaal eerst de eigenaar van ieder subtree en controleer de gevolgen van opschonen.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Bepaal eerst de eigenaar van ieder subtree en controleer de gevolgen van opschonen. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Eigenaars en rechten

**Norm**

Bepaal eerst welke gebruiker een bestand tijdens uitvoering leest of schrijft en welke bovenliggende mappen daarvoor bereikbaar moeten zijn. Stel eigenaar, groep en modus expliciet in. Geef geheimen en gevoelige configuratie alleen de toegang die voor dat gebruik nodig is. De gebruikelijke uitgangspunten zijn:

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

File-resources met effectieve lokale attributen; symlinks, recursieve bomen en source/content-combinaties.

**Automatische controle**

`project_files`

**Detectiegrenzen**

`ensure => absent` wordt overgeslagen. Lokale defaults worden meegenomen; overerving/overrides vragen cataloguscontrole. Recursieve mode-analyse herkent letterlijke true en vier octale cijfers. De check bepaalt niet welke gebruiker rechten nodig heeft.

**Meldingen en severity**

`Declare effective file {attributen} explicitly`: `warning`, `{attributen}` noemt ontbrekende owner/group/mode. `[review] Resolve inherited or overridden file attributes in a catalog`: `warning` wanneer indirecte attributen het oordeel verhinderen. `[review] Recursive executable modes require proof that this tree contains only directories or executables; manage mixed trees separately`: `warning`. `[review] Prove source and content cannot both resolve to non-undef values`: `warning`.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Linux-symlinks vereisen owner en group, geen zinloze chmod-mode. Verwijderresources vereisen geen toegangsattributen. Recursieve executable modes alleen bij aantoonbaar uitsluitend mappen of executables.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_files` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_files warning -->
```puppet
file { '/tmp/synthetic': ensure => file }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_files` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_files clean -->
```puppet
file { '/tmp/synthetic': ensure => file, owner => 'root', group => 'root', mode => '0600' }
```

**Grensgevallen**

Linux-symlinks vereisen owner en group, geen zinloze chmod-mode. Verwijderresources vereisen geen toegangsattributen. Recursieve executable modes alleen bij aantoonbaar uitsluitend mappen of executables. `ensure => absent` wordt overgeslagen. Lokale defaults worden meegenomen; overerving/overrides vragen cataloguscontrole. Recursieve mode-analyse herkent letterlijke true en vier octale cijfers. De check bepaalt niet welke gebruiker rechten nodig heeft. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Eigenaars en rechten](#verdieping-bij-eigenaars-en-rechten).

**Handmatige review**

Controleer de uitvoeringsidentiteit, parent-directorytoegang, symlinkdoelen, source/content per tak, wereldleesbaarheid, groepsschrijfbaarheid en geheimen in rapporten; neem sudo, logrotate, audit en monitoring mee.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](test/resource_contract_test.rb), [shell_contract_test.rb](test/shell_contract_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Eigenaars en rechten

| Bestand of map | Gebruikelijke rechten |
| --- | --- |
| Private configuratie | `0600` |
| Script dat alleen root uitvoert | `0700` |
| Sudoersfragment | `0440` |
| Systemd-unit | `0644` waar systemd dat nodig heeft |
| Statisch terugvalbestand voor een service | Root als eigenaar, de servicegroep en `0640`; zo nodig `0710` voor bovenliggende mappen |

Bij Linux-symlinks stel je het eigenaarschap expliciet in en beveilig je het doel. Een afzonderlijke chmod-modus op de symlink biedt daar geen bruikbare bescherming.

`project_files` controleert de expliciete attributen, recursieve uitvoerrechten en uitsluiting van `source` en `content`, met inbegrip van zichtbare lokale defaults. Overerving en overrides kunnen extra cataloguscontrole vragen. De check heeft geen autofix: hij kan niet bepalen welke gebruiker toegang nodig heeft. Beoordeel zelf de effectieve rechten, de inhoud van recursieve bomen en de bereikbaarheid van bovenliggende paden.

#### Toegang via diensten en rapporten beoordelen

**Norm**

Controleer ook de toegang via sudo, logrotate, audit, monitoring en services vanuit de gebruiker die het werk uitvoert. Gebruik waar nodig `Sensitive[...]` of `Sensitive.new(...)` voor gevoelige inhoud en commando's, zodat die niet in rapporten terechtkomen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Sudo, logrotate, audit, monitoring, services en gevoelige Puppet-inhoud.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Eigenaars en rechten](#eigenaars-en-rechten).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Sensitive is geen vervanging voor toegangsrechten; de norm gebruikt het waar nodig om gevoelige rapportinhoud te beschermen.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Sensitive is geen vervanging voor toegangsrechten; de norm gebruikt het waar nodig om gevoelige rapportinhoud te beschermen.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een correct gechmod bestand is via een helper toch onleesbaar voor de uitvoerende service en een commando lekt in rapporten. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Controleer toegang vanuit de uitvoerende gebruiker en pas Sensitive toe waar gevoelige inhoud of commando’s anders worden gerapporteerd. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Sensitive is geen vervanging voor toegangsrechten; de norm gebruikt het waar nodig om gevoelige rapportinhoud te beschermen.

**Handmatige review**

Controleer elke indirecte toegangsroute en de weergave in rapporten met synthetische waarden.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer elke indirecte toegangsroute en de weergave in rapporten met synthetische waarden. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Privétoegang en uitvoerrechten onderbouwen

**Norm**

Houd SSH-homes en `.ssh` privé en geef gewone bestanden alleen uitvoerrechten als ze daadwerkelijk uitvoerbaar moeten zijn. Licht wereldleesbare of groepsschrijfbare toegang toe. Een bestand dat via HTTP openbaar is hoeft bijvoorbeeld lokaal alleen door de webserver gelezen te kunnen worden.

**Herkomst**

Projectregel

**Toepassingsgebied**

SSH-homes, .ssh en gewone bestanden met wereldleesbare of groepsschrijfbare toegang.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Eigenaars en rechten](#eigenaars-en-rechten).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. HTTP-openbaarheid bewijst geen behoefte aan lokale wereldleesbaarheid; gewone bestanden krijgen alleen benodigde uitvoerrechten.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

HTTP-openbaarheid bewijst geen behoefte aan lokale wereldleesbaarheid; gewone bestanden krijgen alleen benodigde uitvoerrechten.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een via HTTP gepubliceerd bestand is zonder noodzaak ook lokaal wereldleesbaar. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Geef lokaal alleen de benodigde toegang en licht wereldleesbare of groepsschrijfbare rechten toe. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

HTTP-openbaarheid bewijst geen behoefte aan lokale wereldleesbaarheid; gewone bestanden krijgen alleen benodigde uitvoerrechten.

**Handmatige review**

Controleer daadwerkelijke lezers en uitvoerders, privé-SSH-paden en de reden voor ieder execute-bit.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer daadwerkelijke lezers en uitvoerders, privé-SSH-paden en de reden voor ieder execute-bit. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Shellcommando's in Puppet

**Norm**

Geef dynamische Puppet-waarden als afzonderlijk voorbereide shellwoorden aan een exec-commando door. Gebruik daarvoor `stdlib::shell_escape(...)`, sla het resultaat op in een `*_shell`-variabele en voeg dat resultaat zonder extra aanhalingstekens aan het commando toe. Dit geldt ook voor de guards `onlyif` en `unless`. Een optionele guard mag `undef` zijn; de takken die een commando opleveren hebben wel veilige escaping nodig.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Dynamische command, onlyif en unless in exec-resources en zichtbare Exec-defaults; de lexicale toekenningsherkomst van hun waarden.

**Automatische controle**

`project_shell`

**Detectiegrenzen**

Een _shell-naam bewijst niets. De analyse controleert herkomst, niet de plaats van een woord in het shellcommando of de geldigheid van SQL. Shellvariabelen en parserlagen vragen aparte beoordeling.

**Meldingen en severity**

`Command data has no proven shell escaping origin; prepare dynamic words with stdlib::shell_escape before composing the command`: `warning` bij ruwe of niet bewezen commando-invoer.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een optionele guard mag undef zijn. Een volledig statisch script mag eenmaal als geheel worden ge-escapet. Voor willekeurige meerregelige invoer kan een bestand/template nodig zijn.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_shell` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_shell warning -->
```puppet
exec { 'demo': command => "/usr/bin/printf %s ${value}" }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_shell` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_shell clean -->
```puppet
$value_shell = stdlib::shell_escape($value)
exec { 'demo': command => "/usr/bin/printf %s ${value_shell}" }
```

**Grensgevallen**

Een optionele guard mag undef zijn. Een volledig statisch script mag eenmaal als geheel worden ge-escapet. Voor willekeurige meerregelige invoer kan een bestand/template nodig zijn. Een _shell-naam bewijst niets. De analyse controleert herkomst, niet de plaats van een woord in het shellcommando of de geldigheid van SQL. Shellvariabelen en parserlagen vragen aparte beoordeling. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Shellcommando's in Puppet](#verdieping-bij-shellcommandos-in-puppet).

**Handmatige review**

Volg iedere parserlaag tot het uiteindelijke argument. Test spaties, quotes, shelltekens, dollarvariabelen, substitutions, SQL-puntkomma’s en regeleinden geïsoleerd met synthetische waarden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [shell_contract_test.rb](test/shell_contract_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Shellcommando's in Puppet

`project_shell` volgt de herkomst van waarden in exec-commando's en guards. Een variabelenaam met `_shell` bewijst op zichzelf geen escaping. De check heeft geen autofix en kan ook niet bewijzen dat een veilig ge-escapet woord op de juiste plaats in het commando staat. Voer samengestelde commando's daarom geïsoleerd uit met synthetische argumenten die spaties, aanhalingstekens en shelltekens bevatten.

#### Dynamische tekst met passende uitvoer verwerken

**Norm**

Gebruik voor dynamische tekst bij voorkeur `/usr/bin/printf %s ${value_shell}`. Bewust voorbereide regeleinden kun je als letterlijke `\n` vastleggen, eenmaal escapen en met `printf %b` decoderen. Voor willekeurige gebruikers- of runtime-inhoud over meerdere regels is een bestand of template geschikt.

**Herkomst**

Projectregel

**Toepassingsgebied**

Dynamische tekst en bewust voorbereide regeleinden in execs.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Shellcommando's in Puppet](#shellcommandos-in-puppet).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Letterlijke voorbereide \n mag eenmaal ge-escapet en met %b gedecodeerd worden; dat is geen toestemming om willekeurige invoer te decoderen.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Letterlijke voorbereide \n mag eenmaal ge-escapet en met %b gedecodeerd worden; dat is geen toestemming om willekeurige invoer te decoderen.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Willekeurige runtime-inhoud wordt met printf %b geïnterpreteerd alsof alle escapes bedoeld zijn. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik bij voorkeur printf %s voor dynamische tekst; decodeer alleen bewust voorbereide regeleinden met %b. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Letterlijke voorbereide \n mag eenmaal ge-escapet en met %b gedecodeerd worden; dat is geen toestemming om willekeurige invoer te decoderen.

**Handmatige review**

Controleer de herkomst van escapes en gebruik voor willekeurige meerregelige inhoud een bestand of template.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer de herkomst van escapes en gebruik voor willekeurige meerregelige inhoud een bestand of template. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### SQL als volledige shellwaarde doorgeven

**Norm**

Voor SQL escape je de volledige SQL-string en behoud je de afsluitende puntkomma. Gebruik `provider => shell` wanneer puntkomma's of guards anders als afzonderlijke commando's worden gelezen.

**Herkomst**

Projectregel

**Toepassingsgebied**

SQL-strings in Puppet-execs en guards met shellscheiding.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Shellcommando's in Puppet](#shellcommandos-in-puppet).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. provider => shell is voor de beschreven parserbehoefte; de norm schrijft geen provider voor wanneer die behoefte ontbreekt.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

provider => shell is voor de beschreven parserbehoefte; de norm schrijft geen provider voor wanneer die behoefte ontbreekt.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een SQL-string mist de puntkomma of wordt in losse shellcommando’s gelezen. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Escape de volledige SQL-string, behoud de puntkomma en gebruik provider => shell wanneer scheiding of guards dat vereisen. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

provider => shell is voor de beschreven parserbehoefte; de norm schrijft geen provider voor wanneer die behoefte ontbreekt.

**Handmatige review**

Vergelijk het uiteindelijk gelezen SQL-argument inclusief afsluiter en controleer de bedoelde shellprovider.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Vergelijk het uiteindelijk gelezen SQL-argument inclusief afsluiter en controleer de bedoelde shellprovider. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Quoting per parserlaag toepassen

**Norm**

Quoting hoort bij de parserlaag die het argument leest. Een script dat uit ge-escapete woorden is opgebouwd, krijgt zelf nog eenmaal quoting wanneer je het als buitenste `-c`-argument doorgeeft. Escape dezelfde laag niet tweemaal. Een volledig statisch script mag eenmaal als geheel worden ge-escapet.

**Herkomst**

Projectregel

**Toepassingsgebied**

Samengestelde scripts die als argument aan een buitenste -c worden doorgegeven.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Shellcommando's in Puppet](#shellcommandos-in-puppet).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een volledig statisch script mag eenmaal als geheel worden ge-escapet; dezelfde laag wordt niet tweemaal ge-escapet.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een volledig statisch script mag eenmaal als geheel worden ge-escapet; dezelfde laag wordt niet tweemaal ge-escapet.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Veilig voorbereide woorden krijgen tweemaal escaping voor dezelfde laag. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Quote het samengestelde script nog eenmaal voor de buitenste -c-laag; behoud de afzonderlijke woordescaping. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een volledig statisch script mag eenmaal als geheel worden ge-escapet; dezelfde laag wordt niet tweemaal ge-escapet.

**Handmatige review**

Controleer per laag wat exact één argument vormt en voer synthetische spaties, quotes en shelltekens door de lagen.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer per laag wat exact één argument vormt en voer synthetische spaties, quotes en shelltekens door de lagen. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Shellsyntaxis tegen Puppet-interpolatie beschermen

**Norm**

Maak onderscheid tussen een Puppet-waarde en een variabele die de shell pas tijdens uitvoering invult. In een dubbele Puppet-string escape je die shellsyntaxis, bijvoorbeeld als `\$tmpdir`, `\$1` of `\$(...)`, zodat Puppet haar niet zelf interpreteert.

**Herkomst**

Projectregel

**Toepassingsgebied**

Dubbele Puppet-strings met variabelen en substituties die de shell moet uitvoeren.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Shellcommando's in Puppet](#shellcommandos-in-puppet).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een Puppet-waarde en een pas tijdens shelluitvoering gevulde variabele hebben verschillende eigenaars van interpolatie.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een Puppet-waarde en een pas tijdens shelluitvoering gevulde variabele hebben verschillende eigenaars van interpolatie.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Puppet interpreteert een bedoeld shellargument $1 of een shellsubstitutie. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Escape de shellsyntaxis op de Puppet-laag zoals in de norm. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een Puppet-waarde en een pas tijdens shelluitvoering gevulde variabele hebben verschillende eigenaars van interpolatie.

**Handmatige review**

Volg de string eerst door Puppet en daarna door de shell; controleer tmpdir, positieargumenten en command substitution.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Volg de string eerst door Puppet en daarna door de shell; controleer tmpdir, positieargumenten en command substitution. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Afhankelijkheden, audit en transport

<!-- lint-rule-group -->

#### Lokale integraties en runtimeafhankelijkheden kiezen

**Norm**

Gebruik voor lokale integraties bij voorkeur de bestaande modules. De runtimeafhankelijkheden zijn beperkt tot `stdlib`, `concat`, `reboot`, `timezone` en `debconf`, behalve wanneer een eis aantoonbaar niet goed lokaal kan worden ingevuld. Een externe Docker-, MySQL-, Nginx- of RabbitMQ-module toevoegen alleen vanwege vergelijkbare functies past daar niet bij. Neem bij nieuwe gevoelige onderdelen ook pakketbeleid, monitoring en audit mee in de beoordeling.

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe integraties en externe Puppet-moduledependencies.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. De beschreven uitzondering voor aantoonbaar niet goed lokaal invulbare eisen blijft bestaan; vergelijkbare functies alleen zijn onvoldoende.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

De beschreven uitzondering voor aantoonbaar niet goed lokaal invulbare eisen blijft bestaan; vergelijkbare functies alleen zijn onvoldoende.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een externe Nginx-module wordt toegevoegd uitsluitend omdat zij vergelijkbare functies heeft. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik de bestaande lokale integratie en onderbouw een uitzondering alleen met een eis die lokaal niet goed kan worden ingevuld. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

De beschreven uitzondering voor aantoonbaar niet goed lokaal invulbare eisen blijft bestaan; vergelijkbare functies alleen zijn onvoldoende.

**Handmatige review**

Vergelijk de concrete eis met bestaande lokale interfaces; neem pakketbeleid, monitoring en audit mee voor gevoelige onderdelen.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk de concrete eis met bestaande lokale interfaces; neem pakketbeleid, monitoring en audit mee voor gevoelige onderdelen. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Audituitzonderingen onderbouwen

**Norm**

Een audituitzondering bepaalt welke gebeurtenissen uit beeld verdwijnen. Leg bij een wijziging uit welk legitiem gedrag de uitzondering nodig maakt, welke events verdwijnen en waar zij geldt. Controleer naburige uitzonderingen op overlap, zodat de gezamenlijke reikwijdte duidelijk blijft.

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe of gewijzigde auditfilters en naburige uitzonderingen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een lokaal smalle uitzondering kan samen met een naburig filter breed worden; beoordeel ook die combinatie.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een lokaal smalle uitzondering kan samen met een naburig filter breed worden; beoordeel ook die combinatie.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een filter sluit gebeurtenissen uit zonder te verklaren welk legitiem gedrag dit nodig maakt. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Beschrijf legitiem gedrag, verdwenen events en toepassingsgebied en controleer overlap met naburige filters. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een lokaal smalle uitzondering kan samen met een naburig filter breed worden; beoordeel ook die combinatie.

**Handmatige review**

Vergelijk de afzonderlijke en gezamenlijke filterreikwijdte met de genoemde gebeurtenissen.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk de afzonderlijke en gezamenlijke filterreikwijdte met de genoemde gebeurtenissen. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Transportversleuteling behouden

**Norm**

Reverse proxies en verbindingen tussen services gebruiken standaard versleuteling. Alleen voor een upstream zonder TLS is HTTP een expliciete, gedocumenteerde keuze. Los certificaatproblemen op zonder de versleuteling uit te schakelen. Bij lokale of self-signed upstreams leg je vast welke keuze voor vertrouwen en verificatie nodig is.

**Herkomst**

Projectregel

**Toepassingsgebied**

Reverse proxies en verbindingen tussen services, inclusief lokale en self-signed upstreams.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. HTTP is uitsluitend een expliciete gedocumenteerde keuze voor een upstream zonder TLS; lokaal of self-signed rechtvaardigt op zichzelf geen uitschakeling.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

HTTP is uitsluitend een expliciete gedocumenteerde keuze voor een upstream zonder TLS; lokaal of self-signed rechtvaardigt op zichzelf geen uitschakeling.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een certificaatfout wordt opgelost door TLS uit te schakelen terwijl de upstream TLS ondersteunt. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Herstel vertrouwen of verificatie en behoud versleuteling. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

HTTP is uitsluitend een expliciete gedocumenteerde keuze voor een upstream zonder TLS; lokaal of self-signed rechtvaardigt op zichzelf geen uitschakeling.

**Handmatige review**

Controleer upstream-TLS-ondersteuning, gebruikte trustbron en verificatiekeuze; beoordeel de gedocumenteerde HTTP-uitzondering.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer upstream-TLS-ondersteuning, gebruikte trustbron en verificatiekeuze; beoordeel de gedocumenteerde HTTP-uitzondering. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Een minder streng beveiligingsmodel toelichten

**Norm**

Licht een minder streng vertrouwens-, rechten- of sandboxmodel bij de code toe. Als beheerders die keuze vooraf moeten kennen, hoort de uitleg ook in de project-README. Deze afwegingen vragen een inhoudelijke beveiligingsreview; de lintscan kan ze niet bewijzen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Trust, rechten en sandboxkeuzes met een minder strenge instelling.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Niet iedere lokale uitleg hoeft in de README; de beschreven noodzaak voor voorafgaande beheerderkennis bepaalt dat.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Niet iedere lokale uitleg hoeft in de README; de beschreven noodzaak voor voorafgaande beheerderkennis bepaalt dat.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een sandboxbeperking wordt verwijderd zonder lokale reden of beheerderinformatie. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Leg de noodzakelijke afwijking bij de code vast en ook in de project-README wanneer beheerders haar vooraf moeten kennen. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Niet iedere lokale uitleg hoeft in de README; de beschreven noodzaak voor voorafgaande beheerderkennis bepaalt dat.

**Handmatige review**

Lees de reden tegen het concrete servicegedrag en bepaal welke gevolgen vooraf bekend moeten zijn.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Lees de reden tegen het concrete servicegedrag en bepaal welke gevolgen vooraf bekend moeten zijn. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

### Gedeelde services en systemd

**Norm**

`basic_settings` verzorgt de gedeelde serverbasis, van pakketten en APT-bronnen tot systemd, monitoring, loginbeleid en beveiligingsgereedschap. Ook pakketonderhoud, kernel, netwerk, tijdzone en Puppet-runtimegedrag sluiten daarop aan. Integreer andere modules met deze bestaande voorzieningen.

Daarvoor zijn onder meer de bouwstenen `basic_settings::systemd_target`, `systemd_drop_in`, `systemd_service`, `systemd_timer`, `systemd_network`, `monitoring_service`, `monitoring_custom`, `monitoring_timer`, `monitoring_npm_audit`, `security_audit`, `io_logrotate` en `login_sudo` beschikbaar. Gebruik ze voor hun eigen taken, zodat featuremodules geen tweede uitvoering van die voorzieningen krijgen.

De volgende afwegingen beoordeel je bij de review en functionele validatie. Alleen backendselectie bij monitoringaanroepen heeft hier een gerichte projectcheck. De linter controleert geen volledige systemd-ordering of servicehardening.

**Herkomst**

Projectregel; deze handmatige verplichtingen maken deel uit van de bestaande codeafspraken.

**Toepassingsgebied**

Puppet-integraties met de bestaande serverbasis en gedeelde wrappers van basic_settings.

**Automatische controle**

Geen automatische controle voor dit inhoudelijke contract. De opmaakchecks en andere gedeeltelijke controles die in de norm worden genoemd vervangen deze review niet.

**Detectiegrenzen**

Puppet-lint voert geen catalogus of hostactie uit en inspecteert het beschreven runtimegedrag niet. Een groene lintscan bevestigt dit contract daarom niet.

**Meldingen en severity**

Geen lintmelding of lintseverity voor dit inhoudelijke contract; de reviewer keurt de beschreven overtreding af.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit contract vereist inhoudelijke beoordeling en heeft geen automatische correctie.

**Toegestane uitzonderingen**

Een wrapper hoort alleen bij zijn eigen taak. Het noemen van een gedeelde bouwsteen bewijst nog niet dat de prerequisite op het uitvoerpad aanwezig is.

**Suppressions**

Suppressie niet toegestaan: lintmarkeringen kunnen dit handmatige reviewcriterium niet opheffen.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een featuremodule bouwt eigen systemd-targets en monitoringregistratie voor taken die de gedeelde wrappers al afhandelen. Dit voldoet niet aan de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik de bestaande wrapper voor diens eigen taak en geef de feature-instellingen via de bestaande interface door.

**Grensgevallen**

Een wrapper hoort alleen bij zijn eigen taak. Het noemen van een gedeelde bouwsteen bewijst nog niet dat de prerequisite op het uitvoerpad aanwezig is. Controleer de afzonderlijke voorwaarden in de norm, ook wanneer de omliggende Puppet-code geen lintmelding geeft.

**Handmatige review**

Vergelijk de rol van iedere toegevoegde resource met de bestaande systemd-, monitoring-, audit-, logrotate- en sudo-bouwstenen. Valideer hun concrete lifecycle en relaties.

**Verificatie**

Handmatige beoordeling van beide bovenstaande reviewscenario’s tegen de norm: het onjuiste scenario wordt afgekeurd, het correcte scenario voldoet mits de beschreven prerequisites en uitzonderingsvoorwaarden zijn aangetoond. Bij een echte wijziging wordt de concrete functionele validatie buiten de repository uitgevoerd en in de review vastgelegd; de tooltests bewijzen geen modulegedrag.

#### Targets en monitoring

**Norm**

Laat `basic_settings::monitoring_custom` de backend kiezen. Een aanroeper mag alleen beschikbaarheid en ingeschakelde monitoring onderscheiden; een vergelijking met `none` blijft toegestaan.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Monitoringaanroepen en statisch vindbare wrappers, backendvoorwaarden, selectors/case, tussenvariabelen en doorgegeven package-parameters.

**Automatische controle**

`project_monitoring_backend`

**Detectiegrenzen**

De analyse voert geen functies uit. Dynamische wrappernamen en verborgen functiegedrag blijven review. Systemd-targetvolgorde, vendor-enablement en de inhoud van gegenereerde units hebben geen volledige automatische dekking.

**Meldingen en severity**

`Delegate backend selection to basic_settings::monitoring_custom; callers may only distinguish package 'none' from enabled monitoring`: `warning` bij selectie van een concrete backend door een aanroeper.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Vergelijking met none is toegestaan voor inschakelen en opruimen. monitoring_custom zelf kiest de backend; gewone pakketkeuzes zonder monitoringrelatie vallen buiten de check.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_monitoring_backend` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_monitoring_backend warning -->
```puppet
if $basic_settings::monitoring::package == 'openitcockpit' { basic_settings::monitoring_custom { 'demo': } }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_monitoring_backend` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_monitoring_backend clean -->
```puppet
if $basic_settings::monitoring::package != 'none' { basic_settings::monitoring_custom { 'demo': } }
```

**Grensgevallen**

Vergelijking met none is toegestaan voor inschakelen en opruimen. monitoring_custom zelf kiest de backend; gewone pakketkeuzes zonder monitoringrelatie vallen buiten de check. De analyse voert geen functies uit. Dynamische wrappernamen en verborgen functiegedrag blijven review. Systemd-targetvolgorde, vendor-enablement en de inhoud van gegenereerde units hebben geen volledige automatische dekking. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Targets en monitoring](#verdieping-bij-targets-en-monitoring).

**Handmatige review**

Controleer alle uiteindelijke unitnamen alfabetisch, wrappers, vendor-drop-ins, OnFailure, targets en agentregistraties. Valideer actieve monitoring, none en verwijderen; de voorbeeldfragmenten bewijzen geen prerequisites.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [monitoring_decisions_test.rb](test/monitoring_decisions_test.rb), [cli_flow_test.rb](test/cli_flow_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

##### Verdieping bij Targets en monitoring

`basic_settings::monitoring_custom` kiest en configureert de backend. Een aanroeper controleert alleen of monitoring beschikbaar en ingeschakeld is. Bijvoorbeeld:

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_monitoring_backend` gecontroleerd.

<!-- lint-example: project_monitoring_backend clean -->
```puppet
# Register this application's check when monitoring is enabled.
$active = $ensure == present and defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none'
if $active {
  basic_settings::monitoring_custom { 'application':
    source => 'puppet:///modules/profile/check_application',
  }
}
```

Een vergelijking met `none` is toegestaan voor het inschakelen én opruimen van registraties. Een aanroeper selecteert geen concrete backendnaam zoals `'openitcockpit'`. Dat geldt ook voor voorwaarden rond geneste aanroepen, tussenvariabelen zoals `$active`, `case`- en selectorconstructies en waarden die bijvoorbeeld `ensure` bepalen.

`project_monitoring_backend` volgt die keuzes via voorwaarden, tussenvariabelen en vindbare wrappers. Gewone pakketkeuzes zonder relatie met monitoring vallen buiten de check. De [technische naslag](#backendselectie-en-wrappers) beschrijft welke routes worden gevolgd.

De analyse voert geen Puppet-functies uit. Dynamische wrappernamen en verborgen logica in externe functies vragen daarom handmatige beoordeling. Ook correctie gebeurt handmatig: een ruimere backendvoorwaarde kan andere registraties activeren. Valideer actieve monitoring, `package => 'none'` en het verwijderen van een registratie.

#### Monitoring via het centrale agentmodel registreren

**Norm**

Monitoring sluit aan op het centrale OpenITCOCKPIT-agentmodel. Plugins staan onder `/etc/openitcockpit-agent/plugins`; `concat` en `concat::fragment` bouwen `customchecks.ini` op. Gebruik de gedeelde monitoringtypes voor de registratie van services, timers en eigen checks, zodat featuremodules die registratie niet dupliceren.

**Herkomst**

Projectregel

**Toepassingsgebied**

OpenITCOCKPIT-agentplugins, customchecks.ini en registraties van services, timers en checks.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Targets en monitoring](#targets-en-monitoring).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Deze norm laat de feitelijke backendkeuze aan monitoring_custom; aanroepers volgen de afzonderlijke backendregel.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Deze norm laat de feitelijke backendkeuze aan monitoring_custom; aanroepers volgen de afzonderlijke backendregel.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een featuremodule bouwt een tweede eigen registratiemechanisme. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik de gedeelde monitoringtypes, de bestaande pluginlocatie en concat-opbouw van customchecks.ini. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Deze norm laat de feitelijke backendkeuze aan monitoring_custom; aanroepers volgen de afzonderlijke backendregel.

**Handmatige review**

Volg de registratie en levenscyclus door de gedeelde bouwstenen; voorkom dubbele registratie in de featuremodule.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Volg de registratie en levenscyclus door de gedeelde bouwstenen; voorkom dubbele registratie in de featuremodule. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Uiteindelijke systemd-units volledig reviewen

**Norm**

Beoordeel de unit zoals die uiteindelijk op de host terechtkomt. Neem daarvoor de gegenereerde units, lokale wrappers, vendor-drop-ins, directe Service-resources, templates en statische units mee. Vermeld de beoordeelde unitnamen alfabetisch in de review.

**Herkomst**

Projectregel

**Toepassingsgebied**

Gegenereerde units, wrappers, vendor-drop-ins, Service-resources, templates en statische units.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Targets en monitoring](#targets-en-monitoring).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een gegenereerde unit is even relevant als een statisch bestand; bestandsvorm beperkt de review niet.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een gegenereerde unit is even relevant als een statisch bestand; bestandsvorm beperkt de review niet.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: De review kijkt alleen naar de template en mist een vendor-drop-in. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Beoordeel alle lagen van de uiteindelijke unit en vermeld de unitnamen alfabetisch. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een gegenereerde unit is even relevant als een statisch bestand; bestandsvorm beperkt de review niet.

**Handmatige review**

Vergelijk de effectieve unit met elke producerende bron en leg de beoordeelde namen vast.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Vergelijk de effectieve unit met elke producerende bron en leg de beoordeelde namen vast. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Gedeelde targets en service-integratie behouden

**Norm**

De gedeelde targets bepalen hoe de serveronderdelen op elkaar aansluiten. Behoud hun volgorde: `${cluster_id}-system`, `${cluster_id}-storage`, `${cluster_id}-services`, `${cluster_id}-production`, `${cluster_id}-helpers` en `${cluster_id}-require-services`. Een geïntegreerde service gebruikt de gedeelde drop-in-wrapper en bindt aan het passende target. Schakel daarbij vendor-enablement uit. Bij actieve monitoring krijgt de service `OnFailure=notify-failed@%i.service`.

**Herkomst**

Projectregel

**Toepassingsgebied**

Services met centrale targets, drop-ins, vendor-enablement en OnFailure.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Targets en monitoring](#targets-en-monitoring).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. OnFailure=notify-failed@%i.service geldt bij actieve monitoring; eigen voorwaarden blijven behouden.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

OnFailure=notify-failed@%i.service geldt bij actieve monitoring; eigen voorwaarden blijven behouden.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een geïntegreerde service houdt vendor-enablement en bindt aan een verkeerd target. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik de gedeelde drop-in-wrapper en het passende target, behoud de beschreven targetvolgorde en schakel vendor-enablement uit. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

OnFailure=notify-failed@%i.service geldt bij actieve monitoring; eigen voorwaarden blijven behouden.

**Handmatige review**

Volg system, storage, services, production, helpers en require-services; controleer bij actieve monitoring de exacte OnFailure-unit.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Volg system, storage, services, production, helpers en require-services; controleer bij actieve monitoring de exacte OnFailure-unit. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

#### Servicebeveiliging

<!-- lint-rule-group -->

#### Beveiligingsopties op de uitvoerende service zetten

**Norm**

Kies beveiligingsopties voor de concrete `.service` die het proces uitvoert. Dat geldt ook wanneer een timer, socket of path die service start. Service-uitvoeringsopties horen in de service, niet in targets, mounts, sockets, timers of de daemonconfiguratie van journald, resolved en timesyncd.

**Herkomst**

Projectregel

**Toepassingsgebied**

Services die direct of via timers, sockets of paths worden gestart.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Targets, mounts, sockets, timers en daemonconfiguratie van journald, resolved of timesyncd zijn geen vervanging voor de service-instelling.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Targets, mounts, sockets, timers en daemonconfiguratie van journald, resolved of timesyncd zijn geen vervanging voor de service-instelling.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: NoNewPrivileges wordt op de timer gezet en als bescherming van het serviceproces beschouwd. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Beoordeel en plaats de uitvoeringsoptie op de concrete .service. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Targets, mounts, sockets, timers en daemonconfiguratie van journald, resolved of timesyncd zijn geen vervanging voor de service-instelling.

**Handmatige review**

Volg het startpunt tot de uitvoerende unit en controleer waar de uitvoeringsopties terechtkomen.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Volg het startpunt tot de uitvoerende unit en controleer waar de uitvoeringsopties terechtkomen. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Servicebeperkingen tegen alle uitvoerpaden beoordelen

**Norm**

Begin de beoordeling bij de uiteindelijke unit en de Puppet-code of template die haar opbouwt. Loop daarna alle Exec-fasen na. Welke gebruikers en aanvullende groepen voeren ze uit? Zijn capabilities, sudo of setuid nodig? Controleer welke paden, bestanden, sockets en logs bereikbaar of schrijfbaar moeten zijn, inclusief tijdelijke opslag, apparaten, homes en credentials.

Neem ook netwerk- en pakketgedrag, de runtime, plugins, JIT/VM's en procesinspectie mee. Een bekende native oneshot heeft meestal minder afhankelijkheden dan provisioning, pakketbeheer, Puppet, GitLab omnibus, Certbot-hooks, SSH-sessies, monitoringexecutors, OpenITCOCKPIT of back-up- en herstelsoftware. Vooral gedeelde bestanden, apparaten en helpers die privileges wijzigen kunnen een algemene hardeningkeuze ongeschikt maken.

**Herkomst**

Projectregel

**Toepassingsgebied**

Alle Exec-fasen, procesidentiteiten, rechten, paden, netwerkgedrag en runtimes van de uiteindelijke unit.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Native oneshots en complexe provisioning-, monitoring-, back-up- of hersteldiensten hebben verschillende behoeften; de voorbeelden in de norm zijn geen automatische vrijstelling.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Native oneshots en complexe provisioning-, monitoring-, back-up- of hersteldiensten hebben verschillende behoeften; de voorbeelden in de norm zijn geen automatische vrijstelling.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een gedeelde hardeningkeuze blokkeert een hook met sudo die buiten de hoofd-Exec over het hoofd is gezien. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Inventariseer alle Exec-fasen en hun gebruikers, groepen, privilegeovergangen en toegang voordat je de beperking kiest. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Native oneshots en complexe provisioning-, monitoring-, back-up- of hersteldiensten hebben verschillende behoeften; de voorbeelden in de norm zijn geen automatische vrijstelling.

**Handmatige review**

Doorloop elk object uit de norm: paden, sockets, logs, tijdelijke opslag, apparaten, homes, credentials, netwerk, pakketten, plugins, JIT en procesinspectie.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Doorloop elk object uit de norm: paden, sockets, logs, tijdelijke opslag, apparaten, homes, credentials, netwerk, pakketten, plugins, JIT en procesinspectie. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Hardeningbesluiten per optie vastleggen

**Norm**

Leg voor iedere overwogen optie vast of je haar toepast, weglaat of nog onderzoekt, met de reden. De tabel helpt om het mogelijke effect te beoordelen. Kies een gerichte uitzondering wanneer een optie noodzakelijk servicegedrag zou blokkeren.

| Optie | Controleer vooral |
| --- | --- |
| `PrivateDevices=true` | Opslag, USB, virtualisatie/containers, RTC, GPU, seriële poorten, smartcards, tape, scanners/printers en directe netwerktoegang. |
| `PrivateTmp=true` | Bewuste communicatie via gedeelde `/tmp` of `/var/tmp`. |
| `ProtectHome=true` | Bestanden onder home/root/run-user, SSH-materiaal, webinhoud, back-ups en applicatiedata. |
| `ProtectSystem=full` | Schrijven onder `/usr`, `/boot` en `/etc` en benodigde schrijfbare uitzonderingen. |
| `SystemCallArchitectures=native` | Oude of 32-bits ABI's, Wine, QEMU-user, emulatie en compatibiliteitsworkloads. |
| `RestrictSUIDSGID=true` | Installatie, herstel, provisioning, pakketbeheer en aanmaken van SGID-mappen. |
| `LockPersonality=true` | Wijzigingen van uitvoeringsdomein of ASLR en compatibiliteitsmodi. |
| `NoNewPrivileges=true` | sudo/su/runuser/pkexec, setuid-helpers, bestandsgebonden capabilities en privilegeverhoging tijdens uitvoering. |
| `MemoryDenyWriteExecute=true` | JIT/codegeneratie, uitvoerbare stacks/trampolines, runtimepatching of -injectie, gedeeld geheugen/memfd en onbekende binaries/plugins; neem JVM, .NET, V8/Electron, LuaJIT, BEAM, WebAssembly en database-/PCRE-JIT mee. |
| `ProtectHostname=true` | Host- of domeinwijzigingen, provisioning en live gebruik van hostnamen in monitoring, inventarisatie, licenties, clustering of registratie. |
| `ProtectClock=true` | Systeem- en hardwareklokwijzigingen, RTC, tijdcorrectie en -synchronisatie, wake-alarms, planning/back-ups en VM-guesttools. |
| `ProtectControlGroups=true` | Containers/VM's, geneste servicemanagers, supervisors, resourcemeting, orkestratie en cgroup-inspectie of probleemonderzoek. |
| `ProtectKernelLogs=true` | kmsg/dmesg-toegang, verzamelaars van kernellogs en beveiligings-, monitoring- of diagnoseagents. |
| `ProtectKernelModules=true` | Laden, verwijderen en bouwen van modules, DKMS, toegang tot modulebomen en agents voor opslag, netwerk, virtualisatie, hardware of beveiliging. |
| `ProtectKernelTunables=true` | Sysctl-, firewall-, netwerk-, opslag-, energie-, hardware-, container/VM- en provisioningwijzigingen; inspectie van afgeschermde kernelgegevens onder `/proc` en `/sys`. |
| `ProtectProc=invisible` | Inspectie van processen van andere gebruikers, supervisors, monitoring, inventarisatie, beveiliging, debugging, ptrace, hostmounts van `/proc` en hidepid-ondersteuning per mount. |
| `UMask=0077` | Gedeelde of groepsleesbare bestanden, groepsschrijfbare mappen, sockets, logs, webbestanden, back-ups, overdracht via deployment- of tijdelijke bestanden en pakketgedrag dat een ander masker vereist. |

**Herkomst**

Projectregel

**Toepassingsgebied**

Iedere overwogen hardeningoptie uit de onderstaande effectentabel.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. De tabel is een beoordelingshulp, geen verplichting om iedere optie blind te activeren. Nog te onderzoeken keuzes blijven zichtbaar.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

De tabel is een beoordelingshulp, geen verplichting om iedere optie blind te activeren. Nog te onderzoeken keuzes blijven zichtbaar.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: MemoryDenyWriteExecute wordt voor een onbekende JIT-runtime zonder onderzoek geactiveerd. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Leg toepassen, weglaten of verder onderzoek met reden vast en kies een gerichte uitzondering wanneer noodzakelijk gedrag blokkeert. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

De tabel is een beoordelingshulp, geen verplichting om iedere optie blind te activeren. Nog te onderzoeken keuzes blijven zichtbaar.

**Handmatige review**

Controleer voor iedere tabelrij de genoemde functies en schrijfbare of leesbare objecten bij de concrete service; registreer besluit en bewijs.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer voor iedere tabelrij de genoemde functies en schrijfbare of leesbare objecten bij de concrete service; registreer besluit en bewijs. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Umask per service expliciet kiezen

**Norm**

Voor private uitvoer zet je `UMask=0077` expliciet in de servicespecifieke hash bij de sandboxinstellingen. Is het normale `0022`-gedrag nodig, laat de instelling dan weg. Een ander gedeeld masker, zoals `0027`, krijgt een toelichting bij de service.

**Herkomst**

Projectregel

**Toepassingsgebied**

Private en gedeelde bestanden die services aanmaken.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Bij benodigd normaal 0022-gedrag blijft de instelling weg. Een ander gedeeld masker zoals 0027 vereist een lokale toelichting.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Bij benodigd normaal 0022-gedrag blijft de instelling weg. Een ander gedeeld masker zoals 0027 vereist een lokale toelichting.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een private service vertrouwt op een verborgen generieke umask of maakt uitvoer met 0022. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Zet voor private uitvoer UMask=0077 in de servicespecifieke sandboxhash; volg de aparte regels voor 0022 en andere gedeelde maskers. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Bij benodigd normaal 0022-gedrag blijft de instelling weg. Een ander gedeeld masker zoals 0027 vereist een lokale toelichting.

**Handmatige review**

Controleer wie nieuwe bestanden, mappen, sockets en logs moet kunnen gebruiken; vergelijk die behoefte met het effectieve masker.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer wie nieuwe bestanden, mappen, sockets en logs moet kunnen gebruiken; vergelijk die behoefte met het effectieve masker. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Wrapperdefaults voor alle afnemers beoordelen

**Norm**

Beveiligingsdefaults in een generieke wrapper raken alle services die die wrapper gebruiken. Verberg daar daarom geen umask of andere beveiligingskeuze. Beoordeel bij een wijziging iedere bekende gebruiker en valideer het gedrag, of bied per service een gedocumenteerde mogelijkheid om de betreffende beperking uit te schakelen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Generieke servicewrappers en al hun bekende afnemers.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. De norm laat beoordeling en validatie van alle gebruikers of een gedocumenteerde uitschakelmogelijkheid toe; verberg de keuze niet in de wrapper.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

De norm laat beoordeling en validatie van alle gebruikers of een gedocumenteerde uitschakelmogelijkheid toe; verberg de keuze niet in de wrapper.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een wrapper krijgt stilzwijgend een restrictieve umask die bestaande gedeelde bestanden onleesbaar maakt. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Beoordeel en valideer alle bekende afnemers of bied per service een gedocumenteerde uitschakelmogelijkheid voor de beperking. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

De norm laat beoordeling en validatie van alle gebruikers of een gedocumenteerde uitschakelmogelijkheid toe; verberg de keuze niet in de wrapper.

**Handmatige review**

Zoek alle wrappergebruikers en controleer hun normale en privilegegevoelige uitvoerpaden; leg de gekozen uitzondering vast.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Zoek alle wrappergebruikers en controleer hun normale en privilegegevoelige uitvoerpaden; leg de gekozen uitzondering vast. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

### Shellscripts

<!-- lint-rule-group -->

#### Shellbron en gegenereerde shell controleren

**Norm**

De [shellconventies in `AGENTS.md`](../../AGENTS.md#shell-scripts) bepalen de opbouw, naamgeving, opmaak, commandodetectie, argumentverwerking en gegevensverwerking voor alle eigen shellcode. Gebruik ze voor POSIX shell en Bash, ook in bestanden zonder extensie, templates en inline fragmenten. De [shellvalidatie](../../AGENTS.md#shell-validation) beschrijft hoe je de bron en gegenereerde uitvoer controleert; een geslaagde Puppet-lintscan vervangt die controle niet.

**Herkomst**

Projectregel

**Toepassingsgebied**

Alle eigen POSIX- en Bash-code, inclusief extensionless scripts, templates en inline fragmenten.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een .pp-bestand kan shellcode bevatten; een geslaagde Puppet-scan valideert die gegenereerde shell niet.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een .pp-bestand kan shellcode bevatten; een geslaagde Puppet-scan valideert die gegenereerde shell niet.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een shelltemplate wordt alleen met Puppet-lint gecontroleerd. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Beoordeel bron en gerenderde uitvoer met de genoemde shellconventies en shellvalidatie. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een .pp-bestand kan shellcode bevatten; een geslaagde Puppet-scan valideert die gegenereerde shell niet.

**Handmatige review**

Controleer interpreter, opbouw, naamgeving, inspringing, commandodetectie, argumentverwerking en gegevensverwerking volgens de gekoppelde afspraken.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer interpreter, opbouw, naamgeving, inspringing, commandodetectie, argumentverwerking en gegevensverwerking volgens de gekoppelde afspraken. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Runtime-tools op hun functie beoordelen

**Norm**

Beoordeel externe tools volgens de [afspraken over native tools en dependencies](../../AGENTS.md#native-tools-and-dependencies). Gebruik voor eenvoudige controles bij voorkeur shellfunctionaliteit of de uitvoer en exitcode van het oorspronkelijke commando. Een parser zoals `jq` blijft geschikt voor complexe gestructureerde gegevens. Neem bij het verwijderen van een tool ook de pakketinstallatie en andere afnemers mee, en toets volgens de shellvalidatie of het gedrag gelijk blijft. Deze afweging vraagt handmatige review; Puppet-lint bepaalt niet of een runtime-tool functioneel nodig is.

**Herkomst**

Projectregel

**Toepassingsgebied**

Toevoegen, vervangen en verwijderen van shelltools en bijbehorende pakketten.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. jq blijft geschikt bij complexe structuren; het voorkeurspad voor eenvoudige controles is geen verbod op een noodzakelijke parser.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

jq blijft geschikt bij complexe structuren; het voorkeurspad voor eenvoudige controles is geen verbod op een noodzakelijke parser.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een noodzakelijke gestructureerde parser wordt verwijderd uitsluitend om één dependency te besparen. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik native uitvoer voor eenvoudige controles en behoud een parser voor complexe gestructureerde gegevens; controleer alle packageafnemers. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

jq blijft geschikt bij complexe structuren; het voorkeurspad voor eenvoudige controles is geen verbod op een noodzakelijke parser.

**Handmatige review**

Vergelijk output, fouten en exitcodes voor en na vervanging volgens de shellvalidatie en controleer alle resterende consumenten.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk output, fouten en exitcodes voor en na vervanging volgens de shellvalidatie en controleer alle resterende consumenten. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Puppet-waarden rechtstreeks in shelltemplates invoegen

**Norm**

Voor waarden die Puppet in een shelltemplate invoegt, gebruik je ERB met directe shelltoekenningen. Beperk ERB tot het invoegen van waarden; de voorbereiding in Puppet bestaat uit defaults voor beheerde configuratie, serialisatie en shellveilige argumenten. Volg daarbij de afspraken voor [templates](#templates-en-bestandsbronnen) en [shellcommando's in Puppet](#shellcommandos-in-puppet). Voeg alleen een afzonderlijk configuratiebestand of een parser toe wanneer dat is gevraagd of al gebruikelijk is.

**Herkomst**

Projectregel

**Toepassingsgebied**

Puppet-voorbereiding en ERB-shelltemplates met beheerde configuratiewaarden.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een afzonderlijk configuratiebestand of parser wordt alleen toegevoegd wanneer dat is gevraagd of al gebruikelijk is.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een afzonderlijk configuratiebestand of parser wordt alleen toegevoegd wanneer dat is gevraagd of al gebruikelijk is.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een nieuwe parser en configuratielaag worden toegevoegd voor alleen een voorbereide shellwaarde. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik ERB met directe shelltoekenningen en beperk Puppet-voorbereiding tot de beschreven defaults, serialisatie en escaping. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een afzonderlijk configuratiebestand of parser wordt alleen toegevoegd wanneer dat is gevraagd of al gebruikelijk is.

**Handmatige review**

Controleer iedere ingevoegde waarde en de parserlaag die haar leest; vergelijk benodigde uitvoer met de template.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer iedere ingevoegde waarde en de parserlaag die haar leest; vergelijk benodigde uitvoer met de template. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Daemonconfiguratie als invoerbron behouden

**Norm**

Behoud volgens de [invoerafspraken](../../AGENTS.md#arguments-and-runtime-settings) de bestaande invoerroute voor daemonconfiguratie en inloggegevens. Lees waar mogelijk de effectieve daemonconfiguratie, bijvoorbeeld met `vnstat --showconfig`, zodat je geen tweede instellingen of sysfs-terugvalroutes hoeft te onderhouden.

**Herkomst**

Projectregel

**Toepassingsgebied**

Bestaande daemonconfiguratie en credentialinterfaces van shellhelpers.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Effectieve configuratie uitlezen is waar mogelijk het voorkeurspad; het voorbeeld vnstat --showconfig introduceert geen verplichte tool voor andere daemons.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Effectieve configuratie uitlezen is waar mogelijk het voorkeurspad; het voorbeeld vnstat --showconfig introduceert geen verplichte tool voor andere daemons.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een script dupliceert daemoninstellingen via nieuwe CLI-opties en een tweede fallbackketen. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Behoud de bestaande invoerroute en lees waar mogelijk de effectieve daemonconfiguratie. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Effectieve configuratie uitlezen is waar mogelijk het voorkeurspad; het voorbeeld vnstat --showconfig introduceert geen verplichte tool voor andere daemons.

**Handmatige review**

Vergelijk de gelezen waarde met de effectieve daemoninstelling en controleer dat credentials hun bestaande interface behouden.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk de gelezen waarde met de effectieve daemoninstelling en controleer dat credentials hun bestaande interface behouden. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

### Monitoringchecks

**Norm**

Checks volgen de algemene [shellconventies](../../AGENTS.md#shell-scripts) en gebruiken POSIX `#!/bin/sh` met Nagios-exitcodes. De aanvullende [monitoringcontracten](../../AGENTS.md#monitoring-checks) regelen gedeelde executables, instellingen per target en de levenscyclus van registraties. Beoordeel status, ernst, parsing, buffering en perfdata ook tegen de hieronder beschreven uitvoercontracten. Lange uitvoer staat standaard aan; een schakelaar daarvoor wordt alleen op verzoek toegevoegd.

**Herkomst**

Projectregel; deze handmatige verplichtingen maken deel uit van de bestaande codeafspraken.

**Toepassingsgebied**

Gedeelde checkexecutables, targetregistraties en de shell-/Nagios-uitvoerinterface.

**Automatische controle**

Geen automatische controle voor dit inhoudelijke contract. De opmaakchecks en andere gedeeltelijke controles die in de norm worden genoemd vervangen deze review niet.

**Detectiegrenzen**

Puppet-lint voert geen catalogus of hostactie uit en inspecteert het beschreven runtimegedrag niet. Een groene lintscan bevestigt dit contract daarom niet.

**Meldingen en severity**

Geen lintmelding of lintseverity voor dit inhoudelijke contract; de reviewer keurt de beschreven overtreding af.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit contract vereist inhoudelijke beoordeling en heeft geen automatische correctie.

**Toegestane uitzonderingen**

Een schakelaar voor lange uitvoer wordt alleen op verzoek toegevoegd; lange uitvoer staat standaard aan.

**Suppressions**

Suppressie niet toegestaan: lintmarkeringen kunnen dit handmatige reviewcriterium niet opheffen.

**Onjuist voorbeeld**

Handmatig reviewscenario: Per target wordt hetzelfde executable opnieuw gegenereerd en het verwijderen van één target verwijdert daarmee ook de check van andere targets. Dit voldoet niet aan de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Beheer één gedeeld executable onafhankelijk van registraties en geef targetwaarden via de bestaande runtime-interface door.

**Grensgevallen**

Een schakelaar voor lange uitvoer wordt alleen op verzoek toegevoegd; lange uitvoer staat standaard aan. Controleer de afzonderlijke voorwaarden in de norm, ook wanneer de omliggende Puppet-code geen lintmelding geeft.

**Handmatige review**

Controleer twee verschillende registraties en verwijder één target; het executable en de andere registratie blijven bestaan. Beoordeel daarnaast shellsyntax, exitcodes, perfdata en begrensde lange uitvoer.

**Verificatie**

Handmatige beoordeling van beide bovenstaande reviewscenario’s tegen de norm: het onjuiste scenario wordt afgekeurd, het correcte scenario voldoet mits de beschreven prerequisites en uitzonderingsvoorwaarden zijn aangetoond. Bij een echte wijziging wordt de concrete functionele validatie buiten de repository uitgevoerd en in de review vastgelegd; de tooltests bewijzen geen modulegedrag.

#### Packages voor externe commando's

**Norm**

Borg bij iedere monitoringcheck expliciet de packages die zijn externe commando's leveren. Ga er niet van uit dat `basic_settings`, een andere class of de basisinstallatie die packages meeneemt. De check moet bruikbaar zijn met alleen de benodigde module en `basic_settings::monitoring`.

De enige uitzondering voor een benodigd executable is de Puppet/OpenVox-agent zelf: die is al geïnstalleerd om de catalogus toe te passen. De Puppet-agentcheck hergebruikt diens `puppet`-commando; voeg hiervoor geen agentpackage, packagekeuzeparameter of package-`require` toe. Alle overige hulppackages van deze check blijven expliciet geborgd.

Inventariseer het hele script, inclusief de interpreter, pipelines, command substitutions, vaste executablepaden en conditionele uitvoerpaden. Maak onderscheid tussen shell-builtins, lokale functies en externe executables. Controleer de leverancier van ieder benodigd executable voor de ondersteunde Debian/Ubuntu-versies; `awk` heeft bijvoorbeeld meerdere providers en `cmp` komt uit `diffutils`. Een bewust optionele tool met een werkende terugvalroute hoeft geen verplichte package te worden. Leg die terugvalroute vast in de review.

Beheer ontbrekende packages bij de eigenaar van het gedeelde executable met `ensure_packages`, en groepeer packages met gelijke instellingen volgens [pakketten en mappen](#pakketten-en-mappen). Gebruik alleen daadwerkelijk benodigde packages. Een bestaande installatie in dezelfde module of een verplichte parentclass mag de garantie leveren als die op ieder relevant uitvoerpad actief is. Ook een verplichte package-afhankelijkheid kan volstaan, mits je de dependencyketen voor de ondersteunde pakketbronnen controleert. Een aanbeveling, toevallige classdeclaratie of aanwezig executable op de testserver is geen garantie.

Laat de monitoringresource via `require` wachten op de packages die de check gebruikt. Bij gedeelde bestanden moeten ook de registraties via het executable op die packages wachten. Gebruik voor een bewust afzonderlijk beheerde applicatie-installatie de bestaande installatieresource en behoud de bijbehorende voorwaarden. Controleer providers en installatievolgorde: bijvoorbeeld NodeSource levert npm in `nodejs`, terwijl Debian en Ubuntu een afzonderlijk `npm`-package leveren.

Dit is een verplicht reviewpunt. Leg per check de commando's, providers, installatiegaranties en relaties vast. Valideer catalogi zonder de hoofdclass `basic_settings`, met benodigde packages vooraf wel en niet gedeclareerd, met monitoring uitgeschakeld en met meerdere registraties waarvan er één wordt verwijderd. Controleer conditionele providers ook met de relevante declaratievolgorde.

De bestaande checks `project_packages`, `project_guarded_packages` en `project_resource_references` helpen met package-opties, groepering en references. Ze bewijzen niet dat een shellscript alle runtimepackages krijgt: `project_packages` inspecteert package-resources, geen effectieve `ensure_packages`-aanroepen; `project_shell` controleert escaping in Puppet-execs. Een betrouwbare volledigheidscontrole zou scripts, templates, providers en conditionele installatiepaden moeten koppelen. Die package-analyse blijft daarom handmatige review; de linter raadt geen Debian-packages bij willekeurige commandonamen.

**Herkomst**

Projectregel; deze handmatige verplichtingen maken deel uit van de bestaande codeafspraken.

**Toepassingsgebied**

Externe commando’s in gedeelde monitoringexecutables en de Puppet-packagegaranties, registraties en uitvoerrelaties die hen ondersteunen.

**Automatische controle**

Geen automatische controle voor dit inhoudelijke contract. De opmaakchecks en andere gedeeltelijke controles die in de norm worden genoemd vervangen deze review niet.

**Detectiegrenzen**

Puppet-lint voert geen catalogus of hostactie uit en inspecteert het beschreven runtimegedrag niet. Een groene lintscan bevestigt dit contract daarom niet.

**Meldingen en severity**

Geen lintmelding of lintseverity voor dit inhoudelijke contract; de reviewer keurt de beschreven overtreding af.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit contract vereist inhoudelijke beoordeling en heeft geen automatische correctie.

**Toegestane uitzonderingen**

De reeds benodigde Puppet/OpenVox-agent is de enige executable-uitzondering. Een bewust optionele tool met geteste terugvalroute is geen verplichte dependency. Een verplichte parentclass of gecontroleerde package-dependencyketen mag de garantie leveren.

**Suppressions**

Suppressie niet toegestaan: lintmarkeringen kunnen dit handmatige reviewcriterium niet opheffen.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een check gebruikt cmp maar declareert geen diffutils en vertrouwt op de toevallige aanwezigheid via basic_settings. Dit voldoet niet aan de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Borg het package bij de eigenaar van het gedeelde executable en laat de registraties via dat executable op de package-installatie wachten.

**Grensgevallen**

De reeds benodigde Puppet/OpenVox-agent is de enige executable-uitzondering. Een bewust optionele tool met geteste terugvalroute is geen verplichte dependency. Een verplichte parentclass of gecontroleerde package-dependencyketen mag de garantie leveren. Controleer de afzonderlijke voorwaarden in de norm, ook wanneer de omliggende Puppet-code geen lintmelding geeft.

**Handmatige review**

Inventariseer interpreter, pipelines, substitutions, vaste paden en conditionele branches. Controleer Debian/Ubuntu-providers en verplichte dependencyketens; valideer zonder basic_settings, met packages vooraf aanwezig/afwezig, monitoring uit en twee registraties waarvan één vervalt.

**Verificatie**

Handmatige beoordeling van beide bovenstaande reviewscenario’s tegen de norm: het onjuiste scenario wordt afgekeurd, het correcte scenario voldoet mits de beschreven prerequisites en uitzonderingsvoorwaarden zijn aangetoond. Bij een echte wijziging wordt de concrete functionele validatie buiten de repository uitgevoerd en in de review vastgelegd; de tooltests bewijzen geen modulegedrag.

#### Invoer en configuratie

<!-- lint-rule-group -->

#### Optionele monitoringdefaults in het executable houden

**Norm**

Een monitoringcheck heeft zijn optionele runtime-defaults in het executable. Puppet geeft alleen instellingen door die expliciet zijn ingevuld. Gebruik voor zulke Puppet-parameters een passend `Optional[...]` met `undef` als default. Bij `undef` laat de registratie zowel de CLI-optie als het argument weg. Zo ontstaan er geen tweede defaults in manifests, wrappers of ERB-expressies. Pas dit toe op nieuwe instellingen en bij wijzigingen aan bestaande defaultverwerking.

**Herkomst**

Projectregel

**Toepassingsgebied**

Optionele runtime-instellingen in Puppet-registraties, wrappers en ERB.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Pas de norm toe op nieuwe instellingen en wijzigingen aan bestaande defaultverwerking; dit is geen opdracht om ongeraakte interfaces te veranderen.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Pas de norm toe op nieuwe instellingen en wijzigingen aan bestaande defaultverwerking; dit is geen opdracht om ongeraakte interfaces te veranderen.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een registratie geeft een tweede default als CLI-argument door wanneer de Puppet-parameter undef is. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik Optional met default undef en laat bij undef zowel optie als argument weg. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Pas de norm toe op nieuwe instellingen en wijzigingen aan bestaande defaultverwerking; dit is geen opdracht om ongeraakte interfaces te veranderen.

**Handmatige review**

Volg default, override en lege registratie door manifest, wrapper en executable; controleer dat alleen expliciete overrides worden doorgegeven.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Volg default, override en lege registratie door manifest, wrapper en executable; controleer dat alleen expliciete overrides worden doorgegeven. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Effectieve monitoringinvoer volgens het configuratiecontract valideren

**Norm**

De check verwerkt commandline-opties, omgevingsvariabelen en defaults volgens het [configuratiecontract in `AGENTS.md`](../../AGENTS.md#monitoring-check-configuration), dat de algemene invoer- en validatieregels aanvult. Puppet mag twee expliciet opgegeven drempels alvast vergelijken, maar neemt daarvoor geen ontbrekende scriptdefault over.

**Herkomst**

Projectregel

**Toepassingsgebied**

CLI-, environment- en standaardwaarden van monitoringchecks en Puppet-drempelvergelijkingen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Puppet mag twee expliciete drempels vergelijken; daarmee verhuist de validatie van effectieve scriptwaarden niet naar Puppet.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Puppet mag twee expliciete drempels vergelijken; daarmee verhuist de validatie van effectieve scriptwaarden niet naar Puppet.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Puppet vult een ontbrekende scriptdefault in om twee drempels te vergelijken. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Laat de check de effectieve waarden verwerken en valideren; vergelijk in Puppet hoogstens twee expliciet opgegeven drempels. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Puppet mag twee expliciete drempels vergelijken; daarmee verhuist de validatie van effectieve scriptwaarden niet naar Puppet.

**Handmatige review**

Controleer de volgorde van invoerbronnen en toets alleen werkelijk ingevulde Puppet-waarden zonder scriptdefaults te dupliceren.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer de volgorde van invoerbronnen en toets alleen werkelijk ingevulde Puppet-waarden zonder scriptdefaults te dupliceren. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Agentplanning afzonderlijk afstemmen

**Norm**

Het uitvoerinterval en de timeout van de monitoringagent horen bij de registratie. Een scriptoptie of omgevingsvariabele verandert die agentinstellingen niet. Controleer hun samenhang volgens de [afspraken voor de executor](../../AGENTS.md#executor-scheduling).

**Herkomst**

Projectregel

**Toepassingsgebied**

Registratie-interval en executor-timeout naast runtime-opties van het script.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een scriptoptie of environmentvariabele verandert de agentplanning niet.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een scriptoptie of environmentvariabele verandert de agentplanning niet.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een langere script-timeout wordt ingesteld terwijl de agent het proces eerder afbreekt. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Stem interval en agent-timeout afzonderlijk af volgens de executorafspraken. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een scriptoptie of environmentvariabele verandert de agentplanning niet.

**Handmatige review**

Vergelijk de scriptuitvoering, beëindiging en outputbudget met de toegestane executortijd.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk de scriptuitvoering, beëindiging en outputbudget met de toegestane executortijd. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Uitvoer voor beheerders

<!-- lint-rule-group -->

#### Een bruikbare eerste uitvoerregel schrijven

**Norm**

De eerste uitvoerregel vertelt wat er wordt gecontroleerd en wat de beheerder ermee moet. Noem de service, unit, module, interface of resource. Bij een fout of onduidelijke uitkomst horen daar het belangrijkste geraakte object, de directe oorzaak en een indicatie van benodigde escalatie bij. Een gezonde check meldt dat het onderdeel normaal werkt.

**Herkomst**

Projectregel

**Toepassingsgebied**

Eerste uitvoerregel bij gezond, fout en onbekend resultaat.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een gezonde check hoeft geen foutoorzaak te noemen; haar samenvatting bevestigt normaal functioneren.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een gezonde check hoeft geen foutoorzaak te noemen; haar samenvatting bevestigt normaal functioneren.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een foutmelding noemt geen geraakt object of directe oorzaak. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Noem het gecontroleerde onderdeel, belangrijkste object, oorzaak en benodigde escalatie; meld bij gezond resultaat normaal functioneren. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een gezonde check hoeft geen foutoorzaak te noemen; haar samenvatting bevestigt normaal functioneren.

**Handmatige review**

Beoordeel of een beheerder uit alleen de eerste regel kan bepalen wat wordt gecontroleerd en welke actie nodig is.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Beoordeel of een beheerder uit alleen de eerste regel kan bepalen wat wordt gecontroleerd en welke actie nodig is. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Status en technische tellers buiten de samenvatting houden

**Norm**

De machinestatus staat in de exitcode. Begin de tekst daarom niet met een Nagios-statuswoord en gebruik die statusnamen ook niet als labels voor oorzakenlijsten. Houd de eerste regel vrij van nulcategorieën, overzichten van drempels, interne beslislabels en perfdata-achtige fragmenten. Tellers kunnen in perfdata of de lange uitvoer staan.

**Herkomst**

Projectregel

**Toepassingsgebied**

Samenvatting en oorzakenlabels naast Nagios-exitcode en perfdata.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Tellers blijven toegestaan in perfdata en lange uitvoer; de norm beperkt hun plaats.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Tellers blijven toegestaan in perfdata en lange uitvoer; de norm beperkt hun plaats.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: De tekst begint met CRITICAL en bevat nulcategorieën en een drempeloverzicht. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Laat de exitcode de status dragen en verplaats tellers naar perfdata of lange uitvoer. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Tellers blijven toegestaan in perfdata en lange uitvoer; de norm beperkt hun plaats.

**Handmatige review**

Controleer de eerste regel en oorzakenlabels op statuswoorden, nulcategorieën, drempels, interne labels en perfdata-achtige fragmenten.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer de eerste regel en oorzakenlabels op statuswoorden, nulcategorieën, drempels, interne labels en perfdata-achtige fragmenten. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Oorzaak en reikwijdte in de diagnose onderscheiden

**Norm**

Maak in de diagnose duidelijk of het gaat om een configuratiefout, runtimefout, contextuele waarschuwing of onbekende toestand. Heeft de check bewust een beperkte reikwijdte, vermeld die dan. Informatie daarbuiten mag de exitcode niet veranderen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Configuratiefouten, runtimefouten, contextuele waarschuwingen en onbekende toestand.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een bewust beperkte reikwijdte blijft toegestaan mits zichtbaar; informatie daarbuiten mag de status niet wijzigen.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een bewust beperkte reikwijdte blijft toegestaan mits zichtbaar; informatie daarbuiten mag de status niet wijzigen.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een check met beperkte reikwijdte wijzigt zijn exitcode door informatie buiten die reikwijdte. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Vermeld de grens en baseer de exitcode op informatie binnen het vastgestelde bereik. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een bewust beperkte reikwijdte blijft toegestaan mits zichtbaar; informatie daarbuiten mag de status niet wijzigen.

**Handmatige review**

Koppel iedere statusbepalende waarneming aan het gecontroleerde bereik en onderscheid de vier beschreven oorzaakcategorieën.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Koppel iedere statusbepalende waarneming aan het gecontroleerde bereik en onderscheid de vier beschreven oorzaakcategorieën. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### De hoofdoorzaak vooraan in lange uitvoer zetten

**Norm**

Zet in de lange uitvoer de belangrijkste diagnose vooraan. Beschrijf het betrokken onderdeel, wat is waargenomen, de waarschijnlijke oorzaak en een bruikbare vervolgstap of escalatieroute. Verberg de hoofdoorzaak niet tussen details en neem daar geen drempelwaarden op.

**Herkomst**

Projectregel

**Toepassingsgebied**

Volgorde en inhoud van lange diagnoses.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Details mogen volgen, maar verbergen de belangrijkste diagnose niet.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Details mogen volgen, maar verbergen de belangrijkste diagnose niet.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: De directe oorzaak staat onder details en drempelwaarden zonder vervolgstap. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Begin met onderdeel, waarneming, waarschijnlijke oorzaak en vervolgstap of escalatie. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Details mogen volgen, maar verbergen de belangrijkste diagnose niet.

**Handmatige review**

Lees de diagnose in afgedrukte volgorde; controleer dat de hoofdoorzaak vooraan staat en drempelwaarden daar ontbreken.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Lees de diagnose in afgedrukte volgorde; controleer dat de hoofdoorzaak vooraan staat en drempelwaarden daar ontbreken. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Lange uitvoer afsluiten met interpretatie

**Norm**

Sluit niet-triviale lange uitvoer af met `Interpretation:`. Leg daarin uit hoe de getoonde gegevens, reikwijdte en context gelezen moeten worden. De perfdata hoeft daar niet nogmaals te worden opgesomd.

**Herkomst**

Projectregel

**Toepassingsgebied**

Niet-triviale lange uitvoer en de afsluitende Interpretation-sectie.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. De verplichting betreft niet-triviale lange uitvoer; een triviale uitvoer vraagt geen opvulsectie.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

De verplichting betreft niet-triviale lange uitvoer; een triviale uitvoer vraagt geen opvulsectie.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een lange diagnose eindigt met losse tellers zonder uitleg over bereik en context. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Sluit af met Interpretation: en leg uit hoe gegevens, reikwijdte en context gelezen moeten worden. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

De verplichting betreft niet-triviale lange uitvoer; een triviale uitvoer vraagt geen opvulsectie.

**Handmatige review**

Controleer de laatste sectie op betekenis en vervolginformatie zonder perfdata opnieuw op te sommen.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer de laatste sectie op betekenis en vervolginformatie zonder perfdata opnieuw op te sommen. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Veilige en begrensde uitvoer

<!-- lint-rule-group -->

#### Uitvoer alleen bij aantoonbare noodzaak normaliseren

**Norm**

Volg eerst de uitvoerroute van de check voordat je normalisatie toevoegt. Vaste, veilige tekst hoeft niet te worden bewerkt. Normalisatie is nodig wanneer runtimegegevens, externe data of bewuste scheidingen onveilige pipes of ongewenste lege regels kunnen opleveren. Licht een niet-vanzelfsprekende bewerking bij de code toe.

**Herkomst**

Projectregel

**Toepassingsgebied**

Vaste tekst, runtimegegevens, externe data en bewuste uitvoerscheidingen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Vaste veilige tekst hoeft niet te worden bewerkt; dynamische data kan wel normalisatie vereisen.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Vaste veilige tekst hoeft niet te worden bewerkt; dynamische data kan wel normalisatie vereisen.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Vaste veilige tekst krijgt een extra normalisatiepijplijn zonder risico dat zij oplost. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Volg de data naar de uitvoer en normaliseer wanneer onveilige pipes of ongewenste lege regels kunnen ontstaan. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Vaste veilige tekst hoeft niet te worden bewerkt; dynamische data kan wel normalisatie vereisen.

**Handmatige review**

Identificeer per bewerking de onveilige bron en het effect; licht niet-vanzelfsprekende normalisatie bij de code toe.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Identificeer per bewerking de onveilige bron en het effect; licht niet-vanzelfsprekende normalisatie bij de code toe. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Pipes en lege regels in lange uitvoer veilig maken

**Norm**

Nagios kan tekst na een pipe ook op vervolgregels als perfdata lezen. Maak ruwe `|`-tekens daarom veilig zodra dynamische data in de lange uitvoer wordt opgenomen. Begin en eindig zonder lege regels en zet één lege regel tussen afzonderlijke secties; opeenvolgende lege regels zijn niet toegestaan.

**Herkomst**

Projectregel

**Toepassingsgebied**

Dynamische data op alle regels van lange Nagios-uitvoer.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Ook pipes op vervolgregels kunnen perfdata openen; de bescherming geldt voor het volledige lange uitvoerkanaal.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Ook pipes op vervolgregels kunnen perfdata openen; de bescherming geldt voor het volledige lange uitvoerkanaal.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een logregel met een ruwe pipe wordt als vervolgtekst afgedrukt en kan als perfdata worden gelezen. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Maak de pipe veilig bij opname en gebruik precies één lege regel tussen secties, zonder begin- of eindlege regel. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Ook pipes op vervolgregels kunnen perfdata openen; de bescherming geldt voor het volledige lange uitvoerkanaal.

**Handmatige review**

Controleer data met pipes op de eerste en volgende regels en controleer opeenvolgende, leidende en afsluitende lege regels.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer data met pipes op de eerste en volgende regels en controleer opeenvolgende, leidende en afsluitende lege regels. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Eén afkapmechanisme per diagnoseblok gebruiken

**Norm**

Gebruik per diagnoseblok één configureerbare manier van afkappen. Het stapelen van item-, regel-, blok- en tekenlimieten op dezelfde verzameling maakt onduidelijk welke informatie wordt getoond. Een ander uitvoerkanaal mag een eigen limiet hebben wanneer het niet dezelfde gegevens afkapt.

**Herkomst**

Projectregel

**Toepassingsgebied**

Configureerbare item-, regel-, blok- en tekenlimieten op diagnoseverzamelingen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een ander uitvoerkanaal mag een eigen limiet hebben wanneer die niet dezelfde gegevens afkapt.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een ander uitvoerkanaal mag een eigen limiet hebben wanneer die niet dezelfde gegevens afkapt.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Dezelfde verzameling wordt na elkaar door een itemlimiet, regellimiet en tekenlimiet afgeknipt. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Kies per diagnoseblok één configureerbare afkapmethode. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een ander uitvoerkanaal mag een eigen limiet hebben wanneer die niet dezelfde gegevens afkapt.

**Handmatige review**

Volg ieder verzameld item door alle limieten en bepaal welke informatie iedere afkapstap verwijdert.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Volg ieder verzameld item door alle limieten en bepaal welke informatie iedere afkapstap verwijdert. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Interpretatie zichtbaar houden bij een UI-limiet

**Norm**

Bij een relevante UI-limiet begrens je het totale aantal tekens boven `Interpretation:`. Zet de afkapmelding vóór die laatste uitleg, zodat de interpretatie en vervolgstap zichtbaar blijven.

**Herkomst**

Projectregel

**Toepassingsgebied**

Totale tekenlimiet van lange uitvoer boven Interpretation.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Deze totale begrenzing geldt bij een relevante UI-limiet; zij rechtvaardigt geen willekeurige extra limieten op dezelfde verzameling.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Deze totale begrenzing geldt bij een relevante UI-limiet; zij rechtvaardigt geen willekeurige extra limieten op dezelfde verzameling.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een UI-limiet kapt de interpretatie en vervolgstap af. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Begrens de tekst boven Interpretation: en zet de afkapmelding vóór die laatste uitleg. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Deze totale begrenzing geldt bij een relevante UI-limiet; zij rechtvaardigt geen willekeurige extra limieten op dezelfde verzameling.

**Handmatige review**

Controleer de uitvoer bij de exacte grens en bij overschrijding; behoud afkapmelding, interpretatie en vervolgstap.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer de uitvoer bij de exacte grens en bij overschrijding; behoud afkapmelding, interpretatie en vervolgstap. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Werkbegrenzing van tekstbegrenzing onderscheiden

**Norm**

Een limiet op gegevensverzameling heeft een ander doel dan een limiet op de uiteindelijke tekst. APT-ophaal-, groeps- en tijdslimieten of een journalvenster begrenzen het externe werk en de invoer. Ze begrenzen niet de diagnose die al is verzameld. Leg dat onderscheid uit en behoud zichtbare meldingen wanneer uitvoer wordt afgekort.

**Herkomst**

Projectregel

**Toepassingsgebied**

APT-ophaal-, groeps- en tijdslimieten, journalvensters en afkappen van verzamelde diagnose.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een invoerlimiet mag bestaan naast een tekstlimiet omdat zij een ander doel heeft; maak dat doel expliciet.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een invoerlimiet mag bestaan naast een tekstlimiet omdat zij een ander doel heeft; maak dat doel expliciet.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een journalvenster wordt beschreven alsof het de lengte van reeds verzamelde diagnoses begrenst. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Documenteer afzonderlijk welk extern werk wordt begrensd en welke uitvoer wordt ingekort. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een invoerlimiet mag bestaan naast een tekstlimiet omdat zij een ander doel heeft; maak dat doel expliciet.

**Handmatige review**

Controleer de plaats van de grens vóór of na verzameling en behoud zichtbare meldingen bij afgekorte uitvoer.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer de plaats van de grens vóór of na verzameling en behoud zichtbare meldingen bij afgekorte uitvoer. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Perfdata en compatibiliteit

<!-- lint-rule-group -->

#### Perfdatakeys en eenheden stabiel vormgeven

**Norm**

Gebruik compacte, stabiele snake_case-labels die met een kleine letter beginnen en verder alleen kleine letters, cijfers en underscores bevatten. De eenheid hoort in het UOM-veld, bijvoorbeeld `%`, `B`, `s` of `Mbps`, en niet in een voor- of achtervoegsel van het label. Laat afsluitende lege velden weg: gebruik puntkomma's tot en met het laatste ingevulde optionele veld.

**Herkomst**

Projectregel

**Toepassingsgebied**

Labels, UOM en optionele velden van Nagios-perfdata.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Eenheden zoals %, B, s en Mbps horen in UOM; ontbrekende achterste velden worden weggelaten.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Eenheden zoals %, B, s en Mbps horen in UOM; ontbrekende achterste velden worden weggelaten.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een label heet DiskBytes en bevat de eenheid; lege optionele velden blijven als puntkomma’s staan. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik een stabiel snake_case-label met kleine beginletter, zet B in UOM en eindig bij het laatste gevulde optionele veld. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Eenheden zoals %, B, s en Mbps horen in UOM; ontbrekende achterste velden worden weggelaten.

**Handmatige review**

Controleer labeltekens, eenheid en iedere veldpositie zonder betekenisvolle scheiding te verwijderen.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer labeltekens, eenheid en iedere veldpositie zonder betekenisvolle scheiding te verwijderen. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### Counter-UOM alleen voor monotone tellers gebruiken

**Norm**

De eenheid `c` is bedoeld voor een monotone teller die oploopt tot een reset. Gebruik haar niet voor gauges, begrensde aantallen, huidig gebruik, piekwaarden, snelheden of periodetotalen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Perfdatavelden met UOM c.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Gauges, begrensde aantallen, huidig gebruik, pieken, snelheden en periodetotalen zijn geen monotone counters.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Gauges, begrensde aantallen, huidig gebruik, pieken, snelheden en periodetotalen zijn geen monotone counters.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een gauge met huidig geheugengebruik krijgt c. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik c alleen voor een teller die oploopt tot een reset; kies voor een gauge de passende gewone eenheid. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Gauges, begrensde aantallen, huidig gebruik, pieken, snelheden en periodetotalen zijn geen monotone counters.

**Handmatige review**

Volg de meetwaarde over meerdere waarnemingen en bepaal of een daling uitsluitend een reset is.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Volg de meetwaarde over meerdere waarnemingen en bepaal of een daling uitsluitend een reset is. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

#### De externe monitoringinterface behouden

**Norm**

Exitgedrag, samenvattingsvorm, perfdatakeys, CLI-opties, gegenereerde paden en registratienamen vormen de externe interface van de check. Behoud ze, tenzij de opdracht expliciet zo'n afspraak wijzigt. Leg bij een wijziging de operationele reden uit en valideer gezond, fout- en onbekend gedrag.

**Herkomst**

Projectregel

**Toepassingsgebied**

Exitcodes, samenvatting, perfdata, opties, gegenereerde paden en registratienamen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een expliciete opdracht mag de afspraak veranderen; de operationele reden en validatie blijven vereist.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een expliciete opdracht mag de afspraak veranderen; de operationele reden en validatie blijven vereist.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een interne refactor verandert zonder opdracht een perfdatakey of exitcode. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Behoud de interface; documenteer bij een expliciet gevraagde wijziging de operationele reden. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een expliciete opdracht mag de afspraak veranderen; de operationele reden en validatie blijven vereist.

**Handmatige review**

Vergelijk de genoemde interfaceonderdelen vóór en na de wijziging en valideer gezond, fout en onbekend resultaat.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk de genoemde interfaceonderdelen vóór en na de wijziging en valideer gezond, fout en onbekend resultaat. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.


## Autofix en suppressions

Een autofix corrigeert een vastgestelde afwijking; een suppression onderdrukt een melding. Beoordeel eerst de norm en de correctievoorwaarden bij de betrokken regel. De [suppressieregel](#alleen-toegestane-suppressions-gebruiken) beschrijft welke markeringen zijn toegestaan en hoe je ze begrenst. Hieronder staat hoe je een toegestane automatische correctie uitvoert en controleert.

### Automatisch corrigeren (autofix)

Met `--fix` schrijft Puppet-lint ondersteunde correcties rechtstreeks naar de geselecteerde bestanden. Begin met een gewone scan en beoordeel de [voorwaarden van de betrokken checks](#beschikbare-projectchecks) voordat je de correctie uitvoert.

Kies de bestanden die bij je wijziging horen. De eerste aanroep hieronder corrigeert de volledige projectscope en is alleen geschikt wanneer die hele scope is bedoeld. De tweede beperkt de correctie tot één manifest; de derde selecteert daarnaast één check:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Gehele projectscope, uitsluitend wanneer die volledige scope is geautoriseerd. **Wijzigt bestanden:** Geselecteerde manifests. **Verwacht resultaat:** Ondersteunde correcties; resterende warnings/errors blijven falen.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix .
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alleen examples/site.pp. **Wijzigt bestanden:** Geselecteerde manifests. **Verwacht resultaat:** Ondersteunde correcties; resterende warnings/errors blijven falen.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix examples/site.pp
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alleen examples/site.pp en project_resource_references. **Wijzigt bestanden:** Geselecteerde manifests. **Verwacht resultaat:** Ondersteunde correcties; resterende warnings/errors blijven falen.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix --only-checks project_resource_references examples/site.pp
```

Zonder `--only-checks` worden de beschikbare fixes van zowel standaardchecks als projectchecks gebruikt. Een check kan een melding laten staan wanneer de code niet veilig te herschrijven is. De concrete grenzen staan bij [inspringing](#inspringing), [komma's](#kommas), [parameteruitlijning](#parameters-en-instellingen), [commentaarscheiding](#toelichtingen-bij-code), [resource references](#resource-references), [packagegroepen](#pakketten-en-mappen) en [Puppet Strings](#puppet-strings).

Geslaagde correcties verschijnen als `fixed`. Een resterende waarschuwing of fout geeft nog steeds een foutcode. Scan daarna zonder `--fix` opnieuw: Puppet-lint verzamelt alle meldingen vóór het corrigeren, waardoor bijvoorbeeld een lengtemelding nog over de oorspronkelijke regel kan gaan.

Bij een syntaxfout schrijft de CLI het manifest niet weg. Genegeerde meldingen worden evenmin gecorrigeerd. Bekijk na de correctieronde de volledige diff en volg de [verdere afronding](#werkwijze-bij-een-wijziging). De gewone projectaanroep en CI controleren alleen; voor correctie gebruik je expliciet `--fix`. Er is geen aparte Rake-task of formatter voor nodig.

## Parservalidatie en Ruby-controles

### Ruby-code controleren

RuboCop controleert de eigen Ruby-code op de [Ruby-stijlregels van RuboCop](https://docs.rubocop.org/rubocop/). De [projectconfiguratie](../../.rubocop.yml) neemt ook de verborgen map `.tools/` mee, naast onder meer de Gemfile, het Rakefile en Ruby-code in modules. Vendored submodules en geïnstalleerde gems vallen buiten de scan. Templates zijn eveneens uitgesloten: render die eerst en valideer de resulterende code afzonderlijk.

RuboCop wordt met `bundle install` geïnstalleerd. Voer de scan uit vanuit de repositoryroot:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Eigen Ruby-code via .rubocop.yml. **Wijzigt bestanden:** Alleen cache. **Verwacht resultaat:** Exitcode 0 zonder offenses.

```sh
bundle exec rubocop --config .rubocop.yml
```

De configuratie gebruikt de standaardregels en schakelt nieuwe checks in. Er is geen gegenereerde uitzonderingenlijst voor bestaande meldingen. Daardoor geeft de scan een foutcode zolang er afwijkingen zijn. Herstel meldingen binnen de scope van je wijziging en vermeld de resterende meldingen in de review; een uitgevoerd commando betekent nog geen geslaagde controle.

Begin met een gewone scan voordat je automatisch corrigeert. Kies daarna de bestanden die bij je wijziging horen. Bijvoorbeeld:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle en voorafgaande RuboCop-scan. **Invoer:** De benoemde Ruby-bron voor fix; daarna volledige checks. **Wijzigt bestanden:** Ja, de geselecteerde Ruby-bron en testrapporten. **Verwacht resultaat:** Veilige correctie gevolgd door hercontrole en diffreview.

```sh
bundle exec rubocop --config .rubocop.yml --force-exclusion --autocorrect .tools/lint/lib/project_lint/ast.rb
bundle exec rubocop --config .rubocop.yml
bundle exec rake test
git diff --check
git diff
```

`--force-exclusion` respecteert de uitgesloten paden ook wanneer je een bestand expliciet opgeeft. [`--autocorrect`](https://docs.rubocop.org/rubocop/usage/autocorrect.html) gebruikt alleen correcties die RuboCop als veilig aanmerkt. Beoordeel de diff en voer de tests opnieuw uit. Controleer gewijzigde Ruby-code in modules ook met tijdelijke functionele controles buiten de repository; de tooltests dekken dat gedrag niet. `--autocorrect-all` bevat ook mogelijk gedragsveranderende correcties en hoort niet bij deze veilige correctiestap.

RuboCop beoordeelt statische eigenschappen zoals opmaak, mogelijke fouten en complexiteit. De tooltests en inhoudelijke review blijven nodig om vast te stellen of de eigen lintchecks correct werken.

### Puppet-manifests valideren

Controleer ieder gewijzigd Puppet-manifest afzonderlijk met de parser. Vervang het voorbeeldpad door het gewijzigde bestand:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** examples/site.pp; kies voor werkelijk werk het gewijzigde manifest. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Parserstatus 0 bij geldige syntax.

```sh
bundle exec puppet parser validate examples/site.pp
```

Voer vanuit de repositoryroot de volledige selectie met JUnit-rapportage uit:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alle eigen manifests via validate:puppet. **Wijzigt bestanden:** Parser-JUnit in .tools/lint/results. **Verwacht resultaat:** Alle geselecteerde manifests gevalideerd met status 0.

```sh
bundle exec rake validate:puppet
```

De taak selecteert alle eigen `.pp`-bestanden recursief, inclusief `examples/` en nieuwe manifests. De vendored submodules `concat`, `debconf`, `reboot`, `stdlib` en `timezone`, geïnstalleerde gems onder `vendor/` en toolfixtures onder `.tools/` vallen buiten deze selectie. De taak staat los van `rake test` en is geen afhankelijkheid van die testtaak.

`validate:puppet` geeft de geselecteerde bestanden aan `puppet-validate-junit` uit de actieve bundle. Dit commando voert voor ieder bestand afzonderlijk de native `puppet parser validate` uit, zonder kleurcodes. Een fout stopt de controle van de overige bestanden niet. De parser controleert syntax zonder een catalogus te compileren of resources toe te passen; lintregels, functiegedrag en de werking op een host vallen buiten deze controle.

Het rapport staat in `.tools/lint/results/puppet-validate-report.xml`, met suite `puppet-validate` en één testcase per uniek manifestpad. Een niet-nul exitcode van de validator geeft een `failure` met de native foutmelding. Ontbrekende bestanden en ongeschikte bestandstypen krijgen een `error`, net als een validator die niet kan starten of door een signaal eindigt. Een lege selectie levert een foutcase op en slaagt dus niet stilzwijgend. De opdracht eindigt met een foutcode zodra een controle of het schrijven van het rapport mislukt.

Voor een gerichte selectie met rapportage gebruik je:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** examples/site.pp en examples/web.pp. **Wijzigt bestanden:** Het opgegeven XML-rapport. **Verwacht resultaat:** Gerichte parserresultaten; geen volledige eindselectie.

```sh
bundle exec puppet-validate-junit .tools/lint/results/puppet-validate-report.xml examples/site.pp examples/web.pp
```

Het eerste argument is het rapportpad met extensie `.xml`; daarna volgen concrete `.pp`-bestanden, geen directories. Zet paden met spaties tussen quotes. De opdracht maakt de rapportmap zo nodig aan en vervangt bij iedere uitvoering alleen zijn eigen rapportbestand. Een gerichte run bevat alleen die selectie; gebruik voor de eindcontrole de volledige Rake-taak. Afnemende projecten bepalen hun [eigen manifestselectie](#eigen-manifests-valideren).

### Aanvullende validatie

Controleer gewijzigde modulemetadata met:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** basic_settings/metadata.json; kies de gewijzigde metadata. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Exitcode 0 bij geldige metadata.

```sh
bundle exec metadata-json-lint basic_settings/metadata.json
```

Puppet-voorbeelden in Strings en Markdown worden niet door de gewone lintscan gevonden. Werk ze tijdelijk buiten de repository uit tot uitvoerbare invoer en controleer die met de projectlintregels en de parser. Render gewijzigde templates voordat je het resulterende formaat, de shellinspringing en de `Managed by puppet`-header beoordeelt.

Bij gedragswijzigingen onderzoek je wat er op de host verandert: welke bestanden worden geschreven, welke services herstarten en welke rechten of verbindingen daarvoor nodig zijn. Controleer normaal gebruik en een praktisch foutgeval met synthetische invoer. Neem bij een gedeelde bouwsteen alle geraakte gebruikers mee. Voor monitoring gelden de [bijbehorende scenario's](../../AGENTS.md#monitoring-validation); voor dependencies de [prerequisitereview](#resources-en-afhankelijkheden).

Deze functionele controles blijven volgens de [testafspraken](../../AGENTS.md#test-scope) buiten de repositorytests. Leg de uitgevoerde commando's, resultaten en resterende onzekerheid vast in de review.

### Eigen manifests valideren

Stel eerst de [rapportmap](#rapportmap-kiezen) in en voer parservalidatie als afzonderlijke controle uit vanuit je eigen projectroot. Met `lint-project` vanaf versie `0.1.3` is het rapportcommando beschikbaar in je eigen bundle:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** [Eigen installatie](#installatie-in-je-project), bestaande genoemde manifests en [rapportmapinstelling](#rapportmap-kiezen). **Invoer:** De twee genoemde eigen manifests. **Wijzigt bestanden:** XML in de eigen rapportmap. **Verwacht resultaat:** Parserresultaat per geselecteerd manifest.

```sh
bundle exec puppet-validate-junit "$PROJECT_REPORT_DIR/puppet-validate-report.xml" environments/production/manifests/site.pp modules/profile/manifests/init.pp
```

Vervang de manifestpaden door alle eigen `.pp`-bestanden die je wilt controleren. Het commando accepteert concrete bestanden; directories worden als fout gerapporteerd. De [werking en rapportinhoud](#puppet-manifests-valideren) zijn gelijk aan die in deze repository. De uitvoermap staat in je eigen project en wordt automatisch aangemaakt. Bestanden uit `global-modules` en andere dependencies horen niet bij deze eigen selectie. `.puppet-lint.rc` en `PROJECT_LINT_MODULEPATH` bepalen deze parserselectie niet.

Voor een recursieve projectselectie voeg je `gem 'rake'` toe aan je eigen Gemfile als Rake nog ontbreekt, voer je `bundle install` uit en plaats je de volgende taak in je eigen root-Rakefile. Behoud eventuele bestaande taken:

```ruby
namespace :validate do
  desc 'Validate own Puppet manifests and write a JUnit report'
  task :puppet do
    manifests = FileList['**/*.pp'].exclude('.tools/**/*', 'global-modules/**/*', 'vendor/**/*')
    report_dir = ENV.fetch('PROJECT_REPORT_DIR', '.tools/quality/results')
    sh 'bundle', 'exec', 'puppet-validate-junit', File.join(report_dir, 'puppet-validate-report.xml'), *manifests
  end
end
```

Pas de uitsluitingen aan de dependencylocaties van je project aan. Deze selectie neemt nieuwe eigen manifests en uitvoerbare voorbeelden mee en sluit toolfixtures uit. De taak roept de gem aan; je kopieert geen validator of rapportimplementatie. Gebruik `bundle exec rake validate:puppet` lokaal en in de validatiejob zodra je deze taak gebruikt. Houd de taak los van `test` en eventuele standaardtaken voor tooltests. Het [CI-voorbeeld](#controle-in-ci) gebruikt de rechtstreekse aanroep met twee concrete manifests; vervang die door je volledige bestandsselectie of deze Rake-taak.

Voor het onderzoeken van één fout blijft de native opdracht `bundle exec puppet parser validate pad/naar/manifest.pp` beschikbaar. Parservalidatie compileert geen catalogus en vervangt de [eigen gedragsvalidatie](#aanvullende-tests) niet.

### Ruby controleren in een ander project

Bundler installeert RuboCop automatisch als dependency van `lint-project`. Maak in de hoofdmap van je eigen project een `.rubocop.yml` die het gedeelde profiel erft met de [native `inherit_gem`-optie](https://docs.rubocop.org/rubocop/latest/configuration.html):

```yaml
inherit_gem:
  lint-project: config/rubocop.yml

inherit_mode:
  merge:
    - Include
    - Exclude

AllCops:
  Include:
    - '.tools/**/*.rb'
    - '.tools/**/*.rake'
    - '.tools/**/*.gemspec'
  Exclude:
    - 'global-modules/**/*'
    - 'vendor/**/*'
    - '**/templates/**/*'
```

Het gedeelde profiel gebruikt de standaardregels van RuboCop en schakelt nieuwe checks in. Met `inherit_mode` voeg je de eigen bestandsselectie toe aan de standaardselectie, zodat ook gewone Ruby-bestanden, Gemfile en Rakefile gecontroleerd blijven. De scan neemt eigen tools onder `.tools/` mee en slaat `global-modules/` over. Pas de uitgesloten dependency- en templatemappen aan je eigen project aan; templates valideer je na renderen. De Ruby-configuratie laadt geen Puppet-checks. Voer vanuit je projectroot de gewone CLI uit:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen bundle en de hierboven getoonde .rubocop.yml. **Invoer:** Eigen Ruby-code. **Wijzigt bestanden:** Alleen cache. **Verwacht resultaat:** RuboCopstatus 0 zonder offenses.

```sh
bundle exec rubocop --config .rubocop.yml
```

Voor veilige lokale correcties volg je de [RuboCop-werkwijze](#ruby-code-controleren), met de `.rubocop.yml` van je eigen project. Voor console-uitvoer en JUnit XML uit één uitvoering gebruik je de [rapportaanroep](#rapporten-en-artifacts-in-je-project). Voer de Ruby-scan ook in je eigen CI uit. Puppet-lint en RuboCop hebben afzonderlijke commando's: een Puppet-lintscan voert geen Ruby-scan uit.

### Aanvullende tests

Voer naast linting en de [parservalidatie](#eigen-manifests-valideren) de gedragstests van je eigen project uit, met de Puppet- of OpenVox-versie, facts en Hiera die je daarvoor gebruikt. De ontwikkelbundle van de moduleverzameling is geen vereiste.

De gemtests controleren het lintgereedschap. Ze vervangen geen catalogus-, template-, script- of monitoringvalidatie van afnemende projecten.

## Rapportage en CI

### Lintrapporten maken

In deze repository gebruiken alle gepubliceerde validatie-, lint- en testrapporten JUnit XML en staan ze onder `.tools/lint/results/`. Deze gegenereerde map is uitgesloten van versiebeheer. Afnemende projecten kiezen hun [eigen rapportmap](#rapportmap-kiezen). De onderstaande aanroepen gebruiken dezelfde configuratie, bestandsselectie en foutstatus als de gewone scans. Voer ze afzonderlijk uit vanuit de repositoryroot, met de [ontwikkelbundle](#gems-installeren) geïnstalleerd.

Puppet-lint levert zijn native JSON-uitvoer via een pipe aan `puppet-lint-junit`, de rapportomzetter uit `lint-project`. Die schrijft JUnit XML en toont de actieve meldingen met bronpositie in de console. Gebruik Bash met `pipefail`:

**Werkmap:** Repositoryroot. **Shell:** Bash met pipefail. **Vereisten:** Ontwikkelbundle. **Invoer:** Volledige lintselectie. **Wijzigt bestanden:** Puppet-lint-JUnit in .tools/lint/results. **Verwacht resultaat:** Lint- én conversiestatus behouden.

```bash
set -o pipefail
mkdir -p .tools/lint/results
bundle exec puppet-lint --no-config --config .puppet-lint.rc --json . | bundle exec puppet-lint-junit .tools/lint/results/puppet-lint-report.xml
```

`pipefail` bewaart de foutstatus van Puppet-lint en laat ook een mislukte omzetting falen. De omzetter controleert geen Puppet-code en voert de linter niet opnieuw uit. De JSON-invoer blijft intern in de pipe; het opgeslagen artifact bevat XML. Gebruik het gedeelde profiel met `--fail-on-warnings`, zodat actieve waarschuwingen zowel de job als het rapport laten falen.

Het Puppet-rapport groepeert actieve meldingen per bestand en check in één JUnit-testcase. De fouttekst bevat alle bijbehorende regels, kolommen en meldingen. Genegeerde en gecorrigeerde meldingen tellen niet als fout. Een scan zonder actieve bevindingen krijgt één geslaagde testcase voor de gehele scan; dat is geen telling van gecontroleerde manifests of functionele tests. Ontbrekende of ongeldige JSON-invoer en een scan zonder gerapporteerde bestanden leveren een rapport met `ReportError` en een foutcode op. Het opgegeven rapportbestand wordt bij iedere uitvoering vervangen; een eventuele bovenliggende map moet bestaan.

RuboCop maakt in één uitvoering normale console-uitvoer en JUnit XML met zijn [ingebouwde formatter](https://docs.rubocop.org/rubocop/latest/formatters.html#junit-style-formatter):

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Volledige eigen Ruby-selectie. **Wijzigt bestanden:** RuboCop-JUnit en cache. **Verwacht resultaat:** Console en XML uit dezelfde run.

```sh
mkdir -p .tools/lint/results
bundle exec rubocop --config .rubocop.yml --format progress --format junit --out .tools/lint/results/rubocop-report.xml
```

De rapportvarianten voeren iedere linter eenmaal uit en corrigeren geen bronbestanden. RuboCop maakt testcases per bestand en actieve cop. Deze JUnit-testcases beschrijven lintcontroles; de [parservalidatie](#puppet-manifests-valideren) en [tooltests](#tests-uitvoeren-en-uitbreiden) behouden hun eigen rapporten en tellingen. De testreporter vervangt alleen `TEST-*.xml` in dezelfde uitvoermap en behoudt de lint- en validatierapporten. CI bewaart de vier soorten rapporten als [afzonderlijke artifacts](#ci-van-deze-repository).

### Rapportmap kiezen

Kies een eigen map voor gegenereerde rapporten binnen je project, bijvoorbeeld `.tools/quality/results/`, `.tools/checks/results/` of `build/reports/`. De naam `lint` en de locatie onder `.tools/` zijn voor afnemende projecten niet verplicht. `.tools/lint/results/` is de keuze van deze repository, geen vast uitvoerpad van de gedeelde gem. Gebruik een aparte uitvoermap, houd die buiten versiebeheer en schrijf niet naar `global-modules` of de geïnstalleerde gem.

De voorbeelden hieronder gebruiken `PROJECT_REPORT_DIR` om die projectkeuze door te geven. Stel de variabele in vanuit je eigen projectroot voordat je de rapportcommando's uitvoert:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen rapportkeuze. **Invoer:** Het concrete voorbeeldpad. **Wijzigt bestanden:** Alleen shellomgeving. **Verwacht resultaat:** PROJECT_REPORT_DIR beschikbaar voor de volgende procedures.

```sh
export PROJECT_REPORT_DIR=".tools/quality/results"
```

Dit is een afspraak in de voorbeeldconfiguratie van het afnemende project, geen automatisch ingelezen geminstelling. De shellcommando's geven het pad expliciet mee; de voorbeeld-Rake-taak en testhelper lezen de variabele zelf. Zij gebruiken `.tools/quality/results` wanneer de variabele ontbreekt. Geef een niet-leeg pad op, relatief aan de eigen projectroot. De voorbeelden plaatsen ook de CI-artifacts binnen die checkout.

Gebruik dezelfde waarde lokaal en in CI. In het [GitHub-voorbeeld](#controle-in-ci) stel je die eenmaal onder `env` in; in het [GitLab-fragment](#rapporten-tonen-in-gitlab) onder `variables`. De uitvoercommando's, uploadpaden en testsamenvatting verwijzen naar die instelling. Pas daarnaast de eigen `.gitignore` aan het concrete pad aan: Git vervangt daar geen omgevingsvariabelen. De [rapportafspraken](#rapporten-en-artifacts-in-je-project) tonen per controle het bestand binnen deze map.

### CI van deze repository

[GitHub Actions](../../.github/workflows/lint.yml) voert vier onafhankelijke jobs uit. Iedere job haalt de repository met submodules op, installeert de ontwikkelbundle en voert zijn eigen controle uit. Een fout in één controle houdt de andere jobs niet tegen.

| Job | Controle | Downloadbaar artifact | Inhoud |
| --- | --- | --- | --- |
| `Puppet validate` | `bundle exec rake validate:puppet` met JUnit per manifest | `Puppet-validate-report` | `.tools/lint/results/puppet-validate-report.xml` |
| `Puppet lint` | De volledige Puppet-lintscan met JUnit-omzetting | `Puppet-lint-report` | `.tools/lint/results/puppet-lint-report.xml` |
| `Ruby lint` | RuboCop met console- en JUnit-uitvoer | `Ruby-lint-report` | `.tools/lint/results/rubocop-report.xml` |
| `Tool tests` | `bundle exec rake test` met console- en JUnit-uitvoer | `Test-results` | `.tools/lint/results/TEST-*.xml` |

De validatiejob gebruikt de [parsertaak](#puppet-manifests-valideren), de lintjobs gebruiken de [rapportaanroepen](#lintrapporten-maken) en de testjob gebruikt de gewone [roottaak](#tests-uitvoeren-en-uitbreiden). Iedere controle draait eenmaal en behoudt zijn eigen foutstatus. De tests omvatten pluginloading, autofixinteracties en het bouwen en installeren van de gem in een tijdelijk afnemend project. Dat controleert het ontwikkelgereedschap; het bewijst geen correct modulegedrag of ondersteuning van alle platforms.

Open de workflowrun onder **Actions** om de vier uitslagen en de artifacts te bekijken. De testjob publiceert de JUnit-resultaten ook in het samenvattende overzicht van die run. De upload- en samenvattingsstappen gebruiken `!cancelled()`, zodat al gemaakte rapporten na een gewone validatie-, lint- of testfout beschikbaar blijven. Wanneer de installatie of het laden van de tests al mislukt, is er mogelijk nog geen bruikbaar rapport. Een geannuleerde run hoeft evenmin rapporten op te leveren.

Iedere lintjob maakt `.tools/lint/results/` aan vóór het schrijven; de parserreporter maakt die map zelf aan. De uploads gebruiken `include-hidden-files: true`, omdat `.tools` een verborgen map is. Iedere artifactselectie wijst uitsluitend naar het eigen lint- of validatierapport of naar `TEST-*.xml`; de testsamenvatting leest dezelfde testselectie.

Iedere job voert na zijn geslaagde controle rechtstreeks `git diff --exit-code HEAD --` uit. Dit vindt wijzigingen die installatie of controles in gevolgde bestanden hebben achtergelaten ten opzichte van de uitgecheckte commit. Nieuwe, niet-gevolgde bestanden vallen erbuiten. De opdracht vergelijkt geen twee commits en vervangt de lokale whitespacecontrole met `git diff --check` niet. Voer deze CI-controle uit vanuit een schone checkout; lokale ontwikkelwijzigingen geven eveneens een verschil.

De workflow gebruikt de nieuwste stabiele Ruby en installeert Bundler zonder versiepin. `BUNDLE_FROZEN=true` bewaakt de lockfile; `BUNDLE_IGNORE_CONFIG=1` voorkomt afhankelijkheid van persoonlijke Bundler-instellingen. Gems worden binnen de checkout geïnstalleerd via `BUNDLE_PATH=vendor/bundle`. De jobs gebruiken Bash met `pipefail`, zodat ook de Puppet-lintaanroep met JUnit-omzetting zijn foutstatus behoudt. Beide linters controleren alleen; de workflow maakt geen commits en publiceert geen gem.

De artifacts en het testoverzicht vereisen geen extra schrijfrechten op de repository; `contents: read` blijft voldoende. De samenvatting schrijft geen pull-requestcomments of afzonderlijke check runs. Gebruikt de repository verplichte statuschecks, selecteer dan alle vier de jobnamen uit de tabel. Voor afnemende projecten staat hieronder een [voorbeeld met dezelfde CLI](#controle-in-ci).

### Rapporten en artifacts in je project

Gebruik JUnit XML voor alle gepubliceerde validatie-, lint- en testrapporten en schrijf ze naar de [eigen rapportmap](#rapportmap-kiezen). De voorbeelden gebruiken daarvoor `PROJECT_REPORT_DIR`; de projectroot blijft vrij van losse rapportbestanden. De uitvoermap bevat alleen gegenereerde resultaten; de lintercode en gedeelde profielen komen uit de gem in `global-modules` of je andere gembron.

Bewaar bij voorkeur de resultaten van iedere controle in een afzonderlijk artifact van de job die de controle uitvoert. Daardoor vind je een lintbevinding of testfout direct bij de bijbehorende uitslag. De JUnit-bestanden van één testuitvoering vormen samen één testartifact.

| Job | Bestand binnen de gekozen rapportmap | Artifactnaam | Voorwaarde |
| --- | --- | --- | --- |
| `Puppet validate` | `puppet-validate-report.xml` | `Puppet-validate-report` | De eigen Puppet-manifests zijn geselecteerd. |
| `Puppet lint` | `puppet-lint-report.xml` | `Puppet-lint-report` | De eigen Puppet-manifests en lintconfiguratie zijn aanwezig. |
| `Ruby lint` | `rubocop-report.xml` | `Ruby-lint-report` | De eigen Ruby-code en RuboCop-configuratie zijn aanwezig. |
| `Tool tests` | `TEST-*.xml` | `Test-results` | Het project heeft een eigen testsuite en [JUnit-rapportage](#junit-rapportage-instellen). |

De voorbeelden met beide Puppet-rapportcommando's vereisen `lint-project` vanaf versie `0.1.3`. Kies voor `global-modules` een revisie met die gemversie, voer vanuit je eigen projectroot `bundle update lint-project` uit en neem de lockfile en submodulerevisie op in versiebeheer. De commando's zijn onderdeel van de gem; je kopieert geen converter of validator naar je eigen project. Het validatierapport ontstaat tijdens de [parseraanroep](#eigen-manifests-valideren).

Stel eerst `PROJECT_REPORT_DIR` in volgens [Rapportmap kiezen](#rapportmap-kiezen). Maak het Puppet-lintrapport vanuit de projectroot met dezelfde configuratie en bronselectie als de [gewone controle](#eigen-code-controleren):

**Werkmap:** Consumerroot. **Shell:** Bash met errexit en pipefail. **Vereisten:** Eigen bundle, [configuratie](#eigen-lintconfiguratie), [rapportmap](#rapportmap-kiezen) en genoemde manifests/modules. **Invoer:** De twee genoemde eigen manifests. **Wijzigt bestanden:** Puppet-lint-JUnit. **Verwacht resultaat:** Lint- en conversiefouten blijven jobfouten.

```bash
set -eo pipefail
mkdir -p "$PROJECT_REPORT_DIR"
lint_gem="$(bundle info --path lint-project)"
export PROJECT_LINT_MODULEPATH="$PWD/global-modules:$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc --json environments/production/manifests/site.pp modules/profile/manifests/init.pp | bundle exec puppet-lint-junit "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
```

Pas modulemappen en manifestpaden aan je project aan. Bash `pipefail` behoudt de foutstatus van Puppet-lint tijdens de omzetting en laat de opdracht ook bij een conversiefout falen. De configuratie, bestandsselectie en controle op waarschuwingen blijven gelijk aan de gewone scan. De [uitleg over de rapportinhoud](#lintrapporten-maken) beschrijft hoe lintmeldingen in JUnit worden weergegeven.

Voor Ruby gebruik je afzonderlijk de volgende aanroep. De [eigen `.rubocop.yml`](#ruby-controleren-in-een-ander-project) bepaalt welke bestanden worden gecontroleerd:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen bundle, .rubocop.yml en [rapportmap](#rapportmap-kiezen). **Invoer:** Eigen Ruby-selectie. **Wijzigt bestanden:** RuboCop-JUnit en cache. **Verwacht resultaat:** Console en XML met dezelfde foutstatus.

```sh
mkdir -p "$PROJECT_REPORT_DIR"
bundle exec rubocop --config .rubocop.yml --format progress --format junit --out "$PROJECT_REPORT_DIR/rubocop-report.xml"
```

De testtaak uit [JUnit-rapportage instellen](#junit-rapportage-instellen) maakt zijn eigen rapporten tijdens `bundle exec rake test`. Iedere controle draait eenmaal. Alle artifacts bevatten JUnit XML; houd parservalidatie, lintresultaten en tooltests als afzonderlijke suites en artifacts herkenbaar.

Neem de hele gekozen uitvoermap met zijn concrete pad op in de eigen `.gitignore`. Voor de voorbeeldwaarde `.tools/quality/results` is dat:

```gitignore
/.tools/quality/results/
```

Het [GitHub Actions-voorbeeld](#controle-in-ci) bewaart elk rapport als downloadbaar artifact en toont de tooltests ook in het workflowoverzicht. Voor het testoverzicht van GitLab voeg je de [JUnit-registratie](#rapporten-tonen-in-gitlab) toe aan iedere producerende job. Downloaden en weergeven gebruiken dezelfde rapportbestanden.

Gebruik voor het testartifact en de testsamenvatting uitsluitend `TEST-*.xml` binnen de gekozen testmap. Een selectie van de hele map of `*.xml` neemt ook de lint- en validatierapporten mee. Verander je een rapportbestandsnaam, pas dan de bijbehorende upload en JUnit-registratie samen aan. GitHub Actions vereist [`include-hidden-files: true`](https://github.com/actions/upload-artifact#uploading-hidden-files) wanneer de gekozen map onder een verborgen pad zoals `.tools` staat; de onderstaande voorbeelden beperken de upload tot de bedoelde rapportbestanden.

### Controle in CI

Gebruik dezelfde Gemfile, lockfile, configuratie en CLI-aanroepen als lokaal. Het onderstaande GitHub Actions-voorbeeld hoort bij een project met `global-modules`, eigen Ruby-code en een Minitest-suite met de [reporterconfiguratie voor eigen tooltests](#junit-rapportage-instellen). Bewaar het als `.github/workflows/checks.yml` in je eigen project en stel `env.PROJECT_REPORT_DIR` in op de eigen rapportmap. De commando's, uploads en testsamenvatting gebruiken die waarde. Gebruik de jobs die bij je project horen: zonder eigen testsuite laat je `tool_tests` weg. Heeft het project geen eigen Ruby-code, Gemfile, Rakefile of Ruby-tooling om te controleren, laat dan ook `ruby_lint` weg; kopieer geen tests of Ruby-code uit de gedeelde gem om een lege job te vullen.

Iedere job haalt `global-modules` met zijn submodules op en installeert de eigen ontwikkelbundle. De jobs draaien onafhankelijk, zonder `needs` tussen validatie, linting en tests, en bewaren ieder hun [eigen artifact](#rapporten-en-artifacts-in-je-project). Gebruik je een andere gembron of aanvullende Puppet-modules, voeg dan in iedere betrokken job de benodigde installatiestappen toe vóór de controle. De bronselectie en het modulepad volgen de inrichting van je eigen Puppet environment.

```yaml
name: Puppet checks

on:
  pull_request:
  push:

permissions:
  contents: read

env:
  BUNDLE_IGNORE_CONFIG: '1'
  BUNDLE_VERSION: system
  BUNDLE_FROZEN: 'true'
  BUNDLE_PATH: vendor/bundle
  PROJECT_REPORT_DIR: .tools/quality/results

defaults:
  run:
    shell: bash

jobs:
  puppet_validate:
    name: Puppet validate
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Validate own Puppet manifests
        run: bundle exec puppet-validate-junit "$PROJECT_REPORT_DIR/puppet-validate-report.xml" environments/production/manifests/site.pp modules/profile/manifests/init.pp
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload Puppet validation report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Puppet-validate-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/puppet-validate-report.xml

  puppet_lint:
    name: Puppet lint
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Check own Puppet manifests
        run: |
          mkdir -p "$PROJECT_REPORT_DIR"
          test -f .puppet-lint.rc
          lint_gem="$(bundle info --path lint-project)"
          export PROJECT_LINT_MODULEPATH="$GITHUB_WORKSPACE/global-modules:$GITHUB_WORKSPACE/modules"
          bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc --json environments/production/manifests/site.pp modules/profile/manifests/init.pp | bundle exec puppet-lint-junit "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload Puppet lint report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Puppet-lint-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/puppet-lint-report.xml

  ruby_lint:
    name: Ruby lint
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Check own Ruby code
        run: |
          mkdir -p "$PROJECT_REPORT_DIR"
          bundle exec rubocop --config .rubocop.yml --format progress --format junit --out "$PROJECT_REPORT_DIR/rubocop-report.xml"
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload Ruby lint report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Ruby-lint-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/rubocop-report.xml

  # Include this job when the project has its own tool tests and JUnit reporter.
  tool_tests:
    name: Tool tests
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Run own tool tests
        run: bundle exec rake test
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload test results
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Test-results
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/TEST-*.xml
      - name: Publish test summary
        if: ${{ !cancelled() }}
        uses: test-summary/action@v2
        with:
          paths: ${{ env.PROJECT_REPORT_DIR }}/TEST-*.xml
```

De publicatiestappen gebruiken `!cancelled()`: ook na een gewone validatie-, lint- of testfout bewaren ze de gemaakte rapporten, terwijl de producerende job zijn foutstatus behoudt. Na een installatie- of opstartfout is er mogelijk nog geen rapport. Een geannuleerde uitvoering hoeft geen artifacts op te leveren. Laat fouten zichtbaar; gebruik geen autofix of foutonderdrukking in CI.

Iedere job controleert na zijn geslaagde opdracht met `git diff --exit-code HEAD --` of installatie of uitvoering gevolgde bestanden verandert. Hiervoor is een schone checkout nodig. Nieuwe, niet-gevolgde bestanden vallen buiten deze controle; herstel bestanden niet om de stap te laten slagen. `git diff --check` blijft de afzonderlijke lokale whitespacecontrole.

Open in GitHub **Actions** en kies de workflowrun. Daar download je `Puppet-validate-report`, `Puppet-lint-report`, `Ruby-lint-report` en, wanneer de testjob aanwezig is, `Test-results`. Het workflowoverzicht toont daarnaast de JUnit-samenvatting van de tooltests. De configuratie gebruikt alleen `contents: read`; de samenvatting schrijft geen pull-requestcomments en vraagt geen extra repositoryschrijfrechten. Stel bij branchbeveiliging de gebruikte jobs als verplichte statuschecks in.

De Ruby-job gebruikt de [.rubocop.yml van je project](#ruby-controleren-in-een-ander-project); de gem levert het bijbehorende commando. Houd rapportpaden, de eigen `.gitignore` en artifactinstellingen gelijk aan de [rapportafspraken](#rapporten-en-artifacts-in-je-project). Bewaar credentials voor een interne gembron in de daarvoor bedoelde CI-instellingen; zet ze niet in deze configuratie. De tests van `global-modules` draaien in de [CI van deze repository](#ci-van-deze-repository); de testjob van het afnemende project voert uitsluitend zijn eigen tests uit.

#### Rapporten tonen in GitLab

De [GitLab-testweergave](https://docs.gitlab.com/ci/testing/unit_test_reports/) leest JUnit XML via `artifacts:reports:junit`. Een bestand onder alleen `artifacts:paths` is downloadbaar, maar verschijnt daarmee niet in het testoverzicht. Gebruik in je bestaande GitLab-jobs dezelfde installatie, configuratie en rapportcommando's als hierboven; de Puppet-pipe vereist Bash met `set -eo pipefail`.

Voeg de onderstaande rapportmap en artifactinstellingen toe aan de bijbehorende configuratie in `.gitlab-ci.yml`. Voeg `PROJECT_REPORT_DIR` toe aan de bestaande `variables` en kies daar het eigen pad. Zo gebruiken de scripts en uploads dezelfde [CI/CD-variabele](https://docs.gitlab.com/ci/variables/where_variables_can_be_used/); alleen een `export` binnen het script stelt die variabele niet voor de artifactupload in. Dit voorbeeld bevat vier onafhankelijke jobs in dezelfde stage. Gebruik een runner die deze image met Bash uitvoert; `set -eo pipefail` is een Bash-prerequisite. In bestaande jobs kun je alleen de artifactinstellingen overnemen en de eigen installatie en controlecommando’s behouden. Laat `tool_tests` weg wanneer je project geen eigen testsuite heeft.

```yaml
stages:
  - checks

variables:
  PROJECT_REPORT_DIR: .tools/quality/results
  BUNDLE_IGNORE_CONFIG: '1'
  BUNDLE_VERSION: system
  BUNDLE_FROZEN: 'true'
  BUNDLE_PATH: vendor/bundle
  GIT_SUBMODULE_STRATEGY: recursive

.check_setup:
  stage: checks
  image: ruby:latest
  before_script:
    - set -eo pipefail
    - gem install bundler
    - bundle install

puppet_validate:
  extends: .check_setup
  script:
    - bundle exec puppet-validate-junit "$PROJECT_REPORT_DIR/puppet-validate-report.xml" environments/production/manifests/site.pp modules/profile/manifests/init.pp
    - git diff --exit-code HEAD --
  artifacts:
    name: Puppet-validate-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/puppet-validate-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/puppet-validate-report.xml"

puppet_lint:
  extends: .check_setup
  script:
    - mkdir -p "$PROJECT_REPORT_DIR"
    - test -f .puppet-lint.rc
    - lint_gem="$(bundle info --path lint-project)"
    - export PROJECT_LINT_MODULEPATH="$CI_PROJECT_DIR/global-modules:$CI_PROJECT_DIR/modules"
    - bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc --json environments/production/manifests/site.pp modules/profile/manifests/init.pp | bundle exec puppet-lint-junit "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
    - git diff --exit-code HEAD --
  artifacts:
    name: Puppet-lint-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/puppet-lint-report.xml"

ruby_lint:
  extends: .check_setup
  script:
    - mkdir -p "$PROJECT_REPORT_DIR"
    - bundle exec rubocop --config .rubocop.yml --format progress --format junit --out "$PROJECT_REPORT_DIR/rubocop-report.xml"
    - git diff --exit-code HEAD --
  artifacts:
    name: Ruby-lint-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/rubocop-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/rubocop-report.xml"

tool_tests:
  extends: .check_setup
  script:
    - bundle exec rake test
    - git diff --exit-code HEAD --
  artifacts:
    name: Test-results
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/TEST-*.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/TEST-*.xml"
```

`when: always` bewaart beschikbare rapporten ook na een gewone validatie-, lint- of testfout. De CLI-foutcode bepaalt of de job faalt; JUnit-publicatie verandert die status niet. Bekijk de resultaten onder **Tests** in de pipeline en in de testsamenvatting van de merge request. Parservalidatie en lintchecks blijven herkenbaar aan hun eigen suite en artifact. De repository zelf gebruikt de [GitHub Actions-workflow](#ci-van-deze-repository).

## Importeren en distribueren

<a id="de-linter-gebruiken-in-een-ander-puppet-project"></a>

Voeg `lint-project` toe aan de eigen ontwikkelbundle van je project. Je gebruikt de gedeelde checks en profielen uit één gemversie; jouw project bepaalt de te controleren bestanden en het Puppet-modulepad. Een checkout van alle Puppet-modules is alleen nodig als je die modules gebruikt, niet om de linter te kunnen laden.

Voor een project met `global-modules` richt je eerst de [eigen bundle](#installatie-in-je-project) en de configuratie voor [Puppet-lint](#eigen-lintconfiguratie) en [RuboCop](#ruby-controleren-in-een-ander-project) in. Voeg daarnaast de [parservalidatie van eigen manifests](#eigen-manifests-valideren) toe. Heeft je project eigen gereedschap met tests, voeg dan de [testtaak en JUnit-rapportage](#eigen-tooltests) toe. De [rapportafspraken](#rapporten-en-artifacts-in-je-project) en het [CI-voorbeeld](#controle-in-ci) laten zien hoe je de resultaten per controle afzonderlijk bewaart en publiceert.

### Gedeelde tooling hergebruiken

Gebruik `lint-project` als dependency van je eigen project. De gem levert de checks, profielen en rapportcommando's; je hoeft daarvoor geen validator, lintregels of XML-omzetter te schrijven. Je eigen configuratie bepaalt welke bestanden en modulepaden relevant zijn en waar de rapporten terechtkomen.

| Controle | Dit gebruik je uit de gem | Dit stelt je eigen project in |
| --- | --- | --- |
| Puppet-syntax | `puppet-validate-junit` voert de meegeleverde native Puppet-parser uit en schrijft JUnit XML per manifest. | De manifestselectie en het rapportpad. De [optionele Rake-taak](#eigen-manifests-valideren) verzamelt alleen de eigen bestanden en roept dit commando aan. |
| Puppet-lint | De projectchecks, het gedeelde `config/puppet-lint.rc` en `puppet-lint-junit`. | De eigen bestandsuitsluitingen, het Puppet-modulepad en het rapportpad. Gebruik de [native CLI met het gem-entrypoint](#eigen-code-controleren). |
| Ruby-lint | RuboCop en het gedeelde `config/rubocop.yml`. De native JUnit-formatter schrijft het rapport. | De eigen `.rubocop.yml` met `inherit_gem`, bestandsselectie en het rapportpad. |
| Eigen tooltests | De [voorbeelden voor testselectie en rapportage](#eigen-tooltests). | De eigen tests en testdependencies. De reporter van het eigen testframework schrijft JUnit XML. |

Installeer de gem eenmaal per ontwikkelomgeving of CI-job via de eigen Gemfile en lockfile. Roep vervolgens de gedeelde commando's met `bundle exec` aan. Kopieer geen implementatie, gedeelde profielen of gemtests uit `global-modules` en laad zijn Gemfile of Rakefile niet vanuit je eigen project. Het Rakefile van deze repository selecteert onze bestanden; de gemcommando's werken met jouw selectie.

De [CI-voorbeelden](#controle-in-ci) zijn configuratievoorbeelden voor het afnemende project, geen automatisch geïnstalleerde pipeline. Neem de benodigde jobs over en pas alleen de eigen installatie, bestandsselectie, modulepaden en rapportmap aan. Gedeelde verbeteringen komen via de gekozen gemversie of submodulerevisie binnen; een eigen kopie van de implementatie bijhouden is niet nodig. Controleer een update met de eigen lint-, validatie- en testjobs.

### Benodigdheden

Gebruik de nieuwste stabiele Ruby en Bundler en een eigen Gemfile. Voor het controleren van aanroepen moeten de betreffende Puppet-modules lokaal vindbaar zijn. De linter haalt geen modules, catalogi, Hiera of productie-instellingen op.

### Aanbevolen projectstructuur

Gebruik voor nieuwe projecten die deze moduleverzameling als `global-modules` opnemen de onderstaande indeling als voorbeeld. Die sluit aan op de [installatie van de Puppet-modules](../../README.md#installatie). De mapnamen voor eigen gereedschap en rapporten zijn projectkeuzes; `lint-project` vereist geen lokale map met de naam `lint`.

```text
Puppet/
├── Gemfile
├── Gemfile.lock
├── .puppet-lint.rc
├── .rubocop.yml
├── AGENTS.md
├── README.md
├── Rakefile                         # Alleen nodig voor eigen taken of tooltests.
├── .tools/                          # Eigen gereedschap en gegenereerde rapporten.
│   ├── quality/results/             # Voorbeeldrapportmap; kies een eigen pad.
│   └── <tool-name>/
│       ├── bin/                     # Uitvoerbare ingangen, indien nodig.
│       ├── lib/                     # Ruby-code van deze tool, indien nodig.
│       ├── test/
│       │   ├── <behavior>_test.rb
│       │   ├── test_helper.rb       # Alleen voor werkelijk gedeelde testhulp.
│       │   └── fixtures/            # Alleen voor benodigde synthetische invoer.
│       └── README.md
├── global-modules/                  # Deze repository als Git-submodule.
│   └── .tools/lint/
│       └── lint-project.gemspec
├── modules/
│   └── profile/manifests/init.pp
└── environments/
    └── production/
        ├── environment.conf
        └── manifests/site.pp
```

De namen `profile`, `production` en `quality/results` zijn voorbeelden. Voeg de modules en environments toe die jouw project gebruikt en kies een [rapportmap die bij je indeling past](#rapportmap-kiezen). Maak mappen voor eigen gereedschap en een Rakefile pas aan wanneer je zulke tools of taken nodig hebt. Voor het gebruiken van `lint-project` volstaan de dependency en de configuratiebestanden in de projectroot; de [rapportcommando's](#rapporten-en-artifacts-in-je-project) schrijven naar de gekozen uitvoermap.

| Onderdeel | Afspraak |
| --- | --- |
| `Gemfile` en `Gemfile.lock` | Eén ontwikkelbundle in de projectroot voor lokaal werk en CI. Laad `lint-project` als dependency en voeg alleen extra gereedschap toe dat het eigen project gebruikt. |
| `.puppet-lint.rc` en `.rubocop.yml` | Bewaar hier de eigen bestandsselectie en laad de gedeelde profielen volgens [Eigen lintconfiguratie](#eigen-lintconfiguratie) en [Ruby controleren in een ander project](#ruby-controleren-in-een-ander-project). |
| `global-modules/` | Beheer deze dependency via de Git-submodule en de gekozen revisie. Gebruik de gem uit die checkout; voer de controles vanuit de eigen projectroot uit. |
| Eigen rapportmap, bijvoorbeeld `.tools/quality/results/` | Gegenereerde validatie-, lint- en testrapporten van het eigen project. Kies de locatie zelf, bewaar de map buiten versiebeheer en schrijf niet naar de submodule. |
| `.tools/<tool-name>/` | Eén map per eigen tool, met een concrete naam. Gebruik `bin/` voor uitvoerbare ingangen en `lib/` voor Ruby-librarycode wanneer die nodig zijn; een klein zelfstandig script mag rechtstreeks in de toolmap staan. |
| `.tools/<tool-name>/test/` | Houd gedragstests, helpers en fixtures bij de tool die ze controleren. De [testindeling en uitvoering](#eigen-tooltests) beschrijven ook bestaande testmappen. |
| `Rakefile` | Houd eigen taken in de projectroot. Ontdek tooltests recursief onder `.tools/**/test/**/*_test.rb` en voeg alleen bestaande tools toe als `test:<tool-name>`. |

Houd eigen taken voor deze controles beperkt tot de projectspecifieke selectie en het aanroepen van de [gedeelde tooling](#gedeelde-tooling-hergebruiken). Verbeteringen aan de checks, validators en rapportcommando's die voor alle afnemers gelden, horen in de gedeelde gem.

Leg de gekozen eigen toolingindeling en rapportmap vast in de eigen `AGENTS.md` en README. Verwijs voor gedeelde tooling, lintregels en reviewcriteria naar deze handleiding onder `global-modules/.tools/lint/README.md`, zodat die uitleg op één plek onderhouden wordt. De `AGENTS.md` in de submodule beschrijft het werk aan die repository; afnemers leggen de afspraken voor hun eigen project expliciet vast.

Een bestaand project met een andere indeling hoeft daarvoor geen Puppet-modules of environments te verplaatsen. Beschrijf de afwijkende paden in de eigen README en houd Gemfile, bestandsselectie, modulepad en CI daarmee in overeenstemming. De indeling is een aanbevolen werkwijze; de linter dwingt geen mapnamen af. Gebruik je een los gempakket, dan vervalt `global-modules/` als installatievereiste en blijven de afspraken voor de eigen tooling hetzelfde.

### Installatie in je project

Heb je deze repository al als `global-modules` opgenomen, haal dan eerst de submodule en zijn dependencies op volgens de [module-installatie](../../README.md#installatie). Voeg vervolgens dit toe aan de Gemfile in je eigen projectroot:

```ruby
# frozen_string_literal: true

source 'https://rubygems.org'

gem 'lint-project', path: 'global-modules/.tools/lint', require: false
```

Dit pad wijst naar de map met `lint-project.gemspec`, `lib/` en `config/`. Het deel `.tools/lint` hoort bij de locatie van de gedeelde gem in deze repository en bepaalt niet hoe jouw rapportmap heet. De Git-submodule legt de bronrevisie vast; je eigen Gemfile.lock legt de overige gemversies vast. Voer `bundle install` uit vanuit je projectroot en neem de Gemfile, lockfile en submodulerevisie op in je eigen versiebeheer. Daarmee installeer je Puppet-lint, RuboCop, de native Puppet-parser en beide rapportcommando's; aparte dependencies voor deze onderdelen zijn niet nodig.

Zonder checkout kun je een gebouwd gempakket gebruiken. Geef het echte bestandspad op; zet geen credentials in commando’s of je Gemfile:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Nieuwste stabiele Ruby; gebouwd pakket vooraf geleverd op /tmp/lint-project.gem. **Invoer:** Het genoemde gempakket. **Wijzigt bestanden:** Geminstallatie en dependencies. **Verwacht resultaat:** Bundler en pakket geïnstalleerd; volg daarna de eigen Gemfileprocedure.

```sh
gem install bundler
LINT_PACKAGE=/tmp/lint-project.gem
test -f "$LINT_PACKAGE"
gem install "$LINT_PACKAGE"
```

Gebruik bij deze installatieroute de volgende dependency in plaats van de `path:`-dependency. Deze compatibiliteitsconstraint laat versies vanaf 0.1.3 binnen 0.1 toe; zij is geen exacte versiepin. De eigen lockfile legt de gekozen versie vast. De [volledige pakketroute](#gebouwd-gempakket-installeren) gebruikt de daadwerkelijk gecontroleerde pakketversie 0.1.9:

```ruby
source 'https://rubygems.org'

gem 'lint-project', '~> 0.1.3', require: false
```

Voer daarna ook `bundle install` uit. Een interne gemserver kan hetzelfde pakket aanbieden via de gebruikelijke Bundler-sourceconfiguratie. Er is geen gedeelde `BUNDLE_GEMFILE` of apart installatieprogramma nodig.

Bundler ondersteunt ook een rechtstreekse `git:`-dependency. Voor deze repository heeft die `glob: '.tools/lint/*.gemspec'` nodig. Leg de gekozen revisie vast in Gemfile.lock en controleer updates in je eigen CI. Het pad `.tools/lint` is alleen nodig om de gem in de monorepo te vinden; de CLI en configuratie gebruiken daarna de geïnstalleerde gem.

### Eigen code controleren

Het voorbeeld hieronder gebruikt de aanbevolen indeling en controleert twee concrete manifests. Voer het vanuit je projectroot uit:

**Werkmap:** Consumerroot. **Shell:** POSIX shell met errexit. **Vereisten:** Eigen bundle, lokale configuratie en bestaande genoemde manifests/modulemappen. **Invoer:** De twee expliciet genoemde bestanden. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Volledige profielcontrole van deze selectie.

```sh
set -e
lint_gem="$(bundle info --path lint-project)"
export PROJECT_LINT_MODULEPATH="$PWD/global-modules:$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc environments/production/manifests/site.pp modules/profile/manifests/init.pp
```

Vervang de modulemappen en manifestpaden door bestaande paden in jouw project. De modulemappen moeten absoluut zijn en dezelfde volgorde hebben als in de gekozen Puppet environment; het voorbeeld volgt de [module-installatie](../../README.md#installatie), met `global-modules` vóór `modules`. Voeg andere gebruikte modulemappen expliciet toe. Het voorbeeld stopt met `set -e` bij een fout. `test -f` is nodig omdat de native CLI een ontbrekend optiebestand stilzwijgend overslaat. `--no-config` voorkomt dat systeem- of persoonlijke lintopties worden ingelezen. De twee `--config`-opties lezen eerst het gedeelde profiel en vervolgens je eigen bestandsuitsluitingen.

Geef één directory op om die recursief te scannen, of geef één of meer concrete manifestbestanden mee. De native CLI ondersteunt geen combinatie van meerdere directoryscans in één aanroep. Controleer iedere eigen manifestmap wanneer je project meerdere mappen gebruikt en laat CI bij een ontbrekende of lege selectie falen. De keuze van te controleren bestanden is een verantwoordelijkheid van je project; de linter kan niet vaststellen of je alle productiecode hebt geselecteerd.

Plaats aanvullende lintopties na beide `--config`-opties en vóór de manifestpaden. Dezelfde CLI biedt de volgende mogelijkheden:

| Doel | Optie | Gebruik |
| --- | --- | --- |
| Gewone controle | Geen extra optie | Alle actieve regels uit het gedeelde profiel, met je eigen bestandsselectie. |
| Automatisch corrigeren | `--fix` | Alleen lokaal, na beoordeling van de [autofixvoorwaarden](#automatisch-corrigeren-autofix); controleer de diff en scan opnieuw zonder `--fix`. |
| Een check onderzoeken | `--only-checks project_arrays` | Een gerichte selectie tijdens het onderzoeken; de eindcontrole bevat alle gedeelde regels. |
| Onderdrukte meldingen bekijken | `--show-ignored` | Zicht op toegestane lokale suppressions. |
| Een lintrapport maken | `--json` | Native invoer voor de [JUnit-omzetter](#rapporten-en-artifacts-in-je-project), met dezelfde controles en foutstatus. |
| Beschikbare checks bekijken | `--list-checks` | Laat hierbij de manifestpaden weg; de lijst bevat ook uitgeschakelde checks en bewijst geen volledige scan. |

### Een gem bouwen en versie uitbrengen

Het [versienummer en de runtime-afhankelijkheden](lint-project.gemspec) horen bij de gem. Bouw na de volledige validatie een pakket vanuit zijn eigen map:

**Werkmap:** Repositoryroot; cd kiest daarna .tools/lint. **Shell:** POSIX shell. **Vereisten:** Volledige bronvalidatie en RubyGems. **Invoer:** Gemspec en pakketbestanden. **Wijzigt bestanden:** /tmp/lint-project.gem. **Verwacht resultaat:** Lokaal pakket gebouwd.

```sh
cd .tools/lint
gem build lint-project.gemspec --output /tmp/lint-project.gem
```

Het pakket bevat alleen `lib/`, `bin/`, `config/`, de README en de licentie, inclusief `puppet-lint-junit`, `puppet-validate-junit` en hun XML-dependency. Tests, ontwikkelgems en Puppet-modules zijn geen onderdeel van de distributie. Publicatie naar RubyGems is niet nodig; je kunt het bestand via je eigen goedgekeurde distributieroute beschikbaar maken. Een ontvangend project installeert zijn eigen dependencies en bewaart zijn eigen lockfile.

Versie `0.1.9` bevat de standaard actieve checks `project_resource_list_reuse` voor [hergebruik van resourcelijsten](#resourcelijsten-hergebruiken) en `project_resource_dependencies` voor [de opbouw van dependencies](#resource-dependencies-opbouwen). De fixes behandelen exacte herhaling, duidelijke uitbreidingen en aantoonbaar overbodige wrappers in dependency-concats. Afnemende projecten kunnen daardoor nieuwe lintmeldingen krijgen. De beschikbare `project_guarded_packages`-fix voor [package-declaraties](#pakketten-en-mappen) gebruikt `ensure_packages()` en laat conflicterende package-attributen als catalogusfout zichtbaar worden. Die gegenereerde Puppet-code vereist stdlib; de linter levert de module niet mee.

Behandel checknamen, meldingsniveaus, veilige fixresultaten, `PROJECT_LINT_MODULEPATH`, het entrypoint, de gedeelde configuratiepaden en de rapportcommando's als publieke interfaces. Verhoog de gemversie bij een uitgave en beschrijf wijzigingen die afnemers raken. Wijzigingen aan actieve regels en profielen kunnen bestaande projecten laten falen; laat afnemers zo’n update bewust uitvoeren met Bundler en hun eigen CI. Werk een Git-afnemer bij naar een gecontroleerde revisie en een pakketafnemer naar een gecontroleerde gemversie.

### Git-dependency uit de monorepo

Deze route installeert alleen de gem uit een gekozen Git-revisie. Een eventuele Puppet-moduleverzameling blijft een afzonderlijke prerequisite. De consumerroot bevat `Gemfile`, `Gemfile.lock`, `.puppet-lint.rc`, `modules/` en `manifests/site.pp`; een lokale `global-modules/` is voor deze Ruby-installatie niet vereist. Bundler vindt de geneste gemspec met `glob: '.tools/lint/*.gemspec'`. Zonder die selectie is de monoreporoot geen gemdirectory.

**Werkmap:** Nieuwe lege consumerroot. **Shell:** POSIX shell. **Vereisten:** Git, nieuwste stabiele Ruby/Bundler en toegang tot de goedgekeurde Git-/gembron. **Invoer:** Synthetisch manifest hieronder; de gekozen bestaande revisie bevat gemversie 0.1.9. **Wijzigt bestanden:** Eigen Gemfile, lockfile, configuratie, manifest en geïnstalleerde gems. **Verwacht resultaat:** Bundler kiest de geneste gemspec; de volledige profielscan eindigt met 0.

```sh
set -e
cat > Gemfile <<'RUBY'
source 'https://rubygems.org'

gem 'lint-project',
    git: 'https://github.com/DevSysEngineer/puppet-modules.git',
    ref: 'df1b222aa1fa78c19c74503866c4fda7119f8464',
    glob: '.tools/lint/*.gemspec',
    require: false
RUBY
cat > .puppet-lint.rc <<'CONFIG'
--ignore-paths=vendor/*,./vendor/*
CONFIG
mkdir -p modules manifests
printf '%s\n' '$values = concat([1], [2])' > manifests/site.pp
gem install bundler
export BUNDLE_VERSION=system
bundle install
LINT_GEM="$(bundle info --path lint-project)"
export PROJECT_LINT_MODULEPATH="$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$LINT_GEM/lib/project_lint.rb" --config "$LINT_GEM/config/puppet-lint.rc" --config .puppet-lint.rc manifests
```

Dit is een **Volledig uitvoerbaar voorbeeld** voor het gedeelde profiel met de lokale selectie. De integratietest gebruikt dezelfde `git`/`ref`/`glob`-selectie tegen een tijdelijke bare kopie van een bestaande lokale revisie. Zij maakt geen commit en is geen bewijs van netwerkbereikbaarheid of toegangsrechten op de externe Git-server.

Voor een upgrade vervang je `ref` in de eigen Gemfile door een gecontroleerde bestaande revisie, voer je `bundle update lint-project` uit en herhaal je alle eigen eindcontroles. Behoud de eigen lockfile. Meldt Bundler dat de gem niet is gevonden, controleer bronbereikbaarheid, revisie en `glob`; ontbreken daarna projectchecks, controleer het via Bundler gevonden entrypoint en het laadcommando. Zet geen credentials in de Gemfile of bron-URL.

### Gebouwd gempakket installeren

De packagebron is een lokaal gebouwd `.gem`-bestand uit een gecontroleerde checkout. Deze procedure veronderstelt geen publieke publicatie of private registry. Het pakket bevat `lib/`, `bin/`, `config/`, README en LICENSE; bronrepositorytests, Gemfile, Rakefile en Puppet-modules horen niet bij het pakket.

**Werkmap:** Repositoryroot van de gecontroleerde broncheckout; de subshell bouwt in `.tools/lint`. **Shell:** POSIX shell. **Vereisten:** Nieuwste stabiele Ruby/Bundler en de [volledige eindcontrole](#eindcontrole) van de bron. **Invoer:** `lint-project.gemspec` en de daarin geselecteerde pakketbestanden. **Wijzigt bestanden:** Alleen een tijdelijk gempakket. **Verwacht resultaat:** Een gebouwd pakket, met het pad op stdout.

```sh
set -e
LINT_PACKAGE="$(mktemp -d)/lint-project.gem"
export LINT_PACKAGE
(
    cd .tools/lint
    gem build lint-project.gemspec --output "$LINT_PACKAGE"
)
printf 'Pakket voor installatie: %s\n' "$LINT_PACKAGE"
```

**Werkmap:** Nieuwe lege consumerroot, in dezelfde shell met `LINT_PACKAGE` uit het bouwblok of met die variabele vooraf ingesteld op het ontvangen bestaande bestand. **Shell:** POSIX shell. **Vereisten:** Het gebouwde pakket, nieuwste stabiele Ruby/Bundler en toegang tot Ruby-dependencies via de goedgekeurde gembron. **Invoer:** Synthetisch manifest hieronder. **Wijzigt bestanden:** Geïnstalleerde gem en dependencies, eigen Gemfile/lockfile/configuratie/manifest. **Verwacht resultaat:** Scan met alleen het geïnstalleerde pakket en exitcode 0.

```sh
set -e
test -f "$LINT_PACKAGE"
gem install bundler
export BUNDLE_VERSION=system
gem install "$LINT_PACKAGE"
cat > Gemfile <<'RUBY'
source 'https://rubygems.org'

gem 'lint-project', '= 0.1.9', require: false
RUBY
cat > .puppet-lint.rc <<'CONFIG'
--ignore-paths=vendor/*,./vendor/*
CONFIG
mkdir -p modules manifests
printf '%s\n' '$values = concat([1], [2])' > manifests/site.pp
bundle install
LINT_GEM="$(bundle info --path lint-project)"
export PROJECT_LINT_MODULEPATH="$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$LINT_GEM/lib/project_lint.rb" --config "$LINT_GEM/config/puppet-lint.rc" --config .puppet-lint.rc manifests
bundle exec puppet-validate-junit results/parser.xml manifests/site.pp
```

Het manifest is een **Volledig uitvoerbaar voorbeeld** onder het gedeelde lintprofiel. De package-integratietests installeren in een tijdelijke gemhome met een eigen consumerbundle en controleren beide reporters, profielen, een schone scan en een overtreding zonder toegang tot niet-verpakte implementatiebestanden. De tests gebruiken lokaal beschikbare dependencies en zijn geen test van een registrypublicatie.

Voor een upgrade bouw of ontvang je een pakket met de gekozen nieuwe gemversie, installeer je het bestand, pas je de exacte versie in de eigen Gemfile aan en voer je `bundle update lint-project` plus alle eigen eindcontroles uit. Ontbreekt een executable of profiel, controleer het geïnstalleerde pakket via `bundle info --path lint-project`; een pad in de broncheckout is geen vervanging voor een ontbrekend pakketbestand. Een fout bij dependencyresolutie vraagt controle van Ruby en gemspecgrenzen. Het tijdelijke pakket mag na installatie weg; bewaar een uitgave alleen via de goedgekeurde distributieroute.


## Linter ontwikkelen en testen

<a id="linter-ontwikkelen-en-onderhouden"></a>

Dit gedeelte is bedoeld voor wijzigingen aan de linter, de configuratieroute of de ontwikkelbundle. Voor een gewone Puppet-wijziging volstaan de [werkwijze](#werkwijze-bij-een-wijziging) en de relevante codeafspraken.

### Een check toevoegen of wijzigen

Zoek eerst de bestaande codeafspraak en bepaal welk onderdeel automatisch vast te stellen is en welk onderdeel review blijft. Controleer of een standaardcheck, geïnstalleerde plugin of bestaande projectcheck het probleem al afhandelt. Breid die waar mogelijk uit; voeg geen tweede detectie- of correctiepad toe voor hetzelfde contract.

Iedere regel staat in één bestand onder [`lib/project_lint/checks/`](lib/project_lint/checks/). Dat bestand bevat de `PuppetLint.new_check(:project_...)`-registratie, de `check`-methode en een eventuele `fix(problem)`. De bestandsnaam volgt de checknaam zonder het voorvoegsel `project_`; de Ruby-module staat onder `ProjectLint::Checks`. Voeg het bestand met een gewone `require` toe aan [`lib/project_lint.rb`](lib/project_lint.rb). Er is geen aparte registratie- of wrapperlaag.

Meldingen moeten de oorzaak en een bruikbare bronpositie geven; neem geen willekeurige bronwaarden in diagnostiek of JSON op. Gebruik `[review]` als de analyse geen voldoende bewijs voor de gewenste eigenschap of correctie kan leveren.

Werk bij een gewijzigde codeafspraak de relevante regel en het [checkoverzicht](#beschikbare-projectchecks) samen bij. Geef aan wat detectie en autofix daadwerkelijk dekken en wat handmatig blijft. Verander je een algemene conventie, neem dan de regressietests en alle geraakte first-party code in dezelfde wijziging mee. De [documentatie-indeling](../../AGENTS.md#lint-documentation-maintenance) bepaalt waar nieuwe kennis thuishoort.

Voeg tooltests toe onder [`.tools/lint/test/`](test/) die geldig en ongeldig gebruik, grensgevallen en de grenzen van de analyse controleren. Gebruik de [testhandleiding](#tests-uitvoeren-en-uitbreiden) voor discovery en testscope. De tests gebruiken het echte library-entrypoint en de native configuratie. Wijzig je packaging, configuratie of de CLI-aanroep, test dan ook installatie, exitcodes, geladen regels en isolatie van persoonlijke opties vanuit een apart project.

Voer tijdens het werk `bundle exec rake test:lint` uit en sluit af met de [volledige eindcontroles](#werkwijze-bij-een-wijziging). Tests van linteroutput mogen de parser gebruiken om geldige correcties te bewijzen; algemene module-, script- en monitoringtests blijven buiten deze testsuite. Voor autofix gelden de aanvullende criteria onder [Veilige autofixes ontwikkelen](#veilige-autofixes-ontwikkelen).

### Technische werking van de checks

De interne gem maakt de runtime-afhankelijkheden, laadpaden en gedeelde profielen beschikbaar aan andere projecten zonder dat zij onze ontwikkelbundle hoeven te gebruiken. De gem volgt de [RubyGems-libraryconventies](https://guides.rubygems.org/make-your-own-gem/): een entrypoint, eigen code onder `ProjectLint` en runtime-afhankelijkheden in de [gemspec](lint-project.gemspec). Het root-Gemfile en Rakefile blijven verantwoordelijk voor de ontwikkeling van alle repositorytools. Een tweede ontwikkelbundle binnen de gem is niet nodig. De [Bundler-documentatie](https://bundler.io/guides/git.html) beschrijft hoe dezelfde gem vanuit een checkout of Git-bron kan worden gebruikt.

```text
.tools/lint/
├── lint-project.gemspec
├── bin/
│   ├── puppet-lint-junit     # Omzetting van native lintuitvoer naar JUnit XML.
│   └── puppet-validate-junit # Native parservalidatie met JUnit XML per manifest.
├── lib/
│   ├── project_lint.rb
│   └── project_lint/
│       ├── checks/          # Registratie, detectie en autofix per regel.
│       └── ...              # Gedeelde domeinlogica en complexe bronanalyse.
├── config/                  # Gedeelde Puppet-lint- en RuboCop-profielen.
├── test/                    # Gedragstests van deze gem.
└── README.md
```

Puppet-lint blijft de lintengine. De checks gebruiken zijn tokens, `notify`, suppressions, `PuppetLint::NoFix`, `add_token` en `remove_token`. De native CLI bepaalt opties, bestandsselectie, detectie en correcties. Eenvoudige tokenchecks, zoals de controle van Puppet-URLs, hebben geen AST nodig.

[`PuppetJunit`](lib/project_lint/puppet_junit.rb) verwerkt uitsluitend de native JSON-uitvoer voor de [JUnit-rapportage](#lintrapporten-maken). Het uitvoerbare commando `puppet-lint-junit` komt uit dezelfde gem. De omzetter gebruikt `builder` voor XML-escaping, neemt alleen diagnostische velden op en wijzigt geen lintconfiguratie. De [reportertests](test/puppet_junit_test.rb) controleren geldige en ongeldige invoer, unieke testcases en foutdetails; de [pakkettest](test/external_junit_test.rb) controleert de volledige pipe vanuit een onafhankelijk geïnstalleerde gem.

[`PuppetValidate`](lib/project_lint/puppet_validate.rb) roept voor ieder aangeleverd manifest de native parser-CLI uit de actieve bundle aan. Hij voert geen eigen syntaxanalyse uit en gebruikt geen shell om bestandspaden door te geven. [`JunitReport`](lib/project_lint/junit_report.rb) levert de gedeelde XML-opbouw voor beide rapportcommando's. De [validatiereportertests](test/puppet_validate_test.rb) controleren onder meer lege selecties, ontbrekende bestanden en padnamen; de [pakkettest](test/external_validate_test.rb) verifieert succesvolle en mislukte parseruitvoering en rapportage vanuit een zelfstandig project. De selectie van repositorybestanden hoort bij `validate:puppet` in de root-Rakefile.

[`Ast`](lib/project_lint/ast.rb) voegt alleen de structurele informatie van de OpenVox-parser toe: declaraties, expressies, resources en hun omliggende scopes. De tokenindexen van Puppet-lint leveren die volledige structuur niet. Alle structurele checks delen één AST voor de huidige lintinvoer; een nieuwe scan vervangt die analyse, ook bij gelijke tekst in een ander bestand. De analyse voert geen Puppet-functies of catalogi uit. Alleen echte `Puppet::ParseError`-meldingen worden omgezet naar een syntaxfout; programmeerfouten blijven fouten. Een onbekende constructie krijgt waar nodig een reviewmelding.

Gedeelde helpers beschrijven concrete begrippen, zoals resource-attributen, commentaargrenzen, variabeleafhankelijkheden en modulepaden. Checks met een complexe zelfstandige analyse, zoals backendherkomst of shellescaping, houden die analyse apart. Methoden die alleen een check ondersteunen staan bij die check. Een grotere analyse kan binnen hetzelfde bestand worden onderverdeeld, bijvoorbeeld in commentaaropmaak, regelbreedte en suppressions. Houd die onderdelen inhoudelijk samenhangend en blijf de bestaande RuboCop-regels volgen. Geef een nieuwe helper pas een gedeelde plek wanneer bestaande afnemers die complexiteit daadwerkelijk delen.

Het entrypoint laadt eerst `puppet-lint` en daarna de eigen checks. Gebruik daarom `--load` zoals in de voorbeelden, of `require 'project_lint'` vanuit Ruby. Automatische registratie via `lib/puppet-lint/plugins/` wordt bewust niet gebruikt: Puppet-lint laadt gemplugins met `load`, in gemvolgorde. De externe trailing-comma-plugin bewaart oorspronkelijke tokenankers die referencefixes kunnen verwijderen. Door het projectentrypoint na de engine te laden, zijn de upstream-fixes al geregistreerd en blijven beide transformaties bruikbaar. De integratietests bewaken deze laadroute en herhaald laden veroorzaakt geen dubbele registraties. De [native API](https://puppet-lint.com/developer/api/) en de onderhouden [parameterplugin](https://github.com/voxpupuli/puppet-lint-param-types) zijn het uitgangspunt voor nieuwe checks; afhankelijkheden en hun werkelijk geïnstalleerde implementatie bepalen de grenzen van autofix.

[`ModuleResolver`](lib/project_lint/module_resolver.rb) leest het modulepad bij het maken van een analyse, zodat een volgende scan gewijzigde environmentinstellingen kan gebruiken. Gevonden bestanden worden alleen binnen die analyse gecachet en bij gewijzigde bestandsmetadata opnieuw gelezen. Er zijn geen modulepaden die tijdens `require` als globale constants worden vastgelegd. De regels voor vindbaarheid staan bij [Aanroepen van modules controleren](#aanroepen-van-modules-controleren).

#### Omvang en validatiestructuur

`project_positive_flow` meldt een `if`-tak die minder codestructuur bevat dan de bijbehorende `else`. Een opdracht telt als één onderdeel; geneste blokken, resource-instanties, attributen en elementen in arrays, hashes en selectors tellen mee. Commentaar, witruimte, de lengte van strings en gewone functieargumenten tellen niet als extra opdrachten. Naast deze algemene vergelijking controleert dezelfde check de afsluitende structuur van validaties met `fail(...)` en `warning(...)`.

De validatiecontrole herkent rechtstreekse Puppet-aanroepen van `warning()` en `fail()`, ook met een voorloop-`::`. Strings, commentaar, parameterdefaults, afzonderlijke functiedefinities en functies zoals `example::warning()` vallen erbuiten. De positie wordt bepaald via de omliggende opdrachten en blokken, niet via de fysieke regelvolgorde.

#### Classcontroles en vindbare afnemers

`project_class_check_reuse` controleert letterlijke classnamen in de body van iedere class en ieder defined type afzonderlijk. De check telt echte variabelereferenties, inclusief interpolatie en gekwalificeerde verwijzingen vanuit vindbare manifests in het modulepad. Rechtstreeks gebruik via `@variabele` in statisch benoemde ERB-templates en `inline_template` telt ook mee. Commentaar, gewone stringtekst en gelijknamige lokale lambdavariabelen tellen niet als hergebruik. Dynamische classnamen, parameterdefaults, andere resourcetypen en indirecte template- of functielookups vallen buiten deze analyse; beoordeel die bij de review.

Voor hergebruik uit een gecontroleerde class onderzoekt de check de geldige tak van een omvattende `if`, inclusief haakjes en `and` in de voorwaarde. Hij zoekt de class eerst in de huidige bron en daarna via het modulepad. Eén rechtstreekse toekenning van dezelfde classcontrole aan een classvariabele levert een `[review]`-melding op. Toekenningen in lambda's of geneste declaraties, meervoudige toekenningen en samengestelde of omgekeerde resultaten tellen niet mee. Een `or`, negatieve controle, `else` of controle in een andere declaratie bewijst geen beschikbaarheid. Ook deze melding heeft geen autofix: voorwaardelijke toekenningen en verschillen in evaluatiemoment vragen beoordeling van de effectieve catalogus.

#### References en relatiecontext

`project_resource_references` gebruikt de Puppet-AST om directe elementen van iedere array per resourcetype te groeperen. De analyse loopt via de omvattende expressies naar de relatiecontext; ingebouwde datatypen en lokale typealiases worden uitgesloten. De correctie hergebruikt de oorspronkelijke titeltokens in de eerste reference en verwijdert de overige references van dat type elk met hun voorafgaande komma. Daardoor blijven tussenliggende elementen en fixes van andere checks behouden, ook wanneer meerdere typen door elkaar staan. De regels voor sortering, dubbele titels en het verwijderen van de buitenste array staan bij [Resource references](#resource-references).

#### Voorbereiding van voorwaarden

`project_if_sections` volgt opeenvolgende toekenningen terug vanaf de variabelen in de voorwaarde, ook als een afhankelijkheid via een andere variabele loopt. De voorwaarden van aansluitende `elsif`-takken tellen mee bij dezelfde voorbereiding. Een losstaande toekenning of andere opdracht onderbreekt die reeks. Commentaar bij een eerder blok of een bovenliggende voorwaarde geldt niet voor een geneste `if`. Bij een toekenning zoals `$result = if ...` staat de toelichting boven de toekenning en eventuele voorbereiding. De check deelt de analyse van variabeleafhankelijkheden met `project_variable_sections`; de betekenis van de toelichting blijft onderdeel van de inhoudelijke review.

#### Hints voor variabelegroepen

Ontbreekt de toelichting bij de eerste variabele na `{`, dan kan de melding ook naar een latere groep in hetzelfde blok verwijzen. Daarvoor moeten de eerste toekenningen dezelfde buitenste functie aanroepen, bijvoorbeeld `stdlib::shell_escape(...)`. De check kijkt alleen voorbij andere toekenningen en stopt zodra de oorspronkelijke variabele wordt gebruikt. Functieaanroepen met een eigen lambdablok vormen zelf geen kandidaat. De melding noemt de regel van het bestaande commentaar, zodat je kunt beoordelen of samenvoegen de code duidelijker maakt. De hint is geen bewijs van inhoudelijke samenhang: controleer ook of de volgorde van uitvoeren mag veranderen.

#### Backendselectie en wrappers

`project_monitoring_backend` volgt de centrale packagewaarde door toekenningen en voorwaarden. Parameters die aantoonbaar als `package` worden doorgegeven aan een monitoringaanroep tellen ook mee. De check herkent lokale wrappers en statisch benoemde wrappers in het ingestelde modulepad, inclusief classes via `include`, `contain` en `require`. Hij meldt de oorspronkelijke backendselectie één keer, ook als meerdere aanroepen ervan afhangen. Gewone pakketkeuzes zonder die relatie vallen buiten de check; `monitoring_custom` zelf blijft verantwoordelijk voor de concrete backendimplementatie.

### Veilige autofixes ontwikkelen

Begin bij de gebruikte bundle: controleer `bundle exec puppet-lint --no-config --config .puppet-lint.rc --version` en bekijk de implementatie met `bundle show puppet-lint`. Volg de [afspraken voor hergebruik en autofixontwikkeling in `AGENTS.md`](../../AGENTS.md#linting-and-autofix).

De correctie mag geen informatie verzinnen, ontwerpkeuze maken of commentaar verliezen. Controleer ook dat het resultaat geldige Puppet-code is en dat dezelfde regel na de correctie geen melding meer geeft. Bewijs dit voor de hele constructie die je wijzigt; alleen de gemelde regel bekijken is niet voldoende.

`project_guarded_packages` gebruikt de gedeelde AST voor guards, scopes en attribuutvergelijking. De tokenanalyse bepaalt alleen de te vervangen gebieden en de concrete opmaak. De fix draait na die van de bestaande checks en leest de actuele attribuuttokens, zodat eerdere quote- en kommafixes behouden blijven. De [voorwaarden voor packagegroepen](#pakketten-en-mappen) beschrijven wanneer het vervangingsplan wordt geweigerd. De diagnose noemt de packagenamen en geeft controltekens met escapes weer; attribuutwaarden en AST-objecten worden niet aan de melding toegevoegd.

Implementeer `fix(problem)` naast `check` in de betreffende `ProjectLint::Checks`-module. Registreer die module in hetzelfde bestand met `PuppetLint.new_check(:project_...) { include CheckModule }`, zoals de bestaande checks doen. Bewaar tijdens `check` de betrokken tokenobjecten en de voorwaarden voor correctie. Geef de melding een index naar die context, zoals de bestaande projectchecks doen, zodat JSON-diagnostiek geen bronwaarden bevat. Controleer alle voorwaarden voordat je tokens wijzigt. Gebruik `PuppetLint::NoFix` wanneer die voorwaarden niet gelden; Puppet-lint behoudt dan de oorspronkelijke melding.

Gebruik `add_token`, `remove_token` en de eigenschappen van bestaande tokens voor de correctie. Hergebruik tokens die andere checks ook kunnen aanpassen en bepaal benodigde afstanden uit de actuele tokeninhoud. Regel- en kolomnummers blijven tijdens de fixfase bij de oorspronkelijke bron horen. De gedeelde helpers in [`TokenHelpers`](lib/project_lint/token_helpers.rb) ondersteunen tokengebieden en witruimte; zij parsen of herschrijven geen volledig bestand.

Puppet-lint voert eerst alle checks uit en daarna de fixes. Houd daarom rekening met eerder gewijzigde of verwijderde tokens. De parameteruitlijning vernieuwt vlak vóór haar fixes de meldingen op de bewaarde tokens via de native `run`-methode: een eerdere komma- of tabcorrectie kan de breedte van een type veranderen. De native afhandeling van `lint:ignore` en `fix(problem)` blijft daarbij actief. Een correctie over meerdere regels moet ook controleren of zij een genegeerd deel zou veranderen.

Voeg regressietests toe onder [`.tools/lint/test/`](test/) voor detectie zonder wijziging, exacte uitvoer, een schone hercontrole en een ongewijzigde tweede fixrun. Test ook ongeschikte invoer, genegeerde meldingen, comments, strings, meerdere problemen, geneste constructies en samenwerking met de actieve upstream-checks. Test de native CLI op tijdelijke bestanden om de schrijfhandeling en exitcodes te controleren. Parservalidatie van de geproduceerde uitvoer hoort bij het fixcontract; een algemene syntaxsuite voor modules hoort niet bij deze tooltests.

De normale CLI-aanroep en CI blijven alleen controleren. Schakel `fix` uitsluitend in bij een expliciete correctiestap en voeg geen tweede formatter of automatische commitstap toe.

### Tests uitvoeren en uitbreiden

Voer tests uit vanuit de repositoryroot, na [installatie van de ontwikkelbundle](#gems-installeren):

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alle tooltests of alleen de lintertests. **Wijzigt bestanden:** JUnit-testresultaten. **Verwacht resultaat:** Niet-lege selectie zonder failures, errors of onverklaarde skips.

```sh
bundle exec rake test
bundle exec rake test:lint
```

`test` en de standaardtaak ontdekken `.tools/**/test/**/*_test.rb` recursief. `test:lint` selecteert alleen `.tools/lint/test/**/*_test.rb`. De tests staan bij de tool die ze controleren; de roottaak blijft het gezamenlijke startpunt voor CI. Controleer het gerapporteerde aantal tests en eventuele skips. Een geslaagde taak zonder uitgevoerde tests is onvoldoende.

De bestaande testhelper gebruikt `minitest-reporters` voor console-uitvoer en JUnit XML uit dezelfde uitvoering. De rapporten staan per testklasse onder `.tools/lint/results/TEST-*.xml`, ook bij een gewone testfout. De helper bepaalt dit pad vanuit zijn eigen locatie en maakt de uitvoermap aan als die ontbreekt. Een mislukte assertion of onverwachte fout in een test blijft een foutcode opleveren.

De reporter vervangt bij iedere uitvoering alleen de `TEST-*.xml`-bestanden in die map, zodat de rapporten de laatste testselectie weergeven en de lint- en validatierapporten behouden blijven. Met `MINITEST_REPORTERS_REPORTS_DIR` kun je via de reporter een andere uitvoermap kiezen, bijvoorbeeld voor een tijdelijke controle. De rapporten worden niet gecommit.

Een gewone checktest erft rechtstreeks van `Minitest::Test` en gebruikt [`test_helper.rb`](test/test_helper.rb) voor de native lintaanroep. Zet korte Puppet-invoer en verwachte meldingen in de test zelf. De gedeelde `findings`-helper selecteert één regel via de publieke configuratie en herstelt die configuratie na de aanroep. Er zijn geen gespecialiseerde testbasisklassen of fixtures die op de naam van de testmethode worden opgezocht.

```ruby
require_relative 'test_helper'

class ArraysTest < Minitest::Test
  include LintTestSupport

  def test_array_addition_requires_concat
    problems = findings('$values = [1] + [2]', :project_arrays)
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
    assert_includes problems.first[:message], 'concat'
    assert_empty findings('$values = concat([1], [2])', :project_arrays)
  end
end
```

Gebruik `assert_fix(before, after, :project_check_name)` voor detectie, exacte correctie, parservalidatie van de gecorrigeerde uitvoer, een schone hercontrole en een ongewijzigde tweede fixrun. Controleer onveilige constructies ook met `fix: true`: hun invoer moet behouden blijven. De tests voor [referencefixes](test/reference_merging_test.rb) en [documentatie](test/documentation_structure_test.rb) laten beide kanten zien. De [interactietests](test/cross_check_autofix_test.rb) controleren gedeelde tokengebieden met meerdere checks.

De `cli_*_test.rb`-bestanden controleren native bestandsuitvoer, exitcodes, configuratie en suppressions. [`external_project_test.rb`](test/external_project_test.rb) bouwt en installeert de echte `.gem` in een tijdelijk project met een eigen bundle. [`external_ruby_test.rb`](test/external_ruby_test.rb) controleert dat dezelfde dependency ook RuboCop en het gedeelde Ruby-profiel beschikbaar maakt, zonder aparte RuboCop-regel in de Gemfile. De tests gebruiken reeds geïnstalleerde dependencies en `bundle install --local`; ze hebben geen netwerk, productiegegevens of beheerde hosts nodig. Grotere of hergebruikte Puppet-fragmenten staan als afzonderlijke `.pp`-fixtures bij de tests. De expliciete `fixture`-aanroep wijst naar dat bestand; `fixture_set` leest een benoemde verzameling en faalt als die leeg is. Korte invoer staat direct in Ruby. De CLI-tests hebben daarnaast synthetische Ruby-invoer voor het laden van plugins en persoonlijke configuratie.

Onderzoek een fout eerst bij de vermelde input en assertion. Voer de betreffende test tijdens het ontwikkelen apart uit, bijvoorbeeld `bundle exec ruby .tools/lint/test/reference_merging_test.rb`, en sluit af met alle tooltests. Voor de GitHub-uitvoervorm kun je `GITHUB_ACTION=synthetic_test bundle exec rake test` gebruiken; diagnostiektellingen moeten in beide uitvoervormen gelijk blijven.

Test uitsluitend de toolcontracten. Puppet-fragmenten om een lintmelding of autofix te controleren horen hier wel thuis; algemene module-, catalogus-, template-, script- en monitoringtests niet. Gebruik daarvoor bestaande validators en tijdelijke controles buiten de repository, volgens [de testscope](../../AGENTS.md#test-scope). Bewaar een fixture alleen als een groter of hergebruikt scenario daarmee duidelijker wordt.

### Versies bijwerken

Bij de eerste installatie gebruikt Bundler de versies uit de lockfile. Wil je die combinatie bijwerken, voer dan het volgende uit vanuit de hoofdmap van deze repository, met de nieuwste stabiele Ruby actief:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Nieuwste stabiele Ruby en bewuste opdracht tot dependencyupdate. **Invoer:** Eigen Gemfile en bestaande lockfile. **Wijzigt bestanden:** Bundlerinstallatie, gems, Gemfile.lock en rapporten. **Verwacht resultaat:** Bijgewerkte combinatie gecontroleerd; diff van lockfile ter review.

```sh
gem install bundler
BUNDLE_VERSION=system bundle update --all
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec rubocop --config .rubocop.yml
bundle exec rake test
git diff -- Gemfile.lock
```

[`bundle update --all`](https://bundler.io/man/bundle-update.1.html) kiest de nieuwste stabiele gems die onderling en met de ingestelde Ruby-versie passen. Gems kunnen zelf beperkingen aan hun afhankelijkheden stellen. Gebruik geen prereleases voor de gewone ontwikkelomgeving.

Controleer de gewijzigde lockfile en eventuele codeaanpassingen in de review. `bundle install` gebruikt daarna steeds die geteste combinatie.

Werk op macOS Ruby bij met `brew update` en `brew upgrade ruby`. Open daarna een nieuwe terminal, zodat ook het pad voor gemcommando's opnieuw wordt bepaald, en volg opnieuw [Gems installeren](#gems-installeren). Draai na een Ruby-update de volledige lintscan en testsuite.

### Eigen tooltests

Test eigen gereedschap onder `.tools/<tool-name>/test/`, met bestandsnamen die eindigen op `_test.rb`. Zet gedeelde voorbereiding in `test_helper.rb` wanneer meerdere tests die nodig hebben en bewaar grotere synthetische invoer onder `test/fixtures/`. Fixtures mogen zo nodig per gedrag worden gegroepeerd. Gebruik korte invoer direct in de test en los paden op vanaf het testbestand, zodat de uitvoering niet afhangt van de huidige werkmap.

De tests staan bij de tool die ze controleren; er is geen afzonderlijke centrale `.tools/test/` of `.tools/tests/`. Houd require-paden, fixtures, taken, CI en documentatie in overeenstemming met die indeling en behoud de testdekking. Module- en catalogustests horen bij de eigen validatie van het afnemende project en staan buiten `.tools/`.

Gebruik voor Ruby-tooltests Minitest en Rake uit de eigen ontwikkelbundle. Voeg deze dependencies alleen toe als je zulke tests hebt:

```ruby
gem 'minitest'
gem 'rake'
```

Voer daarna `bundle install` uit. In een project met alleen tooltests kan de root-Rakefile de selectie als volgt vastleggen:

```ruby
# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |task|
  task.pattern = '.tools/**/test/**/*_test.rb'
  task.warning = false
end

task default: :test
```

Voer vanuit de projectroot `bundle exec rake test` uit, lokaal en in CI. Controleer het aantal uitgevoerde tests; een geslaagde taak met nul tests bewijst niets. Een aanvullende `test:<tool-name>`-taak selecteert alleen `.tools/<tool-name>/test/**/*_test.rb`. Heeft het project al een verzameltaak voor andere tests, voeg de toolselectie dan als afzonderlijke taak toe en behoud de bestaande dekking en het standaardgedrag.

Laat de selectie alleen de eigen tools doorlopen. De tests onder `global-modules/.tools/lint/test/` horen bij de ontwikkeling van de gedeelde gem en draaien in de CI van die repository. Het afnemende project hoeft die suite niet te kopiëren of via zijn eigen Rakefile te laden. Wie alleen de linters gebruikt, heeft daarvoor geen eigen testmap of testtaak nodig.

#### Testselectie en uitvoeropties

De roottaak hierboven ondersteunt de standaardopties van Rake en Minitest. In deze voorbeelden is `inventory` een eigen tool; vervang de paden en testnamen door die van jouw project.

| Doel | Commando |
| --- | --- |
| Alle eigen tooltests uitvoeren | `bundle exec rake test` |
| Eén testbestand uitvoeren | `bundle exec rake test TEST=.tools/inventory/test/inventory_test.rb` |
| Testnamen tonen | `bundle exec rake test TESTOPTS='--verbose'` |
| Eén testnaam of patroon selecteren | `bundle exec rake test TESTOPTS='--name=/inventory/'` |
| De testvolgorde reproduceerbaar maken | `bundle exec rake test TESTOPTS='--seed=12345'` |

Geef optiewaarden binnen `TESTOPTS` mee met `=`, zoals `--name=/inventory/`; de testloader van Rake behandelt een losse waarde als bestandsnaam. Gebruik een gerichte selectie tijdens het onderzoeken van een fout. CI voert de volledige bedoelde testtaak uit.

Testmethoden behouden hun gebruikelijke `test_...`-namen; namen, aantallen en skips blijven herkenbaar in de console en de rapporten.

#### JUnit-rapportage instellen

De voorkeur is console-uitvoer en JUnit XML uit dezelfde testuitvoering. Voeg voor de Minitest-suite `gem 'minitest-reporters'` toe aan de eigen root-Gemfile naast Minitest en Rake, voer `bundle install` uit en neem de lockfile op in versiebeheer. De reporter is een dependency van je eigen ontwikkelbundle; `lint-project` installeert hem niet voor afnemers.

Configureer de reporters in de eigen `.tools/<tool-name>/test/test_helper.rb`. Het onderstaande voorbeeld gaat uit van die mapdiepte, bepaalt de projectroot vanuit de helper en schrijft naar de [gekozen rapportmap](#rapportmap-kiezen):

```ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/reporters'

project_root = File.expand_path('../../..', __dir__)
report_dir = File.expand_path(ENV.fetch('PROJECT_REPORT_DIR', '.tools/quality/results'), project_root)
reporters = [
  Minitest::Reporters::DefaultReporter.new,
  Minitest::Reporters::JUnitReporter.new(report_dir)
]
Minitest::Reporters.use!(reporters)
```

Laat de testbestanden deze helper laden met `require_relative 'test_helper'` en behoud de voorbereiding en assertions die de eigen tests nodig hebben. Eén uitvoering configureert de reporters eenmaal. Gebruikt de roottaak tests van meerdere eigen tools, laat hun helpers dezelfde reporterinitialisatie laden uit de gedeelde testhulp die dat project daarvoor gebruikt; herinitialiseer de reporters niet per tool.

`bundle exec rake test` toont de testuitslag, maakt de gekozen uitvoermap zo nodig aan en schrijft per testklasse een `TEST-*.xml`-bestand. De reporter vervangt alleen die testbestanden, zodat een gerichte testselectie een beperkt rapport oplevert en de lint- en validatierapporten behouden blijven. Staat de helper elders, pas dan alleen de berekening van `project_root` aan. De rapportmap hoeft niet naast de helper of in een map met de naam `lint` te staan.

Voor alleen de tests kun je de native reporteroptie `MINITEST_REPORTERS_REPORTS_DIR` gebruiken. Die gaat vóór het aan de reporter meegegeven pad en verandert de lint- en validatierapportpaden niet; laat dan ook het testartifact en de testsamenvatting naar die aparte testmap wijzen. Mislukte tests behouden hun foutcode; een JUnit-bestand maakt een mislukte uitvoering niet succesvol.

Gebruikt je project een ander testframework, behoud dan de eigen testtaak en gebruik de JUnit-reporter van dat framework. Pas het rapportpad in de [CI-configuratie](#controle-in-ci) daarop aan.

## Documentatiecontract voor maintainers

Gebruik dit contract wanneer je een regel, check of gebruiksprocedure in deze handleiding bijwerkt. De algemene afspraken voor een volledige inhoudsopgave en samenhang binnen ieder onderwerp staan in [`AGENTS.md`](../../AGENTS.md#markdown). Het onderstaande schema bepaalt welke informatie iedere Puppet-regel daarnaast moet bevatten.

Iedere onafhankelijke Puppet-regel krijgt een eigen `###`- of `####`-subsectie. Gebruik de onderstaande velden exact in deze volgorde; laat geen veld leeg. Een regel kan meerdere checks hebben en een check meerdere regels: verbind ze met interne links, zonder een tweede regelnummering.

```markdown
**Norm**
**Herkomst**
**Toepassingsgebied**
**Automatische controle**
**Detectiegrenzen**
**Meldingen en severity**
**Autofix**
**Autofixvoorwaarden**
**Toegestane uitzonderingen**
**Suppressions**
**Onjuist voorbeeld**
**Correct voorbeeld**
**Grensgevallen**
**Handmatige review**
**Verificatie**
```

Koppen die uitsluitend regels groeperen dragen `<!-- lint-rule-group -->`; zij bevatten zelf geen tweede norm. De structuurtest controleert ieder overig regelblok op het volledige schema, ook wanneer een veld geheel ontbreekt.

`Herkomst` is `Projectregel`, `Upstreamregel`, `Projectspecificatie van upstream` of `Nog niet vastgesteld`; bij upstream hoort een bronverwijzing. De laatste waarde verwijst naar een open verificatiepunt in de oplevering. `Automatische controle` noemt de exacte checknamen of letterlijk `Geen automatische controle`. Beschrijf bij iedere meldingsvariant de trigger, werkelijke severity en variabele tekstdelen. `[review]` is een tekstlabel, geen severity.

`Autofix` is per variant `Geen`, `Voorwaardelijk` of `Alle gedocumenteerde gevallen`, onderbouwd door uitvoering. Beschrijf alle correcties en weigeringsvoorwaarden. Een gemiste detectie is geen toegestane uitzondering. Suppressions noemen naam, syntax, plaats en begrenzing of verbieden suppressie expliciet. Gebruik `Geen` of `Niet van toepassing` uitsluitend met een concrete reden; ontbrekend bewijs krijgt `Nog niet vastgesteld` en een open punt.

Label voorbeelden als `Fragment`, `Volledig uitvoerbaar voorbeeld` of `Handmatig reviewscenario`. Een fragment kan uitsluitend voor benoemde checks groen zijn. Controleer juiste en onjuiste varianten, elke uitzonderings- en begrenzingscategorie, exacte fixes, hercontrole en een ongewijzigde tweede fixrun. Volledige voorbeelden slagen onder het volledige benoemde profiel. Handmatige normen benoemen de concrete reviewstappen en beoordelingscriteria.

Het projectcheckregister staat tussen `<!-- BEGIN PROJECT CHECK REGISTRY -->` en `<!-- END PROJECT CHECK REGISTRY -->`. Gebruik exact de kolommen `Check`, `Actief in repositoryprofiel`, `Actief in gedeeld profiel`, `Meldingsvarianten`, `Autofix` en `Regeluitleg`. Iedere geregistreerde projectcheck heeft één rij; controleer ontbrekende, onbekende en dubbele namen afzonderlijk. Gemengde fixdekking heet `Per meldingsvariant` en verwijst naar de uitwerking.

Werk bij gewijzigde checks, diagnostics, severity, defaults, autofixes, suppressions, configuratie, dependencies, reporters of consumerinterfaces de betrokken velden, registerrijen, procedures en tooltests samen bij. Onderbouw een conclusie zonder documentatie-impact met de daadwerkelijk beoordeelde interfaces. Houd registratie en activatie afzonderlijk, controleer versieclaims tegen gemspec en lockfile en test gewijzigde importroutes ieder in een onafhankelijk consumerproject.

Vermeld vóór ieder procedureblok `Werkmap`, `Shell`, `Vereisten`, `Invoer`, `Wijzigt bestanden` en `Verwacht resultaat`. Definieer alle variabelen en vervangbare paden vooraf. Bij gewijzigde context begint een nieuw contextblok. Behoud inkomende ankers zonder dubbele id's. Leg verplaatste, samengevoegde en gecorrigeerde verplichtingen, uitzonderingen, waarschuwingen en gebruiksroutes met hun vorige en nieuwe locatie en bewijs vast in de oplevering, niet in een nieuw repositorydocument. Automatische tests bewaken inventarissen, links en uitvoercontracten; inhoudsbehoud en begrijpelijkheid blijven handmatige review.

## Problemen oplossen

| Probleem | Controle en herstel |
| --- | --- |
| Bundler mist de gem of een executable | Controleer Ruby, `Gem.bindir`, PATH en de eigen Gemfile. Installeer het pakket of configureer de gembron en voer `bundle install` uit. |
| Projectchecks ontbreken | Controleer `bundle show lint-project` en gebruik `--load` vóór andere projectopties. `--list-checks` moet de `project_*`-checks tonen. |
| Persoonlijke opties hebben invloed | Gebruik `--no-config` vóór de expliciete configuratiebestanden. |
| Een scan slaagt terwijl eigen code fout is | Controleer of alle eigen manifests geselecteerd zijn. Probeer tijdelijk `$values = [1] + [2]`; verwacht `project_arrays` en een foutcode. `concat([1], [2])` hoort die melding op te lossen. |
| Een onjuiste aanroep geeft geen melding | Controleer modulepad, modulevolgorde en manifestlocatie; valideer de catalogus voor gedrag dat lint niet kan bewijzen. |
| De lokale configuratie ontbreekt | Herstel `.puppet-lint.rc`; vertrouw niet op de native CLI om een ontbrekend optiebestand te melden. |

## Eindcontrole

Volg de volledige [werkwijze](#werkwijze-bij-een-wijziging). Een beperkte scan of geslaagde rapportconversie vervangt geen vereiste controle. Noteer ieder commando, exitcode, rapport en eventuele beperking afzonderlijk. Laat gevalideerde wijzigingen in de werkboom voor menselijke review en commit.
