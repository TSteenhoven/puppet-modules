# Puppet-modules #
Dit is een uitbreidingsmodule voor jouw Puppet-omgeving, bestaande uit verschillende onderdelen, namelijk `Basic Settings`, `Nginx`, `PHP` en `MySQL`. Deze onderdelen kunnen afzonderlijk worden gebruikt of in combinatie.

## Installeren ##
Ga naar de hoofdmap van je Git Puppet-omgeving en voeg de submodule toe met het volgende commando: `git submodule add https://github.com/DevSysEngineer/puppet-modules.git global-modules`. Voer vervolgens de volgende opdracht uit: `git submodule update --init --recursive`. Als alles goed gaat, wordt de uitbreidingsmodule nu correct ingeladen in jouw Puppet Git-project. Nu moet alleen de Puppetserver nog weten dat deze map bestaat. Ga naar de `environments` map, kies de betreffende omgeving (bijvoorbeeld `development`). In deze omgeving bevindt zich een `manifests` map. Maak naast deze map een bestand genaamd `environment.conf` aan en plak daarin de onderstaande configuratie:

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
Dit onderdeel bestaat uit subonderdelen die kunnen worden toegepast zonder de hoofdclass te gebruiken. Wanneer de hoofdclass wordt aangesproken, worden de subonderdelen daarin aangesproken en geconfigureerd. Het doel van dit onderdeel is om een headless server op te zetten met zo min mogelijk benodigde GUI-/UI-pakketten, zodat de server zo min mogelijk resources verbruikt. Onnodige pakketten, zoals die voor power management bij laptops, worden verwijderd omdat dit niets te maken heeft met een server. Daarnaast wordt door middel van kernelparameters de server aangepast zodat hij alle benodigde CPU-/powerresources mag benutten. Pakketten zoals mtr en rsync worden wel geïnstalleerd, omdat deze naar mijn mening regelmatig nodig zijn voor systeembeheerders.

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