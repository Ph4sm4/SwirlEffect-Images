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

Swirl = 0.0
<img width="802" height="604" alt="image" src="https://github.com/user-attachments/assets/1ac20b65-7736-4f2c-a663-60351018de28" />

Swirl = 2.0
<img width="802" height="602" alt="image" src="https://github.com/user-attachments/assets/41b304c4-05d4-4082-95b4-0f02fa8ab2be" />

Swirl = 6.0
<img width="803" height="601" alt="image" src="https://github.com/user-attachments/assets/bd710624-915f-4787-b5d1-b3384eaee81e" />

Swirl = 12.0
<img width="798" height="604" alt="image" src="https://github.com/user-attachments/assets/fc26bb79-d514-4022-b9f9-6d099cdad04f" />


