# DVOP_Template — Deployment Pipeline Templates

This repository contains reusable Azure DevOps (YAML) deployment pipelines and supporting PowerShell scripts for deploying the **Titanium Solutions Dental** applications (Origin / Salud / Unity) across multiple customer environments.

## Repository Structure

```
DVOP_Template/
├── configs/                  # (Reserved for future configuration files)
├── pipelines/                # Per-environment pipeline definitions
│   ├── IN-DEMO.yml
│   ├── MONTREAL-QA.yml
│   ├── MONTREAL-SANDBOX.yml
│   ├── RCSI-CFG.yml
│   ├── SDT-MONTREAL.yml
│   ├── WS-SALUD-TRUNK.yml
│   ├── WS100-PM-DHSV.yml
│   ├── WS114-QA-QUMC.yml
│   ├── WS120-MI-LMU.yml
│   ├── WS120-QA-LMU.yml
│   └── WSS-QA-MON.yml
├── scripts/                  # Shared & environment-specific PowerShell scripts
│   ├── Backup-Database.ps1
│   ├── Clear-Registry.ps1
│   ├── Clear-Registry-Salud.ps1
│   ├── Clear-Registry-Unity.ps1
│   ├── Copy-Artifacts.ps1
│   ├── Copy-MSI.ps1
│   ├── Create-UploadWebServices.ps1
│   ├── Install-Application.ps1
│   ├── Install-Insurance.ps1
│   ├── InstallVCRedist.ps1
│   ├── maintenance.html
│   ├── Run-DatabaseMigration.ps1
│   ├── Run-UploadPackages.ps1
│   ├── Save_WebConfig.ps1
│   ├── Server.ps1
│   ├── Start-IIS.ps1
│   ├── Stop-IIS.ps1
│   ├── Uninstall-Application.ps1
│   ├── Uninstall-Insurance.ps1
│   ├── Update-AppJson.ps1
│   ├── MONTREAL-QA/          # Montreal-specific install & config
│   ├── WS-SALUD-TRUNK/       # Salud Trunk-specific install & config
│   ├── WS100-PM-DHSV/        # Unity (DHSV)-specific installer
│   ├── WS114-QA-QUMC/        # QUMC-specific installer
│   ├── WS120-MI-LMU/         # LMU MI-specific installer & config
│   └── WS120-QA-LMU/         # LMU QA-specific installer & config
└── templates/                # Shared pipeline templates (the core logic)
    ├── pipeline-v1.yml       # Template for Origin deployments
    ├── pipeline-v2.yml       # Template for Salud 104.122 deployments
    ├── pipeline-v3.yml       # Template for Salud 104.120 / Trunk deployments
    └── pipeline-v4.yml       # Template for Unity deployments
```

## How It Works

### Design Pattern: Template-Based Pipelines

The repo follows a **template/extends** pattern:

1. **Pipeline files** (`pipelines/*.yml`) — One per customer environment. Each file is lightweight: it declares trigger rules, a variable group, a resource pipeline, and then **extends** a shared template with environment-specific parameters.
2. **Template files** (`templates/pipeline-v*.yml`) — Contain all the deployment stages and logic. Pipeline files never duplicate stage definitions; they just pass parameters into the template.
3. **Scripts** (`scripts/`) — PowerShell scripts invoked by the templates at runtime on the self-hosted agent.

```
pipelines/WS120-QA-LMU.yml
        │
        │  extends
        ▼
templates/pipeline-v1.yml          ──► scripts/*.ps1
        (8 stages)                      (run on agent)
```

### Pipeline File Anatomy

Every pipeline file in `pipelines/` has the same structure:

```yaml
trigger: none          # Manual trigger only (no CI)
pr: none               # No PR triggers

variables:
  - group: '<Variable-Group-Name>'   # Azure DevOps Library variable group

resources:
  pipelines:
    - pipeline: <Alias>
      project: Titanium
      source: "<Build Pipeline Name>"
      trigger:
        tags:
          - ReleaseReady             # Triggers on the upstream build tagging

extends:
  template: ../templates/pipeline-v1.yml
  parameters:
    environmentName:                  '<Environment>'
    agentName:                        '<Self-Hosted-Agent>'
    webAppPool:                       'TitaniumSolutionsDentalAppPool'
    customerPackagesUploadScriptPath: '<path to Run-UploadPackages.ps1>'
    customerPackagesXmlReferencePath: '<path to customer XML>'
    enableBackupRestore:              true|false
    backupDirectory:                  '<UNC path>'           # only when backup enabled
    installOriginScriptPath:          'scripts/<env>/Install-Origin.ps1'
    ...
```

**Key parameters:**

| Parameter | Purpose |
|---|---|
| `agentName` | Selects the self-hosted agent for this environment |
| `environmentName` | Azure DevOps environment (used for approval gates) |
| `enableBackupRestore` | Enables the database backup, restore, and rollback stages |
| `backupDirectory` | Network share for database backups (required when backup is enabled) |
| `installOriginScriptPath` | Path to the environment-specific MSI install script |
| `updateWebConfigScriptPath` | Path to the environment-specific web.config update script |
| `customerPackagesUploadScriptPath` | Path to the customer-packages upload script |
| `customerPackagesXmlReferencePath` | Path to the XML reference files for package upload |
| `variableGroupId` | Azure DevOps variable group ID (used for REST API calls) |

### Deployment Stages

The shared templates define up to **8 sequential stages**:

```
1. Deploy Approval
       │
2. Backup Database  ←── (conditional: enableBackupRestore = true)
       │
3. Fetch Salud Artifacts
       │
4. Install Application
       │
5. Database Migration
       │
6. Upload Customer Packages
       │
7. Restore Database  ←── (runs only on failure, conditional)
       │
8. Rollback           ←── (runs only on failure, conditional)
```

#### Stage Details

| # | Stage | Description |
|---|---|---|
| 1 | **Deploy Approval** | Environment deployment gate. Stops IIS, copies the maintenance page, and starts a lightweight HTTPS listener so end users see an "Upgrade in Progress" page while deployment runs. |
| 2 | **Backup Database** | Takes a `.bak` backup of the SQL Server database to a network share. Filename includes the date. Skipped if `enableBackupRestore` is `false`. |
| 3 | **Fetch Salud Artifacts** | Downloads the MSI installer and build artifacts from the upstream build pipeline (`SaludServices*`) using the Azure DevOps REST API. Copies them to a local staging directory. |
| 4 | **Install Application** | Uninstalls the previous application version via `msiexec /x`, clears the registry, backs up `web.config`, installs the new MSI, and optionally runs the `Update-WebConfig.ps1` script to patch connection strings or feature flags. |
| 5 | **Database Migration** | Runs `Titanium.Migration.DataAccess.Migration.exe` against the target database to apply schema changes. |
| 6 | **Upload Customer Packages** | Creates the `UploadFiles_WebServices.xml` descriptor and runs the customer-specific upload script to push packages (XML/config data) into the application. Restarts IIS and stops the maintenance page. |
| 7 | **Restore Database** | On failure, restores the database from the backup taken in stage 2. Only runs when `enableBackupRestore` is `true` and a previous stage failed. |
| 8 | **Rollback** | On failure, re-downloads the **previous** successful build's artifacts and reinstalls them, effectively rolling the application back to the last known good version. |

### Template Versions

| Template | Upstream Pipeline | Installer | Notes |
|---|---|---|---|
| `pipeline-v1.yml` | Varies per pipeline file | `Setup_Origin.msi` (default) | Base template. Used by most environments. |
| `pipeline-v2.yml` | `Salud Services 104.122` | `Setup_Salud.msi` | More parameterized (e.g. `webAppName`, `poolName`, `enableInsuranceHost`). Used by Montreal environments. |
| `pipeline-v3.yml` | `Salud Services 104.120` / Trunk | `Setup_Salud.msi` | Based on v1 with Salud-specific overrides. |
| `pipeline-v4.yml` | `Unity Services Trunk` | `Setup_Unity.msi` | Unity application deployments. Supports `AppName` and `enableInsuranceHost` parameters. |

### Resource Triggers

Pipelines are triggered by the upstream **build pipeline** tagging a run with `ReleaseReady`:

```
Build Pipeline (e.g. "Salud Services 104.120")
        │
        │  tags: [ReleaseReady]
        ▼
Deployment Pipeline (this repo)
```

This means deployments happen automatically when a build is tagged, or can be triggered manually from Azure DevOps.

## Scripts Reference

### Shared Scripts (`scripts/`)

| Script | Purpose |
|---|---|
| `Backup-Database.ps1` | Backs up a SQL Server database to a `.bak` file at the specified path. Sets a pipeline output variable with the backup file path. |
| `Clear-Registry.ps1` | Exports and removes the `HKLM:\SOFTWARE\Titanium\Origin\Install` registry key to ensure a clean install. |
| `Clear-Registry-Salud.ps1` | Exports and removes the `HKLM:\SOFTWARE\Titanium\Salud\Install` registry key before a Salud installation. |
| `Clear-Registry-Unity.ps1` | Generic registry clearer; accepts an `AppName` parameter and removes `HKLM:\SOFTWARE\Titanium\<AppName>\Install`. |
| `Copy-Artifacts.ps1` | Copies specified build artifacts from source to destination directory. |
| `Copy-MSI.ps1` | Copies one or more MSI/artifact files from a pipeline workspace path to a local destination directory. |
| `Create-UploadWebServices.ps1` | Generates `UploadFiles_WebServices.xml` with URL and authentication details for package upload. |
| `Install-Application.ps1` | Generic MSI installer for Salud/Origin. Accepts all connection and IIS parameters; used as a shared alternative to environment-specific install scripts. |
| `Install-Insurance.ps1` | Silently installs the `InsuranceHostInstaller.msi` with SQL Server connection parameters. |
| `InstallVCRedist.ps1` | Checks for and installs Visual C++ 2015 Redistributables (x86 + x64) if missing. |
| `Run-DatabaseMigration.ps1` | Executes the Titanium database migration tool with connection parameters and logs output. |
| `Run-UploadPackages.ps1` | Wrapper that sources `UploadZipFile.ps1` and overrides `Read-Host` for unattended execution. |
| `Save_WebConfig.ps1` | Backs up `web.config` to `C:\Web.config_Backups\` with a dated filename. |
| `Server.ps1` | Starts an HTTPS listener on port 443 that serves the maintenance page during deployments. |
| `Start-IIS.ps1` | Starts the IIS (W3SVC) service with a timeout-based wait loop. |
| `Stop-IIS.ps1` | Stops the IIS (W3SVC) service and waits for confirmation. |
| `Uninstall-Application.ps1` | Searches the registry for installed applications matching one or more names and silently uninstalls them via `msiexec /x`. |
| `Uninstall-Insurance.ps1` | Searches for and uninstalls the InsuranceHost application by name. |
| `Update-AppJson.ps1` | Finds `appsettings.json` recursively and updates `InsuranceSettings` fields (TransmissionSystem, API keys, credentials) for the InsuranceHost integration. |
| `maintenance.html` | Static HTML page displayed to users during deployments ("Upgrade in Progress"). |

### Environment-Specific Scripts (`scripts/<environment>/`)

Each environment subfolder contains scripts tailored to that deployment target:

- **`Install-Origin.ps1` / `Install-Salud.ps1` / `Install-Unity.ps1`** — MSI installation with environment-specific defaults (database server, database name, features to install, installer UI mode).
- **`Update-WebConfig.ps1`** — Patches `web.config` `appSettings` entries (e.g., reporting service credentials, security flags) after installation.

## Environments

| Pipeline File | Environment | Template | Upstream Build | Backup Enabled | Insurance Host |
|---|---|---|---|---|---|
| `IN-DEMO.yml` | QUMC-QA | v1 | Salud Services 104.120 | No | No |
| `MONTREAL-QA.yml` | Montreal-QA | v2 | Salud Services 104.122 | Yes | No |
| `MONTREAL-SANDBOX.yml` | MontrealSandbox | v2 | Salud Services 104.122 | No | No |
| `RCSI-CFG.yml` | RCSI | v1 | Salud Services Trunk | No | No |
| `SDT-MONTREAL.yml` | SDT-MONTREAL (French Collation) | v2 | Salud Services 104.122 | No | No |
| `WS-SALUD-TRUNK.yml` | WS-SALUD | v1 | Salud Services Trunk | Yes | No |
| `WS100-PM-DHSV.yml` | WS100-PM-DHSV | v4 | Unity Services Trunk | No | No |
| `WS114-QA-QUMC.yml` | QUMC-QA | v1 | Salud Services 104.120 | Yes | No |
| `WS120-MI-LMU.yml` | WS120-MI-LMU | v1 | Salud Services 104.120 | No | No |
| `WS120-QA-LMU.yml` | LMU-QA | v1 | Salud Services 104.120 | Yes | No |
| `WSS-QA-MON.yml` | WSS-QA-MON | v2 | Salud Services 104.122 + InsuranceHost Trunk | Yes | Yes |

## Adding a New Environment

1. **Create a pipeline file** in `pipelines/` — copy an existing one and update the variable group, agent name, environment name, and paths.
2. **Create an environment script folder** in `scripts/<env-name>/` with an `Install-Origin.ps1` or `Install-Salud.ps1` tailored to the target server (database connection, features, etc.).
3. **(Optional)** Add an `Update-WebConfig.ps1` if the environment needs custom `web.config` patches after installation.
4. **Create the Azure DevOps resources**: variable group in the Library, environment with approval gates, and self-hosted agent on the target server.
5. **Register the pipeline** in Azure DevOps pointing to the new YAML file.

## Prerequisites

- **Azure DevOps** project with Library variable groups and environments configured.
- **Self-hosted agents** installed on each target server, named to match the `agentName` parameter.
- **SQL Server** accessible from the agent with credentials stored in variable groups.
- **IIS** configured on the target server with the expected application pool.
- **Visual C++ 2015 Redistributables** (installed automatically by the pipeline if missing).
