param(
  [string]$TerragruntPath = 'terragrunt',
  [string]$TerraformPath = 'terraform',
  [switch]$ValidateTerraform
)
$ErrorActionPreference = 'Stop'
$layout = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $layout -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('agentic-sre-tg-' + [guid]::NewGuid())
$values = @{
  TG_TF_PATH = $TerraformPath
  TG_STATE_RESOURCE_GROUP = 'validation-only'
  TG_STATE_STORAGE_ACCOUNT = 'validationonly'
  TG_STATE_KEY = $null
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
  if ($LASTEXITCODE -ne 0) { throw 'Formatting failed' }
  New-Item -ItemType Directory -Path $fixture | Out-Null
  Copy-Item -LiteralPath "$layout/root.hcl" -Destination $fixture
  foreach ($key in $values.Keys) {
    $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
    [Environment]::SetEnvironmentVariable($key, $values[$key], 'Process')
  }
  $variables = Get-Content "$repo/modules/agentic-sre-stack/variables.tf" -Raw
  $declared = [regex]::Matches($variables, 'variable "([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  foreach ($environmentName in @('poc','prod')) {
    $destination = Join-Path $fixture "environments/$environmentName"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($fileName in @('common.hcl','terragrunt.hcl','.terraform.lock.hcl')) {
      Copy-Item -LiteralPath "$layout/environments/$environmentName/$fileName" -Destination $destination
    }
    $unit = Join-Path $destination 'terragrunt.hcl'
    $text = Get-Content -LiteralPath $unit -Raw
    $source = ($repo.Replace('\','/') + '/modules//agentic-sre-stack')
    $text = [regex]::Replace($text, '(?m)^  source = .*$', ('  source = "' + $source + '"'))
    Set-Content -LiteralPath $unit -Value $text -Encoding UTF8
    $json = & $TerragruntPath render --json --config $unit
    if ($LASTEXITCODE -ne 0) { throw "Render failed: $environmentName" }
    $rendered = $json | ConvertFrom-Json
    $inputs = @($rendered.inputs.PSObject.Properties.Name)
    foreach ($name in $inputs) {
      if ($name -notin $declared) { throw "Unknown input: $environmentName/$name" }
    }
    foreach ($block in [regex]::Split($variables, '(?m)^variable "') | Select-Object -Skip 1) {
      $name = $block.Split('"')[0]
      if ($block -notmatch '\bdefault\s*=' -and $name -notin $inputs) { throw "Missing input: $environmentName/$name" }
    }
    if ($rendered.remote_state.config.key -ne "agentic-sre/$environmentName.tfstate") { throw "Unexpected combined state key for ${environmentName}: '$($rendered.remote_state.config.key)'" }
    if ($ValidateTerraform) {
      & $TerragruntPath run --no-auto-init --non-interactive --working-dir $destination -- init -backend=false -input=false -lockfile=readonly
      if ($LASTEXITCODE -ne 0) { throw "Initialization failed: $environmentName" }
      & $TerragruntPath run --no-auto-init --non-interactive --working-dir $destination -- validate
      if ($LASTEXITCODE -ne 0) { throw "Provider validation failed: $environmentName" }
    }
    Write-Output "PASS $environmentName combined stack (six resource modules)"
  }
  Write-Output 'Both combined stacks passed configuration checks. No Azure access or Terraform plan performed.'
} finally {
  foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
  if ((Test-Path $fixture) -and (Split-Path $fixture -Leaf) -like 'agentic-sre-tg-*' -and (Split-Path $fixture -Parent) -eq ([IO.Path]::GetTempPath()).TrimEnd([char[]]'\/')) {
    if ($ValidateTerraform -and $env:OS -eq 'Windows_NT') {
      Write-Output "Windows provider fixture retained at $fixture."
    } else {
      Remove-Item -LiteralPath $fixture -Recurse -Force
    }
  }
}
