# Tooltests

Met de tests onder `.tools/tests/` controleer je het gedrag van de tools in deze repository. Iedere tool heeft een eigen submap. De lintertests staan in [`lint/`](lint/) en controleren onder meer lintmeldingen, geldige invoer, het laden van configuratie en plugins, bestandsselectie en gebruik vanuit een ander project.

Deze handleiding helpt je de tests uit te voeren, fouten te onderzoeken en tests toe te voegen. Wil je Puppet-code met de linter controleren, volg dan de [lint-README](../lint/README.md#code-controleren).

## Inhoudsopgave

- [Benodigde omgeving](#benodigde-omgeving)
- [Tests uitvoeren](#tests-uitvoeren)
  - [Alleen de linter testen](#alleen-de-linter-testen)
  - [Een testfout onderzoeken](#een-testfout-onderzoeken)
- [Tests toevoegen](#tests-toevoegen)
  - [Bepalen waar een test hoort](#bepalen-waar-een-test-hoort)
  - [Een nieuwe tool toevoegen](#een-nieuwe-tool-toevoegen)
  - [Helpers en testgegevens](#helpers-en-testgegevens)

## Benodigde omgeving

Gebruik een volledige checkout van deze repository, Git, de nieuwste stabiele Ruby en de nieuwste stabiele Bundler. Volg de [installatiestappen in de lint-README](../lint/README.md#installatie) om de ontwikkelomgeving in te richten. De tests gebruiken dezelfde Gemfile en lockfile als de linter.

Voer de commando's hieronder uit vanuit de hoofdmap van de repository. De tooltests gebruiken synthetische invoer en hebben geen productiegeheimen of verbindingen met beheerde servers nodig.

## Tests uitvoeren

Voer alle tooltests uit met:

```sh
bundle exec rake test
```

Rake zoekt naar `.tools/tests/**/*_test.rb` en neemt daarbij alle toolsubmappen en hun onderliggende mappen mee. Met `bundle exec rake` zonder taaknaam voer je dezelfde tests uit. De uitvoer vermeldt hoeveel tests zijn uitgevoerd en of er fouten of overgeslagen tests zijn. Bij een testfout geeft het commando een exitcode ongelijk aan 0 terug, waardoor ook de CI-stap mislukt.

### Alleen de linter testen

Wil je tijdens het ontwikkelen alleen de lintertests uitvoeren, gebruik dan:

```sh
bundle exec rake test:lint
```

Deze taak zoekt uitsluitend onder `.tools/tests/lint/**/*_test.rb`. Op dit moment voeren `test` en `test:lint` dezelfde tests uit, omdat alleen de linter een testsuite heeft. Zodra je tests voor een andere tool toevoegt, neemt `test` die automatisch mee. `test:lint` blijft beperkt tot de linter.

### Een testfout onderzoeken

Bekijk de genoemde test en vergelijk het verwachte resultaat met de uitvoer van de tool. Controleer welke invoer de test gebruikt en welk gedrag de assertion vastlegt. Herstel de oorzaak en voer de betreffende tests opnieuw uit. Sla een falende test niet over om de taak te laten slagen.

Puppet-lint voegt in GitHub Actions annotaties toe aan de gewone meldingen. De CLI-tests controleren beide uitvoervormen en tellen iedere lintmelding één keer. Wil je de hele testsuite lokaal met deze CI-uitvoer draaien, gebruik dan:

```sh
GITHUB_ACTION=synthetic_test bundle exec rake test
```

Stopt de taak voordat er tests worden uitgevoerd, controleer dan eerst de [installatie](../lint/README.md#installatie) en je werkmap. Controleer na het toevoegen of verplaatsen van tests ook of de verwachte tests daadwerkelijk zijn uitgevoerd; een geslaagde taak zonder tests is onvoldoende.

## Tests toevoegen

### Bepalen waar een test hoort

Voeg in deze repository alleen tests toe voor het gedrag van tools, onder `.tools/tests/<tool-name>/`. Kijk daarbij naar het gedrag dat de assertions controleren. Een Puppet-fragment waarmee je een lintmelding uitlokt, hoort bij de lintertests. Een controle van de resources die een module aanmaakt, hoort bij de afzonderlijke functionele validatie. Dat geldt ook voor algemene syntaxiscontroles en controles van templates, scripts en monitoringgedrag.

Gebruik voor die functionele validatie bestaande validators en tijdelijke controles buiten de repository. Leg de uitgevoerde commando's en resultaten vast in de review. Maak hiervoor geen testmap of losse testbestanden in de repositoryroot of bij een module, en neem de controles niet via helpers of taakafhankelijkheden op in de tooltests. De [testafspraken in `AGENTS.md`](../../AGENTS.md#test-scope) beschrijven deze afbakening. Met `bundle exec puppet-lint --no-config --config .puppet-lint.rc .` controleer je de projectcode volgens de [centrale configuratieroute](../lint/README.md#werking-van-de-controles).

### Een nieuwe tool toevoegen

Maak `.tools/tests/<tool-name>/` aan zodra je tests voor een nieuwe tool toevoegt. Gebruik Minitest en geef Rubybestanden met tests een naam die eindigt op `_test.rb`. Rake neemt die bestanden automatisch mee in `test`; daarvoor hoef je het Rakefile niet aan te passen.

Laat de tests de echte toolimplementatie gebruiken. De lintertests controleren bijvoorbeeld de code onder [`.tools/lint/`](../lint/). Bewaar geen tweede implementatie in de testmap. Voor een integratietest mag je wel tijdelijk een kopie maken, bijvoorbeeld om gebruik vanuit een ander project na te bootsen.

### Helpers en testgegevens

Bewaar helpers en fixtures, de invoerbestanden voor je tests, bij de betreffende tool. Laad de benodigde afhankelijkheden via een lokale `test_helper.rb`. Voeg pas een gedeelde helper toe als meerdere tools die daadwerkelijk gebruiken. Een algemene helper mag niet vanzelf de linter laden voor tests van andere tools.

De lintertests maken hun synthetische invoer nu in tijdelijke mappen aan en ruimen die na afloop op. Voeg je opgeslagen fixtures met bewust ongeldige Puppet-code toe, sluit dan alleen die fixturepaden uit van de gewone lintscan. Controleer daarbij dat de eigen projectcode meegenomen blijft.
