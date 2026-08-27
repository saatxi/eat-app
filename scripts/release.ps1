<#
.SYNOPSIS
    Cuts a new release: asks for a X.Y.Z version, creates the annotated tag
    vX.Y.Z (opening the editor for its message) and pushes it to the remote.

.DESCRIPTION
    versionName / versionCode are derived from git (see README "Versioning"),
    so tagging is the whole release ceremony as far as the build is concerned.
    The script refuses to reuse an existing tag: the README requires cutting a
    new one instead of retagging so versionCode keeps increasing.

.PARAMETER Version
    Version to release, as X.Y.Z (a leading "v" is accepted and stripped).
    When omitted the script asks for it interactively.

.PARAMETER Remote
    Remote to push the tag to. Defaults to "origin".

.PARAMETER NoPush
    Create the tag locally but don't push it.

.EXAMPLE
    ./scripts/release.ps1

.EXAMPLE
    ./scripts/release.ps1 -Version 1.4.0
#>
[CmdletBinding()]
param(
    [string] $Version,
    [string] $Remote = 'origin',
    [switch] $NoPush
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

# --- version ----------------------------------------------------------------

$versionPattern = '^v?([0-9]+\.[0-9]+\.[0-9]+)$'
$attemptsLeft = 3

while ($true) {
    if (-not $Version) {
        if ($attemptsLeft -le 0) {
            Fail 'No valid version given.'
        }
        $attemptsLeft--
        $Version = Read-Host 'Version to release (X.Y.Z)'
    }
    $Version = "$Version".Trim()

    if ($Version -match $versionPattern) {
        $Version = $Matches[1]
        break
    }

    Write-Warn "'$Version' is not a valid version. Expected X.Y.Z, e.g. 1.4.0."
    $Version = ''
}

$tag = "v$Version"

# --- preconditions ----------------------------------------------------------

git rev-parse -q --verify "refs/tags/$tag" > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Fail "Tag $tag already exists locally. Never retag a release; cut a new version instead."
}

Write-Step "Checking $Remote for an existing $tag..."
git ls-remote --exit-code --tags $Remote "refs/tags/$tag" > $null 2>&1
$remoteLookup = $LASTEXITCODE
if ($remoteLookup -eq 0) {
    Fail "Tag $tag already exists on $Remote. Cut a new version instead."
}
if ($remoteLookup -ne 2) {
    # 2 means "ref not found", which is what we want; anything else is a real failure.
    Write-Warn "Could not reach $Remote to verify the tag doesn't exist there yet."
}

$dirty = git status --porcelain
if ($dirty) {
    Write-Warn 'The working tree has uncommitted changes; the build would produce a "-dirty" versionName.'
    $answer = Read-Host 'Tag this commit anyway? [y/N]'
    if ($answer -notmatch '^(y|yes)$') {
        Fail 'Aborted: commit or stash your changes first.'
    }
}

$headLine = git log -1 --oneline
Write-Step "Releasing $tag on $headLine"

# --- tag --------------------------------------------------------------------

Write-Step 'Git will now open your editor for the tag message. Save and close to continue; an empty message aborts the release.'
git tag -a $tag
if ($LASTEXITCODE -ne 0) {
    Fail "Tag creation aborted: $tag was not created."
}

Write-Host ''
git tag -n99 -l $tag
Write-Host ''

# --- push -------------------------------------------------------------------

if ($NoPush) {
    Write-Step "Created $tag locally (-NoPush). Push it with: git push $Remote $tag"
    exit 0
}

Write-Step "Pushing $tag to $Remote..."
git push $Remote $tag
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Push failed. The local tag $tag is still there; delete it with 'git tag -d $tag' if you want to start over."
    Fail "Could not push $tag to $Remote."
}

Write-Step "$tag pushed. Next: ./gradlew :app:printVersionInfo, then assembleRelease / bundleRelease (see README)."
