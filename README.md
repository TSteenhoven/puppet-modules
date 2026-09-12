# Puppet-modules

Dit project bevat Puppet-modules voor het inrichten en beheren van Debian- en Ubuntu-servers. Je kunt er een veilige serverbasis, pakketbronnen, netwerkconfiguratie, web- en databaseservices, containers, certificaten en monitoring mee beheren.

De modules kiezen veilige standaardinstellingen en zijn zo opgebouwd dat Puppet steeds dezelfde voorspelbare configuratie oplevert. Je kunt ze los gebruiken of combineren. `basic_settings` richt de serverbasis in en zorgt ervoor dat andere modules daarop kunnen aansluiten.

> [!IMPORTANT]
> **Perforce zet Puppet-open-sourcecode achter een betaalmuur:** In 2025 heeft Perforce, het bedrijf achter Puppet, besloten om de open-sourcecode van Puppet achter een gesloten omgeving te plaatsen. Deze omgeving blijft gratis tot 25 nodes. Heb je er meer, dan moet je betalen. Vind jij, net als ik, dat opensourcesoftware vrij toegankelijk moet blijven? Stap dan over naar [Vox Pupuli](https://voxpupuli.org/). OpenVox van Vox Pupuli is een drop-invervanger voor Puppet. Dat betekent dat je het Puppet-pakket kunt vervangen door het OpenVox-pakket zonder je bestaande Puppet-configuratie aan te passen.

> [!CAUTION]
> **Compatibiliteit:** Dit project is ontworpen voor 64-bits besturingssystemen. De volledige combinatie van modules is gericht op `amd64`.

## Inhoudsopgave

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
    - [GitLab Runner](#gitlab-runner)
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
- **Parameters bij de code:** De Puppet Strings-comments bij classes en defined types beschrijven alle parameters, datatypes, standaardwaarden, afhankelijkheden, aangemaakte bestanden en afwijkend gedrag.

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

Voor kernel-lockdown kiest `kernel_security_lockdown => true` de waarde `integrity`. Met `false` wordt lockdown uitgeschakeld en met een string kun je zelf een modus opgeven. Bij Secure Boot blijft `integrity` de minimale waarde. Voor Multi-Gen LRU gebruikt `kernel_mglru_enable => true` een `min_ttl_ms` van 1000. Met `false` schakel je Multi-Gen LRU uit en met een integer stel je zelf `min_ttl_ms` in.

## Monitoring

OpenITCOCKPIT is het monitoringsysteem dat dit project automatisch kan instellen. Gebruik in `basic_settings` `monitoring_package => 'openitcockpit'`. Zet ook `monitoring_package_install => true` wanneer Puppet het agentpakket moet installeren. Andere modules voegen hun checks automatisch toe zodra OpenITCOCKPIT-monitoring is ingeschakeld.

De checks volgen het Nagios-pluginmodel en kunnen daardoor ook vanuit Naemon, Nagios of Icinga worden uitgevoerd. Ze gebruiken Nagios-exitcodes, noemen de belangrijkste oorzaak in de korte uitvoer, leveren perfdata voor grafieken en tonen extra uitleg in de long output. Controleer bij los gebruik welke commando's, argumenten en door Puppet ingevulde waarden de check nodig heeft.

Gebruik bij een geïnstalleerde check `-h` om de opties en bijbehorende omgevingsvariabelen te bekijken. Voor een eenmalige controle kun je hiermee drempels en uitvoerlimieten aanpassen. Commandline-opties gaan voor op omgevingsvariabelen; de volledige werkwijze staat in het [configuratiecontract](AGENTS.md#monitoring-check-configuration). Pas bij langere looptijden ook de timeout van de executor aan: een instelling in het script verandert die niet.

Met `basic_settings::monitoring_custom` kun je een eigen script in de OpenITCOCKPIT-pluginmap plaatsen en registreren. De defined types `monitoring_service`, `monitoring_timer` en `monitoring_npm_audit` zijn bedoeld voor veelvoorkomende systemd- en npm-controles. De checks zelf staan onder `files/` en `templates/`; zie ook [Beschikbare checks](#beschikbare-checks) en [`examples/monitoring.pp`](examples/monitoring.pp).

Nginx-vhosts met HTTPS en ingevulde certificaat- en sleutelpaden krijgen automatisch een lokale certificaatcontrole. Alle registraties gebruiken één gedeeld script; certificaatpaden worden tijdens de controle uit de Nginx-configuratie gelezen. Met `monitoring_cert => false` verwijder je de registratie voor een vhost.

Laat bij het uitschakelen van de hele monitoring `basic_settings::monitoring` aanwezig met `package => 'none'`: Puppet leegt dan zijn bestaande checkregistratie en herstart een actieve systemd-agent om de oude checks uit het geheugen te verwijderen. Andere pluginbestanden blijven staan.

De OpenITCOCKPIT-agent bindt standaard op `127.0.0.1`, publiceert de Prometheus-exporter standaard niet en verifieert in push-mode standaard het servercertificaat. Publiceer de agent of exporter alleen bewust en regel daarbij firewalling en TLS.

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

De class kan belangrijke serverconfiguratie en conflicterende pakketten vervangen. Controleer vooral sudoers, firewall, netwerk, bootloader, APT-bronnen, automatische updates en de gekozen bron voor Puppet Server. Niet ieder pakket is voor iedere Linux-versie en architectuur beschikbaar; de class schakelt een niet-ondersteunde pakketbron daarom uit. `basic_settings::login_user` houdt home- en SSH-bestanden privé en accepteert voor aangeleverde home- of sleutelbestanden alleen `puppet:///`, `file:///` en HTTPS.

`basic_settings::login` beheert de timeout voor een inactieve interactieve Bash-shell via `/etc/profile.d/tmout.sh`. De bestaande parameter `basic_settings::environment` geeft de serveromgeving door aan `basic_settings::login::environment`: `production` (de standaard) krijgt `TMOUT=900` (15 minuten), iedere andere waarde krijgt `TMOUT=1800` (30 minuten). Stel deze parameter in je serverprofiel of Hiera in op de werkelijke serveromgeving; de Puppet-codeomgeving bepaalt deze waarde niet automatisch. Dit zijn gekozen beleidswaarden, geen garantie dat je aan een beveiligingsnorm voldoet.

Puppet verwijdert bij de migratie uitsluitend het oude `/etc/profile.d/timeout.sh` en schrijft `tmout.sh` als regulier bestand met eigenaar en groep `root` en rechten `0644`. De instelling wordt readonly en geëxporteerd zodra een interactieve shell het profiel laadt. Bij de standaard Bash-loginroutes op Debian en Ubuntu leest `/etc/profile` de bestanden in `/etc/profile.d`, ook bij een consolelogin, interactieve SSH-login, `su -` en `sudo -i`. Een aangepaste shell of profielinrichting moet je afzonderlijk controleren; Dash voert geen idle timeout op basis van `TMOUT` uit.

De wijziging beëindigt geen bestaande sessies en herstart SSH niet. Bij herhaald laden blijft een al readonly ingestelde waarde behouden, zonder foutmelding; open een nieuwe login-shell om een gewijzigde waarde toe te passen. Niet-interactieve shells slaan de instelling over. Bash gebruikt `TMOUT` bij het wachten aan de prompt, maar ook als standaardtimeout voor `read` en bij `select`; scripts die vanuit een interactieve shell starten kunnen de geëxporteerde waarde erven. Geef zulke scripts waar nodig een eigen `read -t`-timeout of verwijder `TMOUT` uit hun eigen omgeving. Zie de [Bash-handleiding](https://manpages.ubuntu.com/manpages/jammy/man1/bash.1.html) voor dit gedrag.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  hosts_enable            => true,
  server_fdqn             => 'server01.example.org',
  systemd_ntp_extra_pools => ['ntp.example.org'],
}
```

Meer gecombineerde basisconfiguratie staat in [`examples/site.pp`](examples/site.pp); `/etc/hosts`-varianten staan in [`examples/hosts.pp`](examples/hosts.pp). De [Puppet Strings bij `basic_settings::login`](basic_settings/manifests/login.pp) beschrijven de logininstellingen.

### `docker`

#### Doel

`docker` installeert Docker CE. `docker::compose` beheert een Compose-project onder `/opt/docker/<naam>`. Met `docker::compose_proxy` publiceer je zo'n Compose-stack via Nginx. De module bevat ook kant-en-klare configuraties voor Authentik, Twenty en GitLab Runner.

#### Belangrijkste eigenschappen

- Installeert Docker CE; de officiële APT-bron kan via `basic_settings` worden beheerd.
- Accepteert Compose-bronnen via `puppet:///`, `file:///` of HTTPS en ondersteunt SHA256-controle voor downloads.
- Beheert per Compose-stack een eigen projectmap, `.env`, extra mappen voor bind mounts en een systemd-service.
- Kan containerstatus, healthchecks, toegestane eenmalige containers en orphans monitoren.
- Kan een Compose-stack via een Nginx reverse proxy publiceren en gebruikt standaard HTTPS naar de containerapplicatie.
- Levert Authentik- en Twenty-configuratie met `Sensitive` geheimen en een optionele Nginx-proxy.
- Levert GitLab Runner met optionele eenmalige registratie en behoud van de actieve runnerconfiguratie.

#### Belangrijke aandachtspunten

Declareer `docker` vóór Compose-resources en zorg dat de Docker-pakketbron beschikbaar is. Geef de inhoud van `.env` met geheimen door als `Sensitive(...)` en gebruik voor gedownloade Compose-bestanden HTTPS met een checksum. `docker::compose_proxy` vereist `nginx` en gebruikt standaard HTTPS naar de achterliggende applicatie. Kies alleen HTTP als die applicatie geen TLS ondersteunt. `docker::authentik` verwijdert standaard de eerste beheerder `akadmin`; zet `akadmin_remove => false` als deze gebruiker moet blijven bestaan. Puppet maakt de map `custom-templates` aan, maar beheert de inhoud niet.

Met de bestaande `basic_settings::systemd`-inrichting start Puppet een nieuwe Compose-service direct en koppelt deze aan het gekozen target voor volgende boots. `ensure => absent` verwijdert alleen de projectmap, inclusief lokale bind-mountgegevens. Ontkoppel en stop de stack daarom zelf voordat je Puppet de map laat verwijderen, en maak een back-up van gegevens die je wilt bewaren.

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

Met `docker::compose_exec` voer je een commando uit in één draaiende container van een Compose-service. Geef het commando als argumentenlijst op en gebruik `creates` of `unless` om onnodige herhaling te voorkomen. De define wacht op de bijbehorende `docker::compose`-stack en stopt bij ontbrekende of meerdere passende containers. Zie de [Puppet Strings](docker/manifests/compose_exec.pp) voor de interface en [`examples/docker.pp`](examples/docker.pp) voor dit gebruik en Compose-, proxy-, Authentik- en Twenty-varianten.

#### GitLab Runner

Met `docker::gitlab_runner` gebruik je een daarvoor bestemde host of VM voor vertrouwde projecten en builds. Richt eerst Docker en `basic_settings::systemd` in en maak de runner in GitLab aan. De manager krijgt toegang tot de host-Docker-socket en heeft daarmee vergaande macht over de host. Jobcontainers krijgen die socket en de runnerconfiguratie niet mee en draaien zonder privileged mode. De vaste jobpolicy `if-not-present` kan gecachte private images zonder nieuwe registry-autorisatie hergebruiken en houdt veranderlijke tags niet vanzelf actueel.

Automatische registratie staat standaard uit. Voor een nieuwe registratie met `auto_register => true` lever je de runner authentication token aan als `Sensitive[String]` uit je beveiligde secretvoorziening. Het voorbeeld veronderstelt dat de Hiera-lookup dit type teruggeeft. `image_tag` kiest de GitLab Runner-image; de standaardimage voor jobs blijft `alpine:latest`.

```puppet
docker::gitlab_runner { 'gitlab-runner':
  auto_register => true,
  runner_token  => lookup('profile::gitlab_runner::runner_token', Sensitive[String]),
  require       => Class['docker'],
}
```

Na het starten van de Compose-container voert Puppet de registratie uit via `docker exec` met `register --non-interactive`. Zodra `config.toml` bestaat, wordt registratie overgeslagen. Dat voorkomt normale herregistratie, maar controleert niet of bestaande configuratie volledig of geldig is. Controleer de runner daarom na een mislukte of onderbroken registratie voordat je Puppet opnieuw laat draaien.

Met `runner_url` kies je de HTTPS-URL van de GitLab-server. Geef alleen `runner_ip` op als de hostnaam via normale DNS niet naar het juiste interne adres verwijst. Bijvoorbeeld: `runner_url => 'https://gitlab.example.org/'` met `runner_ip => '192.0.2.50'` levert binnen de runnercontainer de hostmapping `192.0.2.50 gitlab.example.org` op; de runner blijft verbinden met `https://gitlab.example.org/`. Registratie in dezelfde container gebruikt deze mapping ook.

Zonder `runner_ip`, of met een lege string, blijft normale DNS-resolutie gelden en ontbreekt `extra_hosts`. De mapping geldt alleen voor de runnercontainer; jobcontainers moeten GitLab zelf kunnen bereiken. Zie het [voorbeeld met een vast intern adres](examples/gitlab_runner.md#internal-gitlab-address) voor IPv4, IPv6 en de Compose-vereiste.

Na succesvolle registratie kun je `runner_token` weglaten; pas dan ook de verplichte lookup in je profiel aan. Puppet verwijdert alleen de bootstrapkopie en behoudt de actieve token en systeemidentiteit. Pauzeer de runner in GitLab en laat lopende jobs afronden vóór onderhoud of verwijdering: de eindige stoptijd kan langere jobs afbreken. De [handleiding bij het voorbeeld](examples/gitlab_runner.md) beschrijft registratie, herstel en onderhoud. Zie ook [`examples/gitlab_runner.pp`](examples/gitlab_runner.pp) en de [Puppet Strings](docker/manifests/gitlab_runner.pp).

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

De GitLab APT-bron moet vóór de installatie beschikbaar zijn, bijvoorbeeld via `basic_settings` met `gitlab_enable => true`. Het eerste rootwachtwoord is nog een parameter van het type String. Haal dit wachtwoord uit versleutelde Hiera-data en zet het niet rechtstreeks in een manifest. Het verplaatsen van `/opt/gitlab` en het uitvoeren van `gitlab-ctl reconfigure` kunnen veel wijzigen; controleer daarom eerst opslag, back-ups en het onderhoudsvenster.

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

- Installeert Certbot zonder aanbevolen of voorgestelde extra pakketten.
- Beheert `/etc/letsencrypt/cli.ini`, dat alleen door root kan worden gelezen, met het e-mailadres en de loginstellingen.
- Stelt de systemd-prioriteit in en kan een melding sturen wanneer Certbot mislukt.
- Gebruikt logrotate voor Certbotlogs wanneer logrotate door `basic_settings` wordt beheerd.
- Kan certificaten aanvragen en verwijderen.

#### Belangrijke aandachtspunten

De gekozen Certbot-plugin moet geïnstalleerd en bruikbaar zijn. De standaardplugin van `letsencrypt::certificate` is `nginx`. Declareer daarom `nginx` en controleer DNS, poort 80 en 443 en de route die Certbot voor de controle gebruikt. Certbot kan bij het vernieuwen van een certificaat extra commando's uitvoeren; test daarom ook het herladen van services en de toegang tot certificaatbestanden.

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
  require => [Class['letsencrypt'], Class['nginx']],
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

`automysqlbackup_password` is verplicht en heeft het type `Sensitive[String]`. De root- en applicatiewachtwoorden zijn nog gewone String-parameters en horen daarom uit versleutelde Hiera-data te komen. Controleer of de bufferinstellingen bij het beschikbare RAM passen, test het terugzetten van back-ups en zorg dat de gekozen pakketversie overeenkomt met `package_version`.

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

Richt eerst de OpenITCOCKPIT-server in en zorg dat `Package['openitcockpit']` in de Puppet-catalogus staat. De module beheert de volledige configuratiemap en verwijdert bestanden die niet door Puppet worden beheerd. Zet daarom geen handmatig gemaakte Naemon-configuratie in die map.

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

Een fout netwerkplan kan de beheerverbinding verbreken. Controleer interfacenamen, renderer, routes, gateway en nameservers via consoletoegang voordat Puppet de configuratie toepast. WiFi-hashes kunnen wachtwoorden bevatten; lever die data vanuit afgeschermde Hiera aan.

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
- Controleert bij actieve OpenITCOCKPIT-monitoring lokale TLS-ketens, DNS-namen, sleutels en geldigheid met één gedeeld script.

#### Belangrijke aandachtspunten

Declareer `nginx` vóór de vhosts. `nginx::server` regelt de afhankelijkheden van het pakket en de configuratiemap zelf. Voeg bij een vhost of een wrapper die Nginx-configuratie wijzigt geen `require => Class['nginx']` toe: dat zou de service vóór het configuratiebestand plaatsen, terwijl een wijziging aan dat bestand juist de service moet kunnen verversen. Gebruik voor aanvullende afhankelijkheden de betreffende pakket- of bestandsresource.

De module verwijdert Apache en neemt de Nginx-configuratie over. Controleer bestaande vhosts, document roots, certificaatrechten en gebruikte poorten. Gebruik voor reverse proxies bij voorkeur HTTPS naar de achterliggende applicatie. Schakel certificaatcontrole alleen uit voor een lokale of self-signed verbinding waarvoor dat echt nodig is. Gebruik HTTP alleen als de achterliggende applicatie geen TLS ondersteunt.

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
- Gebruikt standaard loopbackbinding, uitgeschakelde Prometheus-export en TLS-certificaatcontrole.
- Levert een Mirth Connect-agentcheck.
- Kan de server koppelen aan Nginx, PHP-FPM, Naemon, Grafana en de gedeelde systemd-targets.
- Slaat gevoelige Grafana- en pakketbrongegevens op in bestanden die alleen root kan lezen wanneer de betreffende parameter dit ondersteunt.
- Sluit aan op de custom-checkregistratie van `basic_settings`.

#### Belangrijke aandachtspunten

Voor push-mode zijn `push_url` en een `Sensitive` API-key nodig. Maak de pull- of Prometheuspoorten alleen bereikbaar als de firewall en TLS goed zijn ingesteld. De serverclass gebruikt lokale onderdelen van Nginx, PHP-FPM, Naemon en Docker. Test een upgrade daarom voor de hele OpenITCOCKPIT-server en niet alleen voor één los onderdeel.

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

Zorg dat de gekozen PHP-versie in de ingestelde APT-bron beschikbaar is, bijvoorbeeld via Sury in `basic_settings`. De gebruiker, groep en socketrechten van een FPM-pool moeten passen bij de webserver. Stem geheugenlimieten en het aantal PHP-processen af op het beschikbare geheugen en de applicatie.

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

Deze class wijzigt de kernel- en bootconfiguratie en kan daardoor een server onbruikbaar maken als er iets misgaat. De huidige code is gemaakt voor Debian 12 (`bookworm`) met `basic_settings`; gebruik haar niet op Ubuntu of een andere Debian-versie. `proxmox_enable => true` schakelt de Proxmox-pakketbron op dit moment niet in. `basic_settings` verwijdert bovendien de bron- en sleutelbestanden die zijn eigen Proxmox-helper zou gebruiken. Beheer de pakketbron daarom voorlopig in een apart profiel met andere bestandspaden. Zorg voor consoletoegang, een recente back-up en een onderhoudsvenster voordat je deze class toepast.

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

Regel de RabbitMQ APT-bron vóór de installatie. `rabbitmq::tcp` houdt de gewone TCP-poort ingeschakeld zolang de TLS-certificaten niet compleet zijn, zodat RabbitMQ bereikbaar blijft. Controleer daarom of het CA-certificaat, servercertificaat en de privésleutel aanwezig zijn voordat je onversleuteld verkeer uitschakelt. De wachtwoorden voor de managementplugin zijn nog String-parameters en horen uit versleutelde Hiera-data te komen.

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
- Beperkt hostkey-algoritmen en configureert idle timeouts.
- Ondersteunt een alternatieve poort met een afzonderlijke gebruikerslijst.
- Houdt rekening met socket activation op Ubuntu-versies die dit gebruiken.
- Registreert auditregels en een check die configuratie en sessiegedrag beoordeelt.
- Beheert `/etc/ssh/sshd_config.d` als module-eigen configuratieboom.

#### Belangrijke aandachtspunten

De module overschrijft `/etc/ssh/sshd_config` met `# Managed by puppet` en de regel `Include /etc/ssh/sshd_config.d/*.conf`, zodat de beheerde `99-custom.conf` wordt ingelezen. Bestaande instellingen in het hoofdbestand verdwijnen. Neem instellingen die je wilt behouden vooraf over in de door Puppet beheerde configuratie.

De module purgeert onbekende bestanden in `/etc/ssh/sshd_config.d`. Verplaats of vertaal bestaande drop-ins voordat je haar activeert. Houd een tweede root- of consoleverbinding open en controleer sleutels, `allow_users`, firewall en eventuele socket activation vóór de eerste herstart.

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

`bandwidth_max` is de technische interfacesnelheid in Mbit/s, niet een databundel of waarschuwingsgrens. De standaardwaarde `0` schakelt de algemene vnStat-limiet uit. Een kritieke p95-drempel mag niet lager zijn dan de waarschuwing. Een waarde voor één interface gaat voor op de algemene waarde van de class.

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
- [`examples/docker.pp`](examples/docker.pp): Compose, monitoring, Nginx-proxy, Authentik en Twenty.
- [`examples/gitlab_runner.pp`](examples/gitlab_runner.pp): GitLab Runner met eenmalige registratie; [registratie, herstel en onderhoud](examples/gitlab_runner.md).
- [`examples/web.pp`](examples/web.pp): Nginx, PHP-FPM, Let's Encrypt, TLS, security headers en reverse proxies.
- [`examples/data-services.pp`](examples/data-services.pp): MySQL, RabbitMQ en vnStat.
- [`examples/monitoring.pp`](examples/monitoring.pp): OpenITCOCKPIT-agent, eigen checks en monitoringinstellingen.
- [`examples/hosts.pp`](examples/hosts.pp): Beheer van `/etc/hosts` via de hoofdclass, networkclass en losse entries.

## Contributie

Pull requests en meldingen zijn welkom. De [lintconfiguratie, plugins en reviewcriteria](.tools/lint/README.md#naslag) bepalen de codestandaard voor alle eigen modules en uitvoerbare voorbeelden. Je kunt [dezelfde linter ook in je eigen Puppet-project gebruiken](.tools/lint/README.md#de-linter-gebruiken-in-een-ander-puppet-project).

Richt eerst de [ontwikkelomgeving](.tools/lint/README.md#benodigde-omgeving) in en voer `bundle install` uit vanuit de hoofdmap van deze repository. Met `bundle exec puppet-lint .` controleer je de projectcode; met `bundle exec rake test` test je het ontwikkelgereedschap. De lint-README legt uit [hoe je de controles uitvoert en meldingen oplost](.tools/lint/README.md#code-controleren). Voor het uitbreiden van tooltests gebruik je [de testhandleiding](.tools/tests/README.md).

Controleer gewijzigde manifests ook met `bundle exec puppet parser validate`. Valideer gewijzigd gedrag en documentatievoorbeelden afzonderlijk; de tooltests controleren het ontwikkelgereedschap. [`AGENTS.md`](AGENTS.md) beschrijft het werkproces, de inhoudelijke review en de algemene beveiligingsverantwoordelijkheden.
