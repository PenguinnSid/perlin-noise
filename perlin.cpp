#include <math.h>
#include <fstream>
#include <iostream>
//#include <stb_image_write.h>

using namespace std;

// defining a 2-D vector struct
typedef struct{
    float x,y;
} vector2;

// function to compute the random gradient (taken directly from video)
vector2 randomGradient(int ix, int iy) {
    // No precomputed gradients mean this works for any number of grid coordinates
    const unsigned w = 8 * sizeof(unsigned);
    const unsigned s = w / 2; 
    unsigned a = ix, b = iy;
    a *= 3284157443;
 
    b ^= a << s | a >> w - s;
    b *= 1911520717;
 
    a ^= b << s | b >> w - s;
    a *= 2048419325;
    float random = a * (3.14159265 / ~(~0u >> 1)); // in [0, 2*Pi]
    
    // Create the vector from the angle
    vector2 v;
    v.x = sin(random);
    v.y = cos(random);
 
    return v;
}

// function to calculate the dot product and gradient of each point
float dotPoduct(int a,int b,float x,float y){
   
    // (a,b) -> current grid point to find dot product with
    // (x,y) -> point being evaluated

    // random gradient associated with the grid points a,b
    vector2 gradient = randomGradient(a,b);

    // dist. vectors
    float dx = x - float(a);
    float dy = y - float(b);

    // dot prod.
    return (dx*gradient.x + dy*gradient.y);

}

// function to interpolate between 2 distances
float interpolate(float a0, float a1, float w){
    // a0 -> first interpolation input, a1 -> second interpolation input
    // w -> interpolation weight -> [0,1]
    return (a1-a0)*(3-w*2)*w*w + a0;
}

// function to sample perlin noise at any point (x,y)
float perlin(float x,float y){
    // grid points -> (floor and ciel integer values of x,y)
    int x1 = (int)x;
    int y1 = (int)y;
    int x2 = x1+1;
    int y2 = y1+1;

    // interpolation weights
    float wx = x - (float)x1;
    float wy = y - (float)y1;

    // interpolate at top 2 points
    float n0 = dotPoduct(x1,y1,x,y);
    float n1 = dotPoduct(x2,y1,x,y);
    // interpolation based on horizontal weight
    float ix1 = interpolate(n0,n1,wx);

    // interpolate at bottom 2 points
    n0 = dotPoduct(x1,y2,x,y);
    n1 = dotPoduct(x2,y2,x,y);
    // interpolation based on horizontal weight
    float ix2 = interpolate(n0,n1,wx);

    // interpolate by vertical weight
    float result = interpolate(ix1,ix2,wy);

    // returns the final perlin sample at the point
    return result;
}

int main(){

    // stores image in a PGM file
    ofstream image("perlin.pgm");

    // sampling resolution
    const int width = 1920;
    const int height = 1080;

    // initializing PGM file header
    image << "P2\n";
    image << width << " " << height << "\n";
    image << "255\n";

    // sampling scale (determines the grid)
    float scale = 0.02f;

    for(int y = 0;y<height;y++){
        for(int x = 0;x<width;x++){

            // initialize values
            float val = 0.0f;
            float freq = 1.0f;
            float amp = 1.0f;
            float maxAmp = 0.0f;

            for(int octave = 0;octave < 12;octave++){
                
                // calculate perlin noise
                val+=perlin(x*scale*freq,y*scale*freq)*amp;
                // clipping 
                maxAmp+=amp; 

                // frequency doubled and amplitude halved for each octave
                freq*=2.0f;
                amp*=0.5f;

            }

            // normalizes values to the range [-1,1]
            val/= maxAmp;

            // normalize value from [-1,1] to [0,255]
            int pixel = (int)((val + 1.0f) * 0.5f * 255.0f);

            image<<pixel<<" ";
        }
        image<<"\n";
    }
    image.close();

    return 0;
}