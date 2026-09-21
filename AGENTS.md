# AGENTS.md

## Scope And Authority

This file governs project-wide development workflow, engineering responsibilities, security, and documentation governance. Its content and structure follow [Maintaining AGENTS.md](#maintaining-agentsmd).

- Agents must read this file and the root `README.md` before making changes.
- Local agent instructions may refine workflow within this baseline, but must not weaken or duplicate project-wide policy.

### Authority And Rule Placement

Every durable norm has exactly one authoritative location. Classify a new or changed norm by the decision it governs, not by the file where the issue was found. Separate mixed passages before assigning ownership; apply the following questions in order, using the specific tooling route for tool procedures:

1. Does it govern how a developer or agent investigates, scopes, reviews, validates, or delivers a change? Keep that project-wide workflow obligation in `AGENTS.md`.
2. Does it govern how general Puppet code is written or structured? Use [CODE_RULES.md](.tools/lint/docs/CODE_RULES.md).
3. Does it govern Puppet Strings, Puppet code comments, or Puppet interface documentation? Use [DOCUMENTATION_RULES.md](.tools/lint/docs/DOCUMENTATION_RULES.md).
4. Does it govern operational implementation, including managed files, permissions, systemd, shell, runtime tools, or monitoring? Use [OPERATIONAL_RULES.md](.tools/lint/docs/OPERATIONAL_RULES.md).
5. Does it govern installation, configuration, execution, CI, reporting, check registration, autofix, tooltests, or maintenance of the lint tooling? Use the [lint README](.tools/lint/README.md).
6. Does it govern general repository documentation, README structure, Markdown, editorial review, or documentation ownership? Keep it in `AGENTS.md`.

- Never duplicate a complete norm across these layers. Link to the authoritative source when a workflow obligation depends on a code or implementation norm.
- Use a short summary only when it is necessary to explain a workflow decision and does not create a second norm. The authoritative source owns conditions, exceptions, and concrete implementation requirements. Checklists refer to that source without redefining it.
- Maintain code style, layout, naming, and implementation conventions in the rules document that owns the code, not in `AGENTS.md`. This file requires their application and review without defining them again. Linter architecture and Ruby tooling conventions belong in the lint README.
- Rule ownership does not depend on automation. The rules documents are the central code and implementation standard, including fully automated, partly automated, detection-only, and exclusively manual rules. Missing checks or unsafe autofix never move a norm into `AGENTS.md` or make it optional.
- When a task asks for a new general agreement, determine its owner before editing. Do not automatically add it here merely because the request calls it an "agent rule" or names `AGENTS.md`. Classify workflow, Puppet code, Puppet documentation, operational implementation, tooling, and general repository documentation first; add only a focused reference here when agents need to find the norm.
- Keep general workflow out of the rules documents as well: preparation, scope, user changes, Git policy, overall security review, diff review, and reporting incomplete validation remain project-wide responsibilities here.
- Apply this ownership model when maintaining rules or references in root and local agent instructions, the lint guide, or other documentation.

### Project Constraints

#### First-Party Code And Dependencies

- Treat all module directories listed in the README as first-party except the vendored Git submodules `concat`, `debconf`, `reboot`, `stdlib`, and `timezone`.
- Keep changes within first-party code and repository-owned documentation or tooling unless the task explicitly requires a vendored dependency change.
- Never use vendored submodules as project style examples.

Integration choices and exceptions follow [runtime module dependencies](#runtime-module-dependencies).

#### Supported Platforms

The first-party Puppet modules target Debian and Ubuntu servers. The complete module set primarily targets `amd64`; individual platform paths may support a narrower or broader set of releases or architectures.

- Support claims for operating systems, releases, architectures, Puppet, or OpenVox must match the implementation, relevant `metadata.json`, available validation, and Dutch README in the same change.

## Working With The Existing Codebase

### Preparation

- Run `git status --short` before editing.
- Inspect the relevant module files and README sections before changing behavior or structure.
- Inspect the touched module's `metadata.json` when it exists.
- Inspect related manifests, templates, static files, examples, and systemd units, including generated units.
- Check existing integration with `basic_settings`, monitoring, systemd, security audit, `php8::fpm`, `nginx`, and other local modules relevant to the change.
- Check existing ownership, mode, `require`, `notify`, and `subscribe` patterns before adding resources.

### Puppet Code Authority

The [general Puppet rules](.tools/lint/docs/CODE_RULES.md), [Puppet documentation rules](.tools/lint/docs/DOCUMENTATION_RULES.md), and [operational rules](.tools/lint/docs/OPERATIONAL_RULES.md) define the mandatory Puppet conventions, formatting rules, permitted exceptions, and manual review criteria within their respective scopes. The [lint guide](.tools/lint/README.md) owns tooling procedures and the lint workflow; [authority and rule placement](#authority-and-rule-placement) distinguishes those procedures from project-wide workflow. The [project puppet-lint configuration](.puppet-lint.rc), shared profiles, and [project checks](.tools/lint/lib/project_lint/checks/) determine automated activation, detection, and correction; tool tests verify the scenarios they execute.

- Before changing Puppet code or Puppet Strings, follow the lint guide's [workflow](.tools/lint/README.md#werkwijze-bij-een-wijziging) and use its [reading guide](.tools/lint/README.md#leeswijzer) to select and read the relevant conventions and review criteria in `.tools/lint/docs/CODE_RULES.md`.
- For changes affecting Puppet code comments, Puppet Strings, or Puppet interface documentation, also read and apply the relevant rules in `.tools/lint/docs/DOCUMENTATION_RULES.md`.
- For changes affecting managed files or directories, ownership or permissions, security, systemd or services, shell code or templates, runtime tools or operational dependencies, or monitoring checks or registrations, also read and apply the relevant rules in `.tools/lint/docs/OPERATIONAL_RULES.md`. These operational rules apply in addition to the general rules.
- Both additional rule documents can apply to the same change; neither replaces `CODE_RULES.md`. A change affecting both operational code and its documentation must satisfy the applicable rules in all three rule documents.
- Read additional relevant sections when the change affects Puppet Strings, dependencies, monitoring, systemd, security, or lint tooling. Unrelated specialized sections need not be read in advance.
- Follow the authoritative conventions and review criteria for every affected area, extending the reading scope when new dependencies or integrations are found.
- Agents must apply the documented review criteria even when the automated lint checks pass.
- Keep conflicts between the documented norm, configuration, implementation, and test evidence visible. Do not silently change any source to resolve a conflict without evidence or an explicit project decision.
- Changes to Puppet conventions must include their tests and all affected first-party code in the same change.

### Scope And User Changes

- Preserve unrelated user changes.
- Treat a user's corrective edit as the current preferred pattern.
- Never restore an earlier agent approach unless the user explicitly requests it.
- Keep changes, including supporting refactors, scoped to the requested task and affected area.

Apply the [implementation scope](#implementation-scope) when deciding whether additional behavior or structure is justified.

### Impact Review

- Review effects on repository conventions, Puppet abstractions, and reusable wrappers. When a request uses a concrete example, assess whether the same principle applies to other resource types, consumers, or integrations in the affected area. Apply shared behavior consistently, preserve type-specific semantics, and record the scope and any deliberate limits in the change review.
- Review effects on monitoring, logging, alerting, audit rules, and operational diagnostics.
- Review effects on documentation, examples, supported platforms, compatibility, and operational commands.

### Git Commits

- AI agents must never create, amend, or rewrite Git commits through Git commands, APIs, or other tools.
- Leave validated changes in the working tree for human review and commit.

## Security And Privacy

### Security Baseline

- Treat security as a design requirement from the start of every change.
- Preserve correct existing hardening.
- Improve hardening only when application and operational behavior remain correct.
- Prefer the simpler design when it reduces attack surface without violating requirements.

### Privileges And Trust Boundaries

- Review effects on privileges, permissions, users, groups, capabilities, sudo, and secrets.
- Check whether changed code can run with less privilege or under a more constrained service identity.
- Identify new trust boundaries, sudo paths, writable paths, capabilities, and privilege assumptions.

### Systemd Review

- Review effects on systemd ordering, targets, hardening, restart behavior, and failure handling.
- Check whether systemd isolation can be tightened without breaking behavior.

### Network Review

- Review effects on networking, ports, sockets, firewalls, TLS, and service dependencies.
- Identify newly exposed ports.

#### Deployment-Owned Firewall Configuration

- Review firewall changes against the [deployment ownership and structural monitoring contract](.tools/lint/docs/OPERATIONAL_RULES.md#firewallconfiguratie-bij-de-deployment-houden).
- Validate packet reachability separately when required; do not present a successful structural inspection as that validation.

### External Disclosure

External disclosure is every transfer outside an organization-controlled or explicitly approved environment. It includes search queries, AI prompts, pasted text, uploads, screenshots, code snippets, forums, vendor portals, external issue trackers, code-sharing services, chat, email, and browser tools.

- Approval to use an external service must not be treated as authorization for every data type.
- Apply data classification, least disclosure, and minimum-necessary rules to every approved external service.

#### Secrets And Authentication Material

- Never disclose a password, passphrase, API key, access token, refresh token, session identifier, cookie, backup code, or credential-bearing connection string externally, including in search input.
- Never disclose a private key, certificate material, CSR, certificate chain, keystore, truststore, secret file, token file, kubeconfig, or `.env` content externally.
- Remove secrets completely before external use.
- Never use partial masking, prefixes, suffixes, fingerprints, hashes, or encoded variants when they can identify or validate the original value.
- Never put real secrets or credentials in code, comments, documentation, examples, tests, fixtures, logs, commits, tickets, prompts, or troubleshooting material.
- Use clearly synthetic authentication values in every example and reproduction.

#### Operational And Confidential Data

- Never disclose raw operational, personal, medical, customer, employee, organization, or commercially confidential data outside the approved environment.
- Treat logs, stack traces, HL7, FHIR, EDI, database records, exports, configuration files, packet captures, screenshots, source fragments, headers, and query parameters as potentially sensitive.
- Treat hostnames, IP addresses, internal URLs, filenames, usernames, tenant identifiers, project identifiers, and metadata as potentially sensitive.

#### Minimum Disclosure

- Reduce an external question to the minimum technical facts required to understand the problem.
- Prefer a generic description or minimal reproducible example containing only synthetic data.
- Share only the smallest sanitized fragment required to solve the problem.
- Never upload a complete repository, database dump, configuration set, message archive, or log collection when a smaller synthetic reproduction is sufficient.

#### Anonymization And Synthetic Data

- Anonymize or replace all data with synthetic values before it leaves the approved environment.
- Replace real names, identifiers, addresses, numbers, timestamps, domains, hostnames, and environment-specific values.
- Preserve only relationships needed to reproduce the issue.
- Use consistent synthetic placeholders when correlation matters, without reusing production values.
- Evaluate combinations of remaining fields for re-identification of people, organizations, customers, systems, or environments.
- Never call partially masked or pseudonymized data anonymous when re-identification remains reasonably possible.

#### Outbound Review

- Inspect the complete outbound content before sharing, including logs, stack traces, shell history, command output, request and response headers, URLs, query strings, comments, filenames, metadata, screenshots, diffs, archives, and copied surrounding context.

#### Unsafe Disclosure

- Never disclose information when safe sanitization cannot be demonstrated with sufficient confidence.
- Use approved internal documentation, tooling, colleagues, or secure support channels when external sharing is unsafe. A support channel does not override the disclosure restrictions.

#### Disclosure Incidents

- Stop further sharing immediately when a secret or confidential value is disclosed accidentally.
- Never repeat the exposed value in follow-up communication.
- Treat exposed credentials and key material as compromised.
- Revoke or rotate compromised credentials and key material where applicable.
- Follow the applicable security-incident procedure.

## Design And Implementation

### Implementation Scope

- Use the simplest implementation that meets the requested behavior and preserves existing contracts, starting with existing built-in functionality.
- Do not add input formats, normalization, edge-case handling, fallbacks, checks, helpers, configuration files, or abstractions unless the user's request, an existing project or interface contract, or a demonstrated failure within the task's scope requires them. Hypothetical edge cases, possible future use, and general robustness arguments are not sufficient justification. Tests created for an unsolicited extension do not establish a requirement for that extension.
- Before adding such behavior or structure, identify the concrete requirement or demonstrated failure and explain why the simpler implementation cannot satisfy it. Record that justification in the change review; omit the addition when the need cannot be demonstrated. During final diff review, remove additions that lack this justification. When the user asks to simplify, remove unnecessary behavior and its supporting code.

### Runtime Module Dependencies

- Prefer existing local modules for integrations. Runtime Puppet-module dependencies are limited to `stdlib`, `concat`, `reboot`, `timezone`, and `debconf`, except when a requirement demonstrably cannot be met adequately by the local implementation. Similar functionality alone does not justify adding an external Docker, MySQL, Nginx, or RabbitMQ module.
- Review the concrete requirement against existing local interfaces before accepting that exception. For sensitive components, include package policy, monitoring, and audit. For example, reject an external Nginx module added solely for comparable functionality; accept a substantiated exception only for a requirement the local integration cannot adequately meet. This dependency-policy decision requires manual review; the linter does not establish it.

### Reuse And Shared Abstractions

- Inspect existing abstractions before adding a new one.
- Review component interfaces and their callers against the [configuration ownership criteria](.tools/lint/docs/CODE_RULES.md#instellingen-bij-hun-eigenaar-houden), including the boundary between source configuration, internal derived values, and template input.
- Review parent-class interfaces before computing local settings in dependent defines, following the [class-check reuse criteria](.tools/lint/docs/CODE_RULES.md#classcontroles-hergebruiken).
- When work reveals duplicated behavior in the affected area, extract a shared abstraction and migrate the affected callers in the same change.
- Review repeated Puppet resource orchestration against the [defined-type reuse rule](.tools/lint/docs/CODE_RULES.md#herhaalde-resourceorkestratie-in-defined-types-delen).
- Preserve caller-specific security and lifecycle requirements during migration.
- Validate each migrated caller's behavior and dependencies.

### Prerequisite Review

- Identify operational prerequisites and ordering dependencies in changed code using the [prerequisite criteria](.tools/lint/docs/CODE_RULES.md#prerequisites-van-ordering-onderscheiden).
- Verify that the documented contract covers availability and absence according to those criteria; validate both cases, including relevant declaration and evaluation order.
- Apply the [dependency review criteria](.tools/lint/docs/CODE_RULES.md#resources-en-afhankelijkheden) and [external-command package contract](.tools/lint/docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos), including exec resources and managed scripts.

### Resource Placement And Ordering

- Review each added or moved declaration in the complete surrounding implementation against the [resource placement and ordering criteria](.tools/lint/docs/CODE_RULES.md#volgorde-en-meldingen). Record any necessary placement exception and its technical reason in the change review.

### Managed Files And Helpers

- Identify the existing owner of cleanup before adding removal logic and review the change against the [directory ownership and cleanup contract](.tools/lint/docs/OPERATIONAL_RULES.md#recursieve-bewerkingen-tot-module-eigendom-beperken).
- Apply the [managed-file identification](.tools/lint/docs/OPERATIONAL_RULES.md#door-puppet-beheerde-inhoud-markeren) and [management-helper rules](.tools/lint/docs/OPERATIONAL_RULES.md#beheerhelpers-op-de-gedeelde-locatie-installeren) when changing managed content or helpers.
- Verify identification in the resulting file content, including rendered templates and assembled fragments; review any format exception at its source.
- When moving a helper, update and validate all invocations and dependencies together.

### Shell Scripts

- For changes to any first-party shell code, including generated shell, apply the [operational shell rules](.tools/lint/docs/OPERATIONAL_RULES.md#shellscripts).
- Review the purpose of each external tool and all consumers before removing command discovery, package declarations, or dependency references, according to the [runtime-tool criteria](.tools/lint/docs/OPERATIONAL_RULES.md#runtime-tools-op-hun-functie-beoordelen).
- Preserve existing public interfaces or document deliberate changes with their callers, applying the [script input contract](.tools/lint/docs/OPERATIONAL_RULES.md#shellargumenten-en-runtime-instellingen-verwerken).

#### Shell Validation

- Review the source and rendered output against the linked operational shell rules, and run syntax validation with the intended interpreter. Puppet-lint does not validate shell syntax or the complete shell style.
- Validate changed scripts with isolated synthetic cases for every supported input source: defaults, environment-only values, combined environment and CLI values, empty and invalid inputs, and partial overrides. Include related value ordering, repeated options, boolean resets and timeout behavior where applicable.
- When replacing external tools, verify equivalent behavior, validation, error handling, monitoring statuses, exit codes and externally consumed output unless a behavior change is explicitly requested. Include relevant whitespace, escaping, locale and boundary cases in the comparison, and apply the [prerequisite review](#prerequisite-review) to removed or relocated dependencies.
- Keep functional validation outside the repository according to the [test scope](#test-scope), including checks of failure paths and temporary-file cleanup when affected.

### Monitoring Checks

- Apply the [monitoring implementation rules](.tools/lint/docs/OPERATIONAL_RULES.md#monitoringchecks) and review effects on existing checks and registrations.
- Review executor scheduling separately from script options against the [agent scheduling contract](.tools/lint/docs/OPERATIONAL_RULES.md#agentplanning-afzonderlijk-afstemmen).
- Report changed operational risks and verify the affected monitoring behavior with the validation below.

#### Monitoring Validation

- Verify each check's package guarantees through the general [external-command package contract and its documented exceptions](.tools/lint/docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos).
- Apply [shell validation](#shell-validation) to changed check implementations.
- For each changed check, validate registrations with at least two targets invoking the same executable with their own settings.
- For each changed check, validate that retiring one target preserves the shared executable and the other registrations.

## Development Tooling

### Development Environment

- Set up development and CI through the [documented bundle setup](.tools/lint/README.md#installatie), using the root Gemfile, lockfile, standard CLI, and regression tests.

### Linting And Autofix

- Inspect the project configuration and relevant check implementations when determining automated coverage or resolving a lint finding.
- Follow the lint guide's [correction workflow](.tools/lint/README.md#werkwijze-bij-een-wijziging), including the initial findings, safe scoped corrections, rescan, and remaining manual corrections.
- Review corrections manually when safety cannot be demonstrated. Review the complete diff to confirm semantic correctness and scope, preserving functional behavior, resource relationships, dependencies, and intended configuration.

### Linter Changes

- Before changing the linter, apply the [architecture and check development procedures](.tools/lint/README.md#een-check-toevoegen-of-wijzigen), including their public-interface and consumer-validation requirements.
- Use the [native autofix development procedure](.tools/lint/README.md#veilige-autofixes-ontwikkelen) for custom corrections and verify its detection, correction, rescan, idempotence, interaction, and suppression evidence.
- Report checks that appear suitable for safe detection or autofix but lack it as possible linter improvements. Implement them only when linter development is within the task's scope.

### Tool Test Structure

- Keep tests of repository tools beside their implementation under `.tools/<tool-name>/tests/`; use `.tools/lint/tests/` for the linter.
- Never create first-party test directories or test files elsewhere in the repository. This includes root-level `test/`, `tests/`, and `spec/` directories, standalone root-level test files, and module-specific test suites.
- Use fixtures and supporting functionality in tool tests only when they help verify a tool contract.
- Keep tool-specific helpers and fixtures with that tool's tests.
- Introduce shared test helpers only when multiple tools actually need them.

#### Tool Test Tasks

- Keep `test` and the default root Rake task responsible for recursive discovery of `.tools/**/tests/**/*_test.rb`.
- Keep `test:lint` limited to the linter tests under `.tools/lint/tests/`.

#### Test Structure Maintenance

- Update test discovery, path resolution, task definitions, CI, and affected documentation together when changing the test structure.
- Remove superseded test directories, duplicate files, unused support data, obsolete tasks, and stale references after migration.
- Preserve relevant regression coverage.
- Report any intentionally removed tests.
- Verify that the expected tests are discovered and executed; a successful command with no applicable tests is not sufficient validation.

### CI Jobs And Reports

- Apply the [CI and reporting procedures](.tools/lint/README.md#ci-van-deze-repository) when changing tooling or pipelines; verify job independence, report publication, exit-status preservation, and tracked-file checks.
- Never restore files to make a CI cleanliness check pass.

## Validation And Testing

### Test Scope

- Add or maintain repository-owned automated tests only for repository tools.
- Classify tests by the behavior their assertions verify, not by filenames, input formats, or implementation technologies.
- Run repository-wide Puppet syntax validation as a separate task using the native `puppet parser validate` command; keep it outside tool tests and their task dependencies.
- Never add general module, catalog, template, script, or monitoring behavior tests to the repository, including indirect execution through tool tests, helpers, hooks, or task dependencies.
- Perform required functional validation with existing validators and isolated temporary checks outside the repository.

### Isolation And Evidence

- Keep synthetic tests and validation isolated from production credentials, production connections, and managed hosts.
- Never treat vendored submodule tooling as validation of first-party modules.
- Never treat passing lint as a replacement for functional validation or review.
- Verify that the central lint solution and its required review evidence cover changed public interfaces.
- Record applicable review outcomes and functional validation commands and results in the change review.
- Report unavailable tooling, failed or unexecuted checks, fallback checks, and remaining uncertainty.
- Never describe incomplete validation as complete.

### Required Checks

- Run the full lint scan from the repository root with `bundle exec puppet-lint --no-config --config .puppet-lint.rc .` for every completed change. Use this explicit configuration route for targeted scans and autofix as documented in the [CLI instructions](.tools/lint/README.md#werking-van-de-controles).
- Run `bundle exec rubocop --config .rubocop.yml` for changes to first-party Ruby code or Ruby tooling, following the [Ruby validation workflow](.tools/lint/README.md#ruby-code-controleren). Resolve findings within the task's scope and report remaining findings without suppressing them to make the scan pass.
- Run all tool tests with `bundle exec rake test` after any corrections and before completing each change.
- Validate each changed Puppet manifest separately with `bundle exec puppet parser validate` followed by its path. Run `bundle exec rake validate:puppet` for the complete first-party manifest selection and its JUnit report before completion.
- Perform the additional validation relevant to the change, as documented in the [validation guide](.tools/lint/README.md#code-controleren).
- Complete applicable CI checks before marking the change complete.
- Inspect the final change scope with `git diff --name-only`.
- Require `git diff --check` to pass before completion.

## Documentation

### Language And Authority

- Write technical documentation in English, including changelog entries and this file, except for the Dutch documents specified below.
- Keep the root README and the four central lint documents, `.tools/lint/README.md`, `.tools/lint/docs/CODE_RULES.md`, `.tools/lint/docs/DOCUMENTATION_RULES.md`, and `.tools/lint/docs/OPERATIONAL_RULES.md`, in Dutch unless the user explicitly requests another language.
- Describe current behavior and instructions in the present tense. Do not explain current usage through historical comparisons or superseded workflows.
- Keep one authoritative location for each technical fact.
- Use concise summaries with pointers when a fact must appear in more than one layer.
- Place information according to the responsibilities below, using [authority and rule placement](#authority-and-rule-placement) for durable norms. Review every affected explanation against its audience and responsibility; avoid a second hand-maintained contract source. User choices belong in the user guide, parameter contracts in Puppet Strings, and local implementation reasons beside the script or template.
- Add an ADR only when requested or already customary. This exception to adding an ADR does not weaken the duty to document the affected interface or behavior.

| Location | Responsibility |
| --- | --- |
| `AGENTS.md` | Durable project-wide workflow, general review policy, engineering responsibilities, and repository documentation governance, including Markdown, README style, editorial review, information placement, and technical evidence. |
| Root `README.md` | Central user guide for module use and operational decisions. |
| `.tools/lint/README.md` | Central tooling guide with task-based navigation, daily workflow, installation, configuration, check registry, CLI, validation, CI, linter maintenance, tool testing, and downstream integration. |
| `.tools/lint/docs/CODE_RULES.md` | Authoritative general Puppet code rules and review criteria applicable to every Puppet change, including exceptions, detection and autofix limits, and examples. |
| `.tools/lint/docs/DOCUMENTATION_RULES.md` | Puppet code comments, Puppet Strings, and Puppet interface documentation, including their exceptions, detection and autofix limits, and examples. General repository documentation policy remains in `AGENTS.md`. |
| `.tools/lint/docs/OPERATIONAL_RULES.md` | Additional operational Puppet rules and review criteria for managed files, permissions, security, systemd, shell, runtime dependencies, and monitoring, with their exceptions, detection and autofix limits, and examples. |
| Puppet Strings | Concrete public interfaces, complete parameter descriptions, defaults, and fallback chains. |
| Scripts and templates | Local, non-obvious technical reasons and constraints, internal behavior, and per-check output contracts. |
| `examples/` | Expanded configuration scenarios. |
| Tests | Tool behavior, regressions, edge cases, failure scenarios, and automatically verifiable tool contracts. |
| Project documentation | System structure, data flows, component relationships, component purpose, installation, deployment, operations, and troubleshooting. |
| Feature or implementation documentation | Feature-specific interfaces, implementation steps, temporary migrations, and acceptance scenarios outside project-wide policy. |
| Configuration reference | Complete configuration variables, operational defaults, and exact startup or deployment commands outside Puppet Strings. |
| ADRs | Architectural decisions, alternatives, trade-offs, and their rationale. |

### Markdown

- Maintain a linked table of contents near the top of every repository-owned `.md` file except `AGENTS.md`, the sole exception to this requirement. Include every section and subsection heading in document order, at every depth, with nesting that follows the heading hierarchy; exclude the document title and headings inside code examples. Update the contents and verify its links whenever headings change.
- Limit only the repository root `README.md` table of contents to headings at levels two and three.
- Keep the sentences, paragraphs, lists, tables, and examples under each heading on that heading's subject and in a logical reading order. Introduce concepts before relying on them and connect the explanations before and after examples or tables. Rewrite surrounding text when additions or moves break that continuity.
- Keep each prose paragraph or list item on one physical line without hard wrapping, except where Markdown syntax, a table, or a code block requires line breaks.
- Separate distinct topics with normal paragraph breaks.
- Keep documentation professional, concrete, and focused on operational impact and risk.

### Editorial Review

#### Scope And Reading Path

- For every substantive change, determine whether documented interfaces, usage conditions, risks, or properties change. Record the affected documents or the reason no documentation update is needed in the change review. An internal code change alone does not require a root README addition.
- Before changing documentation content, identify each affected document's intended reader and the task it supports. Assess relevance for that concrete task, distinguishing module use, module development, and tooling maintenance where applicable.
- For every substantive change and every edit to a repository-owned Markdown file, read the complete affected documentation sections and surrounding reading path before editing and review them again afterward, including the relevant README section. This applies to all `.md` files, including `AGENTS.md` and small additions to existing text.
- Integrate additions into the existing explanation according to the [Markdown navigation and continuity rules](#markdown), reviewing the preceding and following text under each affected heading.
- For each passage added, changed, moved, or removed, identify the knowledge, decision, action, or troubleshooting it supports. Check that it fits both the document and heading, contributes useful information, and does not contradict existing guidance. Technical accuracy alone does not establish relevance.
- When consolidating repeated facts, preserve summaries, prominent warnings, and prerequisites that serve a distinct reader decision or entry point. Repetition alone is not a reason to remove them.
- Remove passages that serve no task for the intended reader instead of moving them to another heading or below an example.
- Check whether a new reader can identify prerequisites, the next action, and the expected outcome without reconstructing missing context.

#### Technical Evidence And Links

- Verify technical claims that are changed, relocated, or removed as obsolete against current manifests, Puppet Strings, scripts, templates, and examples.
- Never treat the README as implementation evidence.
- Report unresolved differences between documentation and implementation.
- Retain necessary warnings until those differences can be resolved.
- Check that commands, paths, options, and references match the accompanying examples and current implementation.
- Verify changed links.
- Confirm that relocated information is present at its destination.

#### Prose Review

- Read the resulting passage as a continuous whole, including unchanged surrounding text. Correct awkward phrasing, inconsistent terminology, abrupt transitions, and unexplained topic changes without changing technical meaning.
- Compare changed prose in `.tools/lint/README.md` with representative root README passages against the [README style guidance](#readme-style).
- Include a short representative passage in the review for owner feedback.
- Use an owner-accepted passage as a concrete style reference.

#### Limits Of Automated Editorial Checks

- Never treat automated technical checks as proof that an explanation is clear, pleasant to read, or useful for the reader's task.
- Never use AI-detection scores or word blacklists to assess prose quality or content relevance.
- Never impose fixed word, sentence, or paragraph counts or paragraph lengths on explanatory prose, including through automated checks. Apply the [rule structure guidance](#rule-structure) when editing `AGENTS.md`.

### README Guidance

#### README Scope

- Adapt README content to the document's purpose and audience rather than imposing the same outline on module overviews and tooling guides.
- Add detail to the root README only when users need it before use or during the described operation, it changes a security or compatibility decision, or the basic example requires it.
- Keep exhaustive parameter descriptions and developer-only implementation detail in their [designated locations](#language-and-authority), outside the root user guide.
- Reuse existing documentation for expanded variants and parameter details instead of creating a document for each detail or copying complete descriptions across layers.

#### README Navigation And Prerequisites

- Keep required prerequisites, essential warnings, and security- or compatibility-critical conditions beside the action they affect, including when relocating elaboration.
- Link to relocated elaboration from the warning and required action that remain at the point of use.
- Keep placeholder hostnames, replacement values, Hiera guidance, and `Sensitive(...)` handling near the quick start.
- Use `## Inhoudsopgave` for the [table of contents](#markdown) in Dutch READMEs; never label it `Legenda`.
- Maintain a bottom-level list of expanded examples.

#### README Style

##### Tone And Audience

- Write as an experienced colleague explaining the task to a technically competent reader who is new to this project.
- Use representative root README prose as a reference for a direct, practical, infrastructure-focused tone, rather than as a template or proof of quality.
- Never reproduce awkward or over-compressed wording merely for consistency.
- Write ordinary, accessible Dutch around exact code identifiers.
- Prefer familiar Dutch words over unnecessary English or abstract tooling terminology.
- Address the reader directly.
- Preserve natural connections between sentences without generic boilerplate, stock transitions, uncommon synonyms, promotional language, or forced informality.

##### Organization And Explanation

- Organize usage guidance around the reader's task rather than implementation order or review requirements.
- Give each paragraph one coherent topic, separating independent instructions instead of compressing them to shorten the document.
- Describe concrete actions, conditions, and consequences.
- Explain non-obvious choices when the explanation helps the reader act correctly.
- Use headings, lists, and tables when they help navigation or comparison, except where the [considerations presentation rules](#considerations-presentation) require prose.
- Retain useful lists outside those considerations, including main properties and installation steps.
- Do not add filler to make sections look uniform. The required fields in the lint guide's documentation contract are not filler: complete every field, or state why it does not apply without hiding missing evidence.

##### Terminology And Preservation

- Keep necessary technical terminology and exact identifiers.
- Explain project-specific concepts before using them.
- Start README prose list items with a capital letter.
- Preserve the case of identifiers, module names, class names, paths, and literals.
- Preserve intentional author viewpoints and relevant project context when reorganizing content.
- Preserve necessary technical requirements, warnings, exceptions, safeguards, and operational knowledge in their designated documentation layers. For lint documentation, place elaboration exclusively among `README.md`, `CODE_RULES.md`, `DOCUMENTATION_RULES.md`, and `OPERATIONAL_RULES.md` according to their [assigned responsibilities](#tooling-readmes), with links to its authoritative location. Do not create an additional documentation layer to reduce size.
- Remove duplicate explanations and demonstrably obsolete information only after the [editorial review](#editorial-review).

#### README Module Sections

- Preserve the existing module order.
- Present module guidance in this order: purpose, standard usage, main properties, relevant considerations, compact example, then expanded examples or Puppet Strings.
- Never introduce new fixed subheadings for every module.
- List at most eight main properties, using fewer when they suffice.
- Include one compact basic example.
- Link to a relevant scenario in `examples/`.
- Point readers to Puppet Strings for the public interface.

##### Important Considerations

- Limit `Belangrijke aandachtspunten` to module-specific conditions, risks, limitations, and non-obvious choices needed for correct use, a relevant choice, or prevention of a concrete error, unsafe situation, or unexpected change.
- Never expand this section solely because a technical change occurred.
- Update existing guidance before adding a passage when users must choose, configure, prepare, check, or perform something differently.
- Exclude complete parameter descriptions, internal execution order, test results, development history, and general administration advice without a concrete need for the described use.
- Include filenames, permissions, defaults, and other technical details only when they affect a user's choice or action.
- Assess risk severity as well as frequency when selecting warnings.
- Never remove warnings about data loss, lost administrative access, overwritten configuration, security, or incompatibility solely because they describe rare events or lengthen the text.

##### Considerations Presentation

- Make the applicable condition, consequence, and required user action clear where relevant, without imposing a sentence template.
- Write `Belangrijke aandachtspunten` as natural continuous prose, with a separate paragraph for each independent topic.
- Never use bullets, numbered lists, or tables within that section, or replace a list with one long comma- or semicolon-separated sentence.
- Omit its heading when no relevant considerations remain.

### Tooling READMEs

- Keep lint documentation in exactly four central Dutch documents: `.tools/lint/README.md` for tooling and workflow, `.tools/lint/docs/CODE_RULES.md` for general Puppet rules, `.tools/lint/docs/DOCUMENTATION_RULES.md` for Puppet code comments, Puppet Strings, and interface documentation, and `.tools/lint/docs/OPERATIONAL_RULES.md` for additional operational rules, following [language and authority](#language-and-authority).
- Do not create separate documents per check, rule, small rule group, autofix, consumer, CI platform, or test topic. Any additional central lint document requires a separate, explicit architecture change; file size alone never authorizes an automatic fifth document.
- Keep the general rules under `CODE_RULES.md`; do not introduce `STYLE_RULES.md`, since these rules also cover interfaces, parameters, dependencies, and resources. Do not use `REFERENCE.md` for lint rules; module `REFERENCE.md` files retain their Puppet Strings/API-reference purpose.
- Keep each of the four central lint documents strictly below 300 KiB (307200 bytes), guarded by a lint documentation contract test. On an overshoot, first review placement within the four assigned responsibilities. Never delete or shorten necessary content, combine independent rules to save space, or split automatically to meet the limit; any necessary fifth document requires a separate, explicitly reviewed architecture change.
- Preserve requirements, exceptions, warnings, detection limits, autofix conditions, supported usage routes, and manual review criteria during reorganization. Consolidating duplicate explanations must preserve every distinct condition and obligation.
- Keep the lint README's contents task-oriented around lint usage and tooling. Link clearly from the lint README to all three rule documents and between relevant sections in all four documents, following the [Markdown navigation requirements](#markdown). Make the cumulative applicability of the three rule documents explicit in the reading guide.
- Keep both the repository quick start and the consumer quick start before the detailed tooling reference in `README.md`. Keep the sole central check registry and maintainer explanations there, and link directly to the authoritative rule in `CODE_RULES.md`, `DOCUMENTATION_RULES.md`, or `OPERATIONAL_RULES.md` without duplicating full rules or the registry.
- Keep tool-specific test instructions in the owning tooling guide. Do not create separate test READMEs.
- General README brevity, selective-detail, and presentation guidance must not remove information or required fields from the lint guide. Apply the lint guide's documentation contract to its rule reference.

### Lint Documentation Maintenance

- Apply the lint README's [maintainer documentation contract](.tools/lint/README.md#documentatiecontract-voor-maintainers) when changing rules, checks, diagnostics, profiles, configuration, procedures, or consumer interfaces.
- Review ownership using [authority and rule placement](#authority-and-rule-placement), preserve meaning using [consolidation and placement](#consolidation-and-placement), and record the previous location, preserved meaning, new location, and reason for each substantive move in the change review. Do not create another repository document for the migration record.
- Verify incoming links, anchors, inventories, and execution contracts with the documentation tests; review explanatory accuracy and preservation of meaning manually. Verify that each rule and its subordinate headings have one authoritative destination.
- Keep unresolved policy conflicts and unexecuted required checks visible according to [isolation and evidence](#isolation-and-evidence). Do not describe the task as complete while required evidence is missing.

## Maintaining AGENTS.md

### Change Scope

- Read the complete file before a substantive change so existing rules, exceptions, and cross-references inform the edit.
- Update this file when a repository-wide convention, architecture constraint, validation command, security requirement, non-Puppet engineering standard, or operational workflow changes.
- Limit routine maintenance to the affected rules and directly impacted references.
- Restructure the whole file only when explicitly requested or when documented contradictions across sections require it.

### Maintenance Decisions

- Identify the underlying objective, required behavior or lasting knowledge, scope, and necessary exceptions before proposing a policy change. Determine its owner with [authority and rule placement](#authority-and-rule-placement), including when the task explicitly names this file.
- Find the existing authoritative rules that wholly or partly cover the required behavior before adding material.
- Distinguish missing or unclear policy from failure to follow a clear rule before deciding to edit.
- Leave this file unchanged when existing policy covers the requested behavior completely and unambiguously and no structural improvement is needed, even after repeated violations.
- When a clear rule was violated, investigate which execution or verification step failed and correct that step without adding or rewording policy that already covers the behavior.
- Update or clarify the existing authoritative rule before creating a parallel rule. Broaden its scope only when existing authority or an explicit instruction supports that policy change.
- Add a new rule only when necessary durable behavior is not already covered.

### Content And Placement

- Store only durable project-wide engineering rules that govern future development.
- Never record task, ticket, bug, feature, or prompt history, except historical context essential to understanding a technical contract or deliberate exception.
- Convert task instructions, recurring review findings, production issues, security findings, test failures, tooling changes, and agent mistakes into rules only when the required behavior generalizes beyond one task.
- Never copy a task instruction verbatim into this file merely because it requests a policy update.
- When adding new material, place feature-specific implementation detail, configuration guides, troubleshooting, implementation plans, examples, and concrete test scenarios in their [designated locations](#language-and-authority), according to [authority and rule placement](#authority-and-rule-placement), including durable code conventions. When reorganizing this file, apply the [preservation requirements](#consolidation-and-placement) to its existing content.
- Preserve exact technical names, values, and versions when required by a contract, constraint, exception, compatibility requirement, or security requirement.
- Preserve relevant technical detail, explanations, examples, and verification instructions within this file when reorganizing it. Reorganization alone must not move unique content to another file. A change of ownership under [authority and rule placement](#authority-and-rule-placement) is a substantive change to review under [conflict resolution](#conflict-resolution); preserve the information at its authoritative location and leave a targeted reference. Changing ownership never authorizes information loss.

### Consolidation And Placement

- Consolidate duplicate or weaker variants under the [single-authority rule](#authority-and-rule-placement) only when their full meaning is preserved, including any distinct conditions, exceptions, explanations, examples, and verification requirements.
- Place each rule in the narrowest relevant section, extending an existing section when its subject fits.
- Place each exception directly with the rule it modifies.
- Combine rules only when they share the same objective, scope, required behavior, and decision point without hiding independent obligations. For partial overlap, consolidate the shared part and keep additional conditions or exceptions visible.
- Apply the checklist and summary boundaries from [authority and rule placement](#authority-and-rule-placement).
- Never copy project-wide policy into code comments.

### Rule Structure

- Use a recognizable heading for each independent subject or decision domain.
- Use normative bullets when they make independent rules easier to distinguish. Keep closely related conditions and exceptions with the rule they explain.
- Separate independent decisions into bullets or subsections when that clarifies their scope. Do not split a rule merely because it contains several related sentences.
- Do not impose fixed limits on words, sentences, bullets, headings, or nesting depth. Choose the structure that keeps each rule and its conditions understandable together.
- Use prose paragraphs for coherent explanation, definitions, purpose, motivation, and necessary context; not every sentence needs to become a normative bullet.
- Use tables only for genuine matrices or fixed relationships, never to hide long prose rules.

### Rule Wording

- Write active, concrete rules with consistent terminology, explicit scope and triggers, required behavior, and necessary technical boundaries. Generalize only as far as the underlying agreement supports, retaining specific constraints and exceptions.
- Use mandatory wording for obligations and prohibitions, reserving `may`, `can`, `prefer`, and `optional` for genuine discretion.
- State how compliance is verified when this is not apparent from the rule.
- Prioritize completeness, correctness, readability, scope, and traceability over reducing words, lines, bullets, or headings. Improve organization and wording without compressing information, following [content and placement](#content-and-placement) when reorganizing existing content or changing its owner.
- Never compress independent requirements into a dense paragraph to reduce the document's length.

### Conflict Resolution

- Preserve the strongest applicable security rule during consolidation.
- Correct unclear, outdated, incorrect, or contradictory rules only when repository evidence or an explicit project decision establishes the intended requirement. A difference between code and documentation does not by itself show which one is wrong.
- Record substantive policy changes, contradictions, and the reasons for corrected or removed wording in the change review. Identify the affected passages, their previous and new meaning, and the evidence or explicit decision supporting the change.
- When evidence cannot resolve a requirement or contradiction, keep the affected information identifiable, mark the conflict as unresolved, and state which decision is missing in the change review. Continue with uncontested work, but do not present the result as conflict-free or automatically choose the strictest, broadest, or apparently safest wording.

### Final Review

- Review the complete diff against the pre-change version. Verify that every original obligation, prohibition, preference, condition, exception, technical contract, compatibility requirement, security safeguard, explanation, example, and verification instruction remains in this file after reorganization or has an explicitly justified correction. For a substantive change of ownership, verify preservation and a working reference under [content and placement](#content-and-placement).
- Verify that generalization and restructuring neither make required behavior optional nor make optional behavior mandatory.
- Manually verify that every changed rule is necessary, reusable, scannable, non-duplicative, unambiguous, and consistent with this document, its terminology, and its references.
- Run automated checks for literal duplicate rules and local link targets, using repository tooling when available or isolated temporary checks otherwise. Review meaning, structure, and readability manually rather than enforcing numerical prose limits.
- Record the existing policy, reason for change, and preserved obligations and exceptions for each substantive rule change in the change review outside this file.
- Check the reverse direction as well: every new obligation, exception, or technical claim must be supported by the previous policy, an established project agreement, or an explicit instruction. Make unresolved conflicts visible before completion.

## Completion Checklist

### Workflow And Validation

- Verify [preparation and scope](#working-with-the-existing-codebase).
- Verify [Puppet code authority](#puppet-code-authority) and [rule placement](#authority-and-rule-placement).
- Verify applicable [design and implementation review](#design-and-implementation), [shell review and validation](#shell-scripts), and [monitoring review and validation](#monitoring-checks).
- Verify [documentation responsibilities and review](#documentation).
- Verify [impact review](#impact-review).
- Verify the applicable [security reviews](#security-and-privacy).
- Verify [development tooling](#development-tooling) and the [required checks and evidence](#validation-and-testing).
- Verify [policy maintenance and final review](#maintaining-agentsmd) when changing this file.

### External Sharing

- Verify [secrets protection](#secrets-and-authentication-material): no secrets, credentials, certificates, or key material were shared externally.
- Verify [minimum disclosure](#minimum-disclosure) and [anonymization](#anonymization-and-synthetic-data): external material was minimal and synthetic or sufficiently anonymized.
- Verify [outbound review](#outbound-review): hidden data in logs, screenshots, headers, URLs, filenames, and metadata was checked.
- Verify the [disclosure restriction](#unsafe-disclosure): no sharing occurred when safe sanitization could not be demonstrated.

### Delivery

- Identify changed paths in the final response.
- Explain any supporting refactor in the final response.
- Summarize relevant security and systemd decisions in the final response.
- Explain README and `AGENTS.md` decisions in the final response.
- Report validation results and unresolved assumptions or follow-up in the final response.
