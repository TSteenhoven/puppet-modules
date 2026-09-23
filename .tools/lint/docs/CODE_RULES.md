# Puppet-coderegels en reviewcriteria

Dit bestand bevat de algemene Puppet-coderegels en handmatige reviewcriteria van dit project. Volg de toepasselijke regels bij iedere Puppet-wijziging. Raakt je wijziging commentaar, Puppet Strings of documentatie van Puppet-interfaces, pas dan daarnaast de relevante regels uit [DOCUMENTATION_RULES.md](DOCUMENTATION_RULES.md) toe.

Raakt je wijziging beheerde bestanden of mappen, eigenaarschap of rechten, beveiliging, systemd of services, shellcode of shelltemplates, runtime-tools of operationele dependencies, of monitoringchecks en hun registratie, volg dan ook de relevante regels uit [OPERATIONAL_RULES.md](OPERATIONAL_RULES.md). Beide aanvullende documenten kunnen tegelijk van toepassing zijn en vervangen deze algemene coderegels nooit.

De [linthandleiding](../README.md) beschrijft het gebruik, de installatie, de configuratie en het onderhoud van de tooling. Een groene lintscan bewijst niet dat alle handmatige regels zijn nageleefd. Ontbrekende automatische detectie vormt geen uitzondering op een regel.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Basisopmaak](#basisopmaak)
  - [Twee spaties per inspringniveau](#twee-spaties-per-inspringniveau)
  - [Inhoud direct na een openingsaccolade beginnen](#inhoud-direct-na-een-openingsaccolade-beginnen)
  - [Resourcepijlen uitlijnen](#resourcepijlen-uitlijnen)
  - [Aanhalingstekens bij stringinhoud kiezen](#aanhalingstekens-bij-stringinhoud-kiezen)
  - [Selectors vóór resources berekenen](#selectors-vóór-resources-berekenen)
  - [Functionele resourcevolgorde beoordelen](#functionele-resourcevolgorde-beoordelen)
    - [Gedeelde dekking van basisopmaak](#gedeelde-dekking-van-basisopmaak)
- [Inspringing](#inspringing)
    - [Verdieping bij Inspringing](#verdieping-bij-inspringing)
- [Komma's](#kommas)
  - [Spatie na komma’s](#spatie-na-kommas)
  - [Meerregelige lijsten met een komma afsluiten](#meerregelige-lijsten-met-een-komma-afsluiten)
    - [Verdieping bij Meerregelige lijsten met een komma afsluiten](#verdieping-bij-meerregelige-lijsten-met-een-komma-afsluiten)
- [Lange regels](#lange-regels)
    - [Verdieping bij Lange regels](#verdieping-bij-lange-regels)
  - [Alleen toegestane suppressions gebruiken](#alleen-toegestane-suppressions-gebruiken)
- [Parameters en resources](#parameters-en-resources)
  - [Parameters en instellingen](#parameters-en-instellingen)
  - [Classes en defines bruikbaar ontwerpen](#classes-en-defines-bruikbaar-ontwerpen)
  - [Herhaalde resourceorkestratie in defined types delen](#herhaalde-resourceorkestratie-in-defined-types-delen)
  - [Publieke parameters expliciet typeren](#publieke-parameters-expliciet-typeren)
  - [Parameters met defaultafhankelijkheden sorteren](#parameters-met-defaultafhankelijkheden-sorteren)
    - [Verdieping bij Parameters met defaultafhankelijkheden sorteren](#verdieping-bij-parameters-met-defaultafhankelijkheden-sorteren)
  - [Parameterblokken volledig uitlijnen](#parameterblokken-volledig-uitlijnen)
  - [Beveiligingsinstellingen met één waardekeuze modelleren](#beveiligingsinstellingen-met-één-waardekeuze-modelleren)
  - [Parameternamen op onderwerp kiezen](#parameternamen-op-onderwerp-kiezen)
  - [Voorwaarden en validatie](#voorwaarden-en-validatie)
  - [De grootste verwerking vóór de korte afhandeling plaatsen](#de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen)
    - [Verdieping bij De grootste verwerking vóór de korte afhandeling plaatsen](#verdieping-bij-de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen)
  - [Validatie om haar afhankelijke implementatie plaatsen](#validatie-om-haar-afhankelijke-implementatie-plaatsen)
  - [Ruwe en geërfde waarden in templates onderscheiden](#ruwe-en-geërfde-waarden-in-templates-onderscheiden)
  - [Optionele waarden alleen bij gebruik valideren](#optionele-waarden-alleen-bij-gebruik-valideren)
  - [Classcontroles hergebruiken](#classcontroles-hergebruiken)
    - [Verdieping bij Classcontroles hergebruiken](#verdieping-bij-classcontroles-hergebruiken)
  - [Parentclass als prerequisite controleren](#parentclass-als-prerequisite-controleren)
  - [Resources en afhankelijkheden](#resources-en-afhankelijkheden)
  - [Optionele resource-attributen vooraf bepalen](#optionele-resource-attributen-vooraf-bepalen)
  - [Arrays met concat combineren](#arrays-met-concat-combineren)
  - [Bestaande interfaces voor integratiewaarden gebruiken](#bestaande-interfaces-voor-integratiewaarden-gebruiken)
  - [Dependencies pas na een geslaagde controle koppelen](#dependencies-pas-na-een-geslaagde-controle-koppelen)
  - [Prerequisites van ordering onderscheiden](#prerequisites-van-ordering-onderscheiden)
  - [Packageafhankelijkheden bij externe commando’s](#packageafhankelijkheden-bij-externe-commandos)
    - [Optionele packages activeren met realize](#optionele-packages-activeren-met-realize)
  - [Gedeelde voorwaarden om resources groeperen](#gedeelde-voorwaarden-om-resources-groeperen)
  - [Aanroepen en publieke interfaces](#aanroepen-en-publieke-interfaces)
  - [Alle verplichte argumenten doorgeven](#alle-verplichte-argumenten-doorgeven)
    - [Verdieping bij Alle verplichte argumenten doorgeven](#verdieping-bij-alle-verplichte-argumenten-doorgeven)
  - [Overbodige parameterdoorgifte rechtstreeks schrijven](#overbodige-parameterdoorgifte-rechtstreeks-schrijven)
    - [Verdieping bij Overbodige parameterdoorgifte rechtstreeks schrijven](#verdieping-bij-overbodige-parameterdoorgifte-rechtstreeks-schrijven)
  - [Resource references](#resource-references)
  - [References van hetzelfde type samenvoegen](#references-van-hetzelfde-type-samenvoegen)
    - [Verdieping bij References van hetzelfde type samenvoegen](#verdieping-bij-references-van-hetzelfde-type-samenvoegen)
  - [Titels in resource references sorteren](#titels-in-resource-references-sorteren)
  - [Een overbodige buitenste dependency-array verwijderen](#een-overbodige-buitenste-dependency-array-verwijderen)
  - [Resourcelijsten hergebruiken](#resourcelijsten-hergebruiken)
    - [Verdieping bij Resourcelijsten hergebruiken](#verdieping-bij-resourcelijsten-hergebruiken)
  - [Resource-dependencies opbouwen](#resource-dependencies-opbouwen)
    - [Verdieping bij Resource-dependencies opbouwen](#verdieping-bij-resource-dependencies-opbouwen)
  - [Volgorde en meldingen](#volgorde-en-meldingen)
  - [Resources bij hun voorziening plaatsen](#resources-bij-hun-voorziening-plaatsen)
  - [Relaties en meldingen behouden](#relaties-en-meldingen-behouden)
  - [Instellingen bij hun eigenaar houden](#instellingen-bij-hun-eigenaar-houden)

<a id="naslag"></a>

De afspraken hieronder vormen de algemene Puppet-codestandaard, met aanvullende regels voor [Puppet-documentatie](DOCUMENTATION_RULES.md) en [operationele wijzigingen](OPERATIONAL_RULES.md). [`.puppet-lint.rc`](../../../.puppet-lint.rc) bepaalt de actieve controles en de [projectchecks](../lib/project_lint/checks/) bepalen hun feitelijke detectie en autofix; de [linthandleiding](../README.md#puppet-code-lintcontroles-en-hergebruik) beschrijft het volledige autoriteitsmodel en hoe je conflicten tussen deze bronnen vastlegt. Gebruik het overzicht om vanuit een lintmelding naar de betreffende afspraak te gaan. De secties bevatten ook handmatige reviewcriteria: een geslaagde scan bewijst geen correct functioneel gedrag, volledige documentatie of veilige serviceconfiguratie.

## Basisopmaak

<!-- lint-rule-group -->

### Twee spaties per inspringniveau

**Norm**

Puppet-code gebruikt twee spaties per inspringniveau.

**Herkomst**

Projectspecificatie van upstream; [Puppet-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/style_guide.html). De geïnstalleerde native check bepaalt de hieronder beschreven dekking.

**Toepassingsgebied**

Inspringingstokens in Puppet-code; arrays volgen bovendien [Inspringing](#inspringing).

**Automatische controle**

`2sp_soft_tabs`

**Detectiegrenzen**

Controleert alleen of de lengte van een INDENT-token even is; vier spaties op een plaats waar twee nodig zijn worden daarmee niet bewezen. `hard_tabs` meldt afzonderlijk echte tabs.

**Meldingen en severity**

`two-space soft tabs not used`: `error` bij oneven lengte van een inspringingstoken.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de native 2sp_soft_tabs-check heeft geen fixmethode.

**Toegestane uitzonderingen**

Geen uitzondering voor oneven inspringing; de specifieke array- en resourcetitelindeling staat bij Inspringing.

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Fragment; controle `2sp_soft_tabs`; verwacht error.

<!-- lint-example: 2sp_soft_tabs error -->
```puppet
if $active {
   notice('Example')
}
```

**Correct voorbeeld**

Fragment; controle `2sp_soft_tabs`; verwacht geen melding.

<!-- lint-example: 2sp_soft_tabs clean -->
```puppet
if $active {
  notice('Example')
}
```

**Grensgevallen**

Controleert alleen of de lengte van een INDENT-token even is; vier spaties op een plaats waar twee nodig zijn worden daarmee niet bewezen. `hard_tabs` meldt afzonderlijk echte tabs. Geen uitzondering voor oneven inspringing; de specifieke array- en resourcetitelindeling staat bij Inspringing.

**Handmatige review**

Een even aantal spaties kan nog het verkeerde structurele niveau zijn; vergelijk ieder blok met zijn opening.

**Verificatie**

De gemarkeerde voorbeeldparen worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). Voor de beschreven quote- en pijlcorrecties controleert [guide_examples_test.rb](../tests/guide_examples_test.rb) exacte uitvoer, hercontrole en tweede run. Een even aantal spaties kan nog het verkeerde structurele niveau zijn; vergelijk ieder blok met zijn opening.

### Inhoud direct na een openingsaccolade beginnen

**Norm**

Na een openende `{` begint de inhoud direct op de volgende regel, ook als er achter de accolade commentaar staat. Dit geldt voor codeblokken en verzamelingen. Verderop in het blok mogen lege regels onderdelen scheiden. Bij `[` en `(` mag ook de eerste regel leeg zijn. Deze opmaakregels gaan over Puppet-code; tekens binnen strings, reguliere expressies, heredocs of commentaar behouden hun betekenis.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Na een openende `{` begint de inhoud direct op de volgende regel, ook als er achter de accolade commentaar staat. Dit geldt voor codeblokken en verzamelingen. Verderop in het blok mogen lege regels onderdelen scheiden. Bij `[` en `(` mag ook de eerste regel leeg zijn. Deze opmaakregels gaan over Puppet-code; tekens binnen strings, reguliere expressies, heredocs of commentaar behouden hun betekenis.

**Automatische controle**

`project_layout`

**Detectiegrenzen**

Na [ of ( mag de eerste regel leeg zijn. Tekens in strings, regex, heredocs en commentaar blijven data. Lege regels verder in het blok mogen onderdelen scheiden. De inhoudelijke juistheid van de uitleg blijft review.

**Meldingen en severity**

`Remove blank lines immediately after an opening brace`: `warning` op de eerste lege regel, ook met spaties of tabs.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Verwijdert uitsluitend lege tokens na een echte openingsaccolade; comments op de openingsregel blijven behouden en genegeerde bereiken worden niet gewijzigd.

**Toegestane uitzonderingen**

Na [ of ( mag de eerste regel leeg zijn. Tekens in strings, regex, heredocs en commentaar blijven data. Lege regels verder in het blok mogen onderdelen scheiden.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_layout`; verwacht warning.

<!-- lint-example: project_layout warning -->
```puppet
if $active {

  notice('Active')
}
```

**Correct voorbeeld**

Fragment; alleen `project_layout`; verwacht geen melding.

<!-- lint-example: project_layout clean -->
```puppet
if $active {
  notice('Active')
}
```

**Grensgevallen**

Na [ of ( mag de eerste regel leeg zijn. Tekens in strings, regex, heredocs en commentaar blijven data. Lege regels verder in het blok mogen onderdelen scheiden.

**Handmatige review**

Vergelijk de toelichting met de direct betrokken verwerking en controleer dat scheiding en witruimte haar bij de juiste resource of het juiste blok houden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [comment_spacing_test.rb](../tests/comment_spacing_test.rb), [resource_sections_test.rb](../tests/resource_sections_test.rb), [brace_layout_test.rb](../tests/brace_layout_test.rb), [cli_sections_test.rb](../tests/cli_sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Resourcepijlen uitlijnen

**Norm**

Lijn de `=>`-pijlen binnen een resource uit, zodat de attributen en waarden goed te vergelijken zijn.

**Herkomst**

Projectspecificatie van upstream; [Puppet-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/style_guide.html). De geïnstalleerde native check bepaalt de hieronder beschreven dekking.

**Toepassingsgebied**

Resource-attributen en geneste groepen met pijlen op verschillende regels.

**Automatische controle**

`arrow_alignment`

**Detectiegrenzen**

Eenregelige resources en groepen met slechts één pijl worden overgeslagen. De gewenste kolom volgt uit de breedste attribuuttekst per groep; commenttokens worden voor de berekening verwijderd.

**Meldingen en severity**

`indentation of => is not properly aligned (expected in column {verwacht}, but found it in column {gevonden})`: `warning`; kolomnummers zijn variabel.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Past witruimte vóór => aan en kan een volgend attribuut op dezelfde regel naar een nieuwe regel brengen. Een berekende negatieve witruimtebreedte geeft NoFix. Beoordeel comments, nieuwe regels en samenloop met andere fixes vóór toepassing.

**Toegestane uitzonderingen**

Een eenregelige resource hoeft geen kunstmatige uitlijning tussen meerdere regels te krijgen.

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Fragment; controle `arrow_alignment`; verwacht warning.

<!-- lint-example: arrow_alignment warning -->
```puppet
notify { 'example':
  message => 'Example',
  withpath => false,
}
```

**Correct voorbeeld**

Fragment; controle `arrow_alignment`; verwacht geen melding.

<!-- lint-example: arrow_alignment clean -->
```puppet
notify { 'example':
  message  => 'Example',
  withpath => false,
}
```

**Grensgevallen**

Eenregelige resources en groepen met slechts één pijl worden overgeslagen. De gewenste kolom volgt uit de breedste attribuuttekst per groep; commenttokens worden voor de berekening verwijderd. Een eenregelige resource hoeft geen kunstmatige uitlijning tussen meerdere regels te krijgen.

**Handmatige review**

Controleer dat attribuutnamen, waarden, commentaar en resourcegrenzen gelijk blijven; een opgemaakte groep bewijst geen correcte resourcevolgorde.

**Verificatie**

De gemarkeerde voorbeeldparen worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). Voor de beschreven quote- en pijlcorrecties controleert [guide_examples_test.rb](../tests/guide_examples_test.rb) exacte uitvoer, hercontrole en tweede run. Controleer dat attribuutnamen, waarden, commentaar en resourcegrenzen gelijk blijven; een opgemaakte groep bewijst geen correcte resourcevolgorde.

### Aanhalingstekens bij stringinhoud kiezen

**Norm**

Voor letterlijke strings gebruik je enkele aanhalingstekens; dubbele aanhalingstekens zijn bedoeld voor interpolatie of escapes.

**Herkomst**

Projectspecificatie van upstream; [Puppet-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/style_guide.html). De geïnstalleerde native check bepaalt de hieronder beschreven dekking.

**Toepassingsgebied**

Letterlijke strings, interpolaties en bekende escapetekens in Puppet.

**Automatische controle**

`double_quoted_strings`

**Detectiegrenzen**

Inspecteert STRING-tokens zonder herkenbare escapes; apostrofs, nieuwe regels, tabs, backslashes en bekende escapes worden ontzien. Interpolatietokens vallen buiten deze waarschuwing. De bronvorm van iedere escape blijft review.

**Meldingen en severity**

`double quoted string containing no variables`: `warning` bij een geselecteerde letterlijke dubbele string.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Zet het geselecteerde token om naar SSTRING. Alleen de gedetecteerde vorm zonder herkenbare escapes is bedoeld; genegeerde en syntaxfoute invoer krijgt geen CLI-correctie. Behoud de effectieve stringwaarde.

**Toegestane uitzonderingen**

Dubbele quotes blijven toegestaan voor interpolatie of escapes.

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Fragment; controle `double_quoted_strings`; verwacht warning.

<!-- lint-example: double_quoted_strings warning -->
```puppet
$label = "Example"
```

**Correct voorbeeld**

Fragment; controle `double_quoted_strings`; verwacht geen melding.

<!-- lint-example: double_quoted_strings clean -->
```puppet
$label = 'Example'
```

**Grensgevallen**

Inspecteert STRING-tokens zonder herkenbare escapes; apostrofs, nieuwe regels, tabs, backslashes en bekende escapes worden ontzien. Interpolatietokens vallen buiten deze waarschuwing. De bronvorm van iedere escape blijft review. Dubbele quotes blijven toegestaan voor interpolatie of escapes.

**Handmatige review**

Vergelijk de effectieve inhoud, interpolatie en escapes; controleer een string met apostrof handmatig wanneer de detectie haar overslaat.

**Verificatie**

De gemarkeerde voorbeeldparen worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). Voor de beschreven quote- en pijlcorrecties controleert [guide_examples_test.rb](../tests/guide_examples_test.rb) exacte uitvoer, hercontrole en tweede run. Vergelijk de effectieve inhoud, interpolatie en escapes; controleer een string met apostrof handmatig wanneer de detectie haar overslaat.

### Selectors vóór resources berekenen

**Norm**

Bereken de uitkomst van een selector vóór de resource die deze gebruikt. Zo blijft in de resourcedeclaratie zichtbaar welke waarde wordt ingesteld.

**Herkomst**

Projectspecificatie van upstream; [Puppet-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/style_guide.html). De geïnstalleerde native check bepaalt de hieronder beschreven dekking.

**Toepassingsgebied**

Selectors die waarden voor resource-attributen leveren.

**Automatische controle**

`selector_inside_resource`

**Detectiegrenzen**

Herkent in resource_tokens alleen => gevolgd door een variabele en direct daarna ?. Andere expressievormen bewijzen geen afwezigheid van een selector.

**Meldingen en severity**

`selector inside resource block`: `warning` op de betreffende pijl.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de native check heeft geen autofix omdat verplaatsing de evaluatiecontext raakt.

**Toegestane uitzonderingen**

Geen uitzondering gedocumenteerd voor een selector in een resource.

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Fragment; controle `selector_inside_resource`; verwacht warning.

<!-- lint-example: selector_inside_resource warning -->
```puppet
notify { 'example': message => $active ? { true => 'Active', default => 'Inactive' } }
```

**Correct voorbeeld**

Fragment; controle `selector_inside_resource`; verwacht geen melding.

<!-- lint-example: selector_inside_resource clean -->
```puppet
$message = $active ? { true => 'Active', default => 'Inactive' }
notify { 'example': message => $message }
```

**Grensgevallen**

Herkent in resource_tokens alleen => gevolgd door een variabele en direct daarna ?. Andere expressievormen bewijzen geen afwezigheid van een selector. Geen uitzondering gedocumenteerd voor een selector in een resource.

**Handmatige review**

Controleer dat de voorbereide waarde vóór de resource beschikbaar is, binnen hetzelfde geldige pad wordt berekend en dezelfde selectorsemantiek houdt.

**Verificatie**

De gemarkeerde voorbeeldparen worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). Voor de beschreven quote- en pijlcorrecties controleert [guide_examples_test.rb](../tests/guide_examples_test.rb) exacte uitvoer, hercontrole en tweede run. Controleer dat de voorbereide waarde vóór de resource beschikbaar is, binnen hetzelfde geldige pad wordt berekend en dezelfde selectorsemantiek houdt.

### Functionele resourcevolgorde beoordelen

**Norm**

Kies ook de volgorde van resources en gegenereerde configuratie bewust: de linter kan de opmaak controleren, maar bepaalt niet welke volgorde functioneel nodig is.

**Herkomst**

Projectregel

**Toepassingsgebied**

Resources en gegenereerde configuratie met evaluatie- of runtimeafhankelijkheden.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Opmaak bewijst geen catalogusrelatie of runtimevolgorde. Zie [Volgorde en meldingen](#volgorde-en-meldingen) voor de plaatsingscriteria.

**Meldingen en severity**

Geen lintmelding of severity voor functionele volgorde; dit vereist inhoudelijke review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze norm heeft geen autofix.

**Toegestane uitzonderingen**

De concrete plaatsingsuitzonderingen staan bij [Resources bij hun voorziening plaatsen](#resources-bij-hun-voorziening-plaatsen).

**Suppressions**

Suppressie niet toegestaan voor deze check. Een gemiste detectie is geen uitzondering op de norm.

**Onjuist voorbeeld**

Handmatig reviewscenario: configuratie verwijst naar een waarde die pas later op een ander uitvoerpad wordt voorbereid; keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: bereid de waarde op het geldige pad vóór gebruik voor en behoud de vereiste resource- en notificatierelaties.

**Grensgevallen**

Een juist uitgelijnde resource kan functioneel verkeerd geplaatst zijn. Een afhankelijkheidsrelatie bewijst niet dat een classvariabele al geëvalueerd is.

**Handmatige review**

Volg de voorbereiding en iedere afnemer door de relevante branches; controleer ook de gegenereerde configuratievolgorde.

**Verificatie**

Handmatige vergelijking van beide scenario’s: de correcte variant levert de waarde vóór gebruik op hetzelfde geldige pad. Lint is hiervoor geen bewijs.

#### Gedeelde dekking van basisopmaak

De standaardchecks en geïnstalleerde plugins controleren onder meer witruimte, aanhalingstekens, parameterdatatypen en afsluitende komma's. De projectchecks vullen deze controles aan. Bij [autofix](../README.md#automatisch-corrigeren-autofix) gelden voor beide dezelfde eisen aan behoud van gedrag.

De [profielbeschrijving](../README.md#eigen-lintconfiguratie) beschrijft de activatie van native checks en de redenen voor de optionele checkkeuzes.

## Inspringing

**Norm**

Bij een array over meerdere regels bepaalt de regel met `[` de inspringing. De elementen staan twee spaties verder naar rechts; een afsluitende `]` aan het begin van een regel staat op hetzelfde niveau als de openingsregel. Dat geldt ook als de array in een functieaanroep staat:

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Meerregelige arrayliterals in toekenningen, functieargumenten, geneste arrays en resourcetitels.

**Automatische controle**

`project_layout`

**Detectiegrenzen**

Datatypeparameters en indexeringen zijn geen arrays. Alleen elementen en sluitende haken aan het begin van een fysieke regel worden uitgelijnd; string-, heredoc- en commentaarinhoud blijft intact.

**Meldingen en severity**

`Use {aantal} leading spaces for the array element` en `Use {aantal} leading spaces for the closing array bracket`: `warning` bij afwijkende inspringing; `{aantal}` is variabel.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Corrigeert alleen witruimte vóór arraytokens. Geneste arrays worden als groep behandeld; een genegeerd bereik of niet meer veilig vindbaar tokenanker verhindert correctie.

**Toegestane uitzonderingen**

Meerdere elementen op één regel zijn toegestaan. Een resourcetitel direct na `file { [` krijgt het hieronder beschreven extra niveau.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_layout` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_layout warning -->
```puppet
$values = [
      'first',
]
```

**Correct voorbeeld**

Fragment; alleen de controle `project_layout` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_layout clean -->
```puppet
$values = [
  'first',
]
```

**Grensgevallen**

Meerdere elementen op één regel zijn toegestaan. Een resourcetitel direct na `file { [` krijgt het hieronder beschreven extra niveau. Datatypeparameters en indexeringen zijn geen arrays. Alleen elementen en sluitende haken aan het begin van een fysieke regel worden uitgelijnd; string-, heredoc- en commentaarinhoud blijft intact. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Inspringing](#verdieping-bij-inspringing).

**Handmatige review**

Vergelijk de inhoud en volgorde van de elementen en de resourcetitels vóór en na correctie; beoordeel de inhoudelijke plaats van comments afzonderlijk.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [array_layout_test.rb](../tests/array_layout_test.rb), [layout_autofix_test.rb](../tests/layout_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Inspringing

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_layout` gecontroleerd.

<!-- lint-example: project_layout clean -->
```puppet
$label = join([
  'first',
  'second',
], ' ')
```

Extra functiehaakjes, bijvoorbeeld in `Sensitive.new(join([`, voegen geen inspringniveau toe. De array volgt het omliggende codeblok. Alleen een array die als resourcetitel direct achter de accolade begint, zoals `file { [`, krijgt een extra niveau: de elementen staan vier spaties verder dan `file` en de afsluitende `]` twee spaties.

`project_layout` controleert het begin van array-elementen op een nieuwe regel en de afsluitende `]`. Meerdere elementen op één regel zijn toegestaan. Met `--fix` herstelt de check de inspringing, inclusief die van geneste arrays. Stringinhoud, heredocs en commentaar blijven behouden. Vierkante haken in datatypeparameters of indexeringen worden niet als arrays behandeld.

## Komma's

<!-- lint-rule-group -->

### Spatie na komma’s

**Norm**

Zet één spatie na een komma wanneer het volgende element op dezelfde regel staat.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Kommatokens met een volgend code-element op dezelfde fysieke regel.

**Automatische controle**

`project_layout`

**Detectiegrenzen**

De projectcheck analyseert parameterlijsten; de plugin verzorgt resources en verzamelingen. Komma’s vóór een sluittoken vragen geen tussenruimte. Heredoc-einden vereisen handmatige plaatsing.

**Meldingen en severity**

`Use one space after a same-line comma`: `warning` bij afwijkende tussenruimte.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Herschrijft uitsluitend veilige witruimte tussen komma en volgend token; commentaar, genegeerde tokens of een ontbrekend tokenanker verhinderen veilige correctie.

**Toegestane uitzonderingen**

Komma’s vóór een sluittoken en een volgend element op een andere regel vereisen hier geen tussenruimte.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_layout` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_layout warning -->
```puppet
$values = [1,2]
```

**Correct voorbeeld**

Fragment; alleen de controle `project_layout` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_layout clean -->
```puppet
$values = [1, 2]
```

**Grensgevallen**

Een volgende ]/}/) wordt overgeslagen. Commentaar tussen komma en waarde krijgt geen verschuiving. Meerdere elementen op dezelfde regel blijven toegestaan.

**Handmatige review**

Controleer de scheiding van argumenten en plaats de komma bij een heredoc met de Puppet-parser als aanvullende controle.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [layout_autofix_test.rb](../tests/layout_autofix_test.rb), [cli_layout_test.rb](../tests/cli_layout_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Meerregelige lijsten met een komma afsluiten

**Norm**

Sluit een parameterlijst over meerdere regels af met een komma na de laatste parameter. Ook resources en verzamelingen over meerdere regels krijgen een afsluitende komma.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Meerregelige class-/defineparameters, resources, arrays en hashes.

**Automatische controle**

`project_layout`, `trailing_comma`

**Detectiegrenzen**

De projectcheck analyseert parameterlijsten; de plugin verzorgt resources en verzamelingen. Komma’s vóór een sluittoken vragen geen tussenruimte. Heredoc-einden vereisen handmatige plaatsing.

**Meldingen en severity**

`End a multiline parameter block with a trailing comma`: `warning` van project_layout. `missing trailing comma after last element`: `warning` van de plugin.

**Autofix**

Voorwaardelijk voor beide varianten.

**Autofixvoorwaarden**

Voegt een komma toe na het laatst herkende element. Een parameter met een detached heredoc-terminator wordt door de projectfix geweigerd; plaats de komma handmatig en valideer met de parser. De plugin volgt native tokenposities; controleer de resulterende syntax.

**Toegestane uitzonderingen**

Een eenregelige lijst verlangt geen kunstmatige meerregelige vorm. Een heredoc is geen uitzondering op de komma-eis, alleen op de veilige autofix.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_layout`; verwacht warning.

<!-- lint-example: project_layout warning -->
```puppet
class example (
  String $label
) {}
```

**Correct voorbeeld**

Fragment; alleen `project_layout`; verwacht geen melding.

<!-- lint-example: project_layout clean -->
```puppet
class example (
  String $label,
) {}
```

**Grensgevallen**

Eenregelige parameterlijst: toegestaan zonder eindkomma. Meerregelige parameter met heredoc: handmatig. Resources en verzamelingen vallen onder trailing_comma; project_layout behandelt parameters.

**Handmatige review**

Controleer de scheiding van argumenten en plaats de komma bij een heredoc met de Puppet-parser als aanvullende controle.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [layout_autofix_test.rb](../tests/layout_autofix_test.rb), [cli_layout_test.rb](../tests/cli_layout_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Meerregelige lijsten met een komma afsluiten

`project_layout` controleert de spaties en de laatste komma in parameterlijsten; de trailing-comma-plugin controleert resources en verzamelingen. Autofix herstelt de spaties alleen als er geen commentaar tussen de betrokken onderdelen staat. Bij een parameter die eindigt met een heredoc voeg je de laatste komma handmatig op de juiste plaats toe. De autofix kan daar niet veilig bepalen waar de parameter eindigt.

## Lange regels

**Norm**

Houd Puppet-code binnen 140 tekens per regel. Lange arrays en functieaanroepen kun je over meerdere regels verdelen. Laat je een regel bewust langer, voeg dan `# lint:ignore:140chars` toe achter de code. Zo blijft de uitzondering zichtbaar bij de review. De [verdieping bij deze regel](#verdieping-bij-lange-regels) toont de plaatsing bij een lange download-URL.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Fysieke Puppet-coderegels, codecommentaar en de apart behandelde Puppet Strings-blokken.

**Automatische controle**

`140chars`, `project_documentation_layout`

**Detectiegrenzen**

`140chars` slaat bepaalde URL- en template-regels over. De projectnorm verlangt daar toch een zichtbare markering; dat blijft review. Strings wordt apart beoordeeld.

**Meldingen en severity**

`line has more than 140 characters`: `warning` van `140chars`. `project_suppressions` meldt `Only targeted 140chars and puppet_url_without_modules suppressions are allowed; fix other lint violations`: `error`. Strings-varianten staan bij [Puppet Strings](DOCUMENTATION_RULES.md#puppet-strings).

**Autofix**

Geen voor `140chars` en `project_suppressions`; Voorwaardelijk voor de afzonderlijke Strings-varianten

**Autofixvoorwaarden**

De lengtecheck breekt code niet af. Voor afbreekbare documentatie gelden uitsluitend de voorwaarden bij [Puppet Strings](DOCUMENTATION_RULES.md#puppet-strings).

**Toegestane uitzonderingen**

Bewust lange code met een lokale markering; bij Strings uitsluitend ondeelbare letterlijke waarden. Alle plaatsingsvoorwaarden hieronder blijven gelden.

**Suppressions**

Alleen `# lint:ignore:140chars` achter de code of een minimaal blok met `# lint:endignore`; voor `puppet_url_without_modules` gelden de voorwaarden bij bestandsbronnen. Combineren is toegestaan; geen andere check uitschakelen.

**Onjuist voorbeeld**

Fragment; alleen de controle `140chars` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: 140chars warning -->
```puppet
$value = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
```

**Correct voorbeeld**

Fragment; alleen de controle `140chars` is voor dit voorbeeld bedoeld. De melding krijgt `ignored` en is zonder `--show-ignored` niet zichtbaar; de expliciete uitzondering voldoet aan het projectbeleid.

<!-- lint-example: 140chars ignored -->
```puppet
$value = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' # lint:ignore:140chars
```

**Grensgevallen**

Bewust lange code met een lokale markering; bij Strings uitsluitend ondeelbare letterlijke waarden. Alle plaatsingsvoorwaarden hieronder blijven gelden. `140chars` slaat bepaalde URL- en template-regels over. De projectnorm verlangt daar toch een zichtbare markering; dat blijft review. Strings wordt apart beoordeeld. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Lange regels](#verdieping-bij-lange-regels).

**Handmatige review**

Meet ook overgeslagen URL- en template-regels. Controleer dat de markering Puppet-commentaar is en dat een ignoreblok vóór de volgende gewone documentatieregel sluit.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [suppression_policy_test.rb](../tests/suppression_policy_test.rb), [documentation_suppressions_test.rb](../tests/documentation_suppressions_test.rb), [documentation_width_test.rb](../tests/documentation_width_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Lange regels

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_suppressions` gecontroleerd.

<!-- lint-example: project_suppressions clean -->
```puppet
$download_url = 'https://downloads.example.org/releases/application/stable/linux/amd64/packages/application-with-optional-components-and-offline-documentation.tar.gz' # lint:ignore:140chars
```

De markering hoort in Puppet-commentaar, buiten de waarde. Staat daar al een toelichting, zet de markering dan direct na `#` en vóór die toelichting. Heeft een string of heredoc over meerdere regels een lengte-uitzondering nodig, zet dan `# lint:ignore:140chars` vóór de waarde en `# lint:endignore` erna. Houd dat blok zo klein mogelijk. Binnen de string of heredoc zou de markering als inhoud worden verwerkt, bijvoorbeeld in een beheerd bestand of shellcommando. Daar is zij daarom niet toegestaan.

Gewoon codecommentaar volgt de afspraak van [één zin per fysieke regel](DOCUMENTATION_RULES.md#toelichtingen-bij-code). Bij een bewust lange commentaarregel kun je een begrensd ignoreblok gebruiken.

Bij [Puppet Strings](DOCUMENTATION_RULES.md#puppet-strings) verdeel je een beschrijving over meerdere commentregels. Een lange beschrijvende zin heeft dus geen lengte-uitzondering nodig. Alleen een letterlijke waarde die niet zonder betekenisverlies kan worden afgebroken mag langer blijven. Sluit het ignoreblok vóór de volgende gewone documentatieregel.

De standaardcheck `140chars` meldt lange regels, maar slaat bepaalde regels met URL's of `template(...)` over. Ook op die overgeslagen regels vraagt de projectafspraak een markering; controleer dat bij de review. `project_documentation_layout` controleert de lengte en uitzonderingen in Puppet Strings afzonderlijk. De standaardcheck heeft geen autofix; gewone Strings-tekst kan de documentatiecheck wel afbreken.

### Alleen toegestane suppressions gebruiken

**Norm**

`project_suppressions` controleert welke checks via commentaar worden uitgezonderd. Alleen `140chars` en de beschreven uitzondering voor [Puppet-fileserverbronnen](OPERATIONAL_RULES.md#templates-en-bestandsbronnen) zijn toegestaan, eventueel samen. De noodzaak en begrenzing van de uitzondering beoordeel je zelf. Gebruik [`--show-ignored`](../README.md#werking-van-de-controles) om te zien welke meldingen door zulke markeringen worden onderdrukt. Neem je een codevoorbeeld uit documentatie over in een manifest, voeg dan daar een eigen markering toe aan bewust lange regels.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Lintcontrolemarkeringen in Puppet-commenttokens, niet gelijknamige tekst in string- of heredoc-inhoud.

**Automatische controle**

`project_suppressions`

**Detectiegrenzen**

De check controleert de genoemde suppressienamen. Noodzaak, exacte begrenzing en de norm op native overgeslagen URL/template-regels blijven handmatige review.

**Meldingen en severity**

`Only targeted 140chars and puppet_url_without_modules suppressions are allowed; fix other lint violations`: `error` bij een niet-toegestane suppressie.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de beleidscheck verwijdert geen markering; inhoudelijke fouten moeten worden hersteld.

**Toegestane uitzonderingen**

Alleen 140chars en de gerichte puppet_url_without_modules-uitzondering voor files-bronnen, eventueel samen. Zie de lengte- en mountregels voor hun voorwaarden.

**Suppressions**

Suppressie van project_suppressions is niet toegestaan. Toegestane syntax: # lint:ignore:140chars of # lint:ignore:puppet_url_without_modules, lokaal achter de relevante code of minimaal begrensd met # lint:endignore volgens de bijbehorende regel.

**Onjuist voorbeeld**

Fragment; alleen `project_suppressions`; verwacht error.

<!-- lint-example: project_suppressions error -->
```puppet
# lint:ignore:project_arrays
$values = [1] + [2]
# lint:endignore
```

**Correct voorbeeld**

Fragment; alleen `project_suppressions`; verwacht geen melding.

<!-- lint-example: project_suppressions clean -->
```puppet
$values = concat([1], [2])
```

**Grensgevallen**

De twee toegestane namen mogen worden gecombineerd. Iedere andere naam, brede uitschakeling of onderdrukking van deze beleidscheck is niet toegestaan. Een markering in stringinhoud is data en heft geen norm op.

**Handmatige review**

Controleer de noodzaak en begrenzing van elke markering, bekijk --show-ignored en voeg bij overgenomen codevoorbeelden de benodigde lokale markering in het echte manifest toe.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door guide_examples_test.rb. [suppression_policy_test.rb](../tests/suppression_policy_test.rb) controleert namen en commenttokens; [documentation_suppressions_test.rb](../tests/documentation_suppressions_test.rb) controleert de afzonderlijke documentatiegrenzen.

## Parameters en resources

<!-- lint-rule-group -->

### Parameters en instellingen

<!-- lint-rule-group -->

### Classes en defines bruikbaar ontwerpen

**Norm**

Ontwerp classes en defined types zo dat ze afzonderlijk en in combinatie bruikbaar zijn.

**Herkomst**

Projectregel

**Toepassingsgebied**

Classes en defined types die afzonderlijk en gecombineerd worden gebruikt.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Type- en aanroepchecks bewijzen geen bruikbaarheid van een modulecombinatie.

**Meldingen en severity**

Geen lintmelding of severity voor zelfstandige en gecombineerde bruikbaarheid.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze ontwerpnorm vereist inhoudelijke review.

**Toegestane uitzonderingen**

Geen uitzondering gedocumenteerd; verklaar noodzakelijke prerequisites in de interface.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Handmatig reviewscenario: een class werkt alleen door een ongedocumenteerde resource uit een andere module. Keur die verborgen prerequisite af.

**Correct voorbeeld**

Handmatig reviewscenario: beschrijf en lever de benodigde prerequisite en behoud de werking bij afzonderlijk en gecombineerd gebruik.

**Grensgevallen**

Een expliciete vereiste parentclass kan onderdeel van het contract zijn; een toevallige classdeclaratie is geen garantie.

**Handmatige review**

Controleer prerequisites, resource-eigendom en dubbele declaraties bij afzonderlijk gebruik en iedere geraakte combinatie.

**Verificatie**

Handmatige vergelijking van de beschreven scenario’s; controleer het interfacecontract en benodigde afhankelijkheden. Een groene lintscan is geen catalogusbewijs.

### Herhaalde resourceorkestratie in defined types delen

**Norm**

Gebruik herbruikbare defined types voor herhaalde Puppet-resourceorkestratie en geef instellingen die per aanroeper verschillen als parameters door. Behoud de beveiligings- en levenscyclusvereisten van iedere aanroeper.

**Herkomst**

Projectregel

**Toepassingsgebied**

Herhaalde orkestratie van Puppet-resources en migratie van de betrokken aanroepers.

**Automatische controle**

Geen automatische controle

**Detectiegrenzen**

Geen check bewijst semantisch gedeelde resourceorkestratie of equivalentie van alle aanroepers. Opmaak-, aanroep- en dependencychecks dekken uitsluitend hun eigen contracten.

**Meldingen en severity**

Geen lintmelding of severity: deze norm vereist handmatige review.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: voor deze norm bestaat geen automatische correctie.

**Toegestane uitzonderingen**

Een aanroeper behoudt zijn eigen instellingen en voorwaarden; gedeeld gedrag rechtvaardigt geen wijziging daarvan.

**Suppressions**

Niet van toepassing op automatische detectie; een lintmarkering heft deze handmatige norm niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Twee aanroepers dupliceren dezelfde resourceorkestratie of een gedeelde define verliest de beveiligingsvoorwaarde van één aanroeper. Keur dit af.

**Correct voorbeeld**

Handmatig reviewscenario: Deel de resourceorkestratie via een defined type, geef de verschillende instellingen door en behoud de individuele beveiliging en levenscyclus.

**Grensgevallen**

Een aanroeper behoudt zijn eigen instellingen en voorwaarden; gedeeld gedrag rechtvaardigt geen wijziging daarvan. Geen check bewijst semantisch gedeelde resourceorkestratie of equivalentie van alle aanroepers. Opmaak-, aanroep- en dependencychecks dekken uitsluitend hun eigen contracten.

**Handmatige review**

Vergelijk iedere gemigreerde aanroeper, diens instellingen, resource-eigendom, beveiliging, levenscyclus en dependencies.

**Verificatie**

Vergelijk beide reviewscenario’s en valideer iedere gemigreerde aanroeper afzonderlijk volgens de [hergebruikreview](../../../AGENTS.md#reuse-and-shared-abstractions).

### Publieke parameters expliciet typeren

**Norm**

Geef publieke parameters een expliciet datatype, met een ingebouwd Puppet-type of een passende typealias.

**Herkomst**

Projectspecificatie van upstream; [parameter-types-plugin](https://github.com/voxpupuli/puppet-lint-param-types).

**Toepassingsgebied**

Parameterlijsten van classes en defined types, met ingebouwde types en typealiases.

**Automatische controle**

`parameter_types`

**Detectiegrenzen**

De plugin herkent het begintoken van iedere parameter en slaat default-expressies met geneste haakjes over. De aanwezigheid van een type bewijst niet dat het type of de runtimewaarde juist is.

**Meldingen en severity**

`missing datatype for parameter {declaratie}::{parameter}`: `warning` bij een ongetypeerde parameter; namen zijn variabel.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de plugin kan het bedoelde type niet afleiden.

**Toegestane uitzonderingen**

Een passende typealias is toegestaan naast een ingebouwd Puppet-type; geen ongetypeerde uitzondering gedocumenteerd.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `parameter_types`; verwacht warning.

<!-- lint-example: parameter_types warning -->
```puppet
class example ($label) {}
```

**Correct voorbeeld**

Fragment; alleen `parameter_types`; verwacht geen melding.

<!-- lint-example: parameter_types clean -->
```puppet
class example (String $label) {}
```

**Grensgevallen**

Geneste datatypeparameters en defaults met arrays, hashes of functieaanroepen blijven afzonderlijke parameterconstructies. Een Optional-type zonder default levert geen waarde bij een ontbrekend argument.

**Handmatige review**

Vergelijk het gekozen type, undef-toelating en eventuele grenzen met de werkelijke publieke interface.

**Verificatie**

De gemarkeerde paren draaien in guide_examples_test.rb; [interface_contract_test.rb](../tests/interface_contract_test.rb), test_nested_parameter_types_and_multiline_defaults, controleert geneste types/defaults. Catalogusvalidatie blijft nodig voor typebetekenis.

### Parameters met defaultafhankelijkheden sorteren

**Norm**

Voor de sortering gebruikt het project twee groepen. Eerst komen parameters zonder default en zonder buitenste `Optional[...]`. Daarna volgen de parameters met een default of `Optional[...]`. Sorteer beide groepen alfabetisch. Dit fragment laat de indeling zien:

`$label` staat hier in de tweede groep, maar blijft verplicht bij een aanroep: `Optional[String]` staat `undef` toe en levert zelf geen default. Voeg geen default toe om alleen de sortering te veranderen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Publieke class- en defined-typeparameters, hun getypeerde declaratieblokken en lokale defaultafhankelijkheden.

**Automatische controle**

`project_parameter_order`

**Detectiegrenzen**

`Optional` zonder default blijft vereist bij een aanroep. Uitlijning slaat ongetypeerde blokken over. Cyclische lokale defaults geven een uitvoerfout; de check lost de cyclus niet op. Betekenisvolle naamgeving en veilige configuratiekeuzes blijven review.

**Meldingen en severity**

`Put mandatory parameters first, then optional parameters; sort each group alphabetically subject to local default dependencies`, `A local default refers to a parameter that must be declared earlier` en `Explain the necessary default dependency in a trailing comment naming the dependent parameter`: `warning`.

**Autofix**

Geen voor alle drie meldingsvarianten.

**Autofixvoorwaarden**

Niet van toepassing: de check herschikt geen parameters; lokale defaults kunnen de evaluatievolgorde veranderen.

**Toegestane uitzonderingen**

Een lokale defaultafhankelijkheid doorbreekt de normale volgorde met de voorgeschreven toelichting; Optional zonder default blijft vereist bij een aanroep.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_parameter_order` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_parameter_order warning -->
```puppet
class example (String $zulu, String $alpha) {}
```

**Correct voorbeeld**

Fragment; alleen de controle `project_parameter_order` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_parameter_order clean -->
```puppet
class example (String $alpha, String $zulu) {}
```

**Grensgevallen**

Lokale defaultafhankelijkheid doorbreekt de alfabetische volgorde met de voorgeschreven trailing comment. Een buitenste `Optional` staat in groep twee zonder daardoor een default te krijgen. Gesplitste beveiligingsparameters alleen wegens compatibiliteit. `Optional` zonder default blijft vereist bij een aanroep. Uitlijning slaat ongetypeerde blokken over. Cyclische lokale defaults geven een uitvoerfout; de check lost de cyclus niet op. Betekenisvolle naamgeving en veilige configuratiekeuzes blijven review. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Parameters met defaultafhankelijkheden sorteren](#verdieping-bij-parameters-met-defaultafhankelijkheden-sorteren).

**Handmatige review**

Controleer beide sorteergroepen, iedere lokale defaultafhankelijkheid en de trailing comment met de afhankelijke $naam. Voeg geen default toe alleen om te sorteren.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [interface_contract_test.rb](../tests/interface_contract_test.rb), [layout_autofix_test.rb](../tests/layout_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Parameters met defaultafhankelijkheden sorteren

Voor de sortering gebruikt het project twee groepen. Eerst komen parameters zonder default en zonder buitenste `Optional[...]`. Daarna volgen de parameters met een default of `Optional[...]`. Sorteer beide groepen alfabetisch en lijn de typen, namen, `=`-tekens en defaults over het hele parameterblok uit. Dit fragment laat de indeling zien:

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_parameter_order, project_parameter_alignment` gecontroleerd. Omgeef het voor uitvoering met `class example (` en `) {}`.

<!-- lint-example: project_parameter_order, project_parameter_alignment clean parameters -->
```puppet
  String           $value,
  Optional[String] $label,
  Integer          $timeout = 30,
```

`$label` staat hier in de tweede groep, maar blijft verplicht bij een aanroep: `Optional[String]` staat `undef` toe en levert zelf geen default. Voeg geen default toe om alleen de sortering te veranderen.

Een default kan de normale volgorde doorbreken wanneer hij de waarde van een andere parameter gebruikt. Declareer die andere parameter dan eerder. Schuift hij daarmee vóór zijn normale alfabetische positie, leg de reden uit in commentaar achter die parameter en noem daarin de afhankelijke parameter met `$naam`.

`project_parameter_order` controleert de groepen, volgorde, defaultafhankelijkheden en die toelichting. De check sorteert niet automatisch. `project_parameter_alignment` kan de uitlijning herstellen wanneer de parameters op afzonderlijke regels staan en de tussenruimte geen commentaar bevat. Ook geneste typen en defaults over meerdere regels worden meegenomen. Meerdere parameters op één regel, onduidelijke tussenruimte en genegeerde delen vragen handmatige beoordeling.

### Parameterblokken volledig uitlijnen

**Norm**

Lijn de typen, namen, `=`-tekens en defaults over het hele parameterblok uit.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Volledig getypeerde parameterblokken van classes en defined types, inclusief verplichte parameters en meerregelige types of defaults.

**Automatische controle**

`project_parameter_alignment`

**Detectiegrenzen**

`Optional` zonder default blijft vereist bij een aanroep. Uitlijning slaat ongetypeerde blokken over. Cyclische lokale defaults geven een uitvoerfout; de check lost de cyclus niet op. Betekenisvolle naamgeving en veilige configuratiekeuzes blijven review.

**Meldingen en severity**

`Align parameter names after the widest type across the complete parameter block`, `Align parameter equals signs across the complete parameter block` en `Use one space between the aligned equals sign and a same-line default`: `warning`.

**Autofix**

Voorwaardelijk voor alle drie meldingsvarianten.

**Autofixvoorwaarden**

Alle parameters moeten getypeerd zijn, op afzonderlijke regels staan en uitsluitend veilige witruimte tussen type, naam, `=` en default hebben. Geen commentaar of genegeerd bereik verplaatsen. Eerdere quote-/kommafixes worden in de actuele breedte meegenomen.

**Toegestane uitzonderingen**

Geen afwijkende uitlijningsnorm; niet veilig te corrigeren vormen vragen handmatige correctie.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_parameter_alignment`; verwacht warning.

<!-- lint-example: project_parameter_alignment warning -->
```puppet
class example (
  String $alpha,
  Optional[String] $label,
) {}
```

**Correct voorbeeld**

Fragment; alleen `project_parameter_alignment`; verwacht geen melding.

<!-- lint-example: project_parameter_alignment clean -->
```puppet
class example (
  String           $alpha,
  Optional[String] $label,
) {}
```

**Grensgevallen**

Ongetypeerde blokken worden overgeslagen. Meer parameters op één regel, commentaar tussen type/naam/=/default en genegeerde delen weigeren autofix. Geneste types en meerregelige defaults worden meegenomen. Eerdere quote- en kommafixes veranderen de opnieuw berekende breedte.

**Handmatige review**

Controleer type, parameternaam en default vóór en na witruimtecorrectie, en behoud comments op hun oorspronkelijke parameter.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [interface_contract_test.rb](../tests/interface_contract_test.rb), [layout_autofix_test.rb](../tests/layout_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Beveiligingsinstellingen met één waardekeuze modelleren

**Norm**

Biedt een beveiligingsinstelling een veilige standaardwaarde, een uitschakelmogelijkheid en een eigen waarde, gebruik dan één parameter met `Variant[Boolean, String]` of een passende beperkte scalarvariant. Daarbij kiest `true` de veilige standaardwaarde, laat `false` de instelling weg en levert een scalar de eigen waarde. Bereken de effectieve waarde eenmaal in een `*_correct`-variabele die de template gebruikt. Alleen wanneer compatibiliteit dat vereist, splits je dit in afzonderlijke enable/custom/value-parameters.

**Herkomst**

Projectregel

**Toepassingsgebied**

Instellingen met veilige standaard, uitschakeling en eigen scalarwaarde.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Parameters en instellingen](#parameters-en-instellingen).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Alleen een compatibiliteitsvereiste rechtvaardigt afzonderlijke enable/custom/value-parameters.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Alleen een compatibiliteitsvereiste rechtvaardigt afzonderlijke enable/custom/value-parameters.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Drie nieuwe parameters modelleren enable, default en custom zonder compatibiliteitsreden. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik één passende Variant; bereken eenmaal de *_correct-waarde en gebruik die in de template. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Alleen een compatibiliteitsvereiste rechtvaardigt afzonderlijke enable/custom/value-parameters.

**Handmatige review**

Controleer true als veilige standaard, false als weglaten en scalar als eigen waarde in iedere gerenderde variant.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer true als veilige standaard, false als weglaten en scalar als eigen waarde in iedere gerenderde variant. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Parameternamen op onderwerp kiezen

**Norm**

Kies namen in snake_case die beginnen met het onderwerp, gevolgd door de nadere aanduiding: bijvoorbeeld `bandwidth_max`, `p95_warning` of `secret_key_fallback`. Een naam die met een cijfer begint is alleen bruikbaar als dat op alle ondersteunde runtimes is getest.

**Herkomst**

Projectregel

**Toepassingsgebied**

Namen van publieke en lokale Puppet-parameters.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Parameters en instellingen](#parameters-en-instellingen).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een beginletter is niet als extra norm ingevoerd: de bestaande uitzondering voor een getest begincijfer blijft bestaan.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een beginletter is niet als extra norm ingevoerd: de bestaande uitzondering voor een getest begincijfer blijft bestaan.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een parameter heet maxBandwidth. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik een snake_case-naam die met het onderwerp begint, zoals bandwidth_max. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een beginletter is niet als extra norm ingevoerd: de bestaande uitzondering voor een getest begincijfer blijft bestaan.

**Handmatige review**

Controleer naamvolgorde en test een cijfer aan het begin op iedere ondersteunde runtime.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer naamvolgorde en test een cijfer aan het begin op iedere ondersteunde runtime. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Voorwaarden en validatie

<!-- lint-rule-group -->

### De grootste verwerking vóór de korte afhandeling plaatsen

**Norm**

Zet de omvangrijkste verwerking in de eerste tak van een voorwaarde en de kortere afhandeling in de laatste `else`. Een korte foutmelding of terugvalwaarde komt zo na de code die het normale werk uitvoert. De voorwaarde mag daarvoor een ontkenning bevatten. Gelijke takken en een `if` zonder vervolgtak zijn toegestaan; voor `unless` geldt dezelfde volgorde.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

If/unless/elsif met een afzonderlijke vervolgtak.

**Automatische controle**

`project_positive_flow`

**Detectiegrenzen**

Structuur telt; tekstlengte en gewone functieargumenten tellen niet mee. Namespaced eigen functies, functiedeclaraties en parameterdefaults vallen buiten de validatieanalyse. Behoud prioriteit van overlappende elsif-voorwaarden.

**Meldingen en severity**

`Put the larger code branch first and keep shorter handling in the final else; preserve condition semantics and elsif priority`: `warning` bij een kleinere eerste tak dan een vervolgtak.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Gelijke takken en een if zonder vervolgtak zijn toegestaan. Uitsluitend diagnostische foutafhandeling blijft achteraan, ook wanneer voorbereiding en meldingen groter zijn.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_positive_flow` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_positive_flow warning -->
```puppet
if $active { notice('One') } else { notice('One'); notice('Two') }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_positive_flow` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_positive_flow clean -->
```puppet
if !$active { notice('One'); notice('Two') } else { notice('One') }
```

**Grensgevallen**

Gelijke takken en if zonder vervolgtak zijn toegestaan. Een uitsluitend diagnostische fouttak blijft achteraan, ook als voorbereiding en meldingen groter zijn. Een bestaande case mag de laatste default gebruiken. Structuur telt; tekstlengte en gewone functieargumenten tellen niet mee. Namespaced eigen functies, functiedeclaraties en parameterdefaults vallen buiten de validatieanalyse. Behoud prioriteit van overlappende elsif-voorwaarden. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij De grootste verwerking vóór de korte afhandeling plaatsen](#verdieping-bij-de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen).

**Handmatige review**

Vergelijk structurele verwerkingsomvang, behoud waarheidsvoorwaarden en prioriteit van overlappende elsif-voorwaarden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [branch_size_test.rb](../tests/branch_size_test.rb), [validation_flow_test.rb](../tests/validation_flow_test.rb), [cli_flow_test.rb](../tests/cli_flow_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij De grootste verwerking vóór de korte afhandeling plaatsen

`project_positive_flow` controleert zowel de omvang van takken als de plaats van validatiemeldingen. Bij `elsif` vergelijkt de check iedere tak met de grootste afzonderlijke vervolgtak. Een expliciet geneste `if` telt als geneste code. De [technische naslag](../README.md#omvang-en-validatiestructuur) beschrijft de telling en welke aanroepen als validatiemelding worden herkend.

De check heeft geen autofix: het omkeren van een voorwaarde of verplaatsen van code kan de evaluatievolgorde veranderen. Behoud bij `elsif` de prioriteit van overlappende voorwaarden. Test steeds het geldige en ongeldige pad, vooral bij `warning()`: een waarschuwing stopt Puppet niet vanzelf.

### Validatie om haar afhankelijke implementatie plaatsen

**Norm**

Bij invoervalidatie omsluit de geldige tak de implementatie die van die invoer afhankelijk is. Bereken de benodigde waarden vooraf en zet de bijbehorende `warning()` of `fail()` in de afsluitende `else`. Zijn meerdere controles nodig voor dezelfde implementatie, nest die dan. Een bestaande `case` mag zijn foutafhandeling in de laatste `default`-tak houden.

Een fouttak mag meerdere meldingen bevatten en lokale variabelen voorbereiden die voor die meldingen worden gebruikt. Andere verwerking hoort in de geldige tak. Laat de fouttak ook achteraan staan wanneer de meldingen en hun voorbereiding samen groter zijn dan de geldige tak.

Na zo'n validatie volgt binnen dezelfde class of hetzelfde defined type geen implementatiecode meer. Dat geldt ook wanneer de validatie in een buitenste `if`, `case` of lambda-aanroep staat: code ná dat buitenste blok zou buiten de geldige tak vallen. Een volgende `else` of alternatieve `case`-tak vormt een ander uitvoerpad en mag wel volgen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Bodies van classes en defined types met directe warning()/fail()-validatie, inclusief omvattende if/case/lambdablokken.

**Automatische controle**

`project_positive_flow`

**Detectiegrenzen**

Structuur telt; tekstlengte en gewone functieargumenten tellen niet mee. Namespaced eigen functies, functiedeclaraties en parameterdefaults vallen buiten de validatieanalyse. Behoud prioriteit van overlappende elsif-voorwaarden.

**Meldingen en severity**

`Put validation warning() and fail() calls in the final else (or case default), with regular implementation in the valid branch`: `warning` bij onjuiste fouttakplaatsing. `Keep the remaining implementation inside the valid branch; no implementation may follow this validation or its enclosing blocks within the class or defined type`: `warning` bij volgende implementatie buiten het geldige pad.

**Autofix**

Geen voor beide varianten.

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een bestaande case mag de laatste default als fouttak houden. Een volgende else of alternatieve case-tak is een afzonderlijk uitvoerpad en mag volgen. Fouttakken mogen lokale waarden uitsluitend voor hun meldingen voorbereiden.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_positive_flow`; verwacht warning.

<!-- lint-example: project_positive_flow warning -->
```puppet
class example {
  if $active { notice('Active') } else { fail('Inactive') }
  notice('Outside the valid branch')
}
```

**Correct voorbeeld**

Fragment; alleen `project_positive_flow`; verwacht geen melding.

<!-- lint-example: project_positive_flow clean -->
```puppet
class example {
  if $active { notice('Active'); notice('Inside the valid branch') } else { fail('Inactive') }
}
```

**Grensgevallen**

Gelijke takken en if zonder vervolgtak zijn toegestaan. Een uitsluitend diagnostische fouttak blijft achteraan, ook als voorbereiding en meldingen groter zijn. Een bestaande case mag de laatste default gebruiken. Structuur telt; tekstlengte en gewone functieargumenten tellen niet mee. Namespaced eigen functies, functiedeclaraties en parameterdefaults vallen buiten de validatieanalyse. Behoud prioriteit van overlappende elsif-voorwaarden. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Omvang en validatiestructuur](../README.md#omvang-en-validatiestructuur).

**Handmatige review**

Loop geldig en ongeldig pad door tot het einde van de class/define, ook na omvattende blokken. Controleer dat warning Puppet niet vanzelf stopt en dat afhankelijke implementatie daarom binnen de geldige tak blijft.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [branch_size_test.rb](../tests/branch_size_test.rb), [validation_flow_test.rb](../tests/validation_flow_test.rb), [cli_flow_test.rb](../tests/cli_flow_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Ruwe en geërfde waarden in templates onderscheiden

**Norm**

Wanneer een instelling een waarde erft, mag de template de ruwe parameter gebruiken om te bepalen of een regel nodig is. Voor de inhoud van die regel gebruikt de template de berekende waarde.

**Herkomst**

Projectregel

**Toepassingsgebied**

Templates met conditionele directives en berekende geërfde instellingen.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Voorwaarden en validatie](#voorwaarden-en-validatie).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. De ruwe parameter mag de aanwezigheid bepalen; zij vervangt niet de berekende inhoud.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

De ruwe parameter mag de aanwezigheid bepalen; zij vervangt niet de berekende inhoud.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een directive wordt met de ruwe undef-parameter gevuld terwijl de effectieve waarde beschikbaar is. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Gebruik de ruwe parameter uitsluitend om te beslissen of de regel nodig is, en de berekende waarde voor haar inhoud. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

De ruwe parameter mag de aanwezigheid bepalen; zij vervangt niet de berekende inhoud.

**Handmatige review**

Vergelijk de aanwezigheid van de regel en haar inhoud afzonderlijk voor expliciete en geërfde invoer.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Vergelijk de aanwezigheid van de regel en haar inhoud afzonderlijk voor expliciete en geërfde invoer. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Optionele waarden alleen bij gebruik valideren

**Norm**

Valideer een optionele instelling alleen als die daadwerkelijk wordt gebruikt of in configuratie terechtkomt. Een niet-ingestelde optionele waarde is op zichzelf geen fout. Bewaar het resultaat in een variabele met één korte foutmelding of `undef`, maak de resources in de geldige tak en faal in de laatste `else`. Een losse `fail(...)` halverwege de opbouw van waarden of resources past niet in deze structuur.

**Herkomst**

Projectregel

**Toepassingsgebied**

Optionele invoer die wel of niet in resources of configuratie terechtkomt.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Voorwaarden en validatie](#voorwaarden-en-validatie).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Niet-ingesteld is op zichzelf geen fout; een losse fail halverwege resources of waarden is geen toegestane structuur.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Niet-ingesteld is op zichzelf geen fout; een losse fail halverwege resources of waarden is geen toegestane structuur.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een ongebruikte optionele undef-waarde veroorzaakt een fout. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Valideer alleen gebruikte waarden, bewaar één korte foutmelding of undef en plaats resources in de geldige tak. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Niet-ingesteld is op zichzelf geen fout; een losse fail halverwege resources of waarden is geen toegestane structuur.

**Handmatige review**

Volg beide gebruikspaden en controleer dat de foutmelding in de laatste else staat.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Volg beide gebruikspaden en controleer dat de foutmelding in de laatste else staat. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Classcontroles hergebruiken

**Norm**

Gebruik binnen een class of defined type één gedeelde variabele als dezelfde classcontrole vaker nodig is. Gebruik een eenmaal gelezen zuivere classcontrole rechtstreeks; controleer indirecte afnemers vóór verwijderen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Letterlijke defined(Class)-controles in iedere class-/definebody, lokale resultaatvariabelen en vindbare classafnemers.

**Automatische controle**

`project_class_check_reuse`

**Detectiegrenzen**

Dynamische namen, parameterdefaults en indirecte lookups worden niet bewezen. Parenthergebruik vereist een positieve omvattende if; or, negatie, else en andere declaraties bewijzen geen beschikbaarheid.

**Meldingen en severity**

`Evaluate repeated defined(Class[...]) checks once in a shared variable within this class or define; preserve evaluation order`: `warning` bij herhaling. `Inline a defined(Class[...]) result used only once; keep a shared variable only for repeated use and preserve evaluation order`: `warning` bij één lezing. `Remove an unused defined(Class[...]) variable; verify indirect consumers before changing it`: `warning` bij nul lezingen. `[review] Reuse {classvariabele} from the guarded class instead of repeating defined(Class[...]); verify variable availability and evaluation order`: `warning` bij gevonden parentresultaat; `{classvariabele}` is variabel.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een samengestelde voorwaarde mag een eigen betekenisvolle naam houden. Vindbaar gebruik vanuit andere manifests, statische ERB en inline_template telt mee.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_class_check_reuse` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_class_check_reuse warning -->
```puppet
class example { notice(defined(Class['optional'])); notice(defined(Class['optional'])) }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_class_check_reuse` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_class_check_reuse clean -->
```puppet
class example { $enabled = defined(Class['optional']); notice($enabled); notice($enabled) }
```

**Grensgevallen**

Een samengestelde voorwaarde mag een eigen betekenisvolle naam houden. Vindbaar gebruik vanuit andere manifests, statische ERB en inline_template telt mee. Dynamische namen, parameterdefaults en indirecte lookups worden niet bewezen. Parenthergebruik vereist een positieve omvattende if; or, negatie, else en andere declaraties bewijzen geen beschikbaarheid. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Classcontroles hergebruiken](#verdieping-bij-classcontroles-hergebruiken).

**Handmatige review**

Controleer parentdeclaratie, positieve guard, iedere toekenning en afnemer en het evaluatiemoment; een tussenliggende classdeclaratie kan defined veranderen.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [parent_class_checks_test.rb](../tests/parent_class_checks_test.rb), [class_consumers_test.rb](../tests/class_consumers_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Classcontroles hergebruiken

Levert die class al het resultaat van een classcontrole, gebruik dan binnen de geldige tak die variabele. Zo verwijst een Docker-define naar `$docker::monitoring_enable` in plaats van opnieuw `defined(Class['basic_settings::monitoring'])` te berekenen. Controleer dat de class de variabele op dat uitvoerpad invult en dat de afnemer dezelfde betekenis en evaluatievolgorde nodig heeft.

Gebruik binnen een class of defined type één gedeelde variabele als dezelfde classcontrole vaker nodig is. Dat geldt ook bij gebruik in verschillende geneste blokken. Wordt de uitkomst maar één keer gebruikt, neem de controle dan rechtstreeks in de expressie op. Een samengestelde voorwaarde mag wel een eigen naam hebben, zoals `$active = $ensure == present and defined(Class['basic_settings::monitoring'])`: die naam beschrijft wanneer het onderdeel actief is.

`project_class_check_reuse` telt letterlijke classcontroles en vindbaar gebruik van hun resultaat, ook vanuit andere manifests en templates. Binnen een positieve classcontrole meldt hij ook beschikbare classvariabelen voor hergebruik. De [technische naslag](../README.md#classcontroles-en-vindbare-afnemers) beschrijft de grenzen van deze analyse. Dynamische classnamen, parameterdefaults en indirecte lookups beoordeel je zelf.

Er is geen autofix voor samenvoegen of inlinen. `defined(...)` kijkt naar wat tijdens evaluatie al bekend is; een classdeclaratie tussen twee controles kan de uitkomst veranderen. Controleer daarom de [declaratievolgorde](#resources-en-afhankelijkheden) en behoud afnemers die de statische analyse niet vindt.

### Parentclass als prerequisite controleren

**Norm**

Een defined type dat zijn parentclass nodig heeft, controleert eerst `defined(Class['...'])`. Plaats alle code die van die class afhangt in de geldige tak en geef een duidelijke fout als de class ontbreekt.

**Herkomst**

Projectregel

**Toepassingsgebied**

Defined types die een parentclass of haar variabelen nodig hebben.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Classcontroles hergebruiken](#classcontroles-hergebruiken).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een eindcatalogus met de class bewijst niet dat zij vóór de controle geëvalueerd was.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een eindcatalogus met de class bewijst niet dat zij vóór de controle geëvalueerd was.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een define leest een parentvariabele voordat de aanwezigheid van de class is gecontroleerd. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Controleer defined(Class[...]), plaats afhankelijke code in de geldige tak en geef bij ontbreken een duidelijke fout. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een eindcatalogus met de class bewijst niet dat zij vóór de controle geëvalueerd was.

**Handmatige review**

Valideer de aanwezigheid en afwezigheid en de daadwerkelijke evaluatievolgorde van parent en afnemer.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Valideer de aanwezigheid en afwezigheid en de daadwerkelijke evaluatievolgorde van parent en afnemer. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Resources en afhankelijkheden

<!-- lint-rule-group -->

### Optionele resource-attributen vooraf bepalen

**Norm**

Gebruik één declaratie met vooraf berekende waarden wanneer resources alleen in optionele attributen verschillen. Een niet-ingesteld attribuut krijgt `undef`. Zorg daarbij dat `source` en `content` nooit tegelijk gevuld zijn. `project_files` controleert of die uitsluiting uit de code volgt; onopgeloste of overgeërfde waarden vragen een controle van de effectieve catalogus.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

File-resources waarvan optionele source/content-attributen vooraf worden berekend.

**Automatische controle**

`project_files`

**Detectiegrenzen**

Zichtbare lokale resourcedefaults worden meegenomen. Letterlijke undef en herkenbare wederzijdse guards kunnen uitsluiting bewijzen; onbekende, overgeërfde of overridende waarden vragen catalogusreview. Het samenvoegen van overige optionele resource-attributen wordt niet automatisch beoordeeld.

**Meldingen en severity**

`[review] Prove source and content cannot both resolve to non-undef values`: `warning` wanneer wederzijdse uitsluiting niet statisch bewezen is.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Niet-ingestelde attributen krijgen undef; dat is geen uitzondering op wederzijdse uitsluiting.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_files`; verwacht warning.

<!-- lint-example: project_files warning -->
```puppet
file { '/tmp/example': ensure => file, owner => 'root', group => 'root', mode => '0600', source => $source, content => $content }
```

**Correct voorbeeld**

Fragment; alleen `project_files`; verwacht geen melding.

<!-- lint-example: project_files clean -->
```puppet
file { '/tmp/example': ensure => file, owner => 'root', group => 'root', mode => '0600', source => undef, content => 'Example' }
```

**Grensgevallen**

Twee onbekende waarden leveren review op, ook met een vergelijkbare variabelenaam. Een aantoonbare guard kan uitsluiting bewijzen. Controleer zowel geldige als ongeldige branches en effectieve cataloguswaarden.

**Handmatige review**

Controleer per uitvoerpad welke optionele attributen ingevuld zijn en dat source/content nooit beide een niet-undef-waarde krijgen. Behoud resourceattributen en relaties bij samenvoegen.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](../tests/resource_contract_test.rb), [source_uri_test.rb](../tests/source_uri_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Arrays met concat combineren

**Norm**

Combineer arrays met `concat($base, $extra)` en behoud de elementvolgorde. `project_arrays` meldt `+` bij herkenbare arrays, maar berekent geen dynamische typen en heeft geen autofix. Gebruik een eenmalige tussenvariabele wanneer de naam betekenis toevoegt of de code duidelijker maakt.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Optelling van herkenbare arraywaarden in Puppet-expressies.

**Automatische controle**

`project_arrays`

**Detectiegrenzen**

De check herkent arrayliterals en gevolgde lokale arraywaarden, maar berekent geen willekeurige dynamische typen. Een niet-herkende array blijft onder de norm vallen.

**Meldingen en severity**

`Combine arrays with concat(...) while preserving element order`: `warning` bij + met een herkenbare array.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Getal- en hashoptelling blijven toegestaan; een eenmalige tussenvariabele mag betekenis toevoegen of de leesbaarheid verbeteren.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_arrays` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_arrays warning -->
```puppet
$values = [1] + [2]
```

**Correct voorbeeld**

Fragment; alleen de controle `project_arrays` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_arrays clean -->
```puppet
$values = concat([1], [2])
```

**Grensgevallen**

Getal + getal en hash + hash: toegestaan. Arrayliteral + arrayliteral: warning. Onopgeloste waarden: type handmatig bepalen. concat bewaart de elementvolgorde.

**Handmatige review**

Bepaal de effectieve typen van dynamische waarden en vergelijk de volledige elementvolgorde vóór en na vervanging door concat.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_contract_test.rb](../tests/resource_contract_test.rb), [source_uri_test.rb](../tests/source_uri_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Bestaande interfaces voor integratiewaarden gebruiken

**Norm**

Gebruik de bestaande interface om gegevens van een andere bouwsteen te verkrijgen. Een resource, alias, servicetitel of geaccepteerde API kan bijvoorbeeld het pad, de poort of de unitnaam leveren. Bouw die waarden niet zelfstandig opnieuw op; valideer de afspraak tussen beide onderdelen. Als een interface-uitbreiding is afgewezen, werk dan met de geaccepteerde interface of stabiele externe runtimemetadata, zonder alsnog ongedocumenteerde gemaksparameters toe te voegen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Paden, poorten, unitnamen en andere gegevens tussen lokale bouwstenen.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Resources en afhankelijkheden](#resources-en-afhankelijkheden).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een afgewezen interface-uitbreiding mag niet via ongedocumenteerde gemaksparameters alsnog worden toegevoegd.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een afgewezen interface-uitbreiding mag niet via ongedocumenteerde gemaksparameters alsnog worden toegevoegd.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een afnemer bouwt een servicetitel opnieuw op met ongedocumenteerde naamregels. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Lees de waarde via de geaccepteerde resource, alias, servicetitel of API. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een afgewezen interface-uitbreiding mag niet via ongedocumenteerde gemaksparameters alsnog worden toegevoegd.

**Handmatige review**

Vergelijk de contractafspraak tussen beide onderdelen en gebruik na een afgewezen uitbreiding uitsluitend de geaccepteerde route of stabiele externe runtimemetadata.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Vergelijk de contractafspraak tussen beide onderdelen en gebruik na een afgewezen uitbreiding uitsluitend de geaccepteerde route of stabiele externe runtimemetadata. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Dependencies pas na een geslaagde controle koppelen

**Norm**

`defined(...)` ziet alleen wat tijdens evaluatie al bekend is. Koppel een `require` daarom pas na een geslaagde controle aan een geaccepteerde resource of gedocumenteerd anker. Wordt de afhankelijkheid via wrappers geleverd, controleer dan eerst de directe resource, vervolgens de wrapper en daarna de parentwrapper. De eindcatalogus kan andere resources bevatten dan op dat eerdere evaluatiemoment zichtbaar waren.

**Herkomst**

Projectregel

**Toepassingsgebied**

Voorwaardelijke require-relaties met directe resources, wrappers en parentwrappers.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Resources en afhankelijkheden](#resources-en-afhankelijkheden).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een gedocumenteerd anker blijft toegestaan; een later gevulde eindcatalogus is geen bewijs voor vroegere defined-uitkomsten.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een gedocumenteerd anker blijft toegestaan; een later gevulde eindcatalogus is geen bewijs voor vroegere defined-uitkomsten.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een require wordt gekoppeld op basis van een pas later zichtbare wrapper. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Controleer eerst directe resource, dan wrapper en parentwrapper; koppel na succes aan een geaccepteerde resource of anker. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een gedocumenteerd anker blijft toegestaan; een later gevulde eindcatalogus is geen bewijs voor vroegere defined-uitkomsten.

**Handmatige review**

Traceer zichtbaarheid op het evaluatiemoment en onderscheid die van de uiteindelijke catalogus.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Traceer zichtbaarheid op het evaluatiemoment en onderscheid die van de uiteindelijke catalogus. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Prerequisites van ordering onderscheiden

**Norm**

Maak bij dependencies onderscheid tussen wat een operatie nodig heeft om te kunnen draaien en wat alleen de uitvoervolgorde bepaalt. Het weglaten van een dependencyreference, zoals `require`, schakelt de afhankelijke operatie niet uit. Leid runtimebeschikbaarheid nooit uitsluitend af uit de aanwezigheid of afwezigheid van een declaratie.

Het gedocumenteerde contract moet vereiste prerequisites vóór gebruik leveren of het gedrag bij ontbreken vastleggen: sla een optionele operatie over of faal duidelijk bij een verplichte operatie. De [prerequisitereview](../../../AGENTS.md#prerequisite-review) vereist validatie met prerequisites aanwezig en afwezig, inclusief de relevante declaratie- en evaluatievolgorde.

**Herkomst**

Projectregel

**Toepassingsgebied**

Operaties met vereiste of optionele runtimeprerequisites en resource-ordering.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Resources en afhankelijkheden](#resources-en-afhankelijkheden).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Een weggelaten relatie schakelt niets uit; een declaratie alleen bewijst geen runtimebeschikbaarheid.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Een weggelaten relatie schakelt niets uit; een declaratie alleen bewijst geen runtimebeschikbaarheid.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een operatie zonder beschikbare tool blijft actief omdat alleen require is weggelaten. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Lever de vereiste prerequisite of het gedocumenteerde gedrag voor afwezigheid en beoordeel ordering afzonderlijk. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Een weggelaten relatie schakelt niets uit; een declaratie alleen bewijst geen runtimebeschikbaarheid.

**Handmatige review**

Controleer aanwezigheid, afwezigheid, declaratievolgorde en evaluatievolgorde volgens de gekoppelde prerequisitereview.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer aanwezigheid, afwezigheid, declaratievolgorde en evaluatievolgorde volgens de gekoppelde prerequisitereview. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Packageafhankelijkheden bij externe commando’s

<a id="packages-voor-externe-commandos"></a>

**Norm**

Borg de packages die externe commando’s leveren bij de functionaliteit die ze uitvoert. Dit geldt voor Puppet-`exec`-resources, monitoringchecks en andere door Puppet beheerde scripts. Vertrouw niet op de hoofdclass `basic_settings`, een optionele class of de basisinstallatie. Een monitoringcheck moet bruikbaar zijn met alleen zijn eigen module en `basic_settings::monitoring`.

Inventariseer bij een `exec` het effectieve `command`, of de resourcetitel wanneer `command` ontbreekt, en alle commando’s in `onlyif`, `unless` en `refresh`. Neem string- en arrayvormen mee. Bekijk bij iedere toepassing de interpreter, aangeroepen scripts, pipelines, command substitutions, vaste executablepaden en conditionele uitvoerpaden. Onderscheid externe executables van shell-builtins en lokale functies.

Controleer per ondersteunde distributie en pakketbron welk package het executable levert; leid de packagenaam niet uit de commandonaam af. `cmp` komt bijvoorbeeld uit `diffutils` en `awk` heeft meerdere providers. NodeSource levert npm via `nodejs`, terwijl Debian en Ubuntu daarvoor een afzonderlijk `npm`-package leveren.

Borg ontbrekende algemene modulepackages met `ensure_packages` in de hoofdclass en groepeer gelijke instellingen volgens [pakketten en mappen](OPERATIONAL_RULES.md#pakketten-en-mappen). Een define die zijn parentclass vereist, controleert die afhankelijkheid expliciet en hergebruikt haar packages zonder eigen `ensure_packages` of package-declaraties. Een zelfstandige define mag zijn specifieke packages zelf beheren; gedeelde scripts en hun packages hebben één eigenaar.

Verplaats verspreid packagebeheer naar die eigenaar met behoud van optionele installatievoorwaarden en uitvoeringsrelaties. Voor een package dat alleen actieve onderdelen nodig hebben, kan de hoofdclass een [virtuele package met `realize()`](#optionele-packages-activeren-met-realize) aanbieden. Declareer geen extra package als installatie al in dezelfde module of een verplichte parentclass op ieder relevant uitvoerpad is geborgd. Ook een verplichte package-afhankelijkheid kan volstaan wanneer de dependencyketen voor de ondersteunde pakketbronnen is gecontroleerd; een aanbeveling volstaat niet.

Controleer installatie en uitvoeringsvolgorde afzonderlijk. Een `Package[...]`-verwijzing installeert niets; de tekstuele plaats van een package vóór een `exec` bewijst geen dependency. Borg de volgorde met `require`, een andere passende Puppet-relatie of een aantoonbaar geldige dependencyketen. Bij gedeelde scripts wachten ook de registraties of uitvoerders via het executable op zijn packages. Gebruik bij een bewust afzonderlijk beheerde applicatie-installatie de bestaande installatieresource en behoud haar voorwaarden.

Een executable dat uitsluitend op aanwezigheid wordt getest, is geen verplichte dependency. Behoud bewust optionele tools met werkende terugvalroutes: een package toevoegen mag de betekenis van een guard of installatieprocedure niet veranderen. De enige uitzondering voor een vereist executable is de reeds benodigde Puppet/OpenVox-agent zelf. De agentcheck hergebruikt `puppet`; voeg daarvoor geen agentpackage, packagekeuzeparameter of package-`require` toe. De overige hulpmiddelen blijven expliciet geborgd.

**Herkomst**

Projectregel. De beperkte providertabel volgt de Debian/Ubuntu-packages, waaronder de bestandslijsten voor curl bij [Debian](https://packages.debian.org/trixie/amd64/curl/filelist) en [Ubuntu](https://packages.ubuntu.com/noble/amd64/curl/filelist), en de [Debian-documentatie van cmp uit diffutils](https://manpages.debian.org/bookworm/diffutils/cmp.1.en.html).

**Toepassingsgebied**

Externe commando’s in alle `exec`-velden en door Puppet beheerde scripts, inclusief monitoring, met hun installatiegaranties en uitvoeringsrelaties.

**Automatische controle**

`project_exec_packages` controleert een begrensd deel van `exec`-resources. De check gebruikt de expliciete Debian/Ubuntu-koppelingen `bash → bash`, `cmp → diffutils`, `curl → curl`, `jq → jq`, `rsync → rsync`, `tar → tar`, `unzip → unzip` en `wget → wget`. Hij herkent deze namen als eerste executable, ongewijzigd of onder `/bin/` en `/usr/bin/`, in `command`, de impliciete commandotitel, `onlyif`, `unless` en `refresh`. Argumentarrays en arrays met afzonderlijke guards worden volgens hun eigen betekenis behandeld. Een vaste commandoprefix vóór geïnterpoleerde argumenten en een eenduidige voorafgaande lokale toekenning tellen mee.

De analyse hergebruikt lokale resource-defaults en vaste package-/referencelijsten, ook via `concat`. Hij beoordeelt `package`-declaraties en `ensure_packages` afzonderlijk van relaties via `require`, `subscribe`, `before`, `notify` en relatiepijlen. Eenvoudige transitieve relaties via bestanden tellen mee. Packages in een bereikbare class tellen mee via `include`, `contain`, `require`, classdeclaraties of een positieve omvattende `defined(Class[...])`-guard met één classreference. Classbronnen komen uit dezelfde invoer of het [ingestelde modulepad](../README.md#aanroepen-van-modules-controleren). Alleen een classreference bewijst geen installatie; `include` bewijst geen ordering.

`PackageGraph` beoordeelt relevante routes door `case`, `if`/`elsif`/`else` en `unless` afzonderlijk, inclusief geneste keuzes en keuzes binnen verplichte parentclasses. Een package is gegarandeerd wanneer iedere route waarop de onderzochte `exec` kan bestaan zijn installatie borgt. Verschillende geldige dependencyketens per route mogen dezelfde ordering bewijzen; installatie en relaties uit verschillende routes worden nooit samengevoegd tot één bewijs.

Een ontbrekende `else` of `default` telt als een lege route. Een rechtstreeks, aantoonbaar uitgevoerd `fail()` beëindigt een route zonder catalogus; die route hoeft geen runtimepackages te leveren. Lokale variabelen en lijsten mogen per route verschillen als een eenduidige eerdere toekenning op die route hun waarde vastlegt; parameterdefaults zijn geen vaste waarden.

`project_packages`, `project_guarded_packages` en de resourcechecks blijven verantwoordelijk voor APT-opties, groepering en resourceopmaak. `project_shell` blijft verantwoordelijk voor escaping. De keuze van de package-eigenaar en de inhoud van gewone scripts en monitoringexecutables vragen handmatige review; daarvoor geldt dezelfde bovenstaande norm.

**Detectiegrenzen**

De check is geen shellparser, cataloguscompiler of package-resolver. Hij volgt geen pipelines, substitutions, shellfuncties, `sh -c`-bodies, templates of aangeroepen scripts. Onbekende executable-namen en volledig dynamische commando’s blijven handmatige review en krijgen niet ieder een algemene melding. Strings met een terugvaloperator `||`, backticks of nieuwe regels vallen buiten de entrypointdetectie. Dit is een analysegrens, geen vrijstelling van de norm.

Dynamische packages, providers, resource-overrides, collectors, classinheritance en onopgeloste relaties kunnen geen bewezen installatie of ordering leveren. Niet uitgewerkte defined types en resourcecreatie via `create_resources` of `ensure_resources` leveren evenmin zelfstandig bewijs. Een concrete herkende commandodependency krijgt dan gericht review wanneer zijn garantie niet kan worden vastgesteld. De check berekent geen package-dependencies uit distributiemetadata en geen willekeurige voorwaarden of caller-metaparameters. Controleer die ketens in de catalogus. Een geslaagde lintscan bewijst nooit dat alle runtimepackages aanwezig zullen zijn, ook niet bij monitoring.

Een virtuele `@package` levert evenmin automatisch installatiebewijs: `PackageGraph` volgt de activatie door `realize()` niet. Ook met een passende `require` volgt voor een herkend commando `[review]` wanneer alleen die virtuele declaratie de installatie moet borgen. Dit kan geldige Puppet-code zijn; voeg geen dubbele declaratie of onvoorwaardelijke installatie toe om die analysegrens te omzeilen. Onderbouw de garantie met catalogusreview.

De routeanalyse gebruikt de codestructuur en voert geen Puppet-functies of voorwaarden uit. Zij leidt geen verband af tussen afzonderlijke voorwaarden en bewijst geen volledige `case`-dekking uit een parametertype of regexlabels zonder `default`. Per package en `exec` worden maximaal 128 analysestaten onderzocht; als relevante routes overblijven, volgt `[review]`, met behoud van een al bewezen installatiegarantie. Niet-relevante keuzes en al volledig bewezen garanties vragen geen verdere vertakking.

**Meldingen en severity**

Alle varianten zijn `warning`; `[review]` is een tekstlabel. De vaste prefix is `Exec {veld} uses {commando} ({package}):` met uitsluitend het veld en namen uit de providertabel:

- `no package installation guarantee in the owning code; a Package reference does not install it`: De benodigde package is bekend en installatie ontbreekt in de geanalyseerde eigenaar.
- `package installation is declared but no dependency path orders it before execution`: Installatie is aantoonbaar, maar een uitvoeringsrelatie ontbreekt in de geanalyseerde code.
- `[review]` vóór de prefix met `resolve conditional, external or dynamic package installation evidence`: Voor de concrete dependency is de installatiegarantie niet vast te stellen.
- `[review]` vóór de prefix met `package installation is declared; resolve the indirect execution order`: Installatie is aantoonbaar, maar de indirecte ordering is niet vast te stellen.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: packages raden, installatiegedrag wijzigen of relaties zonder voldoende bewijs toevoegen is geen veilige automatische correctie.

**Toegestane uitzonderingen**

De reeds benodigde Puppet/OpenVox-agent en bewust optionele tools met geteste terugvalroutes zoals hierboven beschreven. Een bestaande module- of parentclassinstallatie of gecontroleerde verplichte packageketen is een geldige garantie, geen reden voor een tweede declaratie.

**Suppressions**

Suppressie van `project_exec_packages` is niet toegestaan. Een lintmarkering kan ook de handmatige review niet vervangen.

**Onjuist voorbeeld**

Fragment; `project_exec_packages` meldt ontbrekende installatie, ondanks de reference.

<!-- lint-example: project_exec_packages warning -->
```puppet
exec { 'compare':
  command => '/usr/bin/cmp /tmp/first /tmp/second',
  require => Package['diffutils'],
}
```

**Correct voorbeeld**

Fragment; `project_exec_packages` accepteert de installatie en de indirecte uitvoeringsrelatie.

<!-- lint-example: project_exec_packages clean -->
```puppet
ensure_packages('diffutils', {
  'ensure'          => 'installed',
  'install_options' => ['--no-install-recommends', '--no-install-suggests'],
})
file { '/tmp/first':
  require => Package['diffutils'],
}
exec { 'compare':
  command => '/usr/bin/cmp /tmp/first /tmp/second',
  require => File['/tmp/first'],
}
```

**Grensgevallen**

Een losse `test -x /usr/bin/curl` of `command -v curl` maakt curl niet verplicht. De check herkent zo’n enkelvoudige aanwezigheidscontrole in `onlyif` ook als optionele uitvoering van het corresponderende hoofd- of refreshcommando. Een aanwezigheidscontrole in `unless` kan juist een installatieprocedure beschermen; die blijft behouden. Een package in een andere branch bewijst geen installatie voor deze branch. Een package dat elders in dezelfde module staat telt pas mee wanneer de installatie op het relevante uitvoerpad is geborgd.

Installatie in iedere keuzetak kan een garantie leveren, ook als een tak aanvullende packages installeert. Een tak met `ensure => absent`, een onopgeloste waarde of ontbrekende ordering verhindert goedkeuring voor alle routes. Als de `exec` zelf slechts in één tak staat, tellen alleen de routes mee waarop die `exec` bestaat; een package uitsluitend in de tegenoverliggende tak geeft dan een concrete melding voor ontbrekende installatie.

**Handmatige review**

Leg per gewijzigde functionaliteit commando’s, providers, installatiegaranties en uitvoeringsrelaties vast. Neem alle uitvoerpaden en aanroepende resources mee, inclusief interpreter, scripts, pipelines, substitutions en optionele terugvalroutes. Beoordeel dezelfde punten bij monitoring en gewone scripts, ook wanneer de linter niets meldt.

Beoordeel packagebeheer voor de hele module: controleer welke defines hun parentclass vereisen, welke zelfstandig bruikbaar zijn en welke packages meerdere onderdelen delen. Controleer na verplaatsing dat ieder gebruik op installatie wacht en dat optionele packages alleen op de bedoelde uitvoerpaden worden geactiveerd.

Valideer relevante catalogi zonder de hoofdclass `basic_settings` en met vereiste packages vooraf wel en niet gedeclareerd. Controleer conditionele providers met de relevante declaratie- en evaluatievolgorde. Valideer bij monitoring ook uitgeschakelde monitoring en twee registraties waarvan één vervalt; het gedeelde executable en de andere registratie moeten behouden blijven. Catalogus- en functionele validatie blijven buiten de repositorytooltests.

**Verificatie**

De voorbeeldparen worden door [guide_examples_test.rb](../tests/guide_examples_test.rb) gecontroleerd. [exec_packages_test.rb](../tests/exec_packages_test.rb), [package_graph_test.rb](../tests/package_graph_test.rb) en [package_graph_boundaries_test.rb](../tests/package_graph_boundaries_test.rb) controleren commandovelden, arrays, installatie, ordering, parenthergebruik en analysegrenzen via de native lintengine. [package_graph_branches_test.rb](../tests/package_graph_branches_test.rb) en [package_graph_branch_order_test.rb](../tests/package_graph_branch_order_test.rb) bewaken volledige en onvolledige keuzes, geneste routes, lokale waarden, afzonderlijke dependencyketens en de analysegrens. [external_exec_packages_test.rb](../tests/external_exec_packages_test.rb) controleert de gebouwde gem vanuit een onafhankelijk consumerproject, inclusief parentkeuzes via het modulepad en ongewijzigde bron bij `--fix`. Deze tests bewijzen het toolcontract; leg catalogus- en runtimebewijs afzonderlijk vast in de wijzigingsreview.

#### Optionele packages activeren met realize

Gebruik dit patroon wanneer de hoofdclass de package-instellingen bezit, maar installatie alleen nodig is zodra een afhankelijke define actief wordt. Algemene packages die ieder gebruik van de module nodig heeft, blijven gewoon in `ensure_packages()` in de hoofdclass.

De hoofdclass beschrijft met `@package` de gewenste toestand zonder die al af te dwingen. De actieve define maakt diezelfde resource met `realize(Package[...])` beheerd. Meerdere defines mogen dezelfde resource activeren: er blijft één package-resource met één set instellingen. Zie de [Puppet-uitleg over virtuele resources](https://help.puppet.com/core/current/Content/PuppetCore/lang_virtual.htm).

Fragment uit [netplanio](../../../netplanio/manifests/init.pp); de hoofdclass beheert ook de algemene modulepackages:

```puppet
# Keep the optional package settings with their owner.
if (!defined(Package['wpasupplicant'])) {
  @package { 'wpasupplicant':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }
}
```

Fragment uit [netplanio::wifi](../../../netplanio/manifests/wifi.pp), binnen de bestaande parentclasscontrole en de tak voor `ensure => present`. Alleen de activatie en packagevolgorde zijn getoond; de overige bestandsattributen en de afhandeling van `absent` blijven in de define:

```puppet
# Activate the package before using its functionality.
realize(Package['wpasupplicant'])

file { "/etc/netplan/${name}.yaml":
  require => Package['netplan.io', 'wpasupplicant'],
}
```

`realize()` activeert de declaratie tijdens cataloguscompilatie; het voert de package-installatie niet direct uit en vervangt geen [uitvoeringsrelatie](https://help.puppet.com/core/current/Content/PuppetCore/lang_relationships.htm). Omgekeerd activeert alleen een `require` de virtuele package niet. In deze module wacht het configuratiebestand via `require` op de packages en meldt het wijzigingen aan de bestaande `netplan apply`-exec. Een `exec` die zelf het package nodig heeft, krijgt eveneens een passende dependency.

De vereiste parentclass moet bij evaluatie van de classcontrole bekend zijn. `realize()` zelf kan vóór de virtuele declaratie staan, maar de declaratie moet wel tijdens compilatie beschikbaar komen; anders mislukt compilatie. Een guard met `defined(Package[...])` voorkomt een tweede declaratie, maar bewijst niet dat de bestaande resource de juiste `ensure`, provider of installatieopties heeft. `realize()` herstelt die attributen niet.

Beoordeel bij dit patroon ten minste de volgende catalogi:

- Alleen de hoofdclass of uitsluitend afwezige WiFi-interfaces: de virtuele package wordt door deze module niet geactiveerd.
- Eén of meerdere aanwezige interfaces: één geïnstalleerde package-resource, met een dependency naar ieder afhankelijk configuratiebestand.
- Eén interface verdwijnt terwijl een andere actief blijft: de gedeelde package blijft actief. Laat een define haar daarom niet op `absent` zetten.
- Geen actieve afnemers meer: stoppen met realiseren verwijdert een eerder geïnstalleerd package niet automatisch.
- De parentclass ontbreekt of een bestaande package heeft conflicterende attributen: verifieer de parentfout respectievelijk wijs de ongeldige installatiegarantie af.

Dit zijn handmatige catalogusscenario’s, geen bewijs van automatische lintdekking. De [detectiegrenzen](#packageafhankelijkheden-bij-externe-commandos) gelden ook hier; `netplan` en de WiFi-tools staan bovendien niet in de beperkte commandolijst van `project_exec_packages`.

### Gedeelde voorwaarden om resources groeperen

**Norm**

Plaats resources die dezelfde voorwaarde delen in één buitenste voorwaarde. Hun eigen controles kunnen daarbinnen staan. Zo blijft zichtbaar welke verwerking volledig afhankelijk is van de beschikbaarheid of instelling die je controleert.

**Herkomst**

Projectregel

**Toepassingsgebied**

Resources met een gezamenlijke beschikbaarheids- of inschakelvoorwaarde, inclusief aanroepen van defined types en activatie van virtuele resources.

**Automatische controle**

`project_shared_conditions`

**Detectiegrenzen**

De check vergelijkt rechtstreekse `if`-opdrachten in hetzelfde AST-blok. Minstens één blok moet de gedeelde voorwaarde als volledige conditie gebruiken; andere blokken mogen diezelfde conditie gebruiken of ermee beginnen in een `and`-keten. Herkend worden variabelen, `==`/`!=` tussen een variabele links en een letterlijke scalaire waarde rechts, en negatie van deze expressies, ook met haakjes. Letterlijke stringwaarden worden gelijk behandeld met en zonder quotes; verschillende waardetypen blijven onderscheiden.

Beide geldige takken moeten resourcedeclaraties, defaults, overrides of een bekende resource-aanroep bevatten: `realize`, `include`, `contain`, `require`, `ensure_packages` of `stdlib::ensure_packages`, eventueel met `::` ervoor. Resources binnen iteraties tellen mee. Losse toekenningen leveren geen resourcegroep op. De vergelijking overschrijdt geen blok-, class-, define- of lambdagrenzen. `unless`, losse `elsif`-armen, `or` of functieaanroepen als gedeelde conditie, herleiding via andere conditievariabelen en een gedeelde term die niet vooraan staat vallen buiten de detectie. Twee samengestelde voorwaarden zonder bestaand blok voor alleen de gedeelde conditie worden niet gemeld. De check bewijst geen veilige verplaatsing of catalogusvolgorde.

**Meldingen en severity**

`[review] Group resource declarations under the existing condition at line {line}; preserve additional conditions, fallback branches and evaluation order`: `warning` op iedere andere kandidaat-`if` naast het eerste blok met de volledige gedeelde conditie. `{line}` is het regelnummer van dat bestaande blok; bronwaarden worden niet in de melding opgenomen.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: verplaatsen kan variabelegebruik, evaluatievolgorde, resourcevolgorde en de betekenis van `else`- of `elsif`-takken veranderen. De melding vraagt daarom inhoudelijke review.

**Toegestane uitzonderingen**

Resources met verschillende voorwaarden mogen die eigen controle behouden; de gedeelde buitenvoorwaarde vervangt haar niet. Beoordeel een noodzakelijke afwijkende plaats volgens [Resources bij hun voorziening plaatsen](#resources-bij-hun-voorziening-plaatsen).

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan. De native lintengine verwerkt suppressions technisch; `project_suppressions` bewaakt het verbod.

**Onjuist voorbeeld**

Fragment; alleen `project_shared_conditions` is voor dit voorbeeld bedoeld. Verwacht een warning bij de tweede `if`.

<!-- lint-example: project_shared_conditions warning -->
```puppet
if ($ensure == present) { file { '/tmp/example': } }
if ($ensure == present and $monitoring) { profile::check { 'example': } }
```

**Correct voorbeeld**

Fragment; controle `project_shared_conditions`; verwacht geen melding. De aanvullende monitoringvoorwaarde blijft binnen het gedeelde blok staan.

<!-- lint-example: project_shared_conditions clean -->
```puppet
if ($ensure == present) {
  file { '/tmp/example': }
  if ($monitoring) { profile::check { 'example': } }
}
```

**Grensgevallen**

Het bestaande blok mag vóór of na de specifiekere controle staan. Tussenliggende opdrachten verhinderen detectie niet, maar kunnen samenvoegen wel beïnvloeden. `defined(...)` wordt niet als gedeelde conditie hergebruikt: een tussenliggende declaratie kan de uitkomst veranderen. Een samengestelde conditie mag binnen haar eigen tak blijven bestaan; de check verwijdert of verplaatst niets.

**Handmatige review**

Volg alle afhankelijke verwerking en behoud iedere aanvullende lokale voorwaarde. Controleer bij samenvoegen de beschikbaarheid van variabelen, resourceplaatsing, notificaties en dependencies. Houd de afhandeling voor afwezige of uitgeschakelde resources volledig: een `else` van een samengestelde voorwaarde kan meerdere situaties afhandelen. Valideer de betrokken catalogi met de prerequisites en inschakelvoorwaarden aanwezig en afwezig.

**Verificatie**

[shared_conditions_test.rb](../tests/shared_conditions_test.rb) controleert detectie, bronposities, beide bronvolgorden, aanvullende voorwaarden, verschillende resourcetypen, scopes, analysegrenzen, native suppressions en ongewijzigde bron bij `--fix`. [guide_examples_test.rb](../tests/guide_examples_test.rb) voert de gemarkeerde voorbeeldparen uit. [external_shared_conditions_test.rb](../tests/external_shared_conditions_test.rb) controleert de nieuwe check, exitcodes en ongewijzigde bron vanuit een onafhankelijk geïnstalleerd gempakket. Dit bewijst het toolcontract; module- en hostgedrag worden afzonderlijk gevalideerd.

### Aanroepen en publieke interfaces

<!-- lint-rule-group -->

### Alle verplichte argumenten doorgeven

**Norm**

Geef bij een class- of defined-type-aanroep alle verplichte parameters mee. Ook een `Optional[...]` zonder default blijft een verplicht argument: het type staat `undef` toe, maar vult geen ontbrekende waarde in.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Class- en defined-type-resourceaanroepen met statisch gevonden declaraties en zonder splat.

**Automatische controle**

`project_interface_calls`

**Detectiegrenzen**

Onvindbare declaraties, dynamische namen, include/contain, splats, Hiera, types, onbekende parameters, overerving en containment worden niet volledig gecontroleerd. Het modulepad bepaalt de vindbare versie.

**Meldingen en severity**

`Public interface call omits required parameters: {namen}`: `warning`; de variabele lijst noemt ontbrekende verplichte parameters.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een parameter met een echte default hoeft niet expliciet mee; Optional zonder default blijft verplicht.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_interface_calls` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_interface_calls warning -->
```puppet
define example::item (String $value) {}
example::item { 'demo': }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_interface_calls` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_interface_calls clean -->
```puppet
define example::item (String $value) {}
example::item { 'demo': value => 'synthetic' }
```

**Grensgevallen**

Een vindbare Optional zonder default blijft vereist; een niet-vindbare declaratie kan geen melding over haar vereiste parameters geven. Een splat voorkomt volledige statische argumentcontrole.

**Handmatige review**

Controleer de gekozen moduleversie, alle vereiste argumenten en de eigen catalogusvalidatie, ook zonder lintmelding.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [interface_contract_test.rb](../tests/interface_contract_test.rb), [parameter_passthrough_test.rb](../tests/parameter_passthrough_test.rb), [parameter_filter_defaults_test.rb](../tests/parameter_filter_defaults_test.rb), [parameter_filter_predicate_test.rb](../tests/parameter_filter_predicate_test.rb), [parameter_filter_source_test.rb](../tests/parameter_filter_source_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Alle verplichte argumenten doorgeven

`project_interface_calls` meldt ontbrekende argumenten bij declaraties die de check statisch kan vinden. Binnen deze repository is de eigen moduleverzameling het standaardzoekpad. De [modulepadregels](../README.md#aanroepen-van-modules-controleren) beschrijven hoe de declaratie wordt gekozen en welke aanroepen buiten de analyse vallen.

Een geslaagde scan bewijst geen geldige catalogus. Argumenttypen, onbekende parameters, Hiera, overerving, defaults, containment en splats vragen afzonderlijke catalogusvalidatie. Dat geldt ook wanneer de linter een declaratie niet vindt. De check heeft geen autofix; de juiste argumentwaarde volgt uit de interface en het bedoelde gebruik.

### Overbodige parameterdoorgifte rechtstreeks schrijven

**Norm**

Geef waarden rechtstreeks als benoemde attributen mee wanneer een hash alleen gelijknamige variabelen doorgeeft, zonder verdere verwerking. Schrijf bijvoorbeeld `retention_days => $retention_days` in de resource, in plaats van een hash met die combinatie te maken en die via `* => $settings` uit te pakken.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Hashes bij * => en eerdere eenduidige lokale hashtoekenningen; gefilterde keys bij vindbare ontvangende defined types.

**Automatische controle**

`project_parameter_passthrough`

**Detectiegrenzen**

Onbekende declaraties en splats verhinderen argumentcontrole. Filteranalyse sluit classes met automatische lookup, onbekende bronwaarden/defaults, dynamiek, gekwalificeerde bronvariabelen, resourcedefaults, overrides en overerving uit; alle onderstaande filtervoorwaarden blijven van toepassing.

**Meldingen en severity**

`[review] Pass same-named variables directly as resource attributes`: `warning` bij volledig gelijknamige ongefilterde doorgifte. `[review] Pass this key directly: its source value/default matches the receiving default; review effective values and other hash consumers`: `warning` per overbodig gefilterde key.

**Autofix**

Geen voor beide varianten.

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Een filter blijft behouden voor keys waarvoor afwijkende invoer een andere eindwaarde moet krijgen. Gewone configuratiehashes vallen buiten de doorgifteregel; geen default toevoegen enkel om Optional te hersorteren.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_parameter_passthrough`; verwacht warning.

<!-- lint-example: project_parameter_passthrough warning -->
```puppet
example { 'synthetic': * => { 'label' => $label } }
```

**Correct voorbeeld**

Fragment; alleen `project_parameter_passthrough`; verwacht geen melding.

<!-- lint-example: project_parameter_passthrough clean -->
```puppet
example { 'synthetic': label => $label }
```

**Grensgevallen**

Een filter blijft behouden voor keys waarvoor afwijkende invoer een andere eindwaarde moet krijgen. Gewone configuratiehashes vallen buiten de doorgifteregel; geen default toevoegen enkel om Optional te hersorteren. Onbekende declaraties en splats verhinderen argumentcontrole. Filteranalyse sluit classes met automatische lookup, onbekende bronwaarden/defaults, dynamiek, gekwalificeerde bronvariabelen, resourcedefaults, overrides en overerving uit; alle onderstaande filtervoorwaarden blijven van toepassing. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Overbodige parameterdoorgifte rechtstreeks schrijven](#verdieping-bij-overbodige-parameterdoorgifte-rechtstreeks-schrijven).

**Handmatige review**

Vergelijk per key de effectieve bronwaarde en ontvangende default en valideer catalogi vóór rechtstreekse doorgifte. Behoud nuttige filters voor andere keys en controleer alle hashafnemers en hoofdlettergevoelige ontvangende waarden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [interface_contract_test.rb](../tests/interface_contract_test.rb), [parameter_passthrough_test.rb](../tests/parameter_passthrough_test.rb), [parameter_filter_defaults_test.rb](../tests/parameter_filter_defaults_test.rb), [parameter_filter_predicate_test.rb](../tests/parameter_filter_predicate_test.rb), [parameter_filter_source_test.rb](../tests/parameter_filter_source_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Overbodige parameterdoorgifte rechtstreeks schrijven

Geef waarden rechtstreeks als benoemde attributen mee wanneer een hash alleen gelijknamige variabelen doorgeeft, zonder verdere verwerking. Schrijf bijvoorbeeld `retention_days => $retention_days` in de resource, in plaats van een hash met die combinatie te maken en die via `* => $settings` uit te pakken.

Beoordeel een filter per hashkey. Zoek de bronwaarde of parameterdefault op en vergelijk die met de default van de ontvangende parameter. Geef die key rechtstreeks door wanneer het filter voor die key niets verandert aan de ontvangen waarde. Behoud het filter voor andere keys waarvoor het wel betekenis heeft. Gelijke parameternamen of gelijke parameterdefaults aan beide kanten zijn op zichzelf geen bewijs: een default kan worden overschreven en het filter kan die afwijkende invoer bewust uitsluiten. Dit geldt voor tekst, getallen, booleans, `undef`, arrays en hashes.

Bij een vaste lokale toekenning `$bron = 2` en ontvangende default `2` leveren zowel `$value != 2` als `$value == 2` dezelfde eindwaarde als rechtstreekse doorgifte. Heeft de bronparameter alleen default `2`, dan blijft afwijkende invoer mogelijk. `$value != 2` laat die afwijkende invoer door; `$value == 2` sluit haar juist uit. Ook `$value != 0` kan dan nuttig zijn: invoer `0` leidt door het filter tot de ontvangende default `2`.

`project_parameter_passthrough` meldt eenvoudige, ongefilterde doorgifte wanneer alle hashkeys overeenkomen met rechtstreeks gebruikte variabelenamen. Bij een filter controleert hij iedere key afzonderlijk. Hij volgt de bronvariabele via eerdere, eenduidige lokale toekenningen en verwijzingen naar andere variabelen, of leest de parameterdefault van de omringende class of het defined type. Vervolgens vergelijkt hij die waarde met de default van de parameter die de hashkey aanwijst. De namen van bronvariabele en ontvangende parameter mogen verschillen. Een melding staat op de betreffende hashkey; een nuttig filter voor een andere key houdt die melding niet tegen.

De filteranalyse herkent `.filter` met twee ongetypeerde lambdaparameters zonder defaults en uitsluitend `$value != <letterlijke waarde>` of `$value == <letterlijke waarde>`, ook met omgekeerde operanden of haakjes. Bij gelijke vaste bron- en doelwaarden zijn beide vergelijkingen overbodig voor die key. Bij gelijke parameterdefaults meldt de check alleen `!=` met diezelfde default, zodat filters voor afwijkende invoer behouden blijven. Tekst, getallen, booleans, `undef` en letterlijke arrays en hashes worden exact vergeleken, inclusief hun typen. Bij meerdere filters moet elke voorwaarde aan deze criteria voldoen; een aanvullende voorwaarde wordt niet genegeerd.

De check herkent een hash bij `* =>` en een eerdere, eenduidige hashtoekenning binnen dezelfde scope. Hij zoekt de bron in die scope en het ontvangende defined type in de huidige bron of via het [modulepad](../README.md#aanroepen-van-modules-controleren). Onbekende bronwaarden, ontvangers of defaults krijgen geen filtermelding. Verplichte parameters zonder default, dynamische berekeningen, gekwalificeerde bronvariabelen en niet-eenduidige toekenningen blijven buiten de analyse; Puppet-functies en Hiera worden niet uitgevoerd. Ontvangende classes blijven buiten de filteranalyse vanwege automatische parameterlookup. Zichtbare resourcedefaults, resource-overrides en overerving vereisen ook handmatige review. Gewone configuratiehashes vallen buiten deze regel.

Er is geen autofix. Controleer de effectieve waarden en evaluatievolgorde met catalogusvalidatie voordat je een gemelde key rechtstreeks doorgeeft. Beoordeel ook andere afnemers van dezelfde hash voordat je die key eruit verwijdert. Houd rekening met configuratie buiten het geanalyseerde bestand en met Puppet-vergelijkingen: een tekstvergelijking kan ook andere hoofdletters accepteren, terwijl die schrijfwijze voor de ontvanger verschil maakt.

### Resource references

<!-- lint-rule-group -->

### References van hetzelfde type samenvoegen

**Norm**

Schrijf references van hetzelfde resourcetype binnen één array als één reference met meerdere titels, ook wanneer er references van andere typen tussen staan. Sorteer de titels alfabetisch en zet de samengevoegde reference op de plaats van de eerste reference van dat type. Dit geldt ook voor classes en eigen defined types. Beoordeel buiten dependency-attributen en losse relatieketens eerst de gevolgen voor de arraystructuur, zoals hieronder beschreven.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

References van hetzelfde type in arrays en titellijsten; dependency-attributen en losse relatieketens voor veilige correctie.

**Automatische controle**

`project_resource_references`

**Detectiegrenzen**

Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend.

**Meldingen en severity**

`Merge references of the same resource type within the array and sort their titles alphabetically`: `warning` bij herhaalde references van hetzelfde type. Bij een resulterende enkele dependency-reference kan `; remove the outer array around the resulting single reference` volgen. Onveilige correcties krijgen ` [review] Verify relationship context, array shape, title order and comments before changing this expression`; severity blijft warning.

**Autofix**

Voorwaardelijk voor de samenvoegvariant; Geen voor de variant met [review].

**Autofixvoorwaarden**

Alle relatie-, titel-, tussenliggende-element-, commentaar-, heredoc- en concatvoorwaarden hieronder gelden per variant. De fix behoudt dubbele titels, typegrenzen, tussenliggende references en de eerste positie van het samengevoegde type.

**Toegestane uitzonderingen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_resource_references` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_resource_references warning -->
```puppet
notify { 'demo': require => [Package['zulu'], Package['alpha']] }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_resource_references` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_resource_references clean -->
```puppet
notify { 'demo': require => Package['alpha', 'zulu'] }
```

**Grensgevallen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn. Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij References van hetzelfde type samenvoegen](#verdieping-bij-references-van-hetzelfde-type-samenvoegen).

**Handmatige review**

Vergelijk per arraylaag elementvorm, titelvolgorde en comments. Beoordeel of het relatieresultaat wordt gebruikt en of het eerste concatargument aantoonbaar een array is.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [reference_merging_test.rb](../tests/reference_merging_test.rb), [reference_safety_test.rb](../tests/reference_safety_test.rb), [reference_wrappers_test.rb](../tests/reference_wrappers_test.rb), [reference_concat_test.rb](../tests/reference_concat_test.rb), [cross_check_autofix_test.rb](../tests/cross_check_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij References van hetzelfde type samenvoegen

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_resource_references` gecontroleerd.

<!-- lint-example: project_resource_references clean -->
```puppet
# Both packages are prerequisites for this notification.
notify { 'packages-ready':
  require => Package['alpha', 'zulu'],
}
```

Hier zou `require => [Package['zulu'], Package['alpha']]` dezelfde dependencies beschrijven, maar met onnodige herhaling. Ook een buitenste array zoals `[Package['alpha', 'zulu']]` is op deze plaats overbodig.

Zo wordt `require => [Package['zulu'], Service['nginx'], Package['alpha']]` geschreven als `require => [Package['alpha', 'zulu'], Service['nginx']]`. De service blijft als eigen reference aanwezig. Andere array-elementen onderbreken de controle op herhaalde resourcetypen niet. Voeg geen references uit afzonderlijke functieargumenten, verschillende arraylagen of kanten van een relatiepijl samen. Iedere geneste array wordt afzonderlijk gecontroleerd. Alleen de buitenste array rond één dependency-reference kan weg; meerdere elementen en geneste arraylagen blijven behouden.

`project_resource_references` meldt afzonderlijke references van hetzelfde type binnen een array, ongesorteerde letterlijke titels en overbodige buitenste arrays. Letterlijke titels worden hoofdlettergevoelig vergeleken op hun stringwaarde, zonder de aanhalingstekens mee te tellen. Dubbele titels blijven behouden. Datatypeparameters zoals `Enum[...]`, lokale typealiases en gewone indexeringen vallen buiten deze regel.

Autofix kan dit herstellen bij `require`, `before`, `notify` en `subscribe`, en bij losse relatieketens met `->`, `~>`, `<-` of `<~`. In die context beschrijven de references relaties tussen resources. Bij andere toepassingen kan dezelfde herschrijving de betekenis veranderen: een [reference met meerdere titels levert een array op](https://help.puppet.com/core/current/Content/PuppetCore/lang_data_resource_reference.htm), waardoor `[Package['a', 'b']]` een geneste array bevat en `[Package['a'], Package['b']]` niet. Bij variabelen, functieargumenten, indexeringen en een gebruikt resultaat van een relatie-expressie beoordeel je de gevolgen zelf.

Samenvoegen en sorteren gebeurt alleen automatisch bij letterlijke titels zonder commentaar in het te wijzigen gedeelte of bij een te verwijderen reference. Staan er andere elementen tussen de samen te voegen references, dan moeten ook die references met letterlijke titels zijn. Bij bijvoorbeeld een tussenliggende variabele, functieaanroep of geneste array volgt wel een melding, maar beoordeel je de samenvoeging zelf. Dat geldt ook voor dynamische titels en commentaar: behoud de toelichting bij de juiste resource en beoordeel welke waarden de expressies kunnen krijgen. De linter rekent die waarden niet uit.

Een buitenste array rond één reference kan ook bij een dynamische titel worden verwijderd: `require => [Package[$packages]]` wordt `require => Package[$packages]`. De reference zelf verandert dan niet. Bevat de te wijzigen array commentaar, een heredoc of genegeerde code, dan weigert de autofix ook deze correctie.

Deze relatiecontext omvat ook `concat(...)` dat rechtstreeks een dependency-attribuut of losse relatieketen voedt. Bij het eerste argument verdwijnt een wrapper alleen als de reference aantoonbaar een array oplevert: meerdere titels, een arrayliteral, een eerder voorbereide array of een parameter met type `Array`. Zo wordt `concat([Package[$packages]], $other)` veilig vereenvoudigd als `$packages` een bekende array is. Rond een enkele scalaire of onopgeloste titel blijft de eerste wrapper staan, omdat stdlib `concat()` daar een array vereist. Bij latere argumenten accepteert `concat()` ook een scalaire reference. Gewone functieargumenten en opgeslagen concatresultaten behouden hun arraystructuur.

### Titels in resource references sorteren

**Norm**

Sorteer de titels van resource references alfabetisch. Vergelijk letterlijke titels hoofdlettergevoelig op hun stringwaarde, zonder de quotes mee te tellen; behoud dubbele titels.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

References van hetzelfde type in arrays en titellijsten; dependency-attributen en losse relatieketens voor veilige correctie.

**Automatische controle**

`project_resource_references`

**Detectiegrenzen**

Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend.

**Meldingen en severity**

`Sort resource reference titles alphabetically`: `warning` bij ongesorteerde letterlijke titels. Het wrapper- en [review]-suffix uit de [samenvoegregel](#references-van-hetzelfde-type-samenvoegen) kan worden toegevoegd.

**Autofix**

Voorwaardelijk voor sorteren in veilige relatiecontext; Geen voor de variant met [review].

**Autofixvoorwaarden**

Alle relatie-, titel-, tussenliggende-element-, commentaar-, heredoc- en concatvoorwaarden hieronder gelden per variant. De fix behoudt dubbele titels, typegrenzen, tussenliggende references en de eerste positie van het samengevoegde type.

**Toegestane uitzonderingen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_resource_references`; verwacht warning.

<!-- lint-example: project_resource_references warning -->
```puppet
notify { 'example': require => Package['zulu', 'alpha'] }
```

**Correct voorbeeld**

Fragment; alleen `project_resource_references`; verwacht geen melding.

<!-- lint-example: project_resource_references clean -->
```puppet
notify { 'example': require => Package['alpha', 'zulu'] }
```

**Grensgevallen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn. Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij References van hetzelfde type samenvoegen](#verdieping-bij-references-van-hetzelfde-type-samenvoegen).

**Handmatige review**

Controleer de effectieve titelwaarden, hoofdlettergevoelige volgorde, behouden dubbelen en betekenis van de arrayvorm. Pas de gemeenschappelijke fixvoorwaarden bij de samenvoegregel toe.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [reference_merging_test.rb](../tests/reference_merging_test.rb), [reference_safety_test.rb](../tests/reference_safety_test.rb), [reference_wrappers_test.rb](../tests/reference_wrappers_test.rb), [reference_concat_test.rb](../tests/reference_concat_test.rb), [cross_check_autofix_test.rb](../tests/cross_check_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Een overbodige buitenste dependency-array verwijderen

**Norm**

Bij een dependency-attribuut of een losse relatieketen laat je de buitenste array weg wanneer daarin nog maar één resource reference staat. Behoud meerdere elementen en geneste arraylagen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

References van hetzelfde type in arrays en titellijsten; dependency-attributen en losse relatieketens voor veilige correctie.

**Automatische controle**

`project_resource_references`

**Detectiegrenzen**

Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend.

**Meldingen en severity**

`Remove the outer array around a single resource reference`: `warning` bij een overbodige buitenste array. Onzekere context krijgt het [review]-suffix uit de [samenvoegregel](#references-van-hetzelfde-type-samenvoegen).

**Autofix**

Voorwaardelijk voor een veilige buitenste dependency-array; Geen voor de variant met [review].

**Autofixvoorwaarden**

Verwijdert alleen de wrapper en behoudt de reference. Een dynamische titel is daarvoor toegestaan. Commentaar, heredocs en genegeerde code weigeren de correctie. Binnen rechtstreeks voedende dependency-concat blijft de eerste wrapper bestaan tenzij de reference aantoonbaar een array oplevert; latere concatargumenten mogen scalair zijn. De volledige contextcriteria staan bij [References samenvoegen](#references-van-hetzelfde-type-samenvoegen).

**Toegestane uitzonderingen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_resource_references`; verwacht warning.

<!-- lint-example: project_resource_references warning -->
```puppet
notify { 'example': require => [Package['alpha']] }
```

**Correct voorbeeld**

Fragment; alleen `project_resource_references`; verwacht geen melding.

<!-- lint-example: project_resource_references clean -->
```puppet
notify { 'example': require => Package['alpha'] }
```

**Grensgevallen**

De eerste concat-wrapper blijft bij scalaire/onopgeloste titels staan. Een dynamische titel verhindert op zichzelf geen zuivere wrapperverwijdering. Buiten relatiecontext kan arraystructuur betekenisvol zijn. Typedeclaraties, datatypeparameters en indexeringen zijn uitgesloten. Verschillende functieargumenten, arraylagen en zijden van een relatie blijven gescheiden. Dynamische titels worden niet uitgerekend. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij References van hetzelfde type samenvoegen](#verdieping-bij-references-van-hetzelfde-type-samenvoegen).

**Handmatige review**

Controleer gewone waarden, functieargumenten, opgeslagen concatresultaten, geneste arrays en gebruikte relatieresultaten apart. Bewijs voor het eerste concatargument dat het een array oplevert; verander de reference zelf niet.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [reference_merging_test.rb](../tests/reference_merging_test.rb), [reference_safety_test.rb](../tests/reference_safety_test.rb), [reference_wrappers_test.rb](../tests/reference_wrappers_test.rb), [reference_concat_test.rb](../tests/reference_concat_test.rb), [cross_check_autofix_test.rb](../tests/cross_check_autofix_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Resourcelijsten hergebruiken

**Norm**

Definieer een lijst met resourcetitels eenmaal wanneer declaraties of dependencies dezelfde set gebruiken. Dit geldt voor packages, bestanden, services, classes en eigen defined types. Gebruik bijvoorbeeld dezelfde `$configuration_files` in `file { $configuration_files: ... }` en `File[$configuration_files]`. Kies een naam die bij het doel past; de check schrijft geen variabelenaam voor.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Resourcedeclaraties, references en ensure_packages met minstens twee verschillende letterlijke titels van hetzelfde type binnen dezelfde class, define of topscope.

**Automatische controle**

`project_resource_list_reuse`

**Detectiegrenzen**

Gelijke sets, volledige uitbreidingen en overlap vanaf drie namen en 80% aan beide kanten worden onderscheiden. Onbekende expressies, parameterdefaults, andere functies en lambdascopes blijven buiten vergelijking.

**Meldingen en severity**

`Reuse the resource-title list in a shared variable; extend it with concat() for additional dependencies`: `warning`. Zonder veilige fix volgt ` [review] Verify overlap, scope, evaluation order and comments before extracting the list`; severity blijft warning.

**Autofix**

Voorwaardelijk voor exacte herhaling en duidelijke package-uitbreidingen; Geen voor de beschreven reviewgevallen

**Autofixvoorwaarden**

Uitsluitend één rechtstreeks gebruikte ensure_packages-lijst met dependencies na de aanroep in hetzelfde blok. Alle hieronder beschreven titel-, naam-, scope-, breedte-, commentaar- en uitbreidingsvoorwaarden zijn vereist.

**Toegestane uitzonderingen**

Kleine overlap, verschillende declaratiesets en kleinere dependency-subsets zijn geen reden om lijsten samen te voegen. Behoud aanvullende titels en hun bestaande eigenaar.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_resource_list_reuse` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_resource_list_reuse warning -->
```puppet
file { ['/a', '/b']: }
notify { 'demo': require => File['/a', '/b'] }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_resource_list_reuse` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_resource_list_reuse clean -->
```puppet
$paths = ['/a', '/b']
file { $paths: }
notify { 'demo': require => File[$paths] }
```

**Grensgevallen**

Kleine overlap, verschillende declaratiesets en kleinere dependency-subsets zijn geen reden om lijsten samen te voegen. Behoud aanvullende titels en hun bestaande eigenaar. Gelijke sets, volledige uitbreidingen en overlap vanaf drie namen en 80% aan beide kanten worden onderscheiden. Onbekende expressies, parameterdefaults, andere functies en lambdascopes blijven buiten vergelijking. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Resourcelijsten hergebruiken](#verdieping-bij-resourcelijsten-hergebruiken).

**Handmatige review**

Controleer dat gedeelde variabelen vóór alle afnemers bestaan, verschillen behouden blijven en resources met eigen attributen/levenscyclus niet worden gecombineerd.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_list_reuse_test.rb](../tests/resource_list_reuse_test.rb), [resource_list_reuse_fix_test.rb](../tests/resource_list_reuse_fix_test.rb), [package_list_extensions_test.rb](../tests/package_list_extensions_test.rb), [package_list_scope_test.rb](../tests/package_list_scope_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Resourcelijsten hergebruiken

Bij packages deel je de lijst ook tussen `ensure_packages()` en `Package[...]`, zodat een toevoeging of verwijdering niet op meerdere plaatsen hoeft te worden bijgehouden:

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_resource_list_reuse` gecontroleerd.

<!-- lint-example: project_resource_list_reuse clean -->
```puppet
# Install the tools shared by this feature's consumers.
$feature_packages = ['coreutils', 'grep', 'sed']

ensure_packages($feature_packages, {
  'ensure'          => 'installed',
  'install_options' => ['--no-install-recommends', '--no-install-suggests'],
})

# Include an additional package managed by the consuming deployment.
$feature_required_packages = concat(
  $feature_packages,
  ['curl'],
)

# Order the consumer after its package prerequisites.
notify { 'feature-ready':
  require => Package[$feature_required_packages],
}
```

Aanvullende dependencies blijven behouden in een afzonderlijk voorbereide lijst. Die uitbreiding declareert de extra resources niet: hun bestaande eigenaar blijft daarvoor verantwoordelijk. De [arrayconventie](#resources-en-afhankelijkheden) schrijft `concat(...)` voor; deze hergebruikcheck herkent ook hergebruik via `+`, maar schakelt de aparte melding van `project_arrays` niet uit. De [opbouw van dependencies](#resource-dependencies-opbouwen) houdt titels gescheiden van resource references.

`project_resource_list_reuse` vergelijkt binnen dezelfde class, hetzelfde defined type of dezelfde topscope bronnen met ten minste twee verschillende letterlijke titels van hetzelfde resourcetype. Een andere schrijfvolgorde maakt geen verschil. Identieke sets worden ook gemeld bij herhaalde declaraties, herhaalde references of meerdere `ensure_packages()`-aanroepen. Gelijke titels van verschillende resourcetypen worden niet gekoppeld. Datatypeparameters, lokale typealiases en gewone indexeringen vallen buiten de regel. Samenhangende herhalingen krijgen één melding bij de eerste bronlijst.

Tussen een declaratielijst of `ensure_packages()` en een afzonderlijke reference meldt de check ook een volledig herhaalde basisset met extra titels. Bij overige overlap is een melding beperkt tot minstens drie gemeenschappelijke titels die ten minste 80% van beide sets vormen. Zo'n melding vraagt altijd review: behoud de bedoelde verschillen en deel alleen de gemeenschappelijke basis. Enkele gemeenschappelijke titels, kleinere dependency-subsets en verschillende declaratiesets zijn geen reden om lijsten samen te voegen.

De analyse volgt eerdere, eenduidige lokale toekenningen, aliassen, `concat(...)`, arrayoptelling en letterlijke lijsten in selectors en `if`-expressies. Verwijzingen naar dezelfde bronlijst tellen als hergebruik. Statisch zichtbare namen naast dynamische waarden kunnen een reviewmelding opleveren; onbekende expressies worden niet uitgevoerd. Parameterdefaults, onopgeloste variabelen, andere functieaanroepen en afzonderlijke lambdascopes blijven buiten deze vergelijking. Bij references in gewone waarden en relatieketens volgt alleen een melding: de autofix beperkt zich tot `require`, `before`, `notify` en `subscribe` op resources.

De hergebruik-autofix beperkt zich tot één rechtstreeks aangeroepen, letterlijke `ensure_packages()`-lijst met passende package-dependencies in hetzelfde uitvoerblok, na de installatieaanroep. Er mag geen tweede installatielijst in die scope zijn. De namen moeten uniek zijn en bestaan uit letters, cijfers, `+`, `_`, `.`, `:` of `-`, beginnend met een letter of cijfer. Bij exacte herhaling zet de fix de lijst direct vóór de aanroep in `$required_packages` en vervangt alle passende references; `concat()` is dan niet nodig. Bij declaraties of alleen references beoordeel je de extractie handmatig, met behoud van hun eigen attributen en levenscyclus.

Een duidelijke uitbreiding mag eveneens worden gecorrigeerd: de installatie gebruikt dan `$packages` en na de aanroep volgt `$required_packages = concat($packages, ['extra'])`, verdeeld over meerdere regels. Iedere dependency bevat de volledige basislijst; er mag maximaal één verschillende uitbreidingsset zijn. Resources die alleen de basis nodig hebben gebruiken `$packages`. Overige resources en dependencyvariabelen blijven buiten `Package[...]`. Naamconflicten, ook met gekwalificeerde variabelen of parameters, verhinderen autofix; kies bij handmatige correctie contextnamen.

Bestaande lijstvariabelen met opnieuw uitgeschreven literals, gedeeltelijke overlap, meerdere verschillende uitbreidingen, conditionele waarden, gebruikte functieresultaten, overerving en complexe expressies krijgen geen hergebruik-autofix. Dat geldt ook voor commentaar in de te vervangen lijsten, lintmarkeringen binnen het wijzigingsbereik, een installatielijst over meerdere regels of een nieuwe declaratie langer dan 140 tekens. Commentaar buiten de lijsten blijft behouden; ontbreekt een toelichting boven de installatie, dan voegt de fix een feitelijke toelichting bij de gedeelde variabele toe. Bij twijfel blijft de hele groep staan met `[review]`.

Controleer bij handmatig hergebruik dat de variabele vóór alle afnemers beschikbaar is en dat voorwaarden, resourceattributen en relaties behouden blijven. Een melding bewijst geen beschikbaarheid van resources; volg daarvoor de [dependencyreview](#resources-en-afhankelijkheden) de [packagegaranties voor externe commando’s](#packageafhankelijkheden-bij-externe-commandos).

### Resource-dependencies opbouwen

**Norm**

Combineer eerst titels van hetzelfde resourcetype, maak daarna de resource reference en combineer die pas vervolgens met andere dependencies. Dit geldt ook voor `File[...]`, `Service[...]`, `Class[...]` en eigen defined types. Gebruik voor een uitbreiding een benoemde tussenvariabele, zodat de drie stappen afzonderlijk leesbaar blijven. Bij packages ziet dat er zo uit:

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Concat-aanroepen binnen references van packages, files, services, classes en eigen defined types, inclusief buitenste dependency-concats.

**Automatische controle**

`project_resource_dependencies`

**Detectiegrenzen**

Onbekende variabelen, parameterdefaults, conditionele waarden en references tussen titels krijgen geen extractiefix. Gewone concats en vooraf berekende titelvariabelen zijn toegestaan.

**Meldingen en severity**

`Prepare the extended title list in a variable before the resource reference; combine other dependencies separately`: `warning`. Onveilige gevallen krijgen ` [review] Verify variable contents, conditions, scope and comments before extracting the list`.

**Autofix**

Voorwaardelijk; Geen voor de genoemde reviewvarianten

**Autofixvoorwaarden**

Titels zijn aantoonbaar vaste strings via literals, eerdere eenduidige toekenningen of concat. Geen naamconflict, commentaar, lintmarkering, meerregelig argument of uitvoer buiten 140 tekens. Identieke expressies in hetzelfde blok delen voorbereiding.

**Toegestane uitzonderingen**

Bij gelijke titels volstaat één bestaande lijst; voeg geen concat toe zonder uitbreiding.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_resource_dependencies` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_resource_dependencies warning -->
```puppet
notify { 'demo': require => File[concat(['/a'], ['/b'])] }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_resource_dependencies` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_resource_dependencies clean -->
```puppet
$paths = concat(['/a'], ['/b'])
notify { 'demo': require => File[$paths] }
```

**Grensgevallen**

Bij gelijke titels volstaat één bestaande lijst; voeg geen concat toe zonder uitbreiding. Onbekende variabelen, parameterdefaults, conditionele waarden en references tussen titels krijgen geen extractiefix. Gewone concats en vooraf berekende titelvariabelen zijn toegestaan. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Resource-dependencies opbouwen](#verdieping-bij-resource-dependencies-opbouwen).

**Handmatige review**

Controleer dat titelvariabelen alleen titels bevatten, andere dependencies references blijven en extractie geen voorwaarde of evaluatiegrens passeert.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [resource_dependencies_test.rb](../tests/resource_dependencies_test.rb), [cli_resource_list_reuse_test.rb](../tests/cli_resource_list_reuse_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Resource-dependencies opbouwen

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_resource_dependencies` gecontroleerd.

<!-- lint-example: project_resource_dependencies clean -->
```puppet
# Include the application package alongside the prepared backup tools.
$backup_required_packages = concat(
  $backup_packages,
  ['backup-server'],
)

# Combine package references with the separately prepared resource dependencies.
notify { 'backup-ready':
  require => concat(
    Package[$backup_required_packages],
    $backup_other_require,
  ),
}
```

`$backup_packages` bevat hier package-namen; `$backup_other_require` bevat andere resource references. Geef die laatste variabele nooit door als resourcetitel. Bij exact dezelfde packages volstaat `Package[$backup_packages]`; voeg geen `concat()` toe als er niets samen te voegen is. De [referencecheck](#resource-references) verwijdert aantoonbaar overbodige wrappers in dependency-concats, met behoud van de vereiste array als eerste argument.

`project_resource_dependencies` meldt `concat(...)` binnen resource references, zoals `Package[concat(...)]` of `File[concat(...)]`, ook binnen een buitenste dependency-concat. De check kan de binnenste expressie vóór de omringende resource of toekenning in een tussenvariabele plaatsen. Hij behoudt de volgorde van de concatargumenten en laat andere references op hun plaats. De naam volgt een bestaande lokale naam: `$backup_packages` levert `$backup_required_packages` op en `$configuration_files` levert `$configuration_required_files` op. Zonder bronvariabele gebruikt de fix `$required_titles`. Identieke expressies in hetzelfde blok delen die voorbereiding.

Deze autofix vereist aantoonbaar vaste titels als strings via literals, eerdere eenduidige lokale toekenningen of `concat()`. Onbekende variabelen, parameterdefaults, conditionele waarden, resource references tussen de titels, naamconflicten, commentaar of lintmarkeringen in het wijzigingsbereik krijgen uitsluitend een reviewmelding. De fix verplaatst geen onzekere expressie buiten haar voorwaarde. Meerregelige argumenten en uitvoer buiten de regelbreedte worden eveneens handmatig beoordeeld. Reeds voorbereide titelvariabelen en gewone `concat()`-aanroepen blijven toegestaan.

### Volgorde en meldingen

<!-- lint-rule-group -->

### Resources bij hun voorziening plaatsen

**Norm**

Groepeer resources en aanroepen van defined types bij het onderdeel dat ze beheren. Sluit nieuwe aanroepen aan op de bestaande indeling van het manifest. Aanvullende voorzieningen, zoals back-ups, monitoring en audit, volgen bij elkaar na de configuratie en service waarop ze betrekking hebben, binnen het geldige uitvoerpad en met behoud van hun eigen inschakelvoorwaarden.

Gedeelde voorbereiding en vereiste classes mogen eerder staan wanneer afnemers die nodig hebben. Een vroeg berekende instelvariabele is op zichzelf geen reden om ook de bijbehorende resourcedeclaratie naar het begin te halen. Vereist de evaluatievolgorde een andere plaats voor een gerelateerde aanroep, licht dan bij die aanroep de concrete afhankelijkheid toe en valideer die volgorde.

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe en verplaatste resources en defined-type-aanroepen binnen hun geldige uitvoerpad.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Gedeelde voorbereiding en vereiste classes mogen eerder staan. Een andere plaats voor een gerelateerde aanroep vereist de lokale technische toelichting en validatie uit de norm.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Gedeelde voorbereiding en vereiste classes mogen eerder staan. Een andere plaats voor een gerelateerde aanroep vereist de lokale technische toelichting en validatie uit de norm.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een monitoringregistratie staat vóór de serviceconfiguratie omdat haar instelvariabele vroeg wordt berekend. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Plaats de registratie bij de aanvullende voorzieningen na de configuratie en service; behoud haar inschakelvoorwaarde. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Gedeelde voorbereiding en vereiste classes mogen eerder staan. Een andere plaats voor een gerelateerde aanroep vereist de lokale technische toelichting en validatie uit de norm.

**Handmatige review**

Vergelijk iedere toegevoegde of verplaatste aanroep met de hele omringende implementatie en controleer de concrete evaluatieafhankelijkheid.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk iedere toegevoegde of verplaatste aanroep met de hele omringende implementatie en controleer de concrete evaluatieafhankelijkheid. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

### Relaties en meldingen behouden

**Norm**

Behoud de expliciete `require`-, `notify`- en `subscribe`-relaties tussen resources. Ontstaat een afhankelijkheidscyclus, zoek dan welke relatie of containment die veroorzaakt. Herstel de relatie daar, zodat Puppet de volgorde en herstarts kan blijven regelen. Een los `systemctl`-, `service`- of reloadcommando omzeilt die samenhang en is geen vervanging.

Soms is de afhankelijkheid van een volledige class te breed. Koppel de ordering dan waar nodig aan een kleinere, stabiele resource en behoud meldingen zoals `notify => Service['nginx']`.

**Herkomst**

Projectregel

**Toepassingsgebied**

Ordering, notificaties en containment bij afhankelijkheidscycli en te brede classrelaties.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een kleinere stabiele resource mag de te brede classordering vervangen; de noodzakelijke notify blijft behouden.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een kleinere stabiele resource mag de te brede classordering vervangen; de noodzakelijke notify blijft behouden.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een cyclus wordt omzeild met een los reloadcommando en de notify-relatie verdwijnt. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Herstel de veroorzakende relatie of containment; behoud de service-notificatie, zo nodig met een kleinere stabiele orderingresource. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een kleinere stabiele resource mag de te brede classordering vervangen; de noodzakelijke notify blijft behouden.

**Handmatige review**

Volg de cyclus door require, notify, subscribe en containment; controleer welke wijzigingen daadwerkelijk een herstart melden.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Volg de cyclus door require, notify, subscribe en containment; controleer welke wijzigingen daadwerkelijk een herstart melden. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

### Instellingen bij hun eigenaar houden

**Norm**

Houd instellingen die alleen voor een aanvullende voorziening nodig zijn bij die voorziening. Een bestand dat de daemon zelf configureert blijft bij de daemonconfiguratie staan.

Een class of defined type berekent zelf de afgeleide implementatiewaarden die uitsluitend nodig zijn voor de configuratie of templates die het beheert. Callers leveren de oorspronkelijke configuratie aan; ze berekenen interne waarden niet vooraf om die als parameters terug te geven. Selecteer bijvoorbeeld protocolspecifieke instellingen en bepaal interne identifiers, hashes, bestandspaden en gedeeld eigenaarschap binnen de ontvangende component.

De bestaande class of define mag die berekeningen rechtstreeks uitvoeren; een extra component is daarvoor niet vereist.

Maak onderscheid tussen de unieke titel van een Puppet-registratie en de interne identiteit van het gedeelde object. Geef templates de voorbereide waarden; herhaal daar geen protocolselectie, identiteitsberekening of eigendomsbeslissing. Waarden die de caller zelf beheert, zoals zijn configuratiebestand of de positie van een fragment daarin, blijven broninvoer voor de ontvangende component.

Beoordeel deze indeling bij de review van het hele omliggende blok. De [sectiechecks](DOCUMENTATION_RULES.md#toelichtingen-bij-code) controleren opmaak en toelichtingen; een geslaagde lintscan bewijst niet dat aanroepen inhoudelijk op de juiste plek staan. Verplaats ze niet automatisch op basis van hun naam, type of afstand tot een variabele: hun functie, voorwaarden en evaluatievolgorde bepalen welke plek klopt.

**Herkomst**

Projectregel

**Toepassingsgebied**

Daemonconfiguratie, instellingen van aanvullende voorzieningen en gegevensoverdracht tussen callers, classes, defined types en hun templates.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Namen, resourcetype en afstand tot een variabele bewijzen geen juiste plaats. Ook variabelereferenties, AST-expressies, functie-whitelists en aantallen lezingen bewijzen niet welke component een waarde hoort af te leiden. Deze architectuurafspraak wordt inhoudelijk beoordeeld en heeft geen generieke detectiecheck. De sectiechecks beoordelen alleen opmaak en toelichting.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Namen, resourcetype en afstand tot een variabele bewijzen geen juiste plaats. De sectiechecks beoordelen alleen opmaak en toelichting.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een daemonconfiguratiebestand verhuist naar de monitoringsectie alleen omdat monitoring het leest. De beschreven constructie wordt afgekeurd.

Handmatig reviewscenario: Een profiel berekent transport, socket-identiteit, include-pad en primaire eigenaar en geeft die via extra parameters aan de vhostcomponent. Keur dit af: het profiel bereidt interne listen-configuratie voor die de vhostcomponent zelf uit de broninvoer kan afleiden.

**Correct voorbeeld**

Handmatig reviewscenario: Laat daemonconfiguratie bij de daemon; groepeer uitsluitend monitoringinstellingen bij de registratie. Dit voldoet aan de norm onder de genoemde voorwaarden.

Handmatig reviewscenario: Een profiel geeft adressen, poorten, protocolkeuzes en socketopties aan `nginx::server`. Dit defined type berekent zelf transport, socket-identiteit, include-pad, eigenaarschap en effectieve opties. Het beheert de gedeelde socketconfiguratie en geeft voorbereide listen- of includeregels aan zijn templates. Meerdere vhosts delen één configuratie-eigenaar per socket; hiervoor is geen aparte listen-define nodig.

**Grensgevallen**

Namen, resourcetype en afstand tot een variabele bewijzen geen juiste plaats. De sectiechecks beoordelen alleen opmaak en toelichting.

Een pad van een bestand dat de caller beheert kan geldige broninvoer zijn. Een intern pad dat uitsluitend het ontvangende type beheert hoort daar te worden afgeleid. Verplaats geen lokale berekeningen zonder deze verantwoordelijkheden en de gebruikers van de waarde te beoordelen.

**Handmatige review**

Stel per instelling vast welk onderdeel zij configureert; beoordeel functie, voorwaarden en evaluatievolgorde in het complete blok. Volg de broninvoer via de component tot de gerenderde configuratie en verwijder overbodige afgeleide parameters. Controleer bij gedeelde objecten unieke registratietitels, één eigenaar per interne identiteit, behoud van opties en conflictdetectie, en alle geraakte callers en relaties.

**Verificatie**

Vergelijk de onjuiste en correcte scenario’s tijdens review en controleer het publieke interfacecontract. Valideer gewijzigd gedrag afzonderlijk met tijdelijke catalogi en gerenderde configuratie volgens de [aanvullende validatie](../README.md#aanvullende-validatie). Neem bij listeners TCP, UDP, meerdere gebruikers, verschillende declaratievolgordes en conflicterende opties mee. De documentatiecontracttests controleren de structuur en verwijzingen van deze handmatige regel; ze bewijzen geen component-eigenaarschap of modulegedrag.
