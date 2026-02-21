# GPU Text Search

> **Ultra-high-performance text search using GPU compute shaders**
>
> **Metal (macOS)** and **Vulkan (Linux/WSL2)** backends

---

## Backends

### Metal (macOS) — `main` branch
- Apple Metal compute shaders, Swift CLI
- 32+ GB/s on M2 Pro (200 GB/s unified memory)
- Zero-copy via `storageModeShared`
- Homebrew install: `brew tap teenu/gpu-text-search && brew install gpu-text-search`

### Vulkan (Linux/WSL2) — `vulkan` branch
- Vulkan compute shaders, C CLI
- 3.2 GB/s peak on AMD Vega 8 iGPU via WSL2 (DDR4-3200)
- Works on any Vulkan-capable GPU or CPU (lavapipe)
- Chunked processing for files of any size

---

## Vulkan Backend

### Requirements

- GCC, libvulkan-dev, glslang-tools
- A Vulkan ICD (lavapipe for CPU, RADV/dzn for GPU)

```bash
sudo apt install gcc libvulkan-dev glslang-tools make
```

### Build

```bash
git clone https://github.com/teenu/gpu-text-search.git
cd gpu-text-search
git checkout vulkan
make
```

Or without make:
```bash
glslangValidator -V shaders/search.comp -o shaders/search.comp.spv
gcc -O2 -Wall -Wextra -o gts src/main.c src/vk_init.c src/vk_search.c -lvulkan -lm
```

### Usage

```bash
./gts <file> <pattern> [--benchmark N]

# Examples
./gts genome.fasta "GATTACA"
./gts server.log "ERROR" --benchmark 10
```

### WSL2 GPU Setup

WSL2 doesn't expose `/dev/dri`, so standard Mesa drivers (RADV, ANV) won't find the GPU. The path is:

```
Vulkan → dzn (Mesa) → D3D12 → /dev/dxg → Windows GPU driver → GPU
```

To build the dzn driver from Mesa source:

```bash
sudo apt install meson ninja-build pkg-config python3-mako \
  libdrm-dev llvm-dev libelf-dev libexpat1-dev libclc-18-dev

pip3 install --user meson mako

git clone --depth 1 --branch mesa-25.2.8 \
  https://gitlab.freedesktop.org/mesa/mesa.git /tmp/mesa-dzn

cd /tmp/mesa-dzn
~/.local/bin/meson setup build \
  -Dvulkan-drivers=microsoft-experimental \
  -Dgallium-drivers= -Dglx=disabled -Degl=disabled \
  -Dplatforms= --buildtype=release

ninja -C build

sudo cp build/src/microsoft/vulkan/libvulkan_dzn.so /usr/local/lib/
sudo tee /usr/share/vulkan/icd.d/dzn_icd.x86_64.json << 'EOF'
{"ICD":{"api_version":"1.2.0","library_path":"/usr/local/lib/libvulkan_dzn.so"},"file_format_version":"1.0.0"}
EOF
sudo ldconfig
```

Then run with:
```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/dzn_icd.x86_64.json ./gts file pattern
```

### Architecture

Same algorithm as the Metal backend:

1. File is `mmap`'d and processed in 256 MB chunks
2. GLSL compute shader runs one thread per byte position
3. First/last byte pre-check eliminates ~90% of candidates
4. Unified loop for middle bytes, early exit on mismatch
5. Atomic counter for match count, position array for locations
6. Pre-allocated, persistently-mapped Vulkan buffers reused across chunks

```
src/
  main.c        CLI, mmap, chunked orchestration, benchmark stats
  vk_init.c/h   Instance, device, queue, memory type probing
  vk_search.c/h Pipeline, buffers, dispatch, result readback
shaders/
  search.comp   GLSL 450 compute shader (256 threads/workgroup)
```

### Performance

Tested on 3.2 GB genomic data, pattern "GATTACA" (691,704 matches):

| Backend | Throughput | Hardware |
|---------|-----------|----------|
| Vulkan + dzn | 3.2 GB/s peak | AMD Vega 8 iGPU, DDR4-3200, WSL2 |
| Vulkan + lavapipe | 0.8 GB/s | CPU software renderer |
| Metal | 32+ GB/s | Apple M2 Pro, LPDDR5 |

## Algorithm

Both backends implement identical search logic:

- **Thread model**: One thread per candidate position in the text
- **Pre-filter**: First and last byte comparison before full match (eliminates ~90%)
- **Matching**: Sequential byte comparison for middle characters with early exit
- **Results**: Atomic increment of match counter, bounded position storage
- **Overlapping**: Finds all overlapping occurrences (unlike `grep -o`)

## License

MIT License - see [LICENSE](LICENSE) file.
