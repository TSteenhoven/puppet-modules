# Puppet-modules

Welkom bij mijn Puppet-modules project. Dit is een uitgebreide module voor je Puppet-omgeving, bestaande uit verschillende onderdelen: `Basisinstellingen`, `Nginx`, `PHP`, `MySQL` en `SSH`. Deze onderdelen kunnen afzonderlijk of in combinatie worden gebruikt om je infrastructuur te verbeteren. Om deze uitbreiding mogelijk te maken, vertrouw ik op andere Puppet-modules, die ik heb toegevoegd als git-submodules. Ik wil graag de makers van [debconf](https://github.com/smoeding/puppet-debconf.git), [reboot](https://github.com/puppetlabs/puppetlabs-reboot.git), [stdlib](https://github.com/puppetlabs/puppetlabs-stdlib.git) en [timezone](https://github.com/saz/puppet-timezone.git) bedanken voor hun waardevolle bijdragen.

## Beveiligingsaanpassingen

Het is belangrijk op te merken dat ik binnen verschillende onderdelen verschillende beveiligingsverbeteringen heb geïmplementeerd. Dit kan leiden tot afwijkend gedrag van softwarepakketten ten opzichte van de oorspronkelijke verwachtingen. Zo krijgen sommige softwarepakketten nu extra opties via systemd, zoals `PrivateTmp: true`, `ProtectHome: true` en `ProtectSystem: full`, waardoor ze in een sandboxomgeving worden geplaatst. Daarnaast wordt GRUB aangepast, zodat de kernel bij het opstarten in een veiligere modus draait. Ik wil madaidan en zijn pagina [linux-hardening](https://madaidans-insecurities.github.io/guides/linux-hardening.html) bedanken voor de tips; een groot deel van zijn informatie heb ik als inspiratie gebruikt.

Ik ben me ervan bewust dat zowel vanuit softwareleveranciers als vanuit Linux-distributies (zoals [Fedora](https://discussion.fedoraproject.org/t/f40-change-proposal-systemd-security-hardening-system-wide/96423/11)) vergelijkbare maatregelen worden toegepast. In theorie hoeft dit dus niet in Puppet te worden opgenomen. Echter, aangezien niet alle distributies altijd de meest recente versie van de software gebruiken, bestaat er altijd een kans dat een specifieke beveiligingsaanpassing niet is doorgevoerd. Om deze reden kies ik ervoor om dubbele registratie toe te passen, zowel vanuit de softwareleverancier als vanuit Puppet.

:warning: **64-bits**: Deze uitbreidingsmodule gaat ervan uit dat je besturingssysteem 64-bits is.

## Installatie

Navigeer naar de hoofdmap van je Puppet-omgeving en voeg de submodule toe met het volgende commando:

```bash
git submodule add https://github.com/DevSysEngineer/puppet-modules.git global-modules
```

Voer vervolgens het volgende commando uit:

```bash
git submodule update --init --recursive
```

Als alles goed gaat, wordt de uitbreidingsmodule nu correct ingeladen in je Puppet Git-project. Nu moet alleen de Puppetserver nog weten dat deze map bestaat. Ga naar de `environments` map, kies de betreffende omgeving (bijvoorbeeld `development`). In deze omgeving bevindt zich een `manifests` map. Maak naast deze map een bestand met de naam `environment.conf` aan en plak de onderstaande configuratie:

```
modulepath=$codedir/global-modules:$codedir/modules:$basemodulepath
manifest=./manifests
```

De mapstructuur zou er nu zo uit moeten zien:
- Puppet
  - environments
    - development
      - manifests
      - environment.conf
    - production
      - manifests
      - environment.conf
  - global-modules
  - modules
  - .gitmodules

Via de onderstaande opdracht kun je controleren of de uitbreidingsmodule met submodules correct is ingeladen:

```bash
puppet module list
```

## Basic settings

Dit onderdeel bestaat uit subonderdelen die kunnen worden toegepast zonder de hoofdklasse te gebruiken. Wanneer de hoofdklasse wordt aangeroepen, worden deze subonderdelen daarin aangesproken en geconfigureerd. Het doel van deze sectie is om een [headless server](https://en.wikipedia.org/wiki/Headless_computer) op te zetten met minimale GUI/UI-pakketten, om zo het verbruik van resources te minimaliseren. Bovendien wordt de server aangepast door middel van kernelparameters om alle benodigde CPU-/powerresources te benutten voor High-performance computing ([HPC](https://en.wikipedia.org/wiki/High-performance_computing)).

Onnodige pakketten, zoals die voor energiebeheer op laptops, worden verwijderd omdat ze niet relevant zijn voor een serveromgeving. Pakketten zoals `mtr` en `rsync` worden daarentegen wel geïnstalleerd omdat ze vaak nodig zijn voor systeembeheerders. Daarnaast worden beveiligingspakketten zoals `apparmor` en `auditd` geïnstalleerd om de server te beveiligen en te monitoren op verdachte activiteiten.

Basic settings omvatten de volgende subonderdelen:

- **Development:** Pakketten/configuraties gerelateerd aan ontwikkeling.
- **IO:** Pakketten/configuraties gerelateerd aan opslag, uitschakelen van floppy's, etc.
- **Kernel:** Pakketten/configuraties gerelateerd aan de kernel en optimalisatie ervan voor HPC-gebruik.
- **Locale:** Pakketten/configuraties gerelateerd aan taalinstellingen. Mijn voorkeur gaat uit naar het standaard verwijderen hiervan.
- **Login:** Pakketten/configuraties gerelateerd aan login en gebruikersbeheer.
- **Netwerk:** Pakketten/configuraties gerelateerd aan netwerken en optimalisatie ervan voor HPC-gebruik.
- **Packages:** Installeren van een pakketbeheerder en het verwijderen van andere pakketbeheerders indien mogelijk.
  - **Packages MySQL:** Configureren van APT-repo voor MySQL met bijbehorende sleutel.
  - **Packages Node:** Configureren en installeren van APT-repo voor Node.
- **Pro:** Voor Ubuntu is het mogelijk om een Pro-abonnement af te nemen.

 Dit subonderdeel zorgt ervoor dat alle benodigde pakketten zijn geïnstalleerd.
- **Puppet:** Configureren van Puppet op de juiste manier.
- **Security:** Installeren van benodigde beveiligingspakketten om de server te monitoren.
- **Systemd:** Installeren van systemd en zorgen voor de juiste systeemdoelconfiguratie.
- **Timezone:** Configureren van tijd/datum.

### Voorbeelden

In het onderstaande voorbeeld zie je hoe `basic settings` kan worden aangeroepen:

```puppet
node 'webserver.dev.xxxx.nl' {

    /* Basis serverinstellingen */
    class { 'basic_settings':
        puppetserver_enable     => true,
        mysql_enable            => true,
        nginx_enable            => true,
        sury_enable             => true,
        systemd_ntp_extra_pools => ['ntp.time.nl']
    }
}
```

Zoals eerder vermeld, bevat `basic settings` ook een login subonderdeel. In het onderstaande voorbeeld laat ik zien hoe je een gebruiker kunt toevoegen. Wanneer de gebruiker aan de groep `wheel` wordt toegevoegd, mag de gebruiker `su` gebruiken.

```puppet
    /* Maak gebruiker */
    basic_settings::login_user { 'naam':
        ensure          => $ensure,
        home            => "/home/[naam]",
        uid             => $number,
        gid             => $number,
        password        => Sensitive($password),
        bash_profile    => template('accounts/bash-profile'), # Indien van toepassing
        bashrc          => template('accounts/bashrc'), # Indien van toepassing
        bash_aliases    => template('accounts/bash-aliases'), # Indien van toepassing
        authorized_keys => $authorized_keys,
        groups          => ['wheel'] # Gebruik groep 'wheel' alleen als gebruiker ook moet kunnen 'su'en
    }   

```

## Nginx

Dit onderdeel maakt het mogelijk om een webserver op te zetten op basis van het Nginx-pakket. Wanneer in `Basisinstellingen` de Nginx APT-repo is geactiveerd, probeert deze sectie de nieuwste Nginx-versie te installeren in plaats van de standaardversie die wordt aangeboden door het besturingssysteem. Ik raad aan om de nieuwste versie te gebruiken om nieuwe technologieën zoals `IPv6` en `HTTP3` te ondersteunen.

### Voorbeeld

```puppet
node 'webserver.dev.xxxx.nl' {

    /* Setup Nginx */
    class { 'nginx':
        target  => 'helpers',
        require => Class['basic_settings']
    }

    /* Creëer Nginx-server voor Unifi */
    nginx::server { 'unifi':
        docroot                 => undef,
        server_name             => 'unifi.xxxx.nl',
        http_enable             => true,
        http_ipv6               => false,
        https_enable            => true,
        https_ipv6              => false,
        https_force             => true,
        http2_enable            => true,
        http3_enable            => true,
        fastopen                => 64, # Globaal, werkt ook voor andere servers
        reuseport               => true, # Globaal, werkt ook voor andere servers
        ssl_certificate         => '/etc/letsencrypt/live/unifi.xxxx.nl/fullchain.pem',
        ssl_certificate_key     => '/etc/letsencrypt/live/unifi.xxxx.nl/privkey.pem',
        php_fpm_enable          => false,
        try_files_enable        => false,
        location_directives     => [
            'proxy_pass https://localhost:8443/; # De Unifi Controller-poort',
            'proxy_set_header Host $host;',
            'proxy_set_header X-Real-IP $remote_addr;',
            'proxy_set_header X-Forward-For $proxy_add_x_forwarded_for;',
        ],
        access_log              => '/var/log/nginx/unifi_access.log combined buffer=32k flush=1m',
        error_log               => '/var/log/nginx/unifi_error.log',
        locations               => [
            {
                path                    => '/wss/',
                location_directives     => [
                    '# Nodig om de websockets goed door te sturen.',
                    '# Informatie overgenomen van hier: https://community.ubnt.com/t5/EdgeMAX/Access-Edgemax-gui-via-nginx-reverse-proxy-websocket-problem/td-p/1544354',
                    'proxy_pass https://localhost:8443;',
                    'proxy_http_version 1.1;',
                    'proxy_buffering off;',
                    'proxy_set_header Upgrade $http_upgrade;',
                    'proxy_set_header Connection "Upgrade";',
                    'proxy_read_timeout 86400;'
                ]
            }
        ],
        directives              => [
            '# Unifi gebruikt intern nog steeds zijn eigen certificaat. Dit is omgezet naar PEM en',
            '# wordt vertrouwd voor dit proxydoel. Zie hier voor details:',
            '# https://community.ubnt.com/t5/UniFi-Wireless/Lets-Encrypt-and-UniFi-controller/td-p/1406670',
            'ssl_trusted_certificate /etc/nginx/ssl/unifi.pem;',
            '# Beheerd door Certbot',
            'include /etc/letsencrypt/options-ssl-nginx.conf;'
        ]
    }
}
```