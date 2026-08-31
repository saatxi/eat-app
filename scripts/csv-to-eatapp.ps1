<#
.SYNOPSIS
    Builds an EatApp restaurant-share file (.eatapp) from a CSV, so a batch of
    restaurants can be entered on a PC (e.g. in Excel) and imported into the
    app in one go via "Open with EatApp".

.DESCRIPTION
    Reads a CSV with columns name,cuisineType,address,rating,priceRange,
    website,instagram and writes an eatapp.restaurants.v1 JSON file matching
    RestaurantShareModels.kt / RestaurantImportReader.kt. Rows are validated
    the same way the app would validate them on import (required name/
    cuisineType, rating 0-5, priceRange 0-4, cuisineType from the closed
    vocabulary in Cuisine.kt) -- an invalid row is skipped with a warning
    rather than failing the whole file, since that's what the app does too.

    Pass -Template to just write an example CSV to start from instead of
    converting anything.

.PARAMETER CsvPath
    Path to the input CSV. Required unless -Template is used.

.PARAMETER OutputPath
    Path to write the .eatapp file to. Defaults to the CSV's path with a
    .eatapp extension.

.PARAMETER Template
    Write an example CSV to -OutputPath (default: restaurants-template.csv in
    the current directory) instead of converting anything.

.EXAMPLE
    ./scripts/csv-to-eatapp.ps1 -Template

.EXAMPLE
    ./scripts/csv-to-eatapp.ps1 -CsvPath restaurants.csv

.EXAMPLE
    ./scripts/csv-to-eatapp.ps1 -CsvPath restaurants.csv -OutputPath restaurants.eatapp
#>
[CmdletBinding()]
param(
    [string] $CsvPath,
    [string] $OutputPath,
    [switch] $Template
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string] $Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Warn { param([string] $Message) Write-Host "!!  $Message" -ForegroundColor Yellow }
function Fail       { param([string] $Message) Write-Host "x   $Message" -ForegroundColor Red; exit 1 }

# ConvertTo-Json has no indent control on Windows PowerShell 5.1 (it always
# produces its own multi-line-per-array-element layout), so the share file is
# built by hand here to get plain, stable 2-space-indented JSON.
function Format-JsonString {
    param([string] $Value)
    $escaped = $Value -replace '\\', '\\\\' -replace '"', '\"' `
        -replace "`r`n", '\n' -replace "`n", '\n' -replace "`r", '\n' -replace "`t", '\t'
    return '"' + $escaped + '"'
}

function Format-JsonField {
    param([string] $Key, $Value, [int] $Indent, [bool] $TrailingComma)
    $pad = ' ' * $Indent
    $jsonValue = if ($null -eq $Value) { 'null' }
        elseif ($Value -is [int]) { $Value }
        else { Format-JsonString $Value }
    $comma = if ($TrailingComma) { ',' } else { '' }
    return "$pad`"$Key`": $jsonValue$comma"
}

function ConvertTo-ShareFileJson {
    param([System.Collections.Generic.List[object]] $Restaurants)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('{')
    $lines.Add('  "format": "eatapp.restaurants.v1",')
    if ($Restaurants.Count -eq 0) {
        $lines.Add('  "restaurants": []')
    } else {
        $lines.Add('  "restaurants": [')
        for ($i = 0; $i -lt $Restaurants.Count; $i++) {
            $r = $Restaurants[$i]
            $lines.Add('    {')
            $lines.Add((Format-JsonField 'name' $r.name 6 $true))
            $lines.Add((Format-JsonField 'cuisineType' $r.cuisineType 6 $true))
            $lines.Add((Format-JsonField 'address' $r.address 6 $true))
            $lines.Add((Format-JsonField 'rating' $r.rating 6 $true))
            $lines.Add((Format-JsonField 'priceRange' $r.priceRange 6 $true))
            $lines.Add((Format-JsonField 'website' $r.website 6 $true))
            $lines.Add((Format-JsonField 'instagram' $r.instagram 6 $false))
            $lines.Add('    }' + $(if ($i -eq $Restaurants.Count - 1) { '' } else { ',' }))
        }
        $lines.Add('  ]')
    }
    $lines.Add('}')
    return ($lines -join "`r`n")
}

# Mirrors the closed vocabulary in Cuisine.kt -- kept in sync manually, same
# as the README's copy of it.
$ValidCuisines = @(
    'mediterranean', 'spanish', 'catalan', 'basque', 'italian', 'japanese',
    'chinese', 'asian', 'indian', 'middle_eastern', 'american', 'seafood',
    'bar', 'beer_bar', 'wine_bar', 'cafe', 'bakery', 'dessert', 'breakfast',
    'brunch', 'grill', 'fast_food', 'fine_dining', 'vegetarian'
)

# --- template mode ------------------------------------------------------------

if ($Template) {
    $templatePath = if ($OutputPath) { $OutputPath } else { 'restaurants-template.csv' }
    if (Test-Path -LiteralPath $templatePath) {
        Fail "$templatePath already exists -- pass -OutputPath to write somewhere else."
    }
    @'
name,cuisineType,address,rating,priceRange,website,instagram
Casa Pepe,spanish,"Carrer Major 12, Barcelona",4,2,https://casapepe.com,@casapepe
Sushi Ken,japanese,,5,3,,
'@ | Set-Content -LiteralPath $templatePath -Encoding utf8
    Write-Step "Template written to $templatePath"
    Write-Step ('Valid cuisineType values: ' + ($ValidCuisines -join ', '))
    Write-Step 'rating: 0-5, priceRange: 0-4. address/website/instagram are optional -- leave blank.'
    exit 0
}

# --- validate arguments --------------------------------------------------------

if (-not $CsvPath) {
    Fail 'Pass -CsvPath (or -Template to generate an example CSV first).'
}
if (-not (Test-Path -LiteralPath $CsvPath)) {
    Fail "CSV not found: $CsvPath"
}
if (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::ChangeExtension($CsvPath, '.eatapp')
}

# --- read + validate rows ------------------------------------------------------

$rows = Import-Csv -LiteralPath $CsvPath
if (-not $rows -or $rows.Count -eq 0) {
    Fail "No rows found in $CsvPath."
}

$restaurants = New-Object System.Collections.Generic.List[object]
$skipped = 0
$lineNumber = 1  # header is line 1

foreach ($row in $rows) {
    $lineNumber++

    $name = if ($row.name) { $row.name.Trim() } else { '' }
    $cuisineType = if ($row.cuisineType) { $row.cuisineType.Trim().ToLowerInvariant() } else { '' }

    if (-not $name) {
        Write-Warn "Line $lineNumber -- skipped: name is required."
        $skipped++
        continue
    }
    if (-not $cuisineType) {
        Write-Warn "Line $lineNumber ('$name') -- skipped: cuisineType is required."
        $skipped++
        continue
    }
    if ($ValidCuisines -notcontains $cuisineType) {
        Write-Warn "Line $lineNumber ('$name') -- skipped: cuisineType '$cuisineType' isn't in the known vocabulary."
        $skipped++
        continue
    }

    $rating = 0
    if (-not [int]::TryParse($row.rating, [ref] $rating) -or $rating -lt 0 -or $rating -gt 5) {
        Write-Warn "Line $lineNumber ('$name') -- skipped: rating must be an integer 0-5, got '$($row.rating)'."
        $skipped++
        continue
    }

    $priceRange = 0
    if (-not [int]::TryParse($row.priceRange, [ref] $priceRange) -or $priceRange -lt 0 -or $priceRange -gt 4) {
        Write-Warn "Line $lineNumber ('$name') -- skipped: priceRange must be an integer 0-4, got '$($row.priceRange)'."
        $skipped++
        continue
    }

    $address = if ($row.address) { $row.address.Trim() } else { $null }
    $website = if ($row.website) { $row.website.Trim() } else { $null }
    $instagram = if ($row.instagram) { $row.instagram.Trim() } else { $null }
    if ([string]::IsNullOrWhiteSpace($address)) { $address = $null }
    if ([string]::IsNullOrWhiteSpace($website)) { $website = $null }
    if ([string]::IsNullOrWhiteSpace($instagram)) { $instagram = $null }

    $restaurants.Add([ordered] @{
        name = $name
        cuisineType = $cuisineType
        address = $address
        rating = $rating
        priceRange = $priceRange
        website = $website
        instagram = $instagram
    })
}

if ($restaurants.Count -eq 0) {
    Fail 'No valid rows -- nothing to write.'
}

# --- write output ---------------------------------------------------------
# Written via .NET directly with a BOM-less UTF8Encoding -- Set-Content
# -Encoding utf8 writes a UTF-8 BOM on Windows PowerShell 5.1, and a leading
# BOM byte risks tripping up the JSON parser on the phone.

$json = ConvertTo-ShareFileJson -Restaurants $restaurants
$resolvedOutputPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
[System.IO.File]::WriteAllText($resolvedOutputPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Step "Wrote $($restaurants.Count) restaurant(s) to $OutputPath$(if ($skipped) { " ($skipped row(s) skipped, see warnings above)" })"
Write-Step 'Copy this file to the phone and open it with "Open with EatApp" to import (nothing is written until you confirm on the review screen).'
