#
# TEST PURPOSE/DESCRIPTION:
# ------------------------
#
# This test is to ensure that the workflow running in community mode 
# completes successfully on the RRFS_CONUS_25km grid using the GSD_SAR
# physics suite with ICs and LBCs derived from the HRRR.
#

RUN_ENVIR="community"
PREEXISTING_DIR_METHOD="rename"

PREDEF_GRID_NAME="RRFS_CONUS_25km"
QUILTING="TRUE"

CCPP_PHYS_SUITE="FV3_GSD_SAR"
FCST_LEN_HRS="24"
LBC_SPEC_INTVL_HRS="3"

DATE_FIRST_CYCL="20200810"
DATE_LAST_CYCL="20200810"
CYCL_HRS=( "00" )

EXTRN_MDL_NAME_ICS="HRRR"
EXTRN_MDL_NAME_LBCS="HRRR"
USE_USER_STAGED_EXTRN_FILES="TRUE"