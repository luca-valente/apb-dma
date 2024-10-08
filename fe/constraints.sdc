create_clock -name pclk_1 -period 10 [get_ports pclk_c1]
create_clock -name pclk_2 -period 10 [get_ports pclk_c2]


set_clock_groups -asynchronous  -group {pclk_1}
set_clock_groups -asynchronous  -group {pclk_2}

set_false_path -hold -from [get_pins i_midend/i_w_cdc_fifo/i_src/async_*_o] -to [get_pins i_midend/i_w_cdc_fifo/i_dst/async_*_i]
set_max_delay 1 -from [get_pins i_midend/i_w_cdc_fifo/i_src/async_*_o] -to [get_pins i_midend/i_w_cdc_fifo/i_dst/async_*_i]

set_false_path -hold -from [get_pins i_midend/i_w_cdc_fifo/i_dst/async_*_o] -to [get_pins i_midend/i_w_cdc_fifo/i_src/async_*_i]
set_max_delay 1 -from [get_pins i_midend/i_w_cdc_fifo/i_dst/async_*_o] -to [get_pins i_midend/i_w_cdc_fifo/i_src/async_*_i]

set_false_path -hold -from [get_pins i_midend/i_r_cdc_fifo/i_src/async_*_o] -to [get_pins i_midend/i_r_cdc_fifo/i_dst/async_*_i]
set_max_delay 1 -from [get_pins i_midend/i_r_cdc_fifo/i_src/async_*_o] -to [get_pins i_midend/i_r_cdc_fifo/i_dst/async_*_i]

set_false_path -hold -from [get_pins i_midend/i_r_cdc_fifo/i_dst/async_*_o] -to [get_pins i_midend/i_r_cdc_fifo/i_src/async_*_i]
set_max_delay 1 -from [get_pins i_midend/i_r_cdc_fifo/i_dst/async_*_o] -to [get_pins i_midend/i_r_cdc_fifo/i_src/async_*_i]

set_false_path -hold -from [get_pins i_backend/busy_o] -to [get_pins i_frontend/i_sync/serial_i]
set_max_delay 1 -from [get_pins i_backend/busy_o] -to [get_pins i_frontend/i_sync/serial_i]

set_false_path -hold -from [get_pins i_frontend/start_o] -to [get_pins i_backend/i_sync/serial_i]
set_max_delay 1 -from [get_pins i_frontend/start_o] -to [get_pins i_backend/i_sync/serial_i]

set_false_path -hold -from [get_pins i_frontend/start_addr_o] -to [get_pins i_backend/start_addr_i]
set_max_delay 1 -from [get_pins i_frontend/start_addr_o] -to [get_pins i_backend/start_addr_i]

set_false_path -hold -from [get_pins i_frontend/num_bytes_o] -to [get_pins i_backend/num_bytes_i]
set_max_delay 1 -from [get_pins i_frontend/num_bytes_o] -to [get_pins i_backend/num_bytes_i]

set_false_path -hold -from [get_pins i_frontend/rw_o] -to [get_pins i_backend/rw_i]
set_max_delay 1 -from [get_pins i_frontend/rw_o] -to [get_pins i_backend/rw_i]
