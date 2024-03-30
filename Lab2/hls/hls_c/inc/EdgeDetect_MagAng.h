/**************************************************************************
 *                                                                        *
 *  Edge Detect Design Walkthrough for HLS                                *
 *                                                                        *
 *  Software Version: 1.0                                                 *
 *                                                                        *
 *  Release Date    : Tue Jan 14 15:40:43 PST 2020                        *
 *  Release Type    : Production Release                                  *
 *  Release Build   : 1.0.0                                               *
 *                                                                        *
 *  Copyright 2020, Siemens                                               *
 *                                                                        *
 **************************************************************************
 *  Licensed under the Apache License, Version 2.0 (the "License");       *
 *  you may not use this file except in compliance with the License.      *
 *  You may obtain a copy of the License at                               *
 *                                                                        *
 *      http://www.apache.org/licenses/LICENSE-2.0                        *
 *                                                                        *
 *  Unless required by applicable law or agreed to in writing, software   *
 *  distributed under the License is distributed on an "AS IS" BASIS,     *
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or       *
 *  implied.                                                              *
 *  See the License for the specific language governing permissions and   *
 *  limitations under the License.                                        *
 **************************************************************************
 *                                                                        *
 *  The most recent version of this package is available at github.       *
 *                                                                        *
 *************************************************************************/
#pragma once

#include "EdgeDetect_defs.h"
#include <mc_scverify.h>
#include <ac_math.h>

namespace EdgeDetect_IP
{
  class EdgeDetect_MagAng
  {
  public:
    EdgeDetect_MagAng() {}

    #pragma hls_design interface
    void CCS_BLOCK(run)(ac_channel<gradType4x> &dx_in,
                        ac_channel<gradType4x> &dy_in,
                        ac_channel<Stream_t> &dat_in,
                        maxWType &widthIn,
                        maxHType &heightIn,
                        bool &sw_in,
                        uint32 &crc32_hw_pix_in,
                        uint32 &crc32_hw_dat_out,
                        ac_channel<Stream_t> &dat_out)
    {
      gradType4x dx, dy;
      pixelType4x sum; // fixed point integer for sqrt
      Stream_t stream4;
      crc32_hw_pix_in = 0XFFFFFFFF;
      crc32_hw_dat_out = 0XFFFFFFFF;

      MROW:
      for (maxHType y = 0;; y++)
      {
        #pragma hls_pipeline_init_interval 1
        MCOL:
        for (maxWType x = 0;; x += 4)
        {
          stream4 = dat_in.read();

          dx = dx_in.read();
          dy = dy_in.read();

          #pragma hls_unroll yes
          PARALLEL:
          for (int i = 0; i < 4; i++)
          {
            if (dx.pix[i] > dy.pix[i])
            {
              sum.set_slc(i * 8, ac_int<8, false>(dx.pix[i] - dy.pix[i]));
            }
            else
            {
              sum.set_slc(i * 8, ac_int<8, false>(dy.pix[i] - dx.pix[i]));
            }
          }

          calc_crc32<32>(crc32_hw_pix_in, stream4.pix);

          if (sw_in)
            stream4.pix = sum;

          calc_crc32<32>(crc32_hw_dat_out, stream4.pix);

          dat_out.write(stream4);

          // programmable width exit condition
          // cast to maxWType for RTL code coverage
          if (x == maxWType(widthIn - 4))
          { 
            break;
          }
        }
        // programmable height exit condition
        // cast to maxHType for RTL code coverage
        if (y == maxHType(heightIn - 1))
        { 
          break;
        }
      }
      crc32_hw_pix_in = ~crc32_hw_pix_in;
      crc32_hw_dat_out = ~crc32_hw_dat_out;
    }

  private:
    template <int len>
    void calc_crc32(uint32& crc_in, ac_int<len, false> dat_in)
    {
      const uint32 CRC_POLY = 0xEDB88320;
      uint32 crc_tmp = crc_in;

      #pragma hls_unroll yes
      for (int i = 0; i < len; i++)
      {
        uint1 tmp_bit = crc_in[0] ^ dat_in[i];

        uint31 mask;

        #pragma hls_unroll yes
        for (int i = 0; i < 31; i++)
        {
          mask[i] = tmp_bit & CRC_POLY[i];
        }

        uint31 crc_tmp_h31 = crc_in.slc<31>(1);

        crc_tmp_h31 ^= mask;

        crc_in.set_slc(31, tmp_bit);
        crc_in.set_slc(0, crc_tmp_h31);
      }
      // return crc_tmp;
    }
  };

}
