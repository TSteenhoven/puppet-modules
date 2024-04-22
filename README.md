# Puppet-modules

Welkom bij mijn Puppet-modules project. Dit is een uitbreiding module voor je Puppet-omgeving, die bestaande uit verschillende onderdelen: `Basisinstellingen`, `Nginx`, `PHP`, `MySQL` en `SSH`. Deze onderdelen kunnen afzonderlijk of in combinatie worden gebruikt om je infrastructuur te verbeteren. Om deze uitbreiding mogelijk te maken, vertrouw ik op andere Puppet-modules, die ik heb toegevoegd als git-submodules. Ik wil de makers van [debconf](https://github.com/smoeding/puppet-debconf.git), [reboot](https://github.com/puppetlabs/puppetlabs-reboot.git), [stdlib](https://github.com/puppetlabs/puppetlabs-stdlib.git) en [timezone](https://github.com/saz/puppet-timezone.git) bedanken voor hun waardevolle bijdragen.

Het is belangrijk op te merken dat ik binnen deze modules verschillende beveiligingsverbeteringen heb geïmplementeerd, wat kan leiden tot verschillende gedragingen van softwarepakketten dan oorspronkelijk verwacht. Zo krijgen sommige softwarepakketten nu via systemd extra opties, zoals `PrivateTmp: true`, `ProtectHome: true` en `ProtectSystem: full`, waardoor ze in een sandboxomgeving worden geplaatst. Mocht je problemen ondervinden, aarzel dan niet om contact met ons op te nemen.

:warning: **64-bits**: Deze uitbreidingsmodule gaat ervan uit dat je besturingssysteem 64-bits is.

## Installatie

Navigeer naar de hoofdmap van je Git Puppet-omgeving en voeg de submodule toe met het volgende commando:

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

## Basisinstellingen

Dit onderdeel bestaat uit subonderdelen die kunnen worden toegepast zonder de hoofdclass te gebruiken. Wanneer de hoofdklasse wordt aangeroepen, worden deze subonderdelen daarin aangesproken en geconfigureerd. Het doel van deze sectie is om een [headless server](https://en.wikipedia.org/wiki/Headless_computer) op te zetten met minimale GUI/UI-pakketten, om zo het verbruik van resources te minimaliseren. Bovendien wordt de server aangepast door middel van kernelparameters om alle benodigde CPU-/powerresources te benutten voor High-performance computing ([HPC](https://en.wikipedia.org/wiki/High-performance_computing))

Onnodige pakketten, zoals die voor energiebeheer op laptops, worden verwijderd omdat ze niet relevant zijn voor een serveromgeving. Pakketten zoals `mtr` en `rsync` worden daarintegen wel geïnstalleerd omdat ze vaak nodig zijn voor systeembeheerders. Daarnaast worden beveiligingspakketten zoals `apparmor` en `auditd` geïnstalleerd om de server te beveiligen en te monitoren op verdachte activiteiten.

Basisinstellingen omvatten de volgende subonderdelen:
- **Development:** Pakketten/configuraties gerelateerd aan ontwikkeling.
- **IO:** Pakketten/configuraties gerelateerd aan opslag, uitschakelen van floppy's, etc.
- **Kernel:** Pakketten/configuraties gerelateerd aan de kernel en optimalisatie ervan voor HPC-gebruik.
- **Locale:** Pakketten/configuraties gerelateerd aan taalinstellingen. Mijn voorkeur gaat uit naar het standaard verwijderen hiervan.
- **Netwerk:** Pakketten/configuraties gerelateerd aan netwerken en optimalisatie ervan voor HPC-gebruik.
- **Packages:** Installeren van een pakketbeheerder en het verwijderen van andere pakketbeheerders indien mogelijk.
    - **Packages MySQL:** Configureren van APT-repo voor MySQL met bijbehorende sleutel.
    - **Packages Node:** Configureren en installeren van APT-repo voor Node.
- **Pro:** Voor Ubuntu is het mogelijk om een Pro-abonnement af te nemen. Dit subonderdeel zorgt ervoor dat alle benodigde pakketten zijn geïnstalleerd.
- **Puppet:** Configureren van Puppet op de juiste manier.
- **Security:** Installeren van benodigde beveiligingspakketten om de server te monitoren.
- **Systemd:** Installeren van systemd en zorgen voor de juiste systeemdoelconfiguratie.
- **Timezone:** Configureren van tijd/datum.
- **User:** Pakketten/configuraties gerelateerd aan gebruikersbeheer.

### Voorbeeld

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

    /* Create Nginx server for Unifi */
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
        fastopen                => 64, # Global, works also for other servers
        reuseport               => true, # Global, works also for other servers
        ssl_certificate         => '/etc/letsencrypt/live/unifi.xxxx.nl/fullchain.pem',
        ssl_certificate_key     => '/etc/letsencrypt/live/unifi.xxxx.nl/privkey.pem',
        php_fpm_enable          => false,
        try_files_enable        => false,
        location_directives     => [
            'proxy_pass https://localhost:8443/; # The Unifi Controller Port',
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
                    '# Needed to allow the websockets to forward well.',
                    '# Information adopted from here: https://community.ubnt.com/t5/EdgeMAX/Access-Edgemax-gui-via-nginx-reverse-proxy-websocket-problem/td-p/1544354',
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
            '# Unifi still internally uses its own cert. This was converted to PEM and',
            '# is trusted for the sake of this proxy. See here for details:',
            '# https://community.ubnt.com/t5/UniFi-Wireless/Lets-Encrypt-and-UniFi-controller/td-p/1406670',
            'ssl_trusted_certificate /etc/nginx/ssl/unifi.pem;',
            '# Managed by Certbot',
            'include /etc/letsencrypt/options-ssl-nginx.conf;'
        ]
    }
}
```