$ErrorActionPreference = 'Stop'
if (!$env:ARM_SUBSCRIPTION_ID -or !$env:ARM_TENANT_ID) { throw 'Set ARM_SUBSCRIPTION_ID and ARM_TENANT_ID.' }
$account = az account show -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $account.id -ne $env:ARM_SUBSCRIPTION_ID -or $account.tenantId -ne $env:ARM_TENANT_ID) { throw 'Azure account does not match configured environment.' }
