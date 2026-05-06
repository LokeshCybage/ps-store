---
name: azure-pipelines
description: Author Azure DevOps Pipelines YAML with a practical workflow and copy/paste templates (triggers, variables, stages/jobs/steps, templates, matrix, artifacts). Use when the user mentions Azure Pipelines, Azure DevOps CI/CD, `azure-pipelines.yml`, pipeline templates, stages/jobs/steps, conditions, variables, matrices, or pipeline YAML design.
---

# Azure Pipelines

Helps the agent author Azure DevOps Pipelines YAML with a practical workflow and ready-to-copy templates.

References:
- skills.sh source: https://skills.sh/microsoft/vscode/azure-pipelines
- Microsoft Learn: https://learn.microsoft.com/en-us/azure/devops/pipelines/?view=azure-devops

## Quick Start

When the user asks to “set up a pipeline” or “update Azure Pipelines YAML”, follow this:

1. Pick the pipeline shape (single-stage vs multi-stage).
2. Add triggers (`trigger` / `pr`) and path filters to reduce noise.
3. Create one stage per intent (Build, Test, Package, Deploy).
4. Add publish steps (test results, code coverage, pipeline artifacts).
5. Extract templates when a pattern repeats (jobs/steps).
6. Add a matrix when OS/versions multiply.

Conventions/enforcement live in `.cursor/rules/azure-pipelines.mdc`. This skill focuses on authoring workflow + patterns.

## Authoring workflow

### 1) Start from a minimal, correct skeleton

Use this when you need the smallest “CI builds on main + PR validation” pipeline.

```yaml
trigger:
  branches:
    include: [main]
  paths:
    exclude:
      - docs/*
      - '**/*.md'

pr:
  branches:
    include: [main]
  paths:
    exclude:
      - docs/*
      - '**/*.md'

variables:
  - name: buildConfiguration
    value: Release

pool:
  vmImage: ubuntu-22.04

stages:
  - stage: CI
    jobs:
      - job: buildAndTest
        displayName: Build and test
        steps:
          - checkout: self
            fetchDepth: 1
          - script: |
              set -euo pipefail
              echo "TODO: build"
            displayName: Build
          - script: |
              set -euo pipefail
              echo "TODO: test"
            displayName: Test
```

### 2) Add variables & variable groups (secrets)

Use this when you need shared secrets (service connection names, tokens, etc):

```yaml
variables:
  - group: shared-secrets
  - name: buildConfiguration
    value: Release
```

### 3) Publish test results, coverage, and build outputs

Use the standard publishing tasks so results show up in the Azure DevOps UI:

```yaml
steps:
  - script: |
      set -euo pipefail
      ./scripts/test.sh
    displayName: Run tests

  - task: PublishTestResults@2
    displayName: Publish test results
    condition: succeededOrFailed()
    inputs:
      testResultsFormat: JUnit
      testResultsFiles: '**/test-results.xml'

  - task: PublishPipelineArtifact@1
    displayName: Publish artifact
    inputs:
      targetPath: 'dist'
      artifact: 'drop'
```

### 4) Use a matrix when you need multiple OS/versions

```yaml
jobs:
  - job: build
    strategy:
      matrix:
        linux:
          vmImage: ubuntu-22.04
        windows:
          vmImage: windows-2022
    pool:
      vmImage: $(vmImage)
    steps:
      - script: echo "build on $(vmImage)"
        displayName: Build
```

### 5) Extract templates when duplication starts

Use templates for repeated job/step patterns. Keep templates in `.azure-pipelines/templates/`.

### Templates pattern

`.azure-pipelines/templates/build-job.yml`:

```yaml
parameters:
  - name: name
    type: string
  - name: pool
    type: object
    default: { vmImage: ubuntu-latest }
  - name: steps
    type: stepList
    default: []

jobs:
  - job: ${{ parameters.name }}
    pool: ${{ parameters.pool }}
    steps: ${{ parameters.steps }}
```

Consumed by:

```yaml
jobs:
  - template: templates/build-job.yml
    parameters:
      name: linux
      pool:
        vmImage: ubuntu-22.04
      steps:
        - checkout: self
        - script: |
            set -euo pipefail
            echo "build"
          displayName: Build
```

### 6) Add conditions when the logic needs it

Use conditions to express intent (e.g., only publish on `main`):

```yaml
- task: PublishPipelineArtifact@1
  displayName: Publish artifact (main only)
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  inputs:
    targetPath: 'dist'
    artifact: 'drop'
```

## Ready-to-copy templates

### Minimal single-stage CI (good starting point)

```yaml
trigger:
  branches:
    include: [main]

pr:
  branches:
    include: [main]

pool:
  vmImage: ubuntu-22.04

stages:
  - stage: CI
    jobs:
      - job: build
        displayName: Build
        steps:
          - checkout: self
          - script: |
              set -euo pipefail
              echo "build"
            displayName: Build
```

### Multi-stage build/test + publish artifact

```yaml
trigger:
  branches: { include: [main] }
pr:
  branches: { include: [main] }

pool:
  vmImage: ubuntu-22.04

stages:
  - stage: BuildTest
    displayName: Build and test
    jobs:
      - job: build
        steps:
          - checkout: self
          - script: |
              set -euo pipefail
              echo "build"
            displayName: Build
          - script: |
              set -euo pipefail
              echo "test"
            displayName: Test
          - task: PublishTestResults@2
            displayName: Publish test results
            condition: succeededOrFailed()
            inputs:
              testResultsFormat: JUnit
              testResultsFiles: '**/test-results.xml'

  - stage: Package
    displayName: Package
    dependsOn: BuildTest
    condition: succeeded()
    jobs:
      - job: package
        steps:
          - checkout: self
          - script: |
              set -euo pipefail
              mkdir -p dist
              echo "artifact" > dist/hello.txt
            displayName: Create artifact
          - task: PublishPipelineArtifact@1
            displayName: Publish artifact
            inputs:
              targetPath: 'dist'
              artifact: 'drop'
```

## Appendix: Validate and operate pipelines (optional)

### Local validation (preview/expand YAML)

If you have an existing pipeline definition ID, preview YAML expansion to catch template/schema issues early.

```bash
az --version
az extension show --name azure-devops || az extension add --name azure-devops
az login
az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>

# Preview a run without executing (returns expanded YAML or schema errors)
az rest --method POST \
  --url "https://dev.azure.com/<org>/<project>/_apis/pipelines/<definitionId>/preview?api-version=7.1-preview.1" \
  --body '{ "previewRun": true, "yamlOverride": "'"$(cat azure-pipelines.yml | sed 's/\"/\\\"/g' | tr -d \"\\n\")"'" }'
```

Editor-side: install the **Azure Pipelines** VS Code extension (`ms-azure-devops.azure-pipelines`) for inline schema validation while editing.

### Queue / status / cancel / artifacts (Azure CLI)

```bash
az pipelines run --id <definitionId> --branch my-feature
az pipelines runs list --branch my-feature --top 10 -o table
az pipelines runs show --id <runId>
az pipelines runs cancel --id <runId>
az pipelines runs artifact download --run-id <runId> --artifact-name <name> --path ./_artifacts
