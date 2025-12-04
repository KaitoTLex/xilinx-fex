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


