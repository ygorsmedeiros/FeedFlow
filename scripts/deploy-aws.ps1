[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('DEPLOY')]
    [string]$Authorization,

    [string]$StackName = 'feedflow-dev',
    [string]$Profile = 'feedflow',
    [string]$Region = 'us-east-2',
    [string]$TableName = 'FeedFlowFeedback',
    [string]$JavaHome = 'E:\Program Files\Java\jdk-17'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-SamCli {
    $command = Get-Command sam -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $knownPath = 'C:\Program Files\Amazon\AWSSAMCLI\bin\sam.cmd'
    if (Test-Path -LiteralPath $knownPath) {
        return $knownPath
    }

    throw 'AWS SAM CLI não encontrada no PATH nem no caminho padrão do Windows.'
}

function Invoke-RequiredScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    $global:LASTEXITCODE = 0
    & $Path @Parameters
    $childScriptSucceeded = $?
    $childScriptExitCode = $LASTEXITCODE

    if (-not $childScriptSucceeded -or $childScriptExitCode -ne 0) {
        throw "$FailureMessage Exit code: $childScriptExitCode."
    }
}

if ($Authorization -ne 'DEPLOY') {
    throw 'O deploy exige -Authorization DEPLOY.'
}

$samCli = Resolve-SamCli

Push-Location $repositoryRoot
try {
    Invoke-RequiredScript `
        -Path .\scripts\build-and-test.ps1 `
        -Parameters @{ JavaHome = $JavaHome } `
        -FailureMessage 'O script de build e testes falhou. O deploy foi interrompido.'

    Invoke-RequiredScript `
        -Path .\scripts\validate-sam.ps1 `
        -FailureMessage 'O script de validação SAM falhou. O deploy foi interrompido.'

    $functionZip = Join-Path $repositoryRoot 'feedflow-api\target\function.zip'
    if (-not (Test-Path -LiteralPath $functionZip)) {
        throw 'O function.zip validado não foi encontrado. O deploy foi interrompido.'
    }
    $functionZipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $functionZip).Hash
    $notificationsFunctionZip = Join-Path $repositoryRoot `
        'feedflow-notifications\target\function.zip'
    if (-not (Test-Path -LiteralPath $notificationsFunctionZip)) {
        throw 'O function.zip de notificações validado não foi encontrado. O deploy foi interrompido.'
    }
    $notificationsFunctionZipHash = `
        (Get-FileHash -Algorithm SHA256 -LiteralPath $notificationsFunctionZip).Hash

    Write-Host ''
    Write-Host 'Parâmetros do deploy aguardando confirmação:'
    Write-Host "Stack: $StackName"
    Write-Host "Perfil: $Profile"
    Write-Host "Região: $Region"
    Write-Host "Tabela: $TableName"
    Write-Host "Artefato API: $functionZip"
    Write-Host "SHA-256 API: $functionZipHash"
    Write-Host "Artefato notificações: $notificationsFunctionZip"
    Write-Host "SHA-256 notificações: $notificationsFunctionZipHash"
    Write-Host ''

    Write-Host 'O SAM criará um change set, exibirá as mudanças e pedirá nova confirmação antes de executá-las.'
    $global:LASTEXITCODE = 0
    & $samCli deploy `
        --template-file template.yaml `
        --stack-name $StackName `
        --profile $Profile `
        --region $Region `
        --capabilities CAPABILITY_IAM `
        --resolve-s3 `
        --confirm-changeset `
        --no-fail-on-empty-changeset `
        --parameter-overrides `
            EnvironmentName=dev `
            FeedbackTableName=$TableName `
            LogRetentionDays=14

    $samDeploySucceeded = $?
    $samDeployExitCode = $LASTEXITCODE
    if (-not $samDeploySucceeded -or $samDeployExitCode -ne 0) {
        throw "O deploy SAM não foi concluído. Exit code: $samDeployExitCode."
    }
}
finally {
    Pop-Location
}
