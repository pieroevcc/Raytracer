# build.ps1 - compile the CPU raytracer, and the CUDA version if main.cu exists.
# Usage:  .\build.ps1            # build everything present
#         .\build.ps1 -Run       # build, then run whatever was built
param([switch]$Run)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# --- Locate the MSVC dev environment (cl.exe needs INCLUDE/LIB/PATH set) ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsRoot  = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsRoot) { throw "MSVC (VC Tools) not found. Install the C++ workload." }
$vcvars = Join-Path $vsRoot "VC\Auxiliary\Build\vcvars64.bat"

# Import the vcvars environment into this session (so cl.exe + nvcc's host compiler resolve)
cmd /c "`"$vcvars`" 2>nul && set" | ForEach-Object {
    if ($_ -match '^(.*?)=(.*)$') { Set-Item -Path "env:$($matches[1])" -Value $matches[2] }
}

# --- CPU build ---
Write-Host "==> Building CPU raytracer (raytracer.exe)" -ForegroundColor Cyan
cl /nologo /O2 /EHsc /std:c++17 /Fe:raytracer.exe main.cpp
if ($LASTEXITCODE -ne 0) { throw "CPU build failed" }
Remove-Item *.obj -ErrorAction SilentlyContinue

# --- CUDA build (only if the port exists yet) ---
if (Test-Path "main.cu") {
    Write-Host "==> Building CUDA raytracer (raytracer_cuda.exe)" -ForegroundColor Cyan
    nvcc -O3 -o raytracer_cuda.exe main.cu
    if ($LASTEXITCODE -ne 0) { throw "CUDA build failed" }
}

Write-Host "==> Build OK" -ForegroundColor Green

if ($Run) {
    if (Test-Path "raytracer_cuda.exe") { .\raytracer_cuda.exe } else { .\raytracer.exe }
}
