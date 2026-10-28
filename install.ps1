#requires -Version 5.1
param(
    [string]$InstallHome,
    [switch]$NoPath,
    [switch]$NoAuth,
    [switch]$NoStart,
    [string]$AppPath,
    [ValidateRange(0,65535)][int]$Port=0,
    [switch]$NoWatch
)
# Keep preferences, helper functions and credentials out of an interactive caller.
& {
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$repository='kemarachanger/hianti-downloads'
$publicDistribution=$true
$publicKey='<RSAKeyValue><Modulus>mtCzXlSbGt6rwUAUYvZikJlQm1jROklhWBT9fcUAA0dsN4DKJtw7H3QZf5yKSYIDGpGswOGITruCSFfP4msIJA5RVVMA8/Blp7dQW1E75jDUxGDKSmYYkIkUl4didn16BKzPwZ9ybBNz421HtUw9lZ6YhN2bREX2DCpluaP+o9KYnjpH6i6lRO2tzoJoYjfcfbTIkncILTjMYtu9Hleojg6qA2VAo9ZUibjrbftisPcMr0JcrSyTKZNd0To6UmzNYTWIuU6TRYkr3dA3iasIGhWEXAVldbhFLqW+3vVOTF7T1bdlCWP5HYWbkEQZb2KJbAABJcl2ibaaItDPkWwdPHQRaPmiDawFht26bOheFpbXjC7arDVL1+IaFbkDZc+uYNa2vcBNg9Txbt+en71nbWUs3QqgcDt2Am7ayJ1Ya6m4kxdBPWa+vEJE93onOK69WLAL+ytqF5LTi9eEKR8lqtK3wKOrdDvOHChlZI50S1y+URvFM1XjnNEsoChy5jcF</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
$allowed=@('hianti.ps1','Hianti.Core.psm1','Hianti.Watch.psm1','Hianti.Update.psm1','ProxyInstaller.psm1','release.json','compatibility.json','trust-public.xml','Install-Local.ps1','launcher.ps1','hianti.cmd','payload/config.json','payload/version.dll','LICENSE','README.md','THIRD-PARTY-LICENSE.txt','THIRD-PARTY-AUTHORS.txt')
$stage=Join-Path ([IO.Path]::GetTempPath()) ('hianti-install-' + [Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $stage
$token=''
$policyChanged=$false
$oldTls=[Net.ServicePointManager]::SecurityProtocol
if (-not $publicDistribution) {
    foreach ($name in @('HIANTI_GITHUB_TOKEN','GH_TOKEN','GITHUB_TOKEN')) {
        $token=[Environment]::GetEnvironmentVariable($name)
        if ($token) { break }
    }
}
function Download([string]$Url,[string]$Path,[int]$Limit,[switch]$Json) {
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $uri=[Uri]$Url
    for ($i=0;$i -lt 6;$i++) {
        if ($uri.Scheme -ne 'https' -or $uri.UserInfo) { throw 'Only HTTPS downloads without embedded credentials are allowed.' }
        $request=[Net.HttpWebRequest]::Create($uri)
        $request.AllowAutoRedirect=$false; $request.Timeout=15000; $request.ReadWriteTimeout=15000
        $request.UserAgent='Hianti-Installer/0.1'
        if ($uri.Host -eq 'api.github.com') {
            if ($token) { $request.Headers['Authorization']='Bearer ' + $token }
            $request.Accept=if ($Json) {'application/vnd.github+json'} else {'application/octet-stream'}
        }
        $response=$null
        try {
            $response=$request.GetResponse()
            if ([int]$response.StatusCode -in @(301,302,303,307,308)) { $uri=New-Object Uri($uri,$response.Headers['Location']); continue }
            if ([int]$response.StatusCode -ne 200 -or $response.ContentLength -gt $Limit) { throw 'Unexpected download response.' }
            $output=[IO.File]::Open($Path,[IO.FileMode]::CreateNew)
            $inputStream=$response.GetResponseStream()
            try {
                $buffer=New-Object byte[] 65536; $total=0L
                while (($read=$inputStream.Read($buffer,0,$buffer.Length)) -gt 0) {
                    $total+=$read
                    if ($total -gt $Limit) { throw 'Download size limit exceeded.' }
                    $output.Write($buffer,0,$read)
                }
            } finally { $output.Dispose(); $inputStream.Dispose() }
            return
        } finally { if ($response) { $response.Dispose() } }
    }
    throw 'Too many download redirects.'
}
try {
    Write-Output 'Hianti | Downloading the latest signed release'
    $release=$null
    if ($publicDistribution) {
        foreach ($name in @('feed.json','feed.json.sig')) {
            Download ('https://github.com/' + $repository + '/releases/latest/download/' + $name) (Join-Path $stage $name) 131072
        }
    } else {
        $metadata=Join-Path $stage 'release.json'
        Download ('https://api.github.com/repos/' + $repository + '/releases/latest') $metadata 2097152 -Json
        $release=Get-Content -LiteralPath $metadata -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($name in @('feed.json','feed.json.sig')) {
            $asset=@($release.assets | Where-Object name -eq $name)
            if ($asset.Count -ne 1) { throw ('Missing release asset: ' + $name) }
            Download $asset[0].url (Join-Path $stage $name) 131072
        }
    }
    $bytes=[IO.File]::ReadAllBytes((Join-Path $stage 'feed.json'))
    $rsa=New-Object Security.Cryptography.RSACryptoServiceProvider
    $rsa.PersistKeyInCsp=$false
    try {
        $rsa.FromXmlString($publicKey)
        $signature=[Convert]::FromBase64String([IO.File]::ReadAllText((Join-Path $stage 'feed.json.sig')))
        if (-not $rsa.VerifyData($bytes,'SHA256',$signature)) { throw 'The release signature is invalid.' }
    } finally { $rsa.Dispose() }
    $manifest=[Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.platform -ne 'windows-x64' -or $manifest.version -notmatch '^\d+\.\d+\.\d+$' -or $manifest.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Unsupported release metadata.' }
    if ($release -and ($release.tag_name -ne ('v' + $manifest.version) -or $release.draft -or $release.prerelease)) { throw 'The release does not match the signed version.' }
    $packageName='hianti-' + $manifest.version + '-windows-x64.zip'
    $packageUrl='https://github.com/' + $repository + '/releases/download/v' + $manifest.version + '/' + $packageName
    if ($manifest.url -ne $packageUrl) { throw 'The signed package targets a different distribution repository.' }
    if ($release) {
        $asset=@($release.assets | Where-Object name -eq $packageName)
        if ($asset.Count -ne 1) { throw 'The signed package was not found.' }
        $packageUrl=$asset[0].url
    }
    $archive=Join-Path $stage 'package.zip'
    Download $packageUrl $archive 52428800
    if ((Get-FileHash -LiteralPath $archive).Hash -ne $manifest.sha256) { throw 'Package checksum verification failed.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $package=Join-Path $stage 'package'
    $null=New-Item -ItemType Directory -Path $package
    $zip=[IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $seen=@{}; $total=0L
        foreach ($entry in $zip.Entries) {
            $name=$entry.FullName.Replace('\','/')
            $total+=$entry.Length
            if ($name -notin $allowed -or $seen.ContainsKey($name) -or $entry.Length -gt 30MB -or $total -gt 60MB -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Unsafe or unexpected package entry.' }
            $seen[$name]=$true
            $destination=Join-Path $package $name
            $null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$destination,$false)
        }
        if ($seen.Count -ne $allowed.Count) { throw 'Incomplete package.' }
    } finally { $zip.Dispose() }
    if ([IO.File]::ReadAllText((Join-Path $package 'trust-public.xml')).Trim() -ne $publicKey) { throw 'The package changes the trusted key.' }
    Write-Output 'Hianti | Signature and package verified'
    $oldProcessPolicy=Get-ExecutionPolicy -Scope Process
    if ($oldProcessPolicy -ne 'Bypass') {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
        $policyChanged=$true
    }
    & (Join-Path $package 'Install-Local.ps1') -InstallHome $InstallHome -NoPath:$NoPath -NoAuth:($NoAuth -or $publicDistribution) -Start:(-not $NoStart) -AppPath $AppPath -Port $Port -NoWatch:$NoWatch
} catch {
    $hint=if ($publicDistribution) { ' Check your connection to GitHub and retry the same command.' } else { ' For a private repository, supply your own read-access token in HIANTI_GITHUB_TOKEN.' }
    Write-Error ('Installation failed: ' + $_.Exception.Message + $hint)
} finally {
    $token=''
    [Net.ServicePointManager]::SecurityProtocol=$oldTls
    if ($policyChanged) { Set-ExecutionPolicy -Scope Process -ExecutionPolicy $oldProcessPolicy -Force }
    $resolved=(Resolve-Path -LiteralPath $stage).ProviderPath
    if ([IO.Path]::GetDirectoryName($resolved).TrimEnd('\') -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') -or [IO.Path]::GetFileName($resolved) -notmatch '^hianti-install-[0-9a-f]{32}$') { throw 'Unexpected cleanup path.' }
    if (@(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Refusing to clean linked files.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
}
