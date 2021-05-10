#!/bin/bash

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
. ${scrfunc_dir}/source_util_funcs.sh
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
# Specify the set of valid argument names for this script/function.  Then
# process the arguments provided to this script/function (which should 
# consist of a set of name-value pairs of the form arg1="value1", etc).
#
#-----------------------------------------------------------------------
#
valid_args=( \
"staged_data_basedir" \
"extrn_mdl_name" \
"cdate" \
"ics_or_lbcs" \
"fcst_len_hrs" \
"lbc_spec_intvl_hrs" \
"fhr_offset" \
"fv3gfs_file_fmt" \
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
# Specify set of valid values for some of the input arguments.
#
#-----------------------------------------------------------------------
#
valid_vals_extrn_mdl_name=( "GSMGFS" "FV3GFS" "HRRR" "HRRRX" "RAP" "RAPX" )
valid_vals_ics_or_lbcs=( "ICS" "LBCS" )
valid_vals_fv3gfs_file_fmt=( "nemsio" "grib2" "netcdf" )
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
# Make sure that ics_or_lbcs is set to a valid value.
#
#-----------------------------------------------------------------------
#
ics_or_lbcs="${ics_or_lbcs^^}"
check_var_valid_value "ics_or_lbcs" "valid_vals_ics_or_lbcs"
#
#-----------------------------------------------------------------------
#
# Make sure that fv3gfs_file_fmt is set to a valid value.
#
#-----------------------------------------------------------------------
#
if [ "${extrn_mdl_name}" = "FV3GFS" ]; then
  fv3gfs_file_fmt="${fv3gfs_file_fmt,,}"
  check_var_valid_value "fv3gfs_file_fmt" "valid_vals_fv3gfs_file_fmt"
fi
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
# Make sure that fhr_offset consists of only digits.  If creating symlinks 
# to LBC files, do the same for fcst_len_hrs and lbc_spec_intvl_hrs.
#
#-----------------------------------------------------------------------
#
# If an offset between the beginning of the external model forecast and
# that of the FV3 forecast is not specified, set it to 0.
#
fhr_offset=${fhr_offset:-"00"}
tmp=$( printf "%s" "${fhr_offset}" | sed -n -r -e "s/^([0-9]+)$/\1/p" )
if [ -z "$tmp" ]; then
  print_err_msg_exit "\
fhr_offset must be a string consisting of one or more digits:
  fhr_offset = \"${fhr_offset}\""
fi

if [ "${ics_or_lbcs}" = "LBCS" ]; then

  tmp=$( printf "%s" "${fcst_len_hrs}" | sed -n -r -e "s/^([0-9]+)$/\1/p" )
  if [ -z "$tmp" ]; then
    print_err_msg_exit "\
fcst_len_hrs must be a string consisting of one or more digits:
  fcst_len_hrs = \"${fcst_len_hrs}\""
  fi

  tmp=$( printf "%s" "${lbc_spec_intvl_hrs}" | sed -n -r -e "s/^([0-9]+)$/\1/p" )
  if [ -z "$tmp" ]; then
    print_err_msg_exit "\
lbc_spec_intvl_hrs must be a string consisting of one or more digits:
  lbc_spec_intvl_hrs = \"${lbc_spec_intvl_hrs}\""
  fi

fi
#
#-----------------------------------------------------------------------
#
# Make sure that the specified base directory for staged data exists.
#
#-----------------------------------------------------------------------
#
if [ ! -d "${staged_data_basedir}" ]; then
  print_err_msg_exit "\
The specified base directory (staged_data_basedir) for staged external 
model data does not exist:
  staged_data_basedir = \"${staged_data_basedir}\""
fi
#
#-----------------------------------------------------------------------
#
# Set the starting cycle date for the FV3 forecast.  Then extract from 
# it the the date without the time-of-day as well as the 2-digit time-
# of-day.
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
# Extract from extrn_mdl_cdate the starting date without the time-of-day, 
# the 2-digit starting year, and the (2-digit) starting hour-of-day.  
# Also, set the starting minute to "00".  These are needed below in 
# setting various directory and file names.
#
#-----------------------------------------------------------------------
#
extrn_mdl_yyyymmdd=${extrn_mdl_cdate:0:8}
extrn_mdl_yy=${extrn_mdl_cdate:2:2}
extrn_mdl_hh=${extrn_mdl_cdate:8:2}
extrn_mdl_mn="00"
#
# If using the HRRR, HRRRX, RAP, or RAPX external model, set the Julian 
# day-of-year of the starting date and time of the external model forecast.
#
extrn_mdl_jul_ddd=""
case "${extrn_mdl_name}" in
  "HRRR" | "HRRRX" | "RAP" | "RAPX" )
    extrn_mdl_jul_ddd=$( date --utc --date "${extrn_mdl_yyyymmdd} \
                         ${extrn_mdl_hh}:${extrn_mdl_mn} UTC" "+%j" )
    ;;
esac
#
#-----------------------------------------------------------------------
#
# Set the full path to the base directory containing the external model
# data for the specified cdate and make sure that it exists.
#
#-----------------------------------------------------------------------
#
extrn_mdl_cdate_basedir="${staged_data_basedir}/${extrn_mdl_name}/$cdate"
if [ ! -d "${extrn_mdl_cdate_basedir}" ]; then
  print_err_msg_exit "\
The base directory containing the external model data for the specified
external model and date (extrn_mdl_cdate_basedir) does not exist:
  extrn_mdl_cdate_basedir = \"${extrn_mdl_cdate_basedir}\""
fi
#
#-----------------------------------------------------------------------
#
# Set the full path to the subdirectory under extrn_mdl_cdate_basedir in
# which the external model files should be located.  This depends on 
# whether the symlinks being created point to IC or LBC files.  Then make 
# sure that the subdirectory exists.
#
#-----------------------------------------------------------------------
#
extrn_mdl_files_dir="${extrn_mdl_cdate_basedir}/for_${ics_or_lbcs}"
if [ ! -d "${extrn_mdl_files_dir}" ]; then
  print_err_msg_exit "\
The directory (extrn_mdl_files_dir) that should contain the external model 
files does not exist:
  extrn_mdl_files_dir = \"${extrn_mdl_files_dir}\""
fi
#
#-----------------------------------------------------------------------
#
# Set the array containing the external model's forecast hours to loop
# over when creating symlinks.
#
#-----------------------------------------------------------------------
#
if [ "${ics_or_lbcs}" = "ICS" ]; then
  extrn_mdl_fhr_min=$(( fhr_offset ))
  extrn_mdl_fhr_max=$(( fhr_offset ))
elif [ "${ics_or_lbcs}" = "LBCS" ]; then
# When creating symlinks to LBC files, the first symlink created will 
# point to the external model file containing the first forecast hour 
# at which boundary data are needed, not the intitial time.  Thus, to 
# get extrn_mdl_fhr_min, we must add lbc_spec_intvl_hrs to fhr_offset
# (instead of just using fhr_offset).
  extrn_mdl_fhr_min=$(( fhr_offset + lbc_spec_intvl_hrs ))
  extrn_mdl_fhr_max=$(( fhr_offset + fcst_len_hrs ))
fi
extrn_mdl_fhrs=( $( seq ${extrn_mdl_fhr_min} ${lbc_spec_intvl_hrs} ${extrn_mdl_fhr_max} ) )
#
#-----------------------------------------------------------------------
#
# Loop through all the relevant forecast hours and create one or more
# symlinks for each forecast hour.  Note that the "more" case normally
# happens when considering ICs and an external model whose ICs are found
# in more than one file (e.g. for FV3GFS, the ICs are in the atmanl and
# sfcanl files).
#
#-----------------------------------------------------------------------
#
# Set the forcast minute of the external model.  Currently, this is always
# set to "00".
extrn_mdl_fmn="00"

for fhr in "${extrn_mdl_fhrs[@]}"; do

  extrn_mdl_fhh=$( printf "%02d" "$fhr" )
  extrn_mdl_fhhh=$( printf "%03d" "$fhr" )
  fv3_fcst_hr=$(( fhr - fhr_offset ))
  fv3_fhhh=$( printf "%03d" "${fv3_fcst_hr}" )
#
# Set the names of the external model files and the names of the symlinks
# that will point to those files.
#
  case "${extrn_mdl_name}" in

  "GSMGFS")
    if [ "${ics_or_lbcs}" = "ICS" ]; then
      extrn_mdl_fns=( "gfs.t${extrn_mdl_hh}z.atmanl.nemsio" "gfs.t${extrn_mdl_hh}z.sfcanl.nemsio" )
      symlink_fns=( "gfs.atmanl.nemsio" "gfs.sfcanl.nemsio" )
    elif [ "${ics_or_lbcs}" = "LBCS" ]; then
      extrn_mdl_fns=( "gfs.t${extrn_mdl_hh}z.atmf${extrn_mdl_fhhh}.nemsio" )
      symlink_fns=( "gfs.atmf${extrn_mdl_fhhh}.nemsio" )
    fi
    ;;

  "FV3GFS")
    if [ "${fv3gfs_file_fmt}" = "nemsio" ]; then
      if [ "${ics_or_lbcs}" = "ICS" ]; then
        extrn_mdl_fns=( "gfs.t${extrn_mdl_hh}z.atmanl.nemsio" "gfs.t${extrn_mdl_hh}z.sfcanl.nemsio" )
        symlink_fns=( "gfs.atmanl.nemsio" "gfs.sfcanl.nemsio" )
      elif [ "${ics_or_lbcs}" = "LBCS" ]; then
        extrn_mdl_fns=( "gfs.t${extrn_mdl_hh}z.atmf${extrn_mdl_fhhh}.nemsio" )
        symlink_fns=( "gfs.atmf${extrn_mdl_fhhh}.nemsio" )
      fi
    elif [ "${fv3gfs_file_fmt}" = "grib2" ]; then
      extrn_mdl_fns=( "gfs.t${extrn_mdl_hh}z.pgrb2.0p25.f${extrn_mdl_fhhh}" )
      symlink_fns=( "gfs.pgrb2.0p25.f${extrn_mdl_fhhh}" )
    elif [ "${fv3gfs_file_fmt}" = "netcdf" ]; then
      print_err_msg_exit "\
The name of the external model file (extrn_mdl_fns) has not yet been 
specified for this FV3GFS files having the format specified by 
fv3gfs_file_fmt:
  fv3gfs_file_fmt = \"${fv3gfs_file_fmt}\""
    fi
    ;;

  "HRRR" | "HRRRX" | "RAP" | "RAPX" )
    extrn_mdl_fns=( "${extrn_mdl_yy}${extrn_mdl_jul_ddd}${extrn_mdl_hh}${extrn_mdl_mn}${extrn_mdl_fhh}${extrn_mdl_fmn}" )
    symlink_fns=( "${extrn_mdl_name,,}.out.for_f${fv3_fhhh}" )
    ;;

  *)
    print_err_msg_exit "\
The names of the external model files (extrn_mdl_fns) have not yet been 
specified for this combination of external model and ICS or LBCS:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  ics_or_lbcs = \"${ics_or_lbcs}\""
    ;;

  esac
#
# Loop over all files for the current forecast hour.
#
  relative_or_null="--relative"
  num_files="${#extrn_mdl_fns[@]}"
  for (( i=0; i<=$((num_files-1)); i++ )); do
    target_fp="${extrn_mdl_files_dir}/${extrn_mdl_fns[i]}"
    symlink_fp="${extrn_mdl_cdate_basedir}/${symlink_fns[i]}"
# Need to modify ln_vrfy so that it gives an error and quits if the 
# target does not exist.
    if [ -f "${target_fp}" ]; then
      ln_vrfy -fs ${relative_or_null} "${target_fp}" "${symlink_fp}"
    else
      print_err_msg_exit "\
Cannot create symlink because the target of the link command (target_fp)
does not exist:
  target_fp = \"${target_fp}\""
    fi
  done

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
