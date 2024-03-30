#ifndef _INCLUDED_EDGEDETECT_ALGORITHM_H_
#define _INCLUDED_EDGEDETECT_ALGORITHM_H_

// Revision History
//    Rev 1 - Coding of edge detection algorithm in C++

#include <math.h>
#include <stdlib.h>
// Include constant kernel definition
#include "edge_defs.h"
#include <iostream>

// Template parameters allow configuring the maximum image size
template <int maxImageWidth, int maxImageHeight>
class EdgeDetect_Algorithm
{
  // Define some "constants" for use in algorithm
  //enum {
  //  imageWidth  = 1296,
  //  imageHeight =  864
  //};

public:
  // Constructor
  EdgeDetect_Algorithm() {}

  //--------------------------------------------------------------------------
  // Function: run
  //   Top interface for data in/out of class. Combines vertical and 
  //   horizontal derivative and magnitude/angle computation.
  void run(unsigned char *pix_in,  // image data (streamed in by pixel)
           unsigned int   imageWidth,
           unsigned int   imageHeight,
           bool           sw_in,
           unsigned int  &crc32_pix_in,
           unsigned int  &crc32_magn,
           double        *magn)  // magnitude output
  {
    // allocate buffers for image data
    double *dy = (double *)malloc(maxImageHeight*maxImageWidth*sizeof(double));
    double *dx = (double *)malloc(maxImageHeight*maxImageWidth*sizeof(double));

    verticalDerivative(pix_in, imageWidth, imageHeight, dy);
    horizontalDerivative(pix_in, imageWidth, imageHeight, dx);
    magnitudeAngle(dx, dy, pix_in, imageWidth, imageHeight, sw_in, crc32_pix_in, crc32_magn, magn);

    free(dy);
    free(dx);
  }

  //--------------------------------------------------------------------------
  // Function: verticalDerivative
  //   Compute the vertical derivative on the input data
  void verticalDerivative(unsigned char *pix_in,
           unsigned int   imageWidth,
           unsigned int   imageHeight,
                          double *dy) 
  {
    for (unsigned int y = 0; y < imageHeight; y++) {
      for (unsigned int x = 0; x < imageWidth; x++) {
        // Calculate derivative
        *(dy + y * imageWidth + x) =
          pix_in[clip(y - 1, imageHeight-1) * imageWidth + x] * kernel[0] +
          pix_in[y * imageWidth + x]                          * kernel[1] +
          pix_in[clip(y + 1, imageHeight-1) * imageWidth + x] * kernel[2];
      }
    }
  }

  //--------------------------------------------------------------------------
  // Function: horizontalDerivative
  //   Compute the horizontal derivative on the input data
  void horizontalDerivative(unsigned char *pix_in, 
           unsigned int   imageWidth,
           unsigned int   imageHeight,
                          double *dx) 
  {
    for (unsigned int y = 0; y < imageHeight; y++) {
      for (unsigned int x = 0; x < imageWidth; x++) {
        // Calculate derivative
        *(dx + y * imageWidth + x) =
          pix_in[y * imageWidth + clip(x - 1, imageWidth-1)] * kernel[0] +
          pix_in[y * imageWidth + x]                         * kernel[1] +
          pix_in[y * imageWidth + clip(x + 1, imageWidth-1)] * kernel[2];
        // if (x == imageWidth - 1 && y == 0)
        //   std::cout << *(dx + y * imageWidth + x) << std::endl;
        // if (x == 0 && y == 0)
        //   std::cout << *(dx + y * imageWidth + x) << std::endl;
      }
    }
  }

  //--------------------------------------------------------------------------
  // Function: magnitudeAngle
  //   Compute the magnitute and angle based on the horizontal and vertical
  //   derivative results
  void magnitudeAngle(double *dx, 
                      double *dy, 
                      unsigned char *pix_in,
                      unsigned int imageWidth,
                      unsigned int imageHeight,
                      bool sw_in,
                      unsigned int &crc32_pix_in,
                      unsigned int &crc32_magn,
                      double *magn)
  {
    double dx_sq;
    double dy_sq;
    double sum;
    for (unsigned int y = 0; y < imageHeight; y++) {
      for (unsigned int x = 0; x < imageWidth; x++) {
        dx_sq = *(dx + y * imageWidth + x) * *(dx + y * imageWidth + x);
        dy_sq = *(dy + y * imageWidth + x) * *(dy + y * imageWidth + x);
        sum = dx_sq + dy_sq;
        if (sw_in==0)
          *(magn + y * imageWidth + x) = pix_in[y * imageWidth + x];
        else
          *(magn + y * imageWidth + x) = sqrt(sum);
      }
    }
   
    //crc32 for pix_in
    crc32_pix_in = 0XFFFFFFFF;
    for (unsigned int y = 0; y < imageHeight; y++) 
      for (unsigned int x = 0; x < imageWidth; x+=4)
      {
         unsigned int pix4 = (pix_in[y * imageWidth + x + 0] <<  0) |
                             (pix_in[y * imageWidth + x + 1] <<  8) |
                             (pix_in[y * imageWidth + x + 2] << 16) |
                             (pix_in[y * imageWidth + x + 3] << 24) ;

         crc32_pix_in = calc_crc32<32>(crc32_pix_in, pix4);
      }

    crc32_pix_in = ~crc32_pix_in;    
    
    //crc32 for magn
    crc32_magn = 0XFFFFFFFF;
    for (unsigned int y = 0; y < imageHeight; y++) 
      for (unsigned int x = 0; x < imageWidth; x+=4)
      {
         unsigned int magn4 = ((unsigned int) magn[y * imageWidth + x + 0] <<  0) |
                              ((unsigned int) magn[y * imageWidth + x + 1] <<  8) |
                              ((unsigned int) magn[y * imageWidth + x + 2] << 16) |
                              ((unsigned int) magn[y * imageWidth + x + 3] << 24) ;
         
         crc32_magn = calc_crc32<32>(crc32_magn, magn4);
      }

    crc32_magn = ~crc32_magn;    
  }

private: // Helper functionsi
  template <int len>
  unsigned int calc_crc32(unsigned int crc_in, unsigned int dat_in)
  {
    unsigned int crc_out = crc_in;
    unsigned int dat = dat_in;

    for(int i=0; i<len; i++)
    {
      if ((crc_out^dat)&1)
      {
        crc_out = (crc_out >> 1);
        crc_out = (crc_out ^ CRC_POLY);
        crc_out = (crc_out | 0x80000000);
      }
      else
      {
        crc_out = (crc_out >> 1);
        crc_out = (crc_out & 0x7FFFFFFF);
      }
      dat = dat >> 1;
    }
    return crc_out;
  }

  //--------------------------------------------------------------------------
  // Function: clip
  //   Perform boundary processing by "adjusting" the index value to "clip"
  //   at either end
  int clip(int i, int bound) {
    if (i < 0) {
      return 0;               // clip to the top/left value
    } else if (i >= bound) {
      return bound;           // clip to the bottom/right value
    } else {
      return i;               // return all others untouched
    }
  }

};

#endif

