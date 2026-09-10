# AGENTS.md

## Scope And Authority

- This file governs agent workflow, task scope, collaboration and general security responsibilities in this repository.
- Agents must read this file and the root `README.md` before making changes.
- The root `AGENTS.md` is the project-wide workflow baseline. Local agent instructions may refine workflow within this scope but must not introduce additional or different Puppet code standards.
- The root `README.md` is the central Dutch user guide.
- Puppet Strings document the concrete public interfaces; the lint setup governs code conventions.
- Expanded configuration scenarios belong in `examples/`.

## Puppet Code Authority

For Puppet code conventions, [the project puppet-lint configuration](.puppet-lint.rc), [project plugins](.tools/lint/lib/puppet-lint/plugins/) and [documented review criteria](.tools/lint/README.md) are authoritative. This file contains no separate Puppet code rules, and local agent instructions must not introduce any. Follow the documented bundle setup, run `bundle exec puppet-lint .` and `bundle exec rake spec`, and validate changed manifests separately with `bundle exec puppet parser validate`. Change conventions together with their tests and all affected first-party code. Passing lint does not replace functional validation or review.

## Project Constraints

### Supported Scope

- This repository contains first-party Puppet modules for Debian and Ubuntu servers.
- The complete module set primarily targets `amd64`. Individual platform paths may support a narrower or broader set of releases or architectures.
- Support claims for operating systems, releases, architectures, Puppet, or OpenVox must match the implementation, relevant `metadata.json`, available validation, and the Dutch README in the same change.
- Treat all module directories listed in the README as first-party except the vendored Git submodules `concat`, `debconf`, `reboot`, `stdlib`, and `timezone`.
- Changes must remain inside first-party modules unless the task explicitly requires a vendored dependency change.
- Vendored submodules must not be used as project style examples.

## Working With The Existing Codebase

### Preparation

- Check `git status --short` before editing and preserve unrelated user changes.
- Read the root README and the relevant module files before changing behavior or structure.
- Inspect the touched module's `metadata.json` when it exists.
- Inspect related manifests, templates, static files, README sections, examples, and systemd units.
- Check existing integration with `basic_settings`, monitoring, systemd, security audit, `php8::fpm`, `nginx`, and other local modules relevant to the change.
- Check existing ownership, mode, `require`, `notify`, and `subscribe` patterns before adding resources.
- Treat a user's corrective edit as the current preferred pattern. Do not restore an earlier agent approach unless the user explicitly requests it.

### Scope Control

- Keep changes scoped to the requested task and affected module.
- Do not perform unrelated refactors.
- A necessary supporting refactor must remain local and be explained in the final response.

### Git Commits

- AI agents must not create, amend, or rewrite Git commits, whether through Git commands, APIs, or other tools; committing remains a human-only step.
- Leave validated changes in the working tree for human review and commit.

### Impact Review

- Review effects on repository conventions, Puppet abstractions, and reusable wrappers.
- Review effects on systemd ordering, targets, hardening, restart behavior, and failure handling.
- Review effects on privileges, permissions, users, groups, capabilities, sudo, and secrets.
- Review effects on networking, ports, sockets, firewalls, TLS, and service dependencies.
- Review effects on monitoring, logging, alerting, audit rules, and operational diagnostics.
- Review effects on documentation, examples, supported platforms, compatibility, and operational commands.

## Documentation

### Ownership And Language

- Write technical documentation in English, including changelog entries and this file, except for the READMEs specified below.
- Keep the root README and `.tools/lint/README.md` in Dutch unless the user explicitly requests another language.
- Keep developer workflow and review policy in `AGENTS.md`.
- Keep one authoritative location for each technical fact.
- When a fact must appear in more than one layer, keep one complete source and use concise summaries with pointers elsewhere.

### README Content

- Apply README content guidance to the purpose and audience of the document; do not impose the same outline on module overviews and tooling guides.
- Keep the root README focused on using the modules and making operational decisions, without turning it into an exhaustive parameter or implementation reference.
- Keep `.tools/lint/README.md` focused on using the validation tooling, with a clearly separated reference for the code conventions and review criteria it owns.
- Do not duplicate complete parameter lists, fallback chains, internal script behavior, or per-check output contracts; keep their full descriptions in Puppet Strings or the relevant script or template.
- Keep developer-only implementation detail out of the root user guide; include it in the tooling guide only when it supports a relevant task or its authoritative reference.
- Keep required prerequisites and security- or compatibility-critical conditions beside the action they affect.
- Refer concisely to `AGENTS.md` for agent workflow rather than repeating that policy in a README.
- Keep placeholder hostnames, replacement values, Hiera guidance, and `Sensitive(...)` handling near the quick start.
- Maintain a `## Inhoudsopgave` near the top with main-section links and nested links for modules or tooling tasks, as appropriate.
- Do not label the table of contents `Legenda`.
- Add detail to the root README only when users need it before use, it changes a security or compatibility decision, or the basic example requires it.

### README Module Sections

- Each main module section must explain its purpose before internal detail.
- Apply progressive disclosure to module sections: purpose, standard usage, main properties, risks and limitations, compact example, then expanded examples or Puppet Strings.
- Select no more than five to eight important properties as an upper limit, not a quota to fill.
- State pre-use conditions, operational risks, and limitations.
- Include one compact basic example.
- Link to a relevant scenario in `examples/` and point to Puppet Strings.
- Move expanded variants and authoritative parameter detail to their proper layer when a section grows.
- Maintain a bottom-level list of expanded examples.

### README Style

- Write as an experienced colleague explaining the task to a technically competent reader who is new to this project.
- Use representative root `README.md` prose as a reference for a direct, practical, infrastructure-focused tone, not as a template or automatic proof of quality; do not reproduce awkward or over-compressed wording merely for consistency.
- Write ordinary, accessible Dutch around exact code identifiers; prefer familiar Dutch words over unnecessary English or abstract tooling terminology.
- Address the reader directly.
- Organize usage guidance around the reader's task rather than the order of implementation details or review requirements.
- Give each paragraph one coherent topic; do not compress independent instructions into dense prose merely to avoid lists or shorten the document.
- Describe concrete actions, conditions and consequences; explain non-obvious choices where the explanation helps the reader act correctly.
- Keep necessary technical terminology and exact identifiers; explain project-specific concepts before using them instead of replacing precise terms with vague alternatives.
- Use headings, lists and tables when they help navigation or comparison; do not add content to fill a template or make sections look uniform.
- Preserve intentional author viewpoints, warnings, and project context when reorganizing content.
- Preserve natural connections between sentences without generic boilerplate, stock transitions, uncommon synonyms, promotional language or forced informality.
- Start README prose list items with a capital letter.
- Preserve the case of identifiers, module names, class names, paths, and literals.
- Preserve technical requirements, exceptions, safeguards and operational knowledge during editorial changes; improve their placement and explanation rather than weakening or removing them.

### Markdown

- Do not hard-wrap prose in Markdown files.
- Keep each prose paragraph or list item on one physical line unless Markdown syntax, a table, or a code block requires line breaks.
- The no-hard-wrap rule governs physical line breaks, not paragraph length; separate distinct topics with normal paragraph breaks.
- Keep documentation professional, concrete, and focused on operational impact and risk.

### Editorial Review

- Review the complete affected reading path, including surrounding headings and paragraphs, rather than only the changed lines.
- Check whether a new reader can identify the prerequisites, next action and expected outcome without reconstructing missing context.
- Check that commands, paths, options and references in the prose match the accompanying examples and current implementation.
- Read explanatory passages aloud or review them as continuous prose; rewrite awkward phrasing and unexplained topic changes without changing technical meaning.
- Compare changed lint-README prose with representative root README passages, assessing both against the README Style guidance.
- Include a short representative passage in the review for owner feedback; use an owner-accepted passage as a concrete style reference.
- Treat automated checks as technical validation, not proof that the explanation is clear or pleasant to read; assess whether the text supports the reader's task without AI-detection scores, word blacklists, sentence quotas or fixed paragraph lengths.

## Validation And Testing

### Test Model

- Use the latest stable Ruby and Bundler for development and CI; do not pin their versions in setup commands or runtime configuration.
- Use the root Gemfile, lockfile, standard CLI and regression tests documented in [.tools/lint/README.md](.tools/lint/README.md).
- Run the full lint scan, lint-solution tests and additional validation for every completed change.
- Record the applicable review outcomes and functional evidence in the change review.
- Keep synthetic tests and validation isolated from production credentials, production connections and managed hosts.
- Do not treat vendored submodule tooling as validation of first-party modules.
- Report unavailable tooling, failed or unexecuted checks and remaining uncertainty; do not describe incomplete validation as complete.

### Change Discovery

```sh
git status --short
git diff --name-only
git diff --check
```

## Security And Privacy

### Security Baseline

- Treat security as a design requirement from the start of every change.
- Preserve correct existing hardening.
- Improve hardening only when application and operational behavior remain correct.
- Preserve the strongest applicable rule when consolidating security guidance.
- Do not silently remove an unclear, outdated, or incorrect security rule; replace it with the corrected rule and report the reason.
- When a security requirement cannot be resolved from repository evidence, preserve the safer behavior and report the uncertainty for review.

### External Disclosure

- Treat every transfer outside an organization-controlled or explicitly approved environment as external disclosure.
- External disclosure includes search queries, AI prompts, pasted text, uploads, screenshots, code snippets, forums, vendor portals, external issue trackers, code-sharing services, chat, email, and browser tools.
- Approval to use an external service does not authorize every data type.
- Data classification, least disclosure, and minimum-necessary rules apply to every approved external service.
- Reduce an external question to the minimum technical facts required to understand the problem.
- Prefer a generic description or minimal reproducible example containing only synthetic data.

### Secrets And Authentication Material

- Never disclose a password, passphrase, API key, access token, refresh token, session identifier, cookie, backup code, or credential-bearing connection string externally.
- Never disclose a private key, certificate material, CSR, certificate chain, keystore, truststore, secret file, token file, kubeconfig, or `.env` content externally.
- Remove secrets completely before external use.
- Partial masking, prefixes, suffixes, fingerprints, hashes, and encoded variants are not acceptable when they can identify or validate the original value.
- Never put real secrets or credentials in code, comments, documentation, examples, tests, fixtures, logs, commits, tickets, prompts, or troubleshooting material.
- Use clearly synthetic authentication values in every example and reproduction.

### Operational And Confidential Data

- Do not disclose raw operational, personal, medical, customer, employee, organization, or commercially confidential data outside the approved environment.
- Treat logs, stack traces, HL7, FHIR, EDI, database records, exports, configuration files, packet captures, screenshots, source fragments, headers, and query parameters as potentially sensitive.
- Treat hostnames, IP addresses, internal URLs, filenames, usernames, tenant identifiers, project identifiers, and metadata as potentially sensitive.
- Do not upload a complete repository, database dump, configuration set, message archive, or log collection when a smaller synthetic reproduction is sufficient.

### Anonymization And Synthetic Data

- Anonymize or replace all data with synthetic values before it leaves the approved environment.
- Replace real names, identifiers, addresses, numbers, timestamps, domains, hostnames, and environment-specific values.
- Preserve only relationships needed to reproduce the issue.
- Use consistent synthetic placeholders when correlation matters, but never reuse production values.
- Evaluate combinations of remaining fields for re-identification risk.
- Do not call partially masked or pseudonymized data anonymous when re-identification remains reasonably possible.

### Outbound Review

- Inspect the complete outbound content before sharing it.
- Review logs, stack traces, shell history, command output, request and response headers, URLs, query strings, comments, filenames, metadata, screenshots, diffs, archives, and copied surrounding context.
- Share only the smallest sanitized fragment required to solve the problem.
- Do not disclose information when safe sanitization cannot be demonstrated with sufficient confidence.
- Use approved internal documentation, tooling, colleagues, or secure support channels when external sharing is unsafe.

### Disclosure Incidents

- Stop further sharing immediately when a secret or confidential value is disclosed accidentally.
- Do not repeat the exposed value in follow-up communication.
- Treat exposed credentials and key material as compromised.
- Revoke or rotate compromised credentials and key material where applicable.
- Follow the applicable security-incident procedure.

### Privilege And Isolation Review

- Check whether changed code can run with less privilege or under a more constrained service identity.
- Check whether systemd isolation can be tightened without breaking behavior.
- Identify new trust boundaries, sudo paths, writable paths, exposed ports, capabilities, or privilege assumptions.
- Prefer the simpler design when it reduces attack surface without violating requirements.

## Completion Checklist

### Context And Scope

- Confirm that relevant README sections, metadata, manifests, templates, files, examples, and generated units were inspected.
- Confirm that changes remain scoped to first-party modules unless dependency work was explicitly requested.
- Confirm that unrelated user changes were preserved.

### Code And Documentation

- Confirm that centralized comment, implementation, and documentation rules were followed.
- Complete the [Editorial Review](#editorial-review) and confirm that affected documentation is accurate, non-duplicative, and unambiguous.
- Confirm that the central lint solution and its required review evidence cover changed public interfaces.
- Confirm that required user-facing README changes are in Dutch.

### Security And Operations

- Confirm that permissions, secrets, systemd, monitoring, logging, audit, network exposure, and operational impact were reviewed for the touched area.
- Confirm that no secret, credential, certificate, or key material was shared externally.
- Confirm that externally used data was minimal and synthetic or sufficiently anonymized.
- Confirm that logs, screenshots, headers, URLs, filenames, and metadata were reviewed before external use.
- Confirm that no external disclosure occurred when safe sanitization could not be demonstrated.

### Validation And Reporting

- Run relevant validation commands and report unavailable tooling plus fallback checks.
- Require `git diff --check` to pass.
- In the final response, list changed files or paths, relevant security and systemd review decisions, README and `AGENTS.md` documentation decisions, validation performed, and unresolved assumptions or required follow-up.

## Maintaining AGENTS.md

### Content And Placement

- Store only durable project-wide engineering rules; do not record task, ticket, bug, feature, or prompt history.
- Identify the underlying objective, required behavior, scope, and necessary exceptions before adding a rule.
- Keep feature-specific implementation detail in code, tests, documentation, specifications, or ADRs unless it is a lasting project-wide constraint.
- Keep exact technical detail only when it is a required contract, constraint, exception, compatibility requirement, or security requirement.
- Keep one authoritative location for every rule.
- Place each rule in the narrowest relevant section.
- Place each exception directly with the rule it modifies.
- Leave this file unchanged when existing policy already covers the requested behavior completely and unambiguously.

### Maintenance Triggers

- Update this file when a repository-wide convention, architecture constraint, validation command, security requirement, non-Puppet engineering standard, or operational workflow changes.
- Convert recurring review findings, production issues, security findings, test failures, tooling changes, and repeated agent mistakes into durable rules only when they generalize beyond one task.
- Record the reusable behavior and constraint, not the event or prompt that revealed it.

### Editing Rules

- Check whether an existing rule covers the behavior wholly or partly before adding content.
- Update, broaden, or clarify the authoritative rule before creating a new one.
- Add a new rule only for necessary durable behavior that is not already covered.
- Remove duplicate and weaker variants when consolidating rules.
- Use one primary requirement, prohibition, or decision per bullet.
- Split independent topics into separate bullets or subsections.
- Do not compress several requirements into dense prose to reduce line or bullet count.
- Do not let a lower-level instruction weaken or duplicate project-wide workflow policy or introduce a Puppet code rule.

### Final Review

- Verify that Puppet code rules have not returned to root or local agent instructions; keep their authority exclusively in the central lint solution.
- Verify that every change to this file is necessary, reusable, scannable, non-duplicative, unambiguous, and consistent with the rest of the document.
- Verify that no obligation, prohibition, exception, compatibility contract, or security safeguard was weakened or lost.
- Resolve contradictions when repository evidence determines the correct rule.
- Preserve the safer existing behavior and report the ambiguity when a contradiction cannot be resolved from repository evidence.
