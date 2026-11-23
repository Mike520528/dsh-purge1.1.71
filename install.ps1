#requires -Version 5.1
<#
  dsh-purge 1.1.71 安装器（rc.2 ready）
  用法：右键"使用 PowerShell 运行"，或
        powershell -ExecutionPolicy Bypass -File .\install.ps1
  参数：
        -DshExe <路径>   手动指定 DeepSeek Harness.exe
        -Force           版本不匹配也强行安装（不推荐）
#>
[CmdletBinding()]
param(
    [string]$DshExe,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ExpectedDsh = '0.2.0-rc.2'
$PluginName  = 'dsh-purge'

function Step($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Warn2($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[x] $m" -ForegroundColor Red }

Write-Host ""
Write-Host "  dsh-purge 1.1.71 installer (target: DSH $ExpectedDsh)" -ForegroundColor White
Write-Host "  ------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# ---------- 1. 定位 DSH ----------
if (-not $DshExe) {
    $cands = @()
    $p = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*DeepSeek*' } | Select-Object -First 1
    if ($p -and $p.Path) { $cands += $p.Path }
    $cands += @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'),
        'C:\Program Files\DeepSeek Harness\DeepSeek Harness.exe'
    )
    if (${env:ProgramFiles(x86)}) { $cands += (Join-Path ${env:ProgramFiles(x86)} 'DeepSeek Harness\DeepSeek Harness.exe') }
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                   'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        Get-ItemProperty $k -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like '*DeepSeek Harness*' -and $_.DisplayIcon } |
            ForEach-Object { $cands += ($_.DisplayIcon -replace ',\d+$', '') }
    }
    $DshExe = $cands | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $DshExe -or -not (Test-Path $DshExe)) {
    Fail '找不到 DeepSeek Harness.exe'
    Warn2 '请用 -DshExe "完整路径" 指定，例如：'
    Warn2 '  .\install.ps1 -DshExe "C:\Users\你\AppData\Local\Programs\DeepSeek Harness\DeepSeek Harness.exe"'
    exit 1
}
Ok "DSH: $DshExe"

# ---------- 2. 版本校验 ----------
$ver = (Get-Item $DshExe).VersionInfo.FileVersion
Step "当前 DSH 版本 $ver / 本包要求 $ExpectedDsh"
if ($ver -ne $ExpectedDsh) {
    if (-not $Force) {
        Fail '版本不匹配，已中止。'
        Warn2 '这个包里的补丁按 0.2.0-rc.2 的文件内容定位，换版本会静默错位。'
        Warn2 '确实要装就加 -Force。'
        exit 2
    }
    Warn2 "版本不符，按 -Force 继续（补丁可能部分失效）"
} else {
    Ok '版本匹配'
}

# ---------- 3. DSH_HOME / profile ----------
$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
$prof    = Join-Path $dshHome 'profiles\desktop'
$pkgJson = Join-Path $prof 'package.json'
if (-not (Test-Path $pkgJson)) { Fail "找不到 $pkgJson"; exit 1 }
Ok "Profile: $prof"

# ---------- 4. 冲突检查 ----------
$cur    = Get-Content $pkgJson -Raw | ConvertFrom-Json
$deps   = [ordered]@{}
if ($cur.dependencies) { $cur.dependencies.PSObject.Properties | ForEach-Object { $deps[$_.Name] = $_.Value } }
$bundles = @()
if ($cur.dsh -and $cur.dsh.profile -and $cur.dsh.profile.bundles) { $bundles = @($cur.dsh.profile.bundles) }

foreach ($n in 'Xsdsh-purge', 'dsh-purge-community') {
    if ($deps.Contains($n) -or ($bundles -contains $n)) {
        Fail "检测到冲突插件：$n"
        Warn2 '两者都往 app.asar.unpacked 打补丁，同时启用会互相覆盖。'
        Warn2 "请先从 $pkgJson 里移除 $n，再运行本脚本。"
        exit 3
    }
}
if ($deps.Contains($PluginName)) { Warn2 "$PluginName 已存在，将被覆盖" }

# ---------- 5. 备份 ----------
$bak = "$pkgJson.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item $pkgJson $bak -Force
Ok "已备份 -> $(Split-Path $bak -Leaf)"

# ---------- 6. 定位并固化 tgz ----------
$srcTgz = Join-Path $PSScriptRoot 'dsh-purge-1.1.71-rc2.tgz'
if (-not (Test-Path $srcTgz)) { Fail "缺少 $srcTgz（请保持与本脚本同目录）"; exit 1 }

# 复制一份到 profile 内，之后删掉/移动这个压缩包文件夹也不影响安装
$localDir = Join-Path $prof '_local-plugins'
New-Item -ItemType Directory -Force -Path $localDir | Out-Null
$tgz = Join-Path $localDir 'dsh-purge-1.1.71-rc2.tgz'
Copy-Item $srcTgz $tgz -Force
Ok "插件包已固化到 $localDir"

# ---------- 7. 改写 profile/package.json ----------
$deps[$PluginName] = 'file:' + ($tgz -replace '\\', '/')
if ($bundles -notcontains $PluginName) { $bundles += $PluginName }

if (-not ($cur.PSObject.Properties.Name -contains 'dsh')) {
    $cur | Add-Member -NotePropertyName dsh -NotePropertyValue (New-Object psobject) -Force
}
if (-not $cur.dsh -or -not ($cur.dsh.PSObject.Properties.Name -contains 'profile')) {
    $cur.dsh | Add-Member -NotePropertyName profile -NotePropertyValue (New-Object psobject) -Force
}
$cur | Add-Member -NotePropertyName dependencies -NotePropertyValue ([pscustomobject]$deps) -Force
$cur.dsh.profile | Add-Member -NotePropertyName bundles -NotePropertyValue ([string[]]$bundles) -Force

$json = $cur | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($pkgJson, $json, (New-Object System.Text.UTF8Encoding($false)))
Ok "已写入 dependencies + bundles"

# ---------- 8. 安装 ----------
$nodeExe = $null
$resDir  = Join-Path (Split-Path $DshExe) 'resources'
foreach ($c in @(
    (Join-Path $resDir 'runtime\primary-runtime\dependencies\node\bin\node.exe')
)) { if (Test-Path $c) { $nodeExe = $c; break } }
if (-not $nodeExe) { $c = Get-Command node -ErrorAction SilentlyContinue; if ($c) { $nodeExe = $c.Source } }

$pnpm = $null
foreach ($c in @(
    (Join-Path $dshHome 'dsh-runtimes\dsh-primary-runtime\dependencies\pnpm\bin\pnpm.cjs'),
    (Join-Path $dshHome 'dsh-runtimes\dsh-primary-runtime\dependencies\pnpm\pnpm.cjs')
)) { if (Test-Path $c) { $pnpm = $c; break } }
if (-not $pnpm) { $c = Get-Command pnpm -ErrorAction SilentlyContinue; if ($c) { $pnpm = $c.Source } }

if ($pnpm -and $nodeExe) {
    Step '正在执行 pnpm install（首次可能稍慢）...'
    Push-Location $prof
    try { & $nodeExe $pnpm install --no-frozen-lockfile } catch { Warn2 "pnpm 异常：$_" }
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -eq 0) { Ok 'pnpm install 完成' } else { Warn2 "pnpm 返回 $code，转手动解包" }
} else {
    Warn2 '未找到 pnpm / node，跳过包管理器，直接手动解包'
}

$target = Join-Path $prof "node_modules\$PluginName"
if (-not (Test-Path (Join-Path $target 'package.json'))) {
    Step "手动解包 -> node_modules\$PluginName"
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    & tar -xzf $tgz -C $target --strip-components=1
    if ($LASTEXITCODE -ne 0) { Fail "解包失败，退出码 $LASTEXITCODE"; exit 4 }
    Ok '已解包'
}

# ---------- 9. 收尾 ----------
$final = Join-Path $target 'package.json'
if (-not (Test-Path $final)) { Fail '安装不完整'; exit 4 }

$v = (Get-Content $final -Raw | ConvertFrom-Json).version
Ok "dsh-purge $v 已就位：$target"
Write-Host ''
Write-Host '  下一步：完全退出并重启 DeepSeek Harness。' -ForegroundColor Cyan
Write-Host '  若启动日志提示插件不兼容，按提示执行 dsh plugin allow-version。' -ForegroundColor DarkGray
Write-Host '  卸载：从 profile/package.json 移除 dsh-purge 两处引用，然后重启。' -ForegroundColor DarkGray
Write-Host ''