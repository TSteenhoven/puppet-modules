# Puppet-modules

Dit project bevat Puppet-modules voor het inrichten en beheren van Debian- en Ubuntu-servers. Je kunt er een veilige serverbasis, pakketbronnen, netwerkconfiguratie, web- en databaseservices, containers, certificaten en monitoring mee beheren.

De modules kiezen veilige standaardinstellingen en zijn zo opgebouwd dat Puppet steeds dezelfde voorspelbare configuratie oplevert. Je kunt ze los gebruiken of combineren. `basic_settings` richt de serverbasis in en zorgt ervoor dat andere modules daarop kunnen aansluiten.

> [!IMPORTANT]
> **Perforce zet Puppet-open-sourcecode achter een betaalmuur:** In 2025 heeft Perforce, het bedrijf achter Puppet, besloten om de open-sourcecode van Puppet achter een gesloten omgeving te plaatsen. Deze omgeving blijft gratis tot 25 nodes. Heb je er meer, dan moet je betalen. Vind jij, net als ik, dat opensourcesoftware vrij toegankelijk moet blijven? Stap dan over naar [Vox Pupuli](https://voxpupuli.org/). OpenVox van Vox Pupuli is een drop-invervanger voor Puppet. Dat betekent dat je het Puppet-pakket kunt vervangen door het OpenVox-pakket zonder je bestaande Puppet-configuratie aan te passen.

> [!CAUTION]
> **Compatibiliteit:** Dit project is ontworpen voor 64-bits besturingssystemen. De volledige combinatie van modules is gericht op `amd64`.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Belangrijkste mogelijkheden](#belangrijkste-mogelijkheden)
- [Ondersteuning en compatibiliteit](#ondersteuning-en-compatibiliteit)
- [Technische uitgangspunten](#technische-uitgangspunten)
- [Beveiliging en afwijkende standaardinstellingen](#beveiliging-en-afwijkende-standaardinstellingen)
- [Monitoring](#monitoring)
- [Installatie](#installatie)
- [Quick start](#quick-start)
- [Gebruik van voorbeelden en parameterdocumentatie](#gebruik-van-voorbeelden-en-parameterdocumentatie)
- [Modules](#modules)
  - [`basic_settings`](#basic_settings)
  - [`docker`](#docker)
  - [`gitlab`](#gitlab)
  - [`letsencrypt`](#letsencrypt)
  - [`mysql`](#mysql)
  - [`naemon`](#naemon)
  - [`netplanio`](#netplanio)
  - [`nginx`](#nginx)
  - [`openitcockpit`](#openitcockpit)
  - [`php8`](#php8)
  - [`proxmox`](#proxmox)
  - [`rabbitmq`](#rabbitmq)
  - [`ssh`](#ssh)
  - [`vnstat`](#vnstat)
- [Beschikbare checks](#beschikbare-checks)
- [Uitgebreide voorbeelden](#uitgebreide-voorbeelden)
- [Contributie](#contributie)

## Belangrijkste mogelijkheden

| Onderdeel | Doel |
| --- | --- |
| `basic_settings` | Algemene serverconfiguratie, hardening, APT-bronnen, netwerk, gebruikers, systemd en monitoringbasis. |
| `docker` | Docker CE en beheerde Compose-stacks, inclusief optionele Nginx-proxy en monitoring. |
| `gitlab` | GitLab EE-installatie, omnibusconfiguratie en koppeling met lokale services. |
| `letsencrypt` | Certbot-instellingen en beheerde certificaataanvragen. |
| `mysql` | MySQL-server, databases, gebruikers, grants en versleutelbare back-ups. |
| `naemon` | Naemon-engine en host- en hostgroupconfiguratie voor OpenITCOCKPIT. |
| `netplanio` | Netplan-configuratie voor ethernet en WiFi. |
| `nginx` | Webservers, TLS, PHP-FPM-koppelingen en reverse proxies. |
| `openitcockpit` | OpenITCOCKPIT-agent, servercomponenten en specifieke agentchecks. |
| `php8` | PHP 8 CLI, extensies, PHP-FPM en afzonderlijke FPM-pools. |
| `proxmox` | Proxmox VE-installatie en de overstap naar een Proxmox-kernel. |
| `rabbitmq` | RabbitMQ, TLS, managementplugin, vhosts, exchanges, queues en gebruikers. |
| `ssh` | Gehard OpenSSH-serverbeheer, alternatieve poorten, audit en monitoring. |
| `vnstat` | Verkeersregistratie en capaciteitsmonitoring per netwerkinterface. |
| Monitoring | Nagios-compatibele checks die automatisch voor OpenITCOCKPIT kunnen worden ingesteld. |

## Ondersteuning en compatibiliteit

De modules ondersteunen Debian 11, Debian 12, Debian 13, Ubuntu 22.04 LTS, Ubuntu 23.04, Ubuntu 24.04 LTS en Ubuntu 26.04 LTS. Gebruik voor nieuwe servers bij voorkeur een release die nog reguliere beveiligingsupdates ontvangt. Sommige platformonderdelen hebben een beperktere ondersteuning; controleer daarom altijd de aandachtspunten bij de betreffende module.

De volledige combinatie is gemaakt voor `amd64`. Een deel van `basic_settings` werkt ook op andere 64-bits architecturen, maar pakketbronnen voor bijvoorbeeld MySQL en RabbitMQ worden daar niet altijd ingeschakeld. Test daarom iedere gewenste combinatie zelf wanneer je geen `amd64` gebruikt.

De modules zijn bedoeld voor Puppet 5.5 tot en met Puppet 8. `basic_settings` kan ook de pakketbron en pakketten voor OpenVox 8 beheren. Er is geen centrale testset die iedere combinatie van Puppet- of OpenVox-versie en besturingssysteem controleert, dus test een upgrade altijd eerst buiten productie.

Dit project gebruikt `concat`, `debconf`, `reboot`, `stdlib` en `timezone`. Deze modules worden als Git-submodules meegeleverd en moeten daarom tijdens de installatie ook worden opgehaald.

> [!CAUTION]
> Verschillende modules nemen bestaande configuratiebestanden of pakketkeuzes over. Pas een nieuwe catalogus eerst toe in een testomgeving, controleer wat Puppet wil wijzigen en test daarna de betreffende services. Je hoeft niet alle modules op iedere host te gebruiken.

## Technische uitgangspunten

- **Veilige standaardinstellingen:** Services en configuratiebestanden krijgen strengere rechten, TLS-instellingen en systemd-beperkingen wanneer dat veilig kan.
- **Voorspelbaar beheer:** Puppet beheert bestanden, pakketten en onderlinge relaties. Een volgende Puppet-run hoort geen onnodige wijzigingen op te leveren.
- **Vaste opstartvolgorde:** `basic_settings` maakt systemd-targets voor systeem-, opslag-, service-, productie- en helperprocessen. Andere modules kunnen hun services hieraan koppelen.
- **Los of gecombineerd:** De meeste modules werken zelfstandig. Monitoring, logrotate, auditregels en systemd-koppelingen worden toegevoegd wanneer `basic_settings` ook wordt gebruikt.
- **Geheimen uit profielen of Hiera:** Geef parameters met type `Sensitive[...]` door als `Sensitive(...)`. Haal wachtwoorden voor oudere parameters van het type String uit versleutelde Hiera-data of een profiel en zet ze niet rechtstreeks in manifests.
- **Beheerde externe bronnen:** Gebruik HTTPS of `puppet:///` voor aangeleverde bestanden. Modules die externe inhoud accepteren weigeren plain HTTP waar dat een onnodig integriteitsrisico vormt.

## Beveiliging en afwijkende standaardinstellingen

Deze modules gebruiken bewust strengere beveiligingsinstellingen dan veel standaardpakketten. Dat kan software of beheerprocedures breken die uitgaan van brede bestandstoegang, schrijfbare systeemmappen, zwakke TLS-instellingen of onbeperkte serviceprocessen. Test wijzigingen met de echte toepassing en controleer logs, sockets, certificaten en gedeelde bestanden voordat je productiehosts omzet.

| Wijziging | Mogelijke impact | Vooraf controleren | Aanpassen |
| --- | --- | --- | --- |
| systemd-hardening en afgeschermde omgevingen | Een service kan geen apparaten, home-directory's, tijdelijke bestanden of beschermde systeempaden meer gebruiken. | De paden, hooks, plugins, sockets en hulpmiddelen die de service gebruikt. | Pas alleen de systemd-instelling aan die de service werkelijk in de weg zit. |
| Strikte umask en bestanden voor alleen root | Bestanden die een webserver, back-upproces of beheergroep moet lezen kunnen te privé worden. | Eigenaar, groep en bestandsrechten van certificaten, logs, sockets, exports en back-ups. | Geef alleen de benodigde groep lees- of schrijfrechten en leg in de code uit waarom dit nodig is. |
| Kernel-, netwerk- en GRUB-instellingen | Lockdown, sysctlwaarden of netwerkkeuzes kunnen drivers, virtualisatie en netwerkverkeer van applicaties beïnvloeden. | Secure Boot, kernelmodules, routing, firewall, congestion control en hersteltoegang. | Gebruik de betreffende `basic_settings`-parameters; met `false` kun je veel optionele hardening uitschakelen. |
| SSH-hardening | Wachtwoordlogin, rootlogin, algoritmen of poorten kunnen bestaande toegang blokkeren. | Een werkende sleutel, toegestane gebruikers, firewall en een tweede beheersessie. | Pas `allow_users`, `password_authentication_users`, `permit_root_login` en de poorten aan. |
| TLS en security headers | Oude clients, zelfondertekende certificaten of webapplicaties kunnen niet meer verbinden of onderdelen van een pagina blokkeren. | Certificaatketen, SNI, ondersteunde protocollen, CSP en TLS naar de achterliggende applicatie. | Geef alleen afwijkende protocollen, headers of certificaatcontrole op als daar een duidelijke reden voor is. |
| Auditlogging en monitoring | Extra events en checks kunnen opslag, rechten en meldingsvolume beïnvloeden. | Auditregels, logrotatie, checktimeouts en monitoringontvangers. | Schakel alleen de controles in die je nodig hebt en pas waar nodig intervallen en limieten aan. |

> [!WARNING]
> `basic_settings` kan `/etc/hosts`, sudoers-inhoud, APT-bronnen, netwerkconfiguratie en andere belangrijke serverinstellingen beheren. Schakel een onderdeel uit wanneer die configuratie al ergens anders wordt beheerd. Gebruik bij een bestaande sudo-configuratie in eerste instantie `sudoers_dir_enable => false`.

Bij Secure Boot blijft `integrity` de minimale waarde voor kernel-lockdown, ook met `kernel_security_lockdown => false`. De [Puppet Strings bij `basic_settings::kernel`](basic_settings/manifests/kernel.pp) beschrijven de instelbare modi en de waarden voor Multi-Gen LRU.

## Monitoring

OpenITCOCKPIT is het monitoringsysteem dat dit project automatisch kan instellen. Gebruik in `basic_settings` `monitoring_package => 'openitcockpit'`. Zet ook `monitoring_package_install => true` wanneer Puppet het agentpakket moet installeren. Declareer `basic_settings` of `basic_settings::monitoring` vóór de serviceclasses waarvoor je monitoring wilt gebruiken. Die classes bepalen bij hun evaluatie of ze checks toevoegen.

De checks volgen het Nagios-pluginmodel en kunnen daardoor ook vanuit Naemon, Nagios of Icinga worden uitgevoerd. Ze gebruiken Nagios-exitcodes, noemen de belangrijkste oorzaak in de korte uitvoer, leveren perfdata voor grafieken en tonen extra uitleg in de long output. Controleer bij los gebruik welke commando's, argumenten en door Puppet ingevulde waarden de check nodig heeft.

Gebruik bij een geïnstalleerde check `-h` om de opties en bijbehorende omgevingsvariabelen te bekijken. Voor een eenmalige controle kun je hiermee drempels en uitvoerlimieten aanpassen. Commandline-opties gaan voor op omgevingsvariabelen. Pas bij langere looptijden ook de timeout van de executor aan: een instelling in het script verandert die niet.

Met `basic_settings::monitoring_custom` kun je een eigen script in de OpenITCOCKPIT-pluginmap plaatsen en registreren. De defined types `monitoring_service`, `monitoring_timer` en `monitoring_npm_audit` zijn bedoeld voor veelvoorkomende systemd- en npm-controles. De checks zelf staan onder `files/` en `templates/`; zie ook [Beschikbare checks](#beschikbare-checks) en [`examples/monitoring.pp`](examples/monitoring.pp).

Laat bij het uitschakelen van de hele monitoring `basic_settings::monitoring` aanwezig met `package => 'none'`: Puppet leegt dan zijn bestaande checkregistratie en herstart een actieve systemd-agent om de oude checks uit het geheugen te verwijderen. Andere pluginbestanden blijven staan.

## Installatie

Voer de volgende stappen uit vanuit de hoofdmap van je Puppet-project.

1. Voeg dit project toe als Git-submodule:

   ```sh
   git submodule add https://github.com/DevSysEngineer/puppet-modules.git global-modules
   ```

2. Haal ook de modules op waarvan dit project afhankelijk is:

   ```sh
   git submodule update --init --recursive
   ```

3. Voeg in de gewenste Puppet environment een `environment.conf` toe. De extra `modulepath` maakt de modules uit `global-modules` zichtbaar naast de environmentmodules en de standaardmodulepaden:

   ```ini
   modulepath=$codedir/global-modules:$codedir/modules:$basemodulepath
   manifest=./manifests
   ```

   Bij deze inrichting staat `global-modules` naast `environments` en `modules` onder de codedir:

   ```text
   Puppet/
   ├── environments/
   │   ├── development/
   │   │   ├── environment.conf
   │   │   └── manifests/
   │   └── production/
   │       ├── environment.conf
   │       └── manifests/
   ├── global-modules/
   ├── modules/
   └── .gitmodules
   ```

4. Controleer vanuit de juiste environment of Puppet de modules vindt:

   ```sh
   puppet module list --environment development
   ```

Gebruik de [toolinghandleiding voor je eigen project](.tools/lint/README.md#de-linter-gebruiken-in-een-ander-puppet-project) om de gedeelde controles voor je eigen Puppet- en Ruby-code in te richten.

## Quick start

Dit voorbeeld richt een geharde basis in, activeert OpenITCOCKPIT-monitoring en beheert SSH. De host blijft klein genoeg om eerst veilig te testen; een gecombineerde web-, container- en databaseconfiguratie staat in [`examples/site.pp`](examples/site.pp).

```puppet
node 'server01.example.org' {
  class { 'basic_settings':
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    openitcockpit_enable       => true,
    server_fdqn                => 'server01.example.org',
  }

  # Restrict administrative SSH access after preparing the host baseline.
  class { 'ssh':
    allow_users       => ['admin'],
    permit_root_login => false,
    require           => Class['basic_settings'],
  }

  include openitcockpit

  class { 'openitcockpit::agent':
    push_apikey => Sensitive('replace-with-openitcockpit-api-key'),
    push_enable => true,
    push_url    => 'https://monitoring.example.org',
    require     => Class['basic_settings'],
  }
}
```

Vervang de hostnaam, beheerder en API-key. Compileer eerst de catalogus en pas deze in een testomgeving toe; controleer daarna SSH-toegang en de agentregistratie voordat je dezelfde basis breder uitrolt.

## Gebruik van voorbeelden en parameterdocumentatie

Voorbeelden gebruiken `example.org`, IP-adressen die voor documentatie zijn gereserveerd en waarden die met `replace-with-...` beginnen. Vervang deze waarden door gegevens uit je eigen profielen of Hiera. Gebruik `Sensitive(...)` waar dat wordt ondersteund en bewaar wachtwoorden voor oudere String-parameters versleuteld in Hiera.

De README geeft per module één eenvoudig voorbeeld. In [`examples/`](examples/) staan grotere configuraties waarin je ook ziet hoe classes en resources met elkaar samenwerken. De comments direct boven een Puppet-class of defined type bevatten de volledige lijst met parameters, datatypes, standaardwaarden, aangemaakte bestanden, afhankelijkheden en de betekenis van `true`, `false` en `undef`.

## Modules

### `basic_settings`

#### Doel

`basic_settings` bouwt de gedeelde serverbasis voor Debian en Ubuntu. De class beheert onder meer APT-bronnen, minimale pakketten, standaardinstellingen voor kernel en netwerk, taal, tijdzone, gebruikers, inloggen, beveiliging, Puppet en de systemd-targets waarop andere modules kunnen aansluiten.

Onderliggende classes en defined types kunnen ook los worden gebruikt. Dat is handig wanneer je bijvoorbeeld alleen gebruikers, `/etc/hosts`, een systemd-service, logrotate of een monitoringcheck wilt beheren.

#### Belangrijkste eigenschappen

- Beheert basispakketten en optionele APT-bronnen voor de andere modules.
- Maakt gedeelde systemd-targets en hulpmiddelen voor services, timers, netwerken en drop-ins.
- Beheert instellingen voor de kernel, het netwerk, inloggen, beveiliging, taal, opslag en Puppet.
- Kan OpenITCOCKPIT-monitoring, auditregels, logrotate en meldingen bij mislukte services instellen.
- Beheert optioneel `/etc/hosts` met vaste localhostrecords en aanvullende entries.
- Ondersteunt Puppet- en OpenVox-pakketbronnen en serverinrichting.

#### Belangrijke aandachtspunten

De class kan belangrijke serverconfiguratie en conflicterende pakketten vervangen. Controleer vooral sudoers, firewall, netwerk, bootloader, APT-bronnen, automatische updates en de gekozen bron voor Puppet Server.

Niet ieder pakket is voor iedere Linux-versie en architectuur beschikbaar; de class schakelt een niet-ondersteunde pakketbron daarom uit. Controleer of de benodigde pakketbronnen op jouw platform worden ingeschakeld.

`basic_settings::login` stelt een timeout in voor interactieve Bash-shells: 15 minuten in `production` en 30 minuten in andere serveromgevingen. De shell sluit als je zo lang niets invoert aan de prompt. Stel `basic_settings::environment` in je profiel of Hiera in op de werkelijke serveromgeving; de Puppet-codeomgeving bepaalt deze waarde niet automatisch. Open na een wijziging een nieuwe login-shell om de timeout toe te passen. Controleer bij een afwijkende shell of profielinrichting of de timeout werkt; zie de [Puppet Strings bij `basic_settings::login`](basic_settings/manifests/login.pp).

Scripts die vanuit zo'n shell starten kunnen `TMOUT` erven, waardoor ook `read` en `select` een timeout krijgen. Geef zulke scripts waar nodig een eigen `read -t`-timeout of verwijder `TMOUT` uit hun eigen omgeving.

Met `getty_enable` zet Puppet de niet-gereserveerde tekst- en seriële consoles uit `getty.target` bij iedere run aan of uit. De bestaande bootkoppelingen blijven behouden; systemd kan een gestopte console tussen Puppet-runs of bij een herstart opnieuw activeren. `gui_mode => 'kiosk'` houdt deze consoles ingeschakeld. Controleer vóór inschakelen of ze bruikbaar zijn. De agentfact `console_gettys` toont de ontdekte consoles of een detectiefout.

Gebruikt een andere toepassing een console, reserveer dan de concrete getty-instance in `basic_settings`, bijvoorbeeld met `getty_reserved_units => ['getty@tty2.service']`. Puppet laat die instance buiten het algemene consolebeleid en activeert haar ook in kioskmodus niet opnieuw. Je regelt zelf het gebruik van de console; een reservering stopt of maskeert de getty niet. Zie de [Puppet Strings bij `basic_settings::login`](basic_settings/manifests/login.pp) voor het volledige contract.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  hosts_enable            => true,
  server_fdqn             => 'server01.example.org',
  systemd_ntp_extra_pools => ['ntp.example.org'],
}
```

Meer gecombineerde basisconfiguratie staat in [`examples/site.pp`](examples/site.pp); `/etc/hosts`-varianten staan in [`examples/hosts.pp`](examples/hosts.pp). De Puppet Strings bij [`basic_settings`](basic_settings/manifests/init.pp) en [`basic_settings::login_user`](basic_settings/manifests/login_user.pp) beschrijven de instellingen voor de serverbasis en gebruikers, inclusief bestandsrechten en toegestane bronnen voor home- en sleutelbestanden.

### `docker`

#### Doel

`docker` installeert Docker CE. `docker::compose` beheert een Compose-project onder `/opt/docker/<naam>`. Met `docker::compose_proxy` publiceer je zo'n Compose-stack via Nginx. De module bevat ook kant-en-klare configuraties voor Authentik, Twenty, Nextcloud AIO en GitLab Runner.

#### Belangrijkste eigenschappen

- Installeert Docker CE; de officiële APT-bron kan via `basic_settings` worden beheerd.
- Accepteert Compose-bronnen via `puppet:///`, `file:///` of HTTPS en ondersteunt SHA256-controle voor downloads.
- Beheert per Compose-stack een eigen projectmap, `.env`, extra mappen voor bind mounts en een systemd-service.
- Kan containerstatus, healthchecks, toegestane eenmalige containers, orphans en databaseback-ups monitoren.
- Kan een Compose-stack via een Nginx reverse proxy publiceren en gebruikt standaard HTTPS naar de containerapplicatie.
- Levert Authentik- en Twenty-configuratie met `Sensitive` geheimen, vaste PostgreSQL-back-ups en een optionele Nginx-proxy.
- Levert GitLab Runner met optionele eenmalige registratie en behoud van de actieve runnerconfiguratie.
- Beheert named S3-objectstores in een bestaande Nextcloud AIO-installatie via OCC.

#### Belangrijke aandachtspunten

Declareer `docker` vóór Compose-resources en zorg dat de Docker-pakketbron beschikbaar is. Voor het starten en beheren van de stacks als systemd-service is ook `basic_settings::systemd` nodig. Bij ingeschakelde databaseback-ups, waaronder Authentik en Twenty, is deze class verplicht.

`docker::compose` en `docker::compose_proxy` halen standaard ontbrekende images op (`pull => 'missing'`). Bestaande images worden hergebruikt, behalve bij de tag `latest`: Compose haalt die bij iedere start van de Compose-service opnieuw op. Met `pull => 'never'` moeten alle images vooraf lokaal aanwezig zijn. Zie de [Puppet Strings bij `docker::compose`](docker/manifests/compose.pp) voor alle opties.

Twenty en GitLab Runner kiezen bij `image_tag => 'latest'` automatisch `pull => 'always'`. Een start of herstart van hun Compose-service, ook tijdens een serverstart, kan daardoor een nieuwe versie in gebruik nemen en vereist toegang tot de registry. Bij Twenty geldt dit voor de hele stack, inclusief PostgreSQL en Redis. Andere tags gebruiken `missing`.

Geef de inhoud van `.env` met geheimen door als `Sensitive(...)` en gebruik voor gedownloade Compose-bestanden HTTPS met een checksum.

`docker::compose_proxy` vereist `nginx` en gebruikt standaard HTTPS naar de achterliggende applicatie. Kies alleen HTTP als die applicatie geen TLS ondersteunt.

`docker::authentik` verwijdert standaard de eerste beheerder `akadmin`; zet `akadmin_remove => false` als deze gebruiker moet blijven bestaan. Het [Authentik-voorbeeld](examples/docker.pp) laat zien hoe je een eigen beheerder aanmaakt.

`docker::compose` verwijdert bij `ensure => absent` de volledige projectmap, inclusief back-ups en lokale bind-mountgegevens. Bewaar benodigde gegevens dus vooraf op een andere locatie, stop de applicatiestack en stop en deactiveer de back-uptimer en -service. Laat vervallen systemd-bestanden door het centrale mapbeheer van je host opruimen en herlaad daarna systemd. Zie ook de [Puppet Strings bij `docker::compose`](docker/manifests/compose.pp).

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  docker_enable => true,
}

# Install the runtime after preparing the Docker package source.
class { 'docker':
  require => Class['basic_settings'],
}

# Deploy the application with its managed Compose definition and environment.
docker::compose { 'example':
  compose_source => 'puppet:///modules/profile/example/docker-compose.yml',
  env_content    => Sensitive("COMPOSE_PROJECT_NAME=example\nAPP_SECRET=replace-with-secret\n"),
  require        => Class['docker'],
}
```

Compose-, proxy-, Authentik- en Twenty-varianten staan in [`examples/docker.pp`](examples/docker.pp), met een voorbeeld van een eenmalig commando via `docker::compose_exec`. Zie de Puppet Strings bij [`docker::compose_exec`](docker/manifests/compose_exec.pp) voor commando's en uitvoeringsvoorwaarden en bij [`docker::authentik`](docker/manifests/authentik.pp) voor de applicatie-instellingen en eigen templates.

#### Databaseback-ups

Authentik en Twenty krijgen automatisch een dagelijkse PostgreSQL-back-up om 05:00 uur in de lokale servertijd, met zeven dagen retentie. Voor een ander Compose-project geef je `backup_database_type => 'postgresql'` en `backup_service => 'db'` mee, waarbij je `db` vervangt door de databaseservicenaam uit je Compose-bestand. Deze parameters werken ook via `docker::compose_proxy`; Authentik en Twenty vullen ze zelf in. Met `backup_database_type => undef` declareert Puppet geen back-uptaak; bestaande back-ups blijven in de projectmap staan. Stop bij uitschakelen ook de actieve timer en service. Planning en retentie zijn op de generieke Compose-laag instelbaar; zie de [Puppet Strings](docker/manifests/compose.pp).

De gekozen service moet precies één draaiende PostgreSQL-container hebben. De runner vindt die via de Compose-project- en servicelabels en exporteert de database uit `POSTGRES_DB`, met `POSTGRES_USER` als terugval en uiteindelijk `postgres`. Het wachtwoord komt uit `POSTGRES_PASSWORD` of `POSTGRES_PASSWORD_FILE`. De container moet `pg_dump`, `pg_dumpall` en `timeout` bevatten en PostgreSQL op TCP-poort 5432 met wachtwoordauthenticatie aanbieden; externe databases en `POSTGRES_USER_FILE` of `POSTGRES_DB_FILE` worden niet ondersteund. Zorg zelf dat de applicatie deze database gebruikt: de runner vergelijkt geen applicatieverbindingsgegevens. Bestaande initialisatievariabelen veranderen een reeds gevulde PostgreSQL-volume niet; voer databasewijzigingen en wachtwoordrotaties ook daadwerkelijk door.

Iedere geslaagde run schrijft één bestand `postgresql-<voltooiingstijd>-<run-id>.sql.gz` in `/opt/docker/<project>/backup`, met de voltooiingstijd in Unix-seconden. Het bevat eerst clusterbrede globals, waaronder rollen en tablespaces, en daarna de volledige applicatiedatabase met alle schemas en `CREATE DATABASE`. Zorg voor voldoende vrije ruimte voor een tijdelijke ongecomprimeerde export naast de gecomprimeerde back-ups. De map is alleen toegankelijk voor root en krijgt ook die rechten wanneer je haar via `project_directories` opgeeft.

Start na de eerste inrichting zelf een back-up en controleer het resultaat:

```sh
sudo systemctl start docker-compose-example-backup.service
sudo systemctl status docker-compose-example-backup.timer
sudo journalctl -u docker-compose-example-backup.service
```

De bestaande systemd-monitoring meldt uitvoeringsfouten. `check_compose` controleert of een afgerond, niet-leeg back-upbestand maximaal 86.400 seconden oud is en of er na die run nog verlopen bestanden staan. De controle leest de voltooiingstijd uit de bestandsnaam en controleert geen SQL-inhoud of herstelbaarheid. Een mislukte nieuwe poging maakt een nog recente vorige back-up niet ongeldig. Dagelijkse planning garandeert niet voortdurend een back-up binnen 24 uur: langere runs, timervertraging en de wintertijdwisseling kunnen tijdelijk een ouderdomsalarm geven. Een gemiste timerstart wordt ingehaald, zonder historische snapshots te reconstrueren.

Een export heeft in de container een eigen tijdslimiet van maximaal 3.500 seconden. Bij het stoppen van de hosttaak kan die export nog doorlopen tot deze limiet. Een achtergebleven `/tmp/puppet-compose-backup` in de databasecontainer blokkeert nieuwe runs; verwijder die alleen nadat je hebt vastgesteld dat er geen export meer draait.

Herstel eerst in een afzonderlijke testdatabase met dezelfde PostgreSQL-hoofdversie en de benodigde extensies. Gebruik een lege testcluster met een beheerrol die niet in de globals voorkomt, bijvoorbeeld `restore_admin`, en verbind met diens onderhoudsdatabase. Het SQL-bestand maakt de oorspronkelijke applicatiedatabase aan; een reeds bestaande database of rol met dezelfde naam veroorzaakt een fout. Gebruik de bestaande beveiligde authenticatieroute van de testcontainer en een root-shell met beperkte bestandsrechten. Vervang hieronder het bestandspad en de naam van de testcontainer:

```sh
sudo -i
umask 077
gzip -dc '/opt/docker/example/backup/postgresql-<voltooiingstijd>-<run-id>.sql.gz' > /root/restore.sql
docker exec -i restore-test psql -X -v ON_ERROR_STOP=1 -U restore_admin -d restore_admin < /root/restore.sql
```

Controleer na herstel schemas, data, rollen, eigenaarschap en extensies voordat je op de back-up vertrouwt. Dit zijn lokale databaseback-ups: applicatiebestanden, secrets, externe kopieën en PITR vallen erbuiten.

#### Nextcloud AIO en S3-opslag

Met [`docker::nextcloud`](docker/manifests/nextcloud.pp) start je de AIO-mastercontainer achter een reverse proxy op dezelfde host. Declareer eerst `docker` en zorg voor `basic_settings::systemd`. Met `server_name` laat je Puppet de Nginx-proxy maken; declareer dan ook `nginx` en geef een geldig TLS-certificaat en de bijbehorende sleutel op. De mastercontainer benadert die domeinnaam via de Docker-host. Zonder `server_name` verzorg je die HTTPS-proxy zelf. Voer daarna dezelfde applicatiedomeinnaam in de AIO-interface in en rond de domeinvalidatie en installatie af. Puppet slaat de OCC-configuratie tot die tijd over. De eerste Puppet-run waarin de installatiecontrole slaagt, past de afwijkende instellingen toe.

Voor een eenvoudige SMTP-relay geef je `smtp_server => 'smtp.example.org'` op bij `docker::nextcloud` of `docker::authentik`. Beide gebruiken dezelfde namen voor server, poort, beveiliging en credentials. Je kunt de relay ook centraal instellen via je bestaande `basic_settings`-declaratie, zoals in het [Nextcloud-voorbeeld](examples/docker.pp). Via Hiera is dat `basic_settings::smtp_server: smtp.example.org`; de class moet ook gedeclareerd zijn. Een expliciete applicatieserver gaat voor op de centrale relay.

Voor authenticatie geef je zowel `smtp_username` als `smtp_password` op. Geef het wachtwoord als `Sensitive` door vanuit je beveiligde Hiera-data. Zonder credentials werkt de relay zonder authenticatie. Nextcloud zet dan `mail_smtpauth` op `false`, ook als authenticatie eerder aanstond. Bij Nextcloud worden poort, timeout, afzender en credentialwaarden alleen geschreven als je ze opgeeft. Laat je zo'n optionele waarde later weg, dan blijft de opgeslagen waarde in Nextcloud staan; achtergebleven credentials worden met uitgeschakelde authenticatie niet gebruikt. Puppet beheert de instellingen via OCC en schrijft alleen bij een verschil.

Kies de transportbeveiliging met `smtp_security`. De standaard is `none`: Authentik gebruikt dan geen TLS en Nextcloud gebruikt automatisch STARTTLS als de relay dat aanbiedt. Authentik ondersteunt ook `tls` voor verplicht STARTTLS. Nextcloud wijst die keuze af, omdat STARTTLS daar niet afdwingbaar is. Voor een verplicht versleutelde verbinding met Nextcloud kies je `ssl` en de poort van je relay, doorgaans 465. Dit verschil volgt uit de [Nextcloud-mailconfiguratie](https://docs.nextcloud.com/server/stable/admin_manual/configuration_server/email_configuration.html).

De [Authentik Strings](docker/manifests/authentik.pp) en [Nextcloud Strings](docker/manifests/nextcloud.pp) beschrijven de volledige parametercontracten.

De [officiële reverse-proxyopzet](https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md#external-using-aio-with-an-external-reverse-proxy-eg-caddy-nginx-cloudflare-proxy) gebruikt HTTP tussen Nginx en AIO's Apache-container. De admininterface gebruikt wel HTTPS met een zelfondertekend certificaat. Beide upstreams binden alleen aan `127.0.0.1`; Docker publiceert hiervoor geen externe poort. Met `admin_server_name` publiceer je de admininterface via de normale Nginx-listeners: standaard HTTPS op poort 443, met een redirect vanaf poort 80. Nginx verbindt intern met `https://127.0.0.1:<admin_port>`. Het opgegeven certificaat moet alle geconfigureerde publieke domeinnamen dekken. Met `admin_whitelist_ips` beperk je de toegang via deze adminproxy tot opgegeven IP-adressen of CIDR-netwerken; alle andere adressen worden dan geweigerd. Een lege lijst behoudt de bestaande toegang zonder IP-beperking. Geef de clientadressen op zoals Nginx die ziet; de whitelist geldt niet voor de gewone Nextcloud-hostnaam of rechtstreekse toegang tot de lokale adminpoort. Zonder adminproxy gebruik je een SSH-tunnel voor beheer, bij de standaardinstellingen bijvoorbeeld `ssh -L 8080:127.0.0.1:8080 admin@cloud.example.org`, en open je `https://127.0.0.1:8080`. Gebruik bij een aangepaste `admin_port` die waarde als laatste poort in de tunnelmapping. De admininterface bestuurt via de Docker-socket containers met toegang tot de host; beperk toegang op deploymentniveau. Een read-only socketmount beperkt de Docker-API-bevoegdheden niet.

AIO vereist vaste container- en volumenamen. Met deze wrapper kan daarom één AIO-installatie per lokale Docker-daemon draaien, ook als je andere resourcetitels of poorten kiest. Gebruik voor meerdere installaties [aparte VM's of afzonderlijke rootless Docker-daemons](https://github.com/nextcloud/all-in-one/blob/main/multiple-instances.md); deze wrapper beheert de lokale rootful daemon. De resourcetitel bepaalt alleen het Compose-project van de mastercontainer. AIO beheert de overige containers zelf. De Compose-monitoring controleert daardoor alleen de mastercontainer en bewijst niet dat Nextcloud, de database of AIO-backups gezond zijn. Bij gebruik van Talk verzorg je daarnaast de bereikbaarheid van de door AIO gebruikte Talk-poort in je deployment.

Puppet maakt `/opt/docker/<naam>/backup` aan op de Docker-host met eigenaar `root:root` en rechten `0700`. Om daar backups te laten schrijven, vul je dit volledige hostpad eenmalig in bij **Local backup location** in de AIO-interface, zonder afsluitende slash of `/borg`. Bij een deployment met de naam `nextcloud-aio` vul je dus `/opt/docker/nextcloud-aio/backup` in. AIO koppelt deze hostmap zelf aan zijn Borg-backupcontainer; de backuprepository komt op de host in `/opt/docker/nextcloud-aio/backup/borg`. Hiervoor is geen backupvolume op de mastercontainer nodig. De bestemming wordt opgeslagen in AIO's eigen configuratie en wordt niet ingesteld via de `.env` van deze Compose-stack.

Start vervolgens **Create backup**, bewaar de encryptiesleutel en stel na de eerste geslaagde backup de dagelijkse planning in volgens de [AIO-backupinstructies](https://github.com/nextcloud/all-in-one#backup). Het aanmaken van de map door Puppet activeert nog geen backups en selecteert de bestemming niet automatisch in AIO. Je kunt ook een hostpad buiten de Compose-projectmap of een externe Borg-repository kiezen.

Bij `ensure => absent` verwijdert Compose de hele projectmap, inclusief de lokale backupmap en inhoud. Stel deze backups daarom eerst elders veilig. Stop vervolgens de door AIO beheerde containers via de admininterface en daarna de mastercontainer, volgens het Compose-verwijdercontract. AIO's named volumes blijven bestaan.

Met `docker::nextcloud_s3` registreer je één S3-objectstore in een geïnstalleerde Nextcloud AIO-instance. Geef met `compose_name` de titel van de deployment door, zoals bij `docker::authentik_admin`. `docker::nextcloud_occ` controleert centraal of een `docker::compose`-, `docker::compose_proxy`- of `docker::nextcloud`-resource met die titel beschikbaar is en laat de OCC-opdrachten daarvan afhangen. Zonder zo'n resource mislukt de catalogusopbouw met een gerichte foutmelding. Een wrapper moet uiteindelijk de gelijknamige `docker::compose`-resource leveren.

De gedeelde `docker::compose_exec` voert OCC als `www-data` uit in de vaste container `nextcloud-aio-nextcloud`, overeenkomstig de [AIO-documentatie](https://github.com/nextcloud/all-in-one#how-to-run-occ-commands). Deze door AIO gemaakte container heeft geen Compose-servicelabel; de selectie gebruikt daarom zijn exacte containernaam. Bij een ontbrekende of gestopte container, een onvoltooide installatie of een onleesbare installatiestatus slaat Puppet de OCC-wijzigingen zonder fout over. Iedere Puppet-run controleert opnieuw of de configuratie kan worden toegepast. PHP en OCC worden in de container uitgevoerd; PHP op de host is niet nodig.

De resourcenaam bepaalt de naam onder `objectstore`. Iedere resource beheert alleen die eigen configuratie en laat andere stores staan. Puppet schrijft alleen bij een inhoudelijk verschil. Optionele instellingen die je weglaat krijgen hun standaardwaarde van Nextcloud; een eerder opgegeven optie weglaten verwijdert de bijbehorende override.

Registreren kiest geen primaire opslag: `objectstore default` en `objectstore root` beheer je afzonderlijk. Gebruik per store een eigen bucket waar alleen deze Nextcloud-installatie toegang toe heeft. Het omschakelen van een bestaande installatie migreert geen bestanden en kan bestaande data ontoegankelijk maken. Regel vooraf de migratie en back-ups van zowel de database als de objectdata; zie de [Nextcloud-handleiding voor primaire objectopslag](https://docs.nextcloud.com/server/stable/admin_manual/configuration_files/primary_storage.html).

Vervang de voorbeeldhostnaam en credentials door waarden uit je profiel of versleutelde Hiera-data. Geef het secret door als `Sensitive`; ook de access key en een proxy-URL kunnen gevoelig zijn. Puppet schermt commando's en uitvoer af, maar argumenten blijven zichtbaar voor beheerders die processen op de host of in de container mogen inspecteren. Beperk daarom Docker- en procestoegang en bescherm ook de Nextcloud-configuratie, logs en eventuele profiler.

```puppet
include docker

# Register this store without changing the default or root selection.
docker::nextcloud_s3 { 'server1':
  compose_name   => 'nextcloud-aio',
  bucket         => 'nextcloud-01',
  hostname       => 's3.example.org',
  key            => 'replace-with-access-key',
  secret         => Sensitive('replace-with-secret'),
  use_path_style => true,
}
```

Met `ensure => absent` verwijder je alleen de registratie, zonder credentials te hoeven opgeven. Migreer eerst de data en pas verwijzingen vanuit opslagselecties en gebruikers aan; verwijdering van een store die nog in gebruik is maakt de data ontoegankelijk. Buckets en objecten blijven bestaan. Alleen de Puppet-resource weghalen laat de registratie in Nextcloud staan.

Voor andere OCC-opdrachten gebruik je `docker::nextcloud_occ`, eventueel met een alleen-lezen `unless`-commando. Na een geslaagde installatiecontrole draait de opdracht bij iedere Puppet-run, tenzij `unless` aangeeft dat de instelling al goed staat. Fouten tijdens het wijzigingscommando laten de resource mislukken. Met `--noop` voert Puppet alleen de controles uit. Zie de Puppet Strings bij [`docker::nextcloud_occ`](docker/manifests/nextcloud_occ.pp) voor uitvoeringsvoorwaarden en bij [`docker::nextcloud_s3`](docker/manifests/nextcloud_s3.pp) voor S3-opties en datatypes. Het voorbeeld met twee onafhankelijke stores staat in [`examples/docker.pp`](examples/docker.pp).

#### GitLab Runner

Met `docker::gitlab_runner` gebruik je een daarvoor bestemde host of VM voor vertrouwde projecten en builds. Richt eerst Docker en `basic_settings::systemd` in en maak de runner in GitLab aan. De manager gebruikt de Docker-daemon van de host om afzonderlijke CI-containers te starten en heeft via de socket vergaande macht over de host. Nieuwe automatische registraties geven jobs geen Docker-socket of runnerconfiguratie en schakelen privileged mode niet in. Controleer bij een bestaande registratie zelf de executorinstellingen in `config.toml`; Puppet beheert die inhoud niet.

De vaste jobpolicy `if-not-present` kan gecachte private images zonder nieuwe registry-autorisatie hergebruiken en houdt veranderlijke tags niet vanzelf actueel. Beperk daarom welke projecten de runner mogen gebruiken.

Automatische registratie staat standaard uit. Voor een nieuwe registratie met `auto_register => true` lever je de runner authentication token aan als `Sensitive[String]` uit je beveiligde secretvoorziening. Het voorbeeld veronderstelt dat de Hiera-lookup dit type teruggeeft.

```puppet
docker::gitlab_runner { 'gitlab-runner':
  auto_register => true,
  runner_token  => lookup('profile::gitlab_runner::runner_token', Sensitive[String]),
  require       => Class['docker'],
}
```

Zodra `config.toml` bestaat, slaat Puppet registratie over zonder de inhoud te controleren. Controleer de runner na een mislukte of onderbroken registratie voordat je Puppet opnieuw laat draaien; volg de herstelinstructies bij `auto_register` in de [Puppet Strings](docker/manifests/gitlab_runner.pp).

Geef alleen `runner_ip` op als de hostnaam in `runner_url` via normale DNS niet naar het juiste interne adres verwijst. Die instelling geldt alleen voor de runnercontainer; jobcontainers moeten GitLab zelf kunnen bereiken. De parameterdocumentatie bij `runner_ip` beschrijft de Compose-vereiste en hoe je zo nodig de netwerkconfiguratie van de executor aanpast.

Na succesvolle registratie kun je `runner_token` weglaten; pas dan ook de verplichte lookup in je profiel aan. De actieve registratie blijft behouden.

Pauzeer de runner in GitLab en laat lopende jobs afronden vóór onderhoud of verwijdering: de eindige stoptijd kan langere jobs afbreken. Volg de procedure bij `ensure` in de Puppet Strings voordat je de stack verwijdert. Het volledige voorbeeld voor een aparte Runner-host staat in [`examples/docker.pp`](examples/docker.pp).

### `gitlab`

#### Doel

`gitlab` installeert GitLab EE en koppelt de omnibusservice aan lokale systemd-, monitoring- en auditvoorzieningen. `gitlab::config` beheert `/etc/gitlab/gitlab.rb` en voert `gitlab-ctl reconfigure` uit wanneer de configuratie wijzigt.

#### Belangrijkste eigenschappen

- Installeert GitLab EE met een initiële rootgebruiker.
- Kan `/opt/gitlab` naar een afzonderlijke installatielocatie verplaatsen.
- Beheert HTTPS-, SSH-, SMTP-, Puma-, Sidekiq- en PostgreSQL-instellingen via `gitlab::config`.
- Kan meldingen bij een mislukte service, auditregels en een GitLab-monitoringcheck instellen.
- Kan de service aan het gedeelde `services`-target binden.

#### Belangrijke aandachtspunten

De GitLab APT-bron moet vóór de installatie beschikbaar zijn, bijvoorbeeld via `basic_settings` met `gitlab_enable => true`.

Het eerste rootwachtwoord is nog een parameter van het type String. Haal dit wachtwoord uit versleutelde Hiera-data en zet het niet rechtstreeks in een manifest.

Het verplaatsen van `/opt/gitlab` en het uitvoeren van `gitlab-ctl reconfigure` kunnen veel wijzigen; controleer daarom eerst opslag, back-ups en het onderhoudsvenster.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  gitlab_enable => true,
}

# Install GitLab with the administrator password supplied through Hiera.
class { 'gitlab':
  root_password => lookup('gitlab::root_password'),
  server_fdqn   => 'gitlab.example.org',
  require       => Class['basic_settings'],
}

# Enable HTTPS for the installed GitLab service.
class { 'gitlab::config':
  https   => true,
  require => Class['gitlab'],
}
```

Een groter voorbeeld waarin GitLab samen met de serverbasis wordt gebruikt staat in [`examples/site.pp`](examples/site.pp).

### `letsencrypt`

#### Doel

`letsencrypt` installeert Certbot en beheert de algemene Certbot-instellingen. Met `letsencrypt::certificate` vraag je één certificaat voor één of meer domeinen aan via een gekozen Certbot-plugin.

#### Belangrijkste eigenschappen

- Beheert `/etc/letsencrypt/cli.ini`, dat alleen door root kan worden gelezen, met het e-mailadres en de loginstellingen.
- Stelt de systemd-prioriteit in en kan een melding sturen wanneer Certbot mislukt.
- Gebruikt logrotate voor Certbotlogs wanneer logrotate door `basic_settings` wordt beheerd.
- Kan certificaten aanvragen en verwijderen.

#### Belangrijke aandachtspunten

De gekozen Certbot-plugin moet geïnstalleerd en bruikbaar zijn. Voor de standaardplugin `nginx` declareer je eerst `letsencrypt` en daarna `nginx`, zoals in het voorbeeld. Zo installeert Nginx ook de benodigde Certbot-plugin. Controleer DNS, poort 80 en 443 en de route die Certbot voor de controle gebruikt.

Certbot kan bij het vernieuwen van een certificaat extra commando's uitvoeren; test daarom ook het herladen van services en de toegang tot certificaatbestanden.

#### Basisvoorbeeld

```puppet
class { 'letsencrypt':
  mail_to => 'security@example.org',
}

# Provide the webserver used by the certificate validation plugin.
class { 'nginx':
  securitytxt_contacts => ['mailto:security@example.org'],
  require              => Class['letsencrypt'],
}

# Request a certificate covering both public application names.
letsencrypt::certificate { 'app.example.org':
  domains => ['app.example.org', 'www.app.example.org'],
  plugin  => 'nginx',
  require => Class['letsencrypt', 'nginx'],
}
```

Een volledige Nginx-, PHP- en certificaatcombinatie staat in [`examples/web.pp`](examples/web.pp).

### `mysql`

#### Doel

`mysql` installeert en configureert de MySQL-server en maakt automatisch lokale back-ups. Met defined types beheer je databases, gebruikers en rechten. De module kan samenwerken met PHP-FPM, monitoring, systemd, logrotate en auditd.

#### Belangrijkste eigenschappen

- Beheert MySQL-serverinstellingen boven op een geharde standaardset.
- Levert defined types voor databases, gebruikers en rechten.
- Configureert `automysqlbackup` met een systemd-service en timer.
- Kan back-ups comprimeren en versleutelen.
- Registreert een MySQL-check wanneer monitoring actief is.
- Kan de pakketversie en pakketbron van `basic_settings::package_mysql` overnemen.

#### Belangrijke aandachtspunten

`automysqlbackup_password` is verplicht en heeft het type `Sensitive[String]`. De root- en applicatiewachtwoorden zijn nog gewone String-parameters en horen daarom uit versleutelde Hiera-data te komen.

Gebruik je MySQL zonder `basic_settings::package_mysql`, stem dan `package_version` af op de geïnstalleerde versie. Met die pakketbron neemt de module de versie daarvan over; zie de [Puppet Strings bij `mysql`](mysql/manifests/init.pp).

De module gebruikt vaste bufferinstellingen voor MySQL. Controleer of die bij het beschikbare RAM passen.

Test het terugzetten van de automatisch gemaakte back-ups voordat je daarop vertrouwt.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  mysql_enable  => true,
  mysql_version => 8.0,
}

# Configure database administration and backup credentials after preparing packages.
class { 'mysql':
  automysqlbackup_password => Sensitive('replace-with-backup-password'),
  root_password            => lookup('mysql::root_password'),
  require                  => Class['basic_settings'],
}

# Create the application schema after the database service is available.
mysql::database { 'app':
  ensure  => present,
  require => Class['mysql'],
}
```

Databases, gebruikers, grants, back-upinstellingen en RabbitMQ-combinaties staan in [`examples/data-services.pp`](examples/data-services.pp).

### `naemon`

#### Doel

`naemon` installeert de OpenITCOCKPIT-variant van Naemon en beheert hosts en hostgroepen. De module is bedoeld als onderdeel van een OpenITCOCKPIT-server en niet als algemene zelfstandige Naemon-module.

#### Belangrijkste eigenschappen

- Installeert `openitcockpit-naemon` nadat het OpenITCOCKPIT-pakket beschikbaar is.
- Beheert de directory met Naemon-configuratiefragmenten.
- Levert defined types voor hosts en hostgroepen.
- Koppelt de service aan het gedeelde helpers-target en kan een melding sturen wanneer de service mislukt.
- Past systemd-hardening toe en maakt waar nodig de koppeling `nagios.service` voor software die die oude servicenaam verwacht.

#### Belangrijke aandachtspunten

Richt eerst de OpenITCOCKPIT-server in en zorg dat `Package['openitcockpit']` in de Puppet-catalogus staat.

De module beheert de volledige configuratiemap en verwijdert bestanden die niet door Puppet worden beheerd. Zet daarom geen handmatig gemaakte Naemon-configuratie in die map.

#### Basisvoorbeeld

```puppet
include naemon

naemon::host { 'web01':
  address  => '192.0.2.10',
  friendly => 'Webserver 01',
  require  => Class['naemon'],
}
```

De volledige OpenITCOCKPIT- en monitoringopbouw staat in [`examples/monitoring.pp`](examples/monitoring.pp).

### `netplanio`

#### Doel

`netplanio` installeert Netplan en maakt netwerkconfiguratie voor ethernet en WiFi. De module gebruikt de DHCP- en IPv6-instellingen van `basic_settings::network` wanneer die class aanwezig is.

#### Belangrijkste eigenschappen

- Installeert `netplan.io` en beheert de module-eigen configuratiebestanden.
- Ondersteunt DHCP, statische adressen, nameservers en routes per ethernetinterface.
- Ondersteunt WiFi-accesspoints en optionele interface-instellingen.
- Kan standaardinstellingen van `basic_settings::network` overnemen.
- Past wijzigingen met Netplan toe nadat Puppet de benodigde bestanden en pakketten heeft klaargezet.

#### Belangrijke aandachtspunten

Een fout netwerkplan kan de beheerverbinding verbreken. Controleer interfacenamen, renderer, routes, gateway en nameservers via consoletoegang voordat Puppet de configuratie toepast.

WiFi-hashes kunnen wachtwoorden bevatten; lever die data vanuit afgeschermde Hiera aan.

Declareer `netplanio` vóór de interfaces.

#### Basisvoorbeeld

```puppet
include netplanio

netplanio::ethernet { 'primary':
  addresses   => ['192.0.2.20/24'],
  interface   => 'ens18',
  nameservers => { 'addresses' => ['192.0.2.53'] },
  routes      => { 'default' => { 'via' => '192.0.2.1' } },
  require     => Class['netplanio'],
}
```

Een gecombineerde netwerkinrichting past in het basisprofiel van [`examples/site.pp`](examples/site.pp).

### `nginx`

#### Doel

`nginx` installeert en configureert de Nginx-service. `nginx::server` beheert een website of reverse proxy met TLS, security headers, locations en optionele PHP-FPM-koppeling.

#### Belangrijkste eigenschappen

- Beheert algemene Nginx-, events- en HTTP-instellingen en gebruikt strenge TLS-instellingen.
- Levert vhosts voor statische sites, PHP-applicaties en reverse proxies.
- Ondersteunt HTTP/2, optioneel HTTP/3, HTTPS-forcering en certificate chains.
- Beheert security headers en de gegevens in `security.txt`.
- Werkt samen met Certbot, PHP-FPM, monitoring, auditd, logrotate en de gedeelde systemd-targets.
- Controleert configuratie vóór een service-reload.
- Controleert bij actieve OpenITCOCKPIT-monitoring HTTPS-vhosts met ingevulde certificaat- en sleutelpaden op lokale TLS-ketens, DNS-namen, sleutels en geldigheid. De controle leest de certificaatpaden uit de Nginx-configuratie; met `monitoring_cert => false` verwijder je de registratie voor een vhost.

#### Belangrijke aandachtspunten

Declareer `nginx` vóór de vhosts. Voeg bij een vhost of een wrapper die Nginx-configuratie wijzigt geen `require => Class['nginx']` toe: dat kan een afhankelijkheidscyclus veroorzaken. Gebruik voor aanvullende afhankelijkheden de betreffende pakket- of bestandsresource; `nginx::server` regelt zijn pakket- en configuratieafhankelijkheden zelf.

De module verwijdert Apache en neemt de Nginx-configuratie over. Controleer bestaande vhosts, document roots, certificaatrechten en gebruikte poorten. In `conf.d` worden bestanden met `.conf` binnen `http {}` ingelezen en bestanden met `.main` op hoofdniveau; geef eigen HTTP-configuratie daarom de extensie `.conf`.

Bij actieve HTTP/3 schakelt de module ook `quic_gso`, `quic_retry` en `quic_bpf` in. Gebruik daarvoor een Nginx-build met HTTP/3- en QUIC BPF-ondersteuning op Linux 5.7 of nieuwer, met UDP-segmentatieondersteuning. De Nginx-master moet BPF-programma's mogen laden; controleer dit ook bij containers en aanvullende servicebeperkingen. De module verruimt bij systemd de limiet voor vergrendeld geheugen om BPF-maps te kunnen aanmaken. Deze opties zijn niet afzonderlijk uitschakelbaar; met `http3_enable => false` schakel je HTTP/3 voor een vhost uit.

De bestaande kernelinstellingen `kernel.unprivileged_bpf_disabled = 1` en `net.core.bpf_jit_harden = 2` kunnen behouden blijven. Ze blokkeren BPF voor processen zonder de vereiste rechten en beveiligen de JIT-compiler. De Nginx-master behoudt met die rechten toegang tot BPF.

Houd de gebruikte HTTPS-poort ook voor UDP bereikbaar. Zet voor BPF-routering `reuseport => true` op minstens één vhost per gedeelde combinatie van luisteradres en poort. Je mag `reuseport`, `fastopen`, `backlog` en `multipath` op meerdere vhosts instellen: Puppet voegt gelijke waarden samen en meldt conflicterende waarden tijdens het compileren. De opties komen één keer per luistersocket in de configuratie; IPv4, IPv6, verschillende poorten en TCP/UDP hebben ieder hun eigen socket. Gebruik voor gedeelde listeners dezelfde schrijfwijze van adres en poort. Zie de [Puppet Strings](nginx/manifests/server.pp) voor de voorwaarden en defaults.

Controleer na de uitrol ook de servicestart: `nginx -t` test het laden van BPF-programma's niet. De [NGINX QUIC-documentatie](https://nginx.org/en/docs/http/ngx_http_v3_module.html) beschrijft de runtimevoorwaarden.

Met `multipath => true` op `nginx::server` schakel je Multipath TCP in voor de TCP-listeners van die vhost en zijn redirects. Gebruik hiervoor Nginx 1.29.7 of nieuwer met Multipath TCP-ondersteuning op Linux 5.6 of nieuwer. Standaard staat deze optie uit. Nginx schakelt bij het toevoegen of verwijderen ervan ook `SO_REUSEPORT` in; zie de [NGINX-documentatie](https://nginx.org/en/docs/http/ngx_http_core_module.html#listen) voor de beveiligingsgevolgen.

Gebruik voor reverse proxies bij voorkeur HTTPS naar de achterliggende applicatie. Schakel certificaatcontrole alleen uit voor een lokale of self-signed verbinding waarvoor dat echt nodig is. Gebruik HTTP alleen als de achterliggende applicatie geen TLS ondersteunt.

#### Basisvoorbeeld

```puppet
class { 'nginx':
  securitytxt_contacts => ['mailto:security@example.org'],
}

# Serve the static application with an explicit document root and server name.
nginx::server { 'app.example.org':
  docroot        => '/var/www/app.example.org',
  php_fpm_enable => false,
  server_name    => 'app.example.org',
}
```

TLS-, PHP-FPM-, monitoring-, security-header- en reverse-proxyvarianten staan in [`examples/web.pp`](examples/web.pp). De Puppet Strings bij [`nginx::server`](nginx/manifests/server.pp) en [`nginx::monitoring_cert`](nginx/manifests/monitoring_cert.pp) beschrijven de instellingen, drempels en beperkingen.

### `openitcockpit`

#### Doel

De class `openitcockpit` groepeert de classes voor de OpenITCOCKPIT-agent en -server. `openitcockpit::agent` beheert de agentconfiguratie. `openitcockpit::server` richt de lokale server in en koppelt deze aan de andere benodigde modules.

#### Belangrijkste eigenschappen

- Beheert een agent in pull- of push-mode met selecteerbare ingebouwde metrics.
- Gebruikt standaard `127.0.0.1` als agentadres, uitgeschakelde Prometheus-export en servercertificaatcontrole in push-mode.
- Levert een Mirth Connect-agentcheck.
- Kan de server koppelen aan Nginx, PHP-FPM, Naemon, Grafana en de gedeelde systemd-targets.
- Slaat gevoelige Grafana- en pakketbrongegevens op in bestanden die alleen root kan lezen wanneer de betreffende parameter dit ondersteunt.
- Sluit aan op de custom-checkregistratie van `basic_settings`.

#### Belangrijke aandachtspunten

Voor push-mode zijn `push_url` en een `Sensitive` API-key nodig.

Maak de pull- of Prometheuspoorten alleen bereikbaar als de firewall en TLS goed zijn ingesteld.

De serverclass gebruikt lokale onderdelen van Nginx, PHP-FPM, Naemon en Docker. Test een upgrade daarom voor de hele OpenITCOCKPIT-server en niet alleen voor één los onderdeel.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  openitcockpit_enable => true,
}

include openitcockpit

class { 'openitcockpit::agent':
  push_apikey => Sensitive('replace-with-openitcockpit-api-key'),
  push_enable => true,
  push_url    => 'https://monitoring.example.org',
  require     => Class['basic_settings'],
}
```

Pull-, push- en maatwerkcheckvarianten staan in [`examples/monitoring.pp`](examples/monitoring.pp).

### `php8`

#### Doel

`php8` installeert een gekozen PHP 8 minorversie en extensies. `php8::cli` beheert CLI-instellingen en Composer; `php8::fpm` en `php8::fpm_pool` beheren de FPM-service en afzonderlijke applicatiepools.

#### Belangrijkste eigenschappen

- Installeert alleen de PHP-extensies die je zelf inschakelt.
- Beheert module-eigen INI-bestanden voor CLI en FPM.
- Ondersteunt Composer voor CLI-workloads.
- Levert meerdere FPM-pools met eigen gebruiker, socket en process-managerinstellingen.
- Koppelt FPM aan Nginx, monitoring, systemd en de ingestelde tijdzone.
- Voorkomt dat instellingen die de module zelf beheert via een vrije INI-hash worden overschreven.

#### Belangrijke aandachtspunten

Zorg dat de gekozen PHP-versie in de ingestelde APT-bron beschikbaar is, bijvoorbeeld via Sury in `basic_settings`.

De gebruiker, groep en socketrechten van een FPM-pool moeten passen bij de webserver; anders kan die geen PHP-verzoeken doorgeven.

Stem geheugenlimieten en het aantal PHP-processen af op het beschikbare geheugen en de applicatie.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  sury_enable => true,
}

# Install the PHP runtime and application extensions from the prepared source.
class { 'php8':
  curl          => true,
  mbstring      => true,
  minor_version => 3,
  require       => Class['basic_settings'],
}

# Enable PHP-FPM after its runtime is available.
class { 'php8::fpm':
  require => Class['php8'],
}
```

Een volledige PHP-FPM-pool met Nginx staat in [`examples/web.pp`](examples/web.pp).

### `proxmox`

#### Doel

`proxmox` installeert Proxmox VE op een host waarvan `basic_settings` de platformcontext heeft bepaald. De class beheert ook de overgang naar de Proxmox-kernel en verwijdert conflicterende generieke kernelpakketten.

#### Belangrijkste eigenschappen

- Installeert de Proxmox VE- en iSCSI-pakketten.
- Installeert op het ondersteunde platform de verwachte PVE-kernel.
- Plant een reboot na de kernelovergang.
- Werkt GRUB bij na packagewijzigingen.
- Verwijdert generieke Linux-imagepakketten en `os-prober` na de Proxmox-installatie.

#### Belangrijke aandachtspunten

Deze class wijzigt de kernel- en bootconfiguratie en kan daardoor een server onbruikbaar maken als er iets misgaat. Zorg voor consoletoegang, een recente back-up en een onderhoudsvenster voordat je haar toepast. Gebruik de class uitsluitend op Debian 12 (`bookworm`) met `basic_settings`.

`proxmox_enable => true` schakelt de Proxmox-pakketbron op dit moment niet in. `basic_settings` verwijdert bovendien de bron- en sleutelbestanden die zijn eigen Proxmox-helper zou gebruiken. Beheer de pakketbron daarom voorlopig in een apart profiel met andere bestandspaden.

#### Basisvoorbeeld

```puppet
include basic_settings

# The profile must provide the repository without reusing paths owned by basic_settings.
class { 'proxmox':
  require => Class['basic_settings'],
}
```

De plaats van Proxmox in een serverprofiel wordt getoond in [`examples/site.pp`](examples/site.pp).

### `rabbitmq`

#### Doel

`rabbitmq` installeert en configureert RabbitMQ Server. Aanvullende classes en defined types beheren AMQP/TLS-listeners, de managementplugin, vhosts, exchanges, queues, bindings, gebruikers en permissies.

#### Belangrijkste eigenschappen

- Installeert Erlang en RabbitMQ en koppelt de service aan de gedeelde systemd-targets.
- Beheert het maximale aantal open bestanden, de procesprioriteit en toegestane verouderde RabbitMQ-functies.
- Ondersteunt TLS-listeners en kan plain AMQP uitschakelen zodra certificaten compleet zijn.
- Beheert de managementplugin, vhosts, exchanges, queues, bindings, gebruikers en rechten met Puppet.
- Slaat gevoelige lokale gegevens op in configuratiebestanden die alleen root of de RabbitMQ-gebruiker kan lezen.
- Registreert een RabbitMQ-check met queue- en brokerdiagnose.

#### Belangrijke aandachtspunten

Regel de RabbitMQ APT-bron vóór de installatie.

`rabbitmq::tcp` houdt de gewone TCP-poort ingeschakeld zolang niet alle drie de certificaatpaden zijn opgegeven, ook met `tcp_enable => false`. Geef daarom het CA-certificaat, servercertificaat en de privésleutel op en zorg dat die bestanden beschikbaar zijn voordat je onversleuteld verkeer uitschakelt.

De wachtwoorden voor de managementplugin zijn nog String-parameters en horen uit versleutelde Hiera-data te komen.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  rabbitmq_enable => true,
}

# Install the broker after preparing the RabbitMQ package source.
class { 'rabbitmq':
  require => Class['basic_settings'],
}

# Require TLS for client connections and disable the plain TCP listener.
class { 'rabbitmq::tcp':
  ssl_ca_certificate  => '/etc/rabbitmq/ssl/ca.pem',
  ssl_certificate     => '/etc/rabbitmq/ssl/cert.pem',
  ssl_certificate_key => '/etc/rabbitmq/ssl/key.pem',
  tcp_enable          => false,
  require             => Class['rabbitmq'],
}
```

Vhosts, exchanges, queues, bindings en gebruikers staan in [`examples/data-services.pp`](examples/data-services.pp).

### `ssh`

#### Doel

`ssh` installeert en beheert een geharde OpenSSH-server. De class schrijft de loginbanner en SSH-configuratie, ondersteunt een tweede poort en kan auditregels en een SSH-controle instellen.

#### Belangrijkste eigenschappen

- Beheert toegestane gebruikers, rootlogin en gebruikersspecifieke wachtwoordauthenticatie.
- Genereert ontbrekende hostkeys lokaal op basis van `host_key_algorithms`, met een eigen sleutel per ECDSA-curve.
- Behoudt bestaande private sleutels, herstelt ontbrekende publieke sleutels en configureert idle timeouts.
- Ondersteunt een alternatieve poort met een afzonderlijke gebruikerslijst.
- Houdt rekening met socket activation op Ubuntu-versies die dit gebruiken.
- Registreert auditregels en een check die configuratie en sessiegedrag beoordeelt.
- Beheert `/etc/ssh/sshd_config.d` als module-eigen configuratieboom.

#### Belangrijke aandachtspunten

De module vervangt `/etc/ssh/sshd_config` en verwijdert onbekende bestanden in `/etc/ssh/sshd_config.d`. Bestaande instellingen in het hoofdbestand en onbeheerde drop-ins verdwijnen. Neem instellingen die je wilt behouden vooraf over in de door Puppet beheerde configuratie.

Houd een tweede root- of consoleverbinding open en controleer sleutels, `allow_users`, firewall en eventuele socket activation vóór de eerste herstart, zodat je de toegang niet verliest.

Hostkeys staan in `/etc/ssh/host_keys`. Deze map is van `root` en heeft modus `0700`; private sleutels hebben modus `0600`.

Zet bestaande lokale sleutels en hun bijbehorende `.pub` vóór de uitrol over naar deze map om hun fingerprints te behouden, zonder bestaande sleutels op de doelpaden te overschrijven. Ed25519 en RSA behouden hun bestandsnamen. ECDSA gebruikt `ssh_host_ecdsa_nistp256_key`, `ssh_host_ecdsa_nistp384_key` en `ssh_host_ecdsa_nistp521_key`; kies voor een bestaande `ssh_host_ecdsa_key` de naam die bij de curve past. Controleer de curve vanuit de private sleutel met `sudo ssh-keygen -y -f /etc/ssh/ssh_host_ecdsa_key | ssh-keygen -lf -`. Ontbreekt een sleutel op het nieuwe pad, dan genereert Puppet daar een nieuwe identiteit. Niet-geselecteerde sleutels blijven op schijf staan, maar krijgen geen actieve `HostKey`-regel.

Als meerdere servers dezelfde hostkeys hebben, moet je die zelf vervangen; Puppet behoudt bestaande sleutels. Maak serverimages daarom zonder vooraf gegenereerde hostkeys.

Controleer na de uitrol met `sudo sshd -t` of de configuratie geldig is en met `sudo sshd -T | grep -Ei '^(hostkey|hostkeyalgorithms)'` welke sleutels actief zijn. Met `sudo sh -c 'for key in /etc/ssh/host_keys/ssh_host_*_key.pub; do ssh-keygen -lf "$key"; done'` bekijk je de lokale fingerprints; ook het doorlopen van de afgeschermde map vereist rootrechten. Vergelijk die per actief sleuteltype op twee afzonderlijk ingerichte testservers; de fingerprints moeten verschillen.

#### Basisvoorbeeld

```puppet
class { 'ssh':
  allow_users                   => ['admin', 'deploy'],
  password_authentication_users => [],
  permit_root_login             => false,
}
```

SSH in een gecombineerd webhostprofiel staat in [`examples/site.pp`](examples/site.pp). De [Puppet Strings bij `ssh`](ssh/manifests/init.pp) beschrijven de beschikbare instellingen.

### `vnstat`

#### Doel

`vnstat` installeert vnStat voor lokale verkeersregistratie en capaciteitsmonitoring. Met `vnstat::ethernet` stel je per netwerkinterface de bandbreedte en drempels voor het 95e percentiel in.

#### Belangrijkste eigenschappen

- Beheert vnStatconfiguratie en laat nieuwe interfaces standaard automatisch ontdekken.
- Ondersteunt één technische maximumsnelheid voor alle interfaces en een afwijkende waarde per interface.
- Ondersteunt algemene p95-drempels en afwijkende drempels per interface.
- Koppelt de daemon aan logrotate en de systemd-targets van `basic_settings` wanneer die beschikbaar zijn.
- Registreert een controle die de werkelijke vnStatconfiguratie met het gemeten netwerkgebruik combineert.

#### Belangrijke aandachtspunten

Gebruik voor `bandwidth_max` de technische interfacesnelheid in Mbit/s; een databundel of waarschuwingsgrens is daarvoor ongeschikt. De standaardwaarde `0` schakelt de algemene vnStat-limiet uit.

Kies de p95-drempels afzonderlijk voor de monitoring, met de kritieke drempel minimaal gelijk aan de waarschuwing. De Puppet Strings bij [`vnstat`](vnstat/manifests/init.pp) en [`vnstat::ethernet`](vnstat/manifests/ethernet.pp) beschrijven hoe algemene instellingen en waarden per interface samenwerken.

#### Basisvoorbeeld

```puppet
class { 'vnstat':
  bandwidth_max => 1000,
  p95_critical  => 900,
  p95_warning   => 700,
}

# Monitor the selected network interface using the shared traffic settings.
vnstat::ethernet { 'wan':
  interface => 'ens192',
  require   => Class['vnstat'],
}
```

Meerdere interfaces en verschillende capaciteiten staan in [`examples/data-services.pp`](examples/data-services.pp).

## Beschikbare checks

De checks worden automatisch door relevante modules geregistreerd wanneer OpenITCOCKPIT-monitoring actief is. Je kunt ze ook los vanuit een Nagios-compatibele executor gebruiken. De script- en templatecomments zijn de technische bron voor argumenten, commandodependencies, drempels, exitcodes, perfdata en diagnose-uitvoer.

- [`check_apt`](basic_settings/templates/monitoring/check_apt)
- [`check_audit`](basic_settings/templates/monitoring/check_audit)
- [`check_compose`](docker/files/check_compose)
- [`check_eset`](basic_settings/templates/monitoring/check_eset)
- [`check_gitlab`](gitlab/files/check_gitlab)
- [`check_memory_pressure`](basic_settings/templates/monitoring/check_memory_pressure)
- [`check_mirth_connect`](openitcockpit/templates/agent/check_mirth_connect)
- [`check_mysql`](mysql/templates/check_mysql)
- [`check_network`](basic_settings/templates/monitoring/check_network)
- [`check_nginx_cert`](nginx/templates/check_nginx_cert)
- [`check_nftables`](basic_settings/templates/monitoring/check_nftables)
- [`check_npm_audit`](basic_settings/files/monitoring/check_npm_audit)
- [`check_puppet_agent`](basic_settings/templates/monitoring/puppet/check_agent)
- [`check_rabbitmq`](rabbitmq/templates/check_rabbitmq)
- [`check_ssh`](ssh/templates/check_ssh)
- [`check_systemd_config`](basic_settings/files/monitoring/check_systemd_config)
- [`check_systemd_service`](basic_settings/files/monitoring/check_systemd_service)
- [`check_systemd_timer`](basic_settings/files/monitoring/check_systemd_timer)
- [`check_systemd_timesyncd`](basic_settings/files/monitoring/check_systemd_timesyncd)
- [`check_usb`](basic_settings/templates/monitoring/check_usb)
- [`check_vnstat_interfaces`](vnstat/files/check_vnstat_interfaces)

## Uitgebreide voorbeelden

De map `examples/` bevat grotere, herkenbare scenario's. Houd environment-specifieke waarden in profielen of Hiera en neem voorbeeldgeheimen nooit letterlijk over.

- [`examples/site.pp`](examples/site.pp): Gecombineerde basisinstellingen, webserver, PHP, SSH, Docker, MySQL en profielopbouw.
- [`examples/docker.pp`](examples/docker.pp): Compose, monitoring, Nginx-proxy, Authentik, Twenty, Nextcloud AIO met meerdere S3-objectstores en een aparte GitLab Runner-host met eenmalige registratie.
- [`examples/web.pp`](examples/web.pp): Nginx, PHP-FPM, Let's Encrypt, TLS, security headers en reverse proxies.
- [`examples/data-services.pp`](examples/data-services.pp): MySQL, RabbitMQ en vnStat.
- [`examples/monitoring.pp`](examples/monitoring.pp): OpenITCOCKPIT-agent, eigen checks en monitoringinstellingen.
- [`examples/hosts.pp`](examples/hosts.pp): Beheer van `/etc/hosts` via de hoofdclass, networkclass en losse entries.

## Contributie

Pull requests en meldingen zijn welkom. Wil je een wijziging bijdragen, lees dan eerst [`AGENTS.md`](AGENTS.md) voor het werkproces, de inhoudelijke review en de beveiligingsverantwoordelijkheden. De [algemene codeafspraken en reviewcriteria](.tools/lint/docs/CODE_RULES.md#naslag) gelden voor alle eigen modules en uitvoerbare voorbeelden. Raakt je wijziging commentaar, Puppet Strings of documentatie van Puppet-interfaces, volg dan daarnaast de [documentatieregels](.tools/lint/docs/DOCUMENTATION_RULES.md). Raakt je wijziging beheerde bestanden, rechten, beveiliging, services, shellcode, runtime-dependencies of monitoring, volg dan daarnaast de [operationele regels](.tools/lint/docs/OPERATIONAL_RULES.md). Beide aanvullende regelsbestanden kunnen tegelijk van toepassing zijn. De [leeswijzer](.tools/lint/README.md#leeswijzer) helpt je de relevante onderdelen te vinden.

Richt vervolgens de [ontwikkelomgeving](.tools/lint/README.md#benodigde-omgeving) in en voer `bundle install` uit vanuit de hoofdmap van deze repository. Volg tijdens het aanpassen de [dagelijkse werkwijze](.tools/lint/README.md#werkwijze-bij-een-wijziging), van de eerste lintscan tot de eindcontrole. Gebruik daarbij de volgende controles vanuit de hoofdmap:

- Controleer de Puppet-code met `bundle exec puppet-lint --no-config --config .puppet-lint.rc .`.
- Valideer ieder gewijzigd manifest afzonderlijk met `bundle exec puppet parser validate pad/naar/manifest.pp`; vervang het voorbeeldpad door het gewijzigde bestand.
- Voer vóór oplevering `bundle exec rake validate:puppet` uit om alle eigen manifests te valideren en het bijbehorende rapport te maken.
- Controleer bij Ruby-wijzigingen ook de eigen Ruby-code met `bundle exec rubocop --config .rubocop.yml`. Volg de [RuboCop-werkwijze](.tools/lint/README.md#ruby-code-controleren) voor het beoordelen van meldingen en veilig corrigeren.
- Voer na alle correcties `bundle exec rake test` uit voor de tooltests. Pas je het ontwikkelgereedschap aan, gebruik dan ook de [uitleg over het uitbreiden van tooltests](.tools/lint/README.md#tests-uitvoeren-en-uitbreiden).

De tooltests controleren het ontwikkelgereedschap. Valideer gewijzigd modulegedrag en documentatievoorbeelden daarom afzonderlijk volgens de [aanvullende validatie](.tools/lint/README.md#aanvullende-validatie).

De [uitleg over CI en rapporten](.tools/lint/README.md#ci-van-deze-repository) beschrijft waar je de uitslagen en downloadbare rapporten van je bijdrage vindt.
