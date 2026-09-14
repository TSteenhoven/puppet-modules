# Puppet-lint

Met Puppet-lint controleer je de Puppet-code in dit project. Naast de standaardchecks gebruikt het project eigen checks voor onder meer parameters, documentatie, bestandsrechten en shellcommando's. Deze handleiding bevat de dagelijkse werkwijze, alle Puppet-codeafspraken en reviewcriteria, en de uitleg voor onderhoud en gebruik vanuit andere projecten. De [tooltests](../tests/README.md) controleren het gedrag van de linter.

## Leeswijzer

Begin bij de [dagelijkse werkwijze](#werkwijze-bij-een-wijziging) en kies hieronder de onderwerpen die je wijziging raakt. Je hoeft de overige gespecialiseerde naslag niet vooraf door te nemen. Komt tijdens je werk een nieuwe afhankelijkheid of integratie in beeld, neem dan de bijbehorende sectie erbij.

| Je taak | Lees hierbij |
| --- | --- |
| Een normaal Puppet-manifest aanpassen | [Basisopmaak](#basisopmaak), [parameters en resources](#parameters-en-resources) en [toelichtingen bij code](#toelichtingen-bij-code). |
| Puppet Strings aanpassen | [Puppet Strings](#puppet-strings), [lange regels](#lange-regels) en [waar de uitleg hoort](#waar-de-uitleg-hoort). |
| Resources of dependencies aanpassen | [Resources en afhankelijkheden](#resources-en-afhankelijkheden), [resource references](#resource-references) en [volgorde en meldingen](#volgorde-en-meldingen). |
| Bestanden, privileges of shellcommando's aanpassen | [Bestanden en beveiliging](#bestanden-en-beveiliging) en de [algemene beveiligingsreview](../../AGENTS.md#security-and-privacy). |
| Een monitoringcheck of registratie aanpassen | [Shellscripts en monitoring](#shellscripts-en-monitoring), [targets en monitoring](#targets-en-monitoring) en de [monitoringcontracten](../../AGENTS.md#monitoring-checks). |
| Systemd-integratie aanpassen | [Gedeelde services en systemd](#gedeelde-services-en-systemd), inclusief de beoordeling per service. |
| Een lintmelding oplossen | [Een melding oplossen](#een-melding-oplossen); zoek de checknaam in het [checkoverzicht](#beschikbare-projectchecks). |
| Autofix uitvoeren | [Automatisch corrigeren](#automatisch-corrigeren-autofix) en de voorwaarden bij de betrokken check. |
| Een bestaande lintcheck aanpassen | [Een check toevoegen of wijzigen](#een-check-toevoegen-of-wijzigen) en de bijbehorende [technische werking](#technische-werking-van-de-checks). |
| Een nieuwe lintcheck of autofix ontwikkelen | [Linter ontwikkelen en onderhouden](#linter-ontwikkelen-en-onderhouden), inclusief [veilige autofixes](#veilige-autofixes-ontwikkelen). |
| De centrale linter in een ander Puppet-project gebruiken | [Downstream-installatie, configuratie en CI](#de-linter-gebruiken-in-een-ander-puppet-project). |

## Inhoudsopgave

- [Code controleren](#code-controleren)
  - [Werkwijze bij een wijziging](#werkwijze-bij-een-wijziging)
  - [Werking van de controles](#werking-van-de-controles)
  - [Een melding oplossen](#een-melding-oplossen)
  - [Automatisch corrigeren (autofix)](#automatisch-corrigeren-autofix)
  - [Aanvullende validatie](#aanvullende-validatie)
- [Benodigde omgeving](#benodigde-omgeving)
- [Installatie](#installatie)
  - [Ruby op macOS](#ruby-op-macos)
  - [Gems installeren](#gems-installeren)
- [Naslag](#naslag)
  - [Beschikbare projectchecks](#beschikbare-projectchecks)
  - [Basisopmaak](#basisopmaak)
  - [Inspringing](#inspringing)
  - [Komma's](#kommas)
  - [Lange regels](#lange-regels)
  - [Parameters en resources](#parameters-en-resources)
    - [Parameters en instellingen](#parameters-en-instellingen)
    - [Voorwaarden en validatie](#voorwaarden-en-validatie)
    - [Classcontroles hergebruiken](#classcontroles-hergebruiken)
    - [Resources en afhankelijkheden](#resources-en-afhankelijkheden)
    - [Aanroepen en publieke interfaces](#aanroepen-en-publieke-interfaces)
    - [Resource references](#resource-references)
    - [Volgorde en meldingen](#volgorde-en-meldingen)
  - [Commentaar en documentatie](#commentaar-en-documentatie)
    - [Toelichtingen bij code](#toelichtingen-bij-code)
    - [Voorwaarden toelichten](#voorwaarden-toelichten)
    - [Variabelen groeperen](#variabelen-groeperen)
    - [Puppet Strings](#puppet-strings)
    - [Waar de uitleg hoort](#waar-de-uitleg-hoort)
  - [Bestanden en beveiliging](#bestanden-en-beveiliging)
    - [Templates en bestandsbronnen](#templates-en-bestandsbronnen)
    - [Pakketten en mappen](#pakketten-en-mappen)
    - [Eigenaars en rechten](#eigenaars-en-rechten)
    - [Shellcommando's in Puppet](#shellcommandos-in-puppet)
    - [Afhankelijkheden, audit en transport](#afhankelijkheden-audit-en-transport)
  - [Gedeelde services en systemd](#gedeelde-services-en-systemd)
    - [Targets en monitoring](#targets-en-monitoring)
    - [Servicebeveiliging](#servicebeveiliging)
  - [Shellscripts en monitoring](#shellscripts-en-monitoring)
    - [Opbouw van een check](#opbouw-van-een-check)
    - [Invoer en configuratie](#invoer-en-configuratie)
    - [Waarden en helpers](#waarden-en-helpers)
    - [Uitvoer voor beheerders](#uitvoer-voor-beheerders)
    - [Veilige en begrensde uitvoer](#veilige-en-begrensde-uitvoer)
    - [Perfdata en compatibiliteit](#perfdata-en-compatibiliteit)
- [Linter ontwikkelen en onderhouden](#linter-ontwikkelen-en-onderhouden)
  - [Een check toevoegen of wijzigen](#een-check-toevoegen-of-wijzigen)
  - [Technische werking van de checks](#technische-werking-van-de-checks)
  - [Veilige autofixes ontwikkelen](#veilige-autofixes-ontwikkelen)
  - [Versies bijwerken](#versies-bijwerken)
  - [CI van deze repository](#ci-van-deze-repository)
- [De linter gebruiken in een ander Puppet-project](#de-linter-gebruiken-in-een-ander-puppet-project)
  - [Benodigdheden](#benodigdheden)
  - [Installatie in je project](#installatie-in-je-project)
  - [Eigen lintconfiguratie](#eigen-lintconfiguratie)
  - [Eigen code controleren](#eigen-code-controleren)
  - [Aanroepen van modules controleren](#aanroepen-van-modules-controleren)
  - [Aanvullende tests](#aanvullende-tests)
  - [Controle in CI](#controle-in-ci)
  - [Problemen oplossen](#problemen-oplossen)

## Code controleren

Voer de controles uit vanuit de hoofdmap van deze repository, met de [ontwikkelomgeving](#benodigde-omgeving) en [gems](#gems-installeren) ingericht. Lokaal en in CI gebruiken we hetzelfde commando, dat alleen de projectconfiguratie inleest:

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
```

Controleer vooraf of `.puppet-lint.rc` in de werkmap staat. De CLI slaat een ontbrekend configuratiebestand stilzwijgend over. De relatieve pluginpaden in dat bestand vereisen bovendien de repositoryroot als werkmap.

### Werkwijze bij een wijziging

1. Bekijk `git status --short` en lees de relevante code, modulemetadata en documentatie. Kies met de [leeswijzer](#leeswijzer) de codeafspraken voor je wijziging. De overige voorbereiding staat in [`AGENTS.md`](../../AGENTS.md#preparation).
2. Voer vóór het aanpassen een lintscan uit, zodat je weet welke meldingen al bestonden. Scan gewijzigde code opnieuw voordat je meldingen gaat corrigeren. Tijdens het ontwikkelen kun je de scan tot [één manifest](#werking-van-de-controles) beperken.
3. Gebruik een beschikbare [autofix](#automatisch-corrigeren-autofix) als die voor de betrokken code veilig en deterministisch is. Controleer daarvoor de voorwaarden bij de check. Beperk de correctie tot je wijziging en behoud gedrag, relaties en configuratie.
4. Scan de gecorrigeerde code opnieuw. De uitvoer van de fixrun kan nog meldingen over de oorspronkelijke regels bevatten.
5. Los de resterende meldingen handmatig op en herhaal de scan. Beoordeel ook het gedrag en de toepasselijke reviewcriteria; lint controleert alleen de automatisch vast te stellen eigenschappen.
6. Valideer ieder gewijzigd manifest afzonderlijk met de [Puppet-parser](#aanvullende-validatie). Controleer gewijzigd gedrag, templates, voorbeelden en metadata met de passende validators en tijdelijke synthetische invoer.
7. Voer bij linterontwikkeling de betrokken [tooltests](../tests/README.md#alleen-de-linter-testen) uit. Daarmee controleer je de toolwijziging; modulegedrag valideer je afzonderlijk.
8. Voer na alle correcties de volledige eindcontroles hieronder uit en voltooi de toepasselijke CI-controles. Ook na een geslaagde gerichte scan blijven de volledige lintscan en alle tooltests vereist.
9. Bekijk de uiteindelijke bestandsselectie en diff, inclusief de automatische correcties. Leg de validatie, reviewuitkomsten en eventuele beperkingen vast en laat de wijzigingen klaarstaan voor menselijke review en commit.

Gebruik voor de eindcontroles:

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec rake test
git diff --check
git diff --name-only
git diff
```

`rake test` ontdekt de tooltests recursief en voert ze allemaal uit. `test:lint` beperkt zich tot de lintertests. Zolang alleen de linter een testsuite heeft, leveren beide taken dezelfde selectie op. `git diff --check` zoekt whitespacefouten; de laatste twee commando's tonen de gewijzigde bestanden en hun inhoud.

### Werking van de controles

`--no-config` slaat de automatisch geladen optiebestanden over. Daarna leest `--config .puppet-lint.rc` expliciet de [projectconfiguratie](../../.puppet-lint.rc). Die laadt de projectplugins met `--load`, kiest de uitvoeropmaak en bestandsuitsluitingen en laat ook waarschuwingen een foutcode opleveren. De twee geïnstalleerde lintplugins worden via de bundle geladen.

De combinatie van beide opties voorkomt invloed van persoonlijke Puppet-lint-instellingen. Een gewone `bundle exec puppet-lint .` leest eerst `/etc/puppet-lint.rc`, daarna `~/.puppet-lint.rc` en ten slotte `.puppet-lint.rc` in de werkmap. Die instellingen worden samengevoegd. Daardoor kan een persoonlijke `--fix` of een eerder uitgeschakelde standaardcheck actief blijven. Alleen `--config` toevoegen voorkomt dat niet; alleen `--no-config` gebruiken laadt juist de projectinstellingen niet.

[Bundler-instellingen](#gems-installeren) bepalen welke gems worden gebruikt en waar die staan. Ze regelen niet welke optiebestanden Puppet-lint leest. Voor gebruik vanuit een ander project zorgt de [centrale loader](#eigen-lintconfiguratie) dat de relatieve pluginpaden naar de gedeelde checkout wijzen. Het downstream-script controleert vooraf of de benodigde configuratiebestanden bestaan.

De afsluitende `.` selecteert de hele repository. Nieuwe manifests en bestanden in `examples/` worden automatisch gevonden; de CLI leest ook YAML. De vijf vendored Git-submodules en gems onder `vendor/bundle` zijn uitgesloten. ERB-templates met een YAML-extensie worden pas geldige YAML na renderen en vallen daarom buiten deze scan. Puppet-code in Strings of Markdown vraagt eveneens [afzonderlijke validatie](#aanvullende-validatie).

Voor een gerichte scan vervang je `.` door het manifestpad. Extra opties komen ná `--config .puppet-lint.rc`, zodat ze op de geladen projectchecks werken:

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc path/to/manifest.pp
bundle exec puppet-lint --no-config --config .puppet-lint.rc --only-checks project_resource_references path/to/manifest.pp
bundle exec puppet-lint --no-config --config .puppet-lint.rc --show-ignored .
bundle exec puppet-lint --no-config --config .puppet-lint.rc --json .
bundle exec puppet-lint --no-config --config .puppet-lint.rc --list-checks
```

Met `--only-checks` onderzoek je één of meer genoemde checks; deze beperkte selectie vervangt de eindscan niet. `--show-ignored` toont meldingen die door lintmarkeringen zijn onderdrukt. JSON verandert alleen de uitvoervorm en gebruikt dezelfde controles en exitcodes.

`--list-checks` toont welke checks beschikbaar zijn, inclusief uitgeschakelde checks. De lijst bewijst dus niet dat iedere check draait. Gebruik bij twijfel de proef met [een bekende fout](#een-melding-oplossen).

### Een melding oplossen

Een lintmelding geeft het bestand, de regel, de kolom, de checknaam en de oorzaak. Zoek een `project_*`-check op in het [checkoverzicht](#beschikbare-projectchecks). De link leidt naar de codeafspraak en de voorwaarden voor correctie. Voor standaardchecks is er de [uitleg van Puppet-lint](https://puppetlabs.github.io/puppet-lint/#checks).

Lees de gemelde regel samen met het parameterblok, de resource of het commando waar hij bij hoort. Bepaal welke afwijking wordt gemeld en volg de [werkwijze](#werkwijze-bij-een-wijziging) om die te herstellen. `[review]` betekent dat inhoudelijke beoordeling nodig is of dat de constructie niet veilig automatisch kan worden gewijzigd. Ook zonder die markering kunnen reviewpunten gelden; het overzicht vermeldt de grenzen van iedere check.

Een waarschuwing laat de scan mislukken. Herstel de oorzaak volgens de codeafspraak. De toegestane uitzonderingen zijn beperkt tot [lange regels](#lange-regels) en de beschreven [Puppet-fileserverbronnen](#templates-en-bestandsbronnen); andere checks uitschakelen of alleen een gunstige selectie draaien levert geen volledige controle op.

Stopt de linter voordat hij code controleert, controleer dan de Ruby-installatie, bundle en werkmap volgens [Gems installeren](#gems-installeren). Een ontbrekende plugin kan wijzen op een onvolledige checkout: de hele map `.tools/lint/` is nodig. Met [`--list-checks`](#werking-van-de-controles) zie je of de projectchecks zijn geladen.

Om te controleren of ze ook draaien, maak je tijdelijk buiten de repository een manifest met `$values = [1] + [2]`. Scan het volledige pad met de projectaanroep. Verwacht een foutcode en `project_arrays` bij dat bestand. Vervang de inhoud door `$values = concat([1], [2])`; nu hoort de proef te slagen. Verwijder het tijdelijke bestand daarna.

### Automatisch corrigeren (autofix)

Met `--fix` schrijft Puppet-lint ondersteunde correcties rechtstreeks naar de geselecteerde bestanden. Begin met een gewone scan en beoordeel de [voorwaarden van de betrokken checks](#beschikbare-projectchecks) voordat je de correctie uitvoert.

Kies de bestanden die bij je wijziging horen. De eerste aanroep hieronder corrigeert de volledige projectscope en is alleen geschikt wanneer die hele scope is bedoeld. De tweede beperkt de correctie tot één manifest; de derde selecteert daarnaast één check:

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix .
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix path/to/manifest.pp
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix --only-checks project_resource_references path/to/manifest.pp
```

Zonder `--only-checks` worden de beschikbare fixes van zowel standaardchecks als projectchecks gebruikt. Een check kan een melding laten staan wanneer de code niet veilig te herschrijven is. De concrete grenzen staan bij [inspringing](#inspringing), [komma's](#kommas), [parameteruitlijning](#parameters-en-instellingen), [commentaarscheiding](#toelichtingen-bij-code), [resource references](#resource-references) en [Puppet Strings](#puppet-strings).

Geslaagde correcties verschijnen als `fixed`. Een resterende waarschuwing of fout geeft nog steeds een foutcode. Scan daarna zonder `--fix` opnieuw: Puppet-lint verzamelt alle meldingen vóór het corrigeren, waardoor bijvoorbeeld een lengtemelding nog over de oorspronkelijke regel kan gaan.

Bij een syntaxfout schrijft de CLI het manifest niet weg. Genegeerde meldingen worden evenmin gecorrigeerd. Bekijk na de correctieronde de volledige diff en volg de [verdere afronding](#werkwijze-bij-een-wijziging). De gewone projectaanroep en CI controleren alleen; voor correctie gebruik je expliciet `--fix`. Er is geen aparte Rake-task of formatter voor nodig.

### Aanvullende validatie

Controleer ieder gewijzigd Puppet-manifest afzonderlijk met de parser. Vervang het voorbeeldpad door het gewijzigde bestand:

```sh
bundle exec puppet parser validate path/to/manifest.pp
```

Controleer gewijzigde modulemetadata met:

```sh
bundle exec metadata-json-lint module/metadata.json
```

Puppet-voorbeelden in Strings en Markdown worden niet door de gewone lintscan gevonden. Werk ze tijdelijk buiten de repository uit tot uitvoerbare invoer en controleer die met de projectlintregels en de parser. Render gewijzigde templates voordat je het resulterende formaat, de shellinspringing en de `Managed by puppet`-header beoordeelt.

Bij gedragswijzigingen onderzoek je wat er op de host verandert: welke bestanden worden geschreven, welke services herstarten en welke rechten of verbindingen daarvoor nodig zijn. Controleer normaal gebruik en een praktisch foutgeval met synthetische invoer. Neem bij een gedeelde bouwsteen alle geraakte gebruikers mee. Voor monitoring gelden de [bijbehorende scenario's](../../AGENTS.md#monitoring-validation); voor dependencies de [prerequisitereview](#resources-en-afhankelijkheden).

Deze functionele controles blijven volgens de [testafspraken](../../AGENTS.md#test-scope) buiten de repositorytests. Leg de uitgevoerde commando's, resultaten en resterende onzekerheid vast in de review.

## Benodigde omgeving

Je hebt Git, de nieuwste stabiele Ruby en de nieuwste stabiele Bundler nodig. Werk in een volledige checkout van deze repository, inclusief de verborgen bestanden en Git-submodules. De installatie hieronder haalt de submodules op en installeert de gems die de controles gebruiken.

Voer de commando's voor deze repository uit vanuit de hoofdmap. Het ontwikkelgereedschap staat onder `.tools`, apart van de Puppet-modules. De ontwikkelomgeving bepaalt niet welke Puppet- of OpenVox-versies op beheerde servers worden ondersteund; daarvoor gelden de modulemetadata en de [project-README](../../README.md#ondersteuning-en-compatibiliteit).

De controles passen geen catalogi toe en hebben geen productiegeheimen of verbindingen met beheerde servers nodig. De [testhandleiding](../tests/README.md) beschrijft welke controles bij de tooltests horen en hoe je synthetische testinvoer gebruikt.

## Installatie

Gebruik de nieuwste stabiele Ruby en Bundler. Richt op macOS eerst Ruby in met de onderstaande stappen. Heb je de nieuwste stabiele Ruby al actief, ga dan door met [de gems installeren](#gems-installeren).

### Ruby op macOS

De Ruby die macOS meelevert is te oud voor deze ontwikkelomgeving. De stappen hieronder gebruiken de nieuwste stabiele Ruby uit de [Homebrew-formule `ruby`](https://formulae.brew.sh/formula/ruby) en gaan uit van zsh. Gebruik je een Ruby-versiebeheerder zoals rbenv of mise, installeer en activeer de nieuwste stabiele Ruby daarmee en ga door naar [Gems installeren](#gems-installeren).

Controleer de [macOS-vereisten van Homebrew](https://docs.brew.sh/Installation#macos-requirements), waaronder de benodigde Command Line Tools voor Xcode. Installeer [Homebrew](https://brew.sh/) als `brew` nog niet beschikbaar is en volg ook de aanwijzingen voor de shellconfiguratie. Voer daarna dit blok uit in je huidige terminal:

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

```sh
git submodule update --init --recursive
gem install bundler
export BUNDLE_VERSION=system
bundle install
```

`gem install bundler` installeert de nieuwste stabiele Bundler. Met `BUNDLE_VERSION=system` gebruik je de geïnstalleerde versie, ook wanneer `BUNDLED WITH` in de lockfile een oudere versie noemt. Zet deze variabele ook in een nieuwe terminal voordat je de bundle gebruikt.

De [Gemfile](../../Gemfile) bevat geen vaste gemversies. [`Gemfile.lock`](../../Gemfile.lock) bewaart wel de geteste combinatie, zodat `bundle install` lokaal en in CI dezelfde gems installeert. Het ophalen van nieuwere versies staat apart onder [Versies bijwerken](#versies-bijwerken).

Krijg je een Bundler-fout met `/System/Library/Frameworks/Ruby.framework` of `/usr/bin/bundle` in de melding, dan gebruikt je terminal nog de macOS-installatie. Controleer eerst `ruby --version`, `command -v ruby` en `command -v bundle` en herstel de PATH-instelling hierboven. Bundler installeren met de oude systeem-Ruby of `sudo gem install` lost die versieverschillen niet op.

Naast Puppet-lint worden twee bestaande lintplugins, OpenVox, `metadata-json-lint`, Minitest en Rake geïnstalleerd. OpenVox levert de Puppet-parser voor structurele checks en rechtstreekse manifestvalidatie. Het installeert geen Puppet-agent op je beheerde servers. Alleen `gem install puppet-lint` is daarom niet genoeg voor de volledige projectcontrole.

## Naslag

De afspraken hieronder vormen samen met [`.puppet-lint.rc`](../../.puppet-lint.rc) en de [projectplugins](lib/puppet-lint/plugins/) de Puppet-codestandaard. Gebruik het overzicht om vanuit een lintmelding naar de betreffende afspraak te gaan. De secties bevatten ook handmatige reviewcriteria: een geslaagde scan bewijst geen correct functioneel gedrag, volledige documentatie of veilige serviceconfiguratie.

### Beschikbare projectchecks

De tabel beschrijft de automatische dekking en verwijst naar de volledige regel. **Voorwaardelijk** betekent dat de check alleen aantoonbaar geschikte constructies corrigeert; de voorwaarden staan bij die regel. **Nee** betekent dat de check geen autofix heeft. Beoordeel de genoemde reviewpunten wanneer je wijziging ze raakt, ook als de check geen melding geeft.

| Check en codeafspraak | Automatische controle | Autofix | Handmatige review |
| --- | --- | --- | --- |
| [`project_parameter_order`](#parameters-en-instellingen) | Groepen en alfabetische volgorde, lokale defaultafhankelijkheden en hun toelichting. | Nee | Betekenis van defaults en noodzaak van afwijkende volgorde. |
| [`project_parameter_alignment`](#parameters-en-instellingen) | Uitlijning over het volledige getypeerde parameterblok. | Voorwaardelijk | Commentaar tussen uit te lijnen onderdelen en meerdere parameters op één regel. |
| [`project_documentation`](#puppet-strings) | Summary, API-tag, voorbeeldtag en parameterbeschrijvingen in declaratievolgorde bij classes en defined types. | Nee | Juistheid, volledigheid, uitvoerbaarheid van voorbeelden en API-markering van functies. |
| [`project_documentation_layout`](#puppet-strings) | Regellengte, tag-inspringing en sectiescheiding bij documentatie boven declaraties. | Voorwaardelijk | Summaries, voorbeeldcode, gestructureerde Markdown en lintuitzonderingen met toelichting. |
| [`project_layout`](#inspringing) | Array-inspringing, lege regels na `{`, kommaspaties en afsluitende komma in parameterlijsten. | Voorwaardelijk | Commentaar tussen tokens en heredocs bij het einde van parameters. |
| [`project_comment_spacing`](#toelichtingen-bij-code) | Lege regel vóór een zelfstandig toelichtingsblok na code. | Voorwaardelijk | Betekenis en plaatsing van de toelichting. |
| [`project_resource_sections`](#toelichtingen-bij-code) | Eigen toelichting bij een resourcedeclaratie na een afgesloten blok. | Nee | Waarom de resource daar hoort. |
| [`project_resource_references`](#resource-references) | Aangrenzende references, alfabetische letterlijke titels en overbodige buitenste dependency-array. | Voorwaardelijk | Relatiecontext, arraystructuur, dynamische titels, volgorde en commentaar. |
| [`project_if_sections`](#voorwaarden-toelichten) | Toelichting boven `if`/`unless` en aaneengesloten voorbereiding. | Nee | Inhoudelijke samenhang en evaluatievolgorde. |
| [`project_variable_sections`](#variabelen-groeperen) | Toelichting aan het begin van een blok en na een aantoonbaar afhankelijke groep. | Nee | Groepsindeling en hints voor samenvoegen. |
| [`project_class_check_reuse`](#classcontroles-hergebruiken) | Herhaalde letterlijke classcontroles en gebruik van hun resultaat, inclusief vindbare afnemers. | Nee | Evaluatievolgorde en indirect gebruik dat de analyse niet vindt. |
| [`project_packages`](#pakketten-en-mappen) | APT-opties, met lokale defaults, providers en verwijderresources. | Nee | Effectieve of overgeërfde opties en concrete pakketuitzonderingen. |
| [`project_files`](#eigenaars-en-rechten) | Expliciete eigenaar/groep/modus, recursieve uitvoerrechten en aantoonbare uitsluiting van `source`/`content`. | Nee | Effectieve cataloguswaarden, uitvoeringsidentiteit, toegang en inhoud van bomen. |
| [`project_puppet_urls`](#templates-en-bestandsbronnen) | Toegestane mountprefixen, ook naast een ignore van `puppet_url_without_modules`. | Nee | Dynamische delen, beschikbaarheid en fileserverrechten. |
| [`project_arrays`](#resources-en-afhankelijkheden) | `+` met herkenbare arrays; getal- en hashoptelling blijven toegestaan. | Nee | Dynamische typen en behoud van elementvolgorde. |
| [`project_templates`](#templates-en-bestandsbronnen) | Aanroepen van `epp` en `inline_epp`. | Nee | Templatekeuze, inhoud en gerenderd resultaat. |
| [`project_positive_flow`](#voorwaarden-en-validatie) | Omvang van codetakken en afsluitende structuur van `warning()`/`fail()` in classes en defined types. | Nee | Waarheidsvoorwaarden, `elsif`-prioriteit, geldige en ongeldige uitvoerpaden. |
| [`project_shell`](#shellcommandos-in-puppet) | Aantoonbare escapingherkomst van dynamische exec-commando's en guards. | Nee | Quoting per parserlaag en de plaats van elk argument. |
| [`project_interface_calls`](#aanroepen-en-publieke-interfaces) | Ontbrekende verplichte argumenten bij statisch gevonden declaraties zonder splat. | Nee | Argumenttypen, onbekende parameters, Hiera, defaults, overerving en containment. |
| [`project_monitoring_backend`](#targets-en-monitoring) | Backendselectie bij aanroepers en vindbare wrappers van `monitoring_custom`. | Nee | Dynamische routes, actief/`none` en verwijderen van registraties. |
| [`project_suppressions`](#lange-regels) | Alleen control comments voor `140chars` en `puppet_url_without_modules`, eventueel samen. | Nee | Noodzaak, plaats en kleinste geldige scope van de uitzondering. |

De checks voor opmaak bewijzen niet dat commentaar inhoudelijk klopt. Voor systemd-hardening, transportbeveiliging, shellgedrag, monitoringdefaults, uitvoertijd en gedeelde checkexecutables bestaat hier geen volledige automatische lintcontrole. De betreffende naslagsecties en [`AGENTS.md`](../../AGENTS.md#monitoring-checks) beschrijven de review en functionele validatie.

### Basisopmaak

Puppet-code gebruikt twee spaties per inspringniveau. Lijn de `=>`-pijlen binnen een resource uit, zodat de attributen en waarden goed te vergelijken zijn. Voor letterlijke strings gebruik je enkele aanhalingstekens; dubbele aanhalingstekens zijn bedoeld voor interpolatie of escapes.

Bereken de uitkomst van een selector vóór de resource die deze gebruikt. Zo blijft in de resourcedeclaratie zichtbaar welke waarde wordt ingesteld. Kies ook de volgorde van resources en gegenereerde configuratie bewust: de linter kan de opmaak controleren, maar bepaalt niet welke volgorde functioneel nodig is.

De standaardchecks en geïnstalleerde plugins controleren onder meer witruimte, aanhalingstekens, parameterdatatypen en afsluitende komma's. De projectchecks vullen deze controles aan. Bij [autofix](#automatisch-corrigeren-autofix) gelden voor beide dezelfde eisen aan behoud van gedrag.

De projectconfiguratie gebruikt alle standaard ingeschakelde checks en schakelt daarnaast `class_inherits_from_params_class` in. Ook nieuwe standaardchecks komen bij een update beschikbaar. De optionele checks voor 80 tekens, booleans tussen aanhalingstekens en code op hoofdniveau staan uit: dit project gebruikt een grens van 140 tekens en ondersteunt daemonstrings zoals `'true'` en uitvoerbare profielen. Bestaande stijlachterstand is geen reden om een check uit te schakelen of een module uit te zonderen.

### Inspringing

Bij een array over meerdere regels bepaalt de regel met `[` de inspringing. De elementen staan twee spaties verder naar rechts; een afsluitende `]` aan het begin van een regel staat op hetzelfde niveau als de openingsregel. Dat geldt ook als de array in een functieaanroep staat:

```puppet
$label = join([
  'first',
  'second',
], ' ')
```

Extra functiehaakjes, bijvoorbeeld in `Sensitive.new(join([`, voegen geen inspringniveau toe. De array volgt het omliggende codeblok. Alleen een array die als resourcetitel direct achter de accolade begint, zoals `file { [`, krijgt een extra niveau: de elementen staan vier spaties verder dan `file` en de afsluitende `]` twee spaties.

`project_layout` controleert het begin van array-elementen op een nieuwe regel en de afsluitende `]`. Meerdere elementen op één regel zijn toegestaan. Met `--fix` herstelt de check de inspringing, inclusief die van geneste arrays. Stringinhoud, heredocs en commentaar blijven behouden. Vierkante haken in datatypeparameters of indexeringen worden niet als arrays behandeld.

### Komma's

Zet één spatie na een komma wanneer het volgende element op dezelfde regel staat. Sluit een parameterlijst over meerdere regels af met een komma na de laatste parameter. Ook resources en verzamelingen over meerdere regels krijgen een afsluitende komma.

`project_layout` controleert de spaties en de laatste komma in parameterlijsten; de trailing-comma-plugin controleert resources en verzamelingen. Autofix herstelt de spaties alleen als er geen commentaar tussen de betrokken onderdelen staat. Bij een parameter die eindigt met een heredoc voeg je de laatste komma handmatig op de juiste plaats toe. De autofix kan daar niet veilig bepalen waar de parameter eindigt.

### Lange regels

Houd Puppet-code binnen 140 tekens per regel. Lange arrays en functieaanroepen kun je over meerdere regels verdelen. Laat je een regel bewust langer, voeg dan `# lint:ignore:140chars` toe achter de code. Zo blijft de uitzondering zichtbaar bij de review. Bijvoorbeeld bij een lange download-URL:

```puppet
$download_url = 'https://downloads.example.org/releases/application/stable/linux/amd64/packages/application-with-optional-components-and-offline-documentation.tar.gz' # lint:ignore:140chars
```

De markering hoort in Puppet-commentaar, buiten de waarde. Staat daar al een toelichting, zet de markering dan direct na `#` en vóór die toelichting. Heeft een string of heredoc over meerdere regels een lengte-uitzondering nodig, zet dan `# lint:ignore:140chars` vóór de waarde en `# lint:endignore` erna. Houd dat blok zo klein mogelijk. Binnen de string of heredoc zou de markering als inhoud worden verwerkt, bijvoorbeeld in een beheerd bestand of shellcommando. Daar is zij daarom niet toegestaan.

Gewoon codecommentaar volgt de afspraak van [één zin per fysieke regel](#toelichtingen-bij-code). Bij een bewust lange commentaarregel kun je een begrensd ignoreblok gebruiken.

Bij [Puppet Strings](#puppet-strings) verdeel je een beschrijving over meerdere commentregels. Een lange beschrijvende zin heeft dus geen lengte-uitzondering nodig. Alleen een letterlijke waarde die niet zonder betekenisverlies kan worden afgebroken mag langer blijven. Sluit het ignoreblok vóór de volgende gewone documentatieregel.

De standaardcheck `140chars` meldt lange regels, maar slaat bepaalde regels met URL's of `template(...)` over. Ook op die overgeslagen regels vraagt de projectafspraak een markering; controleer dat bij de review. `project_documentation_layout` controleert de lengte en uitzonderingen in Puppet Strings afzonderlijk. De standaardcheck heeft geen autofix; gewone Strings-tekst kan de documentatiecheck wel afbreken.

`project_suppressions` controleert welke checks via commentaar worden uitgezonderd. Alleen `140chars` en de beschreven uitzondering voor [Puppet-fileserverbronnen](#templates-en-bestandsbronnen) zijn toegestaan, eventueel samen. De noodzaak en begrenzing van de uitzondering beoordeel je zelf. Gebruik [`--show-ignored`](#werking-van-de-controles) om te zien welke meldingen door zulke markeringen worden onderdrukt. Neem je een codevoorbeeld uit documentatie over in een manifest, voeg dan daar een eigen markering toe aan bewust lange regels.

### Parameters en resources

#### Parameters en instellingen

Ontwerp classes en defined types zo dat ze afzonderlijk en in combinatie bruikbaar zijn. Geef publieke parameters een expliciet datatype, met een ingebouwd Puppet-type of een passende typealias.

Voor de sortering gebruikt het project twee groepen. Eerst komen parameters zonder default en zonder buitenste `Optional[...]`. Daarna volgen de parameters met een default of `Optional[...]`. Sorteer beide groepen alfabetisch en lijn de typen, namen, `=`-tekens en defaults over het hele parameterblok uit. Dit fragment laat de indeling zien:

```puppet
  String           $value,
  Optional[String] $label,
  Integer          $timeout = 30,
```

`$label` staat hier in de tweede groep, maar blijft verplicht bij een aanroep: `Optional[String]` staat `undef` toe en levert zelf geen default. Voeg geen default toe om alleen de sortering te veranderen.

Een default kan de normale volgorde doorbreken wanneer hij de waarde van een andere parameter gebruikt. Declareer die andere parameter dan eerder. Schuift hij daarmee vóór zijn normale alfabetische positie, leg de reden uit in commentaar achter die parameter en noem daarin de afhankelijke parameter met `$naam`.

`project_parameter_order` controleert de groepen, volgorde, defaultafhankelijkheden en die toelichting. De check sorteert niet automatisch. `project_parameter_alignment` kan de uitlijning herstellen wanneer de parameters op afzonderlijke regels staan en de tussenruimte geen commentaar bevat. Ook geneste typen en defaults over meerdere regels worden meegenomen. Meerdere parameters op één regel, onduidelijke tussenruimte en genegeerde delen vragen handmatige beoordeling.

Kies namen in snake_case die beginnen met het onderwerp, gevolgd door de nadere aanduiding: bijvoorbeeld `bandwidth_max`, `p95_warning` of `secret_key_fallback`. Een naam die met een cijfer begint is alleen bruikbaar als dat op alle ondersteunde runtimes is getest.

Biedt een beveiligingsinstelling een veilige standaardwaarde, een uitschakelmogelijkheid en een eigen waarde, gebruik dan één parameter met `Variant[Boolean, String]` of een passende beperkte scalarvariant. Daarbij kiest `true` de veilige standaardwaarde, laat `false` de instelling weg en levert een scalar de eigen waarde. Bereken de effectieve waarde eenmaal in een `*_correct`-variabele die de template gebruikt. Alleen wanneer compatibiliteit dat vereist, splits je dit in afzonderlijke enable/custom/value-parameters.

#### Voorwaarden en validatie

Zet de omvangrijkste verwerking in de eerste tak van een voorwaarde en de kortere afhandeling in de laatste `else`. Een korte foutmelding of terugvalwaarde komt zo na de code die het normale werk uitvoert. De voorwaarde mag daarvoor een ontkenning bevatten. Gelijke takken en een `if` zonder vervolgtak zijn toegestaan; voor `unless` geldt dezelfde volgorde.

Bij invoervalidatie omsluit de geldige tak de implementatie die van die invoer afhankelijk is. Bereken de benodigde waarden vooraf en zet de bijbehorende `warning()` of `fail()` in de afsluitende `else`. Zijn meerdere controles nodig voor dezelfde implementatie, nest die dan. Een bestaande `case` mag zijn foutafhandeling in de laatste `default`-tak houden.

Een fouttak mag meerdere meldingen bevatten en lokale variabelen voorbereiden die voor die meldingen worden gebruikt. Andere verwerking hoort in de geldige tak. Laat de fouttak ook achteraan staan wanneer de meldingen en hun voorbereiding samen groter zijn dan de geldige tak.

Na zo'n validatie volgt binnen dezelfde class of hetzelfde defined type geen implementatiecode meer. Dat geldt ook wanneer de validatie in een buitenste `if`, `case` of lambda-aanroep staat: code ná dat buitenste blok zou buiten de geldige tak vallen. Een volgende `else` of alternatieve `case`-tak vormt een ander uitvoerpad en mag wel volgen.

Valideer een optionele instelling alleen als die daadwerkelijk wordt gebruikt of in configuratie terechtkomt. Een niet-ingestelde optionele waarde is op zichzelf geen fout. Bewaar het resultaat in een variabele met één korte foutmelding of `undef`, maak de resources in de geldige tak en faal in de laatste `else`. Een losse `fail(...)` halverwege de opbouw van waarden of resources past niet in deze structuur.

Wanneer een instelling een waarde erft, mag de template de ruwe parameter gebruiken om te bepalen of een regel nodig is. Voor de inhoud van die regel gebruikt de template de berekende waarde.

`project_positive_flow` controleert zowel de omvang van takken als de plaats van validatiemeldingen. Bij `elsif` vergelijkt de check iedere tak met de grootste afzonderlijke vervolgtak. Een expliciet geneste `if` telt als geneste code. De [technische naslag](#omvang-en-validatiestructuur) beschrijft de telling en welke aanroepen als validatiemelding worden herkend.

De check heeft geen autofix: het omkeren van een voorwaarde of verplaatsen van code kan de evaluatievolgorde veranderen. Behoud bij `elsif` de prioriteit van overlappende voorwaarden. Test steeds het geldige en ongeldige pad, vooral bij `warning()`: een waarschuwing stopt Puppet niet vanzelf.

#### Classcontroles hergebruiken

Een defined type dat zijn parentclass nodig heeft, controleert eerst `defined(Class['...'])`. Plaats alle code die van die class afhangt in de geldige tak en geef een duidelijke fout als de class ontbreekt.

Gebruik binnen een class of defined type één gedeelde variabele als dezelfde classcontrole vaker nodig is. Dat geldt ook bij gebruik in verschillende geneste blokken. Wordt de uitkomst maar één keer gebruikt, neem de controle dan rechtstreeks in de expressie op. Een samengestelde voorwaarde mag wel een eigen naam hebben, zoals `$active = $ensure == present and defined(Class['basic_settings::monitoring'])`: die naam beschrijft wanneer het onderdeel actief is.

`project_class_check_reuse` telt letterlijke classcontroles en vindbaar gebruik van hun resultaat, ook vanuit andere manifests en templates. De [technische naslag](#classcontroles-en-vindbare-afnemers) beschrijft welke afnemers de analyse kan vinden. Dynamische classnamen, parameterdefaults en indirecte lookups beoordeel je zelf.

Er is geen autofix voor samenvoegen of inlinen. `defined(...)` kijkt naar wat tijdens evaluatie al bekend is; een classdeclaratie tussen twee controles kan de uitkomst veranderen. Controleer daarom de [declaratievolgorde](#resources-en-afhankelijkheden) en behoud afnemers die de statische analyse niet vindt.

#### Resources en afhankelijkheden

Gebruik één declaratie met vooraf berekende waarden wanneer resources alleen in optionele attributen verschillen. Een niet-ingesteld attribuut krijgt `undef`. Zorg daarbij dat `source` en `content` nooit tegelijk gevuld zijn. `project_files` controleert of die uitsluiting uit de code volgt; onopgeloste of overgeërfde waarden vragen een controle van de effectieve catalogus.

Plaats resources die dezelfde voorwaarde delen in één buitenste voorwaarde. Hun eigen controles kunnen daarbinnen staan. Zo blijft zichtbaar welke verwerking volledig afhankelijk is van de beschikbaarheid of instelling die je controleert.

Maak bij dependencies onderscheid tussen wat een operatie nodig heeft om te kunnen draaien en wat alleen de uitvoervolgorde bepaalt. Het weglaten van `require` schakelt de operatie niet uit. Controleer volgens de [prerequisitereview](../../AGENTS.md#prerequisite-review) wat er gebeurt met de prerequisite aanwezig en afwezig, inclusief de relevante declaratie- en evaluatievolgorde.

`defined(...)` ziet alleen wat tijdens evaluatie al bekend is. Koppel een `require` daarom pas na een geslaagde controle aan een geaccepteerde resource of gedocumenteerd anker. Wordt de afhankelijkheid via wrappers geleverd, controleer dan eerst de directe resource, vervolgens de wrapper en daarna de parentwrapper. De eindcatalogus kan andere resources bevatten dan op dat eerdere evaluatiemoment zichtbaar waren.

Gebruik de bestaande interface om gegevens van een andere bouwsteen te verkrijgen. Een resource, alias, servicetitel of geaccepteerde API kan bijvoorbeeld het pad, de poort of de unitnaam leveren. Bouw die waarden niet zelfstandig opnieuw op; valideer de afspraak tussen beide onderdelen. Als een interface-uitbreiding is afgewezen, werk dan met de geaccepteerde interface of stabiele externe runtimemetadata, zonder alsnog ongedocumenteerde gemaksparameters toe te voegen.

Combineer arrays met `concat($base, $extra)` en behoud de elementvolgorde. `project_arrays` meldt `+` bij herkenbare arrays, maar berekent geen dynamische typen en heeft geen autofix. Gebruik een eenmalige tussenvariabele wanneer de naam betekenis toevoegt of de code duidelijker maakt.

#### Aanroepen en publieke interfaces

Geef bij een class- of defined-type-aanroep alle verplichte parameters mee. Ook een `Optional[...]` zonder default blijft een verplicht argument: het type staat `undef` toe, maar vult geen ontbrekende waarde in.

`project_interface_calls` meldt ontbrekende argumenten bij declaraties die de check statisch kan vinden. Binnen deze repository is de eigen moduleverzameling het standaardzoekpad. De [modulepadregels](#aanroepen-van-modules-controleren) beschrijven hoe de declaratie wordt gekozen en welke aanroepen buiten de analyse vallen.

Een geslaagde scan bewijst geen geldige catalogus. Argumenttypen, onbekende parameters, Hiera, overerving, defaults, containment en splats vragen afzonderlijke catalogusvalidatie. Dat geldt ook wanneer de linter een declaratie niet vindt. De check heeft geen autofix; de juiste argumentwaarde volgt uit de interface en het bedoelde gebruik.

#### Resource references

Schrijf direct aangrenzende references van hetzelfde resourcetype binnen een array als één reference met meerdere titels. Sorteer de titels alfabetisch. Dit geldt ook voor classes en eigen defined types. Bij een dependency-attribuut of een losse relatieketen laat je de buitenste array weg wanneer daarin nog maar één reference staat:

```puppet
# Both packages are prerequisites for this notification.
notify { 'packages-ready':
  require => Package['alpha', 'zulu'],
}
```

Hier zou `require => [Package['zulu'], Package['alpha']]` dezelfde dependencies beschrijven, maar met onnodige herhaling. Ook een buitenste array zoals `[Package['alpha', 'zulu']]` is op deze plaats overbodig.

Een ander array-element onderbreekt de reeks. Zo blijft `[Package['zulu'], Service['nginx'], Package['alpha']]` gescheiden. Voeg ook geen afzonderlijke functieargumenten, geneste arrays of kanten van een relatiepijl samen. Alleen de buitenste array rond één dependency-reference kan weg; meerdere elementen en geneste arraylagen blijven behouden.

`project_resource_references` controleert aangrenzende references, de volgorde van letterlijke titels en overbodige buitenste arrays. Letterlijke titels worden hoofdlettergevoelig vergeleken op hun stringwaarde, zonder de aanhalingstekens mee te tellen. Dubbele titels blijven behouden. Datatypeparameters zoals `Enum[...]`, lokale typealiases en gewone indexeringen vallen buiten deze regel.

Autofix kan dit herstellen bij `require`, `before`, `notify` en `subscribe`, en bij losse relatieketens met `->`, `~>`, `<-` of `<~`. In die context beschrijven de references relaties tussen resources. Bij andere toepassingen kan dezelfde herschrijving de betekenis veranderen: een [reference met meerdere titels levert een array op](https://help.puppet.com/core/current/Content/PuppetCore/lang_data_resource_reference.htm), waardoor `[Package['a', 'b']]` een geneste array bevat en `[Package['a'], Package['b']]` niet. Bij variabelen, functieargumenten, indexeringen en een gebruikt resultaat van een relatie-expressie beoordeel je de gevolgen zelf.

Samenvoegen en sorteren gebeurt alleen automatisch bij letterlijke titels zonder tussenliggend commentaar. Dynamische titels en commentaar vragen handmatige aanpassing: behoud de toelichting bij de juiste resource en beoordeel welke waarden de titels kunnen krijgen. De linter rekent die waarden niet uit.

Een buitenste array rond één reference kan ook bij een dynamische titel worden verwijderd: `require => [Package[$packages]]` wordt `require => Package[$packages]`. De reference zelf verandert dan niet. Bevat de te wijzigen array commentaar, een heredoc of genegeerde code, dan weigert de autofix ook deze correctie.

#### Volgorde en meldingen

Behoud de expliciete `require`-, `notify`- en `subscribe`-relaties tussen resources. Ontstaat een afhankelijkheidscyclus, zoek dan welke relatie of containment die veroorzaakt. Herstel de relatie daar, zodat Puppet de volgorde en herstarts kan blijven regelen. Een los `systemctl`-, `service`- of reloadcommando omzeilt die samenhang en is geen vervanging.

Soms is de afhankelijkheid van een volledige class te breed. Koppel de ordering dan waar nodig aan een kleinere, stabiele resource en behoud meldingen zoals `notify => Service['nginx']`.

Plaats monitoring en audit bij de resource waarop ze betrekking hebben. Configuratie die alleen voor monitoring nodig is hoort bij de monitoringsectie van het manifest. Een bestand dat de daemon zelf configureert blijft bij de daemonconfiguratie staan.

### Commentaar en documentatie

#### Toelichtingen bij code

Een toelichting vertelt waarom de code nodig is, welke beperking ermee wordt opgevangen of welk gevolg de lezer moet kennen. Schrijf codecommentaar in het Engels en houd iedere zin op één fysieke regel. Lijsten, voorbeelden en syntaxis mogen hun eigen regels krijgen. Voor [Puppet Strings](#puppet-strings) geldt een andere opmaak, met afgebroken documentatietekst. Werk willekeurige regelafbrekingen in geraakte codecomments weg.

Licht vooral de keuzes toe die niet uit de volgende regel blijken. Dat geldt bijvoorbeeld voor een resourcegroep, exec, afgeleide waarde, voorwaardelijke directive, gedelegeerde resource of opruimroute. Ook helpers en templatelogica verdienen uitleg wanneer de invoer, uitvoer of gevolgen voor exitcodes niet vanzelf spreken. Bij escaping, parsing, classificatie, samenvoegen van resultaten en terugvalgedrag helpt zo'n toelichting om een latere wijziging veilig te beoordelen.

Een zelfstandig toelichtingsblok begint na een lege regel wanneer er code aan voorafgaat. Aaneengesloten commentaarregels vormen samen één blok; commentaar achter code en lintmarkeringen vormen geen nieuwe toelichting. Direct na `{`, `[` of `(` is geen lege regel vóór het commentaar nodig.

Na een openende `{` begint de inhoud direct op de volgende regel, ook als er achter de accolade commentaar staat. Dit geldt voor codeblokken en verzamelingen. Verderop in het blok mogen lege regels onderdelen scheiden. Bij `[` en `(` mag ook de eerste regel leeg zijn. Deze opmaakregels gaan over Puppet-code; tekens binnen strings, reguliere expressies, heredocs of commentaar behouden hun betekenis.

Een resourcedeclaratie na een afgesloten `}` begint met een lege regel en een eigen toelichting direct boven de declaratie. Dat geldt ook voor defined types, resourcedefaults en overrides. Resources die met `->` of `~>` verbonden zijn blijven samen één keten.

`project_comment_spacing` kan de lege regel vóór een bestaand commentaarblok toevoegen. `project_layout` kan lege regels direct na `{` verwijderen en meldt daarbij de eerste lege regel, ook als die spaties of tabs bevat. Genegeerde delen blijven behouden. `project_resource_sections` controleert of de toelichting bij een nieuwe resource aanwezig is en heeft geen autofix.

Controleer bij de review of de uitleg nog klopt en of lange reeksen instellingen herkenbaar zijn gegroepeerd. Vergelijk de passage met goed gedocumenteerde bestaande code en verwijder verouderde, dubbele of overbodige uitleg. Projectbeleid hoort in de documentatie; implementatiecommentaar legt de lokale reden en gevolgen uit.

#### Voorwaarden toelichten

Geef iedere `if` en `unless` een toelichting die de voorwaarde en de bijbehorende verwerking verklaart. Als direct ervoor variabelen worden berekend die de voorwaarde voorbereiden, staat die toelichting boven de eerste toekenning. De voorbereiding en de voorwaarde vormen dan samen één blok:

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

Groepeer variabelen op het doel waarvoor je ze berekent. Begin een codeblok dat na `{` meteen variabelen toekent met een toelichting binnen dat blok, direct boven de eerste toekenning. Dit geldt ook voor één variabele en voor korte `else`-, `elsif`- en `case`-takken, classes, defined types en lambdablokken. De toelichting boven de voorwaarde beschrijft waarom de tak wordt uitgevoerd; de uitleg binnen het blok beschrijft de variabelen.

Maak een nieuwe groep wanneer na onderling afhankelijke berekeningen een losstaande instelling volgt. In dit voorbeeld horen de genormaliseerde servernaam, de ge-escapete waarde en het label bij elkaar. Het configuratiepad en de numerieke instellingen vormen de volgende groep:

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

Puppet Strings beschrijft de publieke interface bij de code. Zet de documentatie direct boven iedere publieke class en ieder publiek defined type. De lezer moet daarmee kunnen bepalen welke parameters nodig zijn en wat de declaratie op een host verandert. Markeer nieuwe classes, defined types en functies met `@api public` of `@api private`.

Begin met een korte `@summary` op één regel en zet verdere uitleg eronder. Beschrijf iedere parameter eenmaal met `@param`, in dezelfde volgorde als de declaratie. Leg uit wat de waarde betekent, hoe de default tot stand komt en wat bijzondere waarden zoals `undef`, `true` en `false` doen. Neem ook relevante beperkingen, dependencies, gegenereerde resources, terugvalgedrag en gevolgen voor beveiliging of compatibiliteit op.

Een eenvoudig uitvoerbaar `@example` laat het normale gebruik zien. De titel staat achter de tag, de code op de ingesprongen commentregels eronder. Dit documentatieblok toont de opmaak:

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

Breek gewone beschrijvingen af op logische plaatsen, bij voorkeur rond 120 tekens en uiterlijk bij 140 tekens. De inspringing en het commentteken tellen mee. Houd woorden, technische identifiers en inline code intact en behoud de alinea-indeling. Een ondeelbaar element tussen 120 en 140 tekens mag op zijn regel blijven staan. Voor langere letterlijke waarden geldt de uitzondering bij [Lange regels](#lange-regels).

Bij een lange parameterbeschrijving staat alleen de naam achter `@param`; de uitleg volgt met twee extra spaties, als `#   ...`. Een korte beschrijving mag achter de parameternaam blijven staan. Scheid secties en afzonderlijke parameters met een lege commentregel `#`, zodat het één documentatieblok blijft. Een volledig lege broncoderegel hoort daar niet tussen. Behoud binnen voorbeeldcode de verdere code-inspringing. De [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm) beschrijft de algemene opbouw.

`project_documentation` controleert bij classes en defined types de summary, API-markering, voorbeeldtag en parameterbeschrijvingen. De check controleert aanwezigheid en volgorde, niet of de tekst het werkelijke gedrag volledig beschrijft. Ontbrekende uitleg of tags worden niet automatisch ingevuld.

`project_documentation_layout` controleert de opmaak boven classes, defined types, Puppet-functies en typedeclaraties. Afbreekbare tekst boven 120 tekens en documentatieregels boven 140 tekens geven een melding, ook als de standaardcheck een URL zou overslaan. Voorbeeldcode krijgt alleen boven 140 tekens een lengtemelding.

Met `--fix` kan de documentatiecheck gewone tekst afbreken en herkenbare tag-inspringing en sectiescheiding herstellen. Woorden, backtick-inhoud en alinea's blijven behouden. Summaries, voorbeeldtitels, voorbeeldcode en gestructureerde Markdown, zoals lijsten, tabellen en codeblokken, vragen waar nodig handmatige correctie. Een lange summary of voorbeeldtitel kort je zelf in. Bij onveilige of onduidelijke correcties blijft een melding met `[review]` staan.

Een overbodig `140chars`-blok rond uitsluitend gewone documentatie kan de autofix verwijderen. Een blok met een toelichtende reden, een gecombineerde uitzondering of een uitzondering die ook Puppet-code omvat vraagt handmatige begrenzing. Controleer na correctie de tekst en Markdown-opbouw en valideer de voorbeelden volgens [Aanvullende validatie](#aanvullende-validatie).

#### Waar de uitleg hoort

Werk bij een interfacewijziging de Puppet Strings en de geraakte voorbeelden mee bij. Vergelijk de beschreven defaults, relaties en gegenereerde configuratie met het manifest. Als monitoringgedrag voor beheerders verandert, kijk dan ook naar het checkoverzicht in de project-README.

Gebruik de [documentatie-indeling in `AGENTS.md`](../../AGENTS.md#documentation) om te bepalen waar de uitleg thuishoort. Gebruikskeuzes horen in de gebruikershandleiding, parametercontracten in Puppet Strings en lokale implementatieredenen bij het script of de template. Maak geen handmatige `REFERENCE.md` of `docs/`-boom voor informatie die Puppet Strings kan genereren. Voeg een ADR alleen toe wanneer dat is gevraagd of al gebruikelijk is.

Breid bij voorkeur een bestaand voorbeeldscenario uit. Toon daarin de benodigde parameters en zorg dat het voorbeeld met de genoemde voorwaarden uitvoerbaar is. De [project-README](../../README.md#gebruik-van-voorbeelden-en-parameterdocumentatie) beschrijft het gebruik van voorbeeldwaarden, `Sensitive(...)` en Hiera; voor synthetische gegevens gelden de [beveiligingsregels](../../AGENTS.md#security-and-privacy).

### Bestanden en beveiliging

#### Templates en bestandsbronnen

Gebruik ERB en `template(...)` voor gegenereerde configuratie. Bestanden die alleen in een klein optioneel onderdeel verschillen kunnen één template delen. Bij een ander formaat of een andere verantwoordelijkheid past een aparte template. `project_templates` meldt aanroepen van `epp` en `inline_epp`, maar kan de omzetting naar ERB niet automatisch uitvoeren.

Een statisch modulebestand krijgt een bron onder `puppet:///modules/...`. Voor bestanden uit de Puppet-fileservermount `files` gebruik je `puppet:///files/...`. Richt die mount en de benodigde toegang eerst op de Puppet-server in.

De standaardcheck `puppet_url_without_modules` meldt een `files`-bron omdat die buiten de modulemount staat. Markeer deze bewuste keuze op de bronregel, zodat de uitzondering alleen voor die regel geldt:

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

Er is geen autofix voor de bronkeuze. Een andere mount of template kan andere inhoud opleveren. Houd paden en titels voorspelbaar en controleer de gerenderde varianten bij de gebruiker die ze moet kunnen lezen. De aanvullende URL-check staat in [`resources.rb`](lib/puppet-lint/plugins/resources.rb); hiervoor worden geen geïnstalleerde gems aangepast.

#### Pakketten en mappen

Voorkom dat een APT-installatie onbedoeld aanbevolen of voorgestelde pakketten meeneemt. Laat `install_options` eindigen met `['--no-install-recommends', '--no-install-suggests']`, tenzij een concreet pakket een onderbouwde afwijking nodig heeft. Voeg deze opties met `concat(...)` achter de aangeleverde opties toe. `union(...)` verwijdert duplicaten en garandeert daardoor niet dat de voorgeschreven opties achteraan staan.

`project_packages` controleert de opties met inbegrip van zichtbare lokale resourcedefaults. Verwijderresources en expliciet niet-APT-providers vallen buiten die controle. Bij een onopgeloste provider, overerving, overrides of samengestelde opties kan een `[review]`-melding volgen. Beoordeel dan de effectieve opties en de reden voor een eventuele pakketuitzondering. De check heeft geen autofix.

Recursieve bestandsbewerkingen vragen een andere afweging: welke inhoud is volledig eigendom van de module? Gebruik purge, force en recurse alleen voor zulke mappen. Houd `replace => false` op bestanden waarvan een installer of eenmalige initialisatie de inhoud bepaalt.

Bij een gemengde boom beheer je mappen en gewone bestanden apart, zodat bestanden geen onnodige uitvoerrechten krijgen. Voor geëxporteerde applicatiebomen zijn `0750` voor mappen en `0640` voor bestanden het uitgangspunt, tenzij de applicatie aantoonbaar andere rechten nodig heeft. Een private boom zonder uitvoerbare bestanden mag recursief `0600` gebruiken; Puppet voegt dan de zoekrechten voor mappen toe. De inhoud van de boom en de gevolgen van opschonen blijven onderdeel van de handmatige review.

#### Eigenaars en rechten

Bepaal eerst welke gebruiker een bestand tijdens uitvoering leest of schrijft en welke bovenliggende mappen daarvoor bereikbaar moeten zijn. Stel eigenaar, groep en modus expliciet in. Geef geheimen en gevoelige configuratie alleen de toegang die voor dat gebruik nodig is. De gebruikelijke uitgangspunten zijn:

| Bestand of map | Gebruikelijke rechten |
| --- | --- |
| Private configuratie | `0600` |
| Script dat alleen root uitvoert | `0700` |
| Sudoersfragment | `0440` |
| Systemd-unit | `0644` waar systemd dat nodig heeft |
| Statisch terugvalbestand voor een service | Root als eigenaar, de servicegroep en `0640`; zo nodig `0710` voor bovenliggende mappen |

Houd SSH-homes en `.ssh` privé en geef gewone bestanden alleen uitvoerrechten als ze daadwerkelijk uitvoerbaar moeten zijn. Licht wereldleesbare of groepsschrijfbare toegang toe. Een bestand dat via HTTP openbaar is hoeft bijvoorbeeld lokaal alleen door de webserver gelezen te kunnen worden.

Bij Linux-symlinks stel je het eigenaarschap expliciet in en beveilig je het doel. Een afzonderlijke chmod-modus op de symlink biedt daar geen bruikbare bescherming.

Controleer ook de toegang via sudo, logrotate, audit, monitoring en services vanuit de gebruiker die het werk uitvoert. Gebruik waar nodig `Sensitive[...]` of `Sensitive.new(...)` voor gevoelige inhoud en commando's, zodat die niet in rapporten terechtkomen.

`project_files` controleert de expliciete attributen, recursieve uitvoerrechten en uitsluiting van `source` en `content`, met inbegrip van zichtbare lokale defaults. Overerving en overrides kunnen extra cataloguscontrole vragen. De check heeft geen autofix: hij kan niet bepalen welke gebruiker toegang nodig heeft. Beoordeel zelf de effectieve rechten, de inhoud van recursieve bomen en de bereikbaarheid van bovenliggende paden.

#### Shellcommando's in Puppet

Geef dynamische Puppet-waarden als afzonderlijk voorbereide shellwoorden aan een exec-commando door. Gebruik daarvoor `stdlib::shell_escape(...)`, sla het resultaat op in een `*_shell`-variabele en voeg dat resultaat zonder extra aanhalingstekens aan het commando toe. Dit geldt ook voor de guards `onlyif` en `unless`. Een optionele guard mag `undef` zijn; de takken die een commando opleveren hebben wel veilige escaping nodig.

Maak onderscheid tussen een Puppet-waarde en een variabele die de shell pas tijdens uitvoering invult. In een dubbele Puppet-string escape je die shellsyntaxis, bijvoorbeeld als `\$tmpdir`, `\$1` of `\$(...)`, zodat Puppet haar niet zelf interpreteert.

Quoting hoort bij de parserlaag die het argument leest. Een script dat uit ge-escapete woorden is opgebouwd, krijgt zelf nog eenmaal quoting wanneer je het als buitenste `-c`-argument doorgeeft. Escape dezelfde laag niet tweemaal. Een volledig statisch script mag eenmaal als geheel worden ge-escapet.

Voor SQL escape je de volledige SQL-string en behoud je de afsluitende puntkomma. Gebruik `provider => shell` wanneer puntkomma's of guards anders als afzonderlijke commando's worden gelezen.

Gebruik voor dynamische tekst bij voorkeur `/usr/bin/printf %s ${value_shell}`. Bewust voorbereide regeleinden kun je als letterlijke `\n` vastleggen, eenmaal escapen en met `printf %b` decoderen. Voor willekeurige gebruikers- of runtime-inhoud over meerdere regels is een bestand of template geschikt.

`project_shell` volgt de herkomst van waarden in exec-commando's en guards. Een variabelenaam met `_shell` bewijst op zichzelf geen escaping. De check heeft geen autofix en kan ook niet bewijzen dat een veilig ge-escapet woord op de juiste plaats in het commando staat. Voer samengestelde commando's daarom geïsoleerd uit met synthetische argumenten die spaties, aanhalingstekens en shelltekens bevatten.

#### Afhankelijkheden, audit en transport

Gebruik voor lokale integraties bij voorkeur de bestaande modules. De runtimeafhankelijkheden zijn beperkt tot `stdlib`, `concat`, `reboot`, `timezone` en `debconf`, behalve wanneer een eis aantoonbaar niet goed lokaal kan worden ingevuld. Een externe Docker-, MySQL-, Nginx- of RabbitMQ-module toevoegen alleen vanwege vergelijkbare functies past daar niet bij. Neem bij nieuwe gevoelige onderdelen ook pakketbeleid, monitoring en audit mee in de beoordeling.

Een audituitzondering bepaalt welke gebeurtenissen uit beeld verdwijnen. Leg bij een wijziging uit welk legitiem gedrag de uitzondering nodig maakt, welke events verdwijnen en waar zij geldt. Controleer naburige uitzonderingen op overlap, zodat de gezamenlijke reikwijdte duidelijk blijft.

Reverse proxies en verbindingen tussen services gebruiken standaard versleuteling. Alleen voor een upstream zonder TLS is HTTP een expliciete, gedocumenteerde keuze. Los certificaatproblemen op zonder de versleuteling uit te schakelen. Bij lokale of self-signed upstreams leg je vast welke keuze voor vertrouwen en verificatie nodig is.

Licht een minder streng vertrouwens-, rechten- of sandboxmodel bij de code toe. Als beheerders die keuze vooraf moeten kennen, hoort de uitleg ook in de project-README. Deze afwegingen vragen een inhoudelijke beveiligingsreview; de lintscan kan ze niet bewijzen.

### Gedeelde services en systemd

`basic_settings` verzorgt de gedeelde serverbasis, van pakketten en APT-bronnen tot systemd, monitoring, loginbeleid en beveiligingsgereedschap. Ook pakketonderhoud, kernel, netwerk, tijdzone en Puppet-runtimegedrag sluiten daarop aan. Integreer andere modules met deze bestaande voorzieningen.

Daarvoor zijn onder meer de bouwstenen `basic_settings::systemd_target`, `systemd_drop_in`, `systemd_service`, `systemd_timer`, `systemd_network`, `monitoring_service`, `monitoring_custom`, `monitoring_timer`, `monitoring_npm_audit`, `security_audit`, `io_logrotate` en `login_sudo` beschikbaar. Gebruik ze voor hun eigen taken, zodat featuremodules geen tweede uitvoering van die voorzieningen krijgen.

De volgende afwegingen beoordeel je bij de review en functionele validatie. Alleen backendselectie bij monitoringaanroepen heeft hier een gerichte projectcheck. De linter controleert geen volledige systemd-ordering of servicehardening.

#### Targets en monitoring

De gedeelde targets bepalen hoe de serveronderdelen op elkaar aansluiten. Behoud hun volgorde: `${cluster_id}-system`, `${cluster_id}-storage`, `${cluster_id}-services`, `${cluster_id}-production`, `${cluster_id}-helpers` en `${cluster_id}-require-services`. Een geïntegreerde service gebruikt de gedeelde drop-in-wrapper en bindt aan het passende target. Schakel daarbij vendor-enablement uit. Bij actieve monitoring krijgt de service `OnFailure=notify-failed@%i.service`.

Beoordeel de unit zoals die uiteindelijk op de host terechtkomt. Neem daarvoor de gegenereerde units, lokale wrappers, vendor-drop-ins, directe Service-resources, templates en statische units mee. Vermeld de beoordeelde unitnamen alfabetisch in de review.

Monitoring sluit aan op het centrale OpenITCOCKPIT-agentmodel. Plugins staan onder `/etc/openitcockpit-agent/plugins`; `concat` en `concat::fragment` bouwen `customchecks.ini` op. Gebruik de gedeelde monitoringtypes voor de registratie van services, timers en eigen checks, zodat featuremodules die registratie niet dupliceren.

`basic_settings::monitoring_custom` kiest en configureert de backend. Een aanroeper controleert alleen of monitoring beschikbaar en ingeschakeld is. Bijvoorbeeld:

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

#### Servicebeveiliging

Kies beveiligingsopties voor de concrete `.service` die het proces uitvoert. Dat geldt ook wanneer een timer, socket of path die service start. Service-uitvoeringsopties horen in de service, niet in targets, mounts, sockets, timers of de daemonconfiguratie van journald, resolved en timesyncd.

Begin de beoordeling bij de uiteindelijke unit en de Puppet-code of template die haar opbouwt. Loop daarna alle Exec-fasen na. Welke gebruikers en aanvullende groepen voeren ze uit? Zijn capabilities, sudo of setuid nodig? Controleer welke paden, bestanden, sockets en logs bereikbaar of schrijfbaar moeten zijn, inclusief tijdelijke opslag, apparaten, homes en credentials.

Neem ook netwerk- en pakketgedrag, de runtime, plugins, JIT/VM's en procesinspectie mee. Een bekende native oneshot heeft meestal minder afhankelijkheden dan provisioning, pakketbeheer, Puppet, GitLab omnibus, Certbot-hooks, SSH-sessies, monitoringexecutors, OpenITCOCKPIT of back-up- en herstelsoftware. Vooral gedeelde bestanden, apparaten en helpers die privileges wijzigen kunnen een algemene hardeningkeuze ongeschikt maken.

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

Voor private uitvoer zet je `UMask=0077` expliciet in de servicespecifieke hash bij de sandboxinstellingen. Is het normale `0022`-gedrag nodig, laat de instelling dan weg. Een ander gedeeld masker, zoals `0027`, krijgt een toelichting bij de service.

Beveiligingsdefaults in een generieke wrapper raken alle services die die wrapper gebruiken. Verberg daar daarom geen umask of andere beveiligingskeuze. Beoordeel bij een wijziging iedere bekende gebruiker en valideer het gedrag, of bied per service een gedocumenteerde mogelijkheid om de betreffende beperking uit te schakelen.

### Shellscripts en monitoring

De shellcode van monitoringchecks valt buiten Puppet-lint. De onderstaande afspraken vragen daarom afzonderlijke review en synthetische validatie. Gebruik daarbij de [monitoringcontracten](../../AGENTS.md#monitoring-checks): één gedeeld executable per check, instellingen per target en behoud van de andere registraties wanneer één target wordt verwijderd. Voor shellcode geldt [vier spaties inspringing](../../AGENTS.md#shell-formatting), ook na het renderen van een template.

#### Opbouw van een check

Monitoringchecks gebruiken POSIX `#!/bin/sh` en Nagios-exitcodes. Gebruik daarin geen Bash-constructies zoals arrays, `[[ ... ]]`, `(( ... ))`, `function`, process substitution, here-strings, `pipefail`, `read -d` en Bash-specifieke expansies. Ook andere nieuwe scripts en templates gebruiken POSIX shell, tenzij de benodigde functionaliteit Bash vereist.

`mysql/files/automysqlbackup` is een bestaande Bash-uitzondering vanwege arrays, indirecte expansie en rekenkundige lussen. Licht bij wijzigingen aan een Bash-script toe waarom Bash nodig blijft.

Bekijk vóór een nieuwe of gewijzigde check de meest verwante bestaande checks. Sluit aan op hun opbouw en hun verwerking van status, parsing, ernst, buffering, afkappen en perfdata. Als dat patroon niet bij de check past, leg dan uit waarom je ervan afwijkt.

Een check is in deze volgorde opgebouwd:

1. Een fouthelper voor fouten die ook tijdens de voorbereiding kunnen optreden.
2. Het zoeken van de benodigde binaries.
3. De initialisatie van standaardwaarden en omgevingsvariabelen volgens het [configuratiecontract](../../AGENTS.md#monitoring-check-configuration).
4. Eén POSIX `while getopts ... opt; do`-blok voor de CLI-opties.
5. Helpers en validatie van de effectieve instellingen, voordat die worden gebruikt.
6. De hoofdlogica.

Zoek een binary rechtstreeks met `COMMAND=$(command -v command 2>/dev/null) || die ...`. Op de commandopositie wordt `$COMMAND` zonder aanhalingstekens aangeroepen. Quote wel de data-argumenten, tests en toekenningen. Gebruik shellbuiltins rechtstreeks en gebruik `printf` voor uitvoer.

Geef iedere CLI-optie een eigen case-tak met een toekenning. Sluit de verwerking af met één usage-/fouttak voor ongeldige opties en hulp, inclusief `-h` wanneer die optie is gedeclareerd. Lange uitvoer staat standaard aan; een schakelaar daarvoor wordt alleen op verzoek toegevoegd.

#### Invoer en configuratie

Een monitoringcheck heeft zijn optionele runtime-defaults in het executable. Puppet geeft alleen instellingen door die expliciet zijn ingevuld. Gebruik voor zulke Puppet-parameters een passend `Optional[...]` met `undef` als default. Bij `undef` laat de registratie zowel de CLI-optie als het argument weg. Zo ontstaan er geen tweede defaults in manifests, wrappers of ERB-expressies. Pas dit toe op nieuwe instellingen en bij wijzigingen aan bestaande defaultverwerking.

De check verwerkt commandline-opties, omgevingsvariabelen en defaults volgens het [configuratiecontract in `AGENTS.md`](../../AGENTS.md#monitoring-check-configuration). Valideer de effectieve waarden met tijdelijke synthetische invoer, ongeacht de bron van die waarden. Daarbij horen syntaxis, eenheden, bereik, onderlinge drempelvolgorde en runtimebetekenis. Puppet mag twee expliciet opgegeven drempels alvast vergelijken, maar neemt daarvoor geen ontbrekende scriptdefault over.

Als de check Puppet-data nodig heeft, gebruik je een ERB-template met directe shelltoekenningen. Beperk ERB tot het invoegen van variabelen. De voorbereiding in Puppet blijft beperkt tot defaults voor beheerde configuratie, serialisatie en shellveilige waarden. Voeg alleen een afzonderlijk checkconfiguratiebestand of een parser toe wanneer dat is gevraagd of al gebruikelijk is.

Behoud voor daemonconfiguratie en inloggegevens de bestaande invoerroute. Kopieer die gegevens niet naar nieuwe CLI-opties of omgevingsvariabelen. Lees waar mogelijk de effectieve daemonconfiguratie, bijvoorbeeld met `vnstat --showconfig`, zodat je geen tweede instellingen of sysfs-terugvalroutes hoeft te onderhouden.

Het uitvoerinterval en de timeout van de monitoringagent horen bij de registratie. Een scriptoptie of omgevingsvariabele verandert die agentinstellingen niet. Controleer hun samenhang volgens de [afspraken voor de executor](../../AGENTS.md#executor-scheduling).

#### Waarden en helpers

Groepeer instellingen en afgeleide waarden naar hun doel en geef iedere groep een korte toelichting. Dat maakt reeksen defaults, drempels, statuswaarden, tellers, samenvattingen, perfdata, paden, rechten, commando's en relaties herkenbaar.

Een helper is nuttig als hij een taak benoemt, gedeelde validatie of opmaak afhandelt of wezenlijke duplicatie wegneemt. Een losse append, toekenning of `printf` heeft zonder zo'n reden geen eigen helper nodig. Houd eenmalige verwerking bij elkaar als dat duidelijker leest en zet de inhoudelijke verwerking vóór een kleine terugvaltak.

Voor begrensde tellers, perfdata, sorteerbuffers en diagnoses volstaan shellvariabelen en `printf`. Gebruik `mktemp` en tijdelijke bestanden wanneer een commando een bestand vereist of de data te groot of onveilig is voor variabelen. Ruim die bestanden na gebruik op.

Maak regeleinden expliciet met `printf`-formaten en ge-escapete regeleinden; zet geen letterlijke lege regels in gequote toekenningen. Serialiseer lijsten bewust als CSV. Geef metadata uit commandosubstitutie expliciete markeertokens, zodat de verwerking niet afhankelijk is van kunstmatig toegevoegde regeleinden.

#### Uitvoer voor beheerders

De eerste uitvoerregel vertelt wat er wordt gecontroleerd en wat de beheerder ermee moet. Noem de service, unit, module, interface of resource. Bij een fout of onduidelijke uitkomst horen daar het belangrijkste geraakte object, de directe oorzaak en een indicatie van benodigde escalatie bij. Een gezonde check meldt dat het onderdeel normaal werkt.

De machinestatus staat in de exitcode. Begin de tekst daarom niet met een Nagios-statuswoord en gebruik die statusnamen ook niet als labels voor oorzakenlijsten. Houd de eerste regel vrij van nulcategorieën, overzichten van drempels, interne beslislabels en perfdata-achtige fragmenten. Tellers kunnen in perfdata of de lange uitvoer staan.

Maak in de diagnose duidelijk of het gaat om een configuratiefout, runtimefout, contextuele waarschuwing of onbekende toestand. Heeft de check bewust een beperkte reikwijdte, vermeld die dan. Informatie daarbuiten mag de exitcode niet veranderen.

Zet in de lange uitvoer de belangrijkste diagnose vooraan. Beschrijf het betrokken onderdeel, wat is waargenomen, de waarschijnlijke oorzaak en een bruikbare vervolgstap of escalatieroute. Verberg de hoofdoorzaak niet tussen details en neem daar geen drempelwaarden op.

Sluit niet-triviale lange uitvoer af met `Interpretation:`. Leg daarin uit hoe de getoonde gegevens, reikwijdte en context gelezen moeten worden. De perfdata hoeft daar niet nogmaals te worden opgesomd.

#### Veilige en begrensde uitvoer

Volg eerst de uitvoerroute van de check voordat je normalisatie toevoegt. Vaste, veilige tekst hoeft niet te worden bewerkt. Normalisatie is nodig wanneer runtimegegevens, externe data of bewuste scheidingen onveilige pipes of ongewenste lege regels kunnen opleveren. Licht een niet-vanzelfsprekende bewerking bij de code toe.

Nagios kan tekst na een pipe ook op vervolgregels als perfdata lezen. Maak ruwe `|`-tekens daarom veilig zodra dynamische data in de lange uitvoer wordt opgenomen. Begin en eindig zonder lege regels en zet één lege regel tussen afzonderlijke secties; opeenvolgende lege regels zijn niet toegestaan.

Gebruik per diagnoseblok één configureerbare manier van afkappen. Het stapelen van item-, regel-, blok- en tekenlimieten op dezelfde verzameling maakt onduidelijk welke informatie wordt getoond. Een ander uitvoerkanaal mag een eigen limiet hebben wanneer het niet dezelfde gegevens afkapt.

Bij een relevante UI-limiet begrens je het totale aantal tekens boven `Interpretation:`. Zet de afkapmelding vóór die laatste uitleg, zodat de interpretatie en vervolgstap zichtbaar blijven.

Een limiet op gegevensverzameling heeft een ander doel dan een limiet op de uiteindelijke tekst. APT-ophaal-, groeps- en tijdslimieten of een journalvenster begrenzen het externe werk en de invoer. Ze begrenzen niet de diagnose die al is verzameld. Leg dat onderscheid uit en behoud zichtbare meldingen wanneer uitvoer wordt afgekort.

#### Perfdata en compatibiliteit

Gebruik compacte, stabiele snake_case-labels die met een kleine letter beginnen en verder alleen kleine letters, cijfers en underscores bevatten. De eenheid hoort in het UOM-veld, bijvoorbeeld `%`, `B`, `s` of `Mbps`, en niet in een voor- of achtervoegsel van het label. Laat afsluitende lege velden weg: gebruik puntkomma's tot en met het laatste ingevulde optionele veld.

De eenheid `c` is bedoeld voor een monotone teller die oploopt tot een reset. Gebruik haar niet voor gauges, begrensde aantallen, huidig gebruik, piekwaarden, snelheden of periodetotalen.

Exitgedrag, samenvattingsvorm, perfdatakeys, CLI-opties, gegenereerde paden en registratienamen vormen de externe interface van de check. Behoud ze, tenzij de opdracht expliciet zo'n afspraak wijzigt. Leg bij een wijziging de operationele reden uit en valideer gezond, fout- en onbekend gedrag.

## Linter ontwikkelen en onderhouden

Dit gedeelte is bedoeld voor wijzigingen aan de linter, de configuratieroute of de ontwikkelbundle. Voor een gewone Puppet-wijziging volstaan de [werkwijze](#werkwijze-bij-een-wijziging) en de relevante codeafspraken.

### Een check toevoegen of wijzigen

Zoek eerst de bestaande codeafspraak en bepaal welk onderdeel automatisch vast te stellen is en welk onderdeel review blijft. Controleer of een standaardcheck, geïnstalleerde plugin of bestaande projectcheck het probleem al afhandelt. Breid die waar mogelijk uit; voeg geen tweede detectie- of correctiepad toe voor hetzelfde contract.

De [configuratie](../../.puppet-lint.rc) bevat de pluginlijst en algemene opties. Projectchecks staan onder [`lib/puppet-lint/plugins/`](lib/puppet-lint/plugins/). Gebruik `PuppetLint.new_check` en de native diagnostiek. Meldingen moeten de oorzaak en een bruikbare bronpositie geven; neem geen willekeurige bronwaarden in diagnostiek of JSON op. Gebruik `[review]` als de analyse geen voldoende bewijs voor de gewenste eigenschap of correctie kan leveren.

Werk bij een gewijzigde codeafspraak de relevante regel en het [checkoverzicht](#beschikbare-projectchecks) samen bij. Geef aan wat detectie en autofix daadwerkelijk dekken en wat handmatig blijft. Verander je een algemene conventie, neem dan de regressietests en alle geraakte first-party code in dezelfde wijziging mee. De [documentatie-indeling](../../AGENTS.md#lint-documentation-maintenance) bepaalt waar nieuwe kennis thuishoort.

Voeg tooltests toe onder [`.tools/tests/lint/`](../tests/lint/) die geldig en ongeldig gebruik, grensgevallen en de grenzen van de analyse controleren. Gebruik de [testhandleiding](../tests/README.md#tests-toevoegen) voor discovery en testscope. De bestaande helper laadt de echte centrale configuratie; maak geen tweede implementatie in tests. Wijzig je de CLI, configuratieloader of het downstream-script, test dan ook de native aanroep, exitcodes, geladen regels en isolatie van persoonlijke opties.

Voer tijdens het werk `bundle exec rake test:lint` uit en sluit af met de [volledige eindcontroles](#werkwijze-bij-een-wijziging). Tests van linteroutput mogen de parser gebruiken om geldige correcties te bewijzen; algemene module-, script- en monitoringtests blijven buiten deze testsuite. Voor autofix gelden de aanvullende criteria onder [Veilige autofixes ontwikkelen](#veilige-autofixes-ontwikkelen).

### Technische werking van de checks

De [CLI-tests](../tests/lint/cli_test.rb) controleren de configuratieroute met synthetische systeem- en persoonlijke optiebestanden. Ze bewaken ook de native opties, exitcodes en correcties. De vergelijking van de lintuitsluitingen met de Git-index bewaakt welke vendored modulemappen buiten de scan blijven.

[`model.rb`](lib/model.rb) gebruikt de Puppet-parser uit OpenVox voor de AST: declaraties, expressies, resources en hun omliggende structuur. De lexer van Puppet-lint levert commentaar en concrete witruimte. [`strings_documentation.rb`](lib/strings_documentation.rb) deelt de documentatiegrenzen en tekstverwerking; [`nullability.rb`](lib/nullability.rb) onderzoekt aantoonbare uitsluiting via `undef`, guards en lokale toekenningen. De analyse past geen catalogus toe en voert geen Puppet-functies uit.

De [downstream-loader](lib/config.rb) start de native optieparser met `--no-config --config` binnen de gedeelde checkout en herstelt daarna de oorspronkelijke werkmap. Dit maakt de relatieve pluginpaden bruikbaar vanuit andere projecten. De root-CLI leest dezelfde configuratie rechtstreeks; de loader vervangt geen ontbrekende `--no-config` in de buitenste CLI-aanroep, omdat persoonlijke opties dan al verwerkt kunnen zijn.

#### Omvang en validatiestructuur

`project_positive_flow` meldt een `if`-tak die minder codestructuur bevat dan de bijbehorende `else`. Een opdracht telt als één onderdeel; geneste blokken, resource-instanties, attributen en elementen in arrays, hashes en selectors tellen mee. Commentaar, witruimte, de lengte van strings en gewone functieargumenten tellen niet als extra opdrachten. Naast deze algemene vergelijking controleert dezelfde check de afsluitende structuur van validaties met `fail(...)` en `warning(...)`.

De validatiecontrole herkent rechtstreekse Puppet-aanroepen van `warning()` en `fail()`, ook met een voorloop-`::`. Strings, commentaar, parameterdefaults, afzonderlijke functiedefinities en functies zoals `example::warning()` vallen erbuiten. De positie wordt bepaald via de omliggende opdrachten en blokken, niet via de fysieke regelvolgorde.

#### Classcontroles en vindbare afnemers

`project_class_check_reuse` controleert letterlijke classnamen in de body van iedere class en ieder defined type afzonderlijk. De check telt echte variabelereferenties, inclusief interpolatie en gekwalificeerde verwijzingen vanuit vindbare manifests in het modulepad. Rechtstreeks gebruik via `@variabele` in statisch benoemde ERB-templates en `inline_template` telt ook mee. Commentaar, gewone stringtekst en gelijknamige lokale lambdavariabelen tellen niet als hergebruik. Dynamische classnamen, parameterdefaults, andere resourcetypen en indirecte template- of functielookups vallen buiten deze analyse; beoordeel die bij de review.

#### References en relatiecontext

`project_resource_references` gebruikt de Puppet-AST om references en aangrenzende array-elementen te herkennen. De analyse loopt via de omvattende expressies naar de relatiecontext; ingebouwde datatypen en lokale typealiases worden uitgesloten. De correctie hergebruikt de oorspronkelijke titeltokens, zodat spelling, escapes en fixes van andere checks behouden blijven. De regels voor sortering, dubbele titels en het verwijderen van de buitenste array staan bij [Resource references](#resource-references).

#### Voorbereiding van voorwaarden

`project_if_sections` volgt opeenvolgende toekenningen terug vanaf de variabelen in de voorwaarde, ook als een afhankelijkheid via een andere variabele loopt. De voorwaarden van aansluitende `elsif`-takken tellen mee bij dezelfde voorbereiding. Een losstaande toekenning of andere opdracht onderbreekt die reeks. Commentaar bij een eerder blok of een bovenliggende voorwaarde geldt niet voor een geneste `if`. Bij een toekenning zoals `$result = if ...` staat de toelichting boven de toekenning en eventuele voorbereiding. De check deelt de analyse van variabeleafhankelijkheden met `project_variable_sections`; de betekenis van de toelichting blijft onderdeel van de inhoudelijke review.

#### Hints voor variabelegroepen

Ontbreekt de toelichting bij de eerste variabele na `{`, dan kan de melding ook naar een latere groep in hetzelfde blok verwijzen. Daarvoor moeten de eerste toekenningen dezelfde buitenste functie aanroepen, bijvoorbeeld `stdlib::shell_escape(...)`. De check kijkt alleen voorbij andere toekenningen en stopt zodra de oorspronkelijke variabele wordt gebruikt. Functieaanroepen met een eigen lambdablok vormen zelf geen kandidaat. De melding noemt de regel van het bestaande commentaar, zodat je kunt beoordelen of samenvoegen de code duidelijker maakt. De hint is geen bewijs van inhoudelijke samenhang: controleer ook of de volgorde van uitvoeren mag veranderen.

#### Backendselectie en wrappers

`project_monitoring_backend` volgt de centrale packagewaarde door toekenningen en voorwaarden. Parameters die aantoonbaar als `package` worden doorgegeven aan een monitoringaanroep tellen ook mee. De check herkent lokale wrappers en statisch benoemde wrappers in het ingestelde modulepad, inclusief classes via `include`, `contain` en `require`. Hij meldt de oorspronkelijke backendselectie één keer, ook als meerdere aanroepen ervan afhangen. Gewone pakketkeuzes zonder die relatie vallen buiten de check; `monitoring_custom` zelf blijft verantwoordelijk voor de concrete backendimplementatie.

### Veilige autofixes ontwikkelen

Begin bij de gebruikte bundle: controleer `bundle exec puppet-lint --no-config --config .puppet-lint.rc --version` en bekijk de implementatie met `bundle show puppet-lint`. Volg de [afspraken voor hergebruik en autofixontwikkeling in `AGENTS.md`](../../AGENTS.md#linting-and-autofix).

De correctie mag geen informatie verzinnen, ontwerpkeuze maken of commentaar verliezen. Controleer ook dat het resultaat geldige Puppet-code is en dat dezelfde regel na de correctie geen melding meer geeft. Bewijs dit voor de hele constructie die je wijzigt; alleen de gemelde regel bekijken is niet voldoende.

Implementeer `fix(problem)` binnen de betreffende `PuppetLint.new_check`. Bewaar tijdens `check` de betrokken tokenobjecten en de voorwaarden voor correctie. Geef de melding een index naar die context, zoals de bestaande projectchecks doen, zodat JSON-diagnostiek geen bronwaarden bevat. Controleer alle voorwaarden voordat je tokens wijzigt. Gebruik `PuppetLint::NoFix` wanneer die voorwaarden niet gelden; Puppet-lint behoudt dan de oorspronkelijke melding.

Gebruik `add_token`, `remove_token` en de eigenschappen van bestaande tokens voor de correctie. Hergebruik tokens die andere checks ook kunnen aanpassen en bepaal benodigde afstanden uit de actuele tokeninhoud. Regel- en kolomnummers blijven tijdens de fixfase bij de oorspronkelijke bron horen. De gedeelde helpers in [`token_helpers.rb`](lib/token_helpers.rb) ondersteunen tokengebieden en witruimte; zij parsen of herschrijven geen volledig bestand.

Puppet-lint voert eerst alle checks uit en daarna de fixes. Houd daarom rekening met eerder gewijzigde of verwijderde tokens. De parameteruitlijning vernieuwt vlak vóór haar fixes de meldingen op de bewaarde tokens via de native `run`-methode: een eerdere komma- of tabcorrectie kan de breedte van een type veranderen. De native afhandeling van `lint:ignore` en `fix(problem)` blijft daarbij actief. Een correctie over meerdere regels moet ook controleren of zij een genegeerd deel zou veranderen.

Voeg regressietests toe onder [`.tools/tests/lint/`](../tests/lint/) voor detectie zonder wijziging, exacte uitvoer, een schone hercontrole en een ongewijzigde tweede fixrun. Test ook ongeschikte invoer, genegeerde meldingen, comments, strings, meerdere problemen, geneste constructies en samenwerking met de actieve upstream-checks. Test de native CLI op tijdelijke bestanden om de schrijfhandeling en exitcodes te controleren. Parservalidatie van de geproduceerde uitvoer hoort bij het fixcontract; een algemene syntaxsuite voor modules hoort niet bij deze tooltests.

De normale CLI-aanroep en CI blijven alleen controleren. Schakel `fix` uitsluitend in bij een expliciete correctiestap en voeg geen tweede formatter of automatische commitstap toe.

### Versies bijwerken

Bij de eerste installatie gebruikt Bundler de versies uit de lockfile. Wil je die combinatie bijwerken, voer dan het volgende uit vanuit de hoofdmap van deze repository, met de nieuwste stabiele Ruby actief:

```sh
gem install bundler
BUNDLE_VERSION=system bundle update --all
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec rake test
git diff -- Gemfile.lock
```

[`bundle update --all`](https://bundler.io/man/bundle-update.1.html) kiest de nieuwste stabiele gems die onderling en met de ingestelde Ruby-versie passen. Gems kunnen zelf beperkingen aan hun afhankelijkheden stellen. Gebruik geen prereleases voor de gewone ontwikkelomgeving.

Controleer de gewijzigde lockfile en eventuele codeaanpassingen in de review. `bundle install` gebruikt daarna steeds die geteste combinatie.

Werk op macOS Ruby bij met `brew update` en `brew upgrade ruby`. Open daarna een nieuwe terminal, zodat ook het pad voor gemcommando's opnieuw wordt bepaald, en volg opnieuw [Gems installeren](#gems-installeren). Draai na een Ruby-update de volledige lintscan en testsuite.

### CI van deze repository

[De CI-workflow](../../.github/workflows/lint.yml) kiest met `ruby-version: ruby` de nieuwste stabiele Ruby en voert dezelfde installatie, lintscan en tooltests uit. `BUNDLE_FROZEN=true` voorkomt dat een afwijking tussen Gemfile en lockfile stilzwijgend wordt bijgewerkt. Met `BUNDLE_PATH` kun je gems lokaal bijvoorbeeld in `vendor/bundle` installeren.

CI heeft alleen leesrechten, bewaart geen checkoutcredentials en maakt geen wijzigingen of commits.

De Actions gebruiken de versietags [`actions/checkout@v7`](https://github.com/actions/checkout) en [`ruby/setup-ruby@v1`](https://github.com/ruby/setup-ruby). Die volgen updates binnen hun hoofdversie. Een nieuwe hoofdversie moet apart in de workflow worden gekozen. Bundler wordt rechtstreeks met `gem install bundler` geïnstalleerd. Een update binnen deze versies kan daardoor invloed hebben op een volgende CI-run zonder dat onze workflow is aangepast.

## De linter gebruiken in een ander Puppet-project

Gebruik je deze moduleverzameling in een ander Puppet-project, dan kun je dezelfde linter ook voor je eigen manifests, rollen en profielen gebruiken. Je stelt in waar de linter staat, welke bestanden je wilt controleren en waar Puppet de modules vindt.

Je project krijgt een eigen `.puppet-lint.rc` die de centrale configuratie laadt. De plugins en [coderegels](#beschikbare-projectchecks) komen rechtstreeks uit de checkout van de moduleverzameling die je project al gebruikt.

De voorbeelden hieronder gaan uit van deze mappen:

```text
project/
├── .puppet-lint.rc
├── .tools/
│   └── lint.rb
├── manifests/
├── modules/
│   └── profile/
│       └── manifests/
└── global-modules/              # Bestaande checkout van DevSysEngineer/puppet-modules.
    ├── .tools/lint/README.md
    ├── .puppet-lint.rc
    ├── Gemfile
    └── Gemfile.lock
```

`project/` is de hoofdmap van je eigen project. De linter staat onder `global-modules/` en controleert de eigen code onder `manifests/` en `modules/profile/manifests/`.

`global-modules/` is een voorbeeldpad. Staat de moduleverzameling ergens anders, vervang dit pad dan in de installatiecommando's, je `.puppet-lint.rc` en het script. Een dieper pad met spaties, zoals `dependencies/shared modules/puppet-modules`, werkt ook.

### Benodigdheden

Gebruik een volledige checkout van deze repository. Daarin moeten `.puppet-lint.rc`, `Gemfile`, `Gemfile.lock` en de hele map `.tools/lint/` aanwezig zijn. Die laatste map bevat de configuratieloader `lib/config.rb`, de plugins en de Ruby-bestanden die ze nodig hebben, waaronder `lib/model.rb` en `lib/nullability.rb`. Een pakket met alleen Puppet-modules is dus niet voldoende. Controleer ook of verborgen bestanden worden meegeleverd.

Haal de submodules `concat`, `debconf`, `reboot`, `stdlib` en `timezone` op. Dit zijn Puppet-modules die nodig kunnen zijn om aanroepen en catalogi te controleren.

Wil je ook de tooltests uitvoeren, behoud dan de volledige checkout, inclusief `.tools/tests/`, `Rakefile` en de Git-index. De tests gebruiken de index om te controleren welke modulemappen de lintscan uitsluit.

### Installatie in je project

Gebruik de nieuwste stabiele Ruby en Bundler. Richt op macOS eerst [Ruby](#ruby-op-macos) in. Voer daarna onderstaande commando's uit vanuit de hoofdmap van je eigen project. Het voorbeeld gaat uit van een bestaande checkout onder `global-modules`; pas dat pad aan als de moduleverzameling elders staat.

Gebruik hiervoor een gewone terminal, buiten een eventueel eigen `bundle exec`. Heb je zelf `BUNDLE_*`-variabelen voor een andere gemomgeving ingesteld, verwijder die dan eerst. Denk bijvoorbeeld aan `BUNDLE_WITHOUT`, waarmee gems kunnen worden overgeslagen.

```sh
git -C global-modules submodule update --init --recursive
gem install bundler
(
    lint_root="$PWD/global-modules"
    export BUNDLE_GEMFILE="$lint_root/Gemfile"
    export BUNDLE_FROZEN=true BUNDLE_VERSION=system
    bundle install
)
```

Bundler installeert de Ruby-pakketten, de gems, uit `global-modules/Gemfile`. De bijbehorende `Gemfile.lock` bepaalt welke versies worden gebruikt. De installatie en het lintscript gebruiken de gewone Bundler-instellingen, net als wanneer je rechtstreeks in de moduleverzameling werkt. Bundler bepaalt waar de gems komen te staan; het lintscript stelt geen aparte installatiemap in.

Deze installatie levert ook de aanvullende lintplugins en de OpenVox-parser. Heeft je project een eigen Gemfile, blijf die dan voor je eigen ontwikkelgereedschap gebruiken. Je hoeft daar geen gems voor deze linter aan toe te voegen.

Deze `BUNDLE_*`-instellingen kiezen de gedeelde bundle en behouden de vastgelegde gemversies:

| Instelling | Gevolg |
| --- | --- |
| `BUNDLE_GEMFILE` | Kiest de Gemfile van de moduleverzameling. |
| `BUNDLE_FROZEN=true` | Voorkomt dat Bundler de lockfile tijdens de installatie wijzigt. |
| `BUNDLE_VERSION=system` | Gebruikt de geïnstalleerde Bundler. |

De haakjes rond het installatieblok zorgen dat deze instellingen alleen binnen dat blok gelden. Daarna kun je je gewone projectcommando's blijven gebruiken. Persoonlijke Bundler-instellingen en de lokale configuratie onder `global-modules/.bundle/` blijven van toepassing. Gebruik bij installatie en controle dezelfde instellingen als je zelf een gemlocatie kiest, bijvoorbeeld met `BUNDLE_PATH`.

### Eigen lintconfiguratie

Maak in de hoofdmap van je eigen project een `.puppet-lint.rc` met deze inhoud en neem dit bestand op in versiebeheer:

```text
--load=global-modules/.tools/lint/lib/config.rb
```

Deze verwijzing laadt de `.puppet-lint.rc` van de moduleverzameling. Daardoor gebruikt je project steeds de lintregels uit de checkout die het al gebruikt. Je hoeft de centrale regels en pluginlijst niet naar je eigen project te kopiëren of daar bij te houden.

Pas `global-modules/` aan als de moduleverzameling elders staat. Schrijf het pad na `--load=` letterlijk, ook als het spaties bevat; voeg geen aanhalingstekens toe. De loader leest de centrale configuratie vanuit de gedeelde checkout, zodat de relatieve pluginpaden kloppen, en herstelt daarna de werkmap van je project. Alleen `--config=global-modules/.puppet-lint.rc` is niet voldoende: Puppet-lint rekent de pluginpaden dan vanaf je eigen project.

Houd je eigen `.puppet-lint.rc` beperkt tot deze verwijzing. De keuze van eigen manifests en modulepaden stel je hieronder in het lintscript in. Geef afwijkingen van lintregels centraal door, zodat gebruikende projecten dezelfde controles blijven uitvoeren.

### Eigen code controleren

Sla onderstaand script op als `.tools/lint.rb` in je eigen project. Zo staat het ontwikkelgereedschap, net als in deze repository, bij elkaar onder `.tools/`. Gebruik dit script zowel lokaal als in CI. Pas bovenaan deze drie instellingen aan:

| Instelling | Wat geef je op? |
| --- | --- |
| `lint_root` | De map waarin de moduleverzameling staat. |
| `source_dirs` | De mappen met je eigen Puppet-code, gerekend vanaf de hoofdmap van je project. |
| `module_dirs` | De volledige paden waarin Puppet modules zoekt, in dezelfde volgorde als in je environment. |

Het script start `bundle exec puppet-lint` vanuit de hoofdmap van je eigen project, laadt je `.puppet-lint.rc` en geeft de volledige paden naar je eigen manifests mee. De Gemfile en plugins komen uit de moduleverzameling.

```ruby
#!/usr/bin/env ruby

project_root = File.expand_path('..', __dir__)
lint_root = File.realpath(File.join(project_root, 'global-modules'))
project_config = File.join(project_root, '.puppet-lint.rc')
source_dirs = ['manifests', 'modules/profile/manifests']
module_dirs = [File.join(project_root, 'modules'), lint_root]

abort "Missing project lint file: #{project_config}" unless File.file?(project_config)

%w[Gemfile Gemfile.lock .puppet-lint.rc].each do |name|
  abort "Missing shared lint file: #{name}" unless File.file?(File.join(lint_root, name))
end

# Select production manifest directories; dependencies and negative fixtures stay outside this scope.
files = source_dirs.flat_map do |relative|
  directory = File.join(project_root, relative)
  abort "Missing source directory: #{directory}" unless File.directory?(directory)

  Dir.glob('**/*.pp', base: directory).map { |path| File.join(directory, path) }
end.select { |path| File.file?(path) && !File.symlink?(path) }.uniq.sort
abort 'No own Puppet manifests selected; check source_dirs' if files.empty?

unless ARGV.empty?
  abort 'Usage: ruby .tools/lint.rb [project-relative-manifest.pp]' unless ARGV.length == 1
  selected = File.expand_path(ARGV.first, project_root)
  abort "Manifest is outside the own lint scope: #{selected}" unless files.include?(selected)

  files = [selected]
end

ENV.update(
  'BUNDLE_GEMFILE' => File.join(lint_root, 'Gemfile'),
  'BUNDLE_FROZEN' => 'true',
  'BUNDLE_VERSION' => 'system',
  'PROJECT_LINT_MODULEPATH' => module_dirs.join(File::PATH_SEPARATOR),
)
puts "Puppet-lint: #{files.length} own manifests in #{project_root}"
$stdout.flush
Dir.chdir(project_root)
exec('bundle', 'exec', 'puppet-lint', '--no-config', '--config', project_config, '--ignore-paths=', *files)
```

Neem alle mappen met eigen Puppet-code op in `source_dirs`. Voeg bijvoorbeeld `modules/role/manifests`, `modules/application/manifests`, `roles`, `profiles` en de eigen mappen onder `environments/` toe als je die gebruikt. Nieuwe manifests binnen deze mappen worden automatisch gevonden. Maak je een nieuwe map voor rollen of een eigen module, voeg die dan ook aan het script toe.

Kies onder `modules/` de manifestmappen van je eigen modules. Zo blijven modules van derden buiten de stijlcontrole. Sluit niet heel `modules/` uit als daar ook eigen code staat. Houd geïnstalleerde gems en opzettelijk ongeldige testbestanden eveneens buiten de gekozen mappen. Bewaar zulke testbestanden bijvoorbeeld onder `spec/fixtures/`.

Voer vanuit de hoofdmap van je project een volledige scan uit. Met het tweede commando controleer je één eigen manifest; vervang dat pad door een bestaand bestand binnen de gekozen mappen.

```sh
ruby .tools/lint.rb
ruby .tools/lint.rb modules/profile/manifests/init.pp
```

De uitvoer begint met het aantal eigen manifests dat wordt gecontroleerd. Controleer of dat aantal klopt, vooral nadat je `source_dirs` hebt aangepast. Zonder manifests stopt het script met een fout. Een te kleine selectie kan wel slagen, ook als er elders in je project nog fouten staan.

Bij een lintfout zie je het volledige pad naar je eigen bestand, de regel, de kolom en de checknaam. Waarschuwingen, ontbrekende plugins en uitvoeringsfouten geven een foutcode terug, zodat ook CI mislukt.

Het script laadt met `--no-config --config` expliciet de `.puppet-lint.rc` van je eigen project, die de centrale lintconfiguratie inleest. Systeeminstellingen en persoonlijke lintinstellingen worden overgeslagen. `--ignore-paths=` vervangt alleen de bestandsuitsluitingen van de moduleverzameling: je hebt de te controleren bestanden al met `source_dirs` gekozen. De lintregels blijven gelijk.

Gebruik je een Puppet-fileservermount, volg dan de uitleg over de gerichte ignore bij [bestandsbronnen](#templates-en-bestandsbronnen). Beide bronchecks blijven standaard actief; de aanvullende check controleert de mount ook op regels met die ignore.

Deze scan controleert alleen `.pp`-bestanden. YAML, templates, documentatievoorbeelden en bestanden die zelf een symlink zijn vragen aparte controles. De optie `--relative` in de centrale configuratie gaat over de indeling van modules; foutmeldingen blijven het volledige bestandspad tonen.

Je kunt het script ook vanuit een andere werkmap starten. Geef dan het volledige pad naar `.tools/lint.rb` op. Het optionele manifestpad blijft gerekend vanaf de hoofdmap van je project. Geef geen extra lintopties mee en voeg geen eigen lintregels toe.

### Aanroepen van modules controleren

De check `project_interface_calls` controleert of je bij een aanroep de verplichte parameters meegeeft. Daarvoor moet de linter de class of het defined type kunnen vinden. Geef in `module_dirs` de mappen op waarin Puppet daadwerkelijk modules zoekt, in dezelfde volgorde als in je environment.

Het voorbeeld zoekt eerst in je eigen `modules/` en daarna in `global-modules/`. Wissel die volgorde als Puppet de gedeelde modules eerst gebruikt. Voeg ook de gebruikte modulemappen onder `environments/` en de mappen met modules van derden toe. Die modules moeten aanwezig blijven om aanroepen te kunnen controleren, ook als je hun code niet met `source_dirs` op stijl laat controleren.

Geef volledige, bestaande paden op. Vervang `$codedir`, `$basemodulepath` en relatieve paden door de overeenkomstige mappen op je eigen computer of CI-runner. De linter leest geen `environment.conf` en haalt geen instellingen van productieservers op. Gebruiken je environments verschillende modulepaden, controleer de code dan per environment met de bijbehorende paden. Eén gecombineerde lijst kan een andere versie van een module kiezen dan Puppet op de server.

Het script geeft `module_dirs` via `PROJECT_LINT_MODULEPATH` aan de check door. Op macOS en Linux worden de paden gescheiden door `:`. Spaties zijn toegestaan; een `:` in een mapnaam niet. Een leeg, relatief of niet-bestaand modulepad geeft een fout.

Zonder deze variabele zoekt de check alleen in de gedeelde moduleverzameling, waarbij `concat`, `debconf`, `reboot`, `stdlib` en `timezone` worden overgeslagen. Afzonderlijke eigen modules worden dan niet gevonden.

De check gebruikt eerst declaraties uit het bestand dat wordt gecontroleerd. Voor andere aanroepen kiest hij de eerste modulemap met de gevraagde modulenaam. Daarna volgt hij de gebruikelijke Puppet-indeling:

| Aanroep | Gezocht bestand binnen het modulepad |
| --- | --- |
| `example` | `example/manifests/init.pp` |
| `example::item` | `example/manifests/item.pp` |

Ontbreekt het manifest in de eerste gevonden module, dan zoekt de check niet verder in een latere kopie van die module. Bestanden die via een symlink buiten het opgegeven modulepad staan worden ook niet gelezen. Gebruik daarom een gewone checkout binnen een opgegeven modulepad.

> [!CAUTION]
> Vindt de linter een declaratie niet, dan kan een onjuiste aanroep toch door de lintscan komen. Een geslaagde scan bewijst dus niet dat Puppet de catalogus kan compileren. Blijf de aanroepen ook met je eigen catalogustests controleren.

Bij gevonden declaraties controleert de check verplichte parameters, ook bij `Optional[...]` zonder default. Argumenttypen, onbekende parameters, functies, dynamische classnamen, `include`/`contain`, Hiera en overerving worden hiermee niet volledig gecontroleerd. Dat geldt ook voor parameters die je via een splat (`* => $parameters`) meegeeft.

### Aanvullende tests

Voer naast de lintscan ook de syntax- en gedragstests van je eigen project uit. Deze controles vullen elkaar aan:

| Controle | Wat wordt gecontroleerd? |
| --- | --- |
| `ruby .tools/lint.rb` vanuit je eigen project | De gekozen eigen manifests, met de gedeelde lintregels en de modulepaden uit het script. |
| `bundle exec puppet-lint --no-config --config .puppet-lint.rc .` vanuit de gedeelde checkout, met de bijbehorende gems | De projectcode van de moduleverzameling volgens de gedeelde lintregels. |
| `bundle exec rake test` vanuit de gedeelde checkout | Het gedrag van de tools zelf, waaronder het gebruik van de linter vanuit een synthetisch extern project. Zie de [tooltesthandleiding](../tests/README.md). |
| De eigen parser-, metadata-, template-, catalogus- en gedragstests | Je eigen project, met de Puppet- of OpenVox-versie, facts, Hiera en modulepaden die je daarvoor wilt gebruiken. |

Controleer gewijzigde manifests ook rechtstreeks met de Puppet-parser. Voer dit voorbeeld uit vanuit de hoofdmap van je eigen project. Het gebruikt de eerder geïnstalleerde gems van de moduleverzameling. Vervang `global-modules` en het manifestpad waar nodig.

```sh
(
    export BUNDLE_GEMFILE="$PWD/global-modules/Gemfile"
    export BUNDLE_FROZEN=true BUNDLE_VERSION=system
    bundle exec puppet parser validate modules/profile/manifests/init.pp
)
```

Heeft je project een eigen gemomgeving voor tests, blijf die daarvoor gebruiken. Compileer catalogi in een aparte testomgeving met nagebootste facts, Hiera en inloggegevens. De linter past geen catalogi toe en heeft geen productiegeheimen of verbindingen met beheerde servers nodig.

### Controle in CI

Met onderstaande GitHub Actions-workflow voer je dezelfde lintscan uit als op je eigen computer. Neem de lintstappen op in je bestaande workflow of gebruik `.github/workflows/puppet-lint.yml`. De commando's starten vanuit de hoofdmap van je project. Zorg dat je bestaande checkoutstappen de moduleverzameling daar onder `global-modules/` klaarzetten voordat de lintstappen beginnen.

Pas `global-modules` in de installatiestap aan als je een ander pad gebruikt. De te controleren bestanden stel je alleen in `.tools/lint.rb` in. De workflow stopt bij lintfouten, ontbrekende plugins of uitvoeringsfouten. Voeg de eigen syntax- en gedragstests als aparte stappen of jobs toe.

Net als de [CI van deze repository](../../.github/workflows/lint.yml) installeert dit voorbeeld gems onder `vendor/bundle`, gerekend vanaf de map met de gedeelde Gemfile. De Bundler-instellingen gelden voor de hele job, zodat de installatie en de lintscan dezelfde gems gebruiken. CI negeert persoonlijke en lokale Bundler-configuratie en houdt de lockfile ongewijzigd.

```yaml
name: Puppet lint

on:
  pull_request:
  push:

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-24.04
    env:
      BUNDLE_IGNORE_CONFIG: '1'
      BUNDLE_VERSION: system
      BUNDLE_FROZEN: 'true'
      BUNDLE_PATH: vendor/bundle
    steps:
      - uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      # Keep the project's existing checkout steps for global-modules here.
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the shared locked bundle
        run: |
          export BUNDLE_GEMFILE="$PWD/global-modules/Gemfile"
          bundle install
      - name: Check all own manifests
        run: ruby .tools/lint.rb
```

### Problemen oplossen

| Probleem | Controle en herstel |
| --- | --- |
| Bundler mist gems of gebruikt de verkeerde Ruby | Controleer `ruby --version`, `command -v ruby` en `command -v bundle`. Voer het installatieblok opnieuw uit met de nieuwste stabiele Ruby en dezelfde Gemfile en installatiemap. Laat een foutieve lockfile niet tijdens de installatie bijwerken. |
| `Missing project lint file` | Maak de `.puppet-lint.rc` in de hoofdmap van je project zoals onder [Eigen lintconfiguratie](#eigen-lintconfiguratie). |
| `cannot load such file` voor `.tools/lint/...` | Controleer of de checkout volledig is en of het pad in je `.puppet-lint.rc` en `lint_root` naar dezelfde moduleverzameling wijzen. Het script moet Puppet-lint vanuit de hoofdmap van je eigen project starten. |
| De projectchecks lijken niet actief | Gebruik het commando onder deze tabel om de checks te bekijken. Voer daarna ook de proef met een bekende fout uit. |
| Een scan slaagt terwijl eigen code fout is | Controleer het gemelde aantal bestanden en `source_dirs`. Gebruik `ruby .tools/lint.rb`; een scan van `.` vanuit `global-modules` controleert alleen de moduleverzameling. |
| Er worden geen manifests gevonden of een bestand wordt geweigerd | Controleer de mappen in `source_dirs` en geef het manifestpad op vanaf de hoofdmap van je project. Voeg geen bestanden van derden toe om de scan toch te laten slagen. |
| Een onjuiste aanroep geeft geen melding | Controleer `module_dirs`, de volgorde van de modules en de plaats van het manifest. Test aanroepen die de linter niet kan beoordelen met je eigen catalogustests. |

Bekijk de beschikbare checks via je eigen `.puppet-lint.rc`. Voer dit uit vanuit de hoofdmap van je eigen project, met dezelfde Bundler-instellingen als bij de installatie. Pas `global-modules` waar nodig aan:

```sh
(
    export BUNDLE_GEMFILE="$PWD/global-modules/Gemfile"
    export BUNDLE_FROZEN=true BUNDLE_VERSION=system
    bundle exec puppet-lint --no-config --config .puppet-lint.rc --list-checks
)
```

De uitvoer moet de `project_*`-checks bevatten. Controleer bij de eerste inrichting ook of de linter fouten in je eigen code vindt. Voer deze proef uit vanuit de hoofdmap van je eigen project:

1. Maak tijdelijk `manifests/lint_probe.pp` met de inhoud `$values = concat([1], [2])`.
2. Voer `ruby .tools/lint.rb manifests/lint_probe.pp` uit. Dit moet slagen.
3. Vervang de inhoud door `$values = [1] + [2]` en voer hetzelfde commando opnieuw uit. Je moet nu een foutcode krijgen en `project_arrays` bij je eigen bestand zien.
4. Verwijder het tijdelijke bestand. Bewaar opzettelijk ongeldige testbestanden alleen buiten de mappen die je op stijl controleert.

De tests van de gedeelde linter voeren de `.puppet-lint.rc` en het script uit deze handleiding ook uit in een apart voorbeeldproject. Ze controleren onder meer het laden van de centrale configuratie, een genest pad met spaties, het overslaan van persoonlijke lintinstellingen en geldige en ongeldige mounts in Puppet-bestandsbronnen.
