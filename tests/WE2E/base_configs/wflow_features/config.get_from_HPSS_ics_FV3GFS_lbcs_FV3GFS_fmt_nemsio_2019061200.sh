#
# TEST PURPOSE/DESCRIPTION:
# ------------------------
#
# This test checks the capability of the workflow to retrieve from NOAA 
# HPSS nemsio-formatted output files generated by the FV3GFS external 
# model (from which ICs and LBCs will be derived) on the first cycle 
# date (2019061200) on which the FV3GFS officially became operational.
#

RUN_ENVIR="community"
PREEXISTING_DIR_METHOD="rename"

PREDEF_GRID_NAME="RRFS_CONUS_25km"
QUILTING="TRUE"

CCPP_PHYS_SUITE="FV3_GFS_v15p2"

FCST_LEN_HRS="06"
LBC_SPEC_INTVL_HRS="3"

DATE_FIRST_CYCL="20190612"
DATE_LAST_CYCL="20190612"
CYCL_HRS=( "00" )

EXTRN_MDL_NAME_ICS="FV3GFS"
FV3GFS_FILE_FMT_LBCS="nemsio"
EXTRN_MDL_NAME_LBCS="FV3GFS"
FV3GFS_FILE_FMT_ICS="nemsio"
