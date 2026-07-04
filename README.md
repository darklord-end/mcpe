# Minecraft Potet Edition

> **Fork of mcpe64** - Source code for **Minecraft Pocket Edition 0.6.1 alpha** with various fixes, improvements, and automated builds.

[![Android Build](https://github.com/darklord-end/mcpe/actions/workflows/build-android.yml/badge.svg)](https://github.com/darklord-end/mcpe/actions/workflows/build-android.yml)
[![Linux Build](https://github.com/darklord-end/mcpe/actions/workflows/build-linux.yml/badge.svg)](https://github.com/darklord-end/mcpe/actions/workflows/build-linux.yml)
[![WebAssembly Build](https://github.com/darklord-end/mcpe/actions/workflows/build-webassembly.yml/badge.svg)](https://github.com/darklord-end/mcpe/actions/workflows/build-webassembly.yml)
[![Full Build](https://github.com/darklord-end/mcpe/actions/workflows/build-all.yml/badge.svg)](https://github.com/darklord-end/mcpe/actions/workflows/build-all.yml)

**Minecraft Potet Edition** is a fork of the original **Minecraft Pocket Edition 0.6.1 alpha** source code with automated CI/CD pipelines for easy building on multiple platforms.

This project builds upon the work by [Kolyah35](https://gitea.sffempire.ru/Kolyah35/minecraft-pe-0.6.1) and the [mcpe64](https://github.com/darklord-end/mcpe) repository, adding **automated builds** for Android, Linux, and WebAssembly.

## Features

### Game Features
- ✅ Fixed fog rendering
- ✅ Fixed sound system
- ✅ Added sprinting
- ✅ Semi-working chat and commands
- ✅ Options menu implementation
- ✅ Android build support with touch controls
- ✅ Improved F3 debug screen
- ❌ Controller support (planned)
- ❌ Minecraft server hosting (planned)
- ❌ Performance optimizations (planned)

### Build Features
- ✅ **Automated Android APK builds** via GitHub Actions
- ✅ **Automated Linux builds** via GitHub Actions
- ✅ **Automated WebAssembly builds** via GitHub Actions
- ✅ **Parallel builds** for faster CI
- ✅ **Caching** for faster builds
- ✅ **Artifact upload** for easy download

## Quick Start

### Download Pre-built Binaries

The easiest way to get started is to download pre-built binaries from GitHub Actions:

1. Go to the **[Actions](https://github.com/darklord-end/mcpe/actions)** tab
2. Select a completed workflow run (e.g., "Minecraft Potet Edition - Full Build")
3. Scroll down to **Artifacts** section
4. Download the appropriate artifact:
   - **Android**: `minecraft-potet-edition-android-*.zip`
   - **Linux**: `minecraft-potet-edition-linux-*.zip`
   - **WebAssembly**: `minecraft-potet-edition-wasm-*.zip`

### Build from Source

#### Android

**Automated Build (Recommended):**
1. Go to **[Actions](https://github.com/darklord-end/mcpe/actions/workflows/build-android.yml)**
2. Click **Run workflow**
3. Select branch and build type (debug/release)
4. Download the APK from artifacts

**Manual Build:**
```powershell
# Download Android NDK r14b and Android SDK
# Set environment variables:
#   ANDROID_HOME=C:\android-sdk
#   ANDROID_NDK_HOME=C:\android-ndk-r14b

# Full build (NDK + Java + APK)
.\build.ps1

# Skip NDK recompile (Java/assets changed only)
.\build.ps1 -NoJava

# Skip Java recompile (C++ changed only)
.\build.ps1 -NoCpp

# Only repackage + install (no recompile at all)
.\build.ps1 -NoBuild
```

#### Linux

**Automated Build (Recommended):**
1. Go to **[Actions](https://github.com/darklord-end/mcpe/actions/workflows/build-linux.yml)**
2. Click **Run workflow**
3. Select branch and build type (debug/release)
4. Download the binary from artifacts

**Manual Build:**
```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y build-essential cmake git \
    libgl1-mesa-dev libglu1-mesa-dev \
    libx11-dev libxrandr-dev libxinerama-dev \
    libxcursor-dev libxi-dev \
    libwayland-dev libwayland-cursor-dev libwayland-egl-dev libxkbcommon-dev \
    libasound2-dev libpulse-dev \
    libopenal-dev libglfw3-dev \
    libsndfile1-dev libambisonic-dev \
    pkg-config libdrm-dev libgbm-dev ninja-build

# Clone and build
git clone https://github.com/darklord-end/mcpe.git
cd mcpe
mkdir -p build/linux
cd build/linux
cmake -DCMAKE_BUILD_TYPE=Release -G Ninja ../..
ninja -j$(nproc)

# Run
./MinecraftPotetEdition
```

#### WebAssembly

**Automated Build (Recommended):**
1. Go to **[Actions](https://github.com/darklord-end/mcpe/actions/workflows/build-webassembly.yml)**
2. Click **Run workflow**
3. Select branch and build type (debug/release)
4. Download the WebAssembly files from artifacts

**Manual Build:**
```bash
# Install Emscripten SDK
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
cd ..

# Install dependencies
sudo apt-get update
sudo apt-get install -y cmake ninja-build git python3 python3-pip
pip3 install --user -r emsdk/emscripten/requirements.txt

# Clone and build
git clone https://github.com/darklord-end/mcpe.git
cd mcpe
mkdir -p build/webassembly
cd build/webassembly
emcmake cmake -DCMAKE_BUILD_TYPE=Release -G Ninja ../..
ninja -j$(nproc)

# Run (you'll need a web server)
python3 -m http.server 8000
# Then open http://localhost:8000 in your browser
```

## Build Workflows

This project includes several GitHub Actions workflows for automated building:

| Workflow | Description | Badge |
|----------|-------------|-------|
| [build-android.yml](.github/workflows/build-android.yml) | Builds Android APK | [![Android](https://github.com/darklord-end/mcpe/actions/workflows/build-android.yml/badge.svg)](https://github.com/darklord-end/mcpe/actions/workflows/build-android.yml) |
| [build-linux.yml](.github/workflows/build-linux.yml) | Builds Linux binary | [![Linux](https://github.com/darklord-end/mcpe/actions/workflows/build-linux.yml/badge.svg)](https://github.com/darklord-end/mcpe/actions/workflows/build-linux.yml) |
| [build-webassembly.yml](.github/workflows/build-webassembly.yml) | Builds WebAssembly | [![WebAssembly](https://github.com/darklord-end/mcpe/actions/workflows/build-webassembly.yml/badge.svg)](https://github.com/darklord-end/mcpe/actions/workflows/build-webassembly.yml) |
| [build-all.yml](.github/workflows/build-all.yml) | Runs all builds in parallel | [![All](https://github.com/darklord-end/mcpe/actions/workflows/build-all.yml/badge.svg)](https://github.com/darklord-end/mcpe/actions/workflows/build-all.yml) |

See [.github/workflows/README.md](.github/workflows/README.md) for detailed documentation.

## Project Structure

```
.
├── src/                    # Main source code (C++)
│   ├── client/             # Client code (GUI, rendering, input)
│   ├── server/             # Server code
│   ├── world/              # World logic (entities, inventory, items)
│   ├── network/            # Network handling
│   ├── raknet/             # RakNet networking library
│   ├── nbt/                # NBT data handling
│   └── platform/           # Platform-specific code
├── data/                   # Game resources
│   ├── images/             # Textures
│   ├── sound/              # Sound files
│   ├── fonts/              # Fonts
│   └── lang/               # Localization files
├── project/                # Platform-specific projects
│   └── android/            # Android project files
├── .github/                # GitHub configuration
│   └── workflows/          # CI/CD workflows
└── CMakeLists.txt          # Main CMake configuration
```

## Roadmap

### Game Development
- [ ] Add controller support
- [ ] Implement Minecraft server hosting
- [ ] Fix remaining screen issues on Android
- [ ] Performance optimizations
- [ ] Add more commands
- [ ] Improve multiplayer stability

### Build System
- [x] Android automated builds
- [x] Linux automated builds
- [x] WebAssembly automated builds
- [ ] macOS build support
- [ ] Windows build support
- [ ] Docker images for development
- [ ] Automated releases

## Contributing

Contributions are welcome! Here's how you can help:

1. **Report bugs**: Open an issue with detailed information
2. **Suggest features**: Open an issue with your feature request
3. **Submit code**: Fork the repository, make changes, and submit a pull request
4. **Improve builds**: Help optimize the CI/CD workflows

### Development Setup

```bash
# Clone the repository
git clone https://github.com/darklord-end/mcpe.git
cd mcpe

# Set up for your platform (see build instructions above)
```

## Credits

- **Original Repository**: [Kolyah35/minecraft-pe-0.6.1](https://gitea.sffempire.ru/Kolyah35/minecraft-pe-0.6.1)
- **mcpe64 Fork**: [darklord-end/mcpe](https://github.com/darklord-end/mcpe)
- **Build System**: Custom GitHub Actions workflows

## Community

Join the Discord server for updates and support:
[![Discord](https://img.shields.io/badge/Discord-Join-blue?style=for-the-badge&logo=discord)](https://discord.gg/ryZ884DWJf)

## License

This project is a fork of the original Minecraft Pocket Edition 0.6.1 alpha source code. The original code is proprietary to Mojang/Microsoft. This repository is for educational and preservation purposes only.

---

**Minecraft Potet Edition** - Preserving and improving Minecraft PE 0.6.1 for the community.
