# Puppet-code, lintcontroles en hergebruik

<a id="puppet-lint-en-rubocop"></a>
<a id="doel-en-reikwijdte"></a>

Deze handleiding beschrijft hoe je Puppet-code voor de repository `puppet-modules` controleert. Je vindt hier de dagelijkse werkwijze, de lintcommando's en verwijzingen naar de [algemene Puppet-coderegels](docs/CODE_RULES.md), [regels voor Puppet-documentatie](docs/DOCUMENTATION_RULES.md) en [operationele regels](docs/OPERATIONAL_RULES.md). Ook lees je hoe je die controles in een ander Puppet-project gebruikt en hoe je ze onderhoudt.

**Puppet-lint** is een extern controleprogramma dat Puppet-broncode leest en afwijkingen van codeafspraken meldt. Zo'n programma heet een linter; iedere afzonderlijke controle heet een check. Je start het met het commando `puppet-lint`. Het programma heeft standaardchecks en kan extra checks uit uitbreidingen laden.

Voor deze repository zijn zulke uitbreidingen en de bijbehorende configuratie verzameld in **`lint-project`**, ons eigen Ruby-pakket, ook wel een gem genoemd. Dit pakket gebruikt Puppet-lint als controleprogramma en voegt de `project_*`-checks toe voor onder meer parameters, documentatie, bestandsrechten en shellcommando's. Daarnaast installeert het twee externe lintplugins. Je blijft de controles starten met `puppet-lint`; de projectconfiguratie laadt onze uitbreiding en bepaalt samen met het gedeelde regelprofiel welke checks en opties actief zijn.

`lint-project` brengt ook de aanvullende validatie bij elkaar. Het installeert [RuboCop](#ruby-code-controleren) voor de eigen Ruby-code, waaronder de projectchecks en tooltests, en levert een gedeeld RuboCop-profiel mee. Voor [Puppet-parservalidatie](#puppet-manifests-valideren) installeert het de native parser en levert het `puppet-validate-junit`, dat per manifest de syntax controleert en een JUnit XML-testrapport maakt. Puppet-lint, RuboCop en parservalidatie hebben ieder hun eigen commando. De [tooltests](#tests-uitvoeren-en-uitbreiden) controleren de werking van de checks, automatische correcties en installatie vanuit andere projecten.

De lintdocumentatie bestaat uit vier centrale documenten: deze toolinghandleiding en de drie regelsbestanden [CODE_RULES.md](docs/CODE_RULES.md), [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) en [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). Iedere bron heeft een eigen verantwoordelijkheid:

| Bron | Verantwoordelijkheid |
| --- | --- |
| [`AGENTS.md`](../../AGENTS.md) | Repositorybrede workflow, engineering, security en documentatiebeheer; geen tweede verzameling Puppet-normen. |
| Deze [README](#inhoudsopgave) | Gebruik, installatie, configuratie, checks, CLI, CI, imports en onderhoud van de linttooling. |
| [`docs/CODE_RULES.md`](docs/CODE_RULES.md) | Algemene Puppet-coderegels, uitzonderingen en handmatige reviewcriteria voor iedere Puppet-wijziging. |
| [`docs/DOCUMENTATION_RULES.md`](docs/DOCUMENTATION_RULES.md) | Commentaar in Puppet-code, Puppet Strings en documentatie van Puppet-interfaces, met uitzonderingen en handmatige reviewcriteria. Algemene Markdown- en README-afspraken blijven in `AGENTS.md`. |
| [`docs/OPERATIONAL_RULES.md`](docs/OPERATIONAL_RULES.md) | Aanvullende Puppet-regels voor beheerde bestanden, rechten, beveiliging, systemd, shell en monitoring. |
| [`.puppet-lint.rc`](../../.puppet-lint.rc) en [gedeelde configuratie](config/) | Actieve lintconfiguratie. |
| [Projectchecks](lib/project_lint/checks/) | Feitelijk detectie- en autofixgedrag. |
| [Tooltests](tests/) | Automatisch geverifieerde scenario's en regressies; uitsluitend bewijs voor de uitgevoerde scenario's. |

De drie regelsbestanden vormen de centrale code- en implementatiestandaard, ook voor regels zonder automatische check. [AGENTS.md](../../AGENTS.md#authority-and-rule-placement) bepaalt de plaatsing van nieuwe afspraken.

Een groene lintscan bewijst geen volledige normnaleving, geldige catalogus of correct runtimegedrag. Bij ontbrekende automatische dekking blijft de norm gelden en is handmatige review vereist. Bij strijdigheid beschrijf je norm en waargenomen gedrag afzonderlijk en registreer je het conflict in de oplevering; pas de norm of implementatie niet aan als redactionele oplossing. Corrigeer een feitelijk onjuiste CLI-beschrijving alleen met uitvoerbewijs. Behoud onduidelijke normen letterlijk en markeer de precieze onzekerheid. Een niet-uitgevoerde verplichte controle of onopgelost normconflict verhindert de eindstatus `Afgerond`.

## Leeswijzer

Gebruik je de tooling voor het eerst, begin dan bij de snelstart voor [deze repository](#snelstart-in-deze-repository) of [je eigen Puppet-project](#snelstart-in-een-ander-puppet-project). Voor een wijziging volg je de [dagelijkse werkwijze](#werkwijze-bij-een-wijziging). De onderwerpentabel verwijst naar de secties die je wijziging raakt; de vijf taakroutes eronder verbinden die naslag met de benodigde stappen. Je hoeft de overige gespecialiseerde naslag niet vooraf door te nemen. Komt tijdens je werk een nieuwe afhankelijkheid of integratie in beeld, neem dan de bijbehorende sectie erbij.

Volg bij iedere Puppet-wijziging de toepasselijke algemene regels uit [CODE_RULES.md](docs/CODE_RULES.md). Raakt de wijziging commentaar, Puppet Strings of documentatie van Puppet-interfaces, lees en volg dan daarnaast de relevante regels uit [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md).

Raakt de wijziging beheerde bestanden of mappen, eigenaarschap of rechten, beveiliging, systemd of services, shellcode of shelltemplates, runtime-tools of operationele dependencies, of monitoringchecks en hun registratie, volg dan ook de relevante regels uit [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). Beide aanvullende documenten kunnen tegelijk van toepassing zijn. Ze vervangen de algemene coderegels nooit.

Gebruik deze beslisstructuur om de toepasselijke documenten te kiezen. De onderwerpentabel eronder verwijst naar de relevante secties binnen die documenten.

| Je wijziging | Toepasselijke regelsbestanden |
| --- | --- |
| Algemene Puppet-code, zoals een parameterwijziging | [CODE_RULES.md](docs/CODE_RULES.md). |
| Commentaar, Puppet Strings of Puppet-interface-documentatie, zoals gewijzigde Strings bij een class | [CODE_RULES.md](docs/CODE_RULES.md) + [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md). |
| Bestanden, beveiliging, systemd, shell of monitoring, zoals een nieuwe systemd-service | [CODE_RULES.md](docs/CODE_RULES.md) + [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). |
| Operationele Puppet-code met gewijzigde documentatie, zoals een monitoring-define met Puppet Strings | [CODE_RULES.md](docs/CODE_RULES.md) + [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) + [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). |

| Je taak | Lees hierbij |
| --- | --- |
| Een normaal Puppet-manifest aanpassen | [Basisopmaak](docs/CODE_RULES.md#basisopmaak) en [parameters en resources](docs/CODE_RULES.md#parameters-en-resources). |
| Verantwoordelijkheden tussen caller, component en template wijzigen | [Instellingen bij hun eigenaar houden](docs/CODE_RULES.md#instellingen-bij-hun-eigenaar-houden); controleer de gegevensstroom en het gedrag met de [aanvullende validatie](#aanvullende-validatie). |
| Commentaar of Puppet-interface-documentatie aanpassen | [Commentaar en documentatie](docs/DOCUMENTATION_RULES.md#commentaar-en-documentatie), waaronder [toelichtingen bij code](docs/DOCUMENTATION_RULES.md#toelichtingen-bij-code) en [interfacebeschrijvingen synchroniseren](docs/DOCUMENTATION_RULES.md#interfacebeschrijvingen-synchroniseren). |
| Puppet Strings aanpassen | [Puppet Strings](docs/DOCUMENTATION_RULES.md#puppet-strings), [lange regels](docs/CODE_RULES.md#lange-regels) en [waar de uitleg hoort](docs/DOCUMENTATION_RULES.md#waar-de-uitleg-hoort). |
| Resources of dependencies aanpassen | [Packageafhankelijkheden bij externe commando’s](docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos), [Resources en afhankelijkheden](docs/CODE_RULES.md#resources-en-afhankelijkheden), [resource references](docs/CODE_RULES.md#resource-references) en [volgorde en meldingen](docs/CODE_RULES.md#volgorde-en-meldingen). |
| Bestanden, privileges of shellcommando's aanpassen | [Bestanden en beveiliging](docs/OPERATIONAL_RULES.md#bestanden-en-beveiliging), inclusief [beheerheaders](docs/OPERATIONAL_RULES.md#door-puppet-beheerde-inhoud-markeren) en [helperlocaties](docs/OPERATIONAL_RULES.md#beheerhelpers-op-de-gedeelde-locatie-installeren); voer de [algemene beveiligingsreview](../../AGENTS.md#security-and-privacy) uit. |
| Een shellscript, Bash-script, shelltemplate of bijbehorende runtime-dependency aanpassen | [Shellscripts](docs/OPERATIONAL_RULES.md#shellscripts), inclusief [runtime-tools](docs/OPERATIONAL_RULES.md#runtime-tools-op-hun-functie-beoordelen); voer de [projectbrede shellreview en validatie](../../AGENTS.md#shell-scripts) uit. |
| Een monitoringcheck of registratie aanpassen | [Monitoringchecks](docs/OPERATIONAL_RULES.md#monitoringchecks) en [targets en monitoring](docs/OPERATIONAL_RULES.md#targets-en-monitoring); voer de [projectbrede monitoringreview en validatie](../../AGENTS.md#monitoring-checks) uit. |
| Systemd-integratie aanpassen | [Gedeelde services en systemd](docs/OPERATIONAL_RULES.md#gedeelde-services-en-systemd), inclusief de beoordeling per service. |
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
  - [Automatische dekking en handmatige review](#automatische-dekking-en-handmatige-review)
- [Puppet-coderegels en reviewcriteria](#puppet-coderegels-en-reviewcriteria)
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

Gebruik de nieuwste stabiele Ruby en Bundler. Pin hun versies niet in setupcommando’s of runtimeconfiguratie. Richt op macOS eerst Ruby in met de onderstaande stappen. Heb je de nieuwste stabiele Ruby al actief, ga dan door met [de gems installeren](#gems-installeren).

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
| Gedeclareerde runtime | `lint-project 0.1.12`, Ruby `>= 3.2`; builder `~> 3.3`, OpenVox `~> 8.29`, Puppet-lint `~> 5.1`, beide lintplugins `~> 3.0`, RuboCop `~> 1.91`, syslog `~> 0.4` | Dit zijn packagegrenzen, geen testmatrix. |
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

Houd de modules die nodig zijn voor interfacecontrole beschikbaar, ook als hun code buiten de stijlscan valt. Voeg geen regeluitsluitingen toe om echte fouten te verbergen; de toegestane lokale suppressions staan bij de betreffende [codeafspraken](docs/CODE_RULES.md#naslag).

De projectconfiguratie gebruikt alle standaard ingeschakelde checks en schakelt daarnaast `class_inherits_from_params_class` in. Ook nieuwe standaardchecks komen bij een update beschikbaar. De optionele checks voor 80 tekens, booleans tussen aanhalingstekens en code op hoofdniveau staan uit: dit project volgt de [regelgrens van 140 tekens](docs/CODE_RULES.md#lange-regels) en ondersteunt daemonstrings zoals `'true'` en uitvoerbare profielen. Bestaande stijlachterstand is geen reden om een check uit te schakelen of een module uit te zonderen.

### Aanroepen van modules controleren

`PROJECT_LINT_MODULEPATH` bevat de bestaande, absolute modulemappen in dezelfde volgorde als Puppet gebruikt. Op macOS en Linux is de scheiding `:`; spaties zijn toegestaan, een `:` in een mapnaam niet. Een lege, relatieve of ontbrekende map geeft een fout. Zonder deze variabele zoekt de linter vanaf de huidige werkmap als moduleverzameling en slaat hij de vendored namen `concat`, `debconf`, `reboot`, `stdlib` en `timezone` over. Stel de variabele in externe projecten expliciet in.

De resolver gebruikt eerst declaraties uit de actuele lintinvoer. Daarna kiest hij de eerste modulemap met de gevraagde modulenaam en zoekt daar `example/manifests/init.pp` voor `example`, of `example/manifests/item.pp` voor `example::item`. Ontbreekt dat manifest, dan zoekt hij niet verder in een latere kopie van de module. Bestanden achter symlinks buiten de ingestelde modulemap worden niet gelezen.

Controleer environments met verschillende modulepaden apart. Eén samengevoegde lijst kan een andere moduleversie kiezen dan Puppet op de server. De linter leest geen `environment.conf`.

> [!CAUTION]
> Een niet-vindbare declaratie kan geen melding over ontbrekende parameters opleveren. Een geslaagde scan bewijst daarom niet dat Puppet de catalogus kan compileren. Controleer aanroepen ook met de eigen catalogusvalidatie.

Bij vindbare declaraties controleert `project_interface_calls` verplichte parameters, inclusief `Optional[...]` zonder default. Argumenttypen, onbekende parameters, functies, dynamische classnamen, `include`/`contain`, Hiera, overerving en splats worden daarmee niet volledig gevalideerd.

`project_parameter_passthrough` gebruikt dezelfde vindbare defined types om per gefilterde key de bronwaarde of brondefault met de ontvangende parameterdefault te vergelijken. De bron wordt in de actuele lintinvoer opgezocht. Een onbekende bron, ontvanger of default geeft geen filtermelding; de [regel voor parameterdoorgifte](docs/CODE_RULES.md#aanroepen-en-publieke-interfaces) beschrijft de verdere grenzen en reviewcriteria.

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

Een waarschuwing laat de scan mislukken. Herstel de oorzaak volgens de codeafspraak. De toegestane uitzonderingen zijn beperkt tot [lange regels](docs/CODE_RULES.md#lange-regels) en de beschreven [Puppet-fileserverbronnen](docs/OPERATIONAL_RULES.md#templates-en-bestandsbronnen); andere checks uitschakelen of alleen een gunstige selectie draaien levert geen volledige controle op.

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
| `project_parameter_order` | Ja | Ja | [Parameters met defaultafhankelijkheden sorteren](docs/CODE_RULES.md#parameters-met-defaultafhankelijkheden-sorteren) | Geen | [Parameters met defaultafhankelijkheden sorteren](docs/CODE_RULES.md#parameters-met-defaultafhankelijkheden-sorteren) |
| `project_parameter_alignment` | Ja | Ja | [Parameterblokken volledig uitlijnen](docs/CODE_RULES.md#parameterblokken-volledig-uitlijnen) | Per meldingsvariant: [Parameterblokken volledig uitlijnen](docs/CODE_RULES.md#parameterblokken-volledig-uitlijnen) | [Parameterblokken volledig uitlijnen](docs/CODE_RULES.md#parameterblokken-volledig-uitlijnen) |
| `project_documentation` | Ja | Ja | [Publieke declaraties bij de code documenteren](docs/DOCUMENTATION_RULES.md#publieke-declaraties-bij-de-code-documenteren), [Strings API-markering](docs/DOCUMENTATION_RULES.md#strings-api-markering), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Strings-parametercontract](docs/DOCUMENTATION_RULES.md#strings-parametercontract), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden) | Geen | [Publieke declaraties bij de code documenteren](docs/DOCUMENTATION_RULES.md#publieke-declaraties-bij-de-code-documenteren), [Strings API-markering](docs/DOCUMENTATION_RULES.md#strings-api-markering), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Strings-parametercontract](docs/DOCUMENTATION_RULES.md#strings-parametercontract), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden) |
| `project_documentation_layout` | Ja | Ja | [Lange regels](docs/CODE_RULES.md#lange-regels), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden), [Strings-regelbreedte](docs/DOCUMENTATION_RULES.md#strings-regelbreedte), [Strings-taginspringing](docs/DOCUMENTATION_RULES.md#strings-taginspringing), [Strings-secties met commentregels scheiden](docs/DOCUMENTATION_RULES.md#strings-secties-met-commentregels-scheiden), [Lengtesuppressions in Strings begrenzen](docs/DOCUMENTATION_RULES.md#lengtesuppressions-in-strings-begrenzen) | Per meldingsvariant: [Lange regels](docs/CODE_RULES.md#lange-regels), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden), [Strings-regelbreedte](docs/DOCUMENTATION_RULES.md#strings-regelbreedte), [Strings-taginspringing](docs/DOCUMENTATION_RULES.md#strings-taginspringing), [Strings-secties met commentregels scheiden](docs/DOCUMENTATION_RULES.md#strings-secties-met-commentregels-scheiden), [Lengtesuppressions in Strings begrenzen](docs/DOCUMENTATION_RULES.md#lengtesuppressions-in-strings-begrenzen) | [Lange regels](docs/CODE_RULES.md#lange-regels), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden), [Strings-regelbreedte](docs/DOCUMENTATION_RULES.md#strings-regelbreedte), [Strings-taginspringing](docs/DOCUMENTATION_RULES.md#strings-taginspringing), [Strings-secties met commentregels scheiden](docs/DOCUMENTATION_RULES.md#strings-secties-met-commentregels-scheiden), [Lengtesuppressions in Strings begrenzen](docs/DOCUMENTATION_RULES.md#lengtesuppressions-in-strings-begrenzen) |
| `project_layout` | Ja | Ja | [Inspringing](docs/CODE_RULES.md#inspringing), [Spatie na komma’s](docs/CODE_RULES.md#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](docs/CODE_RULES.md#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](docs/CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) | Per meldingsvariant: [Inspringing](docs/CODE_RULES.md#inspringing), [Spatie na komma’s](docs/CODE_RULES.md#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](docs/CODE_RULES.md#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](docs/CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) | [Inspringing](docs/CODE_RULES.md#inspringing), [Spatie na komma’s](docs/CODE_RULES.md#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](docs/CODE_RULES.md#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](docs/CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) |
| `project_comment_spacing` | Ja | Ja | [Toelichtingsblokken van eerdere code scheiden](docs/DOCUMENTATION_RULES.md#toelichtingsblokken-van-eerdere-code-scheiden) | Per meldingsvariant: [Toelichtingsblokken van eerdere code scheiden](docs/DOCUMENTATION_RULES.md#toelichtingsblokken-van-eerdere-code-scheiden) | [Toelichtingsblokken van eerdere code scheiden](docs/DOCUMENTATION_RULES.md#toelichtingsblokken-van-eerdere-code-scheiden) |
| `project_resource_sections` | Ja | Ja | [Een resource na een afgesloten blok toelichten](docs/DOCUMENTATION_RULES.md#een-resource-na-een-afgesloten-blok-toelichten) | Geen | [Een resource na een afgesloten blok toelichten](docs/DOCUMENTATION_RULES.md#een-resource-na-een-afgesloten-blok-toelichten) |
| `project_resource_references` | Ja | Ja | [References van hetzelfde type samenvoegen](docs/CODE_RULES.md#references-van-hetzelfde-type-samenvoegen), [Titels in resource references sorteren](docs/CODE_RULES.md#titels-in-resource-references-sorteren), [Een overbodige buitenste dependency-array verwijderen](docs/CODE_RULES.md#een-overbodige-buitenste-dependency-array-verwijderen) | Per meldingsvariant: [References van hetzelfde type samenvoegen](docs/CODE_RULES.md#references-van-hetzelfde-type-samenvoegen), [Titels in resource references sorteren](docs/CODE_RULES.md#titels-in-resource-references-sorteren), [Een overbodige buitenste dependency-array verwijderen](docs/CODE_RULES.md#een-overbodige-buitenste-dependency-array-verwijderen) | [References van hetzelfde type samenvoegen](docs/CODE_RULES.md#references-van-hetzelfde-type-samenvoegen), [Titels in resource references sorteren](docs/CODE_RULES.md#titels-in-resource-references-sorteren), [Een overbodige buitenste dependency-array verwijderen](docs/CODE_RULES.md#een-overbodige-buitenste-dependency-array-verwijderen) |
| `project_if_sections` | Ja | Ja | [Voorwaarden toelichten](docs/DOCUMENTATION_RULES.md#voorwaarden-toelichten) | Geen | [Voorwaarden toelichten](docs/DOCUMENTATION_RULES.md#voorwaarden-toelichten) |
| `project_variable_sections` | Ja | Ja | [Een variabelegroep bij blokbegin toelichten](docs/DOCUMENTATION_RULES.md#een-variabelegroep-bij-blokbegin-toelichten), [Een onafhankelijke groep na afhankelijke waarden beginnen](docs/DOCUMENTATION_RULES.md#een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen) | Geen | [Een variabelegroep bij blokbegin toelichten](docs/DOCUMENTATION_RULES.md#een-variabelegroep-bij-blokbegin-toelichten), [Een onafhankelijke groep na afhankelijke waarden beginnen](docs/DOCUMENTATION_RULES.md#een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen) |
| `project_class_check_reuse` | Ja | Ja | [Classcontroles hergebruiken](docs/CODE_RULES.md#classcontroles-hergebruiken) | Geen | [Classcontroles hergebruiken](docs/CODE_RULES.md#classcontroles-hergebruiken) |
| `project_exec_packages` | Ja | Ja | [Packageafhankelijkheden bij externe commando’s](docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos) | Geen | [Packageafhankelijkheden bij externe commando’s](docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos) |
| `project_packages` | Ja | Ja | [APT-opties expliciet afsluiten](docs/OPERATIONAL_RULES.md#apt-opties-expliciet-afsluiten) | Geen | [APT-opties expliciet afsluiten](docs/OPERATIONAL_RULES.md#apt-opties-expliciet-afsluiten) |
| `project_guarded_packages` | Ja | Ja | [Gelijk ingestelde packageguards samenvoegen](docs/OPERATIONAL_RULES.md#gelijk-ingestelde-packageguards-samenvoegen) | Per meldingsvariant: [Gelijk ingestelde packageguards samenvoegen](docs/OPERATIONAL_RULES.md#gelijk-ingestelde-packageguards-samenvoegen) | [Gelijk ingestelde packageguards samenvoegen](docs/OPERATIONAL_RULES.md#gelijk-ingestelde-packageguards-samenvoegen) |
| `project_resource_list_reuse` | Ja | Ja | [Resourcelijsten hergebruiken](docs/CODE_RULES.md#resourcelijsten-hergebruiken) | Per meldingsvariant: [Resourcelijsten hergebruiken](docs/CODE_RULES.md#resourcelijsten-hergebruiken) | [Resourcelijsten hergebruiken](docs/CODE_RULES.md#resourcelijsten-hergebruiken) |
| `project_resource_dependencies` | Ja | Ja | [Resource-dependencies opbouwen](docs/CODE_RULES.md#resource-dependencies-opbouwen) | Per meldingsvariant: [Resource-dependencies opbouwen](docs/CODE_RULES.md#resource-dependencies-opbouwen) | [Resource-dependencies opbouwen](docs/CODE_RULES.md#resource-dependencies-opbouwen) |
| `project_files` | Ja | Ja | [Optionele resource-attributen vooraf bepalen](docs/CODE_RULES.md#optionele-resource-attributen-vooraf-bepalen), [Eigenaars en rechten](docs/OPERATIONAL_RULES.md#eigenaars-en-rechten) | Geen | [Optionele resource-attributen vooraf bepalen](docs/CODE_RULES.md#optionele-resource-attributen-vooraf-bepalen), [Eigenaars en rechten](docs/OPERATIONAL_RULES.md#eigenaars-en-rechten) |
| `project_puppet_urls` | Ja | Ja | [Puppet-fileservermounts expliciet kiezen](docs/OPERATIONAL_RULES.md#puppet-fileservermounts-expliciet-kiezen) | Geen | [Puppet-fileservermounts expliciet kiezen](docs/OPERATIONAL_RULES.md#puppet-fileservermounts-expliciet-kiezen) |
| `project_arrays` | Ja | Ja | [Arrays met concat combineren](docs/CODE_RULES.md#arrays-met-concat-combineren) | Geen | [Arrays met concat combineren](docs/CODE_RULES.md#arrays-met-concat-combineren) |
| `project_templates` | Ja | Ja | [Gegenereerde configuratie met ERB renderen](docs/OPERATIONAL_RULES.md#gegenereerde-configuratie-met-erb-renderen) | Geen | [Gegenereerde configuratie met ERB renderen](docs/OPERATIONAL_RULES.md#gegenereerde-configuratie-met-erb-renderen) |
| `project_shared_conditions` | Ja | Ja | [Gedeelde voorwaarden om resources groeperen](docs/CODE_RULES.md#gedeelde-voorwaarden-om-resources-groeperen) | Geen | [Gedeelde voorwaarden om resources groeperen](docs/CODE_RULES.md#gedeelde-voorwaarden-om-resources-groeperen) |
| `project_positive_flow` | Ja | Ja | [De grootste verwerking vóór de korte afhandeling plaatsen](docs/CODE_RULES.md#de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen), [Validatie om haar afhankelijke implementatie plaatsen](docs/CODE_RULES.md#validatie-om-haar-afhankelijke-implementatie-plaatsen) | Geen | [De grootste verwerking vóór de korte afhandeling plaatsen](docs/CODE_RULES.md#de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen), [Validatie om haar afhankelijke implementatie plaatsen](docs/CODE_RULES.md#validatie-om-haar-afhankelijke-implementatie-plaatsen) |
| `project_shell` | Ja | Ja | [Shellcommando's in Puppet](docs/OPERATIONAL_RULES.md#shellcommandos-in-puppet) | Geen | [Shellcommando's in Puppet](docs/OPERATIONAL_RULES.md#shellcommandos-in-puppet) |
| `project_interface_calls` | Ja | Ja | [Alle verplichte argumenten doorgeven](docs/CODE_RULES.md#alle-verplichte-argumenten-doorgeven) | Geen | [Alle verplichte argumenten doorgeven](docs/CODE_RULES.md#alle-verplichte-argumenten-doorgeven) |
| `project_parameter_passthrough` | Ja | Ja | [Overbodige parameterdoorgifte rechtstreeks schrijven](docs/CODE_RULES.md#overbodige-parameterdoorgifte-rechtstreeks-schrijven) | Geen | [Overbodige parameterdoorgifte rechtstreeks schrijven](docs/CODE_RULES.md#overbodige-parameterdoorgifte-rechtstreeks-schrijven) |
| `project_monitoring_backend` | Ja | Ja | [Targets en monitoring](docs/OPERATIONAL_RULES.md#targets-en-monitoring) | Geen | [Targets en monitoring](docs/OPERATIONAL_RULES.md#targets-en-monitoring) |
| `project_suppressions` | Ja | Ja | [Alleen toegestane suppressions gebruiken](docs/CODE_RULES.md#alleen-toegestane-suppressions-gebruiken) | Geen | [Alleen toegestane suppressions gebruiken](docs/CODE_RULES.md#alleen-toegestane-suppressions-gebruiken) |
<!-- END PROJECT CHECK REGISTRY -->

De registratie is vastgesteld via `require 'project_lint'`; activatie is afzonderlijk gecontroleerd met beide configuratieprofielen. `--list-checks` bewijst alleen beschikbaarheid. De inventaris gebruikt `lint-project 0.1.12`, `puppet-lint 5.1.1`, `puppet-lint-param-types 3.0.0` en `puppet-lint-trailing_comma-check 3.0.1` uit de rootlockfile. Nieuwe bundleversies vragen een nieuwe inventaris.

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

De checks voor opmaak bewijzen niet dat commentaar inhoudelijk klopt. Voor systemd-hardening, transportbeveiliging, shellgedrag, monitoringdefaults, uitvoertijd en gedeelde checkexecutables bestaat hier geen volledige automatische lintcontrole. De inhoudelijke criteria staan in de gekoppelde regels; de [projectbrede validatieverplichtingen](../../AGENTS.md#validation-and-testing) blijven daarnaast gelden.

### Automatische dekking en handmatige review

Bepaal de dekking per norm en per meldingsvariant aan de hand van haar velden `Automatische controle`, `Detectiegrenzen`, `Autofix` en `Verificatie`. Detectie en correctie zijn afzonderlijke eigenschappen:

| Status | Betekenis voor de beoordeling |
| --- | --- |
| Volledig geautomatiseerd binnen het beschreven bereik | De check detecteert de beschreven gevallen; controleer de grenzen en het uitgevoerde bewijs voordat je volledige dekking claimt. |
| Gedeeltelijk geautomatiseerd | Een check beoordeelt slechts een deel van de norm; de overige gevallen vragen handmatige review. |
| Alleen detectie | Een melding is beschikbaar, maar er is geen veilige automatische correctie voor deze variant. |
| Autofix beschikbaar | Alleen de gedocumenteerde varianten en voorwaarden mogen automatisch worden gecorrigeerd; hercontrole blijft nodig. |
| Geen automatische controle | De norm vereist handmatige review en waar toepasselijk afzonderlijke functionele validatie. |

Het ontbreken van een check, gedeeltelijke detectie of het ontbreken van veilige autofix verandert de eigenaar of verplichting van de norm niet. Zo controleren `project_files` en `project_shell` bepaalde Puppet-attributen en escaping, maar geen beheerheaders, algemene shellstijl of gedeelde executablelevenscyclus. De regels vermelden die beperkingen bij het betreffende contract. Signaleer een betrouwbare mogelijkheid voor detectie of veilige correctie als lintverbetering; een documentatieverplaatsing geeft geen opdracht om die verbetering te implementeren.

## Puppet-coderegels en reviewcriteria

De volledige Puppet-coderegels en reviewcriteria staan in [CODE_RULES.md](docs/CODE_RULES.md), [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) en [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). De drie bestanden beschrijven per regel de norm, detectiegrenzen, autofixvoorwaarden, uitzonderingen, voorbeelden en handmatige review. Iedere regel heeft één autoritatieve locatie.

Volg bij iedere Puppet-wijziging de toepasselijke algemene regels:

- [Basisopmaak](docs/CODE_RULES.md#basisopmaak), inclusief inspringing, komma's en lange regels.
- [Parameters en resources](docs/CODE_RULES.md#parameters-en-resources).

Raakt de wijziging commentaar, Puppet Strings of documentatie van Puppet-interfaces, volg dan daarnaast de regels voor [Commentaar en documentatie](docs/DOCUMENTATION_RULES.md#commentaar-en-documentatie), inclusief [Puppet Strings](docs/DOCUMENTATION_RULES.md#puppet-strings).

Raakt de wijziging operationele onderdelen, volg dan daarnaast de relevante regels uit deze groepen:

- [Bestanden en beveiliging](docs/OPERATIONAL_RULES.md#bestanden-en-beveiliging).
- [Gedeelde services en systemd](docs/OPERATIONAL_RULES.md#gedeelde-services-en-systemd).
- [Shellscripts](docs/OPERATIONAL_RULES.md#shellscripts).
- [Monitoringchecks](docs/OPERATIONAL_RULES.md#monitoringchecks).

Bij een wijziging aan zowel operationele code als de documentatie daarvan gelden beide aanvullende documenten, zoals uitgewerkt in de [leeswijzer](#leeswijzer). Voor een concrete lintmelding vind je de bijbehorende regel via het [checkregister](#checkregister). De algemene werkwijze voor automatische correcties en suppressions volgt hieronder.

## Autofix en suppressions

Een autofix corrigeert een vastgestelde afwijking; een suppression onderdrukt een melding. Beoordeel eerst de norm en de correctievoorwaarden bij de betrokken regel. De [suppressieregel](docs/CODE_RULES.md#alleen-toegestane-suppressions-gebruiken) beschrijft welke markeringen zijn toegestaan en hoe je ze begrenst. Hieronder staat hoe je een toegestane automatische correctie uitvoert en controleert.

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

Zonder `--only-checks` worden de beschikbare fixes van zowel standaardchecks als projectchecks gebruikt. Een check kan een melding laten staan wanneer de code niet veilig te herschrijven is. De concrete grenzen staan bij [inspringing](docs/CODE_RULES.md#inspringing), [komma's](docs/CODE_RULES.md#kommas), [parameteruitlijning](docs/CODE_RULES.md#parameters-en-instellingen), [commentaarscheiding](docs/DOCUMENTATION_RULES.md#toelichtingen-bij-code), [resource references](docs/CODE_RULES.md#resource-references), [packagegroepen](docs/OPERATIONAL_RULES.md#pakketten-en-mappen) en [Puppet Strings](docs/DOCUMENTATION_RULES.md#puppet-strings).

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

Puppet-voorbeelden in Strings en Markdown worden niet door de gewone lintscan gevonden. Werk ze tijdelijk buiten de repository uit tot uitvoerbare invoer en controleer die met de projectlintregels en de parser. Render gewijzigde templates voordat je het resulterende formaat tegen de [operationele bestands- en shellregels](docs/OPERATIONAL_RULES.md) beoordeelt.

Bij gedragswijzigingen onderzoek je wat er op de host verandert: welke bestanden worden geschreven, welke services herstarten en welke rechten of verbindingen daarvoor nodig zijn. Controleer normaal gebruik en een praktisch foutgeval met synthetische invoer. Neem bij een gedeelde bouwsteen alle geraakte gebruikers mee. Voor monitoring gelden de [bijbehorende scenario's](../../AGENTS.md#monitoring-validation); voor dependencies de [prerequisitereview](docs/CODE_RULES.md#resources-en-afhankelijkheden).

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

Onderhoud parservalidatie, Puppet-linting, Ruby-linting en tooltests als onafhankelijke CI-jobs. Genereer alle gepubliceerde validatie-, lint- en testrapporten tijdens de betreffende uitvoering als JUnit XML. Publiceer iedere soort als afzonderlijk artifact na succes of een gewone controlefout en behoud de oorspronkelijke exitstatus. Bewaar gegenereerde rapporten in een genegeerde results-map onder `.tools/` en documenteer commando’s en locaties hier. Sluit het geslaagde validatiepad van iedere job af met `git diff --exit-code HEAD --`; de [projectworkflow](../../AGENTS.md#ci-jobs-and-reports) verbiedt herstel om die controle te laten slagen.

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
│       ├── tests/
│       │   ├── <behavior>_test.rb
│       │   ├── test_helper.rb       # Alleen voor werkelijk gedeelde testhulp.
│       │   └── fixtures/            # Alleen voor benodigde synthetische invoer.
│       └── README.md
├── global-modules/                  # Deze repository als Git-submodule.
│   └── .tools/lint/
│       ├── README.md
│       ├── docs/
│       │   ├── CODE_RULES.md
│       │   ├── DOCUMENTATION_RULES.md
│       │   └── OPERATIONAL_RULES.md
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
| `.tools/<tool-name>/tests/` | Houd gedragstests, helpers en fixtures bij de tool die ze controleren. De [testindeling en uitvoering](#eigen-tooltests) beschrijven ook bestaande testmappen. |
| `Rakefile` | Houd eigen taken in de projectroot. Ontdek tooltests recursief onder `.tools/**/tests/**/*_test.rb` en voeg alleen bestaande tools toe als `test:<tool-name>`. |

Houd eigen taken voor deze controles beperkt tot de projectspecifieke selectie en het aanroepen van de [gedeelde tooling](#gedeelde-tooling-hergebruiken). Verbeteringen aan de checks, validators en rapportcommando's die voor alle afnemers gelden, horen in de gedeelde gem.

Leg de gekozen eigen toolingindeling en rapportmap vast in de eigen `AGENTS.md` en README. Verwijs voor gedeelde tooling naar deze handleiding onder `global-modules/.tools/lint/README.md` en voor de algemene lintregels en reviewcriteria naar `global-modules/.tools/lint/docs/CODE_RULES.md`. Verwijs voor commentaar, Puppet Strings en interface-documentatie aanvullend naar `global-modules/.tools/lint/docs/DOCUMENTATION_RULES.md` en voor operationele wijzigingen naar `global-modules/.tools/lint/docs/OPERATIONAL_RULES.md`. Beide aanvullende regelsbestanden kunnen tegelijk van toepassing zijn. Zo wordt iedere uitleg op haar eigen plek onderhouden. De `AGENTS.md` in de submodule beschrijft het werk aan die repository; afnemers leggen de afspraken voor hun eigen project expliciet vast.

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

Gebruik bij deze installatieroute de volgende dependency in plaats van de `path:`-dependency. Deze compatibiliteitsconstraint laat versies vanaf 0.1.3 binnen 0.1 toe; zij is geen exacte versiepin. De eigen lockfile legt de gekozen versie vast. De [volledige pakketroute](#gebouwd-gempakket-installeren) gebruikt de daadwerkelijk gecontroleerde pakketversie 0.1.12:

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

Het pakket bevat alleen `lib/`, `bin/`, `config/`, `README.md`, `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md`, `docs/OPERATIONAL_RULES.md` en de licentie, inclusief `puppet-lint-junit`, `puppet-validate-junit` en hun XML-dependency. Tests, ontwikkelgems en Puppet-modules zijn geen onderdeel van de distributie. Publicatie naar RubyGems is niet nodig; je kunt het bestand via je eigen goedgekeurde distributieroute beschikbaar maken. Een ontvangend project installeert zijn eigen dependencies en bewaart zijn eigen lockfile.

Versie `0.1.12` levert de standaard actieve check `project_shared_conditions` voor [resources met een gedeelde voorwaarde](docs/CODE_RULES.md#gedeelde-voorwaarden-om-resources-groeperen). De melding wijst naar een bestaand blok waarmee een andere resourcegroep haar buitenste voorwaarde deelt. Samenvoegen vraagt review van aanvullende voorwaarden, `else`-afhandeling en evaluatievolgorde; deze check heeft daarom geen autofix.

De gem levert ook de standaard actieve check `project_exec_packages` voor [packageafhankelijkheden bij externe commando’s](docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos), zonder autofix. De gem bevat ook de standaard actieve checks `project_resource_list_reuse` voor [hergebruik van resourcelijsten](docs/CODE_RULES.md#resourcelijsten-hergebruiken) en `project_resource_dependencies` voor [de opbouw van dependencies](docs/CODE_RULES.md#resource-dependencies-opbouwen). De fixes behandelen exacte herhaling, duidelijke uitbreidingen en aantoonbaar overbodige wrappers in dependency-concats. Afnemende projecten kunnen daardoor nieuwe lintmeldingen krijgen. De beschikbare `project_guarded_packages`-fix voor [package-declaraties](docs/OPERATIONAL_RULES.md#pakketten-en-mappen) gebruikt `ensure_packages()` en laat conflicterende package-attributen als catalogusfout zichtbaar worden. Die gegenereerde Puppet-code vereist stdlib; de linter levert de module niet mee.

Behandel checknamen, meldingsniveaus, veilige fixresultaten, `PROJECT_LINT_MODULEPATH`, het entrypoint, de gedeelde configuratiepaden en de rapportcommando's als publieke interfaces. Versiebeheer interfacewijzigingen en valideer het gebouwde pakket vanuit een onafhankelijk project. Houd consumerinstallatie en CI-voorbeelden afgestemd op de [aanbevolen projectstructuur](#aanbevolen-projectstructuur); documenteer ondersteunde afwijkingen zonder implementatie of gedeelde profielen te dupliceren. Verhoog de gemversie bij een uitgave en beschrijf wijzigingen die afnemers raken. Wijzigingen aan actieve regels en profielen kunnen bestaande projecten laten falen; laat afnemers zo’n update bewust uitvoeren met Bundler en hun eigen CI. Werk een Git-afnemer bij naar een gecontroleerde revisie en een pakketafnemer naar een gecontroleerde gemversie.

### Git-dependency uit de monorepo

Deze route installeert alleen de gem uit een gekozen Git-revisie. Een eventuele Puppet-moduleverzameling blijft een afzonderlijke prerequisite. De consumerroot bevat `Gemfile`, `Gemfile.lock`, `.puppet-lint.rc`, `modules/` en `manifests/site.pp`; een lokale `global-modules/` is voor deze Ruby-installatie niet vereist. Bundler vindt de geneste gemspec met `glob: '.tools/lint/*.gemspec'`. Zonder die selectie is de monoreporoot geen gemdirectory.

**Werkmap:** Nieuwe lege consumerroot. **Shell:** POSIX shell. **Vereisten:** Git, nieuwste stabiele Ruby/Bundler en toegang tot de goedgekeurde Git-/gembron. **Invoer:** Synthetisch manifest hieronder; de gekozen bestaande revisie bevat gemversie 0.1.11. **Wijzigt bestanden:** Eigen Gemfile, lockfile, configuratie, manifest en geïnstalleerde gems. **Verwacht resultaat:** Bundler kiest de geneste gemspec; de volledige profielscan eindigt met 0.

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

De packagebron is een lokaal gebouwd `.gem`-bestand uit een gecontroleerde checkout. Deze procedure veronderstelt geen publieke publicatie of private registry. Het pakket bevat `lib/`, `bin/`, `config/`, `README.md`, `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md`, `docs/OPERATIONAL_RULES.md` en `LICENSE`; bronrepositorytests, Gemfile, Rakefile en Puppet-modules horen niet bij het pakket.

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

gem 'lint-project', '= 0.1.12', require: false
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

Voeg tooltests toe onder [`.tools/lint/tests/`](tests/) die geldig en ongeldig gebruik, grensgevallen en de grenzen van de analyse controleren. Gebruik de [testhandleiding](#tests-uitvoeren-en-uitbreiden) voor discovery en testscope. De tests gebruiken het echte library-entrypoint en de native configuratie. Wijzig je packaging, configuratie of de CLI-aanroep, test dan ook installatie, exitcodes, geladen regels en isolatie van persoonlijke opties vanuit een apart project.

Voer tijdens het werk `bundle exec rake test:lint` uit en sluit af met de [volledige eindcontroles](#werkwijze-bij-een-wijziging). Tests van linteroutput mogen de parser gebruiken om geldige correcties te bewijzen; algemene module-, script- en monitoringtests blijven buiten deze testsuite. Voor autofix gelden de aanvullende criteria onder [Veilige autofixes ontwikkelen](#veilige-autofixes-ontwikkelen).

### Technische werking van de checks

De interne gem maakt de runtime-afhankelijkheden, laadpaden en gedeelde profielen beschikbaar aan andere projecten zonder dat zij onze ontwikkelbundle hoeven te gebruiken. De gem volgt de [RubyGems-libraryconventies](https://guides.rubygems.org/make-your-own-gem/): een entrypoint, eigen code onder `ProjectLint` en runtime-afhankelijkheden in de [gemspec](lint-project.gemspec). Het root-Gemfile en Rakefile blijven verantwoordelijk voor de ontwikkeling van alle repositorytools. Houd ontwikkelafhankelijkheden en orkestratie daar; een tweede ontwikkelbundle binnen de gem is niet nodig. Gebruik lokaal en in CI dezelfde Bundler-, Rake- en native CLI-routes. De [Bundler-documentatie](https://bundler.io/guides/git.html) beschrijft hoe dezelfde gem vanuit een checkout of Git-bron kan worden gebruikt.

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
├── tests/                    # Gedragstests van deze gem.
├── README.md                # Gebruik en onderhoud van de tooling.
└── docs/
    ├── CODE_RULES.md          # Algemene Puppet-coderegels en reviewcriteria.
    ├── DOCUMENTATION_RULES.md # Puppet-codecommentaar, Strings en interface-documentatie.
    └── OPERATIONAL_RULES.md   # Aanvullende operationele Puppet-regels.
```

Puppet-lint blijft de lintengine. De checks gebruiken zijn tokens, `notify`, suppressions, `PuppetLint::NoFix`, `add_token` en `remove_token`. Geef deze native API’s voor registratie, configuratie, diagnostiek, suppressions en autofix voorrang op eigen infrastructuur. De native CLI bepaalt opties, bestandsselectie, detectie en correcties. Eenvoudige tokenchecks, zoals de controle van Puppet-URLs, hebben geen AST nodig.

[`PuppetJunit`](lib/project_lint/puppet_junit.rb) verwerkt uitsluitend de native JSON-uitvoer voor de [JUnit-rapportage](#lintrapporten-maken). Het uitvoerbare commando `puppet-lint-junit` komt uit dezelfde gem. De omzetter gebruikt `builder` voor XML-escaping, neemt alleen diagnostische velden op en wijzigt geen lintconfiguratie. De [reportertests](tests/puppet_junit_test.rb) controleren geldige en ongeldige invoer, unieke testcases en foutdetails; de [pakkettest](tests/external_junit_test.rb) controleert de volledige pipe vanuit een onafhankelijk geïnstalleerde gem.

[`PuppetValidate`](lib/project_lint/puppet_validate.rb) roept voor ieder aangeleverd manifest de native parser-CLI uit de actieve bundle aan. Hij voert geen eigen syntaxanalyse uit en gebruikt geen shell om bestandspaden door te geven. [`JunitReport`](lib/project_lint/junit_report.rb) levert de gedeelde XML-opbouw voor beide rapportcommando's. De [validatiereportertests](tests/puppet_validate_test.rb) controleren onder meer lege selecties, ontbrekende bestanden en padnamen; de [pakkettest](tests/external_validate_test.rb) verifieert succesvolle en mislukte parseruitvoering en rapportage vanuit een zelfstandig project. De selectie van repositorybestanden hoort bij `validate:puppet` in de root-Rakefile.

[`Ast`](lib/project_lint/ast.rb) voegt alleen de structurele informatie van de OpenVox-parser toe: declaraties, expressies, resources en hun omliggende scopes. De tokenindexen van Puppet-lint leveren die volledige structuur niet. Alle structurele checks delen één AST voor de huidige lintinvoer; een nieuwe scan vervangt die analyse, ook bij gelijke tekst in een ander bestand. De analyse voert geen Puppet-functies of catalogi uit. Alleen echte `Puppet::ParseError`-meldingen worden omgezet naar een syntaxfout; programmeerfouten blijven fouten. Een onbekende constructie krijgt waar nodig een reviewmelding.

Houd Ruby-helpers binnen `ProjectLint` met conventionele namespace-gebaseerde require-paden. Introduceer geen helperconstants op topniveau of veranderlijke configuratie die tijdens laden wordt vastgelegd.

Gedeelde helpers beschrijven concrete begrippen, zoals resource-attributen, commentaargrenzen, variabeleafhankelijkheden en modulepaden. Checks met een complexe zelfstandige analyse, zoals backendherkomst of shellescaping, houden die analyse apart. Methoden die alleen een check ondersteunen staan bij die check. Een grotere analyse kan binnen hetzelfde bestand worden onderverdeeld, bijvoorbeeld in commentaaropmaak, regelbreedte en suppressions. Houd die onderdelen inhoudelijk samenhangend en blijf de bestaande RuboCop-regels volgen. Extraheer alleen bestaande gedeelde complexiteit of een substantiële zelfstandige analyse; houd eenvoudige checkspecifieke methoden bij hun check en voeg geen speculatieve abstracties toe.

Het entrypoint laadt eerst `puppet-lint` en daarna de eigen checks. Gebruik daarom `--load` zoals in de voorbeelden, of `require 'project_lint'` vanuit Ruby. Automatische registratie via `lib/puppet-lint/plugins/` wordt bewust niet gebruikt: Puppet-lint laadt gemplugins met `load`, in gemvolgorde. De externe trailing-comma-plugin bewaart oorspronkelijke tokenankers die referencefixes kunnen verwijderen. Door het projectentrypoint na de engine te laden, zijn de upstream-fixes al geregistreerd en blijven beide transformaties bruikbaar. De integratietests bewaken deze laadroute en herhaald laden veroorzaakt geen dubbele registraties. De [native API](https://puppet-lint.com/developer/api/) en de onderhouden [parameterplugin](https://github.com/voxpupuli/puppet-lint-param-types) zijn het uitgangspunt voor nieuwe checks; afhankelijkheden en hun werkelijk geïnstalleerde implementatie bepalen de grenzen van autofix.

[`ModuleResolver`](lib/project_lint/module_resolver.rb) leest het modulepad bij het maken van een analyse, zodat een volgende scan gewijzigde environmentinstellingen kan gebruiken. Gevonden bestanden worden alleen binnen die analyse gecachet en bij gewijzigde bestandsmetadata opnieuw gelezen. Er zijn geen modulepaden die tijdens `require` als globale constants worden vastgelegd. De regels voor vindbaarheid staan bij [Aanroepen van modules controleren](#aanroepen-van-modules-controleren).

#### Omvang en validatiestructuur

`project_positive_flow` meldt een `if`-tak die minder codestructuur bevat dan de bijbehorende `else`. Een opdracht telt als één onderdeel; geneste blokken, resource-instanties, attributen en elementen in arrays, hashes en selectors tellen mee. Commentaar, witruimte, de lengte van strings en gewone functieargumenten tellen niet als extra opdrachten. Naast deze algemene vergelijking controleert dezelfde check de afsluitende structuur van validaties met `fail(...)` en `warning(...)`.

De validatiecontrole herkent rechtstreekse Puppet-aanroepen van `warning()` en `fail()`, ook met een voorloop-`::`. Strings, commentaar, parameterdefaults, afzonderlijke functiedefinities en functies zoals `example::warning()` vallen erbuiten. De positie wordt bepaald via de omliggende opdrachten en blokken, niet via de fysieke regelvolgorde.

#### Classcontroles en vindbare afnemers

`project_class_check_reuse` controleert letterlijke classnamen in de body van iedere class en ieder defined type afzonderlijk. De check telt echte variabelereferenties, inclusief interpolatie en gekwalificeerde verwijzingen vanuit vindbare manifests in het modulepad. Rechtstreeks gebruik via `@variabele` in statisch benoemde ERB-templates en `inline_template` telt ook mee. Commentaar, gewone stringtekst en gelijknamige lokale lambdavariabelen tellen niet als hergebruik. Dynamische classnamen, parameterdefaults, andere resourcetypen en indirecte template- of functielookups vallen buiten deze analyse; beoordeel die bij de review.

Voor hergebruik uit een gecontroleerde class onderzoekt de check de geldige tak van een omvattende `if`, inclusief haakjes en `and` in de voorwaarde. Hij zoekt de class eerst in de huidige bron en daarna via het modulepad. Eén rechtstreekse toekenning van dezelfde classcontrole aan een classvariabele levert een `[review]`-melding op. Toekenningen in lambda's of geneste declaraties, meervoudige toekenningen en samengestelde of omgekeerde resultaten tellen niet mee. Een `or`, negatieve controle, `else` of controle in een andere declaratie bewijst geen beschikbaarheid. Ook deze melding heeft geen autofix: voorwaardelijke toekenningen en verschillen in evaluatiemoment vragen beoordeling van de effectieve catalogus.

#### References en relatiecontext

`project_resource_references` gebruikt de Puppet-AST om directe elementen van iedere array per resourcetype te groeperen. De analyse loopt via de omvattende expressies naar de relatiecontext; ingebouwde datatypen en lokale typealiases worden uitgesloten. De correctie hergebruikt de oorspronkelijke titeltokens in de eerste reference en verwijdert de overige references van dat type elk met hun voorafgaande komma. Daardoor blijven tussenliggende elementen en fixes van andere checks behouden, ook wanneer meerdere typen door elkaar staan. De regels voor sortering, dubbele titels en het verwijderen van de buitenste array staan bij [Resource references](docs/CODE_RULES.md#resource-references).

#### Voorbereiding van voorwaarden

`project_if_sections` volgt opeenvolgende toekenningen terug vanaf de variabelen in de voorwaarde, ook als een afhankelijkheid via een andere variabele loopt. De voorwaarden van aansluitende `elsif`-takken tellen mee bij dezelfde voorbereiding. Een losstaande toekenning of andere opdracht onderbreekt die reeks. Commentaar bij een eerder blok of een bovenliggende voorwaarde geldt niet voor een geneste `if`. Bij een toekenning zoals `$result = if ...` staat de toelichting boven de toekenning en eventuele voorbereiding. De check deelt de analyse van variabeleafhankelijkheden met `project_variable_sections`; de betekenis van de toelichting blijft onderdeel van de inhoudelijke review.

`project_shared_conditions` zoekt binnen hetzelfde opdrachtenblok naar resourcegroepen met dezelfde voorwaarde als een bestaand `if`-blok. Ook een voorwaarde die met diezelfde controle begint en daarna met `and` verdergaat, wordt herkend. De melding wijst naar het bestaande blok; de [regelbeschrijving](docs/CODE_RULES.md#gedeelde-voorwaarden-om-resources-groeperen) beschrijft de expressievormen, analysegrenzen en vereiste review.

#### Hints voor variabelegroepen

Ontbreekt de toelichting bij de eerste variabele na `{`, dan kan de melding ook naar een latere groep in hetzelfde blok verwijzen. Daarvoor moeten de eerste toekenningen dezelfde buitenste functie aanroepen, bijvoorbeeld `stdlib::shell_escape(...)`. De check kijkt alleen voorbij andere toekenningen en stopt zodra de oorspronkelijke variabele wordt gebruikt. Functieaanroepen met een eigen lambdablok vormen zelf geen kandidaat. De melding noemt de regel van het bestaande commentaar, zodat je kunt beoordelen of samenvoegen de code duidelijker maakt. De hint is geen bewijs van inhoudelijke samenhang: controleer ook of de volgorde van uitvoeren mag veranderen.

#### Backendselectie en wrappers

`project_monitoring_backend` volgt de centrale packagewaarde door toekenningen en voorwaarden. Parameters die aantoonbaar als `package` worden doorgegeven aan een monitoringaanroep tellen ook mee. De check herkent lokale wrappers en statisch benoemde wrappers in het ingestelde modulepad, inclusief classes via `include`, `contain` en `require`. Hij meldt de oorspronkelijke backendselectie één keer, ook als meerdere aanroepen ervan afhangen. Gewone pakketkeuzes zonder die relatie vallen buiten de check; `monitoring_custom` zelf blijft verantwoordelijk voor de concrete backendimplementatie.

### Veilige autofixes ontwikkelen

Begin bij de gebruikte bundle: controleer `bundle exec puppet-lint --no-config --config .puppet-lint.rc --version` en bekijk de implementatie met `bundle show puppet-lint`. Gebruik bestaande checks en veilige correcties van Puppet-lint, geïnstalleerde plugins en projectchecks. Dupliceer ondersteunde detectie of correctie niet handmatig of in een apart hulpmiddel.

Gebruik uitsluitend het native `puppet-lint`-fixmechanisme; bouw geen aparte formatter of autofixengine. Iedere custom fix moet idempotent zijn en voldoet aan de [correctieveiligheid in de dagelijkse werkwijze](#werkwijze-bij-een-wijziging): veilig, deterministisch en binnen scope, met behoud van functioneel gedrag, Puppet-relaties, dependencies en configuratie.

De correctie mag geen informatie verzinnen, ontwerpkeuze maken of commentaar verliezen. Controleer ook dat het resultaat geldige Puppet-code is en dat dezelfde regel na de correctie geen melding meer geeft. Bewijs dit voor de hele constructie die je wijzigt; alleen de gemelde regel bekijken is niet voldoende.

`project_guarded_packages` gebruikt de gedeelde AST voor guards, scopes en attribuutvergelijking. De tokenanalyse bepaalt alleen de te vervangen gebieden en de concrete opmaak. De fix draait na die van de bestaande checks en leest de actuele attribuuttokens, zodat eerdere quote- en kommafixes behouden blijven. De [voorwaarden voor packagegroepen](docs/OPERATIONAL_RULES.md#pakketten-en-mappen) beschrijven wanneer het vervangingsplan wordt geweigerd. De diagnose noemt de packagenamen en geeft controltekens met escapes weer; attribuutwaarden en AST-objecten worden niet aan de melding toegevoegd.

Implementeer `fix(problem)` naast `check` in de betreffende `ProjectLint::Checks`-module. Registreer die module in hetzelfde bestand met `PuppetLint.new_check(:project_...) { include CheckModule }`, zoals de bestaande checks doen. Bewaar tijdens `check` de betrokken tokenobjecten en de voorwaarden voor correctie. Geef de melding een index naar die context, zoals de bestaande projectchecks doen, zodat JSON-diagnostiek geen bronwaarden bevat. Controleer alle voorwaarden voordat je tokens wijzigt. Gebruik `PuppetLint::NoFix` wanneer die voorwaarden niet gelden; Puppet-lint behoudt dan de oorspronkelijke melding.

Gebruik `add_token`, `remove_token` en de eigenschappen van bestaande tokens voor de correctie. Hergebruik tokens die andere checks ook kunnen aanpassen en bepaal benodigde afstanden uit de actuele tokeninhoud. Regel- en kolomnummers blijven tijdens de fixfase bij de oorspronkelijke bron horen. De gedeelde helpers in [`TokenHelpers`](lib/project_lint/token_helpers.rb) ondersteunen tokengebieden en witruimte; zij parsen of herschrijven geen volledig bestand.

Puppet-lint voert eerst alle checks uit en daarna de fixes. Houd daarom rekening met eerder gewijzigde of verwijderde tokens. De parameteruitlijning vernieuwt vlak vóór haar fixes de meldingen op de bewaarde tokens via de native `run`-methode: een eerdere komma- of tabcorrectie kan de breedte van een type veranderen. De native afhandeling van `lint:ignore` en `fix(problem)` blijft daarbij actief. Een correctie over meerdere regels moet ook controleren of zij een genegeerd deel zou veranderen.

Voeg regressietests toe onder [`.tools/lint/tests/`](tests/) voor detectie zonder wijziging, exacte uitvoer, een schone hercontrole en een ongewijzigde tweede fixrun. Test ook ongeschikte invoer, genegeerde meldingen, comments, strings, meerdere problemen, geneste constructies en samenwerking met de actieve upstream-checks. Test de native CLI op tijdelijke bestanden om de schrijfhandeling en exitcodes te controleren. Parservalidatie van de geproduceerde uitvoer hoort bij het fixcontract; een algemene syntaxsuite voor modules hoort niet bij deze tooltests.

De normale CLI-aanroep en CI blijven alleen controleren. Schakel `fix` uitsluitend in bij een expliciete correctiestap en voeg geen tweede formatter of automatische commitstap toe.

### Tests uitvoeren en uitbreiden

Voer tests uit vanuit de repositoryroot, na [installatie van de ontwikkelbundle](#gems-installeren):

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alle tooltests of alleen de lintertests. **Wijzigt bestanden:** JUnit-testresultaten. **Verwacht resultaat:** Niet-lege selectie zonder failures, errors of onverklaarde skips.

```sh
bundle exec rake test
bundle exec rake test:lint
```

`test` en de standaardtaak ontdekken `.tools/**/tests/**/*_test.rb` recursief. `test:lint` selecteert alleen `.tools/lint/tests/**/*_test.rb`. De tests staan bij de tool die ze controleren; de roottaak blijft het gezamenlijke startpunt voor CI. Controleer het gerapporteerde aantal tests en eventuele skips. Een geslaagde taak zonder uitgevoerde tests is onvoldoende.

De bestaande testhelper gebruikt `minitest-reporters` voor console-uitvoer en JUnit XML uit dezelfde uitvoering. De rapporten staan per testklasse onder `.tools/lint/results/TEST-*.xml`, ook bij een gewone testfout. De helper bepaalt dit pad vanuit zijn eigen locatie en maakt de uitvoermap aan als die ontbreekt. Een mislukte assertion of onverwachte fout in een test blijft een foutcode opleveren.

De reporter vervangt bij iedere uitvoering alleen de `TEST-*.xml`-bestanden in die map, zodat de rapporten de laatste testselectie weergeven en de lint- en validatierapporten behouden blijven. Met `MINITEST_REPORTERS_REPORTS_DIR` kun je via de reporter een andere uitvoermap kiezen, bijvoorbeeld voor een tijdelijke controle. De rapporten worden niet gecommit.

Een gewone checktest erft rechtstreeks van `Minitest::Test` en gebruikt [`test_helper.rb`](tests/test_helper.rb) voor de native lintaanroep. Zet korte Puppet-invoer en verwachte meldingen in de test zelf. De gedeelde `findings`-helper selecteert één regel via de publieke configuratie en herstelt die configuratie na de aanroep. Er zijn geen gespecialiseerde testbasisklassen of fixtures die op de naam van de testmethode worden opgezocht.

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

Gebruik `assert_fix(before, after, :project_check_name)` voor detectie, exacte correctie, parservalidatie van de gecorrigeerde uitvoer, een schone hercontrole en een ongewijzigde tweede fixrun. Controleer onveilige constructies ook met `fix: true`: hun invoer moet behouden blijven. De tests voor [referencefixes](tests/reference_merging_test.rb) en [documentatie](tests/documentation_structure_test.rb) laten beide kanten zien. De [interactietests](tests/cross_check_autofix_test.rb) controleren gedeelde tokengebieden met meerdere checks.

De `cli_*_test.rb`-bestanden controleren native bestandsuitvoer, exitcodes, configuratie en suppressions. [`external_project_test.rb`](tests/external_project_test.rb) bouwt en installeert de echte `.gem` in een tijdelijk project met een eigen bundle. [`external_ruby_test.rb`](tests/external_ruby_test.rb) controleert dat dezelfde dependency ook RuboCop en het gedeelde Ruby-profiel beschikbaar maakt, zonder aparte RuboCop-regel in de Gemfile. De tests gebruiken reeds geïnstalleerde dependencies en `bundle install --local`; ze hebben geen netwerk, productiegegevens of beheerde hosts nodig. Grotere of hergebruikte Puppet-fragmenten staan als afzonderlijke `.pp`-fixtures bij de tests. De expliciete `fixture`-aanroep wijst naar dat bestand; `fixture_set` leest een benoemde verzameling en faalt als die leeg is. Korte invoer staat direct in Ruby. De CLI-tests hebben daarnaast synthetische Ruby-invoer voor het laden van plugins en persoonlijke configuratie.

Onderzoek een fout eerst bij de vermelde input en assertion. Voer de betreffende test tijdens het ontwikkelen apart uit, bijvoorbeeld `bundle exec ruby .tools/lint/tests/reference_merging_test.rb`, en sluit af met alle tooltests. Voor de GitHub-uitvoervorm kun je `GITHUB_ACTION=synthetic_test bundle exec rake test` gebruiken; diagnostiektellingen moeten in beide uitvoervormen gelijk blijven.

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

Test eigen gereedschap onder `.tools/<tool-name>/tests/`, met bestandsnamen die eindigen op `_test.rb`. Zet gedeelde voorbereiding in `test_helper.rb` wanneer meerdere tests die nodig hebben en bewaar grotere synthetische invoer onder `tests/fixtures/`. Fixtures mogen zo nodig per gedrag worden gegroepeerd. Gebruik korte invoer direct in de test en los paden op vanaf het testbestand, zodat de uitvoering niet afhangt van de huidige werkmap.

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
  task.pattern = '.tools/**/tests/**/*_test.rb'
  task.warning = false
end

task default: :test
```

Voer vanuit de projectroot `bundle exec rake test` uit, lokaal en in CI. Controleer het aantal uitgevoerde tests; een geslaagde taak met nul tests bewijst niets. Een aanvullende `test:<tool-name>`-taak selecteert alleen `.tools/<tool-name>/tests/**/*_test.rb`. Heeft het project al een verzameltaak voor andere tests, voeg de toolselectie dan als afzonderlijke taak toe en behoud de bestaande dekking en het standaardgedrag.

Laat de selectie alleen de eigen tools doorlopen. De tests onder `global-modules/.tools/lint/tests/` horen bij de ontwikkeling van de gedeelde gem en draaien in de CI van die repository. Het afnemende project hoeft die suite niet te kopiëren of via zijn eigen Rakefile te laden. Wie alleen de linters gebruikt, heeft daarvoor geen eigen testmap of testtaak nodig.

#### Testselectie en uitvoeropties

De roottaak hierboven ondersteunt de standaardopties van Rake en Minitest. In deze voorbeelden is `inventory` een eigen tool; vervang de paden en testnamen door die van jouw project.

| Doel | Commando |
| --- | --- |
| Alle eigen tooltests uitvoeren | `bundle exec rake test` |
| Eén testbestand uitvoeren | `bundle exec rake test TEST=.tools/inventory/tests/inventory_test.rb` |
| Testnamen tonen | `bundle exec rake test TESTOPTS='--verbose'` |
| Eén testnaam of patroon selecteren | `bundle exec rake test TESTOPTS='--name=/inventory/'` |
| De testvolgorde reproduceerbaar maken | `bundle exec rake test TESTOPTS='--seed=12345'` |

Geef optiewaarden binnen `TESTOPTS` mee met `=`, zoals `--name=/inventory/`; de testloader van Rake behandelt een losse waarde als bestandsnaam. Gebruik een gerichte selectie tijdens het onderzoeken van een fout. CI voert de volledige bedoelde testtaak uit.

Testmethoden behouden hun gebruikelijke `test_...`-namen; namen, aantallen en skips blijven herkenbaar in de console en de rapporten.

#### JUnit-rapportage instellen

De voorkeur is console-uitvoer en JUnit XML uit dezelfde testuitvoering. Voeg voor de Minitest-suite `gem 'minitest-reporters'` toe aan de eigen root-Gemfile naast Minitest en Rake, voer `bundle install` uit en neem de lockfile op in versiebeheer. De reporter is een dependency van je eigen ontwikkelbundle; `lint-project` installeert hem niet voor afnemers.

Configureer de reporters in de eigen `.tools/<tool-name>/tests/test_helper.rb`. Het onderstaande voorbeeld gaat uit van die mapdiepte, bepaalt de projectroot vanuit de helper en schrijft naar de [gekozen rapportmap](#rapportmap-kiezen):

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

Gebruik dit contract wanneer je een regel in [CODE_RULES.md](docs/CODE_RULES.md), [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) of [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md), of een checkbeschrijving of gebruiksprocedure in deze README bijwerkt. De algemene afspraken voor de inhoudsopgave en samenhang binnen ieder onderwerp staan in [`AGENTS.md`](../../AGENTS.md#markdown). Het onderstaande schema bepaalt welke informatie iedere Puppet-regel daarnaast moet bevatten.

Iedere onafhankelijke Puppet-regel krijgt in `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` of `docs/OPERATIONAL_RULES.md` een eigen `##`- of `###`-subsectie op precies één autoritatieve locatie. Gebruik de onderstaande velden exact in deze volgorde; laat geen veld leeg. Laat verplichte velden niet weg en hernoem of combineer ze niet, tenzij de eigenaar expliciet om een schemawijziging vraagt. Een regel kan meerdere checks hebben en een check meerdere regels: verbind ze met links naar de betreffende secties in de vier documenten, zonder een tweede regelnummering. Plaats de norm bij het beslispunt waarvoor het document verantwoordelijk is en verwijs vanuit de andere regelsbestanden gericht naar die norm.

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

Formuleer toepasselijkheid en vereiste actie rechtstreeks. Behoud of bestaand beleid verplicht, verboden, aanbevolen of toegestaan is. Houd voorwaarden, toegestane uitzonderingen, analysegrenzen en weigeringen van autofix bij de betreffende norm.

`Herkomst` is `Projectregel`, `Upstreamregel`, `Projectspecificatie van upstream` of `Nog niet vastgesteld`; bij upstream hoort een bronverwijzing. De laatste waarde verwijst naar een open verificatiepunt in de oplevering. `Automatische controle` noemt de exacte checknamen of letterlijk `Geen automatische controle`. Beschrijf bij iedere meldingsvariant de trigger, werkelijke severity en variabele tekstdelen. `[review]` is een tekstlabel, geen severity.

`Autofix` is per variant `Geen`, `Voorwaardelijk` of `Alle gedocumenteerde gevallen`, onderbouwd door uitvoering. Beschrijf alle correcties en weigeringsvoorwaarden. Een gemiste detectie is geen toegestane uitzondering. Suppressions noemen naam, syntax, plaats en begrenzing of verbieden suppressie expliciet. Gebruik `Geen` of `Niet van toepassing` uitsluitend met een concrete reden; ontbrekend bewijs krijgt `Nog niet vastgesteld` en een open punt.

Label voorbeelden als `Fragment`, `Volledig uitvoerbaar voorbeeld` of `Handmatig reviewscenario`. Een fragment kan uitsluitend voor benoemde checks groen zijn. Controleer juiste en onjuiste varianten, elke uitzonderings- en begrenzingscategorie, exacte fixes, hercontrole en een ongewijzigde tweede fixrun. Volledige voorbeelden slagen onder het volledige benoemde profiel. Handmatige normen benoemen de concrete reviewstappen en beoordelingscriteria.

Het centrale projectcheckregister staat uitsluitend in deze README, tussen `<!-- BEGIN PROJECT CHECK REGISTRY -->` en `<!-- END PROJECT CHECK REGISTRY -->`. Gebruik exact de kolommen `Check`, `Actief in repositoryprofiel`, `Actief in gedeeld profiel`, `Meldingsvarianten`, `Autofix` en `Regeluitleg`. Iedere geregistreerde projectcheck heeft één rij; controleer ontbrekende, onbekende en dubbele namen afzonderlijk. Verifieer runtimeregistratie, profielactivatie, diagnostische dekking en regelverwijzingen als afzonderlijke eigenschappen. Classificeer de fixdekking per variant, niet op grond van alleen een aanwezige fixmethode. Gemengde fixdekking heet `Per meldingsvariant` en verwijst naar de uitwerking in `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` of `docs/OPERATIONAL_RULES.md`. Regelverwijzingen uit het register wijzen rechtstreeks naar de betreffende autoritatieve headings; maak geen tweede register in een regelsbestand.

Werk bij gewijzigde checks, diagnostics, severity, defaults, autofixes, suppressions, configuratie, dependencies, reporters of consumerinterfaces de betrokken regelvelden in `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` en `docs/OPERATIONAL_RULES.md`, registerrijen en procedures in deze README, implementatie en tooltests samen bij. Onderbouw een conclusie zonder documentatie-impact met de daadwerkelijk beoordeelde interfaces. Controleer versieclaims tegen de gedeclareerde constraints en opgeloste dependencies. Houd gedeclareerde compatibiliteit, geïnstalleerde versies, werkelijk geteste combinaties en ontwikkelbeleid afzonderlijk.

Verifieer gewijzigde configuratie-instructies tegen de geïnstalleerde CLI, loader en tooltests. Bepaal prioriteit per optietype; ga er niet van uit dat iedere latere waarde de eerdere vervangt. Test gewijzigde downstreamprocedures in een onafhankelijk consumerproject met eigen Gemfile, lockfile, lokale configuratie en manifestselectie. Valideer iedere beschreven installatieroute afzonderlijk, inclusief het gebouwde pakket wanneer dat wordt gedistribueerd; een geslaagde path-installatie bewijst geen Git- of pakketinstallatie. Controleer succesvolle en mislukte commando’s, numerieke exitstatus en rapportproductie. Een geslaagde rapportconversie mag een mislukte lint- of validatierun niet verbergen.

Vermeld vóór ieder procedureblok `Werkmap`, `Shell`, `Vereisten`, `Invoer`, `Wijzigt bestanden` en `Verwacht resultaat`. Definieer alle variabelen en vervangbare paden vooraf. Bij gewijzigde context begint een nieuw contextblok. Behoud headingankers zonder dubbele id's en werk inkomende links bij wanneer de doelheading tussen de vier bestanden verhuist. Leg verplaatste, samengevoegde en gecorrigeerde verplichtingen, uitzonderingen, waarschuwingen en gebruiksroutes met hun vorige en nieuwe locatie en bewijs vast in de oplevering, niet in een nieuw repositorydocument. Automatische tests bewaken inventarissen, links en uitvoercontracten; inhoudsbehoud en begrijpelijkheid blijven handmatige review volgens de [documentatiereview](../../AGENTS.md#lint-documentation-maintenance). Verander lintgedrag of een norm niet om een documentatieverschil weg te werken; beschrijf de norm en het waargenomen gedrag afzonderlijk wanneer de bedoelde oplossing nog niet vaststaat.

De lintdocumentatie bestaat uit exact deze README, `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` en `docs/OPERATIONAL_RULES.md`. Houd toolingprocedures en het centrale checkregister hier, algemene Puppet-regels in `docs/CODE_RULES.md`, regels voor Puppet-codecommentaar, Puppet Strings en interface-documentatie in `docs/DOCUMENTATION_RULES.md` en aanvullende operationele regels in `docs/OPERATIONAL_RULES.md`. De [structuurtest](tests/guide_structure_test.rb) controleert deze indeling en bewaakt dat ieder bestand afzonderlijk strikt kleiner blijft dan 300 KiB (307200 bytes). De foutmelding noemt het bestand, de actuele grootte en de projectlimiet. De [documentatiecontracttest](tests/guide_contract_test.rb) bewaakt daarnaast de registratie, regelverwijzingen en verplichte velden in de drie regelsbestanden. Beide tests beoordelen het contract; ze wijzigen geen documentatie.

Controleer bij een overschrijding eerst of informatie volgens het autoriteitsmodel in een van de andere drie documenten thuishoort. Verwijder of verkort geen noodzakelijke verdieping, voorbeelden of voorwaarden en combineer geen onafhankelijke regels uitsluitend om ruimte te besparen. Maak niet automatisch een vijfde document. Is de verdeling correct en verdere opsplitsing nodig, behandel dat dan als een afzonderlijke, expliciet te beoordelen architectuurwijziging.

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
