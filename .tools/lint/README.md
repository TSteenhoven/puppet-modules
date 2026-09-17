# Puppet-lint en RuboCop

Met Puppet-lint controleer je de Puppet-code in dit project. Naast de standaardchecks gebruikt het project eigen checks voor onder meer parameters, documentatie, bestandsrechten en shellcommando's. Deze handleiding bevat de dagelijkse werkwijze, alle Puppet-codeafspraken en reviewcriteria, en de uitleg voor onderhoud en gebruik vanuit andere projecten. De linter is verpakt als de interne Ruby-gem `lint-project`. De [tooltests](#tests-uitvoeren-en-uitbreiden) controleren de checks, autofixes en installatie vanuit andere projecten.

Met [RuboCop](#ruby-code-controleren) controleer je de eigen Ruby-code, waaronder de implementatie van de Puppet-linter en de tooltests. De gem installeert beide linters en levert hun gedeelde regelprofielen mee. Je voert iedere linter met zijn eigen commando uit.

Met de [Puppet-parservalidatie](#puppet-manifests-valideren) controleer je de syntax van de eigen manifests in een afzonderlijke taak. De gem levert daarvoor de native validator en `puppet-validate-junit`, dat per bestand een JUnit-resultaat maakt.

## Leeswijzer

Begin bij de [dagelijkse werkwijze](#werkwijze-bij-een-wijziging) en kies hieronder de onderwerpen die je wijziging raakt. Je hoeft de overige gespecialiseerde naslag niet vooraf door te nemen. Komt tijdens je werk een nieuwe afhankelijkheid of integratie in beeld, neem dan de bijbehorende sectie erbij.

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

## Inhoudsopgave

- [Code controleren](#code-controleren)
  - [Werkwijze bij een wijziging](#werkwijze-bij-een-wijziging)
  - [Werking van de controles](#werking-van-de-controles)
  - [Een melding oplossen](#een-melding-oplossen)
  - [Automatisch corrigeren (autofix)](#automatisch-corrigeren-autofix)
  - [Ruby-code controleren](#ruby-code-controleren)
  - [Lintrapporten maken](#lintrapporten-maken)
  - [Puppet-manifests valideren](#puppet-manifests-valideren)
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
  - [Shellscripts](#shellscripts)
  - [Monitoringchecks](#monitoringchecks)
    - [Invoer en configuratie](#invoer-en-configuratie)
    - [Uitvoer voor beheerders](#uitvoer-voor-beheerders)
    - [Veilige en begrensde uitvoer](#veilige-en-begrensde-uitvoer)
    - [Perfdata en compatibiliteit](#perfdata-en-compatibiliteit)
- [Linter ontwikkelen en onderhouden](#linter-ontwikkelen-en-onderhouden)
  - [Een check toevoegen of wijzigen](#een-check-toevoegen-of-wijzigen)
  - [Technische werking van de checks](#technische-werking-van-de-checks)
  - [Veilige autofixes ontwikkelen](#veilige-autofixes-ontwikkelen)
  - [Tests uitvoeren en uitbreiden](#tests-uitvoeren-en-uitbreiden)
  - [Versies bijwerken](#versies-bijwerken)
  - [CI van deze repository](#ci-van-deze-repository)
  - [Een gem bouwen en versie uitbrengen](#een-gem-bouwen-en-versie-uitbrengen)
- [De linter gebruiken in een ander Puppet-project](#de-linter-gebruiken-in-een-ander-puppet-project)
  - [Gedeelde tooling hergebruiken](#gedeelde-tooling-hergebruiken)
  - [Benodigdheden](#benodigdheden)
  - [Aanbevolen projectstructuur](#aanbevolen-projectstructuur)
  - [Installatie in je project](#installatie-in-je-project)
  - [Eigen lintconfiguratie](#eigen-lintconfiguratie)
  - [Rapportmap kiezen](#rapportmap-kiezen)
  - [Eigen code controleren](#eigen-code-controleren)
  - [Eigen manifests valideren](#eigen-manifests-valideren)
  - [Aanroepen van modules controleren](#aanroepen-van-modules-controleren)
  - [Ruby controleren in een ander project](#ruby-controleren-in-een-ander-project)
  - [Eigen tooltests](#eigen-tooltests)
    - [Testselectie en uitvoeropties](#testselectie-en-uitvoeropties)
    - [JUnit-rapportage instellen](#junit-rapportage-instellen)
  - [Aanvullende tests](#aanvullende-tests)
  - [Rapporten en artifacts in je project](#rapporten-en-artifacts-in-je-project)
  - [Controle in CI](#controle-in-ci)
    - [Rapporten tonen in GitLab](#rapporten-tonen-in-gitlab)
  - [Problemen oplossen](#problemen-oplossen)

## Code controleren

Voer de controles uit vanuit de hoofdmap van deze repository, met de [ontwikkelomgeving](#benodigde-omgeving) en [gems](#gems-installeren) ingericht. Lokaal en in CI gebruiken we hetzelfde commando, dat alleen de projectconfiguratie inleest:

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
```

Controleer vooraf of `.puppet-lint.rc` in de werkmap staat. De CLI slaat een ontbrekend configuratiebestand stilzwijgend over. De relatieve verwijzingen in dat bestand vereisen de repositoryroot als werkmap.

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

### Werking van de controles

`--no-config` slaat de automatisch geladen optiebestanden over. Daarna leest `--config .puppet-lint.rc` expliciet de [projectconfiguratie](../../.puppet-lint.rc). Die laadt het [library-entrypoint](lib/project_lint.rb) met `--load` en leest het [gedeelde profiel](config/puppet-lint.rc) met de native `--config`-optie. Het gedeelde profiel kiest de uitvoeropmaak en laat ook waarschuwingen een foutcode opleveren. De rootconfiguratie voegt alleen de bestandsuitsluitingen van deze repository toe. De twee externe lintplugins worden via de bundle geladen.

De combinatie van beide opties voorkomt invloed van persoonlijke Puppet-lint-instellingen. Een gewone `bundle exec puppet-lint .` leest eerst `/etc/puppet-lint.rc`, daarna `~/.puppet-lint.rc` en ten slotte `.puppet-lint.rc` in de werkmap. Die instellingen worden samengevoegd. Daardoor kan een persoonlijke `--fix` of een eerder uitgeschakelde standaardcheck actief blijven. Alleen `--config` toevoegen voorkomt dat niet; alleen `--no-config` gebruiken laadt juist de projectinstellingen niet.

[Bundler-instellingen](#gems-installeren) bepalen welke gems worden gebruikt en waar die staan. Ze regelen niet welke optiebestanden Puppet-lint leest. Een ander project gebruikt [zijn eigen bundle](#installatie-in-je-project) en geeft de geïnstalleerde gem en configuratie expliciet aan de CLI door.

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

Stopt de linter voordat hij code controleert, controleer dan de Ruby-installatie, bundle en werkmap volgens [Gems installeren](#gems-installeren). Een ontbrekende plugin kan wijzen op een onvolledige installatie van de gem of een verkeerd entrypoint. Met [`--list-checks`](#werking-van-de-controles) zie je of de projectchecks zijn geladen.

Om te controleren of ze ook draaien, maak je tijdelijk buiten de repository een manifest met `$values = [1] + [2]`. Scan het volledige pad met de projectaanroep. Verwacht een foutcode en `project_arrays` bij dat bestand. Vervang de inhoud door `$values = concat([1], [2])`; nu hoort de proef te slagen. Verwijder het tijdelijke bestand daarna.

### Automatisch corrigeren (autofix)

Met `--fix` schrijft Puppet-lint ondersteunde correcties rechtstreeks naar de geselecteerde bestanden. Begin met een gewone scan en beoordeel de [voorwaarden van de betrokken checks](#beschikbare-projectchecks) voordat je de correctie uitvoert.

Kies de bestanden die bij je wijziging horen. De eerste aanroep hieronder corrigeert de volledige projectscope en is alleen geschikt wanneer die hele scope is bedoeld. De tweede beperkt de correctie tot één manifest; de derde selecteert daarnaast één check:

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix .
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix path/to/manifest.pp
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix --only-checks project_resource_references path/to/manifest.pp
```

Zonder `--only-checks` worden de beschikbare fixes van zowel standaardchecks als projectchecks gebruikt. Een check kan een melding laten staan wanneer de code niet veilig te herschrijven is. De concrete grenzen staan bij [inspringing](#inspringing), [komma's](#kommas), [parameteruitlijning](#parameters-en-instellingen), [commentaarscheiding](#toelichtingen-bij-code), [resource references](#resource-references), [packagegroepen](#pakketten-en-mappen) en [Puppet Strings](#puppet-strings).

Geslaagde correcties verschijnen als `fixed`. Een resterende waarschuwing of fout geeft nog steeds een foutcode. Scan daarna zonder `--fix` opnieuw: Puppet-lint verzamelt alle meldingen vóór het corrigeren, waardoor bijvoorbeeld een lengtemelding nog over de oorspronkelijke regel kan gaan.

Bij een syntaxfout schrijft de CLI het manifest niet weg. Genegeerde meldingen worden evenmin gecorrigeerd. Bekijk na de correctieronde de volledige diff en volg de [verdere afronding](#werkwijze-bij-een-wijziging). De gewone projectaanroep en CI controleren alleen; voor correctie gebruik je expliciet `--fix`. Er is geen aparte Rake-task of formatter voor nodig.

### Ruby-code controleren

RuboCop controleert de eigen Ruby-code op de [Ruby-stijlregels van RuboCop](https://docs.rubocop.org/rubocop/). De [projectconfiguratie](../../.rubocop.yml) neemt ook de verborgen map `.tools/` mee, naast onder meer de Gemfile, het Rakefile en Ruby-code in modules. Vendored submodules en geïnstalleerde gems vallen buiten de scan. Templates zijn eveneens uitgesloten: render die eerst en valideer de resulterende code afzonderlijk.

RuboCop wordt met `bundle install` geïnstalleerd. Voer de scan uit vanuit de repositoryroot:

```sh
bundle exec rubocop --config .rubocop.yml
```

De configuratie gebruikt de standaardregels en schakelt nieuwe checks in. Er is geen gegenereerde uitzonderingenlijst voor bestaande meldingen. Daardoor geeft de scan een foutcode zolang er afwijkingen zijn. Herstel meldingen binnen de scope van je wijziging en vermeld de resterende meldingen in de review; een uitgevoerd commando betekent nog geen geslaagde controle.

Begin met een gewone scan voordat je automatisch corrigeert. Kies daarna de bestanden die bij je wijziging horen. Bijvoorbeeld:

```sh
bundle exec rubocop --config .rubocop.yml --force-exclusion --autocorrect .tools/lint/lib/project_lint/ast.rb
bundle exec rubocop --config .rubocop.yml
bundle exec rake test
git diff --check
git diff
```

`--force-exclusion` respecteert de uitgesloten paden ook wanneer je een bestand expliciet opgeeft. [`--autocorrect`](https://docs.rubocop.org/rubocop/usage/autocorrect.html) gebruikt alleen correcties die RuboCop als veilig aanmerkt. Beoordeel de diff en voer de tests opnieuw uit. Controleer gewijzigde Ruby-code in modules ook met tijdelijke functionele controles buiten de repository; de tooltests dekken dat gedrag niet. `--autocorrect-all` bevat ook mogelijk gedragsveranderende correcties en hoort niet bij deze veilige correctiestap.

RuboCop beoordeelt statische eigenschappen zoals opmaak, mogelijke fouten en complexiteit. De tooltests en inhoudelijke review blijven nodig om vast te stellen of de eigen lintchecks correct werken.

### Lintrapporten maken

In deze repository gebruiken alle gepubliceerde validatie-, lint- en testrapporten JUnit XML en staan ze onder `.tools/lint/results/`. Deze gegenereerde map is uitgesloten van versiebeheer. Afnemende projecten kiezen hun [eigen rapportmap](#rapportmap-kiezen). De onderstaande aanroepen gebruiken dezelfde configuratie, bestandsselectie en foutstatus als de gewone scans. Voer ze afzonderlijk uit vanuit de repositoryroot, met de [ontwikkelbundle](#gems-installeren) geïnstalleerd.

Puppet-lint levert zijn native JSON-uitvoer via een pipe aan `puppet-lint-junit`, de rapportomzetter uit `lint-project`. Die schrijft JUnit XML en toont de actieve meldingen met bronpositie in de console. Gebruik Bash met `pipefail`:

```bash
set -o pipefail
mkdir -p .tools/lint/results
bundle exec puppet-lint --no-config --config .puppet-lint.rc --json . | bundle exec puppet-lint-junit .tools/lint/results/puppet-lint-report.xml
```

`pipefail` bewaart de foutstatus van Puppet-lint en laat ook een mislukte omzetting falen. De omzetter controleert geen Puppet-code en voert de linter niet opnieuw uit. De JSON-invoer blijft intern in de pipe; het opgeslagen artifact bevat XML. Gebruik het gedeelde profiel met `--fail-on-warnings`, zodat actieve waarschuwingen zowel de job als het rapport laten falen.

Het Puppet-rapport groepeert actieve meldingen per bestand en check in één JUnit-testcase. De fouttekst bevat alle bijbehorende regels, kolommen en meldingen. Genegeerde en gecorrigeerde meldingen tellen niet als fout. Een scan zonder actieve bevindingen krijgt één geslaagde testcase voor de gehele scan; dat is geen telling van gecontroleerde manifests of functionele tests. Ontbrekende of ongeldige JSON-invoer en een scan zonder gerapporteerde bestanden leveren een rapport met `ReportError` en een foutcode op. Het opgegeven rapportbestand wordt bij iedere uitvoering vervangen; een eventuele bovenliggende map moet bestaan.

RuboCop maakt in één uitvoering normale console-uitvoer en JUnit XML met zijn [ingebouwde formatter](https://docs.rubocop.org/rubocop/latest/formatters.html#junit-style-formatter):

```sh
mkdir -p .tools/lint/results
bundle exec rubocop --config .rubocop.yml --format progress --format junit --out .tools/lint/results/rubocop-report.xml
```

De rapportvarianten voeren iedere linter eenmaal uit en corrigeren geen bronbestanden. RuboCop maakt testcases per bestand en actieve cop. Deze JUnit-testcases beschrijven lintcontroles; de [parservalidatie](#puppet-manifests-valideren) en [tooltests](#tests-uitvoeren-en-uitbreiden) behouden hun eigen rapporten en tellingen. De testreporter vervangt alleen `TEST-*.xml` in dezelfde uitvoermap en behoudt de lint- en validatierapporten. CI bewaart de vier soorten rapporten als [afzonderlijke artifacts](#ci-van-deze-repository).

### Puppet-manifests valideren

Controleer ieder gewijzigd Puppet-manifest afzonderlijk met de parser. Vervang het voorbeeldpad door het gewijzigde bestand:

```sh
bundle exec puppet parser validate path/to/manifest.pp
```

Voer vanuit de repositoryroot de volledige selectie met JUnit-rapportage uit:

```sh
bundle exec rake validate:puppet
```

De taak selecteert alle eigen `.pp`-bestanden recursief, inclusief `examples/` en nieuwe manifests. De vendored submodules `concat`, `debconf`, `reboot`, `stdlib` en `timezone`, geïnstalleerde gems onder `vendor/` en toolfixtures onder `.tools/` vallen buiten deze selectie. De taak staat los van `rake test` en is geen afhankelijkheid van die testtaak.

`validate:puppet` geeft de geselecteerde bestanden aan `puppet-validate-junit` uit de actieve bundle. Dit commando voert voor ieder bestand afzonderlijk de native `puppet parser validate` uit, zonder kleurcodes. Een fout stopt de controle van de overige bestanden niet. De parser controleert syntax zonder een catalogus te compileren of resources toe te passen; lintregels, functiegedrag en de werking op een host vallen buiten deze controle.

Het rapport staat in `.tools/lint/results/puppet-validate-report.xml`, met suite `puppet-validate` en één testcase per uniek manifestpad. Een niet-nul exitcode van de validator geeft een `failure` met de native foutmelding. Ontbrekende bestanden en ongeschikte bestandstypen krijgen een `error`, net als een validator die niet kan starten of door een signaal eindigt. Een lege selectie levert een foutcase op en slaagt dus niet stilzwijgend. De opdracht eindigt met een foutcode zodra een controle of het schrijven van het rapport mislukt.

Voor een gerichte selectie met rapportage gebruik je:

```sh
bundle exec puppet-validate-junit .tools/lint/results/puppet-validate-report.xml path/to/manifest.pp path/to/other.pp
```

Het eerste argument is het rapportpad met extensie `.xml`; daarna volgen concrete `.pp`-bestanden, geen directories. Zet paden met spaties tussen quotes. De opdracht maakt de rapportmap zo nodig aan en vervangt bij iedere uitvoering alleen zijn eigen rapportbestand. Een gerichte run bevat alleen die selectie; gebruik voor de eindcontrole de volledige Rake-taak. Afnemende projecten bepalen hun [eigen manifestselectie](#eigen-manifests-valideren).

### Aanvullende validatie

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

De controles passen geen catalogi toe en hebben geen productiegeheimen of verbindingen met beheerde servers nodig. De [testhandleiding](#tests-uitvoeren-en-uitbreiden) beschrijft welke controles bij de tooltests horen en hoe je synthetische testinvoer gebruikt.

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

De root-Gemfile laadt de lokale gemspec onder `.tools/lint/`. Die beschrijft de runtime-afhankelijkheden: Puppet-lint, de twee externe lintplugins, RuboCop, OpenVox, `syslog` en de XML-library `builder`. De root-Gemfile voegt alleen het ontwikkelgereedschap toe: `metadata-json-lint`, Minitest, `minitest-reporters`, Rake en `rexml` voor het controleren van XML in de reportertests. Er is één lockfile voor lokaal ontwikkelen en CI. OpenVox levert de Puppet-parser voor structurele checks en rechtstreekse manifestvalidatie. Het installeert geen Puppet-agent op je beheerde servers. Alleen `gem install puppet-lint` is daarom niet genoeg voor de volledige projectcontrole.

## Naslag

De afspraken hieronder vormen samen met [`.puppet-lint.rc`](../../.puppet-lint.rc) en de [projectchecks](lib/project_lint/checks/) de Puppet-codestandaard. Gebruik het overzicht om vanuit een lintmelding naar de betreffende afspraak te gaan. De secties bevatten ook handmatige reviewcriteria: een geslaagde scan bewijst geen correct functioneel gedrag, volledige documentatie of veilige serviceconfiguratie.

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
| [`project_resource_references`](#resource-references) | References van hetzelfde type binnen een array, alfabetische letterlijke titels en overbodige buitenste dependency-array. | Voorwaardelijk | Relatiecontext, arraystructuur, dynamische expressies, volgorde en commentaar. |
| [`project_if_sections`](#voorwaarden-toelichten) | Toelichting boven `if`/`unless` en aaneengesloten voorbereiding. | Nee | Inhoudelijke samenhang en evaluatievolgorde. |
| [`project_variable_sections`](#variabelen-groeperen) | Toelichting aan het begin van een blok en na een aantoonbaar afhankelijke groep. | Nee | Groepsindeling en hints voor samenvoegen. |
| [`project_class_check_reuse`](#classcontroles-hergebruiken) | Herhaalde classcontroles, vindbare afnemers en hergebruik van classvariabelen binnen een positieve classcontrole. | Nee | Beschikbaarheid, evaluatievolgorde en indirect gebruik. |
| [`project_packages`](#pakketten-en-mappen) | APT-opties, met lokale defaults, providers en verwijderresources. | Nee | Effectieve of overgeërfde opties en concrete pakketuitzonderingen. |
| [`project_guarded_packages`](#pakketten-en-mappen) | Herhaalde `if !defined(Package[...])`-declaraties met dezelfde expliciete attributen binnen één class of defined type en hetzelfde blok. | Voorwaardelijk | Bestaande packages, evaluatievolgorde, defaults, relaties, commentaar en beschikbaarheid van stdlib. |
| [`project_files`](#eigenaars-en-rechten) | Expliciete eigenaar/groep/modus, recursieve uitvoerrechten en aantoonbare uitsluiting van `source`/`content`. | Nee | Effectieve cataloguswaarden, uitvoeringsidentiteit, toegang en inhoud van bomen. |
| [`project_puppet_urls`](#templates-en-bestandsbronnen) | Toegestane mountprefixen, ook naast een ignore van `puppet_url_without_modules`. | Nee | Dynamische delen, beschikbaarheid en fileserverrechten. |
| [`project_arrays`](#resources-en-afhankelijkheden) | `+` met herkenbare arrays; getal- en hashoptelling blijven toegestaan. | Nee | Dynamische typen en behoud van elementvolgorde. |
| [`project_templates`](#templates-en-bestandsbronnen) | Aanroepen van `epp` en `inline_epp`. | Nee | Templatekeuze, inhoud en gerenderd resultaat. |
| [`project_positive_flow`](#voorwaarden-en-validatie) | Omvang van codetakken en afsluitende structuur van `warning()`/`fail()` in classes en defined types. | Nee | Waarheidsvoorwaarden, `elsif`-prioriteit, geldige en ongeldige uitvoerpaden. |
| [`project_shell`](#shellcommandos-in-puppet) | Aantoonbare escapingherkomst van dynamische exec-commando's en guards. | Nee | Quoting per parserlaag en de plaats van elk argument. |
| [`project_interface_calls`](#aanroepen-en-publieke-interfaces) | Ontbrekende verplichte argumenten bij statisch gevonden declaraties zonder splat. | Nee | Argumenttypen, onbekende parameters, Hiera, defaults, overerving en containment. |
| [`project_parameter_passthrough`](#aanroepen-en-publieke-interfaces) | Eenvoudige parameterdoorgifte via `* =>`; per gefilterde key de bronwaarde of brondefault vergelijken met de ontvangende default. | Nee | Effectieve waarden, aanvullende filtervoorwaarden en indirect samengestelde hashes. |
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

Levert die class al het resultaat van een classcontrole, gebruik dan binnen de geldige tak die variabele. Zo verwijst een Docker-define naar `$docker::monitoring_enable` in plaats van opnieuw `defined(Class['basic_settings::monitoring'])` te berekenen. Controleer dat de class de variabele op dat uitvoerpad invult en dat de afnemer dezelfde betekenis en evaluatievolgorde nodig heeft.

Gebruik binnen een class of defined type één gedeelde variabele als dezelfde classcontrole vaker nodig is. Dat geldt ook bij gebruik in verschillende geneste blokken. Wordt de uitkomst maar één keer gebruikt, neem de controle dan rechtstreeks in de expressie op. Een samengestelde voorwaarde mag wel een eigen naam hebben, zoals `$active = $ensure == present and defined(Class['basic_settings::monitoring'])`: die naam beschrijft wanneer het onderdeel actief is.

`project_class_check_reuse` telt letterlijke classcontroles en vindbaar gebruik van hun resultaat, ook vanuit andere manifests en templates. Binnen een positieve classcontrole meldt hij ook beschikbare classvariabelen voor hergebruik. De [technische naslag](#classcontroles-en-vindbare-afnemers) beschrijft de grenzen van deze analyse. Dynamische classnamen, parameterdefaults en indirecte lookups beoordeel je zelf.

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

Geef waarden rechtstreeks als benoemde attributen mee wanneer een hash alleen gelijknamige variabelen doorgeeft, zonder verdere verwerking. Schrijf bijvoorbeeld `retention_days => $retention_days` in de resource, in plaats van een hash met die combinatie te maken en die via `* => $settings` uit te pakken.

Beoordeel een filter per hashkey. Zoek de bronwaarde of parameterdefault op en vergelijk die met de default van de ontvangende parameter. Geef die key rechtstreeks door wanneer het filter voor die key niets verandert aan de ontvangen waarde. Behoud het filter voor andere keys waarvoor het wel betekenis heeft. Gelijke parameternamen of gelijke parameterdefaults aan beide kanten zijn op zichzelf geen bewijs: een default kan worden overschreven en het filter kan die afwijkende invoer bewust uitsluiten. Dit geldt voor tekst, getallen, booleans, `undef`, arrays en hashes.

Bij een vaste lokale toekenning `$bron = 2` en ontvangende default `2` leveren zowel `$value != 2` als `$value == 2` dezelfde eindwaarde als rechtstreekse doorgifte. Heeft de bronparameter alleen default `2`, dan blijft afwijkende invoer mogelijk. `$value != 2` laat die afwijkende invoer door; `$value == 2` sluit haar juist uit. Ook `$value != 0` kan dan nuttig zijn: invoer `0` leidt door het filter tot de ontvangende default `2`.

`project_parameter_passthrough` meldt eenvoudige, ongefilterde doorgifte wanneer alle hashkeys overeenkomen met rechtstreeks gebruikte variabelenamen. Bij een filter controleert hij iedere key afzonderlijk. Hij volgt de bronvariabele via eerdere, eenduidige lokale toekenningen en verwijzingen naar andere variabelen, of leest de parameterdefault van de omringende class of het defined type. Vervolgens vergelijkt hij die waarde met de default van de parameter die de hashkey aanwijst. De namen van bronvariabele en ontvangende parameter mogen verschillen. Een melding staat op de betreffende hashkey; een nuttig filter voor een andere key houdt die melding niet tegen.

De filteranalyse herkent `.filter` met twee ongetypeerde lambdaparameters zonder defaults en uitsluitend `$value != <letterlijke waarde>` of `$value == <letterlijke waarde>`, ook met omgekeerde operanden of haakjes. Bij gelijke vaste bron- en doelwaarden zijn beide vergelijkingen overbodig voor die key. Bij gelijke parameterdefaults meldt de check alleen `!=` met diezelfde default, zodat filters voor afwijkende invoer behouden blijven. Tekst, getallen, booleans, `undef` en letterlijke arrays en hashes worden exact vergeleken, inclusief hun typen. Bij meerdere filters moet elke voorwaarde aan deze criteria voldoen; een aanvullende voorwaarde wordt niet genegeerd.

De check herkent een hash bij `* =>` en een eerdere, eenduidige hashtoekenning binnen dezelfde scope. Hij zoekt de bron in die scope en het ontvangende defined type in de huidige bron of via het [modulepad](#aanroepen-van-modules-controleren). Onbekende bronwaarden, ontvangers of defaults krijgen geen filtermelding. Verplichte parameters zonder default, dynamische berekeningen, gekwalificeerde bronvariabelen en niet-eenduidige toekenningen blijven buiten de analyse; Puppet-functies en Hiera worden niet uitgevoerd. Ontvangende classes blijven buiten de filteranalyse vanwege automatische parameterlookup. Zichtbare resourcedefaults, resource-overrides en overerving vereisen ook handmatige review. Gewone configuratiehashes vallen buiten deze regel.

Er is geen autofix. Controleer de effectieve waarden en evaluatievolgorde met catalogusvalidatie voordat je een gemelde key rechtstreeks doorgeeft. Beoordeel ook andere afnemers van dezelfde hash voordat je die key eruit verwijdert. Houd rekening met configuratie buiten het geanalyseerde bestand en met Puppet-vergelijkingen: een tekstvergelijking kan ook andere hoofdletters accepteren, terwijl die schrijfwijze voor de ontvanger verschil maakt.

`project_interface_calls` meldt ontbrekende argumenten bij declaraties die de check statisch kan vinden. Binnen deze repository is de eigen moduleverzameling het standaardzoekpad. De [modulepadregels](#aanroepen-van-modules-controleren) beschrijven hoe de declaratie wordt gekozen en welke aanroepen buiten de analyse vallen.

Een geslaagde scan bewijst geen geldige catalogus. Argumenttypen, onbekende parameters, Hiera, overerving, defaults, containment en splats vragen afzonderlijke catalogusvalidatie. Dat geldt ook wanneer de linter een declaratie niet vindt. De check heeft geen autofix; de juiste argumentwaarde volgt uit de interface en het bedoelde gebruik.

#### Resource references

Schrijf references van hetzelfde resourcetype binnen één array als één reference met meerdere titels, ook wanneer er references van andere typen tussen staan. Sorteer de titels alfabetisch en zet de samengevoegde reference op de plaats van de eerste reference van dat type. Dit geldt ook voor classes en eigen defined types. Beoordeel buiten dependency-attributen en losse relatieketens eerst de gevolgen voor de arraystructuur, zoals hieronder beschreven. Bij een dependency-attribuut of een losse relatieketen laat je de buitenste array weg wanneer daarin nog maar één reference staat:

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

#### Volgorde en meldingen

Groepeer resources en aanroepen van defined types bij het onderdeel dat ze beheren. Sluit nieuwe aanroepen aan op de bestaande indeling van het manifest. Aanvullende voorzieningen, zoals back-ups, monitoring en audit, volgen bij elkaar na de configuratie en service waarop ze betrekking hebben, binnen het geldige uitvoerpad en met behoud van hun eigen inschakelvoorwaarden.

Gedeelde voorbereiding en vereiste classes mogen eerder staan wanneer afnemers die nodig hebben. Een vroeg berekende instelvariabele is op zichzelf geen reden om ook de bijbehorende resourcedeclaratie naar het begin te halen. Vereist de evaluatievolgorde een andere plaats voor een gerelateerde aanroep, licht dan bij die aanroep de concrete afhankelijkheid toe en valideer die volgorde.

Behoud de expliciete `require`-, `notify`- en `subscribe`-relaties tussen resources. Ontstaat een afhankelijkheidscyclus, zoek dan welke relatie of containment die veroorzaakt. Herstel de relatie daar, zodat Puppet de volgorde en herstarts kan blijven regelen. Een los `systemctl`-, `service`- of reloadcommando omzeilt die samenhang en is geen vervanging.

Soms is de afhankelijkheid van een volledige class te breed. Koppel de ordering dan waar nodig aan een kleinere, stabiele resource en behoud meldingen zoals `notify => Service['nginx']`.

Houd instellingen die alleen voor een aanvullende voorziening nodig zijn bij die voorziening. Een bestand dat de daemon zelf configureert blijft bij de daemonconfiguratie staan.

Beoordeel deze indeling bij de review van het hele omliggende blok. De [sectiechecks](#toelichtingen-bij-code) controleren opmaak en toelichtingen; een geslaagde lintscan bewijst niet dat aanroepen inhoudelijk op de juiste plek staan. Verplaats ze niet automatisch op basis van hun naam, type of afstand tot een variabele: hun functie, voorwaarden en evaluatievolgorde bepalen welke plek klopt.

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

Er is geen autofix voor de bronkeuze. Een andere mount of template kan andere inhoud opleveren. Houd paden en titels voorspelbaar en controleer de gerenderde varianten bij de gebruiker die ze moet kunnen lezen. De aanvullende URL-check staat in [`puppet_urls.rb`](lib/project_lint/checks/puppet_urls.rb); hiervoor worden geen geïnstalleerde gems aangepast.

#### Pakketten en mappen

Voorkom dat een APT-installatie onbedoeld aanbevolen of voorgestelde pakketten meeneemt. Laat `install_options` eindigen met `['--no-install-recommends', '--no-install-suggests']`, tenzij een concreet pakket een onderbouwde afwijking nodig heeft. Voeg deze opties met `concat(...)` achter de aangeleverde opties toe. `union(...)` verwijdert duplicaten en garandeert daardoor niet dat de voorgeschreven opties achteraan staan.

`project_packages` controleert de opties met inbegrip van zichtbare lokale resourcedefaults. Verwijderresources en expliciet niet-APT-providers vallen buiten die controle. Bij een onopgeloste provider, overerving, overrides of samengestelde opties kan een `[review]`-melding volgen. Beoordeel dan de effectieve opties en de reden voor een eventuele pakketuitzondering. De check heeft geen autofix.

Voeg herhaalde package-declaraties met dezelfde instellingen samen met behoud van hun evaluatievolgorde, attributen en relaties. `project_guarded_packages` zoekt binnen iedere class en ieder defined type naar twee of meer `if !defined(Package['naam'])`-blokken met een gelijknamige package-resource. De expliciete attributen en waarden moeten overeenkomen; hun schrijfvolgorde telt niet mee. Iedere groep krijgt één melding bij de eerste guard, met de packagenamen in declaratievolgorde. Verschillende instellingen vormen afzonderlijke groepen. Afzonderlijke takken, lambda's, dynamische titels en enkele declaraties worden niet samengevoegd.

De autofix vervangt de guards door een rechtstreekse `ensure_packages()`-aanroep. Die functie controleert bestaande packages ook op de opgegeven attributen. Bij conflicterende instellingen is een duplicate-resource-fout gewenst: zo wordt een inconsistente declaratie zichtbaar. Filter bestaande packages daarom niet vooraf uit de lijst.

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

### Shellscripts

De [shellconventies in `AGENTS.md`](../../AGENTS.md#shell-scripts) bepalen de opbouw, naamgeving, opmaak, commandodetectie, argumentverwerking en gegevensverwerking voor alle eigen shellcode. Gebruik ze voor POSIX shell en Bash, ook in bestanden zonder extensie, templates en inline fragmenten. De [shellvalidatie](../../AGENTS.md#shell-validation) beschrijft hoe je de bron en gegenereerde uitvoer controleert; een geslaagde Puppet-lintscan vervangt die controle niet.

Beoordeel externe tools volgens de [afspraken over native tools en dependencies](../../AGENTS.md#native-tools-and-dependencies). Gebruik voor eenvoudige controles bij voorkeur shellfunctionaliteit of de uitvoer en exitcode van het oorspronkelijke commando. Een parser zoals `jq` blijft geschikt voor complexe gestructureerde gegevens. Neem bij het verwijderen van een tool ook de pakketinstallatie en andere afnemers mee, en toets volgens de shellvalidatie of het gedrag gelijk blijft. Deze afweging vraagt handmatige review; Puppet-lint bepaalt niet of een runtime-tool functioneel nodig is.

Voor waarden die Puppet in een shelltemplate invoegt, gebruik je ERB met directe shelltoekenningen. Beperk ERB tot het invoegen van waarden; de voorbereiding in Puppet bestaat uit defaults voor beheerde configuratie, serialisatie en shellveilige argumenten. Volg daarbij de afspraken voor [templates](#templates-en-bestandsbronnen) en [shellcommando's in Puppet](#shellcommandos-in-puppet). Voeg alleen een afzonderlijk configuratiebestand of een parser toe wanneer dat is gevraagd of al gebruikelijk is.

Behoud volgens de [invoerafspraken](../../AGENTS.md#arguments-and-runtime-settings) de bestaande invoerroute voor daemonconfiguratie en inloggegevens. Lees waar mogelijk de effectieve daemonconfiguratie, bijvoorbeeld met `vnstat --showconfig`, zodat je geen tweede instellingen of sysfs-terugvalroutes hoeft te onderhouden.

### Monitoringchecks

Checks volgen de algemene [shellconventies](../../AGENTS.md#shell-scripts) en gebruiken POSIX `#!/bin/sh` met Nagios-exitcodes. De aanvullende [monitoringcontracten](../../AGENTS.md#monitoring-checks) regelen gedeelde executables, instellingen per target en de levenscyclus van registraties. Beoordeel status, ernst, parsing, buffering en perfdata ook tegen de hieronder beschreven uitvoercontracten. Lange uitvoer staat standaard aan; een schakelaar daarvoor wordt alleen op verzoek toegevoegd.

#### Invoer en configuratie

Een monitoringcheck heeft zijn optionele runtime-defaults in het executable. Puppet geeft alleen instellingen door die expliciet zijn ingevuld. Gebruik voor zulke Puppet-parameters een passend `Optional[...]` met `undef` als default. Bij `undef` laat de registratie zowel de CLI-optie als het argument weg. Zo ontstaan er geen tweede defaults in manifests, wrappers of ERB-expressies. Pas dit toe op nieuwe instellingen en bij wijzigingen aan bestaande defaultverwerking.

De check verwerkt commandline-opties, omgevingsvariabelen en defaults volgens het [configuratiecontract in `AGENTS.md`](../../AGENTS.md#monitoring-check-configuration), dat de algemene invoer- en validatieregels aanvult. Puppet mag twee expliciet opgegeven drempels alvast vergelijken, maar neemt daarvoor geen ontbrekende scriptdefault over.

Het uitvoerinterval en de timeout van de monitoringagent horen bij de registratie. Een scriptoptie of omgevingsvariabele verandert die agentinstellingen niet. Controleer hun samenhang volgens de [afspraken voor de executor](../../AGENTS.md#executor-scheduling).

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

### Een gem bouwen en versie uitbrengen

Het [versienummer en de runtime-afhankelijkheden](lint-project.gemspec) horen bij de gem. Bouw na de volledige validatie een pakket vanuit zijn eigen map:

```sh
cd .tools/lint
gem build lint-project.gemspec --output /tmp/lint-project.gem
```

Het pakket bevat alleen `lib/`, `bin/`, `config/`, de README en de licentie, inclusief `puppet-lint-junit`, `puppet-validate-junit` en hun XML-dependency. Versie `0.1.8` bevat de standaard actieve check `project_guarded_packages` voor [herhaalde package-declaraties](#pakketten-en-mappen), inclusief een voorwaardelijke autofix naar `ensure_packages()`. Afnemende projecten kunnen daardoor nieuwe lintmeldingen krijgen; na autofix worden conflicterende package-attributen zichtbaar als catalogusfout. De gegenereerde Puppet-code vereist stdlib; de linter levert die module niet mee. Tests, ontwikkelgems en Puppet-modules zijn geen onderdeel van de distributie. Publicatie naar RubyGems is niet nodig; je kunt het bestand via je eigen goedgekeurde distributieroute beschikbaar maken. Een ontvangend project installeert zijn eigen dependencies en bewaart zijn eigen lockfile.

Behandel checknamen, meldingsniveaus, veilige fixresultaten, `PROJECT_LINT_MODULEPATH`, het entrypoint, de gedeelde configuratiepaden en de rapportcommando's als publieke interfaces. Verhoog de gemversie bij een uitgave en beschrijf wijzigingen die afnemers raken. Wijzigingen aan actieve regels en profielen kunnen bestaande projecten laten falen; laat afnemers zo’n update bewust uitvoeren met Bundler en hun eigen CI. Werk een Git-afnemer bij naar een gecontroleerde revisie en een pakketafnemer naar een gecontroleerde gemversie.

## De linter gebruiken in een ander Puppet-project

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
| `.puppet-lint.rc` en `.rubocop.yml` | Bewaar hier de eigen bestandsselectie en laad de gedeelde profielen uit de gem volgens de voorbeelden hieronder. |
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

```sh
gem install bundler
gem install /path/to/lint-project.gem
```

Gebruik bij deze installatieroute de volgende dependency in plaats van de `path:`-dependency:

```ruby
source 'https://rubygems.org'

gem 'lint-project', '~> 0.1.3', require: false
```

Voer daarna ook `bundle install` uit. Een interne gemserver kan hetzelfde pakket aanbieden via de gebruikelijke Bundler-sourceconfiguratie. Er is geen gedeelde `BUNDLE_GEMFILE` of apart installatieprogramma nodig.

Bundler ondersteunt ook een rechtstreekse `git:`-dependency. Voor deze repository heeft die `glob: '.tools/lint/*.gemspec'` nodig. Leg de gekozen revisie vast in Gemfile.lock en controleer updates in je eigen CI. Het pad `.tools/lint` is alleen nodig om de gem in de monorepo te vinden; de CLI en configuratie gebruiken daarna de geïnstalleerde gem.

### Eigen lintconfiguratie

Bewaar projectspecifieke bestandsuitsluitingen in je eigen `.puppet-lint.rc`. De gewone lintregels en uitvoerinstellingen komen uit het meegeleverde `config/puppet-lint.rc`. Voor de aanbevolen indeling sluit je de gedeelde modules en geïnstalleerde gems uit van de eigen stijlscan:

```text
--ignore-paths=global-modules/*,./global-modules/*,vendor/*,./vendor/*
```

Houd de modules die nodig zijn voor interfacecontrole beschikbaar, ook als hun code buiten de stijlscan valt. Voeg geen regeluitsluitingen toe om echte fouten te verbergen; de toegestane lokale suppressions staan bij de betreffende [codeafspraken](#naslag).

### Rapportmap kiezen

Kies een eigen map voor gegenereerde rapporten binnen je project, bijvoorbeeld `.tools/quality/results/`, `.tools/checks/results/` of `build/reports/`. De naam `lint` en de locatie onder `.tools/` zijn voor afnemende projecten niet verplicht. `.tools/lint/results/` is de keuze van deze repository, geen vast uitvoerpad van de gedeelde gem. Gebruik een aparte uitvoermap, houd die buiten versiebeheer en schrijf niet naar `global-modules` of de geïnstalleerde gem.

De voorbeelden hieronder gebruiken `PROJECT_REPORT_DIR` om die projectkeuze door te geven. Stel de variabele in vanuit je eigen projectroot voordat je de rapportcommando's uitvoert:

```sh
export PROJECT_REPORT_DIR=".tools/quality/results"
```

Dit is een afspraak in de voorbeeldconfiguratie van het afnemende project, geen automatisch ingelezen geminstelling. De shellcommando's geven het pad expliciet mee; de voorbeeld-Rake-taak en testhelper lezen de variabele zelf. Zij gebruiken `.tools/quality/results` wanneer de variabele ontbreekt. Geef een niet-leeg pad op, relatief aan de eigen projectroot. De voorbeelden plaatsen ook de CI-artifacts binnen die checkout.

Gebruik dezelfde waarde lokaal en in CI. In het [GitHub-voorbeeld](#controle-in-ci) stel je die eenmaal onder `env` in; in het [GitLab-fragment](#rapporten-tonen-in-gitlab) onder `variables`. De uitvoercommando's, uploadpaden en testsamenvatting verwijzen naar die instelling. Pas daarnaast de eigen `.gitignore` aan het concrete pad aan: Git vervangt daar geen omgevingsvariabelen. De [rapportafspraken](#rapporten-en-artifacts-in-je-project) tonen per controle het bestand binnen deze map.

### Eigen code controleren

Het voorbeeld hieronder gebruikt de aanbevolen indeling en controleert twee concrete manifests. Voer het vanuit je projectroot uit:

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

### Eigen manifests valideren

Stel eerst de [rapportmap](#rapportmap-kiezen) in en voer parservalidatie als afzonderlijke controle uit vanuit je eigen projectroot. Met `lint-project` vanaf versie `0.1.3` is het rapportcommando beschikbaar in je eigen bundle:

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

### Aanroepen van modules controleren

`PROJECT_LINT_MODULEPATH` bevat de bestaande, absolute modulemappen in dezelfde volgorde als Puppet gebruikt. Op macOS en Linux is de scheiding `:`; spaties zijn toegestaan, een `:` in een mapnaam niet. Een lege, relatieve of ontbrekende map geeft een fout. Zonder deze variabele zoekt de linter vanaf de huidige werkmap als moduleverzameling en slaat hij de vendored namen `concat`, `debconf`, `reboot`, `stdlib` en `timezone` over. Stel de variabele in externe projecten expliciet in.

De resolver gebruikt eerst declaraties uit de actuele lintinvoer. Daarna kiest hij de eerste modulemap met de gevraagde modulenaam en zoekt daar `example/manifests/init.pp` voor `example`, of `example/manifests/item.pp` voor `example::item`. Ontbreekt dat manifest, dan zoekt hij niet verder in een latere kopie van de module. Bestanden achter symlinks buiten de ingestelde modulemap worden niet gelezen.

Controleer environments met verschillende modulepaden apart. Eén samengevoegde lijst kan een andere moduleversie kiezen dan Puppet op de server. De linter leest geen `environment.conf`.

> [!CAUTION]
> Een niet-vindbare declaratie kan geen melding over ontbrekende parameters opleveren. Een geslaagde scan bewijst daarom niet dat Puppet de catalogus kan compileren. Controleer aanroepen ook met de eigen catalogusvalidatie.

Bij vindbare declaraties controleert `project_interface_calls` verplichte parameters, inclusief `Optional[...]` zonder default. Argumenttypen, onbekende parameters, functies, dynamische classnamen, `include`/`contain`, Hiera, overerving en splats worden daarmee niet volledig gevalideerd.

`project_parameter_passthrough` gebruikt dezelfde vindbare defined types om per gefilterde key de bronwaarde of brondefault met de ontvangende parameterdefault te vergelijken. De bron wordt in de actuele lintinvoer opgezocht. Een onbekende bron, ontvanger of default geeft geen filtermelding; de [regel voor parameterdoorgifte](#aanroepen-en-publieke-interfaces) beschrijft de verdere grenzen en reviewcriteria.

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

```sh
bundle exec rubocop --config .rubocop.yml
```

Voor veilige lokale correcties volg je de [RuboCop-werkwijze](#ruby-code-controleren), met de `.rubocop.yml` van je eigen project. Voor console-uitvoer en JUnit XML uit één uitvoering gebruik je de [rapportaanroep](#rapporten-en-artifacts-in-je-project). Voer de Ruby-scan ook in je eigen CI uit. Puppet-lint en RuboCop hebben afzonderlijke commando's: een Puppet-lintscan voert geen Ruby-scan uit.

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

### Aanvullende tests

Voer naast linting en de [parservalidatie](#eigen-manifests-valideren) de gedragstests van je eigen project uit, met de Puppet- of OpenVox-versie, facts en Hiera die je daarvoor gebruikt. De ontwikkelbundle van de moduleverzameling is geen vereiste.

De gemtests controleren het lintgereedschap. Ze vervangen geen catalogus-, template-, script- of monitoringvalidatie van afnemende projecten.

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

Gebruik dezelfde Gemfile, lockfile, configuratie en CLI-aanroepen als lokaal. Het onderstaande GitHub Actions-voorbeeld hoort bij een project met `global-modules`, eigen Ruby-code en een Minitest-suite met de [reporterconfiguratie hierboven](#junit-rapportage-instellen). Bewaar het als `.github/workflows/checks.yml` in je eigen project en stel `env.PROJECT_REPORT_DIR` in op de eigen rapportmap. De commando's, uploads en testsamenvatting gebruiken die waarde. Gebruik de jobs die bij je project horen: zonder eigen testsuite laat je `tool_tests` weg.

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

Voeg de onderstaande rapportmap en artifactinstellingen toe aan de bijbehorende configuratie in `.gitlab-ci.yml`. Voeg `PROJECT_REPORT_DIR` toe aan de bestaande `variables` en kies daar het eigen pad. Zo gebruiken de scripts en uploads dezelfde [CI/CD-variabele](https://docs.gitlab.com/ci/variables/where_variables_can_be_used/); alleen een `export` binnen het script stelt die variabele niet voor de artifactupload in. Dit fragment bevat geen volledige jobs: behoud de eigen installatie en de hierboven beschreven `script`-commando's. Laat `tool_tests` weg wanneer je project geen eigen testsuite heeft.

```yaml
variables:
  PROJECT_REPORT_DIR: .tools/quality/results

puppet_validate:
  artifacts:
    name: Puppet-validate-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/puppet-validate-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/puppet-validate-report.xml"

puppet_lint:
  artifacts:
    name: Puppet-lint-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/puppet-lint-report.xml"

ruby_lint:
  artifacts:
    name: Ruby-lint-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/rubocop-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/rubocop-report.xml"

tool_tests:
  artifacts:
    name: Test-results
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/TEST-*.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/TEST-*.xml"
```

`when: always` bewaart beschikbare rapporten ook na een gewone validatie-, lint- of testfout. De CLI-foutcode bepaalt of de job faalt; JUnit-publicatie verandert die status niet. Bekijk de resultaten onder **Tests** in de pipeline en in de testsamenvatting van de merge request. Parservalidatie en lintchecks blijven herkenbaar aan hun eigen suite en artifact. De repository zelf gebruikt de [GitHub Actions-workflow](#ci-van-deze-repository).

### Problemen oplossen

| Probleem | Controle en herstel |
| --- | --- |
| Bundler mist de gem of een executable | Controleer Ruby, `Gem.bindir`, PATH en de eigen Gemfile. Installeer het pakket of configureer de gembron en voer `bundle install` uit. |
| Projectchecks ontbreken | Controleer `bundle show lint-project` en gebruik `--load` vóór andere projectopties. `--list-checks` moet de `project_*`-checks tonen. |
| Persoonlijke opties hebben invloed | Gebruik `--no-config` vóór de expliciete configuratiebestanden. |
| Een scan slaagt terwijl eigen code fout is | Controleer of alle eigen manifests geselecteerd zijn. Probeer tijdelijk `$values = [1] + [2]`; verwacht `project_arrays` en een foutcode. `concat([1], [2])` hoort die melding op te lossen. |
| Een onjuiste aanroep geeft geen melding | Controleer modulepad, modulevolgorde en manifestlocatie; valideer de catalogus voor gedrag dat lint niet kan bewijzen. |
| De lokale configuratie ontbreekt | Herstel `.puppet-lint.rc`; vertrouw niet op de native CLI om een ontbrekend optiebestand te melden. |
