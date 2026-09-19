<#
    把本仓库的本地修复同步到正在运行的 MBCCtools 安装目录。

    背景：MBCCtools 的「更新资源」会整包覆盖安装目录（连程序文件一起写入），
    本仓库里的改动（例如 resource/base/pipeline/启动.json 的「等待进入游戏」逻辑）
    会在更新后丢失。更新完再跑一次本脚本即可恢复。

    用法：
        pwsh -File .\apply-local-fix.ps1
        pwsh -File .\apply-local-fix.ps1 -InstallDir "D:\jiaoben\MBCCtools-win-x86_64-v1.3.9"
        pwsh -File .\apply-local-fix.ps1 -CheckOnly     # 只对比，不写入
#>
param(
    [string]$InstallDir = "D:\jiaoben\MBCCtools-win-x86_64-v1.3.9",
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# 需要同步到安装目录的本地补丁文件（相对仓库根目录）
$patchedFiles = @(
    'interface.json',
    'resource\base\pipeline\启动.json',
    'resource\base\pipeline\体力.json',
    'resource\base\pipeline\项目名.json',
    'resource\base\pipeline\切换账号.json',
    'resource\base\image\切换账号.png',
    'resource\base\image\体力3.png'
)

if (-not (Test-Path -LiteralPath $InstallDir)) {
    throw "安装目录不存在：$InstallDir"
}

$changed = 0
$same = 0
$backupDir = Join-Path $InstallDir 'backup'

foreach ($rel in $patchedFiles) {
    $src = Join-Path $repoRoot $rel
    $dst = Join-Path $InstallDir $rel
    if (-not (Test-Path -LiteralPath $src)) { throw "仓库文件缺失：$src" }

    # 新增文件：安装目录里还没有，直接写入（备份阶段跳过）
    if (-not (Test-Path -LiteralPath $dst)) {
        if ($CheckOnly) {
            Write-Host "[需要新增] $rel" -ForegroundColor Yellow
            $changed++
            continue
        }
        $dstDir = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        Copy-Item -LiteralPath $src -Destination $dst -Force
        $newHash = (Get-FileHash -LiteralPath $dst).Hash
        if ($newHash -ne (Get-FileHash -LiteralPath $src).Hash) { throw "写入后校验失败：$dst" }
        Write-Host "[已新增] $rel" -ForegroundColor Cyan
        $changed++
        continue
    }

    $srcHash = (Get-FileHash -LiteralPath $src).Hash
    $dstHash = (Get-FileHash -LiteralPath $dst).Hash

    if ($srcHash -eq $dstHash) {
        Write-Host "[一致] $rel" -ForegroundColor Green
        $same++
        continue
    }

    if ($CheckOnly) {
        Write-Host "[需要同步] $rel" -ForegroundColor Yellow
        $changed++
        continue
    }

    if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = Join-Path $backupDir ("{0}.{1}.bak" -f (Split-Path -Leaf $rel), $stamp)
    Copy-Item -LiteralPath $dst -Destination $bak -Force
    Copy-Item -LiteralPath $src -Destination $dst -Force

    $newHash = (Get-FileHash -LiteralPath $dst).Hash
    if ($newHash -ne $srcHash) { throw "写入后校验失败：$dst" }
    Write-Host "[已同步] $rel  (原文件备份到 $bak)" -ForegroundColor Cyan
    $changed++
}

Write-Host ""
Write-Host ("同步 {0} 个，已一致 {1} 个。" -f $changed, $same)
if ($CheckOnly -and $changed -gt 0) { exit 1 }
if ($changed -gt 0 -and -not $CheckOnly) {
    Write-Host "请重启 MFAAvalonia 让资源改动生效。" -ForegroundColor Yellow
}
