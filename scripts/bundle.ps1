<#
.SYNOPSIS
    Builds a signed release Android App Bundle (.aab) ready for upload to
    Google Play, and archives the R8 mapping file alongside it.

.DESCRIPTION
    Automates steps 3-5 of the README's "Releasing a new version" section:
    verifies release signing is configured (see README "Signing releases"),
    runs `gradlew bundleRelease`, reports the resolved version, and copies
    mapping.txt next to the .aab so it survives the next build (which
    otherwise overwrites it). Warns (with a confirm prompt) if the working
    tree is dirty or HEAD isn't exactly on a vX.Y.Z tag, since either means
    this isn't a clean, reproducible release build.

    This script does not tag anything -- run scripts/release.ps1 first.

.PARAMETER AllowUnsigned
    Proceed even though release signing isn't configured. Produces a .aab
    that Play Console will reject on upload; useful only for a local check
    of the build itself.

.PARAMETER SkipCleanCheck
    Don't warn about / prompt for an uncommitted working tree or a HEAD
    that isn't exactly on a release tag.

.EXAMPLE
    ./scripts/bundle.ps1

.EXAMPLE
    ./scripts/bundle.ps1 -AllowUnsigned
#>
[CmdletBinding()]
param(
    [switch] $AllowUnsigned,
    [switch] $SkipCleanCheck
)

$ErrorActionPreference = 'Stop'

function Write-Step  { param([string] $Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Warn  { param([string] $Message) Write-Host "!!  $Message" -ForegroundColor Yellow }
function Fail        { param([string] $Message) Write-Host "x   $Message" -ForegroundColor Red; exit 1 }

# --- repository -------------------------------------------------------------

$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    Fail 'Not inside a git repository.'
}
Set-Location -LiteralPath $repoRoot

# --- working tree / tag sanity checks ---------------------------------------

if (-not $SkipCleanCheck) {
    $dirty = git status --porcelain
    if ($dirty) {
        Write-Warn 'The working tree has uncommitted changes; the build would produce a "-dirty" versionName.'
        $answer = Read-Host 'Build anyway? [y/N]'
        if ($answer -notmatch '^(y|yes)$') {
            Fail 'Aborted: commit or stash your changes first, or pass -SkipCleanCheck.'
        }
    }

    git describe --tags --exact-match > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn 'HEAD is not exactly on a release tag. Run ./scripts/release.ps1 first for a real release.'
        $answer = Read-Host 'Build anyway? [y/N]'
        if ($answer -notmatch '^(y|yes)$') {
            Fail 'Aborted: tag the release commit first (see scripts/release.ps1), or pass -SkipCleanCheck.'
        }
    }
}

# --- signing ------------------------------------------------------------------
# Mirrors the localOrEnv() lookup in app/build.gradle.kts so this script can
# fail fast instead of letting Gradle silently produce an unsigned .aab.

function Get-LocalOrEnv {
    param([string] $PropertyKey, [string] $EnvKey)
    $localPropsPath = Join-Path $repoRoot 'local.properties'
    if (Test-Path -LiteralPath $localPropsPath) {
        $line = Get-Content -LiteralPath $localPropsPath |
            Where-Object { $_ -match "^\s*$([regex]::Escape($PropertyKey))\s*=" } |
            Select-Object -First 1
        if ($line) {
            $value = ($line -split '=', 2)[1].Trim()
            if ($value) { return $value }
        }
    }
    $envValue = [Environment]::GetEnvironmentVariable($EnvKey)
    if ($envValue) { return $envValue }
    return $null
}

$keystoreFile     = Get-LocalOrEnv 'eatapp.keystore.file' 'EATAPP_KEYSTORE_FILE'
$keystorePassword = Get-LocalOrEnv 'eatapp.keystore.password' 'EATAPP_KEYSTORE_PASSWORD'
$keyAlias         = Get-LocalOrEnv 'eatapp.key.alias' 'EATAPP_KEY_ALIAS'
$keyPassword      = Get-LocalOrEnv 'eatapp.key.password' 'EATAPP_KEY_PASSWORD'

$keystoreResolved = $null
if ($keystoreFile) {
    $keystoreResolved = if ([System.IO.Path]::IsPathRooted($keystoreFile)) {
        $keystoreFile
    } else {
        Join-Path $repoRoot $keystoreFile
    }
}

$hasSigning = [bool]($keystoreResolved -and (Test-Path -LiteralPath $keystoreResolved) -and $keystorePassword -and $keyAlias -and $keyPassword)

if (-not $hasSigning) {
    if ($AllowUnsigned) {
        Write-Warn 'Release signing is not configured; building an UNSIGNED .aab (per -AllowUnsigned). Play Console will reject it on upload.'
    } else {
        Fail ('Release signing is not configured (see README "Signing releases"). Set eatapp.keystore.file/password/alias/keypassword ' +
              'in local.properties or the matching EATAPP_* environment variables, or pass -AllowUnsigned to build anyway for local inspection.')
    }
} else {
    Write-Step "Release signing configured: keystore=$keystoreResolved alias=$keyAlias"
}

# --- version ------------------------------------------------------------------

Write-Step 'Resolving version...'
$versionInfo = & .\gradlew.bat --quiet ':app:printVersionInfo'
if ($LASTEXITCODE -ne 0) {
    Fail 'Could not resolve version info.'
}
$versionInfo | ForEach-Object { Write-Host "    $_" }

$versionName = 'unknown'
foreach ($line in $versionInfo) {
    if ($line -match '^versionName=(.+)$') {
        $versionName = $Matches[1]
        break
    }
}

# --- build ----------------------------------------------------------------

Write-Step 'Building release App Bundle (./gradlew bundleRelease)...'
& .\gradlew.bat bundleRelease
if ($LASTEXITCODE -ne 0) {
    Fail 'bundleRelease failed.'
}

$aabPath = Join-Path $repoRoot 'app\build\outputs\bundle\release\app-release.aab'
if (-not (Test-Path -LiteralPath $aabPath)) {
    Fail "Expected bundle not found at $aabPath."
}

$aabSizeMb = [Math]::Round((Get-Item -LiteralPath $aabPath).Length / 1MB, 2)
Write-Step "Bundle built: $aabPath ($aabSizeMb MB)"

# --- mapping archive --------------------------------------------------------
# Copied next to the bundle (still under build/, so still gitignored) under a
# version-stamped name so the next build's mapping/release/mapping.txt
# overwrite doesn't destroy it before you've moved it somewhere durable.

$mappingSrc = Join-Path $repoRoot 'app\build\outputs\mapping\release\mapping.txt'
if (Test-Path -LiteralPath $mappingSrc) {
    $mappingDest = Join-Path $repoRoot "app\build\outputs\bundle\release\mapping-$versionName.txt"
    Copy-Item -LiteralPath $mappingSrc -Destination $mappingDest -Force
    Write-Step "Mapping file archived to $mappingDest -- move it somewhere durable before your next clean build."
} else {
    Write-Warn "No mapping.txt found at $mappingSrc; deobfuscation for crash reports from this build won't be possible."
}

Write-Host ''
Write-Step "Done. Upload $aabPath to the Play Console."
if ($hasSigning) {
    Write-Step 'Smoke-test the release build on a device before publishing (README "Releasing a new version", step 5).'
}
