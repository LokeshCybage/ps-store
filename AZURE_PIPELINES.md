# Azure Pipelines CI/CD (ps-store)

This repo includes **separate CI pipelines per service** (build/test/coverage/SonarQube + push to ACR + Trivy scan) and a **CD pipeline** to deploy to AKS using Helm.

## Pipelines (YAML files)

- CI
  - `azure-pipelines-ci-frontend.yml`
  - `azure-pipelines-ci-game-catalog.yml`
  - `azure-pipelines-ci-user-service.yml`
  - `azure-pipelines-ci-order-service.yml`
- CD
  - `azure-pipelines-cd-aks.yml`
- Terraform (manual destroy)
  - `azure-pipelines-tf-destroy.yml` — on-demand `terraform plan -destroy` / `apply` using remote state; uses `.azure-pipelines/templates/terraform-destroy.yml`

Shared templates live under `.azure-pipelines/templates/`.

## Required Azure DevOps service connections

- **ACR (Docker registry service connection)** used by `Docker@2`
  - Create a **Docker Registry** service connection pointing at your ACR.
  - Set pipeline variable: `ACR_SERVICE_CONNECTION` = `<service-connection-name>`

- **SonarQube service connection** used by `SonarQubePrepare@7`
  - Create a **SonarQube** service connection (Server URL + token).
  - Set pipeline variable: `SONARQUBE_SERVICE_CONNECTION` = `<service-connection-name>`

- **Azure Resource Manager** service connection used by `AzureCLI@2` (CD)
  - Grant it access to the AKS resource group (and ACR if needed).
  - Set pipeline variable: `AZURE_SUBSCRIPTION_SERVICE_CONNECTION` = `<service-connection-name>`

## Required variables (recommended: Variable Group)

Create a variable group (example: `ps-store-shared`) and link it to all pipelines.

### ACR

- `ACR_LOGIN_SERVER`
  - Example: `myacr.azurecr.io`
  - Used by CD (Helm image repositories)

### AKS (CD only)

- `AKS_RESOURCE_GROUP`
- `AKS_CLUSTER_NAME`

### Terraform remote state + destroy pipeline

Used by `azure-pipelines-tf-destroy.yml` (variable group `ps-store-shared`):

- `TF_BACKEND_RESOURCE_GROUP` — resource group containing the Terraform state storage account
- `TF_BACKEND_STORAGE_ACCOUNT` — storage account name for remote state
- `TF_BACKEND_CONTAINER` — blob container name (e.g. `tfstate`)
- `TF_LOCATION` — Azure region passed as Terraform `-var=location=...` (must match the region used when resources were created)

State blob key per environment is `ps-store/<dev|prod>/terraform.tfstate` (set by the pipeline from the **Target** parameter).

### SonarQube per-service project keys/names

Each CI pipeline expects a project key + name:

- Frontend
  - `SONAR_FRONTEND_PROJECT_KEY`
  - `SONAR_FRONTEND_PROJECT_NAME`
- Game catalog (Python)
  - `SONAR_GAME_CATALOG_PROJECT_KEY`
  - `SONAR_GAME_CATALOG_PROJECT_NAME`
- User service (.NET)
  - `SONAR_USER_SERVICE_PROJECT_KEY`
  - `SONAR_USER_SERVICE_PROJECT_NAME`
- Order service (Node)
  - `SONAR_ORDER_SERVICE_PROJECT_KEY`
  - `SONAR_ORDER_SERVICE_PROJECT_NAME`

## Environments (CD approvals)

The CD pipeline uses deployment jobs with:

- `environment: ps-store-dev`
- `environment: ps-store-prod`

Configure **approvals/checks** on `ps-store-prod` in Azure DevOps if you want gated production releases.

## Image tagging convention

CI uses:

- `imageTag = $(Build.SourceVersion)` (the commit SHA)

CD deploys the same tag via:

- `imageTag = $(Build.SourceVersion)`

This works when CI has already pushed images for that commit into ACR.

