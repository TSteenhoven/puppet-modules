# Puppet-lint

Met Puppet-lint controleer je de Puppet-code in dit project. De standaardchecks worden aangevuld met eigen checks voor onder meer parameters, documentatie, bestandsrechten en shellcommando's. De tests controleren daarnaast voorbeelden, catalogi, templates en monitoringgedrag.

De hulpmiddelen staan in `.tools`, zodat je ze niet verwart met de Puppet-modules. Voer de commando's voor deze repository uit vanuit de hoofdmap. Gebruik je de linter in een ander project, volg dan [de stappen voor dat project](#de-linter-gebruiken-in-een-ander-puppet-project). De instellingen staan in [`.puppet-lint.rc`](../../.puppet-lint.rc) en de eigen checks in [`lib/puppet-lint/plugins/`](lib/puppet-lint/plugins/).

## Inhoudsopgave

- [Installatie](#installatie)
  - [Ruby op macOS](#ruby-op-macos)
- [Code controleren](#code-controleren)
- [De linter gebruiken in een ander Puppet-project](#de-linter-gebruiken-in-een-ander-puppet-project)
  - [Benodigdheden](#benodigdheden)
  - [Installatie in je project](#installatie-in-je-project)
  - [Eigen code controleren](#eigen-code-controleren)
  - [Aanroepen van modules controleren](#aanroepen-van-modules-controleren)
  - [Aanvullende tests](#aanvullende-tests)
  - [Controle in CI](#controle-in-ci)
  - [Problemen oplossen](#problemen-oplossen)
- [Versies bijwerken](#versies-bijwerken)
- [Werking van de controles](#werking-van-de-controles)
- [Beschikbare projectchecks](#beschikbare-projectchecks)
- [Lange regels](#lange-regels)
- [Parameters en resources](#parameters-en-resources)
- [Commentaar en documentatie](#commentaar-en-documentatie)
- [Bestanden en beveiliging](#bestanden-en-beveiliging)
- [Gedeelde services en systemd](#gedeelde-services-en-systemd)
- [Shellscripts en monitoring](#shellscripts-en-monitoring)

## Installatie

Gebruik de nieuwste stabiele Ruby en Bundler. Richt op macOS eerst Ruby in met de onderstaande stappen. Heb je de nieuwste stabiele Ruby al actief, ga dan door met [de gems installeren](#gems-installeren).

### Ruby op macOS

De Ruby die macOS meelevert is te oud voor deze ontwikkelomgeving. Installeer de nieuwste stabiele Ruby met de [Homebrew-formule `ruby`](https://formulae.brew.sh/formula/ruby).

Installeer eerst [Homebrew](https://brew.sh/) als het commando `brew` nog niet beschikbaar is. Voer daarna uit:

```sh
brew install ruby
export PATH="$(brew --prefix ruby)/bin:$PATH"
export PATH="$(ruby -r rubygems -e 'print Gem.bindir'):$PATH"
ruby --version
command -v ruby
```

Controleer met `ruby --version` welke versie actief is en dat `command -v ruby` naar Homebrew wijst, niet naar `/usr/bin/ruby`. De eerste `export` kiest Homebrew-Ruby. De tweede maakt de commando's beschikbaar die je daarna met `gem install` installeert. `brew --prefix` kiest het juiste pad voor zowel Apple Silicon als Intel.

Voeg de twee `export PATH=...`-regels ook in deze volgorde aan `~/.zshrc` toe om ze in nieuwe macOS-terminals te gebruiken. Laat ze na eventuele Homebrew-initialisatie staan. Gebruik je een Ruby-versiebeheerder zoals rbenv of mise, installeer en activeer de nieuwste stabiele Ruby daarmee.

### Gems installeren

Voer dit uit vanuit de repositoryroot met de juiste Ruby actief. Haal ook de Git-submodules op; de catalogustests hebben die nodig.

```sh
git submodule update --init --recursive
gem install bundler
export BUNDLE_VERSION=system
bundle install
```

`gem install bundler` installeert de nieuwste stabiele Bundler. Met `BUNDLE_VERSION=system` gebruik je de geïnstalleerde versie, ook wanneer `BUNDLED WITH` in de lockfile een oudere versie noemt. De [Gemfile](../../Gemfile) bevat geen vaste gemversies. `Gemfile.lock` bewaart wel de geteste combinatie, zodat `bundle install` lokaal en in CI dezelfde gems installeert.

Krijg je een Bundler-fout met `/System/Library/Frameworks/Ruby.framework` of `/usr/bin/bundle` in de melding, dan gebruikt je terminal nog de macOS-installatie. Controleer eerst `ruby --version`, `command -v ruby` en `command -v bundle` en herstel de PATH-instelling hierboven. Bundler installeren met de oude systeem-Ruby of `sudo gem install` lost die versieverschillen niet op.

Naast Puppet-lint worden twee bestaande lintplugins, OpenVox, `metadata-json-lint`, Minitest en Rake geïnstalleerd. OpenVox levert de Puppet-parser voor structurele checks en catalogustests. Het installeert geen Puppet-agent op je beheerde servers. Alleen `gem install puppet-lint` is daarom niet genoeg voor de volledige projectcontrole.

## Code controleren

Voer na je wijzigingen de volledige lintscan en tests uit. De afsluitende `.` geeft aan dat Puppet-lint de repository moet scannen; laat die ook staan wanneer je extra CLI-opties meegeeft.

```sh
bundle exec puppet-lint .
bundle exec rake spec
git diff --check
```

Controleer een gewijzigd manifest ook rechtstreeks met de Puppet-parser. Voor modulemetadata is een aparte validator beschikbaar:

```sh
bundle exec puppet parser validate path/to/manifest.pp
bundle exec metadata-json-lint module/metadata.json
```

Een geslaagde lintscan betekent dat de code aan de automatische checks voldoet. Controleer bij gewijzigd gedrag ook wat Puppet op de server gaat doen: welke bestanden veranderen, welke services herstarten en welke rechten of verbindingen nodig zijn. Test een normaal gebruik en een praktisch foutgeval. Raak je een gedeelde bouwsteen, neem dan ook de modules mee die deze gebruiken.

De afspraken hieronder vormen samen met de configuratie en plugins de codestandaard. Puppet Strings bij de classes en defined types beschrijven hun concrete parameters en gedrag. [`AGENTS.md`](../../AGENTS.md) beschrijft het werkproces. AI-agents laten hun gecontroleerde wijzigingen in de werkboom staan; een mens beoordeelt en commit ze.

## De linter gebruiken in een ander Puppet-project

Gebruik je deze moduleverzameling in een ander Puppet-project, dan kun je dezelfde linter ook voor je eigen manifests, rollen en profielen gebruiken. Je stelt in waar de linter staat, welke bestanden je wilt controleren en waar Puppet de modules vindt.

De linter gebruikt de configuratie, plugins en [coderegels](#beschikbare-projectchecks) rechtstreeks uit de checkout van de moduleverzameling die je project al gebruikt.

De voorbeelden hieronder gaan uit van deze mappen:

```text
project/
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

`global-modules/` is een voorbeeldpad. Staat de moduleverzameling ergens anders, vervang dit pad dan in de installatiecommando's en het script. Een dieper pad met spaties, zoals `dependencies/shared modules/puppet-modules`, werkt ook.

### Benodigdheden

Gebruik een volledige checkout van deze repository. Daarin moeten `.puppet-lint.rc`, `Gemfile`, `Gemfile.lock` en de hele map `.tools/lint/` aanwezig zijn. Die laatste map bevat de plugins en de Ruby-bestanden die ze nodig hebben, waaronder `lib/model.rb` en `lib/nullability.rb`. Een pakket met alleen Puppet-modules is dus niet voldoende. Controleer ook of verborgen bestanden worden meegeleverd.

Haal de submodules `concat`, `debconf`, `reboot`, `stdlib` en `timezone` op. Dit zijn Puppet-modules die nodig kunnen zijn om aanroepen en catalogi te controleren. De tests van de moduleverzameling gebruiken daarnaast de overige repositorybestanden, `Rakefile`, `.gitmodules` en de Git-index, waarin Git de opgenomen bestanden en submodules bijhoudt.

### Installatie in je project

Gebruik de nieuwste stabiele Ruby en Bundler. Richt op macOS eerst [Ruby](#ruby-op-macos) in. Voer daarna onderstaande commando's uit vanuit de hoofdmap van je eigen project. Het voorbeeld gaat uit van een bestaande checkout onder `global-modules`; pas dat pad aan als de moduleverzameling elders staat.

Gebruik hiervoor een gewone terminal, buiten een eventueel eigen `bundle exec`. Heb je zelf `BUNDLE_*`-variabelen voor een andere gemomgeving ingesteld, verwijder die dan eerst. Denk bijvoorbeeld aan `BUNDLE_WITHOUT`, waarmee gems kunnen worden overgeslagen.

```sh
git -C global-modules submodule update --init --recursive
gem install bundler
(
  lint_root="$PWD/global-modules"
  export BUNDLE_GEMFILE="$lint_root/Gemfile"
  export BUNDLE_PATH="$PWD/.cache/puppet-lint"
  export BUNDLE_IGNORE_CONFIG=1 BUNDLE_FROZEN=true BUNDLE_VERSION=system
  bundle install
)
```

Bundler installeert de Ruby-pakketten, de gems, uit `global-modules/Gemfile`. De bijbehorende `Gemfile.lock` bepaalt welke versies worden gebruikt. Deze gems komen apart onder `.cache/puppet-lint/` te staan. Voeg `/.cache/puppet-lint/` toe aan de `.gitignore` van je eigen project.

Deze installatie levert ook de aanvullende lintplugins en de OpenVox-parser. Heeft je project een eigen Gemfile, blijf die dan voor je eigen ontwikkelgereedschap gebruiken. Je hoeft daar geen gems voor deze linter aan toe te voegen.

De `BUNDLE_*`-instellingen houden de installatie gescheiden van je andere Ruby-projecten:

- `BUNDLE_GEMFILE` kiest de Gemfile van de moduleverzameling.
- `BUNDLE_PATH` kiest de aparte installatiemap voor de gems.
- `BUNDLE_IGNORE_CONFIG=1` negeert persoonlijke en lokale Bundler-configuratiebestanden.
- `BUNDLE_FROZEN=true` voorkomt dat Bundler de lockfile tijdens de installatie wijzigt.
- `BUNDLE_VERSION=system` gebruikt de geïnstalleerde Bundler.

De haakjes rond het installatieblok zorgen dat deze instellingen alleen binnen dat blok gelden. Daarna kun je je gewone projectcommando's blijven gebruiken.

### Eigen code controleren

Sla onderstaand script op als `.tools/lint.rb` in je eigen project. Zo staat het ontwikkelgereedschap, net als in deze repository, bij elkaar onder `.tools/`. Gebruik dit script zowel lokaal als in CI. Pas bovenaan deze drie instellingen aan:

| Instelling | Wat geef je op? |
| --- | --- |
| `lint_root` | De map waarin de moduleverzameling staat. |
| `source_dirs` | De mappen met je eigen Puppet-code, gerekend vanaf de hoofdmap van je project. |
| `module_dirs` | De volledige paden waarin Puppet modules zoekt, in dezelfde volgorde als in je environment. |

Het script start `bundle exec puppet-lint` vanuit de hoofdmap van de moduleverzameling en geeft de volledige paden naar je eigen manifests mee. Die werkmap is nodig om de plugins te laden: de `--load`-paden in `.puppet-lint.rc` worden vanaf de werkmap gelezen. Alleen `--config global-modules/.puppet-lint.rc` meegeven vanuit je eigen project is daarom niet voldoende.

```ruby
#!/usr/bin/env ruby

project_root = File.expand_path('..', __dir__)
lint_root = File.realpath(File.join(project_root, 'global-modules'))
source_dirs = ['manifests', 'modules/profile/manifests']
module_dirs = [File.join(project_root, 'modules'), lint_root]

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
  'BUNDLE_PATH' => File.join(project_root, '.cache/puppet-lint'),
  'BUNDLE_IGNORE_CONFIG' => '1',
  'BUNDLE_FROZEN' => 'true',
  'BUNDLE_VERSION' => 'system',
  'PROJECT_LINT_MODULEPATH' => module_dirs.join(File::PATH_SEPARATOR),
)
puts "Puppet-lint: #{files.length} own manifests in #{project_root}"
$stdout.flush
Dir.chdir(lint_root)
exec('bundle', 'exec', 'puppet-lint', '--no-config', '--config', '.puppet-lint.rc', '--ignore-paths=', *files)
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

Het script gebruikt met `--no-config --config .puppet-lint.rc` alleen de centrale lintconfiguratie. Instellingen van het systeem, je persoonlijke instellingen en een eigen `.puppet-lint.rc` worden overgeslagen. `--ignore-paths=` vervangt alleen de bestandsuitsluitingen van de moduleverzameling: je hebt de te controleren bestanden al met `source_dirs` gekozen. De lintregels blijven gelijk.

Deze scan controleert alleen `.pp`-bestanden. YAML, templates, documentatievoorbeelden en bestanden die zelf een symlink zijn vragen aparte controles. De optie `--relative` in de centrale configuratie gaat over de indeling van modules; foutmeldingen blijven het volledige bestandspad tonen.

Je kunt het script ook vanuit een andere werkmap starten. Geef dan het volledige pad naar `.tools/lint.rb` op. Het optionele manifestpad blijft gerekend vanaf de hoofdmap van je project. Geef geen extra lintopties mee en voeg geen eigen lintregels toe.

### Aanroepen van modules controleren

De check `project_interface_calls` controleert of je bij een aanroep de verplichte parameters meegeeft. Daarvoor moet de linter de class of het defined type kunnen vinden. Geef in `module_dirs` de mappen op waarin Puppet daadwerkelijk modules zoekt, in dezelfde volgorde als in je environment.

Het voorbeeld zoekt eerst in je eigen `modules/` en daarna in `global-modules/`. Wissel die volgorde als Puppet de gedeelde modules eerst gebruikt. Voeg ook de gebruikte modulemappen onder `environments/` en de mappen met modules van derden toe. Die modules moeten aanwezig blijven om aanroepen te kunnen controleren, ook als je hun code niet met `source_dirs` op stijl laat controleren.

Geef volledige, bestaande paden op. Vervang `$codedir`, `$basemodulepath` en relatieve paden door de overeenkomstige mappen op je eigen computer of CI-runner. De linter leest geen `environment.conf` en haalt geen instellingen van productieservers op. Gebruiken je environments verschillende modulepaden, controleer de code dan per environment met de bijbehorende paden. Eén gecombineerde lijst kan een andere versie van een module kiezen dan Puppet op de server.

Het script geeft `module_dirs` via `PROJECT_LINT_MODULEPATH` aan de check door. Op macOS en Linux worden de paden gescheiden door `:`. Spaties zijn toegestaan; een `:` in een mapnaam niet. Een leeg, relatief of niet-bestaand modulepad geeft een fout. Zonder deze variabele zoekt de check alleen in de gedeelde moduleverzameling, waarbij `concat`, `debconf`, `reboot`, `stdlib` en `timezone` worden overgeslagen. Afzonderlijke eigen modules worden dan niet gevonden.

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
| `bundle exec puppet-lint .` en `bundle exec rake spec` vanuit de gedeelde checkout, met de bijbehorende gems | De modules en linter van die repository, inclusief voorbeelden, syntaxis en gedrag. Deze tests controleren niet automatisch je eigen projectcode. |
| De eigen parser-, metadata-, template-, catalogus- en gedragstests | Je eigen project, met de Puppet- of OpenVox-versie, facts, Hiera en modulepaden die je daarvoor wilt gebruiken. |

Controleer gewijzigde manifests ook rechtstreeks met de Puppet-parser. Voer dit voorbeeld uit vanuit de hoofdmap van je eigen project. Het gebruikt de eerder geïnstalleerde gems van de moduleverzameling. Vervang `global-modules` en het manifestpad waar nodig.

```sh
(
  export BUNDLE_GEMFILE="$PWD/global-modules/Gemfile"
  export BUNDLE_PATH="$PWD/.cache/puppet-lint"
  export BUNDLE_IGNORE_CONFIG=1 BUNDLE_FROZEN=true BUNDLE_VERSION=system
  bundle exec puppet parser validate modules/profile/manifests/init.pp
)
```

Heeft je project een eigen gemomgeving voor tests, blijf die daarvoor gebruiken. Compileer catalogi in een aparte testomgeving met nagebootste facts, Hiera en inloggegevens. De linter past geen catalogi toe en heeft geen productiegeheimen of verbindingen met beheerde servers nodig.

### Controle in CI

Met onderstaande GitHub Actions-workflow voer je dezelfde lintscan uit als op je eigen computer. Neem de lintstappen op in je bestaande workflow of gebruik `.github/workflows/puppet-lint.yml`. De commando's starten vanuit de hoofdmap van je project. Zorg dat je bestaande checkoutstappen de moduleverzameling daar onder `global-modules/` klaarzetten voordat de lintstappen beginnen.

Pas `global-modules` in de installatiestap aan als je een ander pad gebruikt. De te controleren bestanden stel je alleen in `.tools/lint.rb` in. De workflow stopt bij lintfouten, ontbrekende plugins of uitvoeringsfouten. Voeg de eigen syntax- en gedragstests als aparte stappen of jobs toe.

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
          export BUNDLE_PATH="$PWD/.cache/puppet-lint"
          export BUNDLE_IGNORE_CONFIG=1 BUNDLE_FROZEN=true BUNDLE_VERSION=system
          bundle install
      - name: Check all own manifests
        run: ruby .tools/lint.rb
```

### Problemen oplossen

| Probleem | Controle en herstel |
| --- | --- |
| Bundler mist gems of gebruikt de verkeerde Ruby | Controleer `ruby --version`, `command -v ruby` en `command -v bundle`. Voer het installatieblok opnieuw uit met de nieuwste stabiele Ruby en dezelfde Gemfile en installatiemap. Laat een foutieve lockfile niet tijdens de installatie bijwerken. |
| `cannot load such file` voor `.tools/lint/...` | Controleer of de checkout volledig is en of `lint_root` klopt. Het script moet Puppet-lint vanuit de hoofdmap van de moduleverzameling starten. |
| De projectchecks lijken niet actief | Gebruik het commando onder deze tabel om de checks te bekijken. Voer daarna ook de proef met een bekende fout uit. |
| Een scan slaagt terwijl eigen code fout is | Controleer het gemelde aantal bestanden en `source_dirs`. Gebruik `ruby .tools/lint.rb`; een losse `bundle exec puppet-lint .` vanuit `global-modules` controleert alleen de moduleverzameling. |
| Er worden geen manifests gevonden of een bestand wordt geweigerd | Controleer de mappen in `source_dirs` en geef het manifestpad op vanaf de hoofdmap van je project. Voeg geen bestanden van derden toe om de scan toch te laten slagen. |
| Een onjuiste aanroep geeft geen melding | Controleer `module_dirs`, de volgorde van de modules en de plaats van het manifest. Test aanroepen die de linter niet kan beoordelen met je eigen catalogustests. |

Bekijk de beschikbare checks vanuit de hoofdmap van de moduleverzameling, bijvoorbeeld `global-modules/`. Gebruik daarbij dezelfde `BUNDLE_*`-instellingen als in het installatieblok, met volledige paden naar de Gemfile en de installatiemap in je eigen project:

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --list-checks
```

De uitvoer moet de `project_*`-checks bevatten. Controleer bij de eerste inrichting ook of de linter fouten in je eigen code vindt. Voer deze proef uit vanuit de hoofdmap van je eigen project:

1. Maak tijdelijk `manifests/lint_probe.pp` met de inhoud `$values = concat([1], [2])`.
2. Voer `ruby .tools/lint.rb manifests/lint_probe.pp` uit. Dit moet slagen.
3. Vervang de inhoud door `$values = [1] + [2]` en voer hetzelfde commando opnieuw uit. Je moet nu een foutcode krijgen en `project_arrays` bij je eigen bestand zien.
4. Verwijder het tijdelijke bestand. Bewaar opzettelijk ongeldige testbestanden alleen buiten de mappen die je op stijl controleert.

De tests van de gedeelde linter voeren het script uit deze handleiding ook uit in een apart voorbeeldproject. Ze controleren onder meer een genest pad met spaties en het overslaan van persoonlijke lintinstellingen.

## Versies bijwerken

Gebruik dit wanneer je nieuwe versies van het ontwikkelgereedschap wilt ophalen:

```sh
gem install bundler
BUNDLE_VERSION=system bundle update --all
bundle exec puppet-lint .
bundle exec rake spec
git diff -- Gemfile.lock
```

[`bundle update --all`](https://bundler.io/man/bundle-update.1.html) kiest de nieuwste stabiele gems die onderling en met de ingestelde Ruby-versie passen. Gems kunnen zelf beperkingen aan hun afhankelijkheden stellen. Controleer de gewijzigde lockfile en eventuele codeaanpassingen voordat een mens ze commit. `bundle install` blijft daarna die geteste combinatie gebruiken. Gebruik geen prereleases voor de gewone ontwikkelomgeving.

Werk op macOS Ruby bij met `brew update` en `brew upgrade ruby`. Open daarna een nieuwe terminal, zodat ook het pad voor gemcommando's opnieuw wordt bepaald, en installeer de gems opnieuw. Draai na een Ruby-update de volledige lintscan en testsuite. De ontwikkelversie zegt niets extra's over ondersteunde Puppet- of OpenVox-versies op beheerde servers; controleer daarvoor de modulemetadata en de project-README.

## Werking van de controles

Puppet-lint laadt de eigen plugins via `--load`. Alle standaardchecks blijven actief, ook wanneer een update nieuwe checks toevoegt. Daarnaast is `class_inherits_from_params_class` ingeschakeld. Een ontbrekende plugin of een lintwaarschuwing laat het commando mislukken. De uitvoer vermeldt bestand, regel, kolom en checknaam. Met `bundle exec puppet-lint --json .` krijg je JSON-uitvoer.

De [CLI](https://puppetlabs.github.io/puppet-lint/) leest eerst de systeemconfiguratie, daarna je persoonlijke instellingen en ten slotte de repositoryconfiguratie. Expliciete CLI-opties gaan voor. Als je persoonlijke instellingen bijvoorbeeld automatisch repareren inschakelen, kun je uitsluitend de projectconfiguratie gebruiken:

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
```

De volledige scan vindt nieuwe manifests en bestanden in `examples/` automatisch. De vijf meegeleverde Git-submodules worden niet op onze stijl gecontroleerd. De tests vergelijken hun paden uit `.gitmodules` met de Git-index en de lintuitsluitingen. Geïnstalleerde gems en bewust ongeldige testfixtures blijven eveneens buiten de gewone scan.

ERB-templates met een YAML-extensie worden niet als ruwe YAML gecontroleerd: ze worden pas geldige YAML na het renderen. De tests controleren hun templatesyntaxis wel. Puppet-voorbeelden in Strings en Markdown, inclusief deze verborgen `.tools`-map, worden met dezelfde lintchecks en Puppet-parser gecontroleerd.

De tests roepen bestaande validators rechtstreeks aan: `puppet parser validate`, `metadata-json-lint`, Ruby met `-c` en de gebruikte shell met `-n`. Catalogustests gebruiken nagebootste Debian- en Ubuntu-facts en passen geen catalogi toe. Monitoringtests gebruiken gecontroleerde vervangers voor servicecommando's en benaderen geen beheerde hosts. Je hebt geen historische checkout, migratiescript of fixturegenerator nodig.

[De CI-workflow](../../.github/workflows/lint.yml) kiest met `ruby-version: ruby` de nieuwste stabiele Ruby en voert dezelfde installatie, lintscan en tests uit. `BUNDLE_FROZEN=true` voorkomt dat een afwijking tussen Gemfile en lockfile stilzwijgend wordt bijgewerkt. Met `BUNDLE_PATH` kun je gems lokaal bijvoorbeeld in `vendor/bundle` installeren. CI heeft alleen leesrechten, bewaart geen checkoutcredentials en maakt geen wijzigingen of commits.

De Actions gebruiken de versietags [`actions/checkout@v7`](https://github.com/actions/checkout) en [`ruby/setup-ruby@v1`](https://github.com/ruby/setup-ruby). Die volgen updates binnen hun hoofdversie. Een nieuwe hoofdversie moet apart in de workflow worden gekozen. Bundler wordt rechtstreeks met `gem install bundler` geïnstalleerd. Een update binnen deze versies kan daardoor invloed hebben op een volgende CI-run zonder dat onze workflow is aangepast.

## Beschikbare projectchecks

| Check | Wat wordt gecontroleerd? |
| --- | --- |
| `project_parameter_order` | Verplichte parameters eerst, optionele daarna, alfabetisch binnen elke groep. Een echte afhankelijkheid van een eerdere default mag de volgorde bepalen en moet worden toegelicht. |
| `project_parameter_alignment` | Typen, namen, `=`-tekens en defaults staan over het volledige parameterblok uitgelijnd, ook bij geneste typen en waarden over meerdere regels. |
| `project_documentation` | Classes en defined types hebben een samenvatting, voorbeeld, API-markering en parameterdocumentatie in dezelfde volgorde. Willekeurig afgebroken documentatiezinnen worden gemeld. |
| `project_layout` | Er staat één spatie na komma's op dezelfde regel en een afsluitende komma in parameterlijsten over meerdere regels. De bestaande trailing-comma-plugin controleert resources en verzamelingen. |
| `project_packages` | APT-installaties gebruiken de afgesproken opties, rekening houdend met verwijderresources, providers en lokale defaults. Bij samengestelde opties moeten de voorgeschreven opties achteraan blijven staan. |
| `project_files` | Eigenaars en modi zijn expliciet, recursieve modi maken bestanden niet onnodig uitvoerbaar en `source` en `content` sluiten elkaar aantoonbaar uit. Overgeërfde of onopgeloste waarden kunnen extra cataloguscontrole vragen. |
| `project_arrays` | Arrays worden niet met `+` samengevoegd. Optelling van getallen en hashes blijft toegestaan. |
| `project_templates` | Templates gebruiken ERB. EPP-aanroepen worden gemeld; tekst en commentaar mogen EPP wel noemen. |
| `project_positive_flow` | Een guard begint niet met een fouttak wanneer de andere tak het eigenlijke werk bevat. De check beoordeelt niet iedere validatie- of normalisatietak. |
| `project_shell` | Dynamische exec-commando's en guards gebruiken waarden die via `stdlib::shell_escape` zijn voorbereid. Alleen een naam met `_shell` is geen bewijs van veilige escaping. |
| `project_interface_calls` | Aanroepen passen bij de declaratie in dezelfde bron of het eigen autoloadpad. Verplichte `Optional[...]`-argumenten blijven verplicht. Splat, defaults en containment vragen daarnaast catalogustests. |
| `project_suppressions` | Alleen gerichte `140chars`-uitzonderingen zijn toegestaan. Andere lintfouten moeten worden hersteld. |

Gebruik twee spaties voor inspringing, uitgelijnde pijlen en enkele aanhalingstekens voor letterlijke strings. Dubbele aanhalingstekens zijn nodig voor interpolatie of escapes. Houd de volgorde van resources en gegenereerde configuratie bewust en controleerbaar. Bereken selectors vóór de resourcedeclaratie.

De projectchecks voor documentatie en parametervolgorde vullen de standaardchecks aan. Puppet-lint laat de optionele checks voor 80 tekens, booleans tussen aanhalingstekens en code op hoofdniveau standaard uitgeschakeld. Dat past bij onze 140-tekengrens, daemonstrings zoals `'true'` en uitvoerbare profielen. Schakel geen correcte check uit om bestaande code niet te hoeven herstellen en maak geen uitzonderingslijst voor oude modules of stijlachterstand.

## Lange regels

De `140chars`-check blijft aan. Zet achter iedere bewust langere Puppet-regel `# lint:ignore:140chars`. Dit geldt ook voor lange URL's en templateaanroepen die Puppet-lint zelf al uitzondert. Plaats de markering buiten stringwaarden. Staat er al commentaar achter de code, zet dan de markering direct na de `#`, vóór de bestaande toelichting.

Rond een lange commentaarregel, of een reeks lange commentaarregels, gebruik je `# lint:ignore:140chars` en `# lint:endignore`. Sluit het blok vóór de volgende korte regel. Zo blijft een commentaarzin leesbaar op één regel en blijven andere checks actief. Bekijk deze meldingen met `bundle exec puppet-lint --show-ignored .`.

Zet nooit lintmarkeringen in gegenereerde strings of heredoc-inhoud. Heeft een waarde over meerdere regels een uitzondering nodig, plaats dan het kleinst mogelijke blok buiten de waarde. Puppet-code die uit een documentatievoorbeeld wordt gehaald heeft een eigen markering nodig wanneer die code boven 140 tekens komt.

## Parameters en resources

### Parameters en instellingen

Houd classes en defined types klein genoeg om ze los of samen te gebruiken. Geef publieke parameters een expliciet datatype: een passend ingebouwd type of een typealias. Verplichte parameters hebben geen default en geen buitenste `Optional[...]`; optionele parameters hebben ten minste één daarvan. `Optional[...]` zonder default staat dus bij de optionele parameters, maar je moet de waarde bij een aanroep nog steeds meegeven. Voeg geen default toe alleen om de sortering te veranderen.

Begin namen met het onderwerp en zet nadere aanduidingen achteraan, zoals `bandwidth_max`, `p95_warning` en `secret_key_fallback`. Gebruik snake_case. Laat een naam alleen met een cijfer beginnen als dat op alle ondersteunde runtimes is getest. Moet een default een eerdere parameter lezen, licht die afwijkende volgorde dan toe achter de parameter.

Gebruik voor een beveiligingsinstelling met een veilige default, uitschakelmogelijkheid en eigen waarde één `Variant[Boolean, String]` of een passende beperkte scalarvariant. Daarbij kiest `true` de veilige default, laat `false` de uitvoer weg en geeft een scalar de eigen waarde. Bereken de uitkomst eenmaal in een duidelijke `*_correct`-variabele voor de template. Splits dit alleen in enable/custom/value-parameters wanneer compatibiliteit dat vereist.

### Voorwaarden en validatie

Zet het eigenlijke werk in de positieve tak: resources maken, een aanwezige waarde verwerken of invoer normaliseren. Zet fouten, waarschuwingen en eenvoudige terugvalwaarden in de laatste `else`. Een defined type dat een parentclass nodig heeft controleert `defined(Class['...'])`, houdt alle afhankelijke code binnen die geldige tak en faalt duidelijk als de class ontbreekt. Gebruik een benoemd `defined(...)`-resultaat opnieuw wanneer je het vaker nodig hebt.

Valideer een optionele instelling alleen wanneer deze wordt uitgevoerd of in gegenereerde configuratie wordt overgenomen. Een niet-ingestelde optionele waarde is geen fout. Laat de validatie één korte benoemde foutmelding of `undef` opleveren, maak resources in de geldige tak en faal in de laatste `else`. Plaats geen losse `fail(...)` halverwege de opbouw van waarden of resources. Een template mag de ruwe parameter gebruiken om te bepalen of een lokale regel nodig is, maar schrijft de berekende waarde wanneer overerving geldt.

### Resources en afhankelijkheden

Gebruik één resource met vooraf berekende `undef`-attributen wanneer alleen optionele attributen verschillen. Zorg dat `source` en `content` niet tegelijk gevuld kunnen zijn. Deel een buitenste guard wanneer meerdere resources dezelfde voorwaarde hebben en houd eigen controles daarbinnen. Combineer arrays met `concat(...)`. Een eenmalig gebruikte lokale variabele moet betekenis toevoegen of de code duidelijker maken.

Een `defined(...)`-controle ziet alleen wat tijdens evaluatie al bekend is, niet de toekomstige eindcatalogus. Koppel `require` daarom pas na een geslaagde controle aan een geaccepteerde resource of gedocumenteerd anker. Levert een wrapper de afhankelijkheid, controleer dan achtereenvolgens de directe resource, de wrapper en de parentwrapper. Bouw geen paden, poorten, bestandsnamen of unitnamen van een andere bouwsteen opnieuw op als een resource, alias, servicetitel of geaccepteerde API die waarde beschikbaar maakt. Test de daadwerkelijke afspraak tussen beide resources.

Voeg geen ongedocumenteerde gemaksparameters toe nadat een interface-uitbreiding is afgewezen. Gebruik de geaccepteerde interface of stabiele externe runtimemetadata.

### Volgorde en meldingen

Behoud expliciete `require`-, `notify`- en `subscribe`-relaties. Zoek bij een cycle uit welke catalogusrelatie of containment die veroorzaakt en herstel die relatie bij de bron. Vervang haar niet door een los `systemctl`-, `service`- of reloadcommando. Behoud meldingen zoals `notify => Service['nginx']` en koppel brede ordering waar nodig aan een kleinere stabiele resource.

Houd monitoring en audit bij de bijbehorende resource. Monitoringspecifieke configuratie hoort bij de monitoringsectie van het manifest, behalve wanneer het bestand de daemon zelf configureert.

## Commentaar en documentatie

Schrijf codecommentaar in het Engels. Leg uit waarom de code nodig is, welke beperkingen gelden en welke gevolgen de code heeft. Herhaal niet alleen wat de volgende regel doet. Houd één zin op één fysieke regel; gebruik aparte regels voor echte lijsten, voorbeelden en syntaxis. Verwijder willekeurige regelafbrekingen in nabij commentaar dat je raakt.

Geef bij niet-vanzelfsprekende resourcegroepen, execs, afgeleide waarden, voorwaardelijke directives, gedelegeerde resources en opruimroutes een korte toelichting. Doe hetzelfde bij helpers en templatelogica. Benoem waar nodig de invoer, uitvoer of gevolgen voor exitcodes. Dat is vooral nuttig bij escaping, parsing, classificatie, samenvoegen van resultaten, terugvalgedrag en uitvoeropbouw.

Verdeel lange reeksen defaults, drempels, statuswaarden, tellers, paden, rechten, commando's en relaties in herkenbare groepen. Vergelijk geraakt commentaar met goed gedocumenteerde bestaande code en verwijder verouderde, dubbele of overbodige uitleg. Kopieer geen projectbeleid naar implementatiecommentaar.

### Puppet Strings

Documenteer elke publieke class en elk publiek defined type direct boven de declaratie. Voeg een eenregelige `@summary`, één `@param` per parameter in declaratievolgorde en een eenvoudig uitvoerbaar `@example` toe. Markeer nieuwe classes, defined types en functies als publieke of private API.

Beschrijf wat een parameter betekent, hoe de default werkt en wat bijzondere waarden zoals `undef`, `true` en `false` doen. Neem beperkingen, afhankelijkheden, gegenereerde resources, terugvalgedrag en gevolgen voor beveiliging of compatibiliteit mee. De linter controleert de aanwezigheid en volgorde van tags; beoordeel zelf of de uitleg klopt en volledig is.

### Waar de uitleg hoort

De project-README beschrijft het basisgebruik en wat beheerders vóór gebruik moeten weten. Puppet Strings beschrijven de interfaces. Uitgebreide combinaties horen in `examples/`, en lokale implementatieafspraken blijven bij het script of de template. Deze README en de project-README zijn Nederlands; overige technische documentatie is Engels.

Houd één volledige bron voor elk technisch gegeven. Dupliceer geen complete parameterreferenties of grote voorbeelden. Maak geen handmatige `REFERENCE.md` of `docs/`-boom voor informatie die Puppet Strings kan genereren. Voeg alleen een ADR toe wanneer dat is gevraagd of al gebruikelijk is.

Hergebruik waar mogelijk een bestaand voorbeeldscenario. Voorbeelden moeten uitvoerbaar zijn met de genoemde voorwaarden en alleen de nodige parameters tonen. Gebruik `example.org`, documentatieadressen en `replace-with-...`-waarden. Gebruik `Sensitive(...)` waar het datatype dat ondersteunt en afgeschermde Hiera voor oude String-interfaces; neem geen organisatiegegevens op.

Werk bij een wijziging de geraakte voorbeelden en documentatie mee bij. Vergelijk Strings, defaults, relaties en gegenereerde configuratie met het manifest. Verandert monitoringgedrag voor beheerders, controleer dan ook het checkoverzicht in de project-README.

## Bestanden en beveiliging

### Templates en bestandsbronnen

Render met ERB via `template(...)`. Gebruik één template als bestanden alleen in een klein optioneel onderdeel verschillen. Splits ze wanneer formaat of verantwoordelijkheid wezenlijk anders is. Lever statische bestanden via `puppet:///modules/...`; bronvalidatie moet `puppet:///` toestaan wanneer modulebestanden geldige invoer zijn. Houd paden en titels voorspelbaar en test de gerenderde varianten bij hun werkelijke gebruiker.

### Pakketten en mappen

APT-installaties eindigen met `['--no-install-recommends', '--no-install-suggests']`, tenzij een concreet pakket een afwijking nodig heeft. Gebruik `concat(...)` om deze opties achter aangeleverde opties te zetten. Deduplicatie met `union(...)` garandeert niet dat de voorgeschreven opties achteraan blijven staan.

Gebruik recursieve purge, force en recurse alleen voor mappen die volledig van de module zijn. Behoud `replace => false` op bestanden die een installer of eenmalige initialisatie aanmaakt. Geef een gemengde boom niet recursief uitvoerrechten: beheer mappen en gewone bestanden apart. Een private boom zonder uitvoerbare bestanden mag recursief `0600` gebruiken; Puppet voegt zoekrechten toe aan de mappen. Gebruik voor geëxporteerde applicatiebomen normaal `0750` voor mappen en `0640` voor bestanden, tenzij de applicatie aantoonbaar andere rechten nodig heeft.

### Eigenaars en rechten

Controleer wie een bestand tijdens uitvoering moet lezen of schrijven en welke bovenliggende mappen bereikbaar moeten zijn. Stel eigenaars, groepen en modi expliciet in. Houd geheimen en gevoelige configuratie buiten bereik van andere gebruikers. Gebruik als uitgangspunt:

| Bestand of map | Gebruikelijke rechten |
| --- | --- |
| Private configuratie | `0600` |
| Script dat alleen root uitvoert | `0700` |
| Sudoersfragment | `0440` |
| Systemd-unit | `0644` waar systemd dat nodig heeft |
| Statisch terugvalbestand voor een service | Root als eigenaar, de servicegroep en `0640`; zo nodig `0710` voor bovenliggende mappen |

Houd SSH-homes en `.ssh` privé. Geef uitvoerrechten alleen aan uitvoerbare bestanden. Leg wereldleesbare of groepsschrijfbare toegang uit. Een publiek bereikbaar HTTP-bestand hoeft lokaal niet voor iedereen leesbaar te zijn. Linux-symlinks vereisen expliciet eigenaarschap, maar hebben geen afzonderlijk bruikbare chmod-modus; beveilig hun doelen.

Controleer sudo-, logrotate-, audit-, monitoring- en servicepaden tegen de echte uitvoeringsidentiteit. Gebruik waar nodig `Sensitive[...]` of `Sensitive.new(...)` voor gevoelige inhoud en commando's, zodat die niet via rapporten uitlekken.

### Shellcommando's in Puppet

Interpoleer geen ruwe Puppet-waarden in exec-commando's, `onlyif` of `unless`. Bereid dynamische shellwoorden voor met `stdlib::shell_escape(...)`, noem ze `*_shell` en gebruik ze zonder extra aanhalingstekens als shellwoord. Escape runtimevariabelen en substituties in dubbele Puppet-strings, zoals `\$tmpdir`, `\$1` en `\$(...)`.

Elke echte shellparserlaag heeft één quotinggrens nodig. Een script opgebouwd uit ge-escapete woorden krijgt zelf eenmaal quoting als buitenste `-c`-argument; escape dezelfde laag niet dubbel. Een statisch script mag eenmaal als geheel worden ge-escapet. Test samengestelde commando's met letterlijke waarden die spaties, aanhalingstekens en shelltekens bevatten. Dat een waarde ge-escapet is, bewijst nog niet dat ze op de juiste plaats in het commando wordt gebruikt.

Behoud afsluitende SQL-puntkomma's. Escape de hele SQL-string en gebruik `provider => shell` wanneer puntkomma's of guards anders als aparte commando's worden gelezen. Gebruik bij voorkeur `/usr/bin/printf %s ${value_shell}` voor dynamische inhoud. Bewust voorbereide regeleinden mogen als letterlijke `\n` worden vastgelegd, eenmaal ge-escapet en met `printf %b` worden gedecodeerd. Gebruik voor willekeurige gebruikers- of runtime-inhoud over meerdere regels een bestand of template.

### Afhankelijkheden, audit en transport

Gebruik bij voorkeur de bestaande lokale modules. De runtimeafhankelijkheden blijven beperkt tot `stdlib`, `concat`, `reboot`, `timezone` en `debconf`, tenzij een eis aantoonbaar niet goed lokaal kan worden ingevuld. Voeg geen externe Docker-, MySQL-, Nginx- of RabbitMQ-module toe alleen omdat die vergelijkbare functies heeft. Beoordeel bij nieuwe gevoelige onderdelen ook pakketbeleid, integratie, monitoring en audit.

Leg bij gewijzigde audituitzonderingen uit welk legitiem gedrag wordt uitgezonderd, welke events verdwijnen en waar de uitzondering geldt. Controleer naburige uitzonderingen op overlap.

Reverse proxies en verbindingen tussen services gebruiken standaard versleuteling. HTTP is een expliciete gedocumenteerde keuze voor een upstream zonder TLS. Certificaatproblemen zijn geen reden om versleuteling uit te schakelen. Gebruik bij lokale of self-signed upstreams versleuteling met een bewust afgebakende keuze voor vertrouwen en verificatie. Licht een minder streng vertrouwens-, rechten- of sandboxmodel bij de code toe, en ook in de project-README als beheerders dat vooraf moeten weten.

## Gedeelde services en systemd

`basic_settings` beheert de gedeelde serverbasis: pakketten en APT-bronnen, systemd, monitoring, loginbeleid, beveiligingsgereedschap, pakketonderhoud, kernel, netwerk, tijdzone en Puppet-runtimegedrag. Laat andere modules hierop aansluiten.

Gebruik de bestaande bouwstenen `basic_settings::systemd_target`, `systemd_drop_in`, `systemd_service`, `systemd_timer`, `systemd_network`, `monitoring_service`, `monitoring_custom`, `monitoring_timer`, `monitoring_npm_audit`, `security_audit`, `io_logrotate` en `login_sudo` voor hun eigen taken.

### Targets en monitoring

Behoud de targetladder `${cluster_id}-system`, `${cluster_id}-storage`, `${cluster_id}-services`, `${cluster_id}-production`, `${cluster_id}-helpers` en `${cluster_id}-require-services`. Een geïntegreerde service schakelt vendor-enablement uit, gebruikt de gedeelde drop-in-wrapper en bindt aan het passende target. Bij actieve monitoring wordt `OnFailure=notify-failed@%i.service` toegevoegd.

Controleer bij een wijziging zowel gegenereerde units als lokale wrappers, vendor-drop-ins, directe Service-resources, templates en statische units. Rapporteer de uiteindelijke beoordeelde unitnamen alfabetisch.

Monitoring gebruikt het centrale OpenITCOCKPIT-agentmodel. Plugins staan onder `/etc/openitcockpit-agent/plugins`. Bouw `customchecks.ini` met `concat` en `concat::fragment` en laat de gedeelde monitoringtypes services, timers en eigen checks registreren. Dupliceer die registratie niet in featuremodules.

### Servicebeveiliging

Beoordeel beveiligingsopties per concrete `.service`, ook bij de service achter een timer, socket of path. Service-uitvoeringsopties horen niet in targets, mounts, sockets, timers of daemonconfiguratie van journald, resolved en timesyncd.

Bepaal eerst de uiteindelijke unit en de bijbehorende Puppet-code of template. Loop daarna alle Exec-fasen na: gebruikers, groepen en aanvullende groepen, capabilities, sudo/setuid, schrijfbare paden, bestanden, sockets, logs, tijdelijke opslag, apparaten, hometoegang, credentials, netwerk en pakketgedrag. Neem ook de runtime, plugins, JIT/VM's en procesinspectie mee.

Leg per kandidaat vast of je deze toepast, niet toepast of nader onderzoekt, met een reden. Een bekende native oneshot zonder bijzondere afhankelijkheden is eenvoudiger te beoordelen dan provisioning, pakketbeheer, Puppet, GitLab omnibus, Certbot-hooks, SSH-sessies, monitoringexecutors, OpenITCOCKPIT of back-up- en herstelsoftware. Gedeelde bestanden, apparaten, capabilities, JIT/plugins en helpers die privileges wijzigen vragen extra aandacht. Kies een gerichte uitzondering wanneer een optie de service zou breken.

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

Zet `UMask=0077` voor private uitvoer expliciet in de servicespecifieke hash bij de sandboxinstellingen. Laat de instelling weg als het normale `0022`-gedrag nodig is. Licht een afwijkend gedeeld masker zoals `0027` bij de service toe. Verberg geen masker of andere beveiligingsdefault in een generieke wrapper. Controleer bij gewijzigde wrapperbeveiliging iedere bekende gebruiker; valideer die of geef per service een gedocumenteerde uitschakelmogelijkheid.

## Shellscripts en monitoring

### Opbouw van een check

Nieuwe scripts en templates gebruiken POSIX `#!/bin/sh`, tenzij Bash-functies nodig zijn. Monitoringchecks blijven POSIX en gebruiken Nagios-exitcodes. Gebruik daarin geen arrays, `[[ ... ]]`, `(( ... ))`, `function`, process substitution, here-strings, `pipefail`, `read -d` of Bash-specifieke expansies.

`mysql/files/automysqlbackup` blijft een Bash-uitzondering vanwege arrays, indirecte expansie en rekenkundige lussen. Raak je een Bash-script, verklaar dan waarom Bash nodig blijft.

Bekijk vóór een nieuwe of gewijzigde check de meest verwante bestaande checks. Volg hun volgorde, helpers, statusverwerking, parsing, ernstbepaling, buffering, afkappen en perfdata. Wijk alleen af als het bestaande patroon niet past en licht dat toe.

Gebruik deze opbouw:

1. Fouthelper.
2. Benodigde binaries zoeken.
3. Defaults.
4. Eén POSIX `while getopts ... opt; do`-blok.
5. Helpers.
6. Hoofdlogica.

Zoek afhankelijkheden rechtstreeks met `COMMAND=$(command -v command 2>/dev/null) || die ...`. Roep `$COMMAND` zonder aanhalingstekens aan op de commandopositie en quote de data-argumenten, tests en toekenningen. Gebruik shellbuiltins rechtstreeks en `printf` in plaats van `echo`.

Geef elke CLI-optie een eigen case-tak met toekenning. Eindig met één usage-/fouttak voor ongeldige opties en hulp, inclusief `-h` wanneer deze is gedeclareerd. Lange uitvoer staat standaard aan; voeg alleen op verzoek schakelaars daarvoor toe.

### Invoer en configuratie

Een check die Puppet-data nodig heeft is een ERB-template met directe shelltoekenningen. Beperk ERB tot variabele-invoeging en Puppet-voorbereiding tot defaults, serialisatie en shellveilige waarden. Voeg alleen een checkconfiguratiebestand of parser toe als dat gevraagd is of al gebruikelijk is.

Geef iedere beheerde waarde één leidende invoerroute. Dupliceer deze niet tussen CLI en configuratie zonder compatibiliteitsreden. Gebruik CLI-opties voor runtimefilters en drempels die niet via configuratie worden beheerd. Lees bij voorkeur de effectieve daemonconfiguratie, zoals `vnstat --showconfig`, in plaats van dubbele opties, sysfs-terugvalroutes of aparte checkinstellingen. Valideer drempelsyntaxis, eenheden, omvang, volgorde en runtimebetekenis in de shellcheck.

### Waarden en helpers

Groepeer defaults, drempels, statuswaarden, tellers, samenvattingen, perfdata, paden, rechten, commando's en relaties met een korte toelichting. Voeg een helper toe wanneer die betekenis geeft aan de taak, validatie of opmaak centraliseert of wezenlijke duplicatie wegneemt. Verpak niet zonder zo'n reden één append, toekenning of printf. Houd eenmalige logica inline wanneer dat duidelijker is en zet inhoudelijke verwerking vóór kleine terugvaltakken.

Gebruik shellvariabelen en printf voor begrensde tellers, perfdata, sorteerbuffers en diagnoses. Gebruik tijdelijke bestanden en mktemp alleen wanneer een commando een bestand vereist of data te groot of onveilig is voor variabelen. Ruim tijdelijke bestanden op. Zet geen letterlijke lege regels in gequote toekenningen; gebruik printf-formaten en ge-escapete regeleinden. Serialiseer lijsten bewust als CSV en metadata van commandosubstitutie met expliciete markeertokens in plaats van regeleindetrucs.

### Uitvoer voor beheerders

De eerste regel moet begrijpelijk zijn zonder de volledige uitvoer te openen. Noem de gecontroleerde service, unit, module, interface of resource. Vermeld bij een fout of onduidelijke uitkomst het belangrijkste geraakte object, de directe oorzaak en of escalatie waarschijnlijk nodig is.

Begin de regel niet met een Nagios-statuswoord en label oorzakenlijsten niet met statusnamen; de exitcode geeft de machinestatus. Meld bij een gezonde check dat het onderdeel normaal werkt. Laat nulcategorieën, drempelinventarissen, beslislabels, beslisredenen en perfdata-achtige fragmenten weg. Gedetailleerde tellers horen in perfdata of lange uitvoer.

Maak onderscheid tussen configuratiefouten, runtimefouten, contextuele waarschuwingen en onbekende of onduidelijke toestanden. Vermeld de reikwijdte van een bewust beperkte check. Informatie buiten die reikwijdte mag de exitcode niet veranderen.

Zet de belangrijkste diagnosesectie eerst. Beschrijf het geraakte onderdeel, de waargenomen toestand, de waarschijnlijke oorzaak en wat een beheerder ermee kan doen. Geef een nuttige vervolgstap of escalatieroute. Verberg de hoofdoorzaak niet in detailuitvoer en zet daar geen drempelwaarden in.

Eindig niet-triviale lange uitvoer met `Interpretation:`. Leg daar feitelijk uit hoe de getoonde gegevens, reikwijdte en context gelezen moeten worden, zonder perfdata te herhalen.

### Veilige en begrensde uitvoer

Onderzoek de echte uitvoerroute voordat je normalisatie toevoegt. Dat is alleen nodig wanneer runtimegegevens, externe data of bewuste scheidingen onveilige pipes of ongewenste lege regels kunnen veroorzaken. Licht een niet-vanzelfsprekende bewerking toe en bewerk vaste veilige tekst niet onnodig.

Maak ruwe `|`-tekens veilig zodra dynamische data de lange uitvoer ingaat. Nagios kan ook op vervolgregels tekst na een pipe als perfdata lezen. Gebruik geen lege regels aan begin of einde en geen opeenvolgende lege regels. Zet precies één lege regel tussen afzonderlijke secties.

Gebruik één configureerbare afkapmethode per diagnoseblok. Stapel geen item-, regel-, blok- en tekenlimieten op dezelfde verzamelde diagnose. Een ander uitvoerkanaal mag een eigen limiet hebben als het niet dezelfde gegevens afkapt. Begrens bij relevante UI-limieten het totale aantal tekens boven `Interpretation:` en zet de afkapmelding vóór die laatste uitleg, zodat de vervolgstap zichtbaar blijft.

Grenzen voor dataverzameling, zoals APT-ophaal-, groeps- en tijdslimieten of het journalvenster van de Puppet-agent, begrenzen extern werk of invoer. Ze begrenzen niet de al verzamelde diagnose. Leg het verschil uit en behoud zichtbare meldingen over afgekorte uitvoer.

### Perfdata en compatibiliteit

Labels beginnen met een kleine letter en gebruiken compacte, stabiele snake_case-namen met alleen kleine letters, cijfers en underscores. Zet eenheden in de UOM (`%`, `B`, `s`, `Mbps`), niet in voor- of achtervoegsels van labels. Gebruik puntkomma's alleen tot en met het laatste ingevulde optionele veld.

Gebruik `c` alleen voor monotone tellers die oplopen tot een reset. Gebruik het niet voor gauges, begrensde aantallen, huidig gebruik, piekwaarden, snelheden of periodetotalen.

Behoud exitgedrag, samenvattingsvorm, perfdatakeys, CLI-opties, gegenereerde paden en registratienamen, tenzij de opdracht expliciet die externe afspraak wijzigt. Leg de operationele reden uit en test gewijzigd gezond, fout- en onbekend gedrag.
