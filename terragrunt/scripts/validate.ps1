param(
  [string]$TerragruntPath = 'terragrunt',
  [string]$TerraformPath = 'terraform',
  [switch]$ValidateTerraform
)
$ErrorActionPreference = 'Stop'
$layout = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $layout -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('agentic-sre-tg-' + [guid]::NewGuid())
$environmentValues = @{
  TG_STATE_RESOURCE_GROUP = 'validation-only'
  TG_STATE_STORAGE_ACCOUNT = 'validationonly'
  TG_TF_PATH = $TerraformPath
  TG_PROD_SUBSCRIPTION_ID = '00000000-0000-0000-0000-000000000001'
  TG_PROD_TENANT_ID = '00000000-0000-0000-0000-000000000002'
  TG_PROD_COST_CENTER = 'validation'
  TG_PROD_POSTGRES_ADMIN_OBJECT_ID = '00000000-0000-0000-0000-000000000003'
  TG_PROD_FOUNDRY_PROJECT_ENDPOINT = 'https://validation.services.ai.azure.com/api/projects/validation'
  TG_PROD_FUNCTION_API_IDENTIFIER_URI = 'api://00000000-0000-0000-0000-000000000004'
  TG_PROD_KIBANA_ALERT_SEND_ROLE_ID = '00000000-0000-0000-0000-000000000005'
  TG_PROD_POSTGRES_FIREWALL_RULES = '{"validation":{"start_ip_address":"192.0.2.1","end_ip_address":"192.0.2.1"}}'
}
$previous = @{}
try {
  & $TerragruntPath hcl fmt --check --working-dir (Join-Path $layout 'environments')
  if ($LASTEXITCODE -ne 0) { throw 'Environment formatting check failed' }
  New-Item -ItemType Directory -Path $fixture | Out-Null
  Copy-Item -LiteralPath (Join-Path $layout 'root.hcl') -Destination $fixture
  foreach ($envName in @('poc', 'prod')) {
    $destination = Join-Path $fixture "environments/$envName"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -LiteralPath "$layout/environments/$envName/common.hcl" -Destination $destination
    foreach ($moduleName in @('resource-group', 'app-registrations', 'event-hubs', 'foundry', 'function-app', 'postgresql')) {
      New-Item -ItemType Directory -Path "$destination/$moduleName" -Force | Out-Null
      Copy-Item -LiteralPath "$layout/environments/$envName/$moduleName/terragrunt.hcl" -Destination "$destination/$moduleName"
      Copy-Item -LiteralPath "$layout/environments/$envName/$moduleName/.terraform.lock.hcl" -Destination "$destination/$moduleName"
    }
  }
  foreach ($key in $environmentValues.Keys) {
    $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
    [Environment]::SetEnvironmentVariable($key, $environmentValues[$key], 'Process')
  }
  # The temporary fixture also allows validation placeholders during render.
  foreach ($common in Get-ChildItem "$fixture/environments" -Recurse -Filter common.hcl) {
    $text = Get-Content -LiteralPath $common.FullName -Raw
    $moduleRoot = (Join-Path $repo 'modules').Replace('\', '/')
    $text = [regex]::Replace($text, '(?m)^  iac_modules_repo = .*$', ('  iac_modules_repo = "' + $moduleRoot + '"'))
    Set-Content -LiteralPath $common.FullName -Value $text -Encoding UTF8
  }
  $count = 0
  foreach ($unit in Get-ChildItem "$fixture/environments" -Recurse -Filter terragrunt.hcl) {
    $text = Get-Content -LiteralPath $unit.FullName -Raw
    $text = [regex]::Replace($text, 'skip_outputs\s*=\s*get_terraform_command\(\) == "validate"', 'skip_outputs = true')
    $text = $text.Replace('["validate"]', '["render", "init", "validate"]')
    Set-Content -LiteralPath $unit.FullName -Value $text -Encoding UTF8
    $json = & $TerragruntPath render --json --config $unit.FullName
    if ($LASTEXITCODE -ne 0) { throw "Render failed: $($unit.FullName)" }
    $rendered = $json | ConvertFrom-Json
    $module = $unit.Directory.Name
    $variables = Get-Content "$repo/modules/$module/variables.tf" -Raw
    $declared = [regex]::Matches($variables, 'variable "([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    $inputs = @($rendered.inputs.PSObject.Properties.Name)
    foreach ($inputName in $inputs) {
      if ($inputName -notin $declared) { throw "Unknown input: $module/$inputName" }
    }
    foreach ($block in [regex]::Split($variables, '(?m)^variable "') | Select-Object -Skip 1) {
      $name = $block.Split('"')[0]
      if ($block -notmatch '\bdefault\s*=' -and $name -notin $inputs) { throw "Missing input: $module/$name" }
    }
    $expectedKey = "agentic-sre/terragrunt/environments/$($unit.Directory.Parent.Name)/$module/terraform.tfstate"
    if ($rendered.remote_state.config.key -ne $expectedKey) { throw "Unexpected state key: $module" }
    if (-not (Test-Path ($rendered.terraform.source.Replace('//', '/')))) { throw "Module source does not exist: $module" }
    if ($ValidateTerraform) {
      & $TerragruntPath run --no-auto-init --non-interactive --working-dir $unit.Directory.FullName -- init -backend=false -input=false -lockfile=readonly
      if ($LASTEXITCODE -ne 0) { throw "Provider initialization failed: $($unit.FullName)" }
      & $TerragruntPath run --no-auto-init --non-interactive --working-dir $unit.Directory.FullName -- validate
      if ($LASTEXITCODE -ne 0) { throw "Terraform validation failed: $($unit.FullName)" }
    }
    $count++
    Write-Output "PASS $($unit.Directory.Parent.Name)/$module"
  }
  if ($count -ne 12) { throw "Expected 12 units, found $count" }
  Write-Output 'Validated 12 unit renders, module input names, required inputs, module paths, and state keys. No Azure access or Terraform plan performed.'
  if ($ValidateTerraform) { Write-Output 'Terraform provider validation also passed for all 12 units with backend initialization disabled.' }
} finally {
  foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
  # Delete only this invocation's unique temporary directory.
  if ((Test-Path $fixture) -and (Split-Path $fixture -Leaf) -like 'agentic-sre-tg-*' -and (Split-Path $fixture -Parent) -eq ([IO.Path]::GetTempPath()).TrimEnd([char[]]'\/')) {
    if ($ValidateTerraform -and $env:OS -eq 'Windows_NT') {
      Write-Output "Windows provider validation fixture retained at $fixture (provider paths exceed legacy PowerShell limits)."
    } else {
      Remove-Item -LiteralPath $fixture -Recurse -Force
    }
  }
}
