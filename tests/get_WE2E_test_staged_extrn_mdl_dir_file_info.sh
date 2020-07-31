#
#-----------------------------------------------------------------------
#
# This file defines a function that
#
#-----------------------------------------------------------------------
#
function get_WE2E_test_staged_extrn_mdl_dir_file_info() {
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
  local scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
  local scrfunc_fn=$( basename "${scrfunc_fp}" )
  local scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Get the name of this function.
#
#-----------------------------------------------------------------------
#
  local func_name="${FUNCNAME[0]}"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  Then
# process the arguments provided to this script/function (which should
# consist of a set of name-value pairs of the form arg1="value1", etc).
#
#-----------------------------------------------------------------------
#
  local valid_args=( \
"machine" \
"extrn_mdl_name_ics" \
"extrn_mdl_name_lbcs" \
"lbc_spec_intvl_hrs" \
"fcst_len_hrs" \
"output_varname_extrn_mdl_source_dir_ics" \
"output_varname_extrn_mdl_files_ics" \
"output_varname_extrn_mdl_source_dir_lbcs" \
"output_varname_extrn_mdl_files_lbcs" \
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
# Declare local variables.
#
#-----------------------------------------------------------------------
#
  local extrn_mdl_files_basedir \
        extrn_mdl_source_dir_ics \
        extrn_mdl_source_dir_lbcs \
        extrn_mdl_files_ics \
        rem \
        lbc_spec_times_hrs \
        extrn_mdl_files_lbcs \
        prefix \
        suffix
#
#-----------------------------------------------------------------------
#
# 
#
#-----------------------------------------------------------------------
#
  extrn_mdl_files_basedir=""
  case "$machine" in
  "hera")
    extrn_mdl_files_basedir="/scratch2/BMC/det/Gerard.Ketefian/UFS_CAM/staged_extrn_mdl_files"
    ;;
  "cheyenne")
    extrn_mdl_files_basedir="/glade/p/ral/jntp/UFS_CAM/staged_extrn_mdl_files"
    ;;
  esac

  extrn_mdl_source_dir_ics="${extrn_mdl_files_basedir}/${extrn_mdl_name_ics}"
  extrn_mdl_source_dir_lbcs="${extrn_mdl_files_basedir}/${extrn_mdl_name_lbcs}"
#
#-----------------------------------------------------------------------
#
# 
#
#-----------------------------------------------------------------------
#
  extrn_mdl_files_ics=( "" )
  case ${extrn_mdl_name_ics} in
  "FV3GFS" | "GSMGFS")
    extrn_mdl_files_ics=( "gfs.atmanl.nemsio" "gfs.sfcanl.nemsio" )
    ;;
  "RAPX")
    extrn_mdl_files_ics=( "rapx.out.for_f000" )
    ;;
  "HRRRX")
    extrn_mdl_files_ics=( "hrrrx.out.for_f000" )
    ;;
  esac
#
# Make sure that the forecast length is evenly divisible by the interval
# between the times at which the lateral boundary conditions will be 
# specified.
#
  rem=$(( 10#${fcst_len_hrs} % 10#${lbc_spec_intvl_hrs} ))
  if [ "$rem" -ne "0" ]; then
    print_err_msg_exit "\
The forecast length (FCST_LEN_HRS) must be evenly divisible by the lateral
boundary conditions specification interval (LBC_SPEC_INTVL_HRS):
  FCST_LEN_HRS = ${FCST_LEN_HRS}
  LBC_SPEC_INTVL_HRS = ${LBC_SPEC_INTVL_HRS}
  rem = FCST_LEN_HRS%%LBC_SPEC_INTVL_HRS = $rem"
  fi
  lbc_spec_times_hrs=( $( seq "${lbc_spec_intvl_hrs}" "${lbc_spec_intvl_hrs}" "${fcst_len_hrs}" ) )
  extrn_mdl_files_lbcs=( $( printf "%03d " "${lbc_spec_times_hrs[@]}" ) )

  case ${extrn_mdl_name_lbcs} in
  "FV3GFS" | "GSMGFS")
    prefix="gfs.atmf"
    suffix=".nemsio"
    extrn_mdl_files_lbcs=( "${extrn_mdl_files_lbcs[@]/#/$prefix}" )
    extrn_mdl_files_lbcs=( "${extrn_mdl_files_lbcs[@]/%/$suffix}" )
    ;;
  "RAPX")
    prefix="rapx.out.for_f"
    extrn_mdl_files_lbcs=( "${extrn_mdl_files_lbcs[@]/#/$prefix}" )
    ;;
  "HRRRX")
    prefix="hrrrx.out.for_f"
    extrn_mdl_files_lbcs=( "${extrn_mdl_files_lbcs[@]/#/$prefix}" )
    ;;
  *)
    extrn_mdl_files_lbcs=( "" )
  esac
#
#-----------------------------------------------------------------------
#
# Set output variables.
#
#-----------------------------------------------------------------------
#
  eval ${output_varname_extrn_mdl_source_dir_ics}=${extrn_mdl_source_dir_ics}
  eval ${output_varname_extrn_mdl_files_ics}="("$( printf '\"%s\" ' "${extrn_mdl_files_ics[@]}" )")"
  eval ${output_varname_extrn_mdl_source_dir_lbcs}=${extrn_mdl_source_dir_lbcs}
  eval ${output_varname_extrn_mdl_files_lbcs}="("$( printf '\"%s\" ' "${extrn_mdl_files_lbcs[@]}" )")"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
  { restore_shell_opts; } > /dev/null 2>&1

}

