
#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3


#**************************************************************
# Create Clock
#**************************************************************

set n64_vclk_per 20.000
set n64_vclk_pos_width [expr $n64_vclk_per*3/5]
set n64_vclk_waveform [list 0.000 $n64_vclk_pos_width]

create_clock -name {VCLK_N64_VIRT} -period $n64_vclk_per -waveform $n64_vclk_waveform
create_clock -name {VCLK} -period $n64_vclk_per -waveform $n64_vclk_waveform [get_ports {VCLK}]


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {CLK_4M} -source [get_ports {VCLK}] -divide_by 12 [get_registers {hk_u|CLK_4M}]
create_generated_clock -name {CLK_ADV712x} -source [get_ports {VCLK}] -divide_by 1 -multiply_by 1 [get_ports {CLK_ADV712x}]


#**************************************************************
# Set Input Delay
#**************************************************************

set data_delay_min 2.0
set data_delay_max 8.0
set data_delay_margin 0.2
set input_delay_min [expr $data_delay_min - $data_delay_margin]
set input_delay_max [expr $data_delay_max + $data_delay_margin]

set_input_delay -clock {VCLK_N64_VIRT} -min $input_delay_min [get_ports {nDSYNC D_i[*]}]
set_input_delay -clock {VCLK_N64_VIRT} -max $input_delay_max [get_ports {nDSYNC D_i[*]}]


#**************************************************************
# Set Output Delay
#**************************************************************

set adv_tsu 0.5
set adv_th  1.5
set adv_margin 0.2
set out_dly_max [expr $adv_tsu + $adv_margin]
set out_dly_min [expr -$adv_th - $adv_margin]

set_output_delay -clock {CLK_ADV712x} -max $out_dly_max [get_ports {R_o* G_o* B_o* nCSYNC_ADV712x nBLANK_ADV712x}]
set_output_delay -clock {CLK_ADV712x} -min $out_dly_min [get_ports {R_o* G_o* B_o* nCSYNC_ADV712x nBLANK_ADV712x}]

#set_output_delay -clock {VCLK} 0 [get_ports {nHSYNC nVSYNC nCSYNC nCLAMP}]


#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group \
                            {VCLK_N64_VIRT VCLK CLK_ADV712x} \
                            {CLK_4M}


#**************************************************************
# Set False Path
#**************************************************************

set_false_path -from [get_ports {nRST_io CTRL_i nSYNC_ON_GREEN n16bit_mode_t nVIDeBlur_t en_IGR_Rst_Func en_IGR_DeBl_16b_Func}]
set_false_path -to [get_ports {nRST_io}]

set_false_path -to [get_ports {nHSYNC nVSYNC nCSYNC nCLAMP}]
