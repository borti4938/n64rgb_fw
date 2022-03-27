//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the N64 RGB/YPbPr DAC project.
//
// Copyright (C) 2016-2022 by Peter Bartmann <borti4938@gmail.com>
//
// N64 RGB/YPbPr DAC is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//////////////////////////////////////////////////////////////////////////////////
//
// Company:  Circuit-Board.de
// Engineer: borti4938
//
// Module Name:    n64_vdemux
// Project Name:   N64 RGB DAC Mod
// Target Devices: universial
// Tool versions:  Altera Quartus Prime
// Description:    demux the video data from the input data stream
//
///////////////////////////////////////////////////////////////////////////////////////////


module n64_vdemux(
  VCLK,
  nDSYNC,
  nRST,

  D_i,
  demuxparams_i,

  vdata_sy_0_o,
  vdata_1_o
);

`include "../lib/n64rgb_params.vh"

input VCLK;
input nDSYNC;
input nRST;

input  [color_width-1:0] D_i;
input  [            2:0] demuxparams_i;

output [`VDATA_SY_SLICE] vdata_sy_0_o; // buffer for sync, red, green and blue
output [`VDATA_FU_SLICE] vdata_1_o; // (unpacked array types in ports requires system verilog)


// unpack demux params

wire palmode     = demuxparams_i[  2];
wire ndo_deblur  = demuxparams_i[  1];
wire n16bit_mode = demuxparams_i[  0];


// start of rtl

wire posedge_nCSYNC = !vdata_r_0[3*color_width] & D_i[0];

reg [1:0] data_cnt = 2'b00;
reg nblank_rgb = 1'b1;
reg [`VDATA_FU_SLICE] vdata_r_0 = {vdata_width{1'b0}}; // buffer for sync, red, green and blue
reg [`VDATA_FU_SLICE] vdata_r_1 = {vdata_width{1'b0}}; // buffer for sync, red, green and blue


always @(posedge VCLK or negedge nRST)  // data register management
  if (!nRST)
    data_cnt <= 2'b00;
  else begin
    if (!nDSYNC)
      data_cnt <= 2'b01;  // reset data counter
    else
      data_cnt <= data_cnt + 1'b1;  // increment data counter
  end


always @(posedge VCLK or negedge nRST)
  if (!nRST) begin
    nblank_rgb <= 1'b1;
  end else if (!nDSYNC) begin
    if (ndo_deblur) begin
      nblank_rgb <= 1'b1;
    end else begin
      if(posedge_nCSYNC) // posedge nCSYNC -> reset blanking
        nblank_rgb <= palmode;
      else
        nblank_rgb <= ~nblank_rgb;
    end
  end
  
always @(posedge VCLK or negedge nRST)
  if (!nRST)begin // data register management
    vdata_r_0 <= {vdata_width{1'b0}};
    vdata_r_1 <= {vdata_width{1'b0}};
  end else begin
    if (!nDSYNC) begin
      // shift data to output registers
      if (ndo_deblur)
        vdata_r_1[`VDATA_SY_SLICE] <= vdata_r_0[`VDATA_SY_SLICE];
      if (nblank_rgb)  // deblur active: pass RGB only if not blanked
        vdata_r_1[`VDATA_CO_SLICE] <= vdata_r_0[`VDATA_CO_SLICE];

      // get new sync data
      vdata_r_0[`VDATA_SY_SLICE] <= D_i[3:0];
    end else begin
      // demux of RGB
      case(data_cnt)
        2'b01: vdata_r_0[`VDATA_RE_SLICE] <= n16bit_mode ? D_i : {D_i[6:2], 2'b00};
        2'b10: begin
          vdata_r_0[`VDATA_GR_SLICE] <= n16bit_mode ? D_i : {D_i[6:1], 1'b0};
          if (!ndo_deblur)
            vdata_r_1[`VDATA_SY_SLICE] <= vdata_r_0[`VDATA_SY_SLICE];
        end
        2'b11: vdata_r_0[`VDATA_BL_SLICE] <= n16bit_mode ? D_i : {D_i[6:2], 2'b00};
      endcase
    end
  end

assign vdata_sy_0_o = vdata_r_0[`VDATA_SY_SLICE];
assign vdata_1_o = vdata_r_1;

endmodule
