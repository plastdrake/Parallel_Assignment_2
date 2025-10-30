# Parallel_Assignment_2

This repository contains the Parallel Assignment 2 project: a Mandelbrot renderer with a CUDA runtime and a .NET GUI window.

Contents
- `Mandelbrot.sln` — Visual Studio solution containing the projects.
- `CudaRuntime/` — C++ / CUDA runtime project (native). Contains `kernel.cu` and a Visual C++ project.
- `MandelWindow/` — .NET GUI application (C#) that uses the native CUDA runtime.

Quick start (Windows)

1. Recommended: open `Mandelbrot.sln` in Visual Studio (2019/2022/2023) and build the solution in `Debug` or `Release` configuration. This will build the native CUDA project and the .NET GUI.

2. Command-line build options:

- Build the .NET GUI only:

```powershell
dotnet build Mandelbrot\MandelWindow -c Debug
```

- Build the whole solution with MSBuild (Developer Command Prompt / Visual Studio tools):

```powershell
msbuild Mandelbrot.sln /p:Configuration=Debug
```

Run

After building, run the GUI from:

- `Mandelbrot\MandelWindow\bin\Debug\net8.0-windows\MandelWindow.exe`

Notes about CUDA

- The `CudaRuntime` project is a native C++/CUDA project and requires a compatible CUDA toolkit and Visual Studio integration to build the `.dll` for the GUI to load.
- If you only run the GUI without a built `CudaRuntime.dll`, the application may fail to load native functionality.

Git housekeeping

- A repository-level `.gitignore` was added to stop committing build outputs and IDE temporary files (e.g. `bin/`, `obj/`, `.vs/`, `x64/` and common CUDA build artifacts).
- If you have local generated files that were previously tracked, run the following once from the repository root to untrack them (this keeps the files locally but removes them from Git):

```powershell
git add .gitignore
git rm -r --cached .
git add .
git commit -m "Remove previously tracked build artifacts and apply .gitignore"
git push
```
