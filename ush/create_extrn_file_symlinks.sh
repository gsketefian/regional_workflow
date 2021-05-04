#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Source bash utility functions.
#
#-----------------------------------------------------------------------
#
. ./source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.
# Then process the arguments provided to this script/function (which
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( \
"staged_data_basedir" \
"extrn_mdl_name" \
"cdate" \
"fcst_len_hrs" \
"lbc_spec_intvl_hrs" \
"fhr_offset" \
  )
process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# For debugging purposes, print out values of arguments passed to this
# script.  Note that these will be printed out only if VERBOSE is set to
# TRUE.
#
#-----------------------------------------------------------------------
#
print_input_args valid_args
#
#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
#
valid_vals_extrn_mdl_name=( "GSMGFS" "FV3GFS" "HRRR" "HRRRX" "RAP" "RAPX" )
#
#-----------------------------------------------------------------------
#
# Make sure that extrn_mdl_name is set to a valid value.
#
#-----------------------------------------------------------------------
#
extrn_mdl_name="${extrn_mdl_name^^}"
check_var_valid_value "extrn_mdl_name" "valid_vals_extrn_mdl_name"
#
#-----------------------------------------------------------------------
#
# Make sure that the specified cdate consists of exactly 10 digits.
#
#-----------------------------------------------------------------------
#
cdate_or_null=$( printf "%s" "${cdate}" | \
                 sed -n -r -e "s/^([0-9]{10})$/\1/p" )
if [ -z "${cdate_or_null}" ]; then
  print_err_msg_exit "\
cdate must be a string consisting of exactly 10 digits of the form 
\"YYYYMMDDHH\", where YYYY is the 4-digit year, MM is the 2-digit month, 
DD is the 2-digit day-of-month, and HH is the 2-digit hour-of-day of the
starting date/time of the FV3 forecast:
  cdate = \"${cdate}\""
fi
#
#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
#
fhr_offset=${fhr_offset:-"00"}
#
#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
#
fv3_cdate="$cdate"
fv3_yyyymmdd=${fv3_cdate:0:8}
fv3_hh=${fv3_cdate:8:2}
#
#-----------------------------------------------------------------------
#
# Extract from fv3_cdate the starting year, month, day, and hour of
# the FV3-LAM cycle.  Then subtract the temporal offset specified in
# fhr_offset (assumed to be given in units of hours) from fv3_cdate
# to obtain the starting date and time of the external model, express the
# result in YYYYMMDDHH format, and save it in cdate.  This is the starting
# time of the external model forecast.
#
#-----------------------------------------------------------------------
#
extrn_mdl_cdate=$( date --utc --date "${fv3_yyyymmdd} ${fv3_hh} UTC - ${fhr_offset} hours" "+%Y%m%d%H" )
#
#-----------------------------------------------------------------------
#
# Extract from extrn_mdl_cdate the starting year, month, day, and hour of the external
# model forecast.  Also, set the starting minute to "00" and get the date
# without the time-of-day.  These are needed below in setting various
# directory and file names.
#
#-----------------------------------------------------------------------
#
extrn_mdl_yyyy=${extrn_mdl_cdate:0:4}
extrn_mdl_yy=${extrn_mdl_cdate:2:2}
extrn_mdl_mm=${extrn_mdl_cdate:4:2}
extrn_mdl_dd=${extrn_mdl_cdate:6:2}
extrn_mdl_hh=${extrn_mdl_cdate:8:2}
extrn_mdl_mn="00"
extrn_mdl_yyyymmdd=${extrn_mdl_cdate:0:8}

#
# Get the Julian day-of-year of the starting date and time of the external
# model forecast.
#
extrn_mdl_ddd=$( date --utc --date "${extrn_mdl_yyyy}-${extrn_mdl_mm}-${extrn_mdl_dd} \
                 ${extrn_mdl_hh}:${extrn_mdl_mn} UTC" "+%j" )





extrn_mdl_fhr_min=$(( fhr_offset + lbc_spec_intvl_hrs )) # The +lbc_spec_intvl_hrs is so that we start with the first LBC, not forecast hour 0.  This works for LBCs but not for ICs.
extrn_mdl_fhr_max=$(( fhr_offset + fcst_len_hrs ))
extrn_mdl_fhrs=( $( seq ${extrn_mdl_fhr_min} ${lbc_spec_intvl_hrs} ${extrn_mdl_fhr_max} ) )

extrn_mdl_cdate_dir="${staged_data_basedir}/${extrn_mdl_name}/$cdate"

extrn_mdl_fmn="00"
for fhr in "${extrn_mdl_fhrs[@]}"; do
  extrn_mdl_fhh=$( printf "%02d" "$fhr" )
  fv3_fcst_hr=$(( fhr - fhr_offset ))
  fv3_fhhh=$( printf "%03d" "${fv3_fcst_hr}" )
echo
echo "extrn_mdl_fhh = \"${extrn_mdl_fhh}\";    fv3_fhhh = \"${fv3_fhhh}\""
echo "===>>>  extrn_mdl_yy = ${extrn_mdl_yy}"
  extrn_mdl_fn="${extrn_mdl_yy}${extrn_mdl_ddd}${extrn_mdl_hh}${extrn_mdl_mn}${extrn_mdl_fhh}${extrn_mdl_fmn}"
  extrn_mdl_fp="${extrn_mdl_cdate_dir}/for_LBCS/${extrn_mdl_fn}"
# Need to modify ln_vrfy so that it gives an error and quits if the target does not exist.
  ln_vrfy -fs --relative "${extrn_mdl_fp}" "${extrn_mdl_cdate_dir}/${extrn_mdl_name,,}.out.for_f${fv3_fhhh}" 
rc=$?
echo "rc = $rc"
done
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

