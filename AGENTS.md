# AGENTS.md

## Scope And Authority

This file governs project-wide agent workflow, task scope, collaboration, and general security responsibilities.

- Agents must read this file and the root `README.md` before making changes.
- Local agent instructions may refine workflow within this baseline, but must not weaken or duplicate project-wide policy.

### Puppet Code Authority

- Follow [the project puppet-lint configuration](.puppet-lint.rc), [project plugins](.tools/lint/lib/puppet-lint/plugins/), and [documented review criteria](.tools/lint/README.md) as the authoritative Puppet code conventions.
- Root and local agent instructions must not contain separate, additional, or different Puppet code standards.
- Changes to Puppet conventions must include their tests and all affected first-party code in the same change.

## Project Constraints

### Supported Platforms

The first-party Puppet modules target Debian and Ubuntu servers. The complete module set primarily targets `amd64`; individual platform paths may support a narrower or broader set of releases or architectures.

- Support claims for operating systems, releases, architectures, Puppet, or OpenVox must match the implementation, relevant `metadata.json`, available validation, and Dutch README in the same change.

### First-Party Code And Dependencies

- Treat all module directories listed in the README as first-party except the vendored Git submodules `concat`, `debconf`, `reboot`, `stdlib`, and `timezone`.
- Keep changes within first-party code and repository-owned documentation or tooling unless the task explicitly requires a vendored dependency change.
- Never use vendored submodules as project style examples.

### Shared Check Executables

- When adding or changing monitoring checks, deploy one shared executable per check implementation on each managed host. Reuse it for every target registration; never generate executable copies or wrappers merely to embed different target values.
- Pass target identity and settings that differ between registrations as runtime arguments or through an existing configuration interface. Limit executable templating to values shared by all registrations on the host.
- Manage the shared executable independently of individual registrations so removing or disabling one target preserves checks for other targets.
- Validate with at least two targets that registrations invoke the same executable with their own settings and that retiring one target preserves the shared executable and other registrations.

## Working With The Existing Codebase

### Preparation

- Run `git status --short` before editing.
- Inspect the relevant module files and README sections before changing behavior or structure.
- Inspect the touched module's `metadata.json` when it exists.
- Inspect related manifests, templates, static files, examples, and systemd units, including generated units.
- Check existing integration with `basic_settings`, monitoring, systemd, security audit, `php8::fpm`, `nginx`, and other local modules relevant to the change.
- Check existing ownership, mode, `require`, `notify`, and `subscribe` patterns before adding resources.

### Scope And User Changes

- Preserve unrelated user changes.
- Treat a user's corrective edit as the current preferred pattern.
- Never restore an earlier agent approach unless the user explicitly requests it.
- Keep changes scoped to the requested task and affected area.
- Never perform unrelated refactors.
- Keep a necessary supporting refactor local to the affected area.
- Explain any supporting refactor in the final response.

### Reuse And Shared Abstractions

- When work reveals duplicated behavior in the affected area, extract a shared abstraction and migrate the affected callers in the same change. Use reusable defined types for repeated Puppet resource orchestration, with caller-specific settings passed as parameters.
- Inspect existing abstractions before adding a new one, and validate each migrated caller's behavior and dependencies. Preserve caller-specific security and lifecycle requirements.

### Git Commits

- AI agents must never create, amend, or rewrite Git commits through Git commands, APIs, or other tools.
- Leave validated changes in the working tree for human review and commit.

### Impact Review

- Review effects on repository conventions, Puppet abstractions, and reusable wrappers.
- Review effects on monitoring, logging, alerting, audit rules, and operational diagnostics.
- Review effects on documentation, examples, supported platforms, compatibility, and operational commands.

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

### External Disclosure

External disclosure is every transfer outside an organization-controlled or explicitly approved environment. It includes search queries, AI prompts, pasted text, uploads, screenshots, code snippets, forums, vendor portals, external issue trackers, code-sharing services, chat, email, and browser tools.

- Approval to use an external service must not be treated as authorization for every data type.
- Apply data classification, least disclosure, and minimum-necessary rules to every approved external service.

### Secrets And Authentication Material

- Never disclose a password, passphrase, API key, access token, refresh token, session identifier, cookie, backup code, or credential-bearing connection string externally, including in search input.
- Never disclose a private key, certificate material, CSR, certificate chain, keystore, truststore, secret file, token file, kubeconfig, or `.env` content externally.
- Remove secrets completely before external use.
- Never use partial masking, prefixes, suffixes, fingerprints, hashes, or encoded variants when they can identify or validate the original value.
- Never put real secrets or credentials in code, comments, documentation, examples, tests, fixtures, logs, commits, tickets, prompts, or troubleshooting material.
- Use clearly synthetic authentication values in every example and reproduction.

### Operational And Confidential Data

- Never disclose raw operational, personal, medical, customer, employee, organization, or commercially confidential data outside the approved environment.
- Treat logs, stack traces, HL7, FHIR, EDI, database records, exports, configuration files, packet captures, screenshots, source fragments, headers, and query parameters as potentially sensitive.
- Treat hostnames, IP addresses, internal URLs, filenames, usernames, tenant identifiers, project identifiers, and metadata as potentially sensitive.

### Anonymization And Synthetic Data

- Anonymize or replace all data with synthetic values before it leaves the approved environment.
- Replace real names, identifiers, addresses, numbers, timestamps, domains, hostnames, and environment-specific values.
- Preserve only relationships needed to reproduce the issue.
- Use consistent synthetic placeholders when correlation matters, without reusing production values.
- Evaluate combinations of remaining fields for re-identification risk.
- Never call partially masked or pseudonymized data anonymous when re-identification remains reasonably possible.

### Minimum Disclosure

- Reduce an external question to the minimum technical facts required to understand the problem.
- Prefer a generic description or minimal reproducible example containing only synthetic data.
- Share only the smallest sanitized fragment required to solve the problem.
- Never upload a complete repository, database dump, configuration set, message archive, or log collection when a smaller synthetic reproduction is sufficient.

### Outbound Review

- Inspect the complete outbound content before sharing, including logs, stack traces, shell history, command output, request and response headers, URLs, query strings, comments, filenames, metadata, screenshots, diffs, archives, and copied surrounding context.
- Never disclose information when safe sanitization cannot be demonstrated with sufficient confidence.
- Use approved internal documentation, tooling, colleagues, or secure support channels when external sharing is unsafe.

### Disclosure Incidents

- Stop further sharing immediately when a secret or confidential value is disclosed accidentally.
- Never repeat the exposed value in follow-up communication.
- Treat exposed credentials and key material as compromised.
- Revoke or rotate compromised credentials and key material where applicable.
- Follow the applicable security-incident procedure.

## Validation And Testing

### Development Environment

- Use the latest stable Ruby and Bundler for development and CI.
- Never pin Ruby or Bundler versions in setup commands or runtime configuration.
- Use the root Gemfile, lockfile, standard CLI, and regression tests through the [documented bundle setup](.tools/lint/README.md#installatie).

### Tool Test Scope And Structure

- Keep tests of repository tools under `.tools/test/<tool-name>/`, separate from each tool's implementation directory; use `.tools/test/lint/` for the linter.
- Place tests for each new tool in its own subdirectory under `.tools/test/`.
- Classify tests by the behavior their assertions verify, not by filenames, input formats, or implementation technologies.
- Keep general module, catalog, repository syntax, template, script, and monitoring behavior tests outside `.tools/`.
- Use fixtures and supporting functionality in tool tests only when they help verify a tool contract.
- Keep tool-specific helpers and fixtures with that tool's tests.
- Introduce shared test helpers only when multiple tools actually need them.
- Never execute unrelated module or repository tests indirectly through tool tests, helpers, hooks, or task dependencies.

### Tool Test Tasks

- Keep `test` and the default Rake task responsible for recursive discovery across all tool test subdirectories.
- Keep `test:lint` limited to the linter tests under `.tools/test/lint/`.

### Test Structure Maintenance

- Update test discovery, path resolution, task definitions, CI, and affected documentation together when changing the test structure.
- Remove superseded test directories, duplicate files, unused support data, obsolete tasks, and stale references after migration.
- Preserve relevant regression coverage and explicitly report any intentionally removed tests.
- Verify that the expected tests are discovered and executed; a successful command with no applicable tests is not sufficient validation.

### Required Checks

- Run the full lint scan with `bundle exec puppet-lint .` for every completed change.
- Run all tool tests with `bundle exec rake test` for every completed change.
- Validate each changed Puppet manifest separately with `bundle exec puppet parser validate` followed by its path.
- Perform the additional validation relevant to the change, as documented in the [validation guide](.tools/lint/README.md#code-controleren).
- Inspect the final change scope with `git diff --name-only`.
- Require `git diff --check` to pass before completion.

### Isolation And Evidence

- Keep synthetic tests and validation isolated from production credentials, production connections, and managed hosts.
- Never treat vendored submodule tooling as validation of first-party modules.
- Never treat passing lint as a replacement for functional validation or review.
- Verify that the central lint solution and its required review evidence cover changed public interfaces.
- Record applicable review outcomes and functional evidence in the change review.
- Report unavailable tooling, failed or unexecuted checks, fallback checks, and remaining uncertainty.
- Never describe incomplete validation as complete.

## Documentation

### Language And Authority

- Write technical documentation in English, including changelog entries and this file, except for the READMEs specified below.
- Keep the root README, `.tools/lint/README.md`, and `.tools/test/README.md` in Dutch unless the user explicitly requests another language.
- Keep one authoritative location for each technical fact.
- Use concise summaries with pointers when a fact must appear in more than one layer.
- Place information according to the responsibilities below.

| Location | Responsibility |
| --- | --- |
| `AGENTS.md` | Durable project-wide workflow, general review policy, and engineering responsibilities. |
| Root `README.md` | Central user guide for module use and operational decisions. |
| `.tools/lint/README.md` | Validation tooling guide and separate authoritative reference for code conventions and Puppet review criteria. |
| `.tools/test/README.md` | Running and extending the central tool tests. |
| Puppet Strings | Concrete public interfaces, complete parameter descriptions, defaults, and fallback chains. |
| Scripts and templates | Local, non-obvious technical reasons and constraints, internal behavior, and per-check output contracts. |
| `examples/` | Expanded configuration scenarios. |
| Tests | Functional behavior, regressions, edge cases, failure scenarios, and automatically verifiable contracts. |
| Project or feature documentation | System structure, data flows, component relationships, configuration reference, operational procedures, troubleshooting, and scoped implementation or migration plans. |
| ADRs | Architectural decisions, alternatives, trade-offs, and their rationale. |

### README Scope

- Adapt README content to the document's purpose and audience rather than imposing the same outline on module overviews and tooling guides.
- Add detail to the root README only when users need it before use, it changes a security or compatibility decision, or the basic example requires it.
- Never turn the root README into an exhaustive parameter or implementation reference.
- Keep the lint README focused on using validation tooling, with a clearly separated reference for the conventions and review criteria it owns.
- Use the lint README as the style and organization reference for `.tools/test/README.md`: explain purpose and prerequisites before commands, then cover troubleshooting and adding tests. Adapt sections to tool testing and link to the lint guide for installation and lint rules.
- Keep developer-only implementation detail out of the root user guide.
- Include developer implementation detail in the tooling guide only when it supports a relevant task or its authoritative reference.

### README Navigation And Prerequisites

- Keep required prerequisites and security- or compatibility-critical conditions beside the action they affect.
- Keep placeholder hostnames, replacement values, Hiera guidance, and `Sensitive(...)` handling near the quick start.
- Maintain a `## Inhoudsopgave` near the top with main-section links and relevant nested module or tooling-task links; never label it `Legenda`.
- Maintain a bottom-level list of expanded examples.

### README Module Sections

- Present module guidance in this order: purpose, standard usage, main properties, risks and limitations, compact example, then expanded examples or Puppet Strings.
- List at most eight main properties, using fewer when they suffice.
- State pre-use conditions, operational risks, and limitations.
- Include one compact basic example.
- Link to a relevant scenario in `examples/`.
- Point readers to Puppet Strings for the public interface.
- Move expanded variants and authoritative parameter detail to their designated locations when a section grows.

### README Style

#### Tone And Audience

- Write as an experienced colleague explaining the task to a technically competent reader who is new to this project.
- Use representative root README prose as a reference for a direct, practical, infrastructure-focused tone, rather than as a template or proof of quality.
- Never reproduce awkward or over-compressed wording merely for consistency.
- Write ordinary, accessible Dutch around exact code identifiers.
- Prefer familiar Dutch words over unnecessary English or abstract tooling terminology.
- Address the reader directly.
- Preserve natural connections between sentences without generic boilerplate, stock transitions, uncommon synonyms, promotional language, or forced informality.

#### Organization And Explanation

- Organize usage guidance around the reader's task rather than implementation order or review requirements.
- Give each paragraph one coherent topic, separating independent instructions instead of compressing them to shorten the document.
- Describe concrete actions, conditions, and consequences.
- Explain non-obvious choices when the explanation helps the reader act correctly.
- Use headings, lists, and tables when they help navigation or comparison.
- Never add content to fill a template or make sections look uniform.

#### Terminology And Preservation

- Keep necessary technical terminology and exact identifiers.
- Explain project-specific concepts before using them.
- Start README prose list items with a capital letter.
- Preserve the case of identifiers, module names, class names, paths, and literals.
- Preserve intentional author viewpoints, warnings, and project context when reorganizing content.
- Preserve technical requirements, exceptions, safeguards, and operational knowledge during editorial changes.

### Markdown

- Keep each prose paragraph or list item on one physical line without hard wrapping, except where Markdown syntax, a table, or a code block requires line breaks.
- Separate distinct topics with normal paragraph breaks.
- Keep documentation professional, concrete, and focused on operational impact and risk.

### Editorial Review

- Review the complete affected reading path, including surrounding headings and paragraphs.
- Check whether a new reader can identify prerequisites, the next action, and the expected outcome without reconstructing missing context.
- Check that commands, paths, options, and references match the accompanying examples and current implementation.
- Review explanatory passages as continuous prose, aloud if useful, to correct awkward phrasing and unexplained topic changes without changing technical meaning.
- Compare changed prose in `.tools/lint/README.md` and `.tools/test/README.md` with representative root README passages against the [README style guidance](#readme-style).
- Include a short representative passage in the review for owner feedback.
- Use an owner-accepted passage as a concrete style reference.

### Limits Of Automated Editorial Checks

- Never treat automated technical checks as proof that an explanation is clear, pleasant to read, or useful for the reader's task.
- Never use AI-detection scores or word blacklists to assess prose quality.
- Never judge explanatory prose by sentence quotas or fixed paragraph lengths; the [policy structure limits](#rule-structure) apply specifically to `AGENTS.md` rules.

## Completion Checklist

### Workflow And Validation

- Verify [preparation and scope](#working-with-the-existing-codebase), including preservation of user changes.
- Verify [Puppet code authority](#puppet-code-authority).
- Verify [documentation responsibilities](#documentation), including [editorial review](#editorial-review).
- Verify [impact review](#impact-review).
- Verify the applicable [security reviews](#security-and-privacy).
- Verify the [required checks and evidence](#validation-and-testing).

### External Sharing

- Verify [secrets protection](#secrets-and-authentication-material): no secrets, credentials, certificates, or key material were shared externally.
- Verify [minimum disclosure](#minimum-disclosure) and [anonymization](#anonymization-and-synthetic-data): external material was minimal and synthetic or sufficiently anonymized.
- Verify [outbound review](#outbound-review): hidden data in logs, screenshots, headers, URLs, filenames, and metadata was checked.
- Verify the [disclosure restriction](#outbound-review): no sharing occurred when safe sanitization could not be demonstrated.

### Delivery

- Include changed paths, relevant security and systemd decisions, README and `AGENTS.md` decisions, validation results, and unresolved assumptions or follow-up in the final response.

## Maintaining AGENTS.md

### Content And Placement

- Store only durable project-wide engineering rules that govern future development.
- Never record task, ticket, bug, feature, or prompt history, except historical context essential to understanding a technical contract or deliberate exception.
- Keep feature-specific implementation detail outside this file unless it is a lasting project-wide constraint.
- Move configuration guides, troubleshooting, implementation plans, examples, and concrete test scenarios to their [designated locations](#language-and-authority).
- Keep exact technical names, values, and versions only when required by a contract, constraint, exception, compatibility requirement, or security requirement.

### Maintenance Decisions

- Update this file when a repository-wide convention, architecture constraint, validation command, security requirement, non-Puppet engineering standard, or operational workflow changes.
- Leave this file unchanged when existing policy already covers the requested behavior completely and unambiguously.
- Convert recurring review findings, production issues, security findings, test failures, tooling changes, and agent mistakes into rules only when they generalize beyond one task.
- Identify the underlying objective, required behavior, scope, and necessary exceptions before adding a rule.
- Check whether an existing rule covers the behavior wholly or partly.
- Update, broaden, or clarify the existing authoritative rule before creating a new one.
- Add a new rule only when necessary durable behavior is not already covered.

### Consolidation And Placement

- Keep one authoritative location for every rule, removing duplicate or weaker variants.
- Place each rule in the narrowest relevant section, extending an existing section when its subject fits.
- Place each exception directly with the rule it modifies.
- Combine rules only when they share the same objective, scope, and decision point without hiding independent obligations.
- Keep checklist entries as concise verification references rather than copies of the full policy.
- Never copy project-wide policy into code comments.

### Rule Structure

- Use a recognizable heading for each independent subject or decision domain.
- Use normative bullets with one primary requirement, prohibition, or decision, and only directly related conditions or exceptions.
- Split independent obligations, prohibitions, exceptions, and verification steps into separate bullets or subsections.
- Limit each normative bullet or paragraph to three short sentences.
- Limit each heading to eight independent normative bullets before introducing subject-specific subheadings.
- Use at most one nested bullet level, only for conditions or exceptions to the parent rule.
- Reserve short prose paragraphs for definitions, purpose, or necessary context.
- Use tables only for genuine matrices or fixed relationships, never to hide long prose rules.

### Rule Wording

- Write short, active rules with consistent terminology and concrete triggers, required behavior, and necessary technical boundaries.
- Use mandatory wording for obligations and prohibitions, reserving `may`, `can`, `prefer`, and `optional` for genuine discretion.
- State how compliance is verified when this is not apparent from the rule.
- Prioritize scanability, scope, and traceability over reducing the number of lines, bullets, or headings.

### Conflict Resolution

- Preserve the strongest applicable security rule during consolidation.
- Correct unclear, outdated, incorrect, or contradictory rules when repository evidence determines the required behavior.
- Report contradictions and the reasons for corrected or removed rules in the change review.
- Preserve the safer existing behavior when repository evidence cannot resolve a requirement or contradiction.
- Report unresolved requirements and contradictions for review.

### Final Review

- Compare the complete revision with the original to verify that obligations, prohibitions, exceptions, technical contracts, compatibility, and security safeguards are preserved or explicitly relocated.
- Verify that generalization and restructuring neither make required behavior optional nor make optional behavior mandatory.
- Preserve technically necessary specificity when its removal could change behavior or scope.
- Verify that every changed rule is necessary, reusable, scannable, non-duplicative, unambiguous, and consistent with this document, its terminology, and its references.
