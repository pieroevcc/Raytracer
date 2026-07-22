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

# nvcc lives under CUDA_PATH\bin; the session may predate the installer's env change,
# so fall back to the machine-level value
$cudaPath = $env:CUDA_PATH
if (-not $cudaPath) { $cudaPath = [Environment]::GetEnvironmentVariable('CUDA_PATH','Machine') }
if ($cudaPath) { $env:PATH = "$cudaPath\bin;$env:PATH" }

# --- CPU build ---
Write-Host "==> Building CPU raytracer (raytracer.exe)" -ForegroundColor Cyan
cl /nologo /O2 /EHsc /std:c++17 /Fe:raytracer.exe main.cpp
if ($LASTEXITCODE -ne 0) { throw "CPU build failed" }
Remove-Item *.obj -ErrorAction SilentlyContinue

# --- CUDA build (only if the port exists yet) ---
if (Test-Path "main.cu") {
    Write-Host "==> Building CUDA raytracer (raytracer_cuda.exe)" -ForegroundColor Cyan
    # -arch=sm_89: emit native code for the RTX 4060 (Ada) instead of PTX,
    # so the (older) driver never has to JIT-compile it
    # NOTE: --use_fast_math was measured ~5% SLOWER here (raised occupancy thrashed L1/L2),
    # so it is deliberately omitted. Wall-clock overruled the occupancy metric. Don't re-add.
    nvcc -O3 -arch=sm_89 -o raytracer_cuda.exe main.cu
    if ($LASTEXITCODE -ne 0) { throw "CUDA build failed" }
}

# --- Interactive build (GLFW + OpenGL, CUDA-GL interop from A2 on; only if the source exists) ---
# Compiled with nvcc even though A1 has no device code, so A2's interop lands in the same file
# with zero rewiring. GLFW/GLAD come from vcpkg; full lib paths dodge any -L search ambiguity,
# opengl32.lib resolves off the vcvars LIB path. glfw3.dll must sit next to the exe at runtime.
# -Xcompiler "/MD": vcpkg's x64-windows libs are built against the DYNAMIC CRT, but nvcc's host
# default is the STATIC CRT (/MT) -> unresolved __imp_* symbols + LNK4098. /MD matches them.
if (Test-Path "interactive.cu") {
    Write-Host "==> Building interactive renderer (raytracer_interactive.exe)" -ForegroundColor Cyan
    $vcpkg = "C:\Users\piere\vcpkg\installed\x64-windows"
    nvcc -O3 -arch=sm_89 -Xcompiler "/MD" -I"$vcpkg\include" -o raytracer_interactive.exe interactive.cu "$vcpkg\lib\glfw3dll.lib" "$vcpkg\lib\glad.lib" opengl32.lib
    if ($LASTEXITCODE -ne 0) { throw "Interactive build failed" }
    Copy-Item "$vcpkg\bin\glfw3.dll" -Destination $PSScriptRoot -Force
}

Write-Host "==> Build OK" -ForegroundColor Green

if ($Run) {
    if     (Test-Path "raytracer_interactive.exe") { .\raytracer_interactive.exe }
    elseif (Test-Path "raytracer_cuda.exe")        { .\raytracer_cuda.exe }
    else                                            { .\raytracer.exe }
}
