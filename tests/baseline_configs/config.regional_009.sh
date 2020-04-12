#
# MACHINE will be set by the workflow launch script (launch_FV3SAR_-
# wflow.sh) to value passed in as an argument to that script.
#
MACHINE=""
#
# ACCOUNT will be set by the workflow launch script (launch_FV3SAR_-
# wflow.sh) to value passed in as an argument to that script.
#
ACCOUNT=""
#
# EXPT_SUBDIR will be set by the workflow launch script (launch_FV3SAR_-
# wflow.sh) to a value obtained from the name of this file.
#
EXPT_SUBDIR=""
#
# USE_CRON_TO_RELAUNCH may be reset by the workflow launch script
# (launch_FV3SAR_wflow.sh) to value passed in as an argument to that
# script, but in case it is not, we give it a default value here.
#
USE_CRON_TO_RELAUNCH="TRUE"
#
# CRON_RELAUNCH_INTVL_MNTS may be reset by the workflow launch script
# (launch_FV3SAR_wflow.sh) to value passed in as an argument to that
# script, but in case it is not, we give it a default value here.
#
CRON_RELAUNCH_INTVL_MNTS="02"


QUEUE_DEFAULT="batch"
QUEUE_HPSS="service"
QUEUE_FCST="batch"

VERBOSE="TRUE"

RUN_ENVIR="nco"
PREEXISTING_DIR_METHOD="rename"

EMC_GRID_NAME="conus_c96"  # For now (20200130), this is maps to PREDEF_GRID_NAME="EMC_CONUS_coarse".
GRID_GEN_METHOD="GFDLgrid"

QUILTING="TRUE"
USE_CCPP="TRUE"
CCPP_PHYS_SUITE="FV3_GFS_2017_gfdlmp"
FCST_LEN_HRS="06"
LBC_UPDATE_INTVL_HRS="6"

DATE_FIRST_CYCL="20190901"
DATE_LAST_CYCL="20190901"
CYCL_HRS=( "18" )

EXTRN_MDL_NAME_ICS="FV3GFS"
EXTRN_MDL_NAME_LBCS="FV3GFS"

#
# In NCO mode, the following don't need to be explicitly set to "FALSE" 
# in this configuration file because the experiment generation script
# will do this (along with printing out an informational message).
#
#RUN_TASK_MAKE_GRID="FALSE"
#RUN_TASK_MAKE_OROG="FALSE"
#RUN_TASK_MAKE_SFC_CLIMO="FALSE"

#
# Note:
#
# * RUN is a variable containing a descriptive string for the experiment
#   that is used in forming the variable COMOUT.  COMOUT contains the 
#   full path to the directory in which output files genrated by the post
#   processor will be placed.
# * COMINgfs is the full path to the directory containing files from the 
#   external model (FV3GFS).
# * STMP is the full path to the directory that mostly contains input 
#   files.
# * PTMP is the full path to the directory in which the experiment's 
#   output files will be placed.
#
RUN="an_experiment"
if [ "${MACHINE^^}" = "HERA" ]; then
  COMINgfs="/scratch1/NCEPDEV/hwrf/noscrub/hafs-input/COMGFS"
  STMP="/scratch2/BMC/det/Gerard.Ketefian/UFS_CAM/NCO_dirs/stmp"
  PTMP="/scratch2/BMC/det/Gerard.Ketefian/UFS_CAM/NCO_dirs/ptmp"
elif [ "${MACHINE^^}" = "JET" ]; then
  COMINgfs="/lfs1/projects/hwrf-data/hafs-input/COMGFS"
  STMP="/lfs3/BMC/wrfruc/beck/NCO_dirs/stmp"
  PTMP="/lfs3/BMC/wrfruc/beck/NCO_dirs/ptmp"
else
  COMINgfs="/not/specified/for/this/machine"
  STMP="/not/specified/for/this/machine"
  PTMP="/not/specified/for/this/machine"
fi

#
# In NCO mode, the user must manually (e.g. after doing the build step)
# create the symlink "${FIXrrfs}/fix_sar" that points to EMC's FIXsar 
# directory on the machine.  For example, on hera, the symlink's target
# needs to be
#
#   /scratch2/NCEPDEV/fv3-cam/emc.campara/fix_fv3cam/fix_sar
#
# The experiment generation script will then set FIXsar to 
#
#   FIXsar="${FIXrrfs}/fix_sar/${EMC_GRID_NAME}"
#
# where EMC_GRID_NAME has the value set above.
#

