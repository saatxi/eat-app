# End-to-end test of the join-group Edge Function against the real project.
#
# Flow:
#   1. Sign up user A (anonymous auth) -> creates a group + an invite.
#   2. Sign up user B (anonymous auth).
#   3. B calls the join-group function with A's token -> must succeed.
#   4. B must now read the group and its restaurants through RLS.
#   5. A bogus token must be rejected with 404.
#
# Requires: $env:SUPABASE_URL, $env:SUPABASE_ANON_KEY.
# The test data (two anon users, one group) stays in the project; the group
# name marks it as test data.

$ErrorActionPreference = 'Stop'

$url = $env:SUPABASE_URL
$key = $env:SUPABASE_ANON_KEY
if (-not $url -or -not $key) {
  throw 'Set SUPABASE_URL and SUPABASE_ANON_KEY before running.'
}

Write-Host 'Signing in user A (anonymous)...'
$a = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/signup" `
  -Headers @{ apikey = $key; 'Content-Type' = 'application/json' } `
  -Body '{}'
$aToken = $a.access_token
if (-not $aToken) { throw 'user A signup returned no token' }

Write-Host 'Creating group as user A...'
$groupId = [guid]::NewGuid().ToString()
$null = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/groups" `
  -Headers @{
    apikey = $key
    Authorization = "Bearer $aToken"
    'Content-Type' = 'application/json'
    Prefer = 'return=minimal'
  } `
  -Body (@{ id = $groupId; name = 'RLS e2e test group'; created_by = $a.user.id } | ConvertTo-Json)

$null = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/group_members" `
  -Headers @{
    apikey = $key
    Authorization = "Bearer $aToken"
    'Content-Type' = 'application/json'
    Prefer = 'return=minimal'
  } `
  -Body (@{ group_id = $groupId; user_id = $a.user.id; role = 'owner' } | ConvertTo-Json)

Write-Host 'Creating invite as user A (via create-invite function)...'
$invite = Invoke-RestMethod -Method Post `
  -Uri "$url/functions/v1/create-invite" `
  -Headers @{
    apikey = $key
    Authorization = "Bearer $aToken"
    'Content-Type' = 'application/json'
  } `
  -Body (@{ groupId = $groupId; maxUses = 5; expiresInDays = 1 } | ConvertTo-Json)
$rawToken = $invite.token
if (-not $rawToken) { throw 'create-invite returned no token' }

Write-Host 'Signing in user B (anonymous)...'
$b = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/signup" `
  -Headers @{ apikey = $key; 'Content-Type' = 'application/json' } `
  -Body '{}'
$bToken = $b.access_token
if (-not $bToken) { throw 'user B signup returned no token' }

Write-Host 'Calling join-group as user B...'
$joinRes = Invoke-RestMethod -Method Post `
  -Uri "$url/functions/v1/join-group" `
  -Headers @{
    apikey = $key
    Authorization = "Bearer $bToken"
    'Content-Type' = 'application/json'
  } `
  -Body (@{ token = $rawToken; displayName = 'Bob E2E' } | ConvertTo-Json)

if ($joinRes.groupId -ne $groupId) {
  throw "join-group returned unexpected groupId: $($joinRes.groupId)"
}
Write-Host "Joined group: $($joinRes.groupName)"

Write-Host 'Verifying user B can read the group through RLS...'
$seen = Invoke-RestMethod -Method Get `
  -Uri "$url/rest/v1/groups?id=eq.$groupId&select=name" `
  -Headers @{ apikey = $key; Authorization = "Bearer $bToken" }
if ($seen.Count -ne 1) { throw "user B sees $($seen.Count) groups, expected 1" }
Write-Host "User B sees group: $($seen[0].name)"

Write-Host 'Verifying a bogus token is rejected...'
try {
  $null = Invoke-RestMethod -Method Post `
    -Uri "$url/functions/v1/join-group" `
    -Headers @{
      apikey = $key
      Authorization = "Bearer $bToken"
      'Content-Type' = 'application/json'
    } `
    -Body '{"token":"deadbeefdeadbeefdeadbeefdeadbeef","displayName":"X"}'
  throw 'bogus token was accepted'
} catch {
  $status = $_.Exception.Response.StatusCode.value__
  if ($status -ne 404) { throw "bogus token returned $status, expected 404" }
}

Write-Host 'E2E test passed.'
