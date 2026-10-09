<#
  OTA yayın betiği (stationcheck-updates).
  Kullanım:
    powershell -ExecutionPolicy Bypass -File yayinla.ps1 -UygulamaID 101 -Versiyon 101.26.45 -Platform linux-arm -Klasor <yayın klasörü>
    -Deneme : "deneme" etiketli ön-sürüm (prerelease) açar, zip'i yükler, surum.json'a DOKUNMAZ (betiği denemek için).
  Sıra:
    a) Klasörü zip'ler: <UygulamaID>_<Versiyon>_<Platform>.zip (Data, Sys, Log klasörleri pakete girmez; dosyalar zip'in kökünde).
    b) SHA-256'sını hesaplar.
    c) "v<Versiyon>" release'i yoksa açar; zip'i yükler (aynı adda dosya varsa değiştirir).
    d) Ancak yükleme başarılıysa <UygulamaID>/surum.json'da "versiyon"u ve yalnızca o platformun zip_adres + sha256
       alanlarını günceller; öbür platformlara dokunmaz.
    e) Commit + push.
    f) Tek satır özet: versiyon, platform, zip boyutu, sha256.
  Hata olursa (gh girişi yok, klasör yok, yükleme başarısız …) surum.json'a dokunmadan durur (yarım yayın olmaz).
#>
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d{3}$')][string]$UygulamaID,
    [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Versiyon,
    [Parameter(Mandatory = $true)][ValidateSet('win-x64', 'linux-arm')][string]$Platform,
    [Parameter(Mandatory = $true)][string]$Klasor,
    [switch]$Deneme
)

$ErrorActionPreference = 'Continue'   # yerel komutlar (gh, git) çıkış koduyla denetlenir; PS 5.1'de 'Stop' stderr'i hata sayar
$Kok = $PSScriptRoot
$KorunanKlasorler = @('Data', 'Sys', 'Log')   # yayın klasöründe cihazın kendi verisi: pakete girmez

function Dur([string]$neden) {
    Write-Host "HATA: $neden" -ForegroundColor Red
    Write-Host "surum.json'a dokunulmadı." -ForegroundColor Red
    exit 1
}

# gh: PATH'te yoksa standart kurulum yeri
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) { $gh = 'C:\Program Files\GitHub CLI\gh.exe' }
if (-not (Test-Path $gh)) { Dur "GitHub CLI (gh) bulunamadı." }

# Ön denetimler
if (-not $Versiyon.StartsWith("$UygulamaID.")) { Dur "Versiyon ($Versiyon) Uygulama ID ($UygulamaID) ile başlamıyor." }
if (-not (Test-Path -LiteralPath $Klasor -PathType Container)) { Dur "Klasör yok: $Klasor" }
$surumYolu = Join-Path $Kok "$UygulamaID\surum.json"
if (-not $Deneme -and -not (Test-Path -LiteralPath $surumYolu)) { Dur "surum.json yok: $surumYolu" }
& $gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Dur "GitHub girişi yok (gh auth login)." }
$repo = (& $gh repo view --json nameWithOwner -q .nameWithOwner 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $repo) { Dur "GitHub deposu okunamadı (klasör: $Kok)." }
Push-Location $Kok
try {
    if (-not $Deneme) {
        $kirli = (git status --porcelain -- "$UygulamaID/surum.json")
        if ($kirli) { Dur "$UygulamaID/surum.json'da commit'lenmemiş değişiklik var; önce onu düzeltin." }
    }
} finally { Pop-Location }

# a) Zip (geçici klasörde; dosyalar kökte, '/' ayraçlı; korunan klasörler hariç)
$zipAdi = "${UygulamaID}_${Versiyon}_${Platform}.zip"
$gecici = Join-Path ([IO.Path]::GetTempPath()) ("ota-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $gecici -ErrorAction Stop | Out-Null
$zipYolu = Join-Path $gecici $zipAdi
try {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $kaynak = (Resolve-Path -LiteralPath $Klasor -ErrorAction Stop).Path.TrimEnd('\', '/')
    $dosyalar = Get-ChildItem -LiteralPath $kaynak -Recurse -File -Force | Where-Object {
        $goreli = $_.FullName.Substring($kaynak.Length + 1)
        $ilk = $goreli.Split('\', '/')[0]
        -not ($KorunanKlasorler -contains $ilk -and $goreli.Length -gt $ilk.Length)
    }
    if (-not $dosyalar) { Dur "Klasörde pakete girecek dosya yok: $Klasor" }
    $zip = [IO.Compression.ZipFile]::Open($zipYolu, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in $dosyalar) {
            $ad = $f.FullName.Substring($kaynak.Length + 1).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $ad, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally { $zip.Dispose() }

    # b) SHA-256
    $sha = (Get-FileHash -LiteralPath $zipYolu -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $boyut = (Get-Item -LiteralPath $zipYolu).Length

    # c) Release (yoksa aç) + yükle (aynı adda dosya varsa değiştir)
    $etiket = if ($Deneme) { 'deneme' } else { "v$Versiyon" }
    & $gh release view $etiket --repo $repo *> $null
    if ($LASTEXITCODE -ne 0) {
        $ek = @()
        if ($Deneme) { $ek = @('--prerelease') }
        & $gh release create $etiket --repo $repo --target main --title $etiket --notes "Uygulama $UygulamaID, sürüm $Versiyon" @ek 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Dur "Release açılamadı: $etiket" }
    }
    & $gh release upload $etiket $zipYolu --repo $repo --clobber 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Dur "Zip yüklenemedi: $zipAdi" }
    $adres = "https://github.com/$repo/releases/download/$etiket/$zipAdi"

    # d) surum.json (yalnızca gerçek yayında; yükleme başarılı olduktan sonra)
    if (-not $Deneme) {
        $j = Get-Content -LiteralPath $surumYolu -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        if ($j.uygulama_id -ne $UygulamaID) { Dur "surum.json'daki uygulama_id ($($j.uygulama_id)) $UygulamaID değil." }
        $platformlar = [ordered]@{}
        foreach ($p in $j.paketler.PSObject.Properties) { $platformlar[$p.Name] = @{ zip = [string]$p.Value.zip_adres; sha = [string]$p.Value.sha256 } }
        $platformlar[$Platform] = @{ zip = $adres; sha = $sha }   # yalnızca bu platform değişir
        $zorunlu = if ($j.zorunlu) { 'true' } else { 'false' }
        $satirlar = @()
        foreach ($k in $platformlar.Keys) { $satirlar += "    `"$k`": { `"zip_adres`": `"$($platformlar[$k].zip)`", `"sha256`": `"$($platformlar[$k].sha)`" }" }
        $metin = "{`n  `"uygulama_id`": `"$UygulamaID`",`n  `"versiyon`": `"$Versiyon`",`n  `"zorunlu`": $zorunlu,`n  `"paketler`": {`n" +
                 ($satirlar -join ",`n") + "`n  }`n}`n"
        $null = $metin | ConvertFrom-Json   # yazmadan önce geçerli JSON mu
        [IO.File]::WriteAllText($surumYolu, $metin, (New-Object Text.UTF8Encoding($false)))

        # e) Commit + push
        Push-Location $Kok
        try {
            git add -- "$UygulamaID/surum.json"
            git commit -q -m "$UygulamaID $Versiyon ($Platform) yayınlandı"
            if ($LASTEXITCODE -ne 0) { throw "commit başarısız" }
            git push -q 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "push başarısız (surum.json yerelde commit'li, GitHub'da değil; 'git push' ile yeniden deneyin)" }
        } finally { Pop-Location }
    }

    # f) Özet
    $mb = '{0:N1} MB' -f ($boyut / 1MB)
    $tur = if ($Deneme) { 'DENEME (surum.json değişmedi)' } else { 'Yayınlandı' }
    Write-Host "$tur · $Versiyon · $Platform · $mb · sha256 $sha · $adres" -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $gecici -Recurse -Force -ErrorAction SilentlyContinue
}
