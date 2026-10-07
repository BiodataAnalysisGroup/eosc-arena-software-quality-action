# EOSC Arena software quality action

A GitHub Action that checks research software against the
[EVERSE research software quality indicators](https://everse.software/indicators/website/indicators.html)
using [resqui](https://github.com/BiodataAnalysisGroup/QualityPipelines). It runs
on every push or pull request, writes a report to the job summary and can fail
the job when indicators are not met.

## Quick start

Add `.github/workflows/quality.yml` to your repository:

```yaml
name: Software quality

on:
  push:
  pull_request:

jobs:
  resqui:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: BiodataAnalysisGroup/eosc-arena-software-quality-action@v1
```

This checks the [default set of indicators](configurations/default.json) and
reports the results without failing the job. Open the workflow run to see the
report in its summary.

## What it does

1. Installs resqui (from `BiodataAnalysisGroup/QualityPipelines`, pinned by
   `resqui-version`) in an isolated virtual environment.
2. Runs the indicators listed in the configuration against the checked-out
   commit.
3. Adds a Markdown report to the job summary and uploads the JSON and Markdown
   reports as a workflow artifact.
4. Fails the job if any check has an outcome listed in `fail-on`.

## Inputs

| Input | Default | Description |
|---|---|---|
| `config` | bundled [`default.json`](configurations/default.json) | Path to a resqui configuration file, relative to your repository root. |
| `fail-on` | *(empty)* | Comma-separated outcomes that fail the job: `fail`, `not_run`, or `fail,not_run`. Empty only reports. |
| `github-token` | `${{ github.token }}` | Token for plugins that query the GitHub API. The default is enough for public repositories. |
| `resqui-version` | a pinned release | Tag, branch or commit of `BiodataAnalysisGroup/QualityPipelines` to install. |
| `job-summary` | `true` | Add the Markdown report to the job summary. |
| `artifact-name` | `resqui-report` | Name of the uploaded report artifact. Empty disables the upload. Use distinct names if the action runs more than once in a workflow. |

## Outputs

| Output | Description |
|---|---|
| `passed` | Number of checks whose indicator is satisfied. |
| `failed` | Number of checks whose indicator is not satisfied. |
| `not-run` | Number of checks that could not be performed. |
| `report-json` | Path to the JSON-LD report. |
| `report-markdown` | Path to the Markdown report. |

## Check outcomes and failing the job

Every check ends with one of three outcomes:

| Outcome | Meaning | Example |
|---|---|---|
| `pass` | The indicator is satisfied. | A `LICENSE` file was found. |
| `fail` | The indicator was checked and is not satisfied. | No dependencies are declared. |
| `not_run` | The check could not be performed. | A Docker-based plugin on a runner without Docker. |

By default the action only reports. To use it as a quality gate, set `fail-on`:

```yaml
      - uses: BiodataAnalysisGroup/eosc-arena-software-quality-action@v1
        with:
          config: .resqui.json
          fail-on: fail,not_run
```

Including `not_run` makes sure a check that silently stops working (for
example after a runner change) fails the job instead of being ignored. The
reports are always written and uploaded before the job fails, and an error
annotation summarises the counts.

The outputs can also drive your own logic:

```yaml
      - uses: BiodataAnalysisGroup/eosc-arena-software-quality-action@v1
        id: quality
      - if: steps.quality.outputs.failed != '0'
        run: echo "${{ steps.quality.outputs.failed }} indicators need attention"
```

## Configuration

A configuration lists the indicators to check and the resqui plugin that checks
each one:

```json
{
  "indicators": [
    { "name": "software_has_license", "plugin": "RSFC", "@id": "https://w3id.org/everse/i/indicators/software_has_license" },
    { "name": "software_has_tests", "plugin": "RSFC", "@id": "https://w3id.org/everse/i/indicators/software_has_tests" }
  ]
}
```

- `name` is the check performed by the plugin, `plugin` the resqui plugin
  class, and `@id` the indicator in the
  [EVERSE indicator catalogue](https://w3id.org/everse/i/indicators/).
- Run `resqui indicators` to list the plugins and the checks each provides.
- Start from the [default configuration](configurations/default.json) and keep
  the indicators your project commits to. For a quality gate, a smaller list
  you actually meet with `fail-on: fail,not_run` works better than the full
  list with failures you have decided to accept.

### Default indicators

| Indicator | Plugin | Looks at |
|---|---|---|
| `software_has_license` | RSFC | Commit |
| `software_has_citation` | RSFC | Commit |
| `software_has_documentation` | RSFC | Commit |
| `software_has_tests` | RSFC | Commit |
| `requirements_specified` | RSFC | Commit |
| `versioning_standards_use` | RSFC | Commit |
| `persistent_and_unique_identifier` | RSFC | Commit |
| `descriptive_metadata` | RSFC | Commit and repository metadata |
| `archived_in_software_heritage` | RSFC | Commit (Software Heritage badge) |
| `repository_workflows` | RSFC | Commit |
| `version_control_use` | RSFC | Repository |
| `has_releases` | RSFC | Repository (GitHub releases) |
| `has_ci_tests` | OpenSSF Scorecard | Repository (CI on merged pull requests) |
| `has_published_package` | OpenSSF Scorecard | Repository (publishing workflows on the default branch) |

"Commit" indicators assess the checked-out commit, so they reflect the branch
or pull request being tested. "Repository" indicators look at the repository on
GitHub as a whole: on a feature branch or pull request they still reflect the
default branch and the repository's history.

## Runner requirements

- **Python** is set up by the action.
- **Docker** is needed by the RSFC and OpenSSF Scorecard plugins. GitHub-hosted
  Ubuntu runners have it. On self-hosted runners, install Docker or those checks
  end up `not_run`.
- **Network access** to GitHub, Docker Hub and GHCR.

The first run on a runner pulls the plugin images, which takes a few minutes.

## Reports

- **Job summary:** a table with each indicator, the tool that checked it, its
  outcome and the evidence.
- **Artifact** (`resqui-report` by default): `resqui_summary.json`, a JSON-LD
  assessment following the EVERSE RSQA schema with an `outcome` per check, and
  `resqui_summary.md`.

## Versioning

Pin a release tag (`@v1`) rather than `@main`. Each action release pins a
tested resqui version; set `resqui-version` to try another one.
