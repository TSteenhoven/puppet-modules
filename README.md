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

:warning: **Compatibiliteit**: Wanneer Basic settings gebruikt in een (bestaande) server waarin al sudo configuratie is toegepast, raad ik aan om de optie `sudoers_dir_enable` op `false` te zetten. Hierdoor blijft de bestaande configuratie behouden.

Basic settings omvatten de volgende subonderdelen:

- **Development:** Pakketten/configuraties gerelateerd aan ontwikkeling.
- **IO:** Pakketten/configuraties gerelateerd aan opslag, uitschakelen van floppy's, etc.
- **Kernel:** Pakketten/configuraties gerelateerd aan de kernel en optimalisatie ervan voor HPC-gebruik.
- **Locale:** Pakketten/configuraties gerelateerd aan taalinstellingen.
- **Login:** Pakketten/configuraties gerelateerd aan login en gebruikersbeheer.
- **Netwerk:** Pakketten/configuraties gerelateerd aan netwerken en optimalisatie ervan voor HPC-gebruik.
- **Packages:** Installeren van een pakketbeheerder en het verwijderen van andere pakketbeheerders indien mogelijk.
  - **Packages MySQL:** Configureren van APT-repo voor MySQL met bijbehorende sleutel.
  - **Packages Node:** Configureren en installeren van APT-repo voor Node.
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
# Uncomment dit stukje code wanneer je hoofdclass basic settings niet gebruikt
# class { 'basic_settings::login':
#     mail_to             => $systemd_notify_mail,
#     server_fdqn         => $server_fdqn,
#     sudoers_dir_enable  => $sudoers_dir_enable
# }

# Maak gebruiker
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

## MySQL

MySQL is een populair open-source relationeel databasebeheersysteem (RDBMS). Het wordt veel gebruikt voor het opslaan, ophalen en beheren van gegevens voor websites en applicaties. Dit onderdeel maakt het mogelijk om een MySQL-database server op te zetten en te configureren. Wanneer in `basic settings` de MySQL APT-repo is geactiveerd, probeert dit onderdeel de geselecteerde MySQL-versie te installeren in plaats van de standaardversie of databasevariant zoals MariaDB die vanuit het besturingssysteem wordt aangeboden. Indien `basic settings` of `security package` van `basic package` wordt gebruikt, worden verdachte commando's gemonitord door auditd.

### Voorbeeld
Hieronder een voorbeeld hoe je MySQL database opzet in je Puppet omgeving:

```puppet
# Setup MySQL
class { 'mysql':
    root_password   => 'mypassword'
}

# Maak database www aan
mysql::database { 'www':
    ensure => present
}

# Maak een databasegebruiker aan en verleen alle machtigingen aan de database
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
```

## Nginx

Nginx is een populaire open-source webserver en reverse proxy server. Het staat bekend om zijn hoge prestaties, stabiliteit en lage resourcegebruik, waardoor het geschikt is voor het bedienen van statische en

 dynamische websites, het balanceren van load en het functioneren als mail proxy server. Dit onderdeel maakt het mogelijk om een Nginx-webserver te installeren en te configureren. Indien `basic settings` wordt gebruikt, zal Nginx worden geconfigureerd volgens de aanbevelingen van harde beveiliging. Dit kan bijvoorbeeld inhouden dat specifieke systemd-opties worden ingeschakeld of dat de kernel zo wordt geconfigureerd dat de meest optimale beveiligde versie wordt gebruikt.

### Voorbeeld
Hieronder een voorbeeld hoe je een Nginx-webserver opzet in je Puppet omgeving:

```puppet
# Setup Nginx
class { 'nginx':
    ensure => present
}

# Maak een configuratiebestand aan voor een nieuwe website
nginx::resource::vhost { 'example.com':
    ensure  => present,
    www_root => '/var/www/example.com',
    listen_port => 80
}
```

## PHP

PHP is een veelgebruikte open-source scriptingtaal die speciaal is ontworpen voor webontwikkeling. Het wordt vaak gebruikt in combinatie met een webserver zoals Apache of Nginx om dynamische inhoud op webpagina's te genereren. Dit onderdeel maakt het mogelijk om PHP te installeren en te configureren. Wanneer `basic settings` wordt gebruikt, zal PHP worden geconfigureerd volgens de aanbevelingen van harde beveiliging.

### Voorbeeld
Hieronder een voorbeeld hoe je PHP configureert in je Puppet omgeving:

```puppet
# Setup PHP
class { 'php':
    ensure => present
}

# Installeer extra PHP-modules indien nodig
php::module { 'mysqli':
    ensure => present
}
```

## SSH

SSH (Secure Shell) is een cryptografisch netwerkprotocol voor veilige gegevenscommunicatie, remote shell services of command execution, en andere beveiligde netwerkdiensten tussen twee netwerkcomputers. Dit onderdeel maakt het mogelijk om OpenSSH te configureren volgens de aanbevelingen van harde beveiliging. Dit omvat onder andere het uitschakelen van root login, het beperken van het aantal toegestane authenticatiepogingen en het configureren van key-based authenticatie.

### Voorbeeld
Hieronder een voorbeeld hoe je SSH configureert in je Puppet omgeving:

```puppet
class { 'ssh':
    permit_root_login       => 'no',
    password_authentication => 'no',
    allow_users             => ['user1', 'user2']
}
```

## RabbitMQ

RabbitMQ is een open-source berichtensysteem dat werkt volgens het Advanced Message Queuing Protocol (AMQP). Het wordt vaak gebruikt voor het beheren en afhandelen van berichten tussen verschillende applicaties of componenten binnen een gedistribueerd systeem. RabbitMQ zorgt ervoor dat berichten betrouwbaar en asynchroon kunnen worden uitgewisseld, wat essentieel is voor schaalbare en robuuste applicaties. Dit onderdeel maakt het mogelijk om RabbitMQ te installeren en te configureren.

### Voorbeeld
Hieronder een voorbeeld hoe je RabbitMQ configureert in je Puppet omgeving:

```puppet
# Setup RabbitMQ
class { 'rabbitmq':
    admin_enable => true,
    management_enable => true,
    ssl => true,
    ssl_key => '/path/to/key.pem',
    ssl_cert => '/path/to/cert.pem',
    ssl_cacert => '/path/to/cacert.pem'
}

# Voeg een RabbitMQ-gebruiker toe
rabbitmq::user { 'myuser':
    password => 'mypassword',
    admin    => true
}

# Voeg een RabbitMQ vhost toe
rabbitmq::vhost { 'myvhost':
    ensure => present
}

# Verleen de gebruiker toegang tot de vhost
rabbitmq::permission { 'myuser@myvhost':
    configure_permission => '.*',
    read_permission      => '.*',
    write_permission     => '.*'
}
```

## Contributie
Contributies zijn welkom! Voel je vrij om pull requests in te dienen of problemen te melden via GitHub.