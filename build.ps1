# build.ps1 - compile the CPU raytracer, and the CUDA version if main.cu exists.
# Usage:  .\build.ps1                 # build everything present
#         .\build.ps1 -Run            # build, then run whatever was built
#         .\build.ps1 -Interactive    # build ONLY interactive.cu (skip CPU + main.cu); add -Run to launch
param([switch]$Run, [switch]$Interactive)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# --- Locate the MSVC dev environment (vcvars64.bat sets up cl.exe / INCLUDE / LIB) ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsRoot  = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsRoot) { throw "MSVC (VC Tools) not found. Install the C++ workload." }
$vcvars = Join-Path $vsRoot "VC\Auxiliary\Build\vcvars64.bat"

# nvcc lives under CUDA_PATH\bin; fall back to the machine-level value if the session predates it
$cudaPath = $env:CUDA_PATH
if (-not $cudaPath) { $cudaPath = [Environment]::GetEnvironmentVariable('CUDA_PATH','Machine') }

# Each compile runs INSIDE one cmd process (a tiny temp .bat) that sources vcvars first, so cl/nvcc
# and their environment live in the same process. This replaces the old "import vcvars into
# PowerShell and hope PATH survives" approach, which intermittently dropped cl.exe when the session
# PATH was already long. Writing the command to a .bat also sidesteps cmd/PowerShell quote-nesting.
$batFile  = Join-Path $env:TEMP "rt_build_$PID.bat"
$cudaLine = if ($cudaPath) { "set `"PATH=$cudaPath\bin;%PATH%`"" } else { "" }
function Build-Step($desc, $cmdline) {
    Write-Host "==> $desc" -ForegroundColor Cyan
    Set-Content -LiteralPath $batFile -Encoding Ascii -Value @(
        "@echo off",
        "call `"$vcvars`" >nul 2>&1",
        $cudaLine,
        $cmdline
    )
    & $batFile
    if ($LASTEXITCODE -ne 0) { throw "$desc failed" }
}

# --- CPU build (skipped with -Interactive) ---
if (-not $Interactive) {
    Build-Step "Building CPU raytracer (raytracer.exe)" "cl /nologo /O2 /EHsc /std:c++17 /Fe:raytracer.exe main.cpp"
    Remove-Item *.obj -ErrorAction SilentlyContinue
}

# --- CUDA build (only if the port exists yet; skipped with -Interactive) ---
# -arch=sm_89: emit native Ada code for the RTX 4060 (no driver JIT).
# --use_fast_math was measured ~5% SLOWER here (occupancy thrashed L1/L2) - deliberately omitted.
if ((Test-Path "main.cu") -and (-not $Interactive)) {
    Build-Step "Building CUDA raytracer (raytracer_cuda.exe)" "nvcc -O3 -arch=sm_89 -o raytracer_cuda.exe main.cu"
}

# --- Interactive build (GLFW + OpenGL + CUDA-GL interop; only if the source exists) ---
# GLFW/GLAD from vcpkg; full lib paths dodge -L ambiguity; opengl32.lib off the vcvars LIB path.
# -Xcompiler /MD: vcpkg x64-windows libs use the DYNAMIC CRT; nvcc's host default is STATIC (/MT)
# -> unresolved __imp_* + LNK4098. /MD matches them. glfw3.dll must sit next to the exe at runtime.
if (Test-Path "interactive.cu") {
    $vcpkg = "C:\Users\piere\vcpkg\installed\x64-windows"
    Build-Step "Building interactive renderer (raytracer_interactive.exe)" "nvcc -O3 -arch=sm_89 -Xcompiler /MD -I`"$vcpkg\include`" -o raytracer_interactive.exe interactive.cu `"$vcpkg\lib\glfw3dll.lib`" `"$vcpkg\lib\glad.lib`" opengl32.lib"
    Copy-Item "$vcpkg\bin\glfw3.dll" -Destination $PSScriptRoot -Force
}

Remove-Item -LiteralPath $batFile -ErrorAction SilentlyContinue
Write-Host "==> Build OK" -ForegroundColor Green

if ($Run) {
    if     (Test-Path "raytracer_interactive.exe") { .\raytracer_interactive.exe }
    elseif (Test-Path "raytracer_cuda.exe")        { .\raytracer_cuda.exe }
    else                                            { .\raytracer.exe }
}
