#########
# Clock #
#########
create_clock  -name CLK -period 10 -waveform {0 5} [get_ports CLK]

###################
# set input delay #
###################


####################
# set output delay #
####################


##############################
# Pin Locations and Voltages #
##############################
## Clock signal
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports { CLK }];

## Reset signal (Center Button)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports { RESET }];

## Control Signals (PMOD JC)
set_property -dict { PACKAGE_PIN K17  IOSTANDARD LVCMOS33 } [get_ports { TO_READ  }];
set_property -dict { PACKAGE_PIN M18  IOSTANDARD LVCMOS33 } [get_ports { TO_WRITE }];

## ADDRESS Bus - 6 bits (PMOD JC)
set_property -dict { PACKAGE_PIN N17  IOSTANDARD LVCMOS33 } [get_ports { ADDRESS[0] }];
set_property -dict { PACKAGE_PIN P18  IOSTANDARD LVCMOS33 } [get_ports { ADDRESS[1] }];
set_property -dict { PACKAGE_PIN L17  IOSTANDARD LVCMOS33 } [get_ports { ADDRESS[2] }];
set_property -dict { PACKAGE_PIN M19  IOSTANDARD LVCMOS33 } [get_ports { ADDRESS[3] }];
set_property -dict { PACKAGE_PIN P17  IOSTANDARD LVCMOS33 } [get_ports { ADDRESS[4] }];
set_property -dict { PACKAGE_PIN R18  IOSTANDARD LVCMOS33 } [get_ports { ADDRESS[5] }];

## DATA_IN Bus - 8 bits (PMOD JA)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports { DATA_IN[0] }];
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports { DATA_IN[1] }];
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports { DATA_IN[2] }];
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports { DATA_IN[3] }];
set_property -dict { PACKAGE_PIN H1   IOSTANDARD LVCMOS33 } [get_ports { DATA_IN[4] }];
set_property -dict { PACKAGE_PIN K2   IOSTANDARD LVCMOS33 } [get_ports { DATA_IN[5] }];
set_property -dict { PACKAGE_PIN H2   IOSTANDARD LVCMOS33 } [get_ports { DATA_IN[6] }];
set_property -dict { PACKAGE_PIN G3   IOSTANDARD LVCMOS33 } [get_ports { DATA_IN[7] }];

## DATA_OUT Bus - 8 bits (PMOD JB)
set_property -dict { PACKAGE_PIN A14  IOSTANDARD LVCMOS33 } [get_ports { DATA_OUT[0] }];
set_property -dict { PACKAGE_PIN A16  IOSTANDARD LVCMOS33 } [get_ports { DATA_OUT[1] }];
set_property -dict { PACKAGE_PIN B15  IOSTANDARD LVCMOS33 } [get_ports { DATA_OUT[2] }];
set_property -dict { PACKAGE_PIN B16  IOSTANDARD LVCMOS33 } [get_ports { DATA_OUT[3] }];
set_property -dict { PACKAGE_PIN A15  IOSTANDARD LVCMOS33 } [get_ports { DATA_OUT[4] }];
set_property -dict { PACKAGE_PIN A17  IOSTANDARD LVCMOS33 } [get_ports { DATA_OUT[5] }];
set_property -dict { PACKAGE_PIN C15  IOSTANDARD LVCMOS33 } [get_ports { DATA_OUT[6] }];
set_property -dict { PACKAGE_PIN C16  IOSTANDARD LVCMOS33 } [get_ports { DATA_OUT[7] }];

##########################
# Configuration Settings #
##########################
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]