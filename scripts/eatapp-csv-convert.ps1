<#
.SYNOPSIS
    Converts between an EatApp restaurant-share file (.eatapp) and a CSV, in
    either direction, so a batch of restaurants can be entered/edited on a PC
    (e.g. in Excel) and imported into the app in one go via "Open with
    EatApp", or exported from the app and inspected/edited as a spreadsheet.

.DESCRIPTION
    Direction is picked automatically from -InputPath's extension: a .csv
    file is converted to .eatapp JSON, anything else (.eatapp, .json, ...) is
    read as an eatapp.restaurants.v2 share file and converted to CSV. Pass
    -To to override the guess.

    The CSV has columns name,cuisineType,streetAddress,priceRange,website,
    instagram,tags,city,region,country,visits, matching
    RestaurantShareModels.kt. On the way into .eatapp, rows are validated the
    same way the app would validate them on import (required
    name/cuisineType/priceRange, priceRange 0-4, cuisineType from the closed
    vocabulary in Cuisine.kt) -- an invalid row is skipped with a warning
    rather than failing the whole file, since that's what the app does too.
    On the way into CSV, every row is trusted as-is (it's the app's own
    export).

    tags is a semicolon-separated list, e.g. "date night;terrace".

    visits is a semicolon-separated list of visit entries, each shaped
    "yyyy-MM-dd:rating:priceRange[:notes]", e.g.
    "2026-03-01:4:2:Great tasting menu;2026-06-14:5:2". rating is 0-5,
    priceRange is 0-4 (0 means "not set"), notes is optional and must not
    contain ':' or ';'.

    Pass -Template to just write an example CSV to start from instead of
    converting anything.

.PARAMETER InputPath
    Path to the input file (.csv, or .eatapp/.json). Required unless
    -Template is used.

.PARAMETER OutputPath
    Path to write the converted file to. Defaults to -InputPath with the
    other extension (.csv <-> .eatapp).

.PARAMETER To
    Force the conversion direction: 'eatapp' or 'csv'. Only needed when
    -InputPath's extension doesn't already make it obvious (e.g. a .json
    share file you want written out explicitly as .csv).

.PARAMETER Template
    Write an example CSV to -OutputPath (default: restaurants-template.csv in
    the current directory) instead of converting anything.

.EXAMPLE
    ./scripts/eatapp-csv-convert.ps1 -Template

.EXAMPLE
    ./scripts/eatapp-csv-convert.ps1 -InputPath restaurants.csv

.EXAMPLE
    ./scripts/eatapp-csv-convert.ps1 -InputPath restaurants.eatapp

.EXAMPLE
    ./scripts/eatapp-csv-convert.ps1 -InputPath backup.json -To csv -OutputPath backup.csv
#>
[CmdletBinding()]
param(
    [string] $InputPath,
    [string] $OutputPath,
    [ValidateSet('eatapp', 'csv')]
    [string] $To,
    [switch] $Template
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string] $Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Warn { param([string] $Message) Write-Host "!!  $Message" -ForegroundColor Yellow }
function Fail       { param([string] $Message) Write-Host "x   $Message" -ForegroundColor Red; exit 1 }

# Mirrors the closed vocabulary in Cuisine.kt -- kept in sync manually, same
# as the README's copy of it.
$ValidCuisines = @(
    'mediterranean', 'spanish', 'catalan', 'basque', 'italian', 'japanese',
    'chinese', 'asian', 'indian', 'middle_eastern', 'american', 'seafood',
    'bar', 'beer_bar', 'wine_bar', 'cafe', 'bakery', 'dessert', 'breakfast',
    'brunch', 'grill', 'fast_food', 'fine_dining', 'vegetarian'
)

$ShareFormat = 'eatapp.restaurants.v2'

# --- template mode ------------------------------------------------------------

if ($Template) {
    $templatePath = if ($OutputPath) { $OutputPath } else { 'restaurants-template.csv' }
    if (Test-Path -LiteralPath $templatePath) {
        Fail "$templatePath already exists -- pass -OutputPath to write somewhere else."
    }
    @'
name,cuisineType,streetAddress,priceRange,website,instagram,tags,city,region,country,visits
Casa Pepe,spanish,Carrer Major 12,2,https://casapepe.com,@casapepe,date night;terrace,Barcelona,Catalonia,Spain,2026-03-01:4:2:Great tasting menu
Sushi Ken,japanese,,3,,,,"Tokyo",,Japan,
'@ | Set-Content -LiteralPath $templatePath -Encoding utf8
    Write-Step "Template written to $templatePath"
    Write-Step ('Valid cuisineType values: ' + ($ValidCuisines -join ', '))
    Write-Step 'priceRange: 0-4. streetAddress/website/instagram/tags/city/region/country/visits are optional -- leave blank.'
    Write-Step 'tags: semicolon-separated, e.g. "date night;terrace".'
    Write-Step 'visits: semicolon-separated entries "yyyy-MM-dd:rating:priceRange[:notes]", rating 0-5, priceRange 0-4 (0 = not set).'
    exit 0
}

# --- validate arguments / pick direction ---------------------------------------

if (-not $InputPath) {
    Fail 'Pass -InputPath (or -Template to generate an example CSV first).'
}
if (-not (Test-Path -LiteralPath $InputPath)) {
    Fail "File not found: $InputPath"
}

$inputExtension = [System.IO.Path]::GetExtension($InputPath).TrimStart('.').ToLowerInvariant()
$direction = if ($To) { $To } elseif ($inputExtension -eq 'csv') { 'eatapp' } else { 'csv' }

if (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::ChangeExtension($InputPath, $(if ($direction -eq 'eatapp') { '.eatapp' } else { '.csv' }))
}

# =========================================================================
# CSV -> .eatapp
# =========================================================================

# ConvertTo-Json has no indent control on Windows PowerShell 5.1 (it always
# produces its own multi-line-per-array-element layout), so the share file is
# built by hand here to get plain, stable 2-space-indented JSON.
function Format-JsonString {
    param([string] $Value)
    $escaped = $Value -replace '\\', '\\\\' -replace '"', '\"' `
        -replace "`r`n", '\n' -replace "`n", '\n' -replace "`r", '\n' -replace "`t", '\t'
    return '"' + $escaped + '"'
}

function Format-JsonScalar {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [int] -or $Value -is [long]) { return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture) }
    return Format-JsonString $Value
}

function Format-JsonField {
    param([string] $Key, $Value, [int] $Indent, [bool] $TrailingComma)
    $pad = ' ' * $Indent
    $comma = if ($TrailingComma) { ',' } else { '' }
    return "$pad`"$Key`": $(Format-JsonScalar $Value)$comma"
}

function Format-JsonStringArrayField {
    param([string] $Key, [string[]] $Values, [int] $Indent, [bool] $TrailingComma)
    $pad = ' ' * $Indent
    $comma = if ($TrailingComma) { ',' } else { '' }
    if (-not $Values -or $Values.Count -eq 0) {
        return "$pad`"$Key`": []$comma"
    }
    $items = ($Values | ForEach-Object { Format-JsonString $_ }) -join ', '
    return "$pad`"$Key`": [$items]$comma"
}

function Format-VisitsField {
    param([System.Collections.Generic.List[object]] $Visits, [int] $Indent, [bool] $TrailingComma)
    $pad = ' ' * $Indent
    $innerPad = ' ' * ($Indent + 2)
    $comma = if ($TrailingComma) { ',' } else { '' }
    if ($Visits.Count -eq 0) {
        return "$pad`"visits`": []$comma"
    }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("$pad`"visits`": [")
    for ($i = 0; $i -lt $Visits.Count; $i++) {
        $v = $Visits[$i]
        $trailing = if ($i -eq $Visits.Count - 1) { '' } else { ',' }
        $lines.Add("$innerPad{")
        $lines.Add((Format-JsonField 'visitDate' $v.visitDate ($Indent + 4) $true))
        $lines.Add((Format-JsonField 'rating' $v.rating ($Indent + 4) $true))
        $lines.Add((Format-JsonField 'notes' $v.notes ($Indent + 4) $true))
        $lines.Add((Format-JsonField 'priceRange' $v.priceRange ($Indent + 4) $false))
        $lines.Add("$innerPad}$trailing")
    }
    $lines.Add("$pad]$comma")
    return ($lines -join "`r`n")
}

function ConvertTo-ShareFileJson {
    param([System.Collections.Generic.List[object]] $Restaurants)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('{')
    $lines.Add("  `"format`": `"$ShareFormat`",")
    if ($Restaurants.Count -eq 0) {
        $lines.Add('  "restaurants": []')
    } else {
        $lines.Add('  "restaurants": [')
        for ($i = 0; $i -lt $Restaurants.Count; $i++) {
            $r = $Restaurants[$i]
            $lines.Add('    {')
            $lines.Add((Format-JsonField 'name' $r.name 6 $true))
            $lines.Add((Format-JsonField 'cuisineType' $r.cuisineType 6 $true))
            $lines.Add((Format-JsonField 'streetAddress' $r.streetAddress 6 $true))
            $lines.Add((Format-JsonField 'priceRange' $r.priceRange 6 $true))
            $lines.Add((Format-JsonField 'website' $r.website 6 $true))
            $lines.Add((Format-JsonField 'instagram' $r.instagram 6 $true))
            $lines.Add((Format-JsonStringArrayField 'tags' $r.tags 6 $true))
            $lines.Add((Format-JsonField 'city' $r.city 6 $true))
            $lines.Add((Format-JsonField 'region' $r.region 6 $true))
            $lines.Add((Format-JsonField 'country' $r.country 6 $true))
            $lines.Add((Format-VisitsField $r.visits 6 $false))
            $lines.Add('    }' + $(if ($i -eq $Restaurants.Count - 1) { '' } else { ',' }))
        }
        $lines.Add('  ]')
    }
    $lines.Add('}')
    return ($lines -join "`r`n")
}

function Convert-CsvToEatApp {
    param([string] $CsvPath, [string] $OutPath)

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

        $priceRange = 0
        if (-not [int]::TryParse($row.priceRange, [ref] $priceRange) -or $priceRange -lt 0 -or $priceRange -gt 4) {
            Write-Warn "Line $lineNumber ('$name') -- skipped: priceRange must be an integer 0-4, got '$($row.priceRange)'."
            $skipped++
            continue
        }

        $streetAddress = if ($row.streetAddress) { $row.streetAddress.Trim() } else { $null }
        $website = if ($row.website) { $row.website.Trim() } else { $null }
        $instagram = if ($row.instagram) { $row.instagram.Trim() } else { $null }
        $city = if ($row.city) { $row.city.Trim() } else { $null }
        $region = if ($row.region) { $row.region.Trim() } else { $null }
        $country = if ($row.country) { $row.country.Trim() } else { $null }
        if ([string]::IsNullOrWhiteSpace($streetAddress)) { $streetAddress = $null }
        if ([string]::IsNullOrWhiteSpace($website)) { $website = $null }
        if ([string]::IsNullOrWhiteSpace($instagram)) { $instagram = $null }
        if ([string]::IsNullOrWhiteSpace($city)) { $city = $null }
        if ([string]::IsNullOrWhiteSpace($region)) { $region = $null }
        if ([string]::IsNullOrWhiteSpace($country)) { $country = $null }

        $tags = @()
        if ($row.tags -and -not [string]::IsNullOrWhiteSpace($row.tags)) {
            $tags = @($row.tags -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        $visits = New-Object System.Collections.Generic.List[object]
        $visitParseFailed = $false
        if ($row.visits -and -not [string]::IsNullOrWhiteSpace($row.visits)) {
            foreach ($entry in ($row.visits -split ';')) {
                $trimmedEntry = $entry.Trim()
                if (-not $trimmedEntry) { continue }
                $parts = $trimmedEntry -split ':', 4
                if ($parts.Count -lt 3) {
                    Write-Warn "Line $lineNumber ('$name') -- skipped: visit entry '$trimmedEntry' must be 'yyyy-MM-dd:rating:priceRange[:notes]'."
                    $visitParseFailed = $true
                    break
                }
                $visitDateText, $ratingText, $priceRangeText = $parts[0], $parts[1], $parts[2]
                $notesText = if ($parts.Count -eq 4) { $parts[3] } else { $null }

                $parsedDate = [DateTime]::MinValue
                if (-not [DateTime]::TryParseExact($visitDateText, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref] $parsedDate)) {
                    Write-Warn "Line $lineNumber ('$name') -- skipped: visit date '$visitDateText' must be yyyy-MM-dd."
                    $visitParseFailed = $true
                    break
                }
                $visitDateMillis = [DateTimeOffset]::new($parsedDate, [TimeSpan]::Zero).ToUnixTimeMilliseconds()

                $visitRating = 0
                if (-not [int]::TryParse($ratingText, [ref] $visitRating) -or $visitRating -lt 0 -or $visitRating -gt 5) {
                    Write-Warn "Line $lineNumber ('$name') -- skipped: visit rating must be an integer 0-5, got '$ratingText'."
                    $visitParseFailed = $true
                    break
                }

                $visitPriceRange = 0
                if (-not [int]::TryParse($priceRangeText, [ref] $visitPriceRange) -or $visitPriceRange -lt 0 -or $visitPriceRange -gt 4) {
                    Write-Warn "Line $lineNumber ('$name') -- skipped: visit priceRange must be an integer 0-4, got '$priceRangeText'."
                    $visitParseFailed = $true
                    break
                }

                $visits.Add([ordered] @{
                    visitDate = $visitDateMillis
                    rating = $visitRating
                    notes = if ([string]::IsNullOrWhiteSpace($notesText)) { $null } else { $notesText.Trim() }
                    priceRange = $visitPriceRange
                })
            }
        }
        if ($visitParseFailed) {
            $skipped++
            continue
        }

        $restaurants.Add([ordered] @{
            name = $name
            cuisineType = $cuisineType
            streetAddress = $streetAddress
            priceRange = $priceRange
            website = $website
            instagram = $instagram
            tags = $tags
            city = $city
            region = $region
            country = $country
            visits = $visits
        })
    }

    if ($restaurants.Count -eq 0) {
        Fail 'No valid rows -- nothing to write.'
    }

    # Written via .NET directly with a BOM-less UTF8Encoding -- Set-Content
    # -Encoding utf8 writes a UTF-8 BOM on Windows PowerShell 5.1, and a
    # leading BOM byte risks tripping up the JSON parser on the phone.
    $json = ConvertTo-ShareFileJson -Restaurants $restaurants
    $resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutPath)) { $OutPath } else { Join-Path (Get-Location) $OutPath }
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($resolvedOutputPath)
    [System.IO.File]::WriteAllText($resolvedOutputPath, $json, (New-Object System.Text.UTF8Encoding($false)))

    Write-Step "Wrote $($restaurants.Count) restaurant(s) to $OutPath$(if ($skipped) { " ($skipped row(s) skipped, see warnings above)" })"
    Write-Step 'Copy this file to the phone and open it with "Open with EatApp" to import (nothing is written until you confirm on the review screen).'
}

# =========================================================================
# .eatapp -> CSV
# =========================================================================

function Format-CsvField {
    param([string] $Value)
    if ($null -eq $Value) { return '' }
    return $Value
}

function ConvertTo-Csv-Tags {
    param([string[]] $Tags)
    if (-not $Tags -or $Tags.Count -eq 0) { return '' }
    return ($Tags -join ';')
}

function ConvertTo-Csv-Visits {
    param([System.Collections.Generic.List[object]] $Visits, [string] $Name, [int] $Index)
    if (-not $Visits -or $Visits.Count -eq 0) { return '' }
    $entries = foreach ($v in $Visits) {
        $visitDateMillis = [long] $v.visitDate
        $date = [DateTimeOffset]::FromUnixTimeMilliseconds($visitDateMillis).UtcDateTime.ToString('yyyy-MM-dd')
        $notes = $v.notes
        if ($notes -and ($notes.Contains(':') -or $notes.Contains(';'))) {
            Write-Warn "Restaurant #$Index ('$Name') -- a visit's notes contain ':' or ';' and would corrupt the visits column; notes dropped for that visit."
            $notes = $null
        }
        if ($notes) { "$date`:$($v.rating)`:$($v.priceRange)`:$notes" } else { "$date`:$($v.rating)`:$($v.priceRange)" }
    }
    return ($entries -join ';')
}

function Convert-EatAppToCsv {
    param([string] $EatAppPath, [string] $OutPath)

    # Read as UTF-8 explicitly: .eatapp files are written BOM-less UTF-8 (see
    # Convert-CsvToEatApp), and Get-Content -Raw on Windows PowerShell 5.1
    # falls back to the system ANSI codepage for BOM-less files, which turns
    # accented characters into mojibake (e.g. "Genís" -> "GenÃ­s").
    $rawJson = [System.IO.File]::ReadAllText(
        ([System.IO.Path]::GetFullPath($EatAppPath)),
        (New-Object System.Text.UTF8Encoding($false)))
    try {
        $shareFile = $rawJson | ConvertFrom-Json
    } catch {
        Fail "$EatAppPath isn't valid JSON: $($_.Exception.Message)"
    }

    if ($shareFile.format -ne $ShareFormat) {
        Fail "$EatAppPath has format '$($shareFile.format)', expected '$ShareFormat'."
    }
    if (-not $shareFile.restaurants -or $shareFile.restaurants.Count -eq 0) {
        Fail "No restaurants found in $EatAppPath."
    }

    $csvRows = New-Object System.Collections.Generic.List[object]
    $index = 0
    foreach ($r in $shareFile.restaurants) {
        $index++
        $visitsList = New-Object System.Collections.Generic.List[object]
        if ($r.visits) { foreach ($v in $r.visits) { $visitsList.Add($v) } }

        $csvRows.Add([pscustomobject] [ordered] @{
            name = Format-CsvField $r.name
            cuisineType = Format-CsvField $r.cuisineType
            streetAddress = Format-CsvField $r.streetAddress
            priceRange = $r.priceRange
            website = Format-CsvField $r.website
            instagram = Format-CsvField $r.instagram
            tags = ConvertTo-Csv-Tags $r.tags
            city = Format-CsvField $r.city
            region = Format-CsvField $r.region
            country = Format-CsvField $r.country
            visits = ConvertTo-Csv-Visits $visitsList $r.name $index
        })
    }

    # Export-Csv writes a UTF-8 BOM by default on Windows PowerShell 5.1, and
    # the app never has to read this file back -- that's fine here, unlike
    # the .eatapp side.
    $csvRows | Export-Csv -LiteralPath $OutPath -NoTypeInformation -Encoding utf8

    Write-Step "Wrote $($csvRows.Count) restaurant(s) to $OutPath"
}

# --- run --------------------------------------------------------------------

if ($direction -eq 'eatapp') {
    Convert-CsvToEatApp -CsvPath $InputPath -OutPath $OutputPath
} else {
    Convert-EatAppToCsv -EatAppPath $InputPath -OutPath $OutputPath
}
