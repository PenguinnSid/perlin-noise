# perlin-noise

Perlin Noise implementation in CPP

Tutorial Video Link: https://youtu.be/kCIaHqb60Cw?si=ci5PX04gFqfMkOvz

Generates a PGM file.
Uses ImageMagick to convert PGM files to PNG images.

Plan to implement octaves.
Plan to accelerate using CUDA.

## How to run

# Linux

Install imagemagick for PGM -> PNG conversions
```bash
sudo apt update
sudo apt install imagemagick
```

Compile and Run the file
```bash
g++ perlin.cpp -o perlin
./perlin
```

Convert the PGM image to PNG
```bash
convert perlin.pgm perlin.png
```

# Windows
