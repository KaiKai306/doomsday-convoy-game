[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)][string[]]$RelativePath
)
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$indexPath = Join-Path $projectRoot '.docs\发布\清理归档索引.json'
$index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
$archiveRoot = [System.IO.Path]::GetFullPath([string]$index.archive_root)
$workspace = [System.IO.Path]::GetFullPath('E:\AI_Workspace')
$rootPrefix = $projectRoot.TrimEnd('\') + '\'
$archivePrefix = $archiveRoot.TrimEnd('\') + '\'
if (-not $projectRoot.StartsWith($workspace + '\', [System.StringComparison]::OrdinalIgnoreCase) -or -not $archiveRoot.StartsWith($workspace + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Project and archive must be inside the intended workspace.'
}
$rows = Import-Csv -LiteralPath (Join-Path $projectRoot '.docs\发布\清理文件清单.csv') -Encoding UTF8
$restored = 0
foreach ($requested in $RelativePath) {
    $normalized = $requested.Replace('\','/')
    $row = @($rows | Where-Object { $_.path -ceq $normalized })
    if ($row.Count -ne 1) { throw ('Path is not an exact manifest entry: ' + $requested) }
    $source = [System.IO.Path]::GetFullPath((Join-Path $archiveRoot $requested))
    $destination = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $requested))
    if (-not $source.StartsWith($archivePrefix,[System.StringComparison]::OrdinalIgnoreCase) -or -not $destination.StartsWith($rootPrefix,[System.StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes the project/archive.' }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw ('Archive file is missing: ' + $source) }
    $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $row[0].sha256) { throw ('Archive checksum mismatch: ' + $source) }
    if (Test-Path -LiteralPath $destination) { throw ('Destination already exists; refusing to overwrite: ' + $destination) }
    if ($PSCmdlet.ShouldProcess($destination, 'Restore verified archive file')) {
        New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination
        if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw ('Restored checksum mismatch: ' + $destination) }
        $restored += 1
    }
}
Write-Output ('RESTORE_COMPLETE files=' + $restored)
