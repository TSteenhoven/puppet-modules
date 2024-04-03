# Puppet-modules #
Dit is een uitbreidingsmodule voor jouw Puppet-omgeving, bestaande uit verschillende onderdelen, namelijk `Basic Settings`, `Nginx`, `PHP` en `MySQL`. Deze onderdelen kunnen afzonderlijk worden gebruikt of in combinatie.

## Installeren ##
Ga naar de hoofdmap van je Git Puppet-omgeving en voeg de submodule toe met het volgende commando: 

```
git submodule add https://github.com/DevSysEngineer/puppet-modules.git global-modules
```

Voer vervolgens de volgende opdracht uit: 

```
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

## Basic Settings ##
Dit onderdeel bestaat uit subonderdelen die kunnen worden toegepast zonder de hoofdclass te gebruiken. Wanneer de hoofdclass wordt aangesproken, worden de subonderdelen daarin aangesproken en geconfigureerd. Het doel van dit onderdeel is om een [headless server](https://en.wikipedia.org/wiki/Headless_computer) op te zetten met zo min mogelijk benodigde GUI-/UI-pakketten, zodat de server zo min mogelijk resources verbruikt. Onnodige pakketten, zoals die voor power management bij laptops, worden verwijderd omdat dit niets te maken heeft met een server. Daarnaast wordt door middel van kernelparameters de server aangepast zodat hij alle benodigde CPU-/powerresources mag benutten voor High-performance computing ([HPC](https://en.wikipedia.org/wiki/High-performance_computing)). Pakketten zoals mtr en rsync worden wel geïnstalleerd, omdat deze naar mijn mening regelmatig nodig zijn voor systeembeheerders.

Basic Settings bestaat uit de volgende subonderdelen:
- **Development** Packages / configuraties die te maken hebben met development
- **IO** Packages / configuraties die te maken hebben met opslag, het uitschakelen van floppy etc
- **Kernel** Packages / configuraties die te maken hebben met de kernel en de kernel/sysctl optimaal configureren voor HPC gebruik
- **Locale** Packages / configuraties die te maken hebben met taal. Mijn voorkeur heeft het om standaard dit te verwijderen
- **Netwerk** Packages / configuraties die te maken hebben met netwerk en deze optimaal configureren voor HPC gebruik
- **Packages** Installeren van package manager en overige package manager deinstalleren indien dat mogelijk is
    - **Packages MySQL** APT repo voor MySQL configureren met bijbehorende key
- **Pro** Bij Ubuntu is het mogelijk om een Pro abonnement af te nemen, dit subonderdeel zorgt ervoor dat alle benodigde packages zijn geïnstalleerd
- **Puppet** Configureert Puppet op de juiste manier
- **Systemd** Installeert systemd en zorgt ervoor dat de juiste system target geconfigureerd wordt
- **Timezone**Configureert tijd / datum

### Voorbeeld ###
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