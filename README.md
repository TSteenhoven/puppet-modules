# Puppet-modules
Welkom bij mijn Puppet-modules project. Dit is een uitgebreide module voor je Puppet-omgeving, bestaande uit verschillende onderdelen: `Basic settings`, `Nginx`, `PHP`, `MySQL`, `SSH`, en `RabbitMQ`. Deze onderdelen kunnen afzonderlijk of in combinatie worden gebruikt om je infrastructuur te verbeteren. Om deze uitbreiding mogelijk te maken, vertrouw ik op andere Puppet-modules, die ik heb toegevoegd als git-submodules. Ik wil graag de makers van [debconf](https://github.com/smoeding/puppet-debconf.git), [reboot](https://github.com/puppetlabs/puppetlabs-reboot.git), [stdlib](https://github.com/puppetlabs/puppetlabs-stdlib.git) en [timezone](https://github.com/saz/puppet-timezone.git) bedanken voor hun waardevolle bijdragen.

:warning: **Compatibiliteit**: Deze uitbreidingsmodule is ontworpen voor 64-bits besturingssystemen.

## Beveiligingsaanpassingen
Binnen de verschillende onderdelen heb ik diverse beveiligingsverbeteringen geïmplementeerd, ook wel bekend als [hardening](https://en.wikipedia.org/wiki/Hardening_(computing)). Dit kan leiden tot afwijkend gedrag van softwarepakketten ten opzichte van de oorspronkelijke verwachtingen. Voorbeelden hiervan zijn extra opties in systemd zoals `PrivateTmp: true`, `ProtectHome: true` en `ProtectSystem: full`, en aanpassingen aan GRUB zodat de kernel bij het opstarten in een hardening modus draait. Ook zijn PAM-instellingen zo aangepast dat bestanden via umask 0077 worden aangemaakt. Ik wil madaidan en zijn pagina [linux-hardening](https://madaidans-insecurities.github.io/guides/linux-hardening.html) bedanken voor de waardevolle tips; een groot deel van deze informatie heb ik als inspiratie gebruikt.

Hoewel vergelijkbare maatregelen door softwareleveranciers en Linux-distributies (zoals [Fedora](https://discussion.fedoraproject.org/t/f40-change-proposal-systemd-security-hardening-system-wide/96423/11)) worden toegepast, kies ik ervoor om deze aanpassingen ook in Puppet op te nemen. Dit is omdat niet alle distributies altijd de meest recente versie van de software gebruiken en er altijd een kans bestaat dat een specifieke beveiligingsaanpassing niet is doorgevoerd.

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

Controleer of de uitbreidingsmodule met submodules correct is ingeladen met de volgende opdracht:

```bash
puppet module list
```

## Basic settings

Dit onderdeel bestaat uit subonderdelen die afzonderlijk kunnen worden toegepast zonder de hoofdklasse te gebruiken. Wanneer de hoofdklasse wordt aangeroepen, worden deze subonderdelen daarin geconfigureerd. Het doel van deze sectie is om een [headless server](https://en.wikipedia.org/wiki/Headless_computer) op te zetten met minimale GUI/UI-pakketten, om zo het verbruik van resources te minimaliseren. Daarnaast worden de serverinstellingen geoptimaliseerd voor High-performance computing ([HPC](https://en.wikipedia.org/wiki/High-performance_computing)).

Onnodige pakketten, zoals die voor energiebeheer op laptops, worden verwijderd omdat ze niet relevant zijn voor een serveromgeving. Pakketten zoals `mtr` en `rsync` worden daarentegen wel geïnstalleerd omdat ze vaak nodig zijn voor systeembeheerders. Ook worden beveiligingspakketten zoals `apparmor` en `auditd` geïnstalleerd om de server te beveiligen en te monitoren op verdachte activiteiten.

:warning: **Sudo**: Wanneer `basic settings` gebruikt in een (bestaande) server waarin al sudo configuratie is toegepast, raad ik aan om de optie `sudoers_dir_enable` op `false` te zetten. Hierdoor blijft de bestaande configuratie behouden.

Basic settings omvatten de volgende subonderdelen:

- **Development:** Pakketten/configuraties gerelateerd aan ontwikkeling.
- **IO:** Pakketten/configuraties gerelateerd aan opslag, uitschakelen van floppy's, etc.
- **Kernel:** Pakketten/configuraties gerelateerd aan de kernel en optimalisatie ervan voor HPC-gebruik.
- **Locale:** Pakketten/configuraties gerelateerd aan taalinstellingen.
- **Login:** Pakketten/configuraties gerelateerd aan login en gebruikersbeheer.
- **Netwerk:** Pakketten/configuraties gerelateerd aan netwerken en optimalisatie ervan voor HPC-gebruik.
- **Packages:** Installeren van een pakketbeheerder en het verwijderen van andere pakketbeheerders indien mogelijk.
  - **Packages MongoDB:** Configureren van APT-repo voor MongoDB met bijbehorende sleutel.
  - **Packages MySQL:** Configureren van APT-repo voor MySQL met bijbehorende sleutel.
  - **Packages Nginx:** Configureren van APT-repo voor Nginx met bijbehorende sleutel.
  - **Packages Node:** Configureren en installeren van APT-repo voor Node.
  - **Packages Proxmox:** Configureren van APT-repo voor Proxmox met bijbehorende sleutel.
  - **Packages RabbitMQ:** Configureren van APT-repo voor RabbitMQ met bijbehorende sleutel.
  - **Packages Sury:** Configureren van APT-repo voor Sury met bijbehorende sleutel.
- **Pro:** Voor Ubuntu is het mogelijk om een Pro-abonnement af te nemen.
- **Puppet:** Configureren van Puppet op de juiste manier.
- **Security:** Installeren van benodigde beveiligingspakketten om de server te monitoren.
- **Systemd:** Installeren van systemd en zorgen voor de juiste systeemdoelconfiguratie.
- **Timezone:** Configureren van tijd/datum.

### Voorbeelden

In het onderstaande voorbeeld zie je hoe `basic settings` kan worden aangeroepen:

```puppet
node 'webserver.dev.xxxx.nl' {
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
node 'webserver.dev.xxxx.nl' {
    /* Uncomment dit stukje code wanneer je hoofdclass basic settings niet gebruikt */
    <!-- class { 'basic_settings::login':
        mail_to             => $systemd_notify_mail,
        server_fdqn         => $server_fdqn,
        sudoers_dir_enable  => $sudoers_dir_enable
    } -->

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
}
```

## MySQL

MySQL is een populair open-source relationeel databasebeheersysteem (RDBMS). Het wordt veel gebruikt voor het opslaan, ophalen en beheren van gegevens voor websites en applicaties. Dit onderdeel maakt het mogelijk om een MySQL-database server op te zetten en te configureren. Wanneer in `basic settings` de MySQL APT-repo is geactiveerd, probeert dit onderdeel de geselecteerde MySQL-versie te installeren in plaats van de standaardversie of databasevariant zoals MariaDB die vanuit het besturingssysteem wordt aangeboden. Indien `basic settings` of `security` subonderdelen van `basic package` wordt gebruikt, worden verdachte commando's gemonitord door auditd.

### Voorbeeld
Hieronder een voorbeeld hoe je MySQL database opzet in je Puppet omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {
    /* Setup MySQL */
    class { 'mysql':
        root_password   => 'mypassword'
    }

    /* Maak database www aan */
    mysql::database { 'www':
        ensure => present
    }

    /* Maak een databasegebruiker aan en verleen alle machtigingen aan de database */
    mysql::user { 'www':
        ensure  => present,
        username  => 'www',
        password  => 'mypassword'
    }
    ->
    mysql::grant { 'www':
        ensure  => present,
        username  => 'www',
        database  => 'www'
    }
}
```

## Nginx

Nginx is een populaire open-source webserver en reverse proxy server. Het staat bekend om zijn hoge prestaties, stabiliteit en lage resourcegebruik, waardoor het geschikt is voor het bedienen van statische en dynamische websites, het balanceren van load en het functioneren als mail proxy server. Dit onderdeel maakt het mogelijk om een Nginx-webserver te installeren en te configureren. Indien `basic settings` wordt gebruikt, zal Nginx worden geconfigureerd volgens de aanbevelingen van harde beveiliging. Dit kan bijvoorbeeld inhouden dat specifieke systemd-opties worden ingeschakeld of dat de kernel zo wordt geconfigureerd dat de meest optimale beveiligde versie wordt gebruikt.

### Voorbeeld
Hieronder een voorbeeld hoe je een Nginx-webserver opzet in je Puppet omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {

    /* Setup Nginx */
    class { 'nginx':
        target  => 'helpers',
        require => Class['mysql'] # Indien MySQL ook geïnstalleerd is op de server
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

## PHP

PHP is een veelgebruikte open-source scriptingtaal die speciaal is ontworpen voor webontwikkeling. Het wordt vaak gebruikt in combinatie met een webserver zoals Apache of Nginx om dynamische inhoud op webpagina's te genereren. Dit onderdeel maakt het mogelijk om PHP te installeren en te configureren. Wanneer `basic settings` wordt gebruikt, zal PHP worden geconfigureerd volgens de aanbevelingen van harde beveiliging.

### Voorbeeld
Hieronder een voorbeeld hoe je PHP configureert in je Puppet omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {

    /* Standaard PHP instellingen */
    $php_settings = {
        'opcache.enable'                    => 1,
        'opcache.enable_cli'                => 0,
        'opcache.memory_consumption'        => 1024,
        'opcache.interned_strings_buffer'   => 64,
        'opcache.max_accelerated_files'     => 100000,
        'opcache.max_wasted_percentage'     => 30,
        'opcache.fast_shutdown'             => 1,
        'opcache.validate_timestamps'       => 1,
        'opcache.revalidate_freq'           => 60,
        'opcache.save_comments'             => 0,
        'max_execution_time'                => $fastcgi_read_timeout,
        'post_max_size'                     => '20M',
        'upload_max_filesize'               => '20M',
        'memory_limit'                      => '128M',
        'date.timezone'                     => $timezone
    }

    /* Standaard PHP-FPM instellingen */
    $php_fpm_settings = {
        'request_terminate_timeout' => $fastcgi_read_timeout
    }

    /* Setup PHP8 */
    class { 'php8':
        curl            => true,
        gd              => true,
        mbstring        => true,
        mysql           => true,
        xml             => true,
        minor_version   => '3',
        require         => Class['basic_settings']
    }

    /* PHP 8 cli */
    class {'php8::cli':
        ini_settings    => $php_settings,
        require         => Class['basic_settings']
    }

    /* PHP 8 fpm */
    class {'php8::fpm':
        ini_settings    => stdlib::merge($php_settings, $php_fpm_settings),
        require         => Class['nginx'] # Indien Nginx ook geïnstalleerd is op de server
    }
}
```

## SSH

SSH (Secure Shell) is een cryptografisch netwerkprotocol voor veilige gegevenscommunicatie, remote shell services of command execution, en andere beveiligde netwerkdiensten tussen twee netwerkcomputers. Dit onderdeel maakt het mogelijk om OpenSSH te configureren volgens de aanbevelingen van harde beveiliging. Dit omvat onder andere het uitschakelen van root login, het beperken van het aantal toegestane authenticatiepogingen en het configureren van key-based authenticatie.

### Voorbeeld
Hieronder een voorbeeld hoe je SSH configureert in je Puppet omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {

    class { 'ssh':
        password_authentication_users   => $users_external,
        allow_users                     => $allow_ssh,
    }
}
```

## RabbitMQ

RabbitMQ is een open-source berichtensysteem dat werkt volgens het Advanced Message Queuing Protocol (AMQP). Het wordt vaak gebruikt voor het beheren en afhandelen van berichten tussen verschillende applicaties of componenten binnen een gedistribueerd systeem. RabbitMQ zorgt ervoor dat berichten betrouwbaar en asynchroon kunnen worden uitgewisseld, wat essentieel is voor schaalbare en robuuste applicaties. Dit onderdeel maakt het mogelijk om RabbitMQ te installeren en te configureren.

### Voorbeeld
Hieronder een voorbeeld hoe je RabbitMQ configureert in je Puppet omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {

    /* Setup RabbitMQ */
    class { 'rabbitmq':
        target => 'production',
        require => Class['basic_settings']
    }

    /* Setup rabbitmq TLS */
    class { 'rabbitmq::tcp':
        ssl_ca_certificate      => '/etc/letsencrypt/live/rabbitmq.xxxx.nl/ca_cert.pem',
        ssl_certificate         => '/etc/letsencrypt/live/rabbitmq.xxxx.nl/cert.pem',
        ssl_certificate_key     => '/etc/letsencrypt/live/rabbitmq.xxxx.nl/privkey.pem'
    }

    /* Setup rabbitmq management */
    class { 'rabbitmq::management':
        admin_password      => 'wachtwoord',
        default_queue_type  => 'quorum',
        require             => Class['rabbitmq::tcp']
    }
    rabbitmq::management_exange { 'failure_exchange':
        require => Class['rabbitmq::management']
    }
    rabbitmq::management_queue { 'failure_messages':
        type    => 'quorum',
        require => Rabbitmq::Management_exange['failure_exchange']
    }
    rabbitmq::management_queue { 'result_messages':
        arguments => {
            'x-dead-letter-exchange'    => 'failure_exchange',
            'x-dead-letter-routing-key' => 'failure_messages'
        },
        type    => 'quorum',
        require => Rabbitmq::Management_exange['failure_exchange']
    }
    rabbitmq::management_binding { 'failure_binding':
        source          => 'failure_exchange',
        destination     => 'failure_messages',
        routing_key     => 'failure_exchange',
        require         => Rabbitmq::Management_exange['failure_exchange']
    }

    /* Setup user */
    rabbitmq::management_user { 'bookkeeper':
        password    => 'wachtwoord',
        tags        => undef,
        require     => Class['accounts']
    }
    rabbitmq::management_user_permissions { 'bookkeeper_default':
        user        => 'bookkeeper',
        configure   => '',
        write       => '.*',
        read        => '.*'
    }
}
```

## Contributie
Contributies zijn welkom! Voel je vrij om pull requests in te dienen of problemen te melden via GitHub.