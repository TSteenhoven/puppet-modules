# Puppet-modules

Dit is een uitbreidingsmodule voor jouw Puppet-omgeving, bestaande uit verschillende onderdelen: `Basic Settings`, `Nginx`, `PHP` en `MySQL`. Deze onderdelen kunnen afzonderlijk worden gebruikt of in combinatie. Om deze uitbreidingsmodule mogelijk te maken, vertrouw ik op andere Puppet-modules, die ik via git submodule heb toegevoegd. Ik wil de eigenaren van [debconf](https://github.com/smoeding/puppet-debconf.git), [reboot](https://github.com/puppetlabs/puppetlabs-reboot.git), [stdlib](https://github.com/puppetlabs/puppetlabs-stdlib.git) en [timezone](https://github.com/saz/puppet-timezone.git) bedanken voor hun werk.

## Installeren

Navigeer naar de hoofdmap van je Git Puppet-omgeving en voeg de submodule toe met het volgende commando:

```bash
git submodule add https://github.com/DevSysEngineer/puppet-modules.git global-modules
```

Voer vervolgens de volgende opdracht uit:

```bash
git submodule update --init --recursive
```

Als alles goed gaat, wordt de uitbreidingsmodule nu correct ingeladen in jouw Puppet Git-project. Nu moet alleen de Puppetserver nog weten dat deze map bestaat. Ga naar de `environments` map, kies de betreffende omgeving (bijvoorbeeld `development`). In deze omgeving bevindt zich een `manifests` map. Maak naast deze map een bestand genaamd `environment.conf` aan en plak daarin de onderstaande configuratie:

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

Via de onderstaande opdracht kun je controleren of de uitbreidingsmodule met daarbij subonderdelen correct is ingeladen:
```bash
puppet module list
```

## Basic Settings

Dit onderdeel bestaat uit subonderdelen die kunnen worden toegepast zonder de hoofdclass te gebruiken. Wanneer de hoofdclass wordt aangesproken, worden de subonderdelen daarin aangesproken en geconfigureerd. Het doel van dit onderdeel is om een [headless server](https://en.wikipedia.org/wiki/Headless_computer) op te zetten met zo min mogelijk benodigde GUI-/UI-pakketten, zodat de server zo min mogelijk resources verbruikt. Onnodige pakketten, zoals die voor power management bij laptops, worden verwijderd omdat dit niets te maken heeft met een server. Daarnaast wordt door middel van kernelparameters de server aangepast zodat hij alle benodigde CPU-/powerresources mag benutten voor High-performance computing ([HPC](https://en.wikipedia.org/wiki/High-performance_computing)). Pakketten zoals `mtr` en `rsync` worden wel geïnstalleerd, omdat deze naar mijn mening regelmatig nodig zijn voor systeembeheerders. Daarnaast worden er ook security pakketen geïnstalleerd zoals `apparmor` en `auditd` om de server te beveiligen en te kunnen monitoren op verdachte activiteiten.

Basic Settings bestaat uit de volgende subonderdelen:
- **Development:** Pakketen / configuraties die te maken hebben met development
- **IO:** Pakketen / configuraties die te maken hebben met opslag, het uitschakelen van floppy etc.
- **Kernel:** Pakketen / configuraties die te maken hebben met de kernel en de kernel/sysctl optimaal configureren voor HPC gebruik.
- **Locale:** Pakketen / configuraties die te maken hebben met taal. Mijn voorkeur heeft het om standaard dit te verwijderen.
- **Netwerk:** Pakketen / configuraties die te maken hebben met netwerk en deze optimaal configureren voor HPC gebruik.
- **Packages:** Installeren van package manager en overige package manager deinstalleren indien dat mogelijk is.
    - **Packages MySQL:** APT repo voor MySQL configureren met bijbehorende key.
- **Pro:** Bij Ubuntu is het mogelijk om een Pro abonnement af te nemen, dit subonderdeel zorgt ervoor dat alle benodigde packages zijn geïnstalleerd.
- **Puppet:** Configureert Puppet op de juiste manier.
- **Security:** Installeert benodigde security pakketen om de server te monitoren.
- **Systemd:** Installeert systemd en zorgt ervoor dat de juiste system target geconfigureerd wordt.
- **Timezone:** Configureert tijd / datum.

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

Dit onderdeel maakt het mogelijk om een webserver op te zetten op basis van de Nginx package. Wanneer in `Basic Settings` de Nginx APT repo is geactiveerd, probeert dit onderdeel laatste Nginx-versie te installeren in plaats van de standaard Nginx-versie die wordt aangeboden vanuit het besturingssysteem. Ik raad aan om juist de nieuwste versie te gebruiken, omdat het onderdeel is gebouwd met het idee om nieuwe technologieën te ondersteunen zoals `IPv6` en `HTTP3`.

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