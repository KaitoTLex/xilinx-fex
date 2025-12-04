# Xilinx Vivado on NixOS/Apple Silicon

This repository provides a **NixOS environment** to run **Vivado (x86_64)** on **Apple Silicon (aarch64)** using:

- **FEX**: x86_64 userspace emulator  
- **muvm**: multi-userland virtual root for x86_64 libraries  
- **FHS environment**: for installing and running Vivado in a stable Linux filesystem layout  

---

## Features

- FEX enables x86_64 binaries to run on aarch64 NixOS.  
- muvm mounts x86_64 Nix store and library paths into `/run/muvm/x86_64-linux`.  
- The Vivado FHS environment ensures correct library paths, GTK/X11 support, and box64 for proper execution.  
- Fully integrated with Nix flakes and modular NixOS modules.

---

## Repository Structure

```Host (aarch64 NixOS)
│
├─ FEX → x86_64 emulation
│
├─ muvm → mounts x86_64 Nix store + libraries
│
└─ FHS environment → runs Vivado installer & binaries
```

- `FEX` ensures x86_64 binaries run on aarch64.  
- `muvm` provides a synthetic `/usr/x86_64-linux` root with all required x86_64 libraries.  
- `FHS environment` allows running the Vivado installer in a clean userland with proper libraries.

---

## Requirements

- Nix 3.x / flakes enabled  
- aarch64 Linux (Asahi NixOS recommended)  
- Vivado installer binary (`Xilinx_Unified_2025.x_Installer.bin`)  
- Optional: `sudo` access to bind mounts (muvm root setup)

---

## Setup

1. **Clone the repository**

`git clone https://github.com/KaitoTLex/xilinx-fex`  
`cd xilinx-fex`

2. **Enable NixOS modules**

In your system configuration:

```nix
{
  imports = [
    ./modules/fex.nix
    ./modules/muvm.nix
    ./modules/xilinx-fex.nix
  ];

  programs.fex.enable = true;
  virtualisation.muvm.enable = true;
  hardware.xilinx-fex.enable = true;
}```

3. Rebuild NixOS configuration
    `sudo nixos-rebuild switch`
## Enter FHS Env
Enter FHS Environment

To drop into the environment prepared for Vivado installation:

    nix run .#enter-fex-env

Inside the shell, `$MUVM_X86_ROOT` points to the mounted x86_64 pseudo-root:

```echo $MUVM_X86_ROOT
    # /run/muvm/x86_64-linux```

## Install Vivado

Launch the native Vivado installer (`/usr/x86_64-linux/bin/bash`)

Use all required libraries provided by the FHS and muvm mount
##Run Vivado

After installation, run Vivado from within the FHS environment:

`nix run .#enter-fex-env`

Then inside the FHS shell:

`vivado`
## Troubleshooting

Missing libraries / ELF errors
Ensure hardware.xilinx-fex.enable = true and programs.fex.enable = true are active. Rebuild the system to propagate all mounts.

Box64 / FEX issues

which box64
which FEXBash

Confirm both exist in $PATH inside the FHS shell.

OpenGL / GUI errors
Make sure your system has mesa, libGL, or proper X11 forwarding if using headless.
