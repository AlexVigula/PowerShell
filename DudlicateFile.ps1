#requires -version 3
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType 'Container'})]
    [string]
    $Path = (Get-Location).Path
)

function Get-FileMD5 {
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]
        $Path
    )
    
    $HashAlgorithm = [System.Security.Cryptography.MD5]::Create()
    try {
        $Stream = [System.IO.File]::OpenRead($Path)
        try {
            $HashByteArray = $HashAlgorithm.ComputeHash($Stream)
            return [System.BitConverter]::ToString($HashByteArray).ToLowerInvariant() -replace '-',''
        }
        finally {
            if ($Stream) { $Stream.Dispose() }
        }
    }
    catch {
        Write-Warning "Error processing file '$Path': $_"
        return $null
    }
}

# Проверка пути
if (-not (Test-Path $Path -PathType Container)) {
    Write-Error "Invalid path: $Path"
    exit 1
}

# Основная логика обработки
Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 0 } |
    Group-Object -Property Length |
    Where-Object { $_.Count -gt 1 } |
    ForEach-Object {
        $Group = $_
        
        # Добавляем хеш к каждому файлу
        $FilesWithHashes = $Group.Group | 
            Select-Object *, 
                @{Name = 'ContentHash'; Expression = { Get-FileMD5 -Path $_.FullName }} |
            Where-Object { $_.ContentHash -ne $null }
        
        # Группируем по хешу
        $FilesWithHashes |
            Group-Object -Property ContentHash |
            Where-Object { $_.Count -gt 1 } |
            ForEach-Object {
                [PSCustomObject]@{
                    Hash = $_.Name
                    Size = $Group.Name
                    Files = $_.Group.FullName
                    Count = $_.Count
                }
            }
    } |
    Format-List Hash, Size, Count, 
        @{Name = 'Files'; Expression = { $_.Files -join "`n" }}
