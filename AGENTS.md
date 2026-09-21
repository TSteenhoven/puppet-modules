# AGENTS.md

## Scope And Authority

This file governs project-wide development workflow, engineering responsibilities, and security. Its content and structure follow [Maintaining AGENTS.md](#maintaining-agentsmd).

- Agents must read this file and the root `README.md` before making changes.
- Local agent instructions may refine workflow within this baseline.
- Local agent instructions must not weaken or duplicate project-wide policy.

### Project Constraints

#### First-Party Code And Dependencies

- Treat all module directories listed in the README as first-party except the vendored Git submodules `concat`, `debconf`, `reboot`, `stdlib`, and `timezone`.
- Keep changes within first-party code and repository-owned documentation or tooling unless the task explicitly requires a vendored dependency change.
- Never use vendored submodules as project style examples.

#### Supported Platforms

The first-party Puppet modules target Debian and Ubuntu servers. The complete module set primarily targets `amd64`; individual platform paths may support a narrower or broader set of releases or architectures.

- Support claims for operating systems, releases, architectures, Puppet, or OpenVox must match the implementation, relevant `metadata.json`, available validation, and Dutch README in the same change.

### Puppet Code Authority

The [general Puppet rules](.tools/lint/docs/CODE_RULES.md), [Puppet documentation rules](.tools/lint/docs/DOCUMENTATION_RULES.md), and [operational rules](.tools/lint/docs/OPERATIONAL_RULES.md) define the mandatory Puppet conventions, formatting rules, permitted exceptions, and manual review criteria within their respective scopes. The [lint guide](.tools/lint/README.md) owns the workflow and tooling instructions. The [project puppet-lint configuration](.puppet-lint.rc), shared profiles, and [project checks](.tools/lint/lib/project_lint/checks/) determine automated activation, detection, and correction; tool tests verify the scenarios they execute. This file governs repository-wide workflow, engineering, security, and documentation governance.

- Before changing Puppet code or Puppet Strings, follow the lint guide's [workflow](.tools/lint/README.md#werkwijze-bij-een-wijziging) and use its [reading guide](.tools/lint/README.md#leeswijzer) to select and read the relevant conventions and review criteria in `.tools/lint/docs/CODE_RULES.md`.
- For changes affecting Puppet code comments, Puppet Strings, or Puppet interface documentation, also read and apply the relevant rules in `.tools/lint/docs/DOCUMENTATION_RULES.md`.
- For changes affecting managed files or directories, ownership or permissions, security, systemd or services, shell code or templates, runtime tools or operational dependencies, or monitoring checks or registrations, also read and apply the relevant rules in `.tools/lint/docs/OPERATIONAL_RULES.md`. These operational rules apply in addition to the general rules.
- Both additional rule documents can apply to the same change; neither replaces `CODE_RULES.md`. A change affecting both operational code and its documentation must satisfy the applicable rules in all three rule documents.
- Inspect the project configuration and relevant check implementations when determining automated coverage or resolving a lint finding.
- Read additional relevant sections when the change affects Puppet Strings, dependencies, monitoring, systemd, security, or lint tooling. Unrelated specialized sections need not be read in advance.
- Follow the authoritative conventions and review criteria for every affected area, extending the reading scope when new dependencies or integrations are found.
- Agents must apply the documented review criteria even when the automated lint checks pass.
- Keep conflicts between the documented norm, configuration, implementation, and test evidence visible. Do not silently change any source to resolve a conflict without evidence or an explicit project decision.
- Keep each Puppet rule in exactly one authoritative location within these three rule documents. Root and local agent instructions, the lint README, and other Markdown documents must reference these sources instead of duplicating, adding, or overriding Puppet code standards.
- Changes to Puppet conventions must include their tests and all affected first-party code in the same change.

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
- Keep changes, including supporting refactors, scoped to the requested task and affected area.
- Use the simplest implementation that meets the requested behavior and preserves existing contracts, starting with existing built-in functionality.
- Do not add input formats, normalization, edge-case handling, fallbacks, checks, helpers, configuration files, or abstractions unless the user's request, an existing project or interface contract, or a demonstrated failure within the task's scope requires them. Hypothetical edge cases, possible future use, and general robustness arguments are not sufficient justification. Tests created for an unsolicited extension do not establish a requirement for that extension.
- Before adding such behavior or structure, identify the concrete requirement or demonstrated failure and explain why the simpler implementation cannot satisfy it. Record that justification in the change review; omit the addition when the need cannot be demonstrated. During final diff review, remove additions that lack this justification. When the user asks to simplify, remove unnecessary behavior and its supporting code.

### Impact Review

- Review effects on repository conventions, Puppet abstractions, and reusable wrappers. When a request uses a concrete example, assess whether the same principle applies to other resource types, consumers, or integrations in the affected area. Apply shared behavior consistently, preserve type-specific semantics, and record the scope and any deliberate limits in the change review.
- Review each added or moved declaration in the complete surrounding implementation against the [resource placement and ordering criteria](.tools/lint/docs/CODE_RULES.md#volgorde-en-meldingen). Record any necessary placement exception and its technical reason in the change review.
- Review effects on monitoring, logging, alerting, audit rules, and operational diagnostics.
- Review effects on documentation, examples, supported platforms, compatibility, and operational commands.

### Git Commits

- AI agents must never create, amend, or rewrite Git commits through Git commands, APIs, or other tools.
- Leave validated changes in the working tree for human review and commit.

## Design And Implementation

### Reuse And Shared Abstractions

- Inspect existing abstractions before adding a new one.
- Review parent-class interfaces before computing local settings in dependent defines, following the [class-check reuse criteria](.tools/lint/docs/CODE_RULES.md#classcontroles-hergebruiken).
- Identify the existing owner of cleanup before adding removal logic. When a centrally managed directory removes undeclared files, rely on that mechanism instead of adding cleanup to each consumer. Keep file removal separate from any required runtime stop or reload.
- When work reveals duplicated behavior in the affected area, extract a shared abstraction and migrate the affected callers in the same change.
- Use reusable defined types for repeated Puppet resource orchestration, with caller-specific settings passed as parameters.
- Preserve caller-specific security and lifecycle requirements during migration.
- Validate each migrated caller's behavior and dependencies.

### Prerequisite Review

- Identify which dependencies in changed code are operational prerequisites and which only affect execution order.
- Never treat omission of a dependency reference as disabling the dependent operation.
- Never infer runtime availability solely from the presence or absence of a declaration.
- Verify that the documented contract supplies required prerequisites before use or defines behavior for their absence: skip an optional operation or fail clearly for a required operation.
- Validate dependent behavior with prerequisites present and absent, including relevant declaration or evaluation order.
- Follow the [dependency review criteria](.tools/lint/docs/CODE_RULES.md#resources-en-afhankelijkheden) and [external-command package contract](.tools/lint/docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos) for Puppet-specific details, including exec resources and managed scripts.

### Managed Files And Helpers

#### Managed File Identification

- Include a `Managed by puppet` header in every file whose contents Puppet manages through inline content, templates, static sources, or concatenated fragments, unless the header would invalidate the format.
- Use the exact line `# Managed by puppet` for formats with hash comments, or the format's native comment syntax otherwise.
- Place the header at the start of the file, immediately after any required shebang or format header.
- Document any format constraint requiring omission beside the resource or content source, including binary content, formats without comments, or cryptographic material.
- Verify the header in the resulting file content when adding or changing a managed file. A comment in the Puppet manifest alone does not satisfy this requirement.

#### Management Helpers

- Install internal management scripts and their supporting files under `/usr/local/lib/puppet/`, following the existing MySQL helper layout. Apply this location when adding or changing a helper; keep service-native configuration, data and monitoring plugins in their established locations.
- Update all invocations and dependencies together when moving a helper, and reuse the existing shared directory resource.

## Shell Scripts

These conventions govern all first-party POSIX shell and Bash code, regardless of purpose or filename extension. Apply them when creating or changing shell code, including `.sh` files, extensionless executables, templates and inline fragments.

### Interpreter And Structure

- Use POSIX `#!/bin/sh` unless required functionality needs Bash. For Bash scripts, declare the interpreter explicitly and document the required Bash features beside the implementation.
- Keep code compatible with its declared interpreter, including generated code and inline fragments. Do not use Bash-only constructs, such as arrays, `[[ ... ]]` or `pipefail`, in POSIX shell code.
- Place the shebang and required headers first, following [managed file identification](#managed-file-identification).
- Order the applicable sections as follows: error helper, binary discovery, settings and state initialization, argument parsing, helper functions and input validation, then main logic. Define any helper before it is called.
- Omit sections the script does not need. Do not add options, environment settings or helper layers solely to fill out this structure.
- Resolve external commands directly with `COMMAND=$(command -v command 2>/dev/null) || die ...`, using the script's error helper. Invoke the resolved `$COMMAND` in command position without quotes; keep command arguments separate.
- Use shell builtins directly and use `printf` for output.

### Native Tools And Dependencies

- Review the purpose of each external tool used in changed shell code. Prefer the original command's native output, filters and exit status; do not convert output to JSON or another format solely to extract a simple value or determine success.
- Use shell comparisons, `case` patterns, parameter expansion and builtins for simple validation and string operations when they reliably preserve the required behavior. Do not install additional packages solely for operations the declared shell or original command already handles simply.
- Use a dedicated parser such as `jq` when native structured output requires reliable processing of multiple fields or complex structures. Do not replace a necessary structured parser with fragile shell parsing merely to remove a dependency.
- Follow the [external-command package contract](.tools/lint/docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos) for runtime dependencies. Before removing obsolete command discovery, package declarations or dependency references, review all consumers and retain dependencies still required elsewhere.

### Formatting And Naming

- Use four spaces per indentation level in both source and generated shell code.
- Use descriptive `UPPER_SNAKE_CASE` names for settings, resolved commands and main-program state. Use `lower_snake_case` for helper functions and their internal working variables.
- Group settings and derived values by purpose, with a short comment introducing each logical block. Keep the main flow readable from preparation through execution to result handling.
- Write `if`, `case` and loop bodies with multiple actions across separate, indented lines. Keep one-time processing together when extracting it would obscure the flow, and put substantive processing before a small fallback branch.
- Quote data expansions in arguments, tests and assignments. Preserve literal whitespace in heredocs and multiline quoted data when formatting code.

### Arguments And Runtime Settings

- Preserve existing argument names, input formats, configuration sources and exit behavior. Document any deliberately changed public contract with its callers.
- Retain existing daemon configuration and credential interfaces. Do not copy those values into additional command-line options or environment variables.
- Parse short options in one POSIX `while getopts ... opt; do` block, with a separate `case` branch for each option. Finish with one usage/error branch for invalid options and help, including `-h` when declared; retain positional arguments for interfaces that use them.
- Resolve configurable settings in this order when those sources are supported: explicit command-line input, non-empty environment variable, script default.
- Initialize environment-backed settings with `${VARIABLE:-default}` before parsing arguments, so unset and empty variables use the default. Apply explicit arguments afterward and never reset the result to environment values or defaults.
- Validate effective settings after parsing and before use, regardless of their source. Check syntax, units, ranges, related value ordering, booleans and runtime meaning. Preserve documented optional empty values and report invalid input through the script's error interface.
- Document arguments, options, associated environment variables and defaults in usage or help text. Include repeated options and boolean reset options where supported.

### Helpers And Data Handling

- Add a helper when it names a distinct task, shares validation or formatting, or removes substantial duplication. Do not wrap a single assignment, append or `printf` without such a reason.
- Use shell variables and `printf` for bounded counters, buffers and text. Use `mktemp` when a command requires a file or the data is too large or unsafe for variables, and remove temporary files after use.
- Build text buffers with explicit `printf` formats and escaped newlines instead of literal blank lines in quoted assignments. Choose list separators to match the input or output contract; keep meaningful whitespace in literal data intact.
- Use explicit markers when passing structured metadata through command substitution. Do not depend on artificially appended newlines surviving shell processing.

### Shell Validation

- Review the source and rendered output against these conventions, and run syntax validation with the intended interpreter. Puppet-lint does not validate shell syntax or the complete shell style.
- Validate changed scripts with isolated synthetic cases for every supported input source: defaults, environment-only values, combined environment and CLI values, empty and invalid inputs, and partial overrides. Include related value ordering, repeated options, boolean resets and timeout behavior where applicable.
- When replacing external tools, verify equivalent behavior, validation, error handling, monitoring statuses, exit codes and externally consumed output unless a behavior change is explicitly requested. Include relevant whitespace, escaping, locale and boundary cases in the comparison, and apply the [prerequisite review](#prerequisite-review) to removed or relocated dependencies.
- Keep functional validation outside the repository according to the [test scope](#test-scope), including checks of failure paths and temporary-file cleanup when affected.

## Monitoring Checks

### Shared Check Executables

- When adding or changing monitoring checks, deploy one executable per check implementation on each managed host, shared by every target registration.
- Never generate executable copies or wrappers merely to embed different target values.
- Pass target identity and settings that differ between registrations as runtime arguments or through an existing configuration interface.
- Limit executable templating to values shared by all registrations on the host.
- Manage the shared executable independently of individual registrations so removing or disabling one target preserves checks for other targets.
- Keep monitoring independent of the task it observes: inspect results or status without invoking, sourcing, or depending on the task runner.

### Monitoring Check Configuration

#### Runtime Settings

- Apply the shared [argument and runtime-setting conventions](#arguments-and-runtime-settings) to every check.
- Provide command-line options and environment variables for every configurable runtime setting.
- Follow the check's established conventions for new options.
- Reject invalid required values with Nagios UNKNOWN.

#### Registration And Configuration Interfaces

- Keep optional runtime defaults in the check executable.
- Apply only explicitly supplied overrides from registrations.
- Follow the [input and configuration contract](.tools/lint/docs/OPERATIONAL_RULES.md#invoer-en-configuratie) for Puppet parameters that default to `undef`.

#### Executor Scheduling

- Review executor scheduling separately from script options.
- Verify that the executor timeout allows the script's execution, termination, and output budget.

### Inspection Results

- Report a verified missing required component, policy mismatch, or inactive required service as CRITICAL; report unavailable permissions, tools, or unreadable output that prevents assessment as UNKNOWN.
- Never convert a failed inspection into an empty collection or a healthy result. Preserve verified deviations alongside incomplete observations and document their status precedence.
- Keep diagnostics deterministic and bounded, identifying the affected object and the expected and observed state; supplementary counters must not establish health.

### Monitoring Validation

- Verify each check's package guarantees through the general [external-command package contract and its documented exceptions](.tools/lint/docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos).
- Apply [shell validation](#shell-validation) to changed check implementations.
- For each changed check, validate registrations with at least two targets invoking the same executable with their own settings.
- For each changed check, validate that retiring one target preserves the shared executable and the other registrations.

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

- Consuming projects own their nftables rules, including their contents, names, policies, interfaces, IP families, and delivery mechanism. They may use templates, file sources, or another configuration system.
- Shared modules must not generate or manage deployment firewall profiles, introduce firewall expectation files or their Puppet datatypes and validation functions, or add specialized monitoring classes to take over that responsibility.
- Keep firewall monitoring in the existing network integration. Pass deployment-owned structural expectations as runtime arguments to the shared executable and compare them with loaded state; never infer required components solely from that state.
- Never treat general rule counts or empty tables/chains as proof of protection or failure. Document the scope of a successful structural check and validate packet reachability separately when required.

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

## Development Tooling

### Development Environment

- Use the latest stable Ruby and Bundler for development and CI.
- Never pin Ruby or Bundler versions in setup commands or runtime configuration.
- Use the root Gemfile, lockfile, standard CLI, and regression tests through the [documented bundle setup](.tools/lint/README.md#installatie).

### Ruby Linter Architecture

- Use Puppet-lint as the lint engine and prefer its registration, configuration, diagnostic, suppression, and autofix APIs over custom infrastructure.
- Keep reusable runtime code and dependencies in the linter gem; keep development dependencies and orchestration in the root Gemfile and Rakefile.
- Keep project Ruby helpers within `ProjectLint` and use conventional namespace-based require paths; do not introduce top-level helper constants or mutable configuration captured during loading.
- Keep each check's native registration, detection, and fix together, following the [check development guide](.tools/lint/README.md#een-check-toevoegen-of-wijzigen).
- Extract helpers only for existing shared complexity or a substantial standalone analysis; keep simple check-specific methods with their check and avoid speculative abstractions.
- Treat the documented gem entrypoint, profiles, check names, and downstream settings as public contracts; version changes and validate packaged use from an independent project.
- Keep local and CI execution on the same Bundler, Rake, and native CLI routes.
- Keep downstream setup and CI examples aligned with the [recommended consumer layout](.tools/lint/README.md#aanbevolen-projectstructuur). Document supported layout differences without duplicating the linter implementation or shared profiles.

### Linting And Autofix

#### Existing Tools

- Use existing checks and safe autofixes from `puppet-lint`, installed plugins, and project custom checks.
- Never reproduce supported detection or safe correction logic manually or in separate tools.

#### Correction Workflow

- Establish existing findings before editing and scan changed code before resolving individual findings, following the lint guide's [development workflow](.tools/lint/README.md#werkwijze-bij-een-wijziging).
- Apply available autofixes within the task's scope only when they are demonstrably safe and deterministic, preserving functional behavior, Puppet resource relationships, dependencies, and intended configuration.
- Review corrections manually when their safety cannot be demonstrated.
- Follow the [lint usage instructions](.tools/lint/README.md#automatisch-corrigeren-autofix) for commands and selection options.
- Rerun the linter after autofix.
- Resolve only the remaining findings manually after the rescan.
- Review the complete diff after corrections to confirm that automatic changes are semantically correct and within scope.

#### Autofix Development

- Implement custom autofixes through the native `puppet-lint` fix mechanism under the [correction safety criteria](#correction-workflow).
- Never build a separate formatter or autofix engine.
- Require custom autofixes to be idempotent.
- Follow the [autofix development guidance](.tools/lint/README.md#veilige-autofixes-ontwikkelen) for implementation and review.
- Verify each fix through detection, exact correction, a clean rescan, and an unchanged second fix run, including interactions with enabled checks and lint suppressions.
- Report custom checks that appear suitable for safe autofix but lack it as linter improvements.
- Implement those improvements only when linter development is within the task's scope.

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

- Run Puppet parser validation, Puppet linting, Ruby linting, and tool tests in independent CI jobs.
- Generate all published validation, lint, and test reports as JUnit XML during their respective check execution. Publish each job's reports as separate artifacts after success or an ordinary check failure, preserving the check's exit status.
- End each job's successful validation path with `git diff --exit-code HEAD --` to detect changes to tracked files. Never restore files to make this check pass.
- Keep generated reports in an ignored results directory under `.tools/` and document their commands and locations in the [lint guide](.tools/lint/README.md#ci-van-deze-repository).

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
- Place information according to the responsibilities below.

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
- Keep the lint README's contents task-oriented around lint usage and tooling. Organize the rule documents around their assigned domains: general Puppet code in `CODE_RULES.md`, Puppet comments and interface documentation in `DOCUMENTATION_RULES.md`, and operational rules in `OPERATIONAL_RULES.md`. Link clearly from the lint README to all three rule documents and between relevant sections in all four documents, following the [Markdown navigation requirements](#markdown). Make the cumulative applicability of the three rule documents explicit in the reading guide.
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
- Keep both the repository quick start and the consumer quick start before the detailed tooling reference in `README.md`. Keep the sole central check registry and maintainer explanations there, and link directly to the authoritative rule in `CODE_RULES.md`, `DOCUMENTATION_RULES.md`, or `OPERATIONAL_RULES.md` without duplicating full rules or the registry.
- Keep tool-specific test instructions in the owning tooling guide. Do not create separate test READMEs.
- General README brevity, selective-detail, and presentation guidance must not remove information or required fields from the lint guide. Apply the lint guide's documentation contract to its rule reference.

### Lint Documentation Maintenance

#### Rule Contract

- Maintain every new or changed Puppet rule in `CODE_RULES.md`, `DOCUMENTATION_RULES.md`, or `OPERATIONAL_RULES.md` according to ownership of the decision it governs, using the same field schema defined in the lint README's [documentation contract](.tools/lint/README.md#documentatiecontract-voor-maintainers). Link from the other rule documents when their scopes meet instead of duplicating the norm. Do not omit, rename, or merge required fields without an explicit owner request to change that schema.
- State each rule's applicability and required action directly. Preserve whether existing policy is mandatory, prohibited, recommended, or permitted.
- Keep conditions, permitted exceptions, analysis limits, and autofix refusal cases with the rule they modify. An undetected violation is not a permitted exception.
- Document every distinct diagnostic variant and its actual severity. Classify autofix coverage per variant rather than inferring coverage from the existence of a fix method.
- Label examples as fragments, complete executable examples, or manual review scenarios. Do not describe a fragment as passing the complete profile unless that complete run was executed successfully.
- Use an explicit reason for a field that does not apply. Missing evidence is an unresolved item, not a reason to omit the field or claim compliance.

#### Inventory And Synchronization

- Maintain tooling procedures and exactly one entry per registered `project_*` check in `README.md`. Link registry entries directly to the relevant authoritative rules in `CODE_RULES.md`, `DOCUMENTATION_RULES.md`, or `OPERATIONAL_RULES.md`. Verify runtime registration, profile activation, diagnostic coverage, and rule links as separate properties.
- Synchronize implementation, rule fields in `CODE_RULES.md`, `DOCUMENTATION_RULES.md`, and `OPERATIONAL_RULES.md`, registry entries and procedures in `README.md`, and tool tests in the same change when checks, diagnostics, severity, defaults, fixes, suppressions, configuration, dependencies, reports, or public consumer interfaces change. A check change can therefore require edits across the four documents.
- When a tooling change has no documentation impact, identify the reviewed interfaces and explain that conclusion in the change review. Do not use that explanation to leave changed documented behavior stale.
- Treat check names, entrypoints, shared configuration paths, report executables, public environment variables, and consumer invocation behavior as public interfaces. Document and test intentional interface changes.
- Verify version claims against their declared constraints and resolved dependencies. Keep declared compatibility, installed versions, tested combinations, and repository development policy distinct.

#### Executable Procedures

- State the working directory, shell, prerequisites, input selection, file mutations, and expected result before an executable procedure. Define all variables and replacement values before use.
- Verify changed configuration instructions against the installed CLI, loader, and tooltests. Determine precedence by option type instead of assuming every later value replaces an earlier one.
- Validate changed downstream procedures in a separate consumer project with its own Gemfile, lockfile, local configuration, and manifest selection. Do not rely on the source repository's implicit environment.
- Validate each documented installation route independently, including the built package when package distribution is documented. A successful path installation does not prove Git or package installation.
- Verify both successful and failing command outcomes, including numeric exit status and report production. A successful report conversion must not conceal a failed validation or lint process.

#### Preservation And Review

- Record the previous location, preserved meaning, new location, and reason for each substantive documentation change in the change review. Do not create another repository document for this migration record.
- Preserve heading anchors when reorganizing lint documentation, update repository-owned incoming links when their target moves between the four documents, and verify target files and fragments. Verify that each existing rule and its subordinate headings retain exactly one authoritative destination in `CODE_RULES.md`, `DOCUMENTATION_RULES.md`, or `OPERATIONAL_RULES.md`.
- Do not change lint behavior or weaken a rule to resolve a documentation mismatch. Record the normative requirement and observed behavior separately when the intended resolution is not established.
- Keep unresolved policy conflicts and unexecuted required checks visible in the delivery report, following [isolation and evidence](#isolation-and-evidence). Do not describe the task as complete while required evidence is missing.
- Use automated checks to verify technical inventories, links, and execution contracts. Review explanatory accuracy and preservation of meaning manually; successful automation does not prove prose quality.

## Maintaining AGENTS.md

### Content And Placement

- Store only durable project-wide engineering rules that govern future development.
- Never record task, ticket, bug, feature, or prompt history, except historical context essential to understanding a technical contract or deliberate exception.
- Convert task instructions, recurring review findings, production issues, security findings, test failures, tooling changes, and agent mistakes into rules only when the required behavior generalizes beyond one task.
- Never copy a task instruction verbatim into this file merely because it requests a policy update.
- When adding new material, place feature-specific implementation detail, configuration guides, troubleshooting, implementation plans, examples, and concrete test scenarios in their [designated locations](#language-and-authority), unless they are lasting project-wide constraints. When reorganizing this file, apply the [preservation requirements](#consolidation-and-placement) to its existing content.
- Preserve exact technical names, values, and versions when required by a contract, constraint, exception, compatibility requirement, or security requirement.
- Keep relevant technical detail, explanations, examples, and verification instructions in this file when reorganizing it. Other documentation may supplement this content, but must not replace information removed from this file.

### Change Scope

- Update this file when a repository-wide convention, architecture constraint, validation command, security requirement, non-Puppet engineering standard, or operational workflow changes.
- Limit routine maintenance to the affected rules and directly impacted references.
- Restructure the whole file only when explicitly requested or when documented contradictions across sections require it.
- Read the complete file before a substantive change so existing rules, exceptions, and cross-references inform the edit.

### Maintenance Decisions

- Identify the underlying objective, required behavior or lasting knowledge, scope, and necessary exceptions before proposing a policy change. Determine where that content belongs.
- Find the existing authoritative rules that wholly or partly cover the required behavior.
- Distinguish missing or unclear policy from failure to follow a clear rule before deciding to edit.
- Leave this file unchanged when existing policy covers the requested behavior completely and unambiguously and no structural improvement is needed, even after repeated violations.
- When a clear rule was violated, investigate which execution or verification step failed.
- Correct that failed step without adding or rewording policy that already covers the behavior.
- Update or clarify the existing authoritative rule before creating a parallel rule. Broaden its scope only when existing authority or an explicit instruction supports that policy change.
- Add a new rule only when necessary durable behavior is not already covered.

### Consolidation And Placement

- Keep one authoritative location for every normative rule. Consolidate duplicate or weaker variants only when their full meaning is preserved, including any distinct conditions, exceptions, explanations, examples, and verification requirements.
- Place each rule in the narrowest relevant section, extending an existing section when its subject fits.
- Place each exception directly with the rule it modifies.
- Combine rules only when they share the same objective, scope, required behavior, and decision point without hiding independent obligations. For partial overlap, consolidate the shared part and keep additional conditions or exceptions visible.
- Keep checklist entries as concise verification references rather than copies of the full policy.
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
- Prioritize completeness, correctness, readability, scope, and traceability over reducing words, lines, bullets, or headings. Improve organization and wording without compressing information or moving it out of this file.
- Never compress independent requirements into a dense paragraph to reduce the document's length.

### Conflict Resolution

- Preserve the strongest applicable security rule during consolidation.
- Correct unclear, outdated, incorrect, or contradictory rules only when repository evidence or an explicit project decision establishes the intended requirement. A difference between code and documentation does not by itself show which one is wrong.
- Record substantive policy changes, contradictions, and the reasons for corrected or removed wording in the change review. Identify the affected passages, their previous and new meaning, and the evidence or explicit decision supporting the change.
- When evidence cannot resolve a requirement or contradiction, keep the affected information identifiable, mark the conflict as unresolved, and state which decision is missing in the change review. Continue with uncontested work, but do not present the result as conflict-free or automatically choose the strictest, broadest, or apparently safest wording.

### Final Review

- Review the complete diff against the pre-change version. Verify that every original obligation, prohibition, preference, condition, exception, technical contract, compatibility requirement, security safeguard, explanation, example, and verification instruction remains in this file or has an explicitly justified correction.
- Verify that generalization and restructuring neither make required behavior optional nor make optional behavior mandatory.
- Manually verify that every changed rule is necessary, reusable, scannable, non-duplicative, unambiguous, and consistent with this document, its terminology, and its references.
- Run automated checks for literal duplicate rules and local link targets, using repository tooling when available or isolated temporary checks otherwise. Review meaning, structure, and readability manually rather than enforcing numerical prose limits.
- Record the existing policy, reason for change, and preserved obligations and exceptions for each substantive rule change in the change review outside this file.
- Check the reverse direction as well: every new obligation, exception, or technical claim must be supported by the previous policy, an established project agreement, or an explicit instruction. Make unresolved conflicts visible before completion.

## Completion Checklist

### Workflow And Validation

- Verify [preparation and scope](#working-with-the-existing-codebase).
- Verify [Puppet code authority](#puppet-code-authority).
- Verify applicable [design and implementation rules](#design-and-implementation), [shell conventions](#shell-scripts), and [monitoring contracts](#monitoring-checks).
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
