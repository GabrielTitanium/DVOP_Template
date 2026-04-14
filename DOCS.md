# DVOP_Template — Documentation

## Table of Contents

1. [Overview](#overview)
2. [Repository Layout](#repository-layout)
3. [How the Template System Works](#how-the-template-system-works)
4. [Pipeline File Anatomy](#pipeline-file-anatomy)
5. [Template Reference](#template-reference)
6. [Parameter Reference](#parameter-reference)
7. [Deployment Stages Deep Dive](#deployment-stages-deep-dive)
8. [Scripts Reference](#scripts-reference)
9. [Variable Groups](#variable-groups)
10. [Adding a New Pipeline](#adding-a-new-pipeline)
11. [Existing Environments](#existing-environments)
12. [Troubleshooting](#troubleshooting)

---

## Overview

This repository is the single source of truth for **Azure DevOps deployment pipelines** that release Titanium Solutions Dental applications (Origin, Salud, Unity) onto customer-hosted Windows servers.

The core idea is **DRY deployment logic**: all stage definitions live in a small set of shared templates under `templates/`. Each customer environment is represented by a thin pipeline file in `pipelines/` that simply selects a template and passes environment-specific parameters into it.

```
pipelines/<ENV>.yml          ← thin, per-environment config
        │  extends
        ▼
templates/pipeline-v*.yml    ← all deployment logic
        │  runs
        ▼
scripts/*.ps1                ← PowerShell tasks run on the agent
```

---

## Repository Layout

```
DVOP_Template/
├── configs/               # Reserved for future shared config
├── pipelines/             # One .yml file per customer environment
├── scripts/               # PowerShell scripts used by the templates
│   ├── <shared>.ps1       # Scripts used across all environments
│   ├── MONTREAL-QA/       # Scripts specific to Montreal QA
│   ├── WS-SALUD-TRUNK/    # Scripts specific to Salud Trunk
│   ├── WS100-PM-DHSV/     # Scripts specific to DHSV (Unity)
│   ├── WS114-QA-QUMC/     # Scripts specific to QUMC
│   ├── WS120-MI-LMU/      # Scripts specific to LMU MI
│   └── WS120-QA-LMU/      # Scripts specific to LMU QA
└── templates/             # Shared YAML templates
    ├── pipeline-v1.yml    # Origin environments
    ├── pipeline-v2.yml    # Salud 104.122 / Montreal environments
    ├── pipeline-v3.yml    # Salud 104.120 / Trunk environments
    └── pipeline-v4.yml    # Unity environments
```

---

## How the Template System Works

Azure DevOps supports a `extends` keyword that lets a pipeline file delegate all its stage/job definitions to a template, while supplying environment-specific values as parameters.

```yaml
# pipelines/MY-ENV.yml
extends:
  template: ../templates/pipeline-v2.yml
  parameters:
    agentName: 'MY-AGENT'
    environmentName: 'MY-ENV'
    ...
```

This means:
- **You never write deployment stages twice.** Bug fixes or improvements to a stage automatically apply to every environment that uses that template.
- **Pipeline files are purely configuration.** They contain a variable group name, a resource pipeline reference, and a parameter block. Nothing else.
- **Template versioning is explicit.** Choosing `pipeline-v1.yml` vs `pipeline-v4.yml` determines which application type (Origin / Salud / Unity) and which stage set will run.

### Trigger Model

Pipelines are triggered in two ways:

1. **Automatic** — an upstream build pipeline tags a run with `ReleaseReady`. The deployment pipeline detects this tag and starts automatically.
2. **Manual** — a team member triggers the pipeline directly from the Azure DevOps UI.

```
Build Pipeline (e.g. "Salud Services 104.122")
        │
        │  git tag: ReleaseReady
        ▼
Deployment Pipeline (this repo) auto-starts
```

---

## Pipeline File Anatomy

Every file in `pipelines/` follows this structure:

```yaml
trigger: none   # No CI triggers — deployments are intentional
pr: none        # No PR triggers

variables:
  - group: '<VARIABLE-GROUP-NAME>'   # Must exist in Azure DevOps Library

resources:
  pipelines:
    - pipeline: <AliasForThisPipeline>
      project: Titanium
      source: "<Exact Build Pipeline Name>"
      trigger:
        tags:
          - ReleaseReady

    # Optional second resource (e.g. InsuranceHost)
    - pipeline: InsuranceHostTrunk
      project: Titanium
      source: "InsuranceHost Trunk"

extends:
  template: ../templates/pipeline-v2.yml
  parameters:
    environmentName:                  'MY-ENV'
    agentName:                        'MY-AGENT'
    installerFile:                    'Setup_Salud.msi'
    poolName:                         'Default'
    webAppName:                       'Salud'
    webAppPool:                       'TitaniumSolutionsDentalAppPool'
    updateWebConfigScriptPath:        'scripts/MY-ENV/Update-WebConfig.ps1'
    customerPackagesUploadScriptPath: 'C:\Build\CustomerPackages\...\Run-UploadPackages.ps1'
    customerPackagesXmlReferencePath: 'C:\Build\CustomerPackages\...'
    enableBackupRestore:              true
    backupDirectory:                  '\\SQLSERVER\Backups\MY-ENV'
    installOriginScriptPath:          'scripts/MY-ENV/Install-Salud.ps1'
    organization:                     'Titanium-Solutions'
    project:                          'Titanium'
    variableGroupId:                  '35'
```

---

## Template Reference

### `pipeline-v1.yml` — Origin (base template)

The original template. Used for Origin deployments. Most parameters have no defaults and must be supplied explicitly.

**Key differences from v2/v3/v4:**
- Single resource pipeline (no InsuranceHost support).
- Uses `installOriginScriptPath` parameter for the install script.
- No `poolName` or `webAppName` flexibility — uses `Default` pool and infers names.

### `pipeline-v2.yml` — Salud 104.122 / Montreal

Used for Montreal-family environments. Extended with:
- `poolName` — lets you target a named agent pool (e.g. `Dublin`).
- `webAppName` — IIS web application name (`Salud`, `Origin`, etc.).
- `enableInsuranceHost` — when `true`, downloads and installs `InsuranceHostInstaller.msi` using `Copy-MSI.ps1` and `Install-Insurance.ps1`, then updates `appsettings.json` via `Update-AppJson.ps1`.
- Requires a second `resources.pipelines` entry for `InsuranceHost Trunk` when `enableInsuranceHost: true`.

### `pipeline-v3.yml` — Salud 104.120 / Trunk

Similar to v1 but wired to the `Salud Services 104.120` / Trunk build pipeline. Used for environments on older Salud branches.

### `pipeline-v4.yml` — Unity

Used for Unity application deployments. Key parameters:
- `AppName` — the application name used in registry cleanup (`Clear-Registry-Unity.ps1`).
- `installerFile` — set to `Setup_Unity.msi`.
- `installScriptPath` — path to an `Install-Unity.ps1` script.
- `enableInsuranceHost` — same as v2; controls whether InsuranceHost is deployed alongside Unity.

---

## Parameter Reference

| Parameter | Type | Default | Description |
|---|---|---|---|
| `agentName` | string | — | Name of the self-hosted agent on the target server. |
| `environmentName` | string | — | Azure DevOps environment name (drives approval gates). |
| `installerFile` | string | — | MSI filename to install (`Setup_Origin.msi`, `Setup_Salud.msi`, `Setup_Unity.msi`). |
| `webAppName` | string | — | IIS web application name (used in uninstall lookup and install). |
| `AppName` | string | — | Application name for registry key path (v4 only). |
| `webAppPool` | string | `TitaniumSolutionsDentalAppPool` | IIS application pool name. |
| `poolName` | string | `Default` | Azure DevOps agent pool name (v2/v4). |
| `enableBackupRestore` | boolean | `false` | When `true`, adds Backup, Restore, and Rollback stages. |
| `backupDirectory` | string | `''` | UNC path for `.bak` database backups. Required when `enableBackupRestore: true`. |
| `installScriptPath` | string | `''` | Path to the environment-specific install script (v4). |
| `installOriginScriptPath` | string | `''` | Path to the environment-specific install script (v1/v2/v3). |
| `updateWebConfigScriptPath` | boolean/string | `false` | Path to the `Update-WebConfig.ps1` script. Set to `false` to skip. |
| `customerPackagesUploadScriptPath` | string | — | Absolute path to the customer's `Run-UploadPackages.ps1` on the agent. |
| `customerPackagesXmlReferencePath` | string | — | Absolute path to the customer package XML directory on the agent. |
| `organization` | string | `Titanium-Solutions` | Azure DevOps organization name (used for REST API calls). |
| `project` | string | `Titanium` | Azure DevOps project name (used for REST API calls). |
| `variableGroupId` | string | `''` | Variable group ID (used by REST API to fetch secrets at runtime). |
| `enableInsuranceHost` | boolean | `false` | When `true`, deploys InsuranceHost alongside the main application (v2/v4). |

---

## Deployment Stages Deep Dive

Templates define up to **8 sequential stages**. Conditional stages are only injected into the pipeline when the relevant parameter is set.

```
Stage 1 ─── Deploy Approval          (always runs)
Stage 2 ─── Backup Database          (only if enableBackupRestore: true)
Stage 3 ─── Fetch Artifacts          (always runs)
Stage 4 ─── Install Application      (always runs)
Stage 5 ─── Database Migration       (always runs)
Stage 6 ─── Upload Customer Packages (always runs)
Stage 7 ─── Restore Database         (only if enableBackupRestore: true AND a prior stage failed)
Stage 8 ─── Rollback                 (only if a prior stage failed)
```

### Stage 1 — Deploy Approval

- Requests approval through the Azure DevOps **Environment** gate.
- Stops IIS (`Stop-IIS.ps1`).
- Copies `Server.ps1` and `maintenance.html` to `C:\MaintenancePage\MaintenancePage\`.
- Registers a Windows Scheduled Task (`MaintenanceServer`) that runs `Server.ps1` as SYSTEM.
- Starts the task — this launches an HTTPS listener on port 443 serving the maintenance page to end users.

### Stage 2 — Backup Database *(conditional)*

- Reads database credentials from the variable group (`$(privateDB)`, `$(databaseName)`, etc.).
- Calls `Backup-Database.ps1`, which performs a SQL Server backup to `$(backupDirectory)`.
- Publishes the backup file path as a pipeline output variable for use in Stage 7.

### Stage 3 — Fetch Artifacts

- Uses the Azure DevOps REST API to locate the latest (or tagged) build artifacts from the upstream pipeline.
- Downloads the MSI installer and any additional artifacts to a local staging directory (`C:\Build\`).
- For environments with `enableInsuranceHost: true`, also copies the InsuranceHost MSI using `Copy-MSI.ps1`.

### Stage 4 — Install Application

1. Uninstalls the existing application using `Uninstall-Application.ps1` (searches registry, runs `msiexec /x /qn`).
2. Clears the Titanium registry key with `Clear-Registry.ps1` / `Clear-Registry-Salud.ps1` / `Clear-Registry-Unity.ps1`.
3. Backs up the current `web.config` using `Save_WebConfig.ps1`.
4. Installs the new MSI by calling the environment-specific install script (`Install-Application.ps1`, `Install-Unity.ps1`, etc.) with all required parameters sourced from the variable group.
5. If `updateWebConfigScriptPath` is set, runs `Update-WebConfig.ps1` to patch connection strings and feature flags.
6. If `enableInsuranceHost: true`, installs `InsuranceHostInstaller.msi` via `Install-Insurance.ps1` and updates `appsettings.json` via `Update-AppJson.ps1`.

### Stage 5 — Database Migration

- Runs `Run-DatabaseMigration.ps1`, which executes `Titanium.Migration.DataAccess.Migration.exe`.
- Applies all pending schema migrations to the target database.
- Logs migration output to the pipeline console.

### Stage 6 — Upload Customer Packages

- Calls `Create-UploadWebServices.ps1` to generate `UploadFiles_WebServices.xml`.
- Runs the customer-specific `Run-UploadPackages.ps1` to push package data into the application.
- Restarts IIS (`Start-IIS.ps1`).
- Stops the maintenance page task (kills the scheduled task).

### Stage 7 — Restore Database *(conditional, failure path)*

- Runs only when `enableBackupRestore: true` AND a previous stage has failed.
- Calls `Backup-Database.ps1` in restore mode using the path set by Stage 2.
- Returns the database to its pre-deployment state.

### Stage 8 — Rollback *(failure path)*

- Runs only when a previous stage has failed.
- Uses the Azure DevOps REST API to find the **last successful** run of the upstream build pipeline.
- Downloads its artifacts and re-runs the install script to restore the previous application version.

---

## Scripts Reference

### Shared Scripts (`scripts/`)

| Script | Purpose |
|---|---|
| `Backup-Database.ps1` | SQL Server backup/restore. Writes backup path to a pipeline output variable. |
| `Clear-Registry.ps1` | Removes `HKLM:\SOFTWARE\Titanium\Origin\Install` before install. |
| `Clear-Registry-Salud.ps1` | Removes `HKLM:\SOFTWARE\Titanium\Salud\Install` before install. |
| `Clear-Registry-Unity.ps1` | Removes `HKLM:\SOFTWARE\Titanium\<AppName>\Install`. Accepts `-AppName` parameter. |
| `Copy-Artifacts.ps1` | Copies build artifacts from pipeline workspace to a local directory. |
| `Copy-MSI.ps1` | Copies one or more MSI files from the pipeline workspace to a local staging path. Used for InsuranceHost. |
| `Create-UploadWebServices.ps1` | Generates the `UploadFiles_WebServices.xml` descriptor used by customer upload scripts. |
| `Install-Application.ps1` | Generic parameterized MSI installer for Salud/Origin. Accepts all IIS and database parameters. |
| `Install-Insurance.ps1` | Silently installs `InsuranceHostInstaller.msi` with SQL Server credentials. |
| `InstallVCRedist.ps1` | Installs Visual C++ 2015 Redistributables (x86/x64) if not already present. |
| `Run-DatabaseMigration.ps1` | Runs the Titanium migration executable and logs output. |
| `Run-UploadPackages.ps1` | Non-interactive wrapper for customer upload scripts. |
| `Save_WebConfig.ps1` | Backs up `web.config` with a dated filename. |
| `Server.ps1` | HTTPS listener on port 443 serving the maintenance page. |
| `Start-IIS.ps1` | Starts IIS (W3SVC) and waits for confirmation. |
| `Stop-IIS.ps1` | Stops IIS (W3SVC) and waits for confirmation. |
| `Uninstall-Application.ps1` | Registry-based MSI uninstaller. Accepts an array of app names, supports `-Uninstall` switch. |
| `Uninstall-Insurance.ps1` | Registry-based uninstaller for the InsuranceHost application. |
| `Update-AppJson.ps1` | Updates `InsuranceSettings` in `appsettings.json` for the InsuranceHost integration. |
| `maintenance.html` | Static "Upgrade in Progress" page shown during deployments. |

### Environment-Specific Scripts (`scripts/<env>/`)

| Folder | Script | Notes |
|---|---|---|
| `MONTREAL-QA/` | `Install-Salud.ps1` | Salud MSI install for Montreal QA. |
| `MONTREAL-QA/` | `Update-WebConfig.ps1` | Patches `web.config` appSettings for Montreal. Also used by `MONTREAL-SANDBOX` and `SDT-MONTREAL`. |
| `WS-SALUD-TRUNK/` | `Install-Salud.ps1` | Salud MSI install for Salud Trunk environment. |
| `WS-SALUD-TRUNK/` | `Update-WebConfig.ps1` | web.config patch for Salud Trunk. |
| `WS100-PM-DHSV/` | `Install-Unity.ps1` | Unity MSI installer for WS100-PM-DHSV. |
| `WS114-QA-QUMC/` | `Install-Origin.ps1` | Origin MSI installer for QUMC QA. |
| `WS120-MI-LMU/` | `Install-Origin.ps1` | Origin MSI installer for LMU MI. |
| `WS120-MI-LMU/` | `Update-WebConfig.ps1` | web.config patch for LMU MI. |
| `WS120-QA-LMU/` | `Install-Origin.ps1` | Origin MSI installer for LMU QA. |
| `WS120-QA-LMU/` | `Update-WebConfig.ps1` | web.config patch for LMU QA. |

---

## Variable Groups

Each environment has a corresponding **Azure DevOps Library variable group** that provides secrets to the pipeline at runtime. Common variables stored in groups:

| Variable | Description |
|---|---|
| `privateDB` | SQL Server hostname or IP address |
| `databaseName` | Target database name |
| `dsnMssqlPassword` | SQL Server password |
| `dsnMssqlUsername` | SQL Server username |
| `reportingServicesURL` | SSRS URL |
| `reportingServicesUserName` | SSRS username |
| `reportingServicesPassword` | SSRS password |

> Variable groups must be created in the Azure DevOps **Library** before registering the pipeline. The group name must match the value in the `variables.group` field of the pipeline file.

---

## Adding a New Pipeline

Follow these steps to add a deployment pipeline for a new environment.

### Step 1 — Create the Azure DevOps resources

Before writing any code, ensure these exist in Azure DevOps:

- [ ] **Variable group** in Library (name it after the environment, e.g. `MY-NEW-ENV`). Populate all required secrets.
- [ ] **Environment** with the approval gates configured (under Pipelines → Environments).
- [ ] **Self-hosted agent** installed and registered on the target server. Note the agent name.

### Step 2 — Choose a template

| Application | Upstream build pipeline | Template to use |
|---|---|---|
| Origin | Any Salud Services 104.x | `pipeline-v1.yml` |
| Salud (Montreal region) | Salud Services 104.122 | `pipeline-v2.yml` |
| Salud (120/Trunk) | Salud Services 104.120 / Trunk | `pipeline-v3.yml` |
| Unity | Unity Services Trunk | `pipeline-v4.yml` |

If the environment also deploys InsuranceHost alongside the main app, use `pipeline-v2.yml` or `pipeline-v4.yml` and set `enableInsuranceHost: true`.

### Step 3 — Create the environment script folder

```
scripts/
└── MY-NEW-ENV/
    ├── Install-<App>.ps1    ← required
    └── Update-WebConfig.ps1 ← optional
```

Copy the closest existing install script (e.g. `scripts/WS120-QA-LMU/Install-Origin.ps1`) and update:
- Default `dsnMssqlServer`, `dsnMssqlDatabase`
- `$features` list (which MSI features to install)
- `$webAppName`, `$webAppPool`, `$installDir`

### Step 4 — Create the pipeline file

Create `pipelines/MY-NEW-ENV.yml`:

```yaml
trigger: none
pr: none

variables:
  - group: 'MY-NEW-ENV'

resources:
  pipelines:
    - pipeline: SaludServices104_120   # alias (no spaces, no special chars)
      project: Titanium
      source: "Salud Services 104.120" # exact name of the build pipeline
      trigger:
        tags:
          - ReleaseReady

extends:
  template: ../templates/pipeline-v1.yml
  parameters:
    environmentName:                  'MY-NEW-ENV'
    agentName:                        'MY-AGENT-NAME'
    installerFile:                    'Setup_Origin.msi'
    webAppName:                       'Origin'
    webAppPool:                       'TitaniumSolutionsDentalAppPool'
    enableBackupRestore:              true
    backupDirectory:                  '\\SQLSERVER\Backups\MY-NEW-ENV'
    installOriginScriptPath:          'scripts/MY-NEW-ENV/Install-Origin.ps1'
    updateWebConfigScriptPath:        'scripts/MY-NEW-ENV/Update-WebConfig.ps1'
    customerPackagesUploadScriptPath: 'C:\Build\CustomerPackages\...\Run-UploadPackages.ps1'
    customerPackagesXmlReferencePath: 'C:\Build\CustomerPackages\...'
    organization:                     'Titanium-Solutions'
    project:                          'Titanium'
    variableGroupId:                  '<group-id>'
```

> Find the variable group ID in Azure DevOps → Library → click the group → check the URL for the `variableGroupId` query parameter.

### Step 5 — Register in Azure DevOps

1. Go to **Pipelines → New Pipeline**.
2. Select **Azure Repos Git** and point to this repository.
3. Choose **Existing Azure Pipelines YAML file** and select `pipelines/MY-NEW-ENV.yml`.
4. Save (do not run yet).
5. Grant the pipeline permission to access the variable group and environment when prompted.

### Step 6 — Test

Trigger the pipeline manually for the first run. Review each stage's logs, particularly the install and web.config stages. Once confirmed working, the `ReleaseReady` tag on the upstream build will trigger it automatically going forward.

---

## Existing Environments

| Pipeline File | Environment | Template | Application | Upstream Build | Backup | Insurance Host |
|---|---|---|---|---|---|---|
| `IN-DEMO.yml` | QUMC-QA | v1 | Origin | Salud Services 104.120 | No | No |
| `MONTREAL-QA.yml` | Montreal-QA | v2 | Salud | Salud Services 104.122 | Yes | No |
| `MONTREAL-SANDBOX.yml` | MontrealSandbox | v2 | Salud | Salud Services 104.122 | No | No |
| `RCSI-CFG.yml` | RCSI | v1 | Salud | Salud Services Trunk | No | No |
| `SDT-MONTREAL.yml` | SDT-MONTREAL | v2 | Salud (French collation) | Salud Services 104.122 | No | No |
| `WS-SALUD-TRUNK.yml` | WS-SALUD | v1 | Salud | Salud Services Trunk | Yes | No |
| `WS100-PM-DHSV.yml` | WS100-PM-DHSV | v4 | Unity | Unity Services Trunk | No | No |
| `WS114-QA-QUMC.yml` | QUMC-QA | v1 | Origin | Salud Services 104.120 | Yes | No |
| `WS120-MI-LMU.yml` | WS120-MI-LMU | v1 | Origin | Salud Services 104.120 | No | No |
| `WS120-QA-LMU.yml` | LMU-QA | v1 | Origin | Salud Services 104.120 | Yes | No |
| `WSS-QA-MON.yml` | WSS-QA-MON | v2 | Origin + InsuranceHost | Salud 104.122 + InsuranceHost Trunk | Yes | Yes |

---

## Troubleshooting

### Pipeline doesn't start automatically after a build tag

- Confirm the build pipeline resource `source` name exactly matches the Azure DevOps pipeline name (case-sensitive, spaces included).
- Verify the build pipeline tagged the run with `ReleaseReady` (check the run's tags in Azure DevOps).
- Ensure the deployment pipeline has been granted access to the build pipeline resource (a prompt appears on the first run).

### Stage fails at "Install Application"

- Check that the variable group contains all required variables (`privateDB`, `databaseName`, `dsnMssqlUsername`, `dsnMssqlPassword`).
- Review the `msiexec` log typically written to `C:\Build\msiexec.log` on the agent.
- Confirm the agent is running with administrator privileges.

### IIS fails to stop/start

- Ensure the W3SVC service exists on the target server (`Get-Service W3SVC`).
- Confirm the agent service account has `SeServiceLogonRight` and administrator privileges.

### `maintenance.html` not served to users

- The `MaintenanceServer` scheduled task must be registered and run as SYSTEM with PowerShell.
- Port 443 must not be blocked by a firewall rule.
- Check the task exists: `Get-ScheduledTask -TaskName MaintenanceServer`.

### Database migration fails

- Check the migration tool path on the agent — it must be present in the build artifact.
- Review the migration log file emitted to the pipeline console for schema conflict details.
- Ensure the SQL Server user has `db_owner` rights on the target database.

### Rollback doesn't reinstall the previous version

- The pipeline uses the ADO REST API to fetch the last successful build. Confirm the upstream build pipeline has at least one prior successful run.
- Check the `organization` and `project` parameters are correct.
- Ensure the access token (`System.AccessToken`) has permission to read build artifacts.
