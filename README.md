# Image Swirl Effect in x86 Assembly

A real-time image swirl/vortex effect implemented in 32-bit x86 assembly using FPU instructions, with a C++/OpenGL viewer.

## Features

- Swirl transformation written entirely in x86 assembly (NASM)
- Uses x87 FPU for floating-point math (sin, cos, atan2, sqrt)
- OpenGL/GLFW-based image viewer
- Configurable swirl intensity via command line
- Supports images with 1-4 channels (grayscale, RGB, RGBA)

## Building

```bash
make
```

## Usage

```bash
./image_viewer <image_path> <swirl_strength>
```

**Example:**
```bash
./image_viewer photo.jpg 2.0
```

- `swirl_strength`: Controls the intensity of the swirl effect. Try values between -5.0 and 5.0. Negative values swirl in the opposite direction.

## Dependencies

- NASM assembler
- GCC/G++ compiler (32-bit support)
- GLFW 3.x
- OpenGL 3.3+

## How It Works

The assembly code (`swirl.asm`) transforms each pixel by:
1. Computing the distance and angle from the image center
2. Applying a rotation based on distance (closer pixels rotate more)
3. Sampling the source image at the computed coordinates

Pixels outside the swirl radius are copied unchanged for efficiency.
