# perlin-noise

Perlin Noise implementation in CPP

Tutorial Video Link: https://youtu.be/kCIaHqb60Cw?si=ci5PX04gFqfMkOvz

Generates a PGM file.
Uses ImageMagick to convert PGM files to PNG images.

Plan to implement octaves.
Plan to accelerate using CUDA.

## How to run

### Linux

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

### Windows

Install ImageMagick for PGM -> PNG conversions
```powershell
winget install ImageMagick.ImageMagick
```

Compile and Run the file
```powershell
g++ perlin.cpp -o perlin.exe 
.\perlin.exe
```

Convert the PGM image to PNG
```powershell
magick perlin.pgm perlin.png
```