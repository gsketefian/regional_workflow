MACHINE="hera"
ACCOUNT="an_account"
EXPT_SUBDIR="test_community"

QUEUE_DEFAULT="batch"
QUEUE_HPSS="service"
QUEUE_FCST="batch"

VERBOSE="TRUE"

RUN_ENVIR="community"
PREEXISTING_DIR_METHOD="rename"

PREDEF_GRID_NAME="RRFS_CONUS_25km"
GRID_GEN_METHOD="ESGgrid"
QUILTING="TRUE"
CCPP_PHYS_SUITE="FV3_GFS_2017_gfdlmp"
FCST_LEN_HRS="6"
LBC_SPEC_INTVL_HRS="6"

DATE_FIRST_CYCL="20190701"
DATE_LAST_CYCL="20190701"
CYCL_HRS=( "00" )

EXTRN_MDL_NAME_ICS="FV3GFS"
EXTRN_MDL_NAME_LBCS="FV3GFS"

RUN_TASK_MAKE_GRID="TRUE"
RUN_TASK_MAKE_OROG="TRUE"
RUN_TASK_MAKE_SFC_CLIMO="TRUE"
