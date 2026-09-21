# Puppet-code documenteren

Dit bestand bevat de regels voor commentaar in Puppet-code, Puppet Strings en documentatie van Puppet-interfaces. Pas de relevante regels toe wanneer je wijziging deze documentatie raakt. Blijf daarbij de toepasselijke algemene coderegels uit [CODE_RULES.md](CODE_RULES.md) volgen.

Raakt de wijziging ook beheerde bestanden of mappen, eigenaarschap of rechten, beveiliging, systemd of services, shellcode of shelltemplates, runtime-tools of operationele dependencies, of monitoringchecks en hun registratie, volg dan daarnaast de relevante regels uit [OPERATIONAL_RULES.md](OPERATIONAL_RULES.md). Beide aanvullende documenten kunnen tegelijk van toepassing zijn en vervangen de algemene coderegels nooit.

De [linthandleiding](../README.md) beschrijft het gebruik en onderhoud van de tooling. De algemene afspraken voor repositorydocumentatie, Markdown, README-stijl en redactionele review staan in [AGENTS.md](../../../AGENTS.md#documentation). Een groene lintscan bewijst niet dat alle handmatige regels zijn nageleefd. Ontbrekende automatische detectie vormt geen uitzondering op een regel.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Commentaar en documentatie](#commentaar-en-documentatie)
  - [Toelichtingen bij code](#toelichtingen-bij-code)
  - [Toelichtingsblokken van eerdere code scheiden](#toelichtingsblokken-van-eerdere-code-scheiden)
    - [Verdieping bij Toelichtingsblokken van eerdere code scheiden](#verdieping-bij-toelichtingsblokken-van-eerdere-code-scheiden)
  - [Inhoud direct na een openingsaccolade beginnen](#inhoud-direct-na-een-openingsaccolade-beginnen)
  - [Een resource na een afgesloten blok toelichten](#een-resource-na-een-afgesloten-blok-toelichten)
  - [Bestaande implementatie-uitleg actueel houden](#bestaande-implementatie-uitleg-actueel-houden)
  - [Niet-zichtbare implementatiekeuzes toelichten](#niet-zichtbare-implementatiekeuzes-toelichten)
  - [Codecommentaar in Engelse zinnen schrijven](#codecommentaar-in-engelse-zinnen-schrijven)
  - [Voorwaarden toelichten](#voorwaarden-toelichten)
    - [Verdieping bij Voorwaarden toelichten](#verdieping-bij-voorwaarden-toelichten)
  - [Variabelen groeperen](#variabelen-groeperen)
  - [Een variabelegroep bij blokbegin toelichten](#een-variabelegroep-bij-blokbegin-toelichten)
  - [Een onafhankelijke groep na afhankelijke waarden beginnen](#een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen)
    - [Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen)
  - [Puppet Strings](#puppet-strings)
  - [Publieke declaraties bij de code documenteren](#publieke-declaraties-bij-de-code-documenteren)
    - [Verdieping bij Publieke declaraties bij de code documenteren](#verdieping-bij-publieke-declaraties-bij-de-code-documenteren)
  - [Strings API-markering](#strings-api-markering)
  - [Strings-summary op één regel](#strings-summary-op-één-regel)
  - [Strings-parametercontract](#strings-parametercontract)
  - [Uitvoerbare Strings-voorbeelden](#uitvoerbare-strings-voorbeelden)
    - [Verdieping bij Uitvoerbare Strings-voorbeelden](#verdieping-bij-uitvoerbare-strings-voorbeelden)
  - [Strings-regelbreedte](#strings-regelbreedte)
    - [Verdieping bij Strings-regelbreedte](#verdieping-bij-strings-regelbreedte)
  - [Strings-taginspringing](#strings-taginspringing)
  - [Strings-secties met commentregels scheiden](#strings-secties-met-commentregels-scheiden)
    - [Verdieping bij Strings-secties met commentregels scheiden](#verdieping-bij-strings-secties-met-commentregels-scheiden)
  - [Lengtesuppressions in Strings begrenzen](#lengtesuppressions-in-strings-begrenzen)
  - [Waar de uitleg hoort](#waar-de-uitleg-hoort)
  - [Interfacebeschrijvingen synchroniseren](#interfacebeschrijvingen-synchroniseren)
  - [Documentatie op haar aangewezen plaats onderhouden](#documentatie-op-haar-aangewezen-plaats-onderhouden)
  - [Uitvoerbare voorbeeldscenario’s onderhouden](#uitvoerbare-voorbeeldscenarios-onderhouden)

## Commentaar en documentatie

<!-- lint-rule-group -->

### Toelichtingen bij code

<!-- lint-rule-group -->

### Toelichtingsblokken van eerdere code scheiden

**Norm**

Een zelfstandig toelichtingsblok begint na een lege regel wanneer er code aan voorafgaat. Aaneengesloten commentaarregels vormen samen één blok; commentaar achter code en lintmarkeringen vormen geen nieuwe toelichting. Direct na `{`, `[` of `(` is geen lege regel vóór het commentaar nodig.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Een zelfstandig toelichtingsblok begint na een lege regel wanneer er code aan voorafgaat. Aaneengesloten commentaarregels vormen samen één blok; commentaar achter code en lintmarkeringen vormen geen nieuwe toelichting. Direct na `{`, `[` of `(` is geen lege regel vóór het commentaar nodig.

**Automatische controle**

`project_comment_spacing`

**Detectiegrenzen**

Direct na {, [ of ( hoeft geen lege regel vóór commentaar. Een trailing comment of lintmarkering is geen zelfstandig toelichtingsblok. De inhoudelijke juistheid van de uitleg blijft review.

**Meldingen en severity**

`Put a blank line before a standalone explanatory comment block`: `warning` wanneer een zelfstandig toelichtingsblok direct op code volgt.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Voegt alleen een lege regel vóór bestaande uitleg toe; behoudt aaneengesloten comments, trailing comments en genegeerde delen.

**Toegestane uitzonderingen**

Direct na {, [ of ( hoeft geen lege regel vóór commentaar. Een trailing comment of lintmarkering is geen zelfstandig toelichtingsblok.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_comment_spacing` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_comment_spacing warning -->
```puppet
$value = 1
# Explain the next value.
$other = 2
```

**Correct voorbeeld**

Fragment; alleen de controle `project_comment_spacing` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_comment_spacing clean -->
```puppet
$value = 1

# Explain the next value.
$other = 2
```

**Grensgevallen**

Direct na {, [ of ( hoeft geen lege regel vóór commentaar. Een trailing comment of lintmarkering is geen zelfstandig toelichtingsblok.

**Handmatige review**

Vergelijk de toelichting met de direct betrokken verwerking en controleer dat scheiding en witruimte haar bij de juiste resource of het juiste blok houden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [comment_spacing_test.rb](../tests/comment_spacing_test.rb), [resource_sections_test.rb](../tests/resource_sections_test.rb), [brace_layout_test.rb](../tests/brace_layout_test.rb), [cli_sections_test.rb](../tests/cli_sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Toelichtingsblokken van eerdere code scheiden

`project_comment_spacing` kan de lege regel vóór een bestaand commentaarblok toevoegen. `project_layout` kan lege regels direct na `{` verwijderen en meldt daarbij de eerste lege regel, ook als die spaties of tabs bevat. Genegeerde delen blijven behouden. `project_resource_sections` controleert of de toelichting bij een nieuwe resource aanwezig is en heeft geen autofix.

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

### Een resource na een afgesloten blok toelichten

**Norm**

Een resourcedeclaratie na een afgesloten `}` begint met een lege regel en een eigen toelichting direct boven de declaratie. Dat geldt ook voor defined types, resourcedefaults en overrides. Resources die met `->` of `~>` verbonden zijn blijven samen één keten.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Een resourcedeclaratie na een afgesloten `}` begint met een lege regel en een eigen toelichting direct boven de declaratie. Dat geldt ook voor defined types, resourcedefaults en overrides. Resources die met `->` of `~>` verbonden zijn blijven samen één keten.

**Automatische controle**

`project_resource_sections`

**Detectiegrenzen**

Dit omvat defined types, resourcedefaults en overrides. Resources verbonden met een relatiepijl blijven samen één keten. De inhoudelijke juistheid van de uitleg blijft review.

**Meldingen en severity**

`Start a resource declaration after a closed block with a blank line and a preceding explanatory comment`: `warning` bij ontbrekende eigen toelichting of scheiding.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de check verzint geen uitleg en verplaatst geen resources.

**Toegestane uitzonderingen**

Dit omvat defined types, resourcedefaults en overrides. Resources verbonden met een relatiepijl blijven samen één keten.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_resource_sections`; verwacht warning.

<!-- lint-example: project_resource_sections warning -->
```puppet
if $active { notice('Active') }
notify { 'example': }
```

**Correct voorbeeld**

Fragment; alleen `project_resource_sections`; verwacht geen melding.

<!-- lint-example: project_resource_sections clean -->
```puppet
if $active { notice('Active') }

# Report the independently configured state.
notify { 'example': }
```

**Grensgevallen**

Dit omvat defined types, resourcedefaults en overrides. Resources verbonden met een relatiepijl blijven samen één keten.

**Handmatige review**

Vergelijk de toelichting met de direct betrokken verwerking en controleer dat scheiding en witruimte haar bij de juiste resource of het juiste blok houden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [comment_spacing_test.rb](../tests/comment_spacing_test.rb), [resource_sections_test.rb](../tests/resource_sections_test.rb), [brace_layout_test.rb](../tests/brace_layout_test.rb), [cli_sections_test.rb](../tests/cli_sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Bestaande implementatie-uitleg actueel houden

**Norm**

Controleer bij de review of de uitleg nog klopt en of lange reeksen instellingen herkenbaar zijn gegroepeerd. Vergelijk de passage met goed gedocumenteerde bestaande code en verwijder verouderde, dubbele of overbodige uitleg. Projectbeleid hoort in de documentatie; implementatiecommentaar legt de lokale reden en gevolgen uit.

**Herkomst**

Projectregel

**Toepassingsgebied**

Bestaande toelichtingen in geraakte implementatieblokken.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Toelichtingen bij code](#toelichtingen-bij-code).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Het verwijderen van uitleg is alleen passend wanneer zij verouderd, dubbel of overbodig is; noodzakelijke lokale redenen blijven staan.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Het verwijderen van uitleg is alleen passend wanneer zij verouderd, dubbel of overbodig is; noodzakelijke lokale redenen blijven staan.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Commentaar beschrijft een verwijderde fallback en dupliceert projectbeleid. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Verwijder verouderde of overbodige uitleg en behoud lokale redenen en gevolgen; laat beleid in de documentatie. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Het verwijderen van uitleg is alleen passend wanneer zij verouderd, dubbel of overbodig is; noodzakelijke lokale redenen blijven staan.

**Handmatige review**

Vergelijk met de huidige code en goed gedocumenteerde voorbeelden en controleer herkenbare groepering van lange instellingenreeksen.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Vergelijk met de huidige code en goed gedocumenteerde voorbeelden en controleer herkenbare groepering van lange instellingenreeksen. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Niet-zichtbare implementatiekeuzes toelichten

**Norm**

Licht vooral de keuzes toe die niet uit de volgende regel blijken. Dat geldt bijvoorbeeld voor een resourcegroep, exec, afgeleide waarde, voorwaardelijke directive, gedelegeerde resource of opruimroute. Ook helpers en templatelogica verdienen uitleg wanneer de invoer, uitvoer of gevolgen voor exitcodes niet vanzelf spreken. Bij escaping, parsing, classificatie, samenvoegen van resultaten en terugvalgedrag helpt zo'n toelichting om een latere wijziging veilig te beoordelen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Resourcegroepen, execs, afgeleide waarden, directives, delegatie, opruimroutes, helpers en templatelogica.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Toelichtingen bij code](#toelichtingen-bij-code).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Vanzelfsprekende code verlangt geen overbodige herhaling; de norm richt zich op keuzes en gevolgen die niet direct zichtbaar zijn.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Vanzelfsprekende code verlangt geen overbodige herhaling; de norm richt zich op keuzes en gevolgen die niet direct zichtbaar zijn.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een complexe escaping- of terugvalstap heeft geen uitleg over haar gevolgen. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Beschrijf de reden en de relevante invoer, uitvoer of exitgevolgen wanneer die niet vanzelf spreken. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Vanzelfsprekende code verlangt geen overbodige herhaling; de norm richt zich op keuzes en gevolgen die niet direct zichtbaar zijn.

**Handmatige review**

Controleer iedere genoemde soort keuze en koppel de uitleg aan het lokale risico van parsing, classificatie of samenvoegen.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Controleer iedere genoemde soort keuze en koppel de uitleg aan het lokale risico van parsing, classificatie of samenvoegen. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Codecommentaar in Engelse zinnen schrijven

**Norm**

Een toelichting vertelt waarom de code nodig is, welke beperking ermee wordt opgevangen of welk gevolg de lezer moet kennen. Schrijf codecommentaar in het Engels en houd iedere zin op één fysieke regel. Lijsten, voorbeelden en syntaxis mogen hun eigen regels krijgen. Voor [Puppet Strings](#puppet-strings) geldt een andere opmaak, met afgebroken documentatietekst. Werk willekeurige regelafbrekingen in geraakte codecomments weg.

**Herkomst**

Projectregel

**Toepassingsgebied**

Gewone codecomments buiten Puppet Strings.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Toelichtingen bij code](#toelichtingen-bij-code).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Lijsten, voorbeelden en syntaxis mogen eigen regels krijgen; Puppet Strings heeft afgebroken tekst volgens de aparte opmaak.

**Meldingen en severity**

Geen afzonderlijke lintmelding of severity voor deze norm; de overtreding vraagt de hieronder beschreven handmatige afkeur.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de concrete inhoudelijke correctie kan niet door een opmaakfix worden bewezen.

**Toegestane uitzonderingen**

Lijsten, voorbeelden en syntaxis mogen eigen regels krijgen; Puppet Strings heeft afgebroken tekst volgens de aparte opmaak.

**Suppressions**

Suppressie niet toegestaan: de handmatige norm blijft gelden, ook bij een groene scan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een Engelse zin wordt willekeurig over meerdere fysieke regels verdeeld. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Houd iedere zin op één fysieke regel en leg de reden, beperking of relevante gevolgen uit. Beoordeel de genoemde voorwaarden afzonderlijk.

**Grensgevallen**

Lijsten, voorbeelden en syntaxis mogen eigen regels krijgen; Puppet Strings heeft afgebroken tekst volgens de aparte opmaak.

**Handmatige review**

Lees de volledige zin en werk willekeurige afbrekingen in geraakte comments weg.

**Verificatie**

Handmatige beoordeling van beide scenario’s: Lees de volledige zin en werk willekeurige afbrekingen in geraakte comments weg. De onjuiste variant wordt afgekeurd; de juiste variant voldoet onder de beschreven voorwaarden. Module- en hostgedrag worden hiermee niet als getest gepresenteerd.

### Voorwaarden toelichten

**Norm**

Geef iedere `if` en `unless` een toelichting die de voorwaarde en de bijbehorende verwerking verklaart. Als direct ervoor variabelen worden berekend die de voorwaarde voorbereiden, staat die toelichting boven de eerste toekenning. De voorbereiding en de voorwaarde vormen dan samen één blok:

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

If/unless, geneste voorwaarden, toekenningsvormen en aaneengesloten voorbereiding inclusief transitieve invoer en elsif-condities.

**Automatische controle**

`project_if_sections`

**Detectiegrenzen**

Een ongerelateerde toekenning of andere opdracht onderbreekt de terugwaartse reeks. Bestaand commentaar wordt alleen op plaatsing beoordeeld; inhoud blijft review.

**Meldingen en severity**

`Explain the conditional above its preparatory variable assignments, or above the if/unless when there are none`: `warning` bij ontbrekende toelichting boven het vastgestelde begin.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Elsif deelt de ketentoelichting. Tussen uitleg en blok mag een lege regel staan. Een geneste if heeft wel een eigen toelichting nodig.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_if_sections` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_if_sections warning -->
```puppet
if $active { notice('Active') }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_if_sections` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_if_sections clean -->
```puppet
# Report the active state.
if $active { notice('Active') }
```

**Grensgevallen**

Elsif deelt de ketentoelichting. Tussen uitleg en blok mag een lege regel staan. Een geneste if heeft wel een eigen toelichting nodig. Een ongerelateerde toekenning of andere opdracht onderbreekt de terugwaartse reeks. Bestaand commentaar wordt alleen op plaatsing beoordeeld; inhoud blijft review. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Voorwaarden toelichten](#verdieping-bij-voorwaarden-toelichten).

**Handmatige review**

Controleer dat de uitleg alle voorbereide waarden en de feitelijke voorwaarde verklaart en niet alleen een vorig of buitenste blok beschrijft.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [if_sections_test.rb](../tests/if_sections_test.rb), [cli_sections_test.rb](../tests/cli_sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Voorwaarden toelichten

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_if_sections` gecontroleerd.

<!-- lint-example: project_if_sections clean -->
```puppet
# Register this target only when monitoring is enabled.
$active = $ensure == present and defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none'
if ($active) {
  notice('Register the active monitoring target')
}
```

Zonder voorbereiding staat de toelichting boven de voorwaarde zelf. Bij `$result = if ...` staat zij boven de toekenning en eventuele voorbereiding. Een `elsif` hoort bij dezelfde keten; een geneste voorwaarde krijgt een eigen toelichting. Er mag een lege regel tussen toelichting en blok staan. De [gewone commentaaropmaak](#toelichtingen-bij-code) regelt de scheiding met eerdere code.

`project_if_sections` volgt de aaneengesloten voorbereiding van de voorwaarde. Een losstaande toekenning of andere opdracht onderbreekt die reeks. De [technische analyse](../README.md#voorbereiding-van-voorwaarden) beschrijft hoe indirecte afhankelijkheden worden gevolgd.

De check schrijft of verplaatst geen commentaar. Beoordeel bij een melding of de toelichting zowel de voorbereiding als de voorwaarde uitlegt. Commentaar bij een eerder of bovenliggend blok vervangt die uitleg niet.

### Variabelen groeperen

<!-- lint-rule-group -->

### Een variabelegroep bij blokbegin toelichten

**Norm**

Groepeer variabelen op het doel waarvoor je ze berekent. Begin een codeblok dat na `{` meteen variabelen toekent met een toelichting binnen dat blok, direct boven de eerste toekenning. Dit geldt ook voor één variabele en voor korte `else`-, `elsif`- en `case`-takken, classes, defined types en lambdablokken. De toelichting boven de voorwaarde beschrijft waarom de tak wordt uitgevoerd; de uitleg binnen het blok beschrijft de variabelen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Toekenningen direct na { in classes, defines, lambdas, else-, elsif- en case-takken.

**Automatische controle**

`project_variable_sections`

**Detectiegrenzen**

Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope.

**Meldingen en severity**

`Explain the variable group immediately inside the opening brace`: `warning` bij ontbrekende inhoudelijke toelichting. Een eventuele groepeerhint blijft onderdeel van die warning; zie de gedeelde verdieping.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Ook één variabele verlangt de toelichting. De toelichting boven een voorwaarde vervangt die binnen haar tak niet.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_variable_sections` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_variable_sections warning -->
```puppet
if $active {
  $value = 1
}
```

**Correct voorbeeld**

Fragment; alleen de controle `project_variable_sections` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_variable_sections clean -->
```puppet
if $active {
  # Prepare the selected value.
  $value = 1
}
```

**Grensgevallen**

Onafhankelijke instellingen mogen samen één toelichting delen. Er is geen verplicht commentaar per variabele. Een resource, voorwaarde of andere opdracht beëindigt de reeks. Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen).

**Handmatige review**

Controleer per groep het doel en de werkelijk gebruikte variabelen. Beoordeel vóór samenvoegen of een eerste gebruik of andere uitvoering de verplaatsing verhindert.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [variable_openings_test.rb](../tests/variable_openings_test.rb), [variable_dependencies_test.rb](../tests/variable_dependencies_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Een onafhankelijke groep na afhankelijke waarden beginnen

**Norm**

Maak een nieuwe groep wanneer na onderling afhankelijke berekeningen een losstaande instelling volgt. De [verdieping bij deze regel](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen) laat dit zien met een genormaliseerde servernaam, een ge-escapete waarde en een label, gevolgd door afzonderlijke configuratie-instellingen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Reeds toegelichte aaneengesloten toekenningsreeksen met echte lokale afhankelijkheden.

**Automatische controle**

`project_variable_sections`

**Detectiegrenzen**

Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope.

**Meldingen en severity**

`Start unrelated assignments after a dependent variable group with a blank line and a preceding explanatory comment`: `warning` bij een onafhankelijke toekenning na een aantoonbaar afhankelijke groep. Een eventuele groepeerhint blijft warning.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Onafhankelijke instellingen mogen samen onder één toelichting. De check verlangt geen commentaar per variabele. Andere opdrachten beëindigen de reeks; buiten blokbegin worden alleen reeds toegelichte reeksen onderzocht.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_variable_sections`; verwacht warning.

<!-- lint-example: project_variable_sections warning -->
```puppet
# Prepare a related pair.
$a = 'a'
$b = $a
$c = 'c'
```

**Correct voorbeeld**

Fragment; alleen `project_variable_sections`; verwacht geen melding.

<!-- lint-example: project_variable_sections clean -->
```puppet
# Prepare a related pair.
$a = 'a'
$b = $a

# Configure the independent value.
$c = 'c'
```

**Grensgevallen**

Onafhankelijke instellingen mogen samen één toelichting delen. Er is geen verplicht commentaar per variabele. Een resource, voorwaarde of andere opdracht beëindigt de reeks. Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen).

**Handmatige review**

Controleer per groep het doel en de werkelijk gebruikte variabelen. Beoordeel vóór samenvoegen of een eerste gebruik of andere uitvoering de verplaatsing verhindert.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide_examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [variable_openings_test.rb](../tests/variable_openings_test.rb), [variable_dependencies_test.rb](../tests/variable_dependencies_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen

Maak een nieuwe groep wanneer na onderling afhankelijke berekeningen een losstaande instelling volgt. In dit voorbeeld horen de genormaliseerde servernaam, de ge-escapete waarde en het label bij elkaar. Het configuratiepad en de numerieke instellingen vormen de volgende groep:

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_variable_sections` gecontroleerd.

<!-- lint-example: project_variable_sections clean -->
```puppet
# Prepare arguments only for an active certificate check.
if $active {
  # Normalize the name for the command and its label.
  $server_name_correct = regsubst($server_name ? { undef => '', default => $server_name }, '\s+', ' ', 'G')
  $server_name_shell = stdlib::shell_escape($server_name_correct)
  $check_friendly = "Nginx TLS ${server_name_correct}"

  # Escape the configuration path and numeric settings before passing them to the check.
  $config_file_shell = stdlib::shell_escape($config_file)
  $detail_limit_shell = stdlib::shell_escape(String($detail_limit))
  $timeout_shell = stdlib::shell_escape(String($timeout))
  $validity_critical_shell = stdlib::shell_escape(String($validity_critical))
  $validity_warning_shell = stdlib::shell_escape(String($validity_warning))
}
```

`project_variable_sections` controleert de toelichting aan het begin van een blok en de grenzen tussen toegelichte groepen. Een leeg commentaar of alleen een lintmarkering telt niet als toelichting. Zodra een toekenning een eerder berekende variabele uit de groep gebruikt, zoekt de check naar de eerste volgende toekenning die onafhankelijk van die groep is. Die krijgt een eigen toelichting; alleen een lege regel is onvoldoende. Een later samengesteld commando maakt zo'n eerdere scheiding niet overbodig.

Onafhankelijke instellingen mogen samen onder één toelichting staan, zoals de numerieke instellingen in het voorbeeld. De check verlangt dus geen commentaar per variabele. Hij leidt samenhang af uit echte verwijzingen, ook in interpolatie. Een overeenkomstige naam, dezelfde functie of hetzelfde externe invoerveld is daarvoor geen bewijs.

Een resource, voorwaarde of andere opdracht beëindigt de onderzochte reeks. Buiten het begin van een blok onderzoekt de check alleen reeksen die al een toelichting hebben. De analyse houdt lokale lambdavariabelen en parameters gescheiden van variabelen buiten de lambda.

Bij een ontbrekende toelichting kan de melding wijzen op een latere groep met dezelfde buitenste functie. Gebruik die hint om te beoordelen of de waarden bij elkaar horen en of de volgorde van uitvoeren mag veranderen. De [technische naslag](../README.md#hints-voor-variabelegroepen) beschrijft wanneer de hint verschijnt. Er is geen autofix: de linter kan de inhoudelijke samenhang niet bepalen en verplaatst daarom geen code.

### Puppet Strings

<!-- lint-rule-group -->

De volgende zelfstandige regels delen de Strings-parser. Inhoudelijke controles en opmaakcontroles zijn afzonderlijke checks; iedere regel vermeldt haar eigen varianten.

### Publieke declaraties bij de code documenteren

**Norm**

Puppet Strings beschrijft de publieke interface bij de code. Zet de documentatie direct boven iedere publieke class en ieder publiek defined type. De lezer moet daarmee kunnen bepalen welke parameters nodig zijn en wat de declaratie op een host verandert.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types. API-markering van nieuwe functies blijft handmatig waar die niet wordt geanalyseerd.

**Automatische controle**

`project_documentation`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit.

**Meldingen en severity**

De inhoudscheck meldt ontbrekende summary, API-tag, voorbeeld en parameterbeschrijvingen afzonderlijk; de exacte warnings staan bij [Summary](#strings-summary-op-één-regel), [API](#strings-api-markering), [Voorbeeld](#uitvoerbare-strings-voorbeelden) en [Parameters](#strings-parametercontract).

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Geen uitzondering op de beschreven documentatieplicht; een detectiegrens heft haar niet op.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

De inhoudscheck betrekt ook niet als public gemarkeerde classes en defined types. Een functionele beschrijving voor een functie wordt niet door deze check bewezen.

**Handmatige review**

Vergelijk de documentatie met de publieke parameters en de daadwerkelijke gevolgen op een host; beoordeel ook een aanwezig maar onjuist contract.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). [interface_contract_test.rb](../tests/interface_contract_test.rb), `test_documentation_matches_each_declaration`, verifieert afzonderlijke declaraties. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Verdieping bij Publieke declaraties bij de code documenteren

`project_documentation` controleert bij classes en defined types de summary, API-markering, voorbeeldtag en parameterbeschrijvingen. De check controleert aanwezigheid en volgorde, niet of de tekst het werkelijke gedrag volledig beschrijft. Ontbrekende uitleg of tags worden niet automatisch ingevuld.

### Strings API-markering

**Norm**

Markeer nieuwe classes, defined types en functies met `@api public` of `@api private`.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types. API-markering van nieuwe functies blijft handmatig waar die niet wordt geanalyseerd.

**Automatische controle**

`project_documentation`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. Functies vallen buiten deze inhoudscheck.

**Meldingen en severity**

`Document the declaration with @api public or @api private`: `warning` wanneer niet precies één geldige API-regel aanwezig is.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Geen uitzondering op de beschreven documentatieplicht; een detectiegrens heft haar niet op.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Een dubbele API-tag geeft dezelfde warning. Een nieuwe functie zonder API-markering vraagt handmatige afkeur; dat ontbreken wordt hier niet automatisch gedetecteerd.

**Handmatige review**

Bepaal de bedoelde public/private-interface en controleer nieuwe classes, defines én functies.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). [interface_contract_test.rb](../tests/interface_contract_test.rb) controleert documentatie per declaratie; het bovenstaande fragment bewijst de API-variant. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Strings-summary op één regel

**Norm**

Begin met een korte `@summary` op één regel en zet verdere uitleg eronder.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation`, `project_documentation_layout`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. Summarytekst wordt niet automatisch ingekort.

**Meldingen en severity**

`Document the declaration with one non-empty @summary`: `warning` bij ontbrekende, lege of dubbele summary. `Keep @summary on one line; move additional explanation to the overview`: `warning` bij vervolgtekst in de summary. Lengtevarianten en hun suffix staan bij [Strings-regelbreedte](#strings-regelbreedte).

**Autofix**

Geen voor de inhoudsvariant en summaryvervolgtekst. Voor de lengtevariant bij een summary: Geen.

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Geen uitzondering op de beschreven documentatieplicht; een detectiegrens heft haar niet op.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Een lange summary wordt handmatig ingekort zonder betekenisverlies; nadere uitleg verhuist naar de overview. Een ingesprongen vervolgzin is geen tweede toegestane summaryregel.

**Handmatige review**

Controleer één korte summary en behoud noodzakelijke details in de overview.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). [documentation_structure_test.rb](../tests/documentation_structure_test.rb), `test_summary_requires_manual_shortening_without_deleting_text`, verifieert behoud en weigering. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Strings-parametercontract

**Norm**

Beschrijf iedere parameter eenmaal met `@param`, in dezelfde volgorde als de declaratie. Leg uit wat de waarde betekent, hoe de default tot stand komt en wat bijzondere waarden zoals `undef`, `true` en `false` doen. Neem ook relevante beperkingen, dependencies, gegenereerde resources, terugvalgedrag en gevolgen voor beveiliging of compatibiliteit op.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types. API-markering van nieuwe functies blijft handmatig waar die niet wordt geanalyseerd.

**Automatische controle**

`project_documentation`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. De check leest tagvolgorde en aanwezige tekst, geen defaultsemantiek.

**Meldingen en severity**

`Document every parameter exactly once, in declaration order`: `warning` bij een verschil tussen tagnamen en declaratievolgorde. `Give each @param a description of its contract and default meaning`: `warning` wanneer tekst op de tagregel en de eerstvolgende ingesprongen regel ontbreekt.

**Autofix**

Geen voor beide meldingsvarianten.

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Een korte beschrijving mag op de @param-regel staan; de [tagopmaak](#strings-taginspringing) bepaalt langere tekst.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example (String $label) {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @param label
#   Supplies the displayed label.
#
# @api public
class example (String $label) {}
```

**Grensgevallen**

Typeannotaties zoals @param [String] label worden herkend. Lege beschrijvingen, dubbelen en verkeerde volgorde vragen correctie; aanwezige maar onjuiste defaultuitleg blijft review.

**Handmatige review**

Vergelijk iedere parameter, default, undef/true/false-betekenis, dependency, gegenereerde resource, fallback en beveiligings- of compatibiliteitsgevolg met de implementatie.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). [documentation_scope_test.rb](../tests/documentation_scope_test.rb), beschrijvingsscenario’s, en [interface_contract_test.rb](../tests/interface_contract_test.rb) controleren aanwezigheid en volgorde. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Uitvoerbare Strings-voorbeelden

**Norm**

Een eenvoudig uitvoerbaar `@example` laat het normale gebruik zien. De titel staat achter de tag, de code op de ingesprongen commentregels eronder. Dit documentatieblok toont de opmaak:

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation`, `project_documentation_layout`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. De opmaakcheck herkent vervolgregels, maar bewijst geen syntactisch of functioneel juist voorbeeld.

**Meldingen en severity**

`Provide a Puppet Strings @example`: `warning` bij ontbrekende tag met niet-lege titel. `Put the example description on the @example line`: `warning` bij lege titel. `Put example code on indented comment lines below @example`: `warning` wanneer de eerstvolgende inhoud ontbreekt of een nieuwe tag is. Inspringing en breedte volgen de afzonderlijke opmaakregels.

**Autofix**

Geen voor deze drie varianten.

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Voorbeeldcode bewaart haar eigen verdere inspringing; zij wordt niet als gewone tekst afgebroken.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
# @summary Demonstrates the interface.
#
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Een lege titel, ontbrekende code, onjuiste eerste inspringing en code boven 140 tekens zijn verschillende scenario’s. Markdown- of code-inhoud wordt niet geherformuleerd.

**Handmatige review**

Werk het voorbeeld met prerequisites tijdelijk uit, valideer correcte en onjuiste invoer met parser en volledig profiel en beoordeel het normale gebruik.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). [documentation_examples_test.rb](../tests/documentation_examples_test.rb) controleert behoud van voorbeeldcode, breedte, handmatige inspringing en titel/body. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Verdieping bij Uitvoerbare Strings-voorbeelden

Fragment; dit behouden documentatieblok toont de opmaak en is op zichzelf geen volledige declaratie.

Voor dit fragment wordt uitsluitend `project_documentation, project_documentation_layout` gecontroleerd. Voeg voor uitvoering `class example (Boolean $keyboard_enable = true) {}` toe na het blok.

<!-- lint-example: project_documentation, project_documentation_layout clean keyboard_class -->
```puppet
# @summary Manages local console configuration.
#
# This class manages console packages and configuration, using the host defaults
# when no explicit override is supplied.
#
# @example Enable keyboard configuration
#   class { 'example':
#     keyboard_enable => true,
#   }
#
# @param keyboard_enable
#   Controls keyboard package and configuration management.
#   `undef` uses the host default; `true` enables management and `false` disables it.
#
# @api public
```

### Strings-regelbreedte

**Norm**

Breek gewone beschrijvingen af op logische plaatsen, bij voorkeur rond 120 tekens en uiterlijk bij 140 tekens. De inspringing en het commentteken tellen mee. Houd woorden, technische identifiers en inline code intact en behoud de alinea-indeling. Een ondeelbaar element tussen 120 en 140 tekens mag op zijn regel blijven staan. Voor langere letterlijke waarden geldt de uitzondering bij [Lange regels](CODE_RULES.md#lange-regels).

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Voorbeeldcode wordt pas boven 140 tekens gemeld. Een ondeelbaar element tussen 120 en 140 blijft intact. Gewone tekst, summaries, voorbeeldtitels, Markdownstructuur en letterlijke waarden krijgen verschillende fixbehandeling.

**Meldingen en severity**

`Puppet Strings documentation exceeds the maximum 140-character line length`: `warning` boven 140 zonder geldige literaluitzondering. `Puppet Strings documentation exceeds the preferred 120-character line width`: `warning` voor afbreekbare niet-voorbeeldtekst boven 120. Het suffix is `Shorten @summary and move the full description into the overview`, `Keep the @example title on one line and shorten it manually` of `Wrap documentation across comment lines; preserve literal values and example code`. Onveilig herschrijven voegt ` [review] Adjust manually; this construct cannot be safely rewritten` toe. `[review]` blijft warning.

**Autofix**

| Variant en constructie | Classificatie |
| --- | --- |
| Maximum of preferred bij veilig afbreekbare gewone tekst | Voorwaardelijk |
| Maximum of preferred bij summary, voorbeeldtitel, codevoorbeeld of onveilige structuur | Geen |

**Autofixvoorwaarden**

Breekt alleen gewone tekst op woorden af; behoudt backticks, identifiers, whitespace in literals en alinea’s. Herkenbare @param-tekst kan onder de tag verhuizen. Lijsten, tabellen, codefences, ingesprongen code, harde Markdownregeleinden, ongebalanceerde delimiters, onleesbare tags en ondeelbare te brede output krijgen geen onveilige herschrijving.

**Toegestane uitzonderingen**

Ondeelbare elementen van 120–140 tekens blijven toegestaan; langere literals uitsluitend met de begrensde uitzondering bij Lange regels.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# @summary Demonstrates the interface.
#
# word word word word word word word word word word word word word word word word word word word word word word word word end.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# word word word word word word word word word word word word
# word word word word word word word word word word word word end.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

120 tekens: schoon. Afbreekbare tekst op 121 en 140: preferred-warning. 141: maximum-warning. Een ondeelbaar pad van 126 tekens blijft schoon; een lange URL verbergt omringende afbreekbare tekst niet. Unicode en geneste inspringing tellen mee. De afzonderlijke Markdown-weigeringscategorieën staan in de autofixvoorwaarden.

**Handmatige review**

Lees tekst en gerenderde Markdown na; behoud alle woorden en technische waarden en controleer de werkelijke regellengte inclusief # en inspringing.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). [documentation_width_test.rb](../tests/documentation_width_test.rb) controleert 120/121/140/141, identifiers, URL, Unicode en parametertekst; [documentation_markup_test.rb](../tests/documentation_markup_test.rb) controleert iedere genoemde structuurweigering en woord-/alineabehoud. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Verdieping bij Strings-regelbreedte

`project_documentation_layout` controleert de opmaak boven classes, defined types, Puppet-functies en typedeclaraties. Afbreekbare tekst boven 120 tekens en documentatieregels boven 140 tekens geven een melding, ook als de standaardcheck een URL zou overslaan. Voorbeeldcode krijgt alleen boven 140 tekens een lengtemelding.

Met `--fix` kan de documentatiecheck gewone tekst afbreken en herkenbare tag-inspringing en sectiescheiding herstellen. Woorden, backtick-inhoud en alinea's blijven behouden. Summaries, voorbeeldtitels, voorbeeldcode en gestructureerde Markdown, zoals lijsten, tabellen en codeblokken, vragen waar nodig handmatige correctie. Een lange summary of voorbeeldtitel kort je zelf in. Bij onveilige of onduidelijke correcties blijft een melding met `[review]` staan.

> **Open normconflict (oplevering: Strings-breedte):** de behouden norm noemt circa 120 tekens een voorkeur en 140 het uiterste. De check meldt afbreekbare tekst op 121–140 tekens met warning, waardoor het profiel faalt. `test_preferred_width_is_distinguished_from_hard_maximum` en `test_exact_line_width_boundaries_include_the_comment_prefix` bevestigen dit verschil. Deze wijziging maakt de voorkeur niet verplicht en verandert de check niet; besluitvorming over de bedoelde grens blijft open.

### Strings-taginspringing

**Norm**

Bij een lange parameterbeschrijving staat alleen de naam achter `@param`; de uitleg volgt met twee extra spaties, als `#   ...`. Een korte beschrijving mag achter de parameternaam blijven staan.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Herkenbare voortzettingstekst wordt onderscheiden van voorbeeldcode en gestructureerde Markdown. Een lange @param-tag zonder leesbare parameternaam wordt niet herschreven.

**Meldingen en severity**

`Puppet Strings continuation lines must be indented with two spaces`: `warning` bij afwijkende voortzettingsinspringing. Kan met sectiescheiding of breedte op dezelfde regel worden gecombineerd met `; `. Onveilige constructies houden het [review]-suffix uit de breedteregel.

**Autofix**

Voorwaardelijk voor gewone herkenbare vervolgtekst; Geen voor onveilig te herschrijven voorbeeldcode, summaryvervolg of gestructureerde inhoud.

**Autofixvoorwaarden**

Herstelt uitsluitend herkenbare tekstinspringing; behoudt verdere inspringing in codevoorbeelden en weigert samenvattingen of gestructureerde Markdown wanneer het herschrijven onveilig is.

**Toegestane uitzonderingen**

Korte parameterbeschrijvingen mogen achter de parameternaam blijven staan.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @param label
# Supplies the displayed label.
#
# @api public
class example (String $label) {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @param label
#   Supplies the displayed label.
#
# @api public
class example (String $label) {}
```

**Grensgevallen**

Korte inlinebeschrijving: toegestaan. Lange beschrijving: onder de tag. Verkeerd ingesprongen gewone vervolgtekst: fix. Eerste voorbeeldregel met afwijkende inspringing: handmatig; verdere voorbeeldcode blijft exact.

**Handmatige review**

Controleer het verschil tussen proza en voorbeeldcode en behoud de betekenisvolle code-inspringing.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). [documentation_structure_test.rb](../tests/documentation_structure_test.rb), `test_continuation_indentation_is_corrected_for_parameters_and_other_tags`; [documentation_examples_test.rb](../tests/documentation_examples_test.rb), inspringingsweigeringen. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Strings-secties met commentregels scheiden

**Norm**

Scheid secties en afzonderlijke parameters met een lege commentregel `#`, zodat het één documentatieblok blijft. Een volledig lege broncoderegel hoort daar niet tussen. Behoud binnen voorbeeldcode de verdere code-inspringing.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Een lege bronregel en whitespace-only comment worden anders behandeld dan een lege commentregel. Herkende sectieovergangen krijgen scheiding; gewone alinea’s behouden hun volgorde.

**Meldingen en severity**

`Separate Puppet Strings sections with a blank comment line (#)`: `warning` bij volledig lege bronregel, whitespace-only comment of ontbrekende sectiescheiding. De formatter kan dit met inspringings- en breedtemeldingen op dezelfde regel combineren.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Vervangt lege bronregels door # en voegt herkenbare sectiescheiding toe. Correctie met daarnaast onveilige inspringing of te brede ondeelbare output kan worden geweigerd; tekst en alinea’s blijven behouden.

**Toegestane uitzonderingen**

Lege commentregels bewaren één documentatieblok; betekenisvolle lege regels in voorbeeldcode blijven behouden.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Volledig lege bronregel: wordt #. Comment met alleen spaties: wordt #. Twee bestaande alinea’s: blijven gescheiden en in volgorde. Ontbrekende scheiding plus onveilige code-inspringing: handmatige review.

**Handmatige review**

Lees sectiegrenzen en alinea’s en controleer dat voorbeeldcode en letterlijke inhoud niet zijn samengevoegd.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). [documentation_structure_test.rb](../tests/documentation_structure_test.rb) controleert secties en lege bronregels; [documentation_markup_test.rb](../tests/documentation_markup_test.rb) controleert alinea’s en whitespace-only comments. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Verdieping bij Strings-secties met commentregels scheiden

De [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm) beschrijft de algemene opbouw.

### Lengtesuppressions in Strings begrenzen

**Norm**

Een overbodig `140chars`-blok rond uitsluitend gewone documentatie kan de autofix verwijderen. Een blok met een toelichtende reden, een gecombineerde uitzondering of een uitzondering die ook Puppet-code omvat vraagt handmatige begrenzing. Controleer na correctie de tekst en Markdown-opbouw en valideer de voorbeelden volgens [Aanvullende validatie](../README.md#aanvullende-validatie).

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Een suppression moet uitsluitend gewone documentatie beslaan om automatisch verwijderd te kunnen worden. Gemengde inhoud, toelichtende reden en gecombineerde checks worden niet stilzwijgend herschreven.

**Meldingen en severity**

`Do not disable the 140-character rule for normal Puppet Strings documentation; wrap the documentation instead`: `warning`. Bij handmatige begrenzing volgt ` [review] Narrow the suppression manually, preserving literal values and other checks`.

**Autofix**

Voorwaardelijk voor een verwijderbaar uitsluitend-documentatieblok; Geen voor niet veilig te begrenzen blokken.

**Autofixvoorwaarden**

Verwijdert uitsluitend een overbodig enkelvoudig 140chars-blok en breekt veilige gewone tekst af; behoudt redenen, gecombineerde checks, letterlijke waarden en Puppet-code.

**Toegestane uitzonderingen**

Een ondeelbare lange letterlijke waarde mag een minimaal begrensde 140chars-uitzondering krijgen; sluit vóór gewone documentatie.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# lint:ignore:140chars
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
# lint:endignore
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Uitsluitend gewone documentatie zonder reden: verwijderbaar. Reden achter de markering, meerdere checks, code in hetzelfde bereik of literalgrens: handmatig behouden en begrenzen.

**Handmatige review**

Controleer ieder teken van het suppressionbereik; verifieer dat gewone tekst weer wordt gecontroleerd en literals en andere checks behouden blijven.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide_examples_test.rb](../tests/guide_examples_test.rb). [documentation_suppressions_test.rb](../tests/documentation_suppressions_test.rb) controleert verwijderbare en geweigerde suppressions en scopes. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Waar de uitleg hoort

<!-- lint-rule-group -->

### Interfacebeschrijvingen synchroniseren

**Norm**

Werk bij een interfacewijziging de Puppet Strings en de geraakte voorbeelden mee bij. Vergelijk de beschreven defaults, relaties en gegenereerde configuratie met het manifest. Als monitoringgedrag voor beheerders verandert, kijk dan ook naar het checkoverzicht in de project-README.

**Herkomst**

Projectregel

**Toepassingsgebied**

Puppet Strings, voorbeelden en het beheerdergerichte checkoverzicht bij interfacewijzigingen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Het checkoverzicht verandert alleen wanneer het beheerdergerichte monitoringgedrag verandert.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Het checkoverzicht verandert alleen wanneer het beheerdergerichte monitoringgedrag verandert.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een parameterdefault verandert, maar Strings en het voorbeeld noemen de oude waarde. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Werk Strings en geraakte voorbeelden bij en pas bij gewijzigd monitoringgedrag het checkoverzicht aan. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Het checkoverzicht verandert alleen wanneer het beheerdergerichte monitoringgedrag verandert.

**Handmatige review**

Vergelijk defaults, relaties en gegenereerde configuratie afzonderlijk met het manifest.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Vergelijk defaults, relaties en gegenereerde configuratie afzonderlijk met het manifest. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

### Documentatie op haar aangewezen plaats onderhouden

**Norm**

Gebruik de [documentatie-indeling in `AGENTS.md`](../../../AGENTS.md#documentation) om te bepalen waar de uitleg thuishoort. Gebruikskeuzes horen in de gebruikershandleiding, parametercontracten in Puppet Strings en lokale implementatieredenen bij het script of de template. Maak geen handmatige `REFERENCE.md` of `docs/`-boom voor informatie die Puppet Strings kan genereren. Voeg een ADR alleen toe wanneer dat is gevraagd of al gebruikelijk is.

**Herkomst**

Projectregel

**Toepassingsgebied**

Gebruikskeuzes, parametercontracten en lokale implementatieredenen.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een ADR wordt alleen toegevoegd op verzoek of wanneer dat al gebruikelijk is; dit wijzigt de inhoudelijke documentatieplicht niet.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Een ADR wordt alleen toegevoegd op verzoek of wanneer dat al gebruikelijk is; dit wijzigt de inhoudelijke documentatieplicht niet.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een handmatig REFERENCE.md dupliceert de door Puppet Strings te genereren parameterbeschrijvingen. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Behoud parametercontracten bij de code, gebruikskeuzes in de gebruikershandleiding en lokale redenen bij script of template. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Een ADR wordt alleen toegevoegd op verzoek of wanneer dat al gebruikelijk is; dit wijzigt de inhoudelijke documentatieplicht niet.

**Handmatige review**

Controleer de verantwoordelijkheden van iedere geraakte uitleg en voorkom een tweede handmatige contractbron.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer de verantwoordelijkheden van iedere geraakte uitleg en voorkom een tweede handmatige contractbron. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.

### Uitvoerbare voorbeeldscenario’s onderhouden

**Norm**

Breid bij voorkeur een bestaand voorbeeldscenario uit. Toon daarin de benodigde parameters en zorg dat het voorbeeld met de genoemde voorwaarden uitvoerbaar is. De [project-README](../../../README.md#gebruik-van-voorbeelden-en-parameterdocumentatie) beschrijft het gebruik van voorbeeldwaarden, `Sensitive(...)` en Hiera; voor synthetische gegevens gelden de [beveiligingsregels](../../../AGENTS.md#security-and-privacy).

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe en bijgewerkte gebruiksvoorbeelden bij publieke interfaces.

**Automatische controle**

Geen automatische controle. Eventuele ondersteunende checks die in de norm worden genoemd bewijzen dit inhoudelijke contract niet.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Uitbreiden van een bestaand scenario is een voorkeur. De uitvoerbaarheid onder de vermelde voorwaarden en de beveiligingsafspraken blijven verplicht.

**Meldingen en severity**

Geen lintmelding of severity voor deze handmatige norm; de reviewer beoordeelt de overtreding op de hieronder genoemde criteria.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: dit inhoudelijke contract heeft geen autofix.

**Toegestane uitzonderingen**

Uitbreiden van een bestaand scenario is een voorkeur. De uitvoerbaarheid onder de vermelde voorwaarden en de beveiligingsafspraken blijven verplicht.

**Suppressions**

Suppressie niet toegestaan: een lintmarkering heft deze reviewverplichting niet op.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een voorbeeld mist een verplicht argument en presenteert een geheim als gewone tekst. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Breid bij voorkeur het bestaande scenario uit, vermeld voorwaarden en vereiste argumenten en volg de beschreven Sensitive- en Hiera-afspraken. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Grensgevallen**

Uitbreiden van een bestaand scenario is een voorkeur. De uitvoerbaarheid onder de vermelde voorwaarden en de beveiligingsafspraken blijven verplicht.

**Handmatige review**

Controleer alle genoemde prerequisites, argumenten en synthetische waarden; valideer het uitgewerkte voorbeeld volgens Aanvullende validatie.

**Verificatie**

Handmatige vergelijking van het onjuiste en correcte scenario met de norm: Controleer alle genoemde prerequisites, argumenten en synthetische waarden; valideer het uitgewerkte voorbeeld volgens Aanvullende validatie. Het onjuiste scenario schendt de genoemde verplichting; de juiste variant behoudt de uitzonderingsvoorwaarden. Dit is reviewbewijs, geen uitgevoerde host- of modulegedragstest.
