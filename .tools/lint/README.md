# Puppet-lint

Met Puppet-lint controleer je de Puppet-code in dit project. Naast de standaardchecks gebruikt het project eigen checks voor onder meer parameters, documentatie, bestandsrechten en shellcommando's. De [tooltests](../tests/README.md) controleren het gedrag van de linter.

Deze handleiding helpt je de controles te installeren, uit te voeren en meldingen op te lossen. De [naslag](#naslag) beschrijft hoe de controles werken en welke codeafspraken en reviewcriteria gelden. Gebruik je de moduleverzameling in een ander Puppet-project, volg dan [de stappen voor dat project](#de-linter-gebruiken-in-een-ander-puppet-project).

## Inhoudsopgave

- [Benodigde omgeving](#benodigde-omgeving)
- [Installatie](#installatie)
  - [Ruby op macOS](#ruby-op-macos)
  - [Gems installeren](#gems-installeren)
- [Code controleren](#code-controleren)
  - [Een melding oplossen](#een-melding-oplossen)
- [Versies bijwerken](#versies-bijwerken)
- [De linter gebruiken in een ander Puppet-project](#de-linter-gebruiken-in-een-ander-puppet-project)
  - [Benodigdheden](#benodigdheden)
  - [Installatie in je project](#installatie-in-je-project)
  - [Eigen lintconfiguratie](#eigen-lintconfiguratie)
  - [Eigen code controleren](#eigen-code-controleren)
  - [Aanroepen van modules controleren](#aanroepen-van-modules-controleren)
  - [Aanvullende tests](#aanvullende-tests)
  - [Controle in CI](#controle-in-ci)
  - [Problemen oplossen](#problemen-oplossen)
- [Naslag](#naslag)
  - [Werking van de controles](#werking-van-de-controles)
  - [Beschikbare projectchecks](#beschikbare-projectchecks)
  - [Inspringing](#inspringing)
  - [Lange regels](#lange-regels)
  - [Parameters en resources](#parameters-en-resources)
  - [Commentaar en documentatie](#commentaar-en-documentatie)
    - [Puppet Strings](#puppet-strings)
  - [Bestanden en beveiliging](#bestanden-en-beveiliging)
  - [Gedeelde services en systemd](#gedeelde-services-en-systemd)
  - [Shellscripts en monitoring](#shellscripts-en-monitoring)

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

## Code controleren

Voer na de installatie de volgende controles uit vanuit de hoofdmap van deze repository. Herhaal ze na je wijzigingen:

```sh
bundle exec puppet-lint .
bundle exec rake test
git diff --check
```

De lintscan zoekt afwijkingen van de automatische codechecks in de projectcode. `rake test` controleert uitsluitend de tools zelf; de [testhandleiding](../tests/README.md) legt uit hoe je deze tests uitvoert en uitbreidt. Met `git diff --check` controleer je de wijzigingen op whitespacefouten. De afsluitende `.` bij Puppet-lint geeft aan dat de hele repository moet worden gescand; laat die ook staan wanneer je extra CLI-opties meegeeft.

Gebruik tijdens het ontwikkelen `bundle exec rake test:lint` om alleen de lintertests uit te voeren. Op dit moment leveren `test` en `test:lint` dezelfde testselectie op, omdat er alleen voor de linter tooltests zijn. Zodra er tests voor andere tools bijkomen, neemt `test` die automatisch mee.

Controleer ieder gewijzigd Puppet-manifest ook rechtstreeks met de parser:

```sh
bundle exec puppet parser validate path/to/manifest.pp
```

Vervang `path/to/manifest.pp` door het pad van het gewijzigde bestand. Heb je modulemetadata aangepast, controleer dan ook het betreffende bestand:

```sh
bundle exec metadata-json-lint module/metadata.json
```

Vervang `module/metadata.json` door het pad van dat bestand.

Een geslaagde lintscan betekent dat de code aan de automatische checks voldoet. Beoordeel bij gewijzigd gedrag ook wat Puppet op de server gaat doen: welke bestanden veranderen, welke services herstarten en welke rechten of verbindingen nodig zijn. Test een normaal gebruik en een praktisch foutgeval. Raak je een gedeelde bouwsteen, neem dan ook de modules mee die deze gebruiken. Het werkproces en de vereiste review staan in [`AGENTS.md`](../../AGENTS.md).

### Een melding oplossen

Een lintmelding noemt het bestand, de regel, de kolom, de checknaam en de oorzaak. Ook een waarschuwing laat de scan mislukken. De eigen checks vind je op naam onder [Beschikbare projectchecks](#beschikbare-projectchecks); de bijbehorende codeafspraken staan verderop in de naslag. Voor standaardchecks kun je de [uitleg van Puppet-lint](https://puppetlabs.github.io/puppet-lint/#checks) raadplegen.

1. Bekijk de genoemde regel samen met het parameterblok, de resource of het commando waar deze bij hoort.
2. Herstel de oorzaak volgens de betreffende afspraak. Voor een bewust lange regel volg je de gerichte uitzondering onder [Lange regels](#lange-regels). Voor een Puppet-fileservermount volg je de uitleg bij [bestandsbronnen](#templates-en-bestandsbronnen).
3. Voer de volledige lintscan en tests opnieuw uit. Controleer een gewijzigd manifest ook met de parser zoals hierboven beschreven.

Stopt de linter voordat hij code kan controleren, herstel dan eerst de installatie. Controleer bij Ruby- of Bundler-fouten de actieve Ruby en de stappen onder [Gems installeren](#gems-installeren). Bij een ontbrekende plugin moeten de volledige checkout, de geïnstalleerde bundle en de werkmap kloppen. Onder [Werking van de controles](#werking-van-de-controles) lees je welke configuratiebestanden de CLI laadt en hoe je uitsluitend de projectconfiguratie gebruikt.

## Versies bijwerken

Bij de eerste installatie gebruikt Bundler de versies uit de lockfile. Wil je die combinatie bijwerken, voer dan het volgende uit vanuit de hoofdmap van deze repository, met de nieuwste stabiele Ruby actief:

```sh
gem install bundler
BUNDLE_VERSION=system bundle update --all
bundle exec puppet-lint .
bundle exec rake test
git diff -- Gemfile.lock
```

[`bundle update --all`](https://bundler.io/man/bundle-update.1.html) kiest de nieuwste stabiele gems die onderling en met de ingestelde Ruby-versie passen. Gems kunnen zelf beperkingen aan hun afhankelijkheden stellen. Gebruik geen prereleases voor de gewone ontwikkelomgeving.

Controleer de gewijzigde lockfile en eventuele codeaanpassingen in de review. `bundle install` gebruikt daarna steeds die geteste combinatie.

Werk op macOS Ruby bij met `brew update` en `brew upgrade ruby`. Open daarna een nieuwe terminal, zodat ook het pad voor gemcommando's opnieuw wordt bepaald, en volg opnieuw [Gems installeren](#gems-installeren). Draai na een Ruby-update de volledige lintscan en testsuite.

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
| `bundle exec puppet-lint .` vanuit de gedeelde checkout, met de bijbehorende gems | De projectcode van de moduleverzameling volgens de gedeelde lintregels. |
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
| Een scan slaagt terwijl eigen code fout is | Controleer het gemelde aantal bestanden en `source_dirs`. Gebruik `ruby .tools/lint.rb`; een losse `bundle exec puppet-lint .` vanuit `global-modules` controleert alleen de moduleverzameling. |
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

## Naslag

De afspraken in deze naslag vormen samen met [`.puppet-lint.rc`](../../.puppet-lint.rc) en de [projectplugins](lib/puppet-lint/plugins/) de codestandaard. De tabellen helpen je een lintmelding terug te vinden; de overige secties beschrijven ook criteria die je zelf bij de review moet beoordelen. Puppet Strings bij classes en defined types beschrijven hun concrete parameters en gedrag.

Voor de dagelijkse controles kun je terug naar [Code controleren](#code-controleren).

### Werking van de controles

Puppet-lint laadt de eigen plugins via `--load`. Alle standaardchecks blijven actief, ook wanneer een update nieuwe checks toevoegt. Daarnaast is `class_inherits_from_params_class` ingeschakeld. De uitzonderingen die Puppet-lint zelf standaard uit laat staan worden toegelicht bij [Beschikbare projectchecks](#beschikbare-projectchecks).

Voor [bestandsbronnen](#templates-en-bestandsbronnen) draait `project_puppet_urls` naast de standaardcheck `puppet_url_without_modules`. De aanvullende check staat in de beheerde plugin `resources.rb`; geïnstalleerde gems worden niet aangepast.

Een ontbrekende plugin of een lintwaarschuwing laat het commando mislukken. De uitvoer vermeldt bestand, regel, kolom en checknaam. Met `bundle exec puppet-lint --json .` krijg je JSON-uitvoer.

De [CLI](https://puppetlabs.github.io/puppet-lint/) leest eerst de systeemconfiguratie, daarna je persoonlijke instellingen en ten slotte de repositoryconfiguratie. Expliciete CLI-opties gaan voor. Als je persoonlijke instellingen bijvoorbeeld automatisch repareren inschakelen, kun je uitsluitend de projectconfiguratie gebruiken:

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
```

De volledige scan vindt nieuwe manifests en bestanden in `examples/` automatisch. De vijf meegeleverde Git-submodules worden niet op onze stijl gecontroleerd. De tooltests vergelijken de lintuitsluitingen met de Git-index. Geïnstalleerde gems blijven eveneens buiten de gewone scan. De lintertests maken hun ongeldige invoer tijdelijk buiten de repository aan.

ERB-templates met een YAML-extensie worden niet als ruwe YAML gecontroleerd: ze worden pas geldige YAML na het renderen. Controleer gewijzigde templates daarom afzonderlijk. Valideer ook Puppet-voorbeelden in Strings en Markdown met de lintregels en de Puppet-parser; de lintscan leest deze voorbeelden niet uit de documentatie.

[De CI-workflow](../../.github/workflows/lint.yml) kiest met `ruby-version: ruby` de nieuwste stabiele Ruby en voert dezelfde installatie, lintscan en tooltests uit. `BUNDLE_FROZEN=true` voorkomt dat een afwijking tussen Gemfile en lockfile stilzwijgend wordt bijgewerkt. Met `BUNDLE_PATH` kun je gems lokaal bijvoorbeeld in `vendor/bundle` installeren.

CI heeft alleen leesrechten, bewaart geen checkoutcredentials en maakt geen wijzigingen of commits.

De Actions gebruiken de versietags [`actions/checkout@v7`](https://github.com/actions/checkout) en [`ruby/setup-ruby@v1`](https://github.com/ruby/setup-ruby). Die volgen updates binnen hun hoofdversie. Een nieuwe hoofdversie moet apart in de workflow worden gekozen. Bundler wordt rechtstreeks met `gem install bundler` geïnstalleerd. Een update binnen deze versies kan daardoor invloed hebben op een volgende CI-run zonder dat onze workflow is aangepast.

### Beschikbare projectchecks

| Check | Wat wordt gecontroleerd? |
| --- | --- |
| `project_parameter_order` | Verplichte parameters eerst, optionele daarna, alfabetisch binnen elke groep. Een echte afhankelijkheid van een eerdere default mag de volgorde bepalen en moet worden toegelicht. |
| `project_parameter_alignment` | Typen, namen, `=`-tekens en defaults staan over het volledige parameterblok uitgelijnd, ook bij geneste typen en waarden over meerdere regels. |
| `project_documentation` | Classes en defined types hebben een samenvatting, voorbeeld, API-markering en parameterdocumentatie in dezelfde volgorde. |
| `project_documentation_layout` | Puppet Strings gebruikt afgebroken tekst, ingesprongen tagvervolgregels en lege commentregels tussen secties. `--fix` herstelt veilige tekst en verwijdert overbodige lengte-uitzonderingen; zie [Puppet Strings](#puppet-strings). |
| `project_layout` | Arrays over meerdere regels gebruiken de [afgesproken inspringing](#inspringing). Direct na een openende `{` staan geen lege regels, ook als achter de accolade commentaar staat. Er staat één spatie na komma's op dezelfde regel en een afsluitende komma in parameterlijsten over meerdere regels. De bestaande trailing-comma-plugin controleert resources en verzamelingen. |
| `project_comment_spacing` | Een zelfstandig toelichtingsblok na code begint na een lege regel. Direct na `{`, `[` of `(` vereist deze check geen lege regel; voor `{` geldt de controle van `project_layout`. |
| `project_resource_sections` | Een resourcedeclaratie na een afgesloten blok krijgt een eigen toelichting; samen met `project_comment_spacing` wordt ook de lege regel vóór die toelichting gecontroleerd. |
| `project_resource_references` | Direct aangrenzende references van hetzelfde resourcetype in een array worden samengevoegd; titels binnen een reference staan alfabetisch. `--fix` herstelt letterlijke titels zonder tussenliggend commentaar. Zie [resource references](#resource-references) voor de afbakening. |
| `project_if_sections` | Iedere `if` of `unless` krijgt een toelichting boven de voorbereidende variabelen, of boven de voorwaarde als die voorbereiding ontbreekt. Een `elsif` hoort bij dezelfde keten; geneste voorwaarden krijgen hun eigen toelichting. |
| `project_variable_sections` | Variabelen direct na een openende `{` krijgen binnen het blok een toelichting. Na een groep met onderlinge afhankelijkheden begint een losstaande toekenning een nieuwe toegelichte groep. Waar mogelijk noemt de melding een bestaande groep om samenvoegen te beoordelen. |
| `project_class_check_reuse` | Herhaalde `defined(Class['...'])`-controles binnen een class of defined type delen één variabele. Bij één gebruik staat de controle rechtstreeks in de expressie. Aantoonbaar gebruik vanuit andere classes of ERB telt mee. |
| `project_packages` | APT-installaties gebruiken de afgesproken opties, rekening houdend met verwijderresources, providers en lokale defaults. Bij samengestelde opties moeten de voorgeschreven opties achteraan blijven staan. |
| `project_files` | Eigenaars en modi zijn expliciet, recursieve modi maken bestanden niet onnodig uitvoerbaar en `source` en `content` sluiten elkaar aantoonbaar uit. Overgeërfde of onopgeloste waarden kunnen extra cataloguscontrole vragen. |
| `project_puppet_urls` | Puppet-URL's beginnen met een toegestane mount volgens de afspraken voor [bestandsbronnen](#templates-en-bestandsbronnen), ook wanneer de standaardcheck lokaal wordt genegeerd. Deze aanvullende check herschrijft bronnen niet automatisch. |
| `project_arrays` | Arrays worden niet met `+` samengevoegd. Optelling van getallen en hashes blijft toegestaan. |
| `project_templates` | Templates gebruiken ERB. EPP-aanroepen worden gemeld; tekst en commentaar mogen EPP wel noemen. |
| `project_positive_flow` | Grotere codetakken staan vóór kortere afhandeling in `else`. Binnen classes en defined types staan `warning()` en `fail()` in een afsluitende fouttak; na hun validatie of een omvattend blok volgt geen implementatiecode meer. De check gebruikt de Puppet-structuur, inclusief geneste voorwaarden. |
| `project_shell` | Dynamische exec-commando's en guards gebruiken waarden die via `stdlib::shell_escape` zijn voorbereid. Alleen een naam met `_shell` is geen bewijs van veilige escaping. |
| `project_interface_calls` | Aanroepen passen bij de declaratie in dezelfde bron of het eigen autoloadpad. Verplichte `Optional[...]`-argumenten blijven verplicht. Splat, defaults en containment vragen daarnaast catalogustests. |
| `project_monitoring_backend` | Aanroepers van `monitoring_custom` laten de backendkeuze aan dat type over. De check volgt voorwaarden, tussenvariabelen en vindbare wrappers; alleen onderscheid tussen `none` en actieve monitoring is toegestaan. |
| `project_suppressions` | Alleen gerichte uitzonderingen voor `140chars` en `puppet_url_without_modules` zijn toegestaan, eventueel samen. Andere lintfouten moeten worden hersteld. |

Gebruik twee spaties voor inspringing, uitgelijnde pijlen en enkele aanhalingstekens voor letterlijke strings. Dubbele aanhalingstekens zijn nodig voor interpolatie of escapes. Houd de volgorde van resources en gegenereerde configuratie bewust en controleerbaar. Bereken selectors vóór de resourcedeclaratie.

De projectchecks voor documentatie en parametervolgorde vullen de standaardchecks aan. Puppet-lint laat de optionele checks voor 80 tekens, booleans tussen aanhalingstekens en code op hoofdniveau standaard uitgeschakeld. Dat past bij onze 140-tekengrens, daemonstrings zoals `'true'` en uitvoerbare profielen. Schakel geen correcte check uit om bestaande code niet te hoeven herstellen en maak geen uitzonderingslijst voor oude modules of stijlachterstand.

### Inspringing

Staat een array over meerdere regels, laat de elementen dan twee spaties verder inspringen dan de regel waarop `[` staat. Dit geldt ook binnen functieaanroepen zoals `join([` en `Sensitive.new(join([`: extra haakjes op die regel voegen geen inspringing toe. Een afsluitende `]` aan het begin van een regel krijgt dezelfde inspringing als de regel met de bijbehorende `[`. Behoud daarbij de inspringing van het omliggende codeblok.

Bij een resourcetitel die direct achter de openende accolade begint, zoals `file { [`, komt daar één niveau bij: de elementen staan vier spaties verder dan `file` en de afsluitende `]` twee spaties.

`project_layout` controleert het begin van elementen die op een nieuwe regel staan en de afsluitende `]`. Meerdere elementen op dezelfde regel blijven toegestaan. De check laat de inhoud van strings, heredocs en commentaar ongemoeid en behandelt typeparameters en indexeringen niet als arrays. De check past de inspringing niet automatisch aan met `--fix`.

### Lange regels

De `140chars`-check blijft aan. Zet achter iedere bewust langere Puppet-regel `# lint:ignore:140chars`. Dit geldt ook voor lange URL's en templateaanroepen die Puppet-lint zelf al uitzondert. Plaats de markering buiten stringwaarden. Staat er al commentaar achter de code, zet dan de markering direct na de `#`, vóór de bestaande toelichting.

Breek [Puppet Strings-documentatie](#puppet-strings) af over commentregels. Een lange beschrijvende zin is geen reden om `140chars` uit te schakelen. Alleen voor een waarde die technisch niet veilig kan worden afgebroken, zoals een lange letterlijke waarde waarin spaties betekenis hebben, gebruik je een gericht blok met `# lint:ignore:140chars` en `# lint:endignore`. Sluit dat blok vóór de volgende gewone documentatieregel. Voor overige bewust lange commentaarregels blijft zo'n begrensd blok toegestaan. Bekijk genegeerde meldingen met `bundle exec puppet-lint --show-ignored .`.

Zet nooit lintmarkeringen in gegenereerde strings of heredoc-inhoud. Heeft een waarde over meerdere regels een uitzondering nodig, plaats dan het kleinst mogelijke blok buiten de waarde. Puppet-code die uit een documentatievoorbeeld wordt gehaald heeft een eigen markering nodig wanneer die code boven 140 tekens komt.

### Parameters en resources

#### Parameters en instellingen

Houd classes en defined types klein genoeg om ze los of samen te gebruiken. Geef publieke parameters een expliciet datatype: een passend ingebouwd type of een typealias.

Voor de parametervolgorde komen verplichte parameters eerst en optionele daarna, alfabetisch binnen elke groep. Verplichte parameters hebben geen default en geen buitenste `Optional[...]`; optionele parameters hebben ten minste één daarvan. `Optional[...]` zonder default staat dus bij de optionele parameters, maar je moet de waarde bij een aanroep nog steeds meegeven. Voeg geen default toe alleen om de sortering te veranderen.

De normale volgorde kan afwijken als de standaardwaarde van een parameter een andere parameter nodig heeft. Die andere parameter moet dan eerder staan, zodat Puppet de waarde kan gebruiken. Schuift deze parameter daardoor naar voren ten opzichte van de normale volgorde, dan hoort de reden in commentaar achter die parameter te staan, met de naam van de parameter die ervan afhankelijk is. `project_parameter_order` controleert ook of die toelichting aanwezig is.

Begin namen met het onderwerp en zet nadere aanduidingen achteraan, zoals `bandwidth_max`, `p95_warning` en `secret_key_fallback`. Gebruik snake_case. Laat een naam alleen met een cijfer beginnen als dat op alle ondersteunde runtimes is getest.

Gebruik voor een beveiligingsinstelling met een veilige default, uitschakelmogelijkheid en eigen waarde één `Variant[Boolean, String]` of een passende beperkte scalarvariant. Daarbij kiest `true` de veilige default, laat `false` de uitvoer weg en geeft een scalar de eigen waarde. Bereken de uitkomst eenmaal in een duidelijke `*_correct`-variabele voor de template. Splits dit alleen in enable/custom/value-parameters wanneer compatibiliteit dat vereist.

#### Voorwaarden en validatie

Zet het grotere codeblok in de eerste tak en houd de kortere afhandeling in de laatste `else`. Zo staan bijvoorbeeld het opbouwen van resources en het verwerken van invoer vóór een korte foutmelding, waarschuwing of terugvalwaarde. De omvang van de code bepaalt de volgorde; de voorwaarde mag daarvoor een ontkenning bevatten.

`project_positive_flow` meldt een `if`-tak die minder codestructuur bevat dan de bijbehorende `else`. Een opdracht telt als één onderdeel; geneste blokken, resource-instanties, attributen en elementen in arrays, hashes en selectors tellen mee. Commentaar, witruimte, de lengte van strings en gewone functieargumenten tellen niet als extra opdrachten. Naast deze algemene vergelijking controleert dezelfde check de afsluitende structuur van validaties met `fail(...)` en `warning(...)`.

Voor gewone implementatiecode zijn gelijke takken en een `if` zonder vervolgtak toegestaan. Bij `elsif` vergelijkt de check iedere tak met de grootste afzonderlijke vervolgtak, zodat een reeks kleine alternatieven niet door optelling als één groot blok wordt behandeld. Een expliciet geneste `if` telt wel als geneste code; voor `unless` geldt dezelfde volgorde. Keer bij het omwisselen van takken de voorwaarde correct om en behoud de prioriteit van overlappende `elsif`-voorwaarden.

Laat validatievoorwaarden binnen een class of defined type zoveel mogelijk de volledige implementatie omsluiten. Bereken daarvoor benodigde waarden vooraf, plaats de reguliere code in de geldige `if`-tak en zet de bijbehorende `warning()` of `fail()` in de afsluitende `else`. Nest meerdere controles als dezelfde implementatie aan meerdere voorwaarden moet voldoen. Een bestaande `case` mag zijn foutafhandeling in de laatste `default`-tak houden.

Na deze validatiestructuur mag binnen dezelfde class of hetzelfde defined type geen implementatiecode meer volgen. `project_positive_flow` volgt daarvoor ook de bovenliggende blokken: code na een buitenste `if`, `case` of lambda-aanroep wordt eveneens gemeld. Een volgende afsluitende `else` of alternatieve `case`-tak is een ander uitvoerpad en geldt dus niet als code ná de validatie. De check beoordeelt de structuur van opdrachten, niet hun fysieke regelvolgorde.

De fouttak mag meerdere meldingen bevatten en lokale variabelen voorbereiden die aantoonbaar voor die meldingen worden gebruikt. Andere opdrachten horen in de geldige tak. Een fouttak blijft achteraan staan wanneer de meldingen en hun voorbereiding samen groter zijn dan de geldige tak; de algemene omvangscontrole geeft daarvoor geen tegenstrijdige melding. De check herkent rechtstreekse Puppet-aanroepen van `warning()` en `fail()`, inclusief namen met een voorloop-`::`. Strings, commentaar, parameterdefaults, afzonderlijke functiedefinities en functies zoals `example::warning()` vallen buiten deze aanvullende controle.

De linter herschrijft deze besturingslogica niet met `--fix`. Controleer bij het verplaatsen van code de evaluatievolgorde en optionele instellingen. Bij `warning()` bepaalt de plaatsing bovendien of de reguliere code bij ongeldige invoer nog wordt uitgevoerd; test daarom zowel het geldige als het ongeldige pad.

Een defined type dat een parentclass nodig heeft controleert `defined(Class['...'])`. Houd alle afhankelijke code binnen die geldige tak en faal duidelijk als de class ontbreekt.

Gebruik binnen een class of defined type één gedeelde variabele wanneer dezelfde `defined(Class['...'])`-controle vaker nodig is, ook bij gebruik in verschillende geneste blokken. Wordt het resultaat maar één keer gebruikt, zet de controle dan rechtstreeks in de expressie en laat de tussenvariabele weg. Een samengestelde voorwaarde zoals `$active = $ensure == present and defined(Class['basic_settings::monitoring'])` mag wel een eigen naam krijgen: die variabele beschrijft wanneer iets actief is.

`project_class_check_reuse` controleert letterlijke classnamen in de body van iedere class en ieder defined type afzonderlijk. De check telt echte variabelereferenties, inclusief interpolatie en gekwalificeerde verwijzingen vanuit vindbare manifests in het modulepad. Rechtstreeks gebruik via `@variabele` in statisch benoemde ERB-templates en `inline_template` telt ook mee. Commentaar, gewone stringtekst en gelijknamige lokale lambdavariabelen tellen niet als hergebruik. Dynamische classnamen, parameterdefaults, andere resourcetypen en indirecte template- of functielookups vallen buiten deze analyse; beoordeel die bij de review.

De check verplaatst of vervangt geen code met `--fix`. Controleer bij samenvoegen en inlinen de [evaluatievolgorde van `defined(...)`](#resources-en-afhankelijkheden), vooral wanneer tussendoor een class wordt gedeclareerd. Behoud ook gebruik vanuit andere modules of templates dat de statische analyse niet kan vinden.

Valideer een optionele instelling alleen wanneer deze wordt uitgevoerd of in gegenereerde configuratie wordt overgenomen. Een niet-ingestelde optionele waarde is geen fout. Laat de validatie één korte benoemde foutmelding of `undef` opleveren, maak resources in de geldige tak en faal in de laatste `else`. Plaats geen losse `fail(...)` halverwege de opbouw van waarden of resources.

Een template mag de ruwe parameter gebruiken om te bepalen of een lokale regel nodig is, maar schrijft de berekende waarde wanneer overerving geldt.

#### Resources en afhankelijkheden

Gebruik één resource met vooraf berekende `undef`-attributen wanneer alleen optionele attributen verschillen. Zorg dat `source` en `content` niet tegelijk gevuld kunnen zijn. Deel een buitenste guard wanneer meerdere resources dezelfde voorwaarde hebben en houd eigen controles daarbinnen.

Combineer arrays met `concat(...)`. Een lokale variabele die je maar één keer gebruikt moet betekenis toevoegen of de code duidelijker maken.

Een `defined(...)`-controle ziet alleen wat tijdens evaluatie al bekend is, niet de toekomstige eindcatalogus. Koppel `require` daarom pas na een geslaagde controle aan een geaccepteerde resource of gedocumenteerd anker. Levert een wrapper de afhankelijkheid, controleer dan achtereenvolgens de directe resource, de wrapper en de parentwrapper.

Bouw geen paden, poorten, bestandsnamen of unitnamen van een andere bouwsteen opnieuw op als een resource, alias, servicetitel of geaccepteerde API die waarde beschikbaar maakt. Test de daadwerkelijke afspraak tussen beide resources.

Voeg geen ongedocumenteerde gemaksparameters toe nadat een interface-uitbreiding is afgewezen. Gebruik de geaccepteerde interface of stabiele externe runtimemetadata.

#### Resource references

Voeg direct aangrenzende references van hetzelfde resourcetype binnen een array samen tot één reference. Sorteer de titels binnen die reference alfabetisch. Dit geldt voor alle resourcetypen, inclusief classes en eigen defined types. Gebruik bijvoorbeeld `[Package['console-setup', 'keyboard-configuration']]` waar eerst `[Package['console-setup'], Package['keyboard-configuration']]` stond.

Verschillende types blijven gescheiden. Een ander array-element onderbreekt de reeks: `[Package['zulu'], Service['nginx'], Package['alpha']]` blijft zo staan. De linter voegt geen afzonderlijke functieargumenten, geneste arrays of kanten van een relatiepijl samen, omdat daarmee de betekenis kan veranderen.

`project_resource_references` gebruikt de Puppet-AST om references en aangrenzende array-elementen te herkennen. De check sorteert letterlijke titels op hun stringwaarde, hoofdlettergevoelig en zonder aanhalingstekens mee te tellen. Bestaande correcte references blijven ongemoeid; dubbele titels worden behouden. Met `--fix` laat je de check samenvoegen en sorteren:

```sh
bundle exec puppet-lint --fix --only-checks project_resource_references path/to/manifest.pp
```

Controleer daarna de diff en voer de [volledige controles](#code-controleren) uit. Bevat een samen te voegen reeks dynamische titels of commentaar tussen de references, dan blijft de melding staan en pas je de code zelf aan. Hetzelfde geldt voor verkeerd gesorteerde letterlijke titels met tussenliggend commentaar. Behoud de toelichting bij de juiste resource en beoordeel de volgorde van dynamische titels aan de hand van de waarden die ze kunnen krijgen; de linter berekent die waarden niet. Puppet-datatypen zoals `Enum[...]`, lokale typealiases en gewone indexeringen vallen buiten deze regel.

#### Volgorde en meldingen

Behoud expliciete `require`-, `notify`- en `subscribe`-relaties. Zoek bij een cycle uit welke catalogusrelatie of containment die veroorzaakt en herstel die relatie bij de bron. Vervang haar niet door een los `systemctl`-, `service`- of reloadcommando. Behoud meldingen zoals `notify => Service['nginx']` en koppel brede ordering waar nodig aan een kleinere stabiele resource.

Houd monitoring en audit bij de bijbehorende resource. Monitoringspecifieke configuratie hoort bij de monitoringsectie van het manifest, behalve wanneer het bestand de daemon zelf configureert.

### Commentaar en documentatie

Codecommentaar helpt de lezer begrijpen waarom de code nodig is, welke beperkingen gelden en welke gevolgen de code heeft. Een herhaling van wat de volgende regel doet is daarvoor niet voldoende. Schrijf dit commentaar in het Engels, met iedere zin op één fysieke regel. Echte lijsten, voorbeelden en syntaxis krijgen aparte regels. Voor Puppet Strings gelden de [afspraken voor afgebroken documentatietekst](#puppet-strings). Verwijder bij een wijziging willekeurige regelafbrekingen in overige geraakte toelichtingen.

Zet een lege regel tussen code en een volgend zelfstandig commentaarblok, bijvoorbeeld na een variabeletoekenning. Direct na een openende `{`, `[` of `(` is die scheiding niet nodig. Aaneengesloten commentaarregels blijven bij elkaar; commentaar achter code en lintmarkeringen vormen zelf geen nieuw toelichtingsblok. `project_comment_spacing` controleert deze scheiding.

Zet geen lege regel tussen een openende `{` en de eerste toelichting of code van het blok. Staat de accolade aan het einde van de regel, eventueel gevolgd door commentaar zoals `# lint:ignore:140chars`, dan begint de inhoud direct op de volgende regel. `project_layout` meldt de eerste lege regel, ook als die alleen spaties of tabs bevat. De controle geldt voor codeblokken en verzamelingen met accolades; tekst binnen strings, reguliere expressies, heredocs en commentaar blijft buiten deze controle. Lege regels tussen onderdelen verderop in het blok blijven toegestaan. Bij `[` en `(` mag de eerstvolgende regel wel leeg zijn.

Begint na een afgesloten `}` een resourcedeclaratie, plaats dan een lege regel en direct boven de declaratie een toelichting op die resource. Dit geldt ook voor defined types, resourcedefaults en overrides. Een met `->` of `~>` verbonden resourceketen blijft één geheel. `project_resource_sections` controleert de aanwezigheid van de toelichting; beoordeel zelf of die uitlegt waarom de resource daar nodig is.

Geef iedere `if` en `unless` een eigen toelichting. Staan er direct ervoor variabelen die de voorwaarde voorbereiden, zet het commentaar dan boven de eerste van die toekenningen. De variabelen en de voorwaarde vormen samen één toegelicht blok; commentaar dat alleen boven de `if` staat vervangt de uitleg boven die voorbereiding niet. Zonder voorbereidende variabelen staat de toelichting boven de `if` zelf. Er mag een lege regel tussen de toelichting en het blok staan; de bestaande commentaarcheck bewaakt de scheiding met voorafgaande code.

`project_if_sections` volgt opeenvolgende toekenningen terug vanaf de variabelen in de voorwaarde, ook als een afhankelijkheid via een andere variabele loopt. De voorwaarden van aansluitende `elsif`-takken tellen mee bij dezelfde voorbereiding. Een losstaande toekenning of andere opdracht onderbreekt die reeks. Commentaar bij een eerder blok of een bovenliggende voorwaarde geldt niet voor een geneste `if`. Bij een toekenning zoals `$result = if ...` staat de toelichting boven de toekenning en eventuele voorbereiding. De check deelt de analyse van variabeleafhankelijkheden met `project_variable_sections`; de betekenis van de toelichting blijft onderdeel van de inhoudelijke review.

Hier staat de uitleg boven de variabele die bepaalt of de registratie actief is:

```puppet
# Register this target only when monitoring is enabled.
$active = $ensure == present and defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none'
if ($active) {
  notice('Register the active monitoring target')
}
```

De linter verplaatst of schrijft dit commentaar niet met `--fix`: beoordeel bij het oplossen van een melding of de toelichting zowel de voorbereiding als de voorwaarde uitlegt.

Geef bij niet-vanzelfsprekende resourcegroepen, execs, afgeleide waarden, voorwaardelijke directives, gedelegeerde resources en opruimroutes een korte toelichting. Doe hetzelfde bij helpers en templatelogica. Benoem waar nodig de invoer, uitvoer of gevolgen voor exitcodes. Dat is vooral nuttig bij escaping, parsing, classificatie, samenvoegen van resultaten, terugvalgedrag en uitvoeropbouw.

Verdeel lange reeksen defaults, drempels, statuswaarden, tellers, paden, rechten, commando's en relaties in herkenbare groepen. Vergelijk geraakt commentaar met goed gedocumenteerde bestaande code en verwijder verouderde, dubbele of overbodige uitleg. Kopieer geen projectbeleid naar implementatiecommentaar.

Begint een codeblok na `{` met een variabeletoekenning, zet dan binnen dat blok direct boven de variabelen een toelichting. Dit geldt ook voor één toekenning, korte `else`- en `elsif`-takken, `case`-takken, classes, defined types en lambdablokken. Het commentaar boven de voorwaarde vervangt deze toelichting binnen het blok niet. `project_variable_sections` controleert de aanwezigheid ervan; een leeg commentaar of alleen een lintmarkering is onvoldoende.

Daarnaast controleert `project_variable_sections` opeenvolgende variabeletoekenningen binnen hetzelfde codeblok, vanaf een toelichting direct boven een toekenning. Zodra een waarde een eerder toegekende variabele uit die groep gebruikt, vormen ze een aantoonbare afhankelijkheid. De eerste volgende toekenning die geen eerdere variabele uit die groep gebruikt, moet een eigen toelichting krijgen. Alleen een lege regel is onvoldoende; de bestaande `project_comment_spacing`-check controleert de lege regel vóór het nieuwe commentaar. Een later samengesteld commando heft zo'n eerdere scheiding niet op.

In dit voorbeeld begint het actieve blok met de toelichting op de servernaam. De genormaliseerde naam, de shellwaarde en het label horen bij elkaar. Het configuratiepad en de numerieke instellingen staan samen in de volgende groep:

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

De check vereist geen apart commentaar voor iedere losse instelling. Hij leidt samenhang af uit echte variabelereferenties, ook in interpolatie; overeenkomstige namen, dezelfde functie of hetzelfde externe invoerveld zijn daarvoor geen bewijs. Lokale variabelen en parameters van een lambda worden van buitenliggende variabelen onderscheiden.

Een andere opdracht, zoals een resource of `if`, beëindigt de onderzochte reeks. Buiten het begin van een blok onderzoekt de check alleen reeksen met een voorafgaande toelichting.

Ontbreekt de toelichting bij de eerste variabele na `{`, dan kan de melding ook naar een latere groep in hetzelfde blok verwijzen. Daarvoor moeten de eerste toekenningen dezelfde buitenste functie aanroepen, bijvoorbeeld `stdlib::shell_escape(...)`. De check kijkt alleen voorbij andere toekenningen en stopt zodra de oorspronkelijke variabele wordt gebruikt. Functieaanroepen met een eigen lambdablok vormen zelf geen kandidaat. De melding noemt de regel van het bestaande commentaar, zodat je kunt beoordelen of samenvoegen de code duidelijker maakt. De hint is geen bewijs van inhoudelijke samenhang: controleer ook of de volgorde van uitvoeren mag veranderen.

Beoordeel zelf of het commentaar en de gekozen groepen inhoudelijk kloppen. De linter bedenkt geen commentaar en verplaatst geen code met `--fix`.

#### Puppet Strings

Documenteer elke publieke class en elk publiek defined type direct boven de declaratie. Voeg een eenregelige `@summary`, één `@param` per parameter in declaratievolgorde en een eenvoudig uitvoerbaar `@example` toe. Markeer nieuwe classes, defined types en functies als publieke of private API.

De parameteruitleg moet duidelijk maken wat een parameter betekent, hoe de default werkt en wat bijzondere waarden zoals `undef`, `true` en `false` doen. Daarbij horen ook de beperkingen, afhankelijkheden, gegenereerde resources, het terugvalgedrag en de gevolgen voor beveiliging of compatibiliteit. De linter controleert de aanwezigheid en volgorde van tags; of de uitleg klopt en volledig is, blijft onderdeel van de inhoudelijke review.

Volg voor de opbouw de [officiële Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). Breek normale documentatietekst af over commentregels, bij voorkeur rond 120 tekens en uiterlijk bij 140 tekens, inclusief inspringing en commentteken. Kies waar mogelijk een logisch punt in de zin. Behoud woorden, technische identifiers, inline code en echte paragrafen.

Houd `@summary` kort en op één regel; zet verdere uitleg als gewone beschrijving eronder. Plaats bij langere `@param`-uitleg alleen de parameternaam achter de tag en de beschrijving op vervolgregels. Laat die regels twee spaties inspringen ten opzichte van de tag: `#   ...`. Een korte beschrijving op dezelfde regel als `@param` blijft toegestaan. Scheid secties en afzonderlijke parameters met `#`, zonder een volledig lege broncoderegel in het documentatieblok. Laat bij `@example` de titel achter de tag staan en de code eronder, met behoud van de verdere code-inspringing.

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

`project_documentation_layout` controleert commentaar boven classes, defined types, Puppet-functies en type-declaraties. De check meldt afbreekbare tekst boven 120 tekens en documentatieregels boven 140 tekens, ook wanneer de standaardcheck een URL uitzondert. Een ondeelbaar element tussen 120 en 140 tekens mag blijven staan. Voor langere letterlijke waarden geldt uitsluitend de gerichte uitzondering onder [Lange regels](#lange-regels). Voorbeeldcode krijgt alleen een lengtemelding boven 140 tekens en wordt nooit als lopende tekst afgebroken.

Laat veilige opmaakfouten herstellen met:

```sh
bundle exec puppet-lint --fix --only-checks project_documentation_layout path/to/manifest.pp
```

De autofix breekt gewone tekst af zonder woorden of backtick-inhoud te splitsen, bewaart paragrafen en herstelt herkenbare tag-inspringing en sectiescheiding. Hij verwijdert een `140chars`-blok alleen als het uitsluitend gewone documentatie bevat. Een toelichtende reden of een gecombineerde lintuitzondering blijft staan voor handmatige beoordeling.

Lengte- of opmaakproblemen in summaries, voorbeeldcode, lijsten, tabellen, codeblokken en onduidelijke Markdown vragen handmatige aanpassing; daarvoor blijft een melding met `[review]` staan. Controleer ook bij een geslaagde autofix de inhoud en betekenis in de diff.

Voer daarna de [volledige controles](#code-controleren) opnieuw uit. Bij een algemene `--fix` kunnen meldingen van de standaardcheck `140chars` nog op de oorspronkelijke regels slaan: Puppet-lint verzamelt alle meldingen voordat de fixes worden toegepast. Een nieuwe scan controleert de herschreven regels.

#### Waar de uitleg hoort

De [documentatieafspraken in `AGENTS.md`](../../AGENTS.md#documentation) bepalen de taal en de verdeling tussen gebruikershandleiding, toolinghandleiding, Puppet Strings en uitgebreide voorbeelden. Lokale implementatieafspraken blijven bij het script of de template.

Maak geen handmatige `REFERENCE.md` of `docs/`-boom voor informatie die Puppet Strings kan genereren. Voeg alleen een ADR toe wanneer dat is gevraagd of al gebruikelijk is.

Hergebruik waar mogelijk een bestaand voorbeeldscenario. Voorbeelden moeten uitvoerbaar zijn met de genoemde voorwaarden en alleen de nodige parameters tonen. Volg voor voorbeeldwaarden, `Sensitive(...)` en Hiera de [uitleg in de project-README](../../README.md#gebruik-van-voorbeelden-en-parameterdocumentatie) en de [beveiligingsregels in `AGENTS.md`](../../AGENTS.md#security-and-privacy).

Werk bij een wijziging de geraakte voorbeelden en documentatie mee bij. Vergelijk Strings, defaults, relaties en gegenereerde configuratie met het manifest. Verandert monitoringgedrag voor beheerders, controleer dan ook het checkoverzicht in de project-README.

### Bestanden en beveiliging

#### Templates en bestandsbronnen

Render met ERB via `template(...)`. Gebruik één template als bestanden alleen in een klein optioneel onderdeel verschillen. Splits ze wanneer formaat of verantwoordelijkheid wezenlijk anders is.

Lever statische modulebestanden via `puppet:///modules/...`. Gebruik `puppet:///files/...` voor bestanden uit een fileservermount met de naam `files`. Die mount moet op de Puppet-server zijn ingericht en de benodigde toegang toestaan voordat je de bron gebruikt.

De standaardcheck `puppet_url_without_modules` blijft actief en meldt bronnen buiten `modules/`. Voeg bij een bewuste `files`-bron `# lint:ignore:puppet_url_without_modules` toe aan de bronregel. Zo markeer je alleen die plek als uitzondering:

```puppet
file { '/tmp/example-app.tar.gz':
  ensure => file,
  owner  => 'root',
  group  => 'root',
  mode   => '0600',
  source => 'puppet:///files/example/app.tar.gz', # lint:ignore:puppet_url_without_modules
}
```

De aanvullende check `project_puppet_urls` accepteert `modules/` en `files/` en blijft ook op de gemarkeerde regel actief. Een andere of ontbrekende mount, zoals bij `puppet:///invalid/example/app.tar.gz`, geeft dus nog steeds een waarschuwing en laat de scan mislukken. Dezelfde mountcontrole geldt voor Puppet-URL's met een expliciete servernaam. De mountnaam moet gevolgd worden door `/`; `files_backup/` geldt dus niet als `files/`.

De check beoordeelt strings die met `puppet://` beginnen, ook in bronarrays en vóór interpolatie in het vervolgpad. Hij rekent dynamische delen niet uit en controleert geen bestandsinhoud, beschikbaarheid of serverrechten. Controleer die bij de functionele validatie. Bronvalidatie in modules moet `puppet:///` toestaan wanneer deze bestanden geldige invoer zijn. Houd paden en titels voorspelbaar en test de gerenderde varianten bij hun werkelijke gebruiker.

#### Pakketten en mappen

APT-installaties eindigen met `['--no-install-recommends', '--no-install-suggests']`, tenzij een concreet pakket een afwijking nodig heeft. Gebruik `concat(...)` om deze opties achter aangeleverde opties te zetten. Deduplicatie met `union(...)` garandeert niet dat de voorgeschreven opties achteraan blijven staan.

Gebruik recursieve purge, force en recurse alleen voor mappen die volledig van de module zijn. Behoud `replace => false` op bestanden die een installer of eenmalige initialisatie aanmaakt.

Geef een gemengde boom niet recursief uitvoerrechten: beheer mappen en gewone bestanden apart. Een private boom zonder uitvoerbare bestanden mag recursief `0600` gebruiken; Puppet voegt zoekrechten toe aan de mappen. Gebruik voor geëxporteerde applicatiebomen normaal `0750` voor mappen en `0640` voor bestanden, tenzij de applicatie aantoonbaar andere rechten nodig heeft.

#### Eigenaars en rechten

Controleer wie een bestand tijdens uitvoering moet lezen of schrijven en welke bovenliggende mappen bereikbaar moeten zijn. Stel eigenaars, groepen en modi expliciet in. Houd geheimen en gevoelige configuratie buiten bereik van andere gebruikers. Gebruik als uitgangspunt:

| Bestand of map | Gebruikelijke rechten |
| --- | --- |
| Private configuratie | `0600` |
| Script dat alleen root uitvoert | `0700` |
| Sudoersfragment | `0440` |
| Systemd-unit | `0644` waar systemd dat nodig heeft |
| Statisch terugvalbestand voor een service | Root als eigenaar, de servicegroep en `0640`; zo nodig `0710` voor bovenliggende mappen |

Houd SSH-homes en `.ssh` privé. Geef uitvoerrechten alleen aan uitvoerbare bestanden. Leg wereldleesbare of groepsschrijfbare toegang uit. Een publiek bereikbaar HTTP-bestand hoeft lokaal niet voor iedereen leesbaar te zijn.

Linux-symlinks vereisen expliciet eigenaarschap, maar hebben geen afzonderlijk bruikbare chmod-modus; beveilig hun doelen.

Controleer sudo-, logrotate-, audit-, monitoring- en servicepaden tegen de echte uitvoeringsidentiteit. Gebruik waar nodig `Sensitive[...]` of `Sensitive.new(...)` voor gevoelige inhoud en commando's, zodat die niet via rapporten uitlekken.

#### Shellcommando's in Puppet

Interpoleer geen ruwe Puppet-waarden in exec-commando's, `onlyif` of `unless`. Bereid dynamische shellwoorden voor met `stdlib::shell_escape(...)`, noem ze `*_shell` en gebruik ze zonder extra aanhalingstekens als shellwoord. Escape runtimevariabelen en substituties in dubbele Puppet-strings, zoals `\$tmpdir`, `\$1` en `\$(...)`.

Een optionele guard mag `undef` zijn. De shellcheck accepteert die ontbrekende waarde en controleert de escaping in de takken die wel een commando opleveren.

Elke echte shellparserlaag heeft één quotinggrens nodig. Een script opgebouwd uit ge-escapete woorden krijgt zelf eenmaal quoting als buitenste `-c`-argument; escape dezelfde laag niet dubbel. Een statisch script mag eenmaal als geheel worden ge-escapet. Test samengestelde commando's met letterlijke waarden die spaties, aanhalingstekens en shelltekens bevatten. Dat een waarde ge-escapet is, bewijst nog niet dat ze op de juiste plaats in het commando wordt gebruikt.

Behoud afsluitende SQL-puntkomma's. Escape de hele SQL-string en gebruik `provider => shell` wanneer puntkomma's of guards anders als aparte commando's worden gelezen.

Gebruik bij voorkeur `/usr/bin/printf %s ${value_shell}` voor dynamische inhoud. Bewust voorbereide regeleinden mogen als letterlijke `\n` worden vastgelegd, eenmaal ge-escapet en met `printf %b` worden gedecodeerd. Gebruik voor willekeurige gebruikers- of runtime-inhoud over meerdere regels een bestand of template.

#### Afhankelijkheden, audit en transport

Gebruik bij voorkeur de bestaande lokale modules. De runtimeafhankelijkheden blijven beperkt tot `stdlib`, `concat`, `reboot`, `timezone` en `debconf`, tenzij een eis aantoonbaar niet goed lokaal kan worden ingevuld. Voeg geen externe Docker-, MySQL-, Nginx- of RabbitMQ-module toe alleen omdat die vergelijkbare functies heeft. Beoordeel bij nieuwe gevoelige onderdelen ook pakketbeleid, integratie, monitoring en audit.

Leg bij gewijzigde audituitzonderingen uit welk legitiem gedrag wordt uitgezonderd, welke events verdwijnen en waar de uitzondering geldt. Controleer naburige uitzonderingen op overlap.

Reverse proxies en verbindingen tussen services gebruiken standaard versleuteling. HTTP is een expliciete gedocumenteerde keuze voor een upstream zonder TLS. Certificaatproblemen zijn geen reden om versleuteling uit te schakelen. Gebruik bij lokale of self-signed upstreams versleuteling met een bewust afgebakende keuze voor vertrouwen en verificatie. Licht een minder streng vertrouwens-, rechten- of sandboxmodel bij de code toe, en ook in de project-README als beheerders dat vooraf moeten weten.

### Gedeelde services en systemd

`basic_settings` beheert de gedeelde serverbasis: pakketten en APT-bronnen, systemd, monitoring, loginbeleid, beveiligingsgereedschap, pakketonderhoud, kernel, netwerk, tijdzone en Puppet-runtimegedrag. Laat andere modules hierop aansluiten.

Gebruik de bestaande bouwstenen `basic_settings::systemd_target`, `systemd_drop_in`, `systemd_service`, `systemd_timer`, `systemd_network`, `monitoring_service`, `monitoring_custom`, `monitoring_timer`, `monitoring_npm_audit`, `security_audit`, `io_logrotate` en `login_sudo` voor hun eigen taken.

#### Targets en monitoring

Behoud de targetladder `${cluster_id}-system`, `${cluster_id}-storage`, `${cluster_id}-services`, `${cluster_id}-production`, `${cluster_id}-helpers` en `${cluster_id}-require-services`. Een geïntegreerde service schakelt vendor-enablement uit, gebruikt de gedeelde drop-in-wrapper en bindt aan het passende target. Bij actieve monitoring wordt `OnFailure=notify-failed@%i.service` toegevoegd.

Controleer bij een wijziging zowel gegenereerde units als lokale wrappers, vendor-drop-ins, directe Service-resources, templates en statische units. Rapporteer de uiteindelijke beoordeelde unitnamen alfabetisch.

Monitoring gebruikt het centrale OpenITCOCKPIT-agentmodel. Plugins staan onder `/etc/openitcockpit-agent/plugins`. Bouw `customchecks.ini` met `concat` en `concat::fragment` en laat de gedeelde monitoringtypes services, timers en eigen checks registreren. Dupliceer die registratie niet in featuremodules.

Laat de keuze en inrichting van de backend over aan `basic_settings::monitoring_custom`. Een aanroeper mag controleren of monitoring beschikbaar en ingeschakeld is, bijvoorbeeld met `$basic_settings::monitoring::package != 'none'`. Vergelijk daar niet met een concrete backendnaam zoals `'openitcockpit'`. Dit geldt voor iedere voorwaarde die een aanroep omvat, ongeacht hoe diep die aanroep staat. Ook een tussenvariabele zoals `$active`, een `case` of selector, en waarden die bijvoorbeeld `ensure` bepalen, mogen die backendselectie niet overnemen. Vergelijken met `none` blijft toegestaan voor het inschakelen én opruimen van registraties.

`project_monitoring_backend` volgt de centrale packagewaarde door toekenningen en voorwaarden. Parameters die aantoonbaar als `package` worden doorgegeven aan een monitoringaanroep tellen ook mee. De check herkent lokale wrappers en statisch benoemde wrappers in het ingestelde modulepad, inclusief classes via `include`, `contain` en `require`. Hij meldt de oorspronkelijke backendselectie één keer, ook als meerdere aanroepen ervan afhangen. Gewone pakketkeuzes zonder die relatie vallen buiten de check; `monitoring_custom` zelf blijft verantwoordelijk voor de concrete backendimplementatie.

Gebruik bijvoorbeeld deze opbouw:

```puppet
# Register this application's check when monitoring is enabled.
$active = $ensure == present and defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none'
if $active {
  basic_settings::monitoring_custom { 'application':
    source => 'puppet:///modules/profile/check_application',
  }
}
```

De analyse voert geen Puppet-functies uit en kan dynamisch berekende wrappernamen of verborgen logica in externe functies niet volledig volgen. Beoordeel die routes bij de review. De check herschrijft voorwaarden niet met `--fix`, omdat verbreden van een backendvoorwaarde het gedrag kan veranderen. Controleer bij een wijziging ook actieve monitoring, `package => 'none'` en het verwijderen van een registratie.

#### Servicebeveiliging

Beoordeel beveiligingsopties per concrete `.service`, ook bij de service achter een timer, socket of path. Service-uitvoeringsopties horen niet in targets, mounts, sockets, timers of daemonconfiguratie van journald, resolved en timesyncd.

Werk bij de beoordeling vanuit de service die uiteindelijk wordt uitgevoerd:

1. Bepaal de uiteindelijke unit en de bijbehorende Puppet-code of template.
2. Loop alle Exec-fasen na. Controleer gebruikers, groepen en aanvullende groepen, capabilities en sudo/setuid. Breng ook schrijfbare paden, bestanden, sockets, logs, tijdelijke opslag, apparaten, hometoegang, credentials, netwerk en pakketgedrag in beeld. Neem de runtime, plugins, JIT/VM's en procesinspectie mee.
3. Leg per overwogen beveiligingsoptie vast of je deze toepast, niet toepast of nader onderzoekt, met een reden. Gebruik de tabel hieronder om de gevolgen te beoordelen en kies een gerichte uitzondering wanneer een optie de service zou breken.

Een bekende native oneshot zonder bijzondere afhankelijkheden is eenvoudiger te beoordelen dan provisioning, pakketbeheer, Puppet, GitLab omnibus, Certbot-hooks, SSH-sessies, monitoringexecutors, OpenITCOCKPIT of back-up- en herstelsoftware. Gedeelde bestanden, apparaten, capabilities, JIT/plugins en helpers die privileges wijzigen vragen extra aandacht.

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

Zet `UMask=0077` voor private uitvoer expliciet in de servicespecifieke hash bij de sandboxinstellingen. Laat de instelling weg als het normale `0022`-gedrag nodig is. Licht een afwijkend gedeeld masker zoals `0027` bij de service toe.

Verberg geen masker of andere beveiligingsdefault in een generieke wrapper. Een wijziging aan wrapperbeveiliging raakt ook de services die deze wrapper gebruiken. Controleer daarom iedere bekende gebruiker; valideer die of geef per service een gedocumenteerde uitschakelmogelijkheid.

### Shellscripts en monitoring

#### Opbouw van een check

Nieuwe scripts en templates gebruiken POSIX `#!/bin/sh`, tenzij Bash-functies nodig zijn. Monitoringchecks blijven POSIX en gebruiken Nagios-exitcodes. Gebruik daarin geen arrays, `[[ ... ]]`, `(( ... ))`, `function`, process substitution, here-strings, `pipefail`, `read -d` of Bash-specifieke expansies.

`mysql/files/automysqlbackup` blijft een Bash-uitzondering vanwege arrays, indirecte expansie en rekenkundige lussen. Raak je een Bash-script, verklaar dan waarom Bash nodig blijft.

Bekijk vóór een nieuwe of gewijzigde check de meest verwante bestaande checks. Volg hun volgorde, helpers, statusverwerking, parsing, ernstbepaling, buffering, afkappen en perfdata. Wijk alleen af als het bestaande patroon niet past en licht dat toe.

Gebruik deze opbouw:

1. Fouthelper.
2. Benodigde binaries zoeken.
3. Standaardwaarden en omgevingsvariabelen initialiseren volgens het [configuratiecontract voor monitoringchecks](../../AGENTS.md#monitoring-check-configuration).
4. Eén POSIX `while getopts ... opt; do`-blok.
5. Helpers en validatie van de uiteindelijke instellingen, vóór gebruik in de hoofdlogica.
6. Hoofdlogica.

Zoek afhankelijkheden rechtstreeks met `COMMAND=$(command -v command 2>/dev/null) || die ...`. Roep `$COMMAND` zonder aanhalingstekens aan op de commandopositie en quote de data-argumenten, tests en toekenningen. Gebruik shellbuiltins rechtstreeks en `printf` in plaats van `echo`.

Geef elke CLI-optie een eigen case-tak met toekenning. Eindig met één usage-/fouttak voor ongeldige opties en hulp, inclusief `-h` wanneer deze is gedeclareerd.

Lange uitvoer staat standaard aan; voeg alleen op verzoek schakelaars daarvoor toe.

#### Invoer en configuratie

Een check die Puppet-data nodig heeft is een ERB-template met directe shelltoekenningen. Beperk ERB tot variabele-invoeging en Puppet-voorbereiding tot standaardwaarden voor beheerde configuratie, serialisatie en shellveilige waarden. Voeg alleen een checkconfiguratiebestand of parser toe als dat gevraagd is of al gebruikelijk is.

Het [configuratiecontract in `AGENTS.md`](../../AGENTS.md#monitoring-check-configuration) bepaalt hoe checks commandline-opties, omgevingsvariabelen en standaardwaarden verwerken en valideren. Controleer dit met tijdelijke synthetische invoer voor iedere gewijzigde check; Puppet-lint controleert deze shelllogica niet.

Geef Puppet-parameters voor optionele runtime-instellingen een passend `Optional[...]`-type met `undef` als standaardwaarde. Voeg een CLI-optie alleen toe wanneer de parameter is ingevuld; laat bij `undef` zowel de optie als het argument weg. Neem de scriptdefaults niet opnieuw op als terugvalwaarden in manifests, wrappers of ERB-expressies. Pas dit toe bij nieuwe instellingen en wanneer je de verwerking van standaardwaarden voor een bestaande instelling wijzigt.

Puppet mag twee expliciete drempels alvast vergelijken, maar mag voor die controle geen ontbrekende scriptdefault namaken. Het uitvoerinterval en de timeout van de monitoringagent horen bij de registratie. Een scriptoptie of omgevingsvariabele wijzigt die agentinstellingen niet; beoordeel hun samenhang volgens `AGENTS.md`.

Behoud voor beheerde daemonconfiguratie en inloggegevens de bestaande invoerroute. Dupliceer die gegevens niet in nieuwe CLI-opties of omgevingsvariabelen. De runtime-instellingen van de check volgen het hierboven genoemde configuratiecontract.

Lees bij voorkeur de effectieve daemonconfiguratie, zoals `vnstat --showconfig`, in plaats van dubbele opties, sysfs-terugvalroutes of aparte checkinstellingen. Valideer drempelsyntaxis, eenheden, omvang, volgorde en runtimebetekenis in de shellcheck.

#### Waarden en helpers

Groepeer defaults, drempels, statuswaarden, tellers, samenvattingen, perfdata, paden, rechten, commando's en relaties met een korte toelichting.

Een helper is nuttig wanneer die betekenis geeft aan de taak, validatie of opmaak centraliseert of wezenlijke duplicatie wegneemt. Voeg niet alleen voor één append, toekenning of printf een helper toe zonder zo'n reden. Houd eenmalige logica inline wanneer dat duidelijker is en zet inhoudelijke verwerking vóór kleine terugvaltakken.

Gebruik shellvariabelen en printf voor begrensde tellers, perfdata, sorteerbuffers en diagnoses. Gebruik tijdelijke bestanden en mktemp alleen wanneer een commando een bestand vereist of data te groot of onveilig is voor variabelen. Ruim tijdelijke bestanden op.

Zet geen letterlijke lege regels in gequote toekenningen; gebruik printf-formaten en ge-escapete regeleinden. Serialiseer lijsten bewust als CSV en metadata van commandosubstitutie met expliciete markeertokens in plaats van regeleindetrucs.

#### Uitvoer voor beheerders

De eerste regel moet begrijpelijk zijn zonder de volledige uitvoer te openen. Daarin staat welke service, unit, module, interface of resource wordt gecontroleerd. Bij een fout of onduidelijke uitkomst noemt die regel ook het belangrijkste geraakte object, de directe oorzaak en of escalatie waarschijnlijk nodig is.

De exitcode geeft de machinestatus. Begin de eerste regel daarom niet met een Nagios-statuswoord en label oorzakenlijsten niet met statusnamen. Meld bij een gezonde check dat het onderdeel normaal werkt.

Laat in de eerste regel nulcategorieën, drempelinventarissen, beslislabels, beslisredenen en perfdata-achtige fragmenten weg. Gedetailleerde tellers horen in perfdata of lange uitvoer.

Maak onderscheid tussen configuratiefouten, runtimefouten, contextuele waarschuwingen en onbekende of onduidelijke toestanden. Vermeld de reikwijdte van een bewust beperkte check. Informatie buiten die reikwijdte mag de exitcode niet veranderen.

Zet de belangrijkste diagnosesectie eerst. Beschrijf het geraakte onderdeel, de waargenomen toestand, de waarschijnlijke oorzaak en wat een beheerder ermee kan doen. Geef een nuttige vervolgstap of escalatieroute. Verberg de hoofdoorzaak niet in detailuitvoer en zet daar geen drempelwaarden in.

Eindig niet-triviale lange uitvoer met `Interpretation:`. Leg daar feitelijk uit hoe de getoonde gegevens, reikwijdte en context gelezen moeten worden, zonder perfdata te herhalen.

#### Veilige en begrensde uitvoer

Onderzoek de echte uitvoerroute voordat je normalisatie toevoegt. Dat is alleen nodig wanneer runtimegegevens, externe data of bewuste scheidingen onveilige pipes of ongewenste lege regels kunnen veroorzaken. Licht een niet-vanzelfsprekende bewerking toe en bewerk vaste veilige tekst niet onnodig.

Nagios kan ook op vervolgregels tekst na een pipe als perfdata lezen. Maak ruwe `|`-tekens daarom veilig zodra dynamische data de lange uitvoer ingaat.

Gebruik geen lege regels aan begin of einde en geen opeenvolgende lege regels. Zet precies één lege regel tussen afzonderlijke secties.

Gebruik één configureerbare afkapmethode per diagnoseblok. Stapel geen item-, regel-, blok- en tekenlimieten op dezelfde verzamelde diagnose. Een ander uitvoerkanaal mag een eigen limiet hebben als het niet dezelfde gegevens afkapt.

Begrens bij relevante UI-limieten het totale aantal tekens boven `Interpretation:` en zet de afkapmelding vóór die laatste uitleg, zodat de vervolgstap zichtbaar blijft.

Grenzen voor dataverzameling, zoals APT-ophaal-, groeps- en tijdslimieten of het journalvenster van de Puppet-agent, begrenzen extern werk of invoer. Ze begrenzen niet de al verzamelde diagnose. Leg het verschil uit en behoud zichtbare meldingen over afgekorte uitvoer.

#### Perfdata en compatibiliteit

Labels beginnen met een kleine letter en gebruiken compacte, stabiele snake_case-namen met alleen kleine letters, cijfers en underscores. Zet eenheden in de UOM (`%`, `B`, `s`, `Mbps`), niet in voor- of achtervoegsels van labels. Gebruik puntkomma's alleen tot en met het laatste ingevulde optionele veld.

Gebruik `c` alleen voor monotone tellers die oplopen tot een reset. Gebruik het niet voor gauges, begrensde aantallen, huidig gebruik, piekwaarden, snelheden of periodetotalen.

Behoud exitgedrag, samenvattingsvorm, perfdatakeys, CLI-opties, gegenereerde paden en registratienamen, tenzij de opdracht expliciet die externe afspraak wijzigt. Leg de operationele reden uit en test gewijzigd gezond, fout- en onbekend gedrag.
