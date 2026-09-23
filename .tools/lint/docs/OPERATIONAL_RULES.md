# Operationele Puppet-regels en reviewcriteria

Dit bestand bevat de aanvullende Puppet-regels voor runtimegedrag, beheerde hosts en operationele integraties. Volg bij iedere Puppet-wijziging de toepasselijke algemene regels uit [CODE_RULES.md](CODE_RULES.md). Raakt je wijziging beheerde bestanden of mappen, eigenaarschap of rechten, beveiliging, systemd of services, shellcode of shelltemplates, runtime-tools of operationele dependencies, of monitoringchecks en hun registratie, pas dan daarnaast de relevante regels uit dit bestand toe. Deze operationele regels vervangen de algemene coderegels nooit.

Raakt je wijziging ook commentaar, Puppet Strings of documentatie van Puppet-interfaces, volg dan daarnaast de relevante regels uit [DOCUMENTATION_RULES.md](DOCUMENTATION_RULES.md). Bij zo'n wijziging gelden dus de toepasselijke regels uit alle drie regelsbestanden.

De [linthandleiding](../README.md) beschrijft het gebruik, de installatie, de configuratie en het onderhoud van de tooling. Een groene lintscan bewijst niet dat alle handmatige regels zijn nageleefd. Ontbrekende automatische detectie vormt geen uitzondering op een regel.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Bestanden en beveiliging](#bestanden-en-beveiliging)
  - [Templates en bestandsbronnen](#templates-en-bestandsbronnen)
  - [Door Puppet beheerde inhoud markeren](#door-puppet-beheerde-inhoud-markeren)
  - [Beheerhelpers op de gedeelde locatie installeren](#beheerhelpers-op-de-gedeelde-locatie-installeren)
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
  - [Firewallconfiguratie bij de deployment houden](#firewallconfiguratie-bij-de-deployment-houden)
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
  - [Interpreter en shellcompatibiliteit](#interpreter-en-shellcompatibiliteit)
  - [Shellscripts in uitvoervolgorde opbouwen](#shellscripts-in-uitvoervolgorde-opbouwen)
  - [Externe commando’s rechtstreeks vinden](#externe-commandos-rechtstreeks-vinden)
  - [Shellcode opmaken en benoemen](#shellcode-opmaken-en-benoemen)
  - [Shellargumenten en runtime-instellingen verwerken](#shellargumenten-en-runtime-instellingen-verwerken)
  - [Shellhelpers op een herkenbare taak afbakenen](#shellhelpers-op-een-herkenbare-taak-afbakenen)
  - [Shellbuffers en tijdelijke bestanden kiezen](#shellbuffers-en-tijdelijke-bestanden-kiezen)
  - [Tekstbuffers en substitutiemetadata opbouwen](#tekstbuffers-en-substitutiemetadata-opbouwen)
  - [Runtime-tools op hun functie beoordelen](#runtime-tools-op-hun-functie-beoordelen)
  - [Puppet-waarden rechtstreeks in shelltemplates invoegen](#puppet-waarden-rechtstreeks-in-shelltemplates-invoegen)
  - [Daemonconfiguratie als invoerbron behouden](#daemonconfiguratie-als-invoerbron-behouden)
- [Monitoringchecks](#monitoringchecks)
  - [Checkexecutables onafhankelijk van targets delen](#checkexecutables-onafhankelijk-van-targets-delen)
  - [Monitoring onafhankelijk van de waargenomen taak houden](#monitoring-onafhankelijk-van-de-waargenomen-taak-houden)
  - [Vastgestelde afwijkingen en onvolledige inspecties onderscheiden](#vastgestelde-afwijkingen-en-onvolledige-inspecties-onderscheiden)
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

## Bestanden en beveiliging

<!-- lint-rule-group -->

### Templates en bestandsbronnen

<!-- lint-rule-group -->

### Door Puppet beheerde inhoud markeren

**Norm**

Geef ieder bestand waarvan Puppet de inhoud beheert een `Managed by puppet`-header, ongeacht of de inhoud uit inline content, een template, een statische bron of samengevoegde fragmenten komt. Gebruik voor formaten met hashcommentaar exact `# Managed by puppet`; gebruik anders de eigen commentsyntaxis van het formaat. De header staat aan het begin, direct na een verplichte shebang of formaatheader.

Laat de header alleen weg wanneer hij het formaat ongeldig zou maken. Documenteer die formaatbeperking naast de resource of inhoudsbron, ook bij binaire inhoud, formaten zonder commentaar of cryptografisch materiaal. De header hoort in het resulterende bestand; alleen een commentaarregel in het Puppet-manifest voldoet niet.

**Herkomst**

Projectregel

**Toepassingsgebied**

Alle door Puppet beheerde bestandsinhoud, inclusief inline content, templates, statische bronnen en concatenatiefragmenten.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Geen check inspecteert de header in alle inhoudsbronnen of gerenderde bestanden. `project_files` controleert andere bestandsattributen.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Alleen een header die het bestandsformaat ongeldig maakt mag worden weggelaten, met lokale onderbouwing.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een manifest bevat de beheermelding als commentaar, maar het gegenereerde configuratiebestand niet. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Een shellscript begint met zijn shebang, gevolgd door de exacte beheerheader. Een commentaarloos formaat heeft een onderbouwde uitzondering naast zijn bron.

**Grensgevallen**

Alleen een header die het bestandsformaat ongeldig maakt mag worden weggelaten, met lokale onderbouwing. Geen check inspecteert de header in alle inhoudsbronnen of gerenderde bestanden. `project_files` controleert andere bestandsattributen.

**Handmatige review**

Controleer de daadwerkelijk geschreven inhoud, de plaats na een verplichte formaatheader en iedere reden voor weglaten.

**Verificatie**

Render of assembleer gewijzigde inhoud en inspecteer de header of de gedocumenteerde formaatuitzondering. Vergelijk de twee reviewscenario’s; documentatiecontracttests controleren geen beheerde bestandsinhoud.

### Beheerhelpers op de gedeelde locatie installeren

**Norm**

Installeer interne beheerscripts en hun ondersteunende bestanden onder `/usr/local/lib/puppet/`, volgens de bestaande helperindeling van MySQL. Pas deze locatie toe wanneer je een helper toevoegt of wijzigt en hergebruik de bestaande gedeelde directoryresource. Service-eigen configuratie, data en monitoringplugins behouden hun gevestigde locaties.

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe of gewijzigde interne beheerscripts en ondersteunende bestanden.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Geen check bepaalt of een bestand een interne beheerhelper is of controleert alle aanroepen en ondersteunende bestanden.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Service-eigen configuratie, data en monitoringplugins blijven op hun gevestigde locaties; ongewijzigde helpers vallen buiten een migratieplicht.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een nieuwe interne beheerhelper krijgt een eigen installatiemap en een tweede declaratie van de gedeelde directory. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Installeer de helper bij de bestaande MySQL-helperindeling en hergebruik de directoryresource; behoud de native configuratie- en pluginlocaties.

**Grensgevallen**

Service-eigen configuratie, data en monitoringplugins blijven op hun gevestigde locaties; ongewijzigde helpers vallen buiten een migratieplicht. Geen check bepaalt of een bestand een interne beheerhelper is of controleert alle aanroepen en ondersteunende bestanden.

**Handmatige review**

Volg het helperpad door bestanden, aanroepen en dependencies en controleer de gedeelde directory-eigenaar.

**Verificatie**

Controleer bij verplaatsing alle aanroepen en dependencies volgens de [helperreview](../../../AGENTS.md#managed-files-and-helpers). Vergelijk de reviewscenario’s en valideer geraakt gedrag tijdelijk buiten de repository.

### Gegenereerde configuratie met ERB renderen

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

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [source_uri_test.rb](../tests/source_uri_test.rb), [resource_contract_test.rb](../tests/resource_contract_test.rb), [cli_diagnostics_test.rb](../tests/cli_diagnostics_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Puppet-fileservermounts expliciet kiezen

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

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [source_uri_test.rb](../tests/source_uri_test.rb), [resource_contract_test.rb](../tests/resource_contract_test.rb), [cli_diagnostics_test.rb](../tests/cli_diagnostics_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Puppet-fileservermounts expliciet kiezen

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

Er is geen autofix voor de bronkeuze. Een andere mount of template kan andere inhoud opleveren. Houd paden en titels voorspelbaar en controleer de gerenderde varianten bij de gebruiker die ze moet kunnen lezen. De aanvullende URL-check staat in [`puppet_urls.rb`](../lib/project_lint/checks/puppet_urls.rb); hiervoor worden geen geïnstalleerde gems aangepast.

### Pakketten en mappen

<!-- lint-rule-group -->

### APT-opties expliciet afsluiten

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

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](../tests/resource_contract_test.rb), [guarded_packages_test.rb](../tests/guarded_packages_test.rb), [guarded_packages_safety_test.rb](../tests/guarded_packages_safety_test.rb), [guarded_packages_fix_test.rb](../tests/guarded_packages_fix_test.rb), [external_guarded_packages_test.rb](../tests/external_guarded_packages_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij APT-opties expliciet afsluiten

`project_packages` controleert de opties met inbegrip van zichtbare lokale resourcedefaults. Verwijderresources en expliciet niet-APT-providers vallen buiten die controle. Bij een onopgeloste provider, overerving, overrides of samengestelde opties kan een `[review]`-melding volgen. Beoordeel dan de effectieve opties en de reden voor een eventuele pakketuitzondering. De check heeft geen autofix.

> **Open normconflict (oplevering: package-uitzondering):** de norm laat een onderbouwde concrete pakketuitzondering toe. De check geeft voor ontbrekende of afwijkende opties ook bij zo’n onderbouwing een warning; het profiel faalt en project_packages mag niet worden onderdrukt. De check heeft geen interface om die onderbouwing te erkennen. De norm en implementatie blijven ongewijzigd; erkenning van zo’n uitzondering bij directe resource-declaraties vraagt een afzonderlijk besluit.

> **Open normconflict (oplevering: APT-flagvolgorde):** de norm toont de afsluitende opties in de volgorde recommends, suggests. De check accepteert ook de omgekeerde volgorde. Een geïsoleerde volledige profielscan bevestigt voor beide volgorden exitcode 0 en voor een ontbrekende flag exitcode 1 met project_packages. De oorspronkelijke norm en de implementatie blijven behouden; de bedoelde onderlinge volgorde wordt niet als redactionele wijziging besloten.

### Gelijk ingestelde packageguards samenvoegen

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

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](../tests/resource_contract_test.rb), [guarded_packages_test.rb](../tests/guarded_packages_test.rb), [guarded_packages_safety_test.rb](../tests/guarded_packages_safety_test.rb), [guarded_packages_fix_test.rb](../tests/guarded_packages_fix_test.rb), [external_guarded_packages_test.rb](../tests/external_guarded_packages_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Gelijk ingestelde packageguards samenvoegen

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

### Mappen en bestanden in gemengde bomen apart beheren

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

### Recursieve bewerkingen tot module-eigendom beperken

**Norm**

Recursieve bestandsbewerkingen vragen een andere afweging: welke inhoud is volledig eigendom van de module? Gebruik purge, force en recurse alleen voor zulke mappen. Houd `replace => false` op bestanden waarvan een installer of eenmalige initialisatie de inhoud bepaalt.

Heeft een centraal beheerde map al de verantwoordelijkheid om niet-gedeclareerde bestanden te verwijderen, gebruik dan dat mechanisme in plaats van opruimresources per afnemer toe te voegen. Houd bestandsverwijdering gescheiden van een eventueel vereiste runtime-stop of reload.

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

Bepaal eerst de eigenaar van ieder subtree en controleer de gevolgen van opschonen, de centrale verwijdering van niet-gedeclareerde bestanden en de afzonderlijke runtime-stop of reload.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Bepaal eerst de eigenaar van ieder subtree en controleer de gevolgen van opschonen, de centrale verwijdering van niet-gedeclareerde bestanden en de afzonderlijke runtime-stop of reload. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Eigenaars en rechten

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

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](../tests/resource_contract_test.rb), [shell_contract_test.rb](../tests/shell_contract_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Eigenaars en rechten

| Bestand of map | Gebruikelijke rechten |
| --- | --- |
| Private configuratie | `0600` |
| Script dat alleen root uitvoert | `0700` |
| Sudoersfragment | `0440` |
| Systemd-unit | `0644` waar systemd dat nodig heeft |
| Statisch terugvalbestand voor een service | Root als eigenaar, de servicegroep en `0640`; zo nodig `0710` voor bovenliggende mappen |

Bij Linux-symlinks stel je het eigenaarschap expliciet in en beveilig je het doel. Een afzonderlijke chmod-modus op de symlink biedt daar geen bruikbare bescherming.

`project_files` controleert de expliciete attributen, recursieve uitvoerrechten en uitsluiting van `source` en `content`, met inbegrip van zichtbare lokale defaults. Overerving en overrides kunnen extra cataloguscontrole vragen. De check heeft geen autofix: hij kan niet bepalen welke gebruiker toegang nodig heeft. Beoordeel zelf de effectieve rechten, de inhoud van recursieve bomen en de bereikbaarheid van bovenliggende paden.

### Toegang via diensten en rapporten beoordelen

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

### Privétoegang en uitvoerrechten onderbouwen

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

### Shellcommando's in Puppet

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

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [shell_contract_test.rb](../tests/shell_contract_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Shellcommando's in Puppet

`project_shell` volgt de herkomst van waarden in exec-commando's en guards. Een variabelenaam met `_shell` bewijst op zichzelf geen escaping. De check heeft geen autofix en kan ook niet bewijzen dat een veilig ge-escapet woord op de juiste plaats in het commando staat. Voer samengestelde commando's daarom geïsoleerd uit met synthetische argumenten die spaties, aanhalingstekens en shelltekens bevatten.

### Dynamische tekst met passende uitvoer verwerken

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

### SQL als volledige shellwaarde doorgeven

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

### Quoting per parserlaag toepassen

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

### Shellsyntaxis tegen Puppet-interpolatie beschermen

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

### Afhankelijkheden, audit en transport

<!-- lint-rule-group -->

### Lokale integraties en runtimeafhankelijkheden kiezen

<!-- lint-rule-group -->

De keuze van toegestane externe Puppet-moduledependencies is [repositorybeleid](../../../AGENTS.md#first-party-code-and-dependencies), inclusief de onderbouwde uitzondering en review van gevoelige onderdelen. Gebruik voor de technische integratie de regels voor [gedeelde voorzieningen](#gedeelde-services-en-systemd) en voor executables het [packagecontract](CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos).

### Audituitzonderingen onderbouwen

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

### Transportversleuteling behouden

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

### Een minder streng beveiligingsmodel toelichten

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

### Firewallconfiguratie bij de deployment houden

**Norm**

Afnemende projecten beheren hun eigen nftables-regels: inhoud, namen, policies, interfaces, IP-families en aanlevermethode. Zij mogen daarvoor templates, bestandsbronnen of een ander configuratiesysteem gebruiken. Gedeelde modules genereren of beheren geen deployment-firewallprofielen, voegen geen firewallverwachtingsbestanden met bijbehorende Puppet-datatypes of validatiefuncties toe en introduceren geen gespecialiseerde monitoringclasses die dit eigenaarschap overnemen.

Houd firewallmonitoring in de bestaande netwerkintegratie. Geef de deployment-eigen structurele verwachtingen als runtimeargumenten aan het gedeelde executable en vergelijk ze met de geladen toestand. Leid vereiste onderdelen nooit uitsluitend uit die geladen toestand af.

Algemene aantallen regels en lege tabellen of chains bewijzen noch bescherming noch falen. Documenteer de reikwijdte van een geslaagde structurele check; valideer pakketbereikbaarheid afzonderlijk wanneer dat nodig is.

**Herkomst**

Projectregel

**Toepassingsgebied**

Deployment-eigen firewallconfiguratie en structurele firewallmonitoring vanuit de gedeelde modules.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

De huidige projectchecks analyseren dit runtimecontract niet; opmaak- of resourcechecks leveren hiervoor geen bewijs.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

De deployment kiest zelf haar aanlevermethode; een structureel geslaagde check vervangt geen benodigde bereikbaarheidstest.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een check leidt de verwachte chains af uit de geladen firewall en rapporteert gezondheid op basis van een regeltelling. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Een deployment levert verwachtingen via runtimeargumenten; de bestaande netwerkcheck vergelijkt die met geladen state en benoemt de grens van die structurele beoordeling.

**Grensgevallen**

De deployment kiest zelf haar aanlevermethode; een structureel geslaagde check vervangt geen benodigde bereikbaarheidstest. De huidige projectchecks analyseren dit runtimecontract niet; opmaak- of resourcechecks leveren hiervoor geen bewijs.

**Handmatige review**

Controleer configuratie-eigendom, de herkomst van iedere verwachting en de conclusies die de check uit geladen state trekt.

**Verificatie**

Beoordeel beide scenario’s en valideer passende, ontbrekende en afwijkende structuren met synthetische invoer. Voer vereiste bereikbaarheidstests afzonderlijk uit volgens de [netwerkreview](../../../AGENTS.md#network-review).

## Gedeelde services en systemd

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

### Targets en monitoring

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

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [monitoring_decisions_test.rb](../tests/monitoring_decisions_test.rb), [cli_flow_test.rb](../tests/cli_flow_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Targets en monitoring

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

`project_monitoring_backend` volgt die keuzes via voorwaarden, tussenvariabelen en vindbare wrappers. Gewone pakketkeuzes zonder relatie met monitoring vallen buiten de check. De [technische naslag](../README.md#backendselectie-en-wrappers) beschrijft welke routes worden gevolgd.

De analyse voert geen Puppet-functies uit. Dynamische wrappernamen en verborgen logica in externe functies vragen daarom handmatige beoordeling. Ook correctie gebeurt handmatig: een ruimere backendvoorwaarde kan andere registraties activeren. Valideer actieve monitoring, `package => 'none'` en het verwijderen van een registratie.

### Monitoring via het centrale agentmodel registreren

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

### Uiteindelijke systemd-units volledig reviewen

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

### Gedeelde targets en service-integratie behouden

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

### Servicebeveiliging

<!-- lint-rule-group -->

### Beveiligingsopties op de uitvoerende service zetten

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

### Servicebeperkingen tegen alle uitvoerpaden beoordelen

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

### Hardeningbesluiten per optie vastleggen

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

### Umask per service expliciet kiezen

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

### Wrapperdefaults voor alle afnemers beoordelen

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

## Shellscripts

<!-- lint-rule-group -->

### Shellbron en gegenereerde shell controleren

**Norm**

De regels in dit hoofdstuk gelden voor alle eigen POSIX-shell- en Bash-code, ongeacht doel of bestandsextensie: `.sh`-bestanden, executables zonder extensie, shelltemplates, gegenereerde shellcode en inline fragmenten. Broncode en gegenereerde code moeten aan dezelfde toepasselijke shellregels voldoen. Voor de uitvoering van syntaxis- en functionele controles geldt de [shellvalidatie](../../../AGENTS.md#shell-validation).

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

### Interpreter en shellcompatibiliteit

**Norm**

Gebruik POSIX `#!/bin/sh`, tenzij benodigde functionaliteit Bash vereist. Declareer bij Bash de interpreter expliciet en documenteer de benodigde Bash-functies naast de implementatie. Houd alle code compatibel met de gedeclareerde interpreter, inclusief gegenereerde code en inline fragmenten. Gebruik geen Bash-constructies zoals arrays, `[[ ... ]]` of `pipefail` in POSIX-shellcode.

Plaats de shebang en vereiste headers eerst, volgens [beheerde inhoud markeren](#door-puppet-beheerde-inhoud-markeren).

**Herkomst**

Projectregel

**Toepassingsgebied**

Interpreterkeuze en compatibiliteit van eigen shellbron, templates en inline shell.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Bash is toegestaan wanneer benodigde functionaliteit dat vereist en die behoefte naast de implementatie is gedocumenteerd.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een script met `#!/bin/sh` gebruikt `[[ ... ]]` of `pipefail`. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik POSIX-constructies of declareer Bash wanneer benodigde functionaliteit dat vereist en leg die behoefte lokaal uit.

**Grensgevallen**

Bash is toegestaan wanneer benodigde functionaliteit dat vereist en die behoefte naast de implementatie is gedocumenteerd. Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Handmatige review**

Vergelijk gebruikte constructies met de interpreter, ook na renderen; controleer de verplichte headers.

**Verificatie**

Beoordeel de onjuiste en correcte scenario’s tegen de norm en voer bij gewijzigde shellcode de [shellvalidatie](../../../AGENTS.md#shell-validation) uit op bron en gerenderde uitvoer. Dit zijn handmatige scenario’s; de documentatietests bewijzen alleen de structuur en verwijzingen van deze regel.

### Shellscripts in uitvoervolgorde opbouwen

**Norm**

Orden de toepasselijke onderdelen als volgt: fouthelper, commandodetectie, initialisatie van instellingen en toestand, argumentverwerking, helperfuncties en invoervalidatie, daarna de hoofdverwerking. Definieer iedere helper voordat hij wordt aangeroepen. Laat onderdelen weg die het script niet nodig heeft; voeg geen opties, omgevingsinstellingen of helperlagen toe uitsluitend om deze structuur te vullen.

**Herkomst**

Projectregel

**Toepassingsgebied**

De volgorde van onderdelen en functies in eigen shellscripts.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Onderdelen die het script niet nodig heeft worden weggelaten; de structuur vereist geen extra functionaliteit.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: De commandodetectie roept een fouthelper aan die pas verderop is gedefinieerd. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Definieer eerst de fouthelper, ontdek daarna commando’s en plaats alleen daadwerkelijk benodigde volgende onderdelen.

**Grensgevallen**

Onderdelen die het script niet nodig heeft worden weggelaten; de structuur vereist geen extra functionaliteit. Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Handmatige review**

Volg de eerste aanroep van iedere helper en vergelijk de onderdelen met de voorgeschreven uitvoervolgorde.

**Verificatie**

Beoordeel de onjuiste en correcte scenario’s tegen de norm en voer bij gewijzigde shellcode de [shellvalidatie](../../../AGENTS.md#shell-validation) uit op bron en gerenderde uitvoer. Dit zijn handmatige scenario’s; de documentatietests bewijzen alleen de structuur en verwijzingen van deze regel.

### Externe commando’s rechtstreeks vinden

**Norm**

Zoek externe commando’s rechtstreeks met `COMMAND=$(command -v command 2>/dev/null) || die ...`, via de fouthelper van het script. Roep de gevonden `$COMMAND` zonder quotes aan op de commandopositie en houd argumenten afzonderlijk. Gebruik shell-builtins rechtstreeks en gebruik `printf` voor uitvoer. De installatiegaranties blijven onder het [packagecontract](CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos) vallen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Commandodetectie en aanroepen van externe executables en builtins in eigen shellcode.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Builtins worden rechtstreeks gebruikt; zij vereisen geen externe commandodetectie.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een script verstopt executable en argumenten in één commandovariabele zonder de fout bij commandodetectie af te handelen. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Vind het executable rechtstreeks met de beschreven `command -v`-toekenning en fouthelper, en geef afzonderlijke data-argumenten mee.

**Grensgevallen**

Builtins worden rechtstreeks gebruikt; zij vereisen geen externe commandodetectie. Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Handmatige review**

Controleer de discovery, fouthelper, commandopositie en gescheiden argumenten; onderscheid builtins van externe tools.

**Verificatie**

Beoordeel de onjuiste en correcte scenario’s tegen de norm en voer bij gewijzigde shellcode de [shellvalidatie](../../../AGENTS.md#shell-validation) uit op bron en gerenderde uitvoer. Dit zijn handmatige scenario’s; de documentatietests bewijzen alleen de structuur en verwijzingen van deze regel.

### Shellcode opmaken en benoemen

**Norm**

Gebruik vier spaties per inspringniveau in zowel broncode als gegenereerde shellcode. Gebruik beschrijvende `UPPER_SNAKE_CASE`-namen voor instellingen, gevonden commando’s en toestand van het hoofdprogramma; gebruik `lower_snake_case` voor helperfuncties en hun interne werkvariabelen.

Groepeer instellingen en afgeleide waarden op doel en introduceer ieder logisch blok met een kort commentaar. Houd de hoofdverwerking leesbaar van voorbereiding via uitvoering tot resultaatafhandeling. Schrijf bodies van `if`, `case` en lussen met meerdere acties op afzonderlijke ingesprongen regels. Houd eenmalige verwerking bijeen wanneer extractie de stroom onduidelijker zou maken; plaats de omvangrijke verwerking vóór een kleine terugvaltak.

Quote data-expansies in argumenten, tests en toekenningen. Behoud letterlijke witruimte in heredocs en meerregelige gequote data bij het opmaken.

**Herkomst**

Projectregel

**Toepassingsgebied**

Inspringing, naamgeving, blokopmaak en dataquoting in shellbron en gegenereerde shell.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Letterlijke witruimte in heredocs en meerregelige gequote data blijft behouden; eenmalige verwerking hoeft geen aparte helper te krijgen.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een formatter past de letterlijke inspringing in een heredoc aan of laat een data-argument ongequote. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik de beschreven namen en vier-spatie-inspringing voor code, quote data en behoud de betekenisvolle witruimte van letterlijke inhoud.

**Grensgevallen**

Letterlijke witruimte in heredocs en meerregelige gequote data blijft behouden; eenmalige verwerking hoeft geen aparte helper te krijgen. Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Handmatige review**

Controleer namen, blokdoelen en de stroom van voorbereiding tot resultaat; vergelijk letterlijke data vóór en na opmaak.

**Verificatie**

Beoordeel de onjuiste en correcte scenario’s tegen de norm en voer bij gewijzigde shellcode de [shellvalidatie](../../../AGENTS.md#shell-validation) uit op bron en gerenderde uitvoer. Dit zijn handmatige scenario’s; de documentatietests bewijzen alleen de structuur en verwijzingen van deze regel.

### Shellargumenten en runtime-instellingen verwerken

**Norm**

Behoud bestaande argumentnamen, invoerformaten, configuratiebronnen en exitgedrag. Documenteer een bewust gewijzigd publiek contract samen met de aanroepers. Voor daemonconfiguratie en inloggegevens geldt [behoud van de bestaande invoerbron](#daemonconfiguratie-als-invoerbron-behouden).

Verwerk korte opties in één POSIX `while getopts ... opt; do`-blok, met een afzonderlijke `case`-tak per optie. Eindig met één usage-/fouttak voor ongeldige opties en hulp, inclusief `-h` wanneer die optie is gedeclareerd. Behoud positionele argumenten voor interfaces die ze gebruiken.

Los instelbare waarden, voor zover deze bronnen worden ondersteund, op in deze volgorde: expliciete commandline-invoer, niet-lege omgevingsvariabele, scriptdefault. Initialiseer omgevingsinstellingen met `${VARIABLE:-default}` vóór de argumentverwerking, zodat unset en leeg de default gebruiken. Pas expliciete argumenten daarna toe en zet het resultaat nooit terug naar environment of defaults.

Valideer de effectieve instellingen na parsing en vóór gebruik, ongeacht hun bron. Controleer syntaxis, eenheden, bereiken, onderlinge waardevolgorde, booleans en runtimebetekenis. Behoud gedocumenteerde optionele lege waarden en meld ongeldige invoer via de foutinterface van het script.

Beschrijf argumenten, opties, bijbehorende omgevingsvariabelen en defaults in usage- of hulptekst. Neem herhaalde opties en boolean-resetopties op wanneer die worden ondersteund.

**Herkomst**

Projectregel

**Toepassingsgebied**

Bestaande en gewijzigde shellinterfaces met CLI-argumenten, omgevingsvariabelen of defaults.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

De bronvolgorde geldt alleen voor ondersteunde bronnen. Positionele interfaces, gedocumenteerde optionele lege waarden en bestaande publieke contracten blijven behouden; hulp en resetopties worden niet zonder behoefte toegevoegd.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een CLI-override wordt na parsing teruggezet naar een omgevingswaarde, of environmentinvoer ontsnapt aan validatie. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Initialiseer ondersteunde environment/defaultbronnen, pas CLI-overrides toe en valideer vervolgens de effectieve waarden vóór gebruik.

**Grensgevallen**

De bronvolgorde geldt alleen voor ondersteunde bronnen. Positionele interfaces, gedocumenteerde optionele lege waarden en bestaande publieke contracten blijven behouden; hulp en resetopties worden niet zonder behoefte toegevoegd. Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Handmatige review**

Volg iedere ondersteunde invoerbron tot de gebruikte waarde; vergelijk usage, argumentnamen, invoerformaat en exitgedrag met aanroepers.

**Verificatie**

Beoordeel de onjuiste en correcte scenario’s tegen de norm en voer bij gewijzigde shellcode de [shellvalidatie](../../../AGENTS.md#shell-validation) uit op bron en gerenderde uitvoer. Dit zijn handmatige scenario’s; de documentatietests bewijzen alleen de structuur en verwijzingen van deze regel.

### Shellhelpers op een herkenbare taak afbakenen

**Norm**

Voeg een helper toe wanneer die een afzonderlijke taak benoemt, validatie of opmaak deelt of aanzienlijke duplicatie wegneemt. Verpak zonder zo’n reden geen enkele toekenning, append of `printf` in een helper.

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe en gewijzigde helperfuncties in shellcode.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Een korte helper is toegestaan wanneer hij een afzonderlijke taak benoemt of validatie of opmaak deelt; omvang alleen is geen criterium.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een helper verbergt uitsluitend één toekenning zonder gedeelde taak of validatie. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Een helper benoemt een afzonderlijke verwerking of deelt bestaande validatie tussen echte aanroepers.

**Grensgevallen**

Een korte helper is toegestaan wanneer hij een afzonderlijke taak benoemt of validatie of opmaak deelt; omvang alleen is geen criterium. Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Handmatige review**

Beoordeel de taak, bestaande aanroepers en weggenomen duplicatie; houd eenmalige verwerking begrijpelijk.

**Verificatie**

Beoordeel de onjuiste en correcte scenario’s tegen de norm en voer bij gewijzigde shellcode de [shellvalidatie](../../../AGENTS.md#shell-validation) uit op bron en gerenderde uitvoer. Dit zijn handmatige scenario’s; de documentatietests bewijzen alleen de structuur en verwijzingen van deze regel.

### Shellbuffers en tijdelijke bestanden kiezen

**Norm**

Gebruik shellvariabelen en `printf` voor begrensde tellers, buffers en tekst. Gebruik `mktemp` wanneer een commando een bestand verlangt of de data te groot of onveilig is voor variabelen, en verwijder tijdelijke bestanden na gebruik.

**Herkomst**

Projectregel

**Toepassingsgebied**

Gebufferde shellgegevens en tijdelijke bestanden.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Een commandocontract dat een bestand vereist of data die te groot of onveilig is voor variabelen rechtvaardigt `mktemp`.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een noodzakelijk tijdelijk bestand blijft na gebruik of een foutpad staan. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik variabelen voor begrensde tekst; maak een vereist tijdelijk bestand met `mktemp` en ruim het op.

**Grensgevallen**

Een commandocontract dat een bestand vereist of data die te groot of onveilig is voor variabelen rechtvaardigt `mktemp`. Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Handmatige review**

Controleer dat het medium bij omvang en commandocontract past; volg levensduur en opruimen op de geraakte uitvoerpaden.

**Verificatie**

Beoordeel de onjuiste en correcte scenario’s tegen de norm en voer bij gewijzigde shellcode de [shellvalidatie](../../../AGENTS.md#shell-validation) uit op bron en gerenderde uitvoer. Dit zijn handmatige scenario’s; de documentatietests bewijzen alleen de structuur en verwijzingen van deze regel.

### Tekstbuffers en substitutiemetadata opbouwen

**Norm**

Bouw tekstbuffers met expliciete `printf`-formats en ge-escapete regeleinden in plaats van letterlijke lege regels in gequote toekenningen. Kies lijstscheiding volgens het invoer- of uitvoercontract en behoud betekenisvolle witruimte in letterlijke data.

Gebruik expliciete markeringen wanneer gestructureerde metadata via command substitution wordt doorgegeven. Vertrouw er niet op dat kunstmatig toegevoegde regeleinden shellverwerking overleven.

**Herkomst**

Projectregel

**Toepassingsgebied**

Tekstbuffers, lijstscheiding en gestructureerde metadata via command substitution.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Betekenisvolle witruimte in letterlijke data blijft intact; deze opbouwregel rechtvaardigt geen wijziging van het dataformaat.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een metadataoverdracht vertrouwt uitsluitend op een toegevoegde afsluitende newline. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Bouw de buffer met expliciete formats en gebruik herkenbare markeringen voor gestructureerde metadata.

**Grensgevallen**

Betekenisvolle witruimte in letterlijke data blijft intact; deze opbouwregel rechtvaardigt geen wijziging van het dataformaat. Puppet-lint controleert geen shellsyntaxis, scriptopbouw of gerenderd shellgedrag. De Puppet-check voor exec-escaping bewijst dit shellcontract niet.

**Handmatige review**

Controleer formats, scheidingstekens en verlies van afsluitende regeleinden; behoud betekenisvolle witruimte.

**Verificatie**

Beoordeel de onjuiste en correcte scenario’s tegen de norm en voer bij gewijzigde shellcode de [shellvalidatie](../../../AGENTS.md#shell-validation) uit op bron en gerenderde uitvoer. Dit zijn handmatige scenario’s; de documentatietests bewijzen alleen de structuur en verwijzingen van deze regel.

### Runtime-tools op hun functie beoordelen

**Norm**

Gebruik bij voorkeur de eigen uitvoer, filters en exitstatus van het oorspronkelijke commando. Converteer uitvoer niet naar JSON of een ander formaat alleen om een eenvoudige waarde uit te lezen of succes vast te stellen.

Gebruik shellvergelijkingen, `case`-patronen, parameterexpansie en builtins voor eenvoudige validatie en tekstbewerkingen wanneer zij het vereiste gedrag betrouwbaar behouden. Installeer geen extra packages uitsluitend voor bewerkingen die de gedeclareerde shell of het oorspronkelijke commando al eenvoudig uitvoert.

Gebruik een specifieke parser zoals `jq` wanneer oorspronkelijke gestructureerde uitvoer betrouwbare verwerking van meerdere velden of complexe structuren vereist. Vervang een noodzakelijke gestructureerde parser niet door kwetsbare shellparsing alleen om een dependency te verwijderen.

Voor runtime-dependencies geldt het [packagecontract](CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos). Behoud dependencies die andere afnemers nog nodig hebben. De [shellreview en validatie](../../../AGENTS.md#shell-scripts) regelen het onderzoek van alle afnemers en de vergelijking van gedrag bij vervanging.

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

### Puppet-waarden rechtstreeks in shelltemplates invoegen

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

### Daemonconfiguratie als invoerbron behouden

**Norm**

Behoud de bestaande invoerroute voor daemonconfiguratie en inloggegevens. Kopieer die waarden niet naar extra commandline-opties of omgevingsvariabelen. Lees waar mogelijk de effectieve daemonconfiguratie, bijvoorbeeld met `vnstat --showconfig`, zodat je geen tweede instellingen of sysfs-terugvalroutes hoeft te onderhouden.

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

## Monitoringchecks

**Norm**

Borg de runtimepackages volgens [packageafhankelijkheden bij externe commando’s](CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos). Checks volgen de algemene [shellconventies](#shellscripts) en gebruiken POSIX `#!/bin/sh` met Nagios-exitcodes. Volg voor gedeelde executables en instellingen per target de [registratielevenscyclus](#checkexecutables-onafhankelijk-van-targets-delen). Beoordeel status, ernst, parsing, buffering en perfdata ook tegen de hieronder beschreven uitvoercontracten. Lange uitvoer staat standaard aan; een schakelaar daarvoor wordt alleen op verzoek toegevoegd.

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

### Checkexecutables onafhankelijk van targets delen

**Norm**

Deploy bij een nieuwe of gewijzigde monitoringcheck één executable per checkimplementatie op iedere beheerde host, gedeeld door alle targetregistraties. Genereer geen kopieën of wrappers alleen om verschillende targetwaarden in te vullen. Geef targetidentiteit en instellingen die tussen registraties verschillen als runtimeargumenten of via een bestaande configuratie-interface door. Beperk templating van het executable tot waarden die alle registraties op de host delen.

Beheer het gedeelde executable onafhankelijk van individuele registraties, zodat het verwijderen of uitschakelen van één target de checks voor andere targets behoudt.

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe en gewijzigde checkimplementaties, executabletemplates en targetregistraties.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

De huidige projectchecks analyseren dit runtimecontract niet; opmaak- of resourcechecks leveren hiervoor geen bewijs.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Een bestaande configuratie-interface is toegestaan naast runtimeargumenten; executabletemplating is beperkt tot hostbreed gedeelde waarden.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Het verwijderen van één target verwijdert ook het executable dat een ander target gebruikt. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Twee registraties gebruiken hetzelfde executable met hun eigen instellingen; het executable heeft een onafhankelijke eigenaar.

**Grensgevallen**

Een bestaande configuratie-interface is toegestaan naast runtimeargumenten; executabletemplating is beperkt tot hostbreed gedeelde waarden. De huidige projectchecks analyseren dit runtimecontract niet; opmaak- of resourcechecks leveren hiervoor geen bewijs.

**Handmatige review**

Volg iedere registratie naar hetzelfde executable en controleer gedeelde templatewaarden, targetargumenten en eigenaarschap bij verwijderen of uitschakelen.

**Verificatie**

Valideer minstens twee targets met eigen instellingen en verwijder of deactiveer één target volgens de [monitoringvalidatie](../../../AGENTS.md#monitoring-validation). Controleer behoud van het executable en de andere registratie. Vergelijk ook beide handmatige reviewscenario’s.

### Monitoring onafhankelijk van de waargenomen taak houden

**Norm**

Houd monitoring onafhankelijk van de taak die zij observeert: inspecteer resultaten of status zonder de taakrunner aan te roepen, te sourcen of ervan afhankelijk te zijn.

**Herkomst**

Projectregel

**Toepassingsgebied**

Monitoring van taken en hun uitvoer of opgeslagen status.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

De huidige projectchecks analyseren dit runtimecontract niet; opmaak- of resourcechecks leveren hiervoor geen bewijs.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Geen uitzondering: statusinspectie mag geen uitvoering of sourcing van de taakrunner vereisen.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een check start de taakrunner om te bepalen of diens laatste resultaat gezond was. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Lees het bestaande resultaat of de status zonder de taak uit te voeren.

**Grensgevallen**

Geen uitzondering: statusinspectie mag geen uitvoering of sourcing van de taakrunner vereisen. De huidige projectchecks analyseren dit runtimecontract niet; opmaak- of resourcechecks leveren hiervoor geen bewijs.

**Handmatige review**

Volg commandopaden en afhankelijkheden van de check; controleer dat inspectie de waargenomen taak niet uitvoert.

**Verificatie**

Vergelijk de scenario’s en controleer de check met synthetische taakresultaten zonder beschikbare taakrunner; beoordeel dat de inspectie geen taak uitvoert.

### Vastgestelde afwijkingen en onvolledige inspecties onderscheiden

**Norm**

Meld een geverifieerd ontbrekend vereist onderdeel, een policyafwijking of een inactieve vereiste service als CRITICAL. Meld ontbrekende rechten of tools en onleesbare uitvoer die beoordeling verhinderen als UNKNOWN.

Zet een mislukte inspectie nooit om naar een lege verzameling of een gezond resultaat. Behoud vastgestelde afwijkingen naast onvolledige waarnemingen en documenteer hun statusprioriteit. Houd diagnostiek deterministisch en begrensd; benoem het geraakte object en de verwachte en waargenomen toestand. Aanvullende tellers mogen geen gezondheid vaststellen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Statusbepaling en diagnose bij geverifieerde afwijkingen en mislukte of onvolledige inspecties.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

De huidige projectchecks analyseren dit runtimecontract niet; opmaak- of resourcechecks leveren hiervoor geen bewijs.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Een onbeschikbare inspectietool levert UNKNOWN; een geverifieerd ontbrekend vereist onderdeel levert CRITICAL. Bij samenloop blijft de gedocumenteerde prioriteit zichtbaar.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een mislukte inspectie wordt een lege lijst en daardoor een gezond resultaat. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Behoud een vastgestelde afwijking én het onvolledige deel en kies de exitstatus volgens de gedocumenteerde prioriteit.

**Grensgevallen**

Een onbeschikbare inspectietool levert UNKNOWN; een geverifieerd ontbrekend vereist onderdeel levert CRITICAL. Bij samenloop blijft de gedocumenteerde prioriteit zichtbaar. De huidige projectchecks analyseren dit runtimecontract niet; opmaak- of resourcechecks leveren hiervoor geen bewijs.

**Handmatige review**

Onderscheid werkelijk vastgesteld ontbreken van een inspectie die ontbreken niet kan beoordelen; toets gemengde resultaten, objectidentiteit en verwachte versus waargenomen toestand.

**Verificatie**

Controleer met synthetische invoer ontbrekende componenten, beleidsafwijkingen, inactieve services, ontbrekende rechten/tools, onleesbare uitvoer en gecombineerde afwijkingen met onvolledige inspectie. Vergelijk beide reviewscenario’s; tooltests bewijzen geen monitoringgedrag.

### Invoer en configuratie

<!-- lint-rule-group -->

### Optionele monitoringdefaults in het executable houden

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

### Effectieve monitoringinvoer volgens het configuratiecontract valideren

**Norm**

Pas de algemene [shellargument- en runtime-instellingen](#shellargumenten-en-runtime-instellingen-verwerken) op iedere check toe. Bied voor iedere configureerbare runtime-instelling commandline-opties én omgevingsvariabelen aan en volg de bestaande optieconventies van de check. Wijs ongeldige vereiste waarden af met Nagios UNKNOWN.

Puppet mag twee expliciet opgegeven drempels alvast vergelijken, maar neemt daarvoor geen ontbrekende scriptdefault over. Voor registratie-overrides geldt [het defaultcontract](#optionele-monitoringdefaults-in-het-executable-houden).

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

### Agentplanning afzonderlijk afstemmen

**Norm**

Het uitvoerinterval en de timeout van de monitoringagent horen bij de registratie. Een scriptoptie of omgevingsvariabele verandert die agentinstellingen niet. De executor-timeout moet ruimte bieden voor uitvoering, beëindiging en uitvoer van het script. Beoordeel de agentplanning daarom afzonderlijk van scriptopties.

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

### Uitvoer voor beheerders

<!-- lint-rule-group -->

### Een bruikbare eerste uitvoerregel schrijven

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

### Status en technische tellers buiten de samenvatting houden

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

### Oorzaak en reikwijdte in de diagnose onderscheiden

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

### De hoofdoorzaak vooraan in lange uitvoer zetten

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

### Lange uitvoer afsluiten met interpretatie

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

### Veilige en begrensde uitvoer

<!-- lint-rule-group -->

### Uitvoer alleen bij aantoonbare noodzaak normaliseren

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

### Pipes en lege regels in lange uitvoer veilig maken

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

### Eén afkapmechanisme per diagnoseblok gebruiken

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

### Interpretatie zichtbaar houden bij een UI-limiet

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

### Werkbegrenzing van tekstbegrenzing onderscheiden

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

### Perfdata en compatibiliteit

<!-- lint-rule-group -->

### Perfdatakeys en eenheden stabiel vormgeven

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

### Counter-UOM alleen voor monotone tellers gebruiken

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

### De externe monitoringinterface behouden

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
