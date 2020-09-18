#!/bin/bash -l

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
# The current script should be located in the "tests" subdirectory of 
# the workflow directory, which we denote by homerrfs.  Thus, the work-
# flow directory (homerrfs) is the one above the directory of the cur-
# rent script.  Set HOMRErrfs accordingly.
#
#-----------------------------------------------------------------------
#
homerrfs=${scrfunc_dir%/*}
#
#-----------------------------------------------------------------------
#
# Set directories.
#
#-----------------------------------------------------------------------
#
ushdir="$homerrfs/ush"
baseline_configs_dir="$homerrfs/tests/baseline_configs"
#
#-----------------------------------------------------------------------
#
# Source bash utility functions.
#
#-----------------------------------------------------------------------
#
. $ushdir/source_util_funcs.sh


. ./get_WE2E_test_staged_extrn_mdl_dir_file_info.sh
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
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( \
"expts_file" \
"machine" \
"account" \
"expt_basedir" \
"use_cron_to_relaunch" \
"cron_relaunch_intvl_mnts" \
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
# Check arguments.
#
#-----------------------------------------------------------------------
#
if [ 1 = 0 ]; then
  if [ "$#" -ne 1 ]; then

    print_err_msg_exit "
Incorrect number of arguments specified:

  Number of arguments specified:  $#

Usage:

  ${scrfunc_fn}  expts_file

where expts_file is the name of the file containing the list of experi-
ments to run.  If expts_file is the absolute path to a file, it is used
as is.  If it is a relative path (including just a file name), it is as-
sumed to be given relative to the path from which this script is called.
"

  fi
fi
#
#-----------------------------------------------------------------------
#
# Verify that an experiments list file has been specified.  If not, 
# print out an error message and exit.
#
#-----------------------------------------------------------------------
#
# Note: 
# The function process_args() should be modified to look for required
# arguments, which can be denoted by appending to the name of a required
# argument the string "; REQUIRED".  It can then check that all required
# arguments are in fact specified in the arguments list.  That way, the
# following if-statement will not be needed since process_args() will 
# catch the case of missing required arguments.
# 
if [ -z "${expts_file}" ] || \
   [ -z "${machine}" ] || \
   [ -z "${account}" ]; then
  print_err_msg_exit "\
An experiments list file (expts_file), a machine name (machine), and an
account name (account) must be specified as input arguments to this 
script.  One or more of these is currently set to an empty string:
  expts_file = \"${expts_file}\"
  machine = \"${machine}\"
  account = \"${account}\"
Use the following format to specify these in the argument list passed to
this script:
  ${scrfunc_fn}  \\
    expts_file=\"name_of_file_or_full_path_to_file\" \\
    machine=\"name_of_machine_to_run_on\" \\
    account=\"name_of_hpc_account_to_use\" \\
    ..."
fi
#
#-----------------------------------------------------------------------
#
# Get the full path to the experiments list file and verify that it exists.
#
#-----------------------------------------------------------------------
#
expts_list_fp=$( readlink -f "${expts_file}" )

if [ ! -f "${expts_list_fp}" ]; then
  print_err_msg_exit "\
The experiments list file (expts_file) specified as an argument to this
script (and with full path given by expts_list_fp) does not exist:
  expts_file = \"${expts_file}\"
  expts_list_fp = \"${expts_list_fp}\""
fi
#
#-----------------------------------------------------------------------
#
# Read in the list of experiments (which might be baselines) to run.
# This entails reading in each line of the file expts_list.txt in the 
# directory of this script and saving the result in the array variable 
# expts_list.  Note that each line of expts_list.txt has the form
#
#   BASELINE_NAME  |  VAR_NAME_1="VAR_VALUE_1"  |  ... |  VAR_NAME_N="VAR_VALUE_N"
#
# where BASELINE_NAME is the name of the baseline and the zero or more
# variable name-value pairs following the baseline name are a list of 
# variables to modify from the baseline.  Note that:
#
# 1) There must exist a experiment/workflow configuration file named
#    config.BASELINE_NAME.sh in a subdirectory named baseline_configs 
#    in the directory of this script.
#
# 2) The variable name-value pairs on each line of the expts_list.txt 
#    file are delimited from the baseline and from each other by pipe 
#    characters (i.e. "|").  
#
#-----------------------------------------------------------------------
#
print_info_msg "
Reading in list of forecast experiments from file
  expts_list_fp = \"${expts_list_fp}\"
and storing result in the array \"all_lines\" (one array element per expe-
riment)..."

readarray -t all_lines < "${expts_list_fp}"

all_lines_str=$( printf "\'%s\'\n" "${all_lines[@]}" )
print_info_msg "
All lines from experiments list file (expts_list_fp) read in, where:
  expts_list_fp = \"${expts_list_fp}\"
Contents of file are (line by line, each line within single quotes, and 
before any processing):

${all_lines_str}
"
#
#-----------------------------------------------------------------------
#
# Loop through the elements of all_lines and modify each line to remove
# leading and trailing whitespace and any whitespace before and after the
# field separator character (which is the pipe character, "|").  Also, 
# drop any elements that are empty after this processing, and save the 
# resulting set of non-empty elements in the array expts_list.
#
#-----------------------------------------------------------------------
#
expts_list=()
field_separator="\|"  # Need backslash as an escape sequence in the sed commands below.

j=0
num_lines="${#all_lines[@]}"
for (( i=0; i<=$((num_lines-1)); i++ )); do
#
# Remove all leading and trailing whitespace from the current element of
# all_lines.
#
  all_lines[$i]=$( printf "%s" "${all_lines[$i]}" | \
                   sed -r -e "s/^[ ]*//" -e "s/[ ]*$//" )
#
# Remove spaces before and after all field separators in the current 
# element of all_lines.  Note that we use the pipe symbol, "|", as the
# field separator.
#
  all_lines[$i]=$( printf "%s" "${all_lines[$i]}" | \
                   sed -r -e "s/[ ]*${field_separator}[ ]*/${field_separator}/g" )
#
# If the last character of the current line is a field separator, remove
# it.
#
  all_lines[$i]=$( printf "%s" "${all_lines[$i]}" | \
                   sed -r -e "s/${field_separator}$//g" )
#
# If after the processing above the current element of all_lines is not
# empty, save it as the next element of expts_list.
#
  if [ ! -z "${all_lines[$i]}" ]; then
    expts_list[$j]="${all_lines[$i]}"
    j=$((j+1))
  fi

done
#
#-----------------------------------------------------------------------
#
# Get the number of experiments to run and print out an informational 
# message.
#
#-----------------------------------------------------------------------
#
num_expts="${#expts_list[@]}"
expts_list_str=$( printf "  \'%s\'\n" "${expts_list[@]}" )
print_info_msg "
After processing, the number of experiments to run (num_expts) is:
  num_expts = ${num_expts}
The list of forecast experiments to run (one experiment per line) is gi-
ven by:
${expts_list_str}
"
#
#-----------------------------------------------------------------------
#
# Loop through the elements of the array expts_list.  For each element
# (i.e. for each experiment), generate an experiment directory and cor-
# responding workflow and then launch the workflow.
#
#-----------------------------------------------------------------------
#
for (( i=0; i<=$((num_expts-1)); i++ )); do

  print_info_msg "
Processing experiment \"${expts_list[$i]}\" ..."
#
# Get the name of the baseline on which the current experiment is based.
# Then save the remainder of the current element of expts_list in the
# variable "remainder".  Note that if this variable is empty, then the
# current experiment is identical to the current baseline.  If not, then
# "remainder" contains the modifications that need to be made to the 
# current baseline to obtain the current experiment.
#
#  regex_search="^([^\|]*)(\|(.*)|)"
  regex_search="^([^${field_separator}]*)(${field_separator}(.*)|)"
  baseline_name=$( printf "%s" "${expts_list[$i]}" | \
                   sed -r -n -e "s/${regex_search}/\1/p" )
  remainder=$( printf "%s" "${expts_list[$i]}" | \
               sed -r -n -e "s/${regex_search}/\3/p" )
#
# Get the names and corresponding values of the variables that need to
# be modified in the current baseline to obtain the current experiment.
# The following while-loop steps through all the variables listed in 
# "remainder".
#
  modvar_name=()
  modvar_value=()
  num_mod_vars=0
  while [ ! -z "${remainder}" ]; do
#
# Get the next variable-value pair in remainder, and save what is left
# of remainder back into itself.
#
    next_field=$( printf "%s" "$remainder" | \
                  sed -r -e "s/${regex_search}/\1/" )
    remainder=$( printf "%s" "$remainder" | \
                 sed -r -e "s/${regex_search}/\3/" )
#
# Save the name of the variable in the variable-value pair obtained 
# above in the array modvar_name.  Then save the value in the variable-
# value pair in the array modvar_value.
#
    modvar_name[${num_mod_vars}]=$( printf "%s" "${next_field}" | \
                                    sed -r -e "s/^([^=]*)=(.*)/\1/" )
    modvar_value[${num_mod_vars}]=$( printf "%s" "${next_field}" | \
                                     sed -r -e "s/^([^=]*)=(\")?([^\"]+*)(\")?/\3/" )
#
# Increment the index that keeps track of the number of variables that 
# need to be modified in the current baseline to obtain the current ex-
# periment.
#
    num_mod_vars=$((num_mod_vars+1))

  done
#
# Generate the path to the configuration file for the current baseline.
# This will be modified to obtain the configuration file for the current 
# experiment.
#
  baseline_config_fp="${baseline_configs_dir}/config.${baseline_name}.sh"
#
# Print out an error message and exit if a configuration file for the 
# current baseline does not exist.
#
  if [ ! -f "${baseline_config_fp}" ]; then
    print_err_msg_exit "\
The experiment/workflow configuration file (baseline_config_fp) for the
specified baseline (baseline_name) does not exist:
  baseline_name = \"${baseline_name}\"
  baseline_config_fp = \"${baseline_config_fp}\"
Please correct and rerun."
  fi
#
# Generate a name for the current experiment.  We start with the name of 
# the current baseline and modify it to indicate which variables must be
# reset to obtain the current experiment.
#
  expt_name="${baseline_name}"
  for (( j=0; j<${num_mod_vars}; j++ )); do
    if [ $j -lt ${#modvar_name[@]} ]; then
      expt_name="${expt_name}__${modvar_name[$j]}.eq.${modvar_value[$j]}"
    else
      break
    fi
  done
#
# Set expt_subdir to the name of the current experiment.  Below, we will
# write this to the configuration file for the current experiment.
#
  expt_subdir="${expt_name}"
#
# The following comment needs to be updated.
# Create a configuration file for the current experiment.  We do this by
# first copying the baseline configuration file and then modifying the 
# the values of those variables within it that are different between the
# baseline and the experiment.
#
  expt_config_fp="$ushdir/config.${expt_name}.sh"
  rm_vrfy -f "${expt_config_fp}"
#
#-----------------------------------------------------------------------
#
# Source the experiment configuration file to obtain user-specified 
# workflow variables.  Some of these will be needed below.
#
#-----------------------------------------------------------------------
#
  . "${baseline_config_fp}"
#
#-----------------------------------------------------------------------
#
# Common portion of error messages that may get printed below.
#
#-----------------------------------------------------------------------
#
  msg_common="
The experiment/test name (expt_name) and the location of the workflow 
configuration file (expt_config_fp) are:
  expt_name = \"${expt_name}\"
  expt_config_fp = \"${expt_config_fp}\""
#
#-----------------------------------------------------------------------
#
# Add a section to the workflow configuration file that sets the machine,
# account to which to charge computational resources, and the name of the
# experiment subdirectory (which here is the name of the WE2E tests).
#
#-----------------------------------------------------------------------
#
  expt_basedir_setting_or_null=""
  if [ ! -z "{expt_basedir}" ]; then
    expt_basedir_setting_or_null="EXPT_BASEDIR=\"${expt_basedir}\""
  fi

  { cat << EOM >> ${expt_config_fp}
#
#-----------------------------------------------------------------------
#
# The machine on which to run, the account to which to charge computational
# resources, the base directory in which to create the experiment directory
# (if different from the default location), and the name of the experiment 
# subdirectory.
#
#-----------------------------------------------------------------------
#
MACHINE="${machine}"
ACCOUNT="${account}"
${expt_basedir_setting_or_null}
EXPT_SUBDIR="${expt_subdir}"
EOM
  } || print_err_msg_exit "\
Heredoc (cat) command to write to the workflow configuration file the 
name of the machine on which to run, the account to which to charge 
computational resources, and the name of the experiment subdirectory 
failed.
${msg_common}"
#
#-----------------------------------------------------------------------
#
# Get the settings of various machine-dependent parameters from the 
# configuration file.  If any of these are set to an empty string, reset 
# them to the machine-dependent values specified below.
#
#-----------------------------------------------------------------------
#
  case "$machine" in
#
  "hera")
    QUEUE_DEFAULT="batch"
    QUEUE_HPSS="service"
    QUEUE_FCST="batch"
    ;;
#
  "cheyenne")
    QUEUE_DEFAULT="regular"
    QUEUE_HPSS="regular"
    QUEUE_FCST="regular"
    ;;
#
  esac
#
# Add a section to the workflow configuration file that sets the names of
# the queues to which to submit the various workflow tasks.
#
  { cat << EOM >> ${expt_config_fp}
#
#-----------------------------------------------------------------------
#
# Names of queues to which to submit workflow tasks.
#
#-----------------------------------------------------------------------
#
QUEUE_DEFAULT="${QUEUE_DEFAULT}"
QUEUE_HPSS="${QUEUE_HPSS}"
QUEUE_FCST="${QUEUE_FCST}"
EOM
  } || print_err_msg_exit "\
Heredoc (cat) command to write to the workflow configuration file the 
names of the queues to which to submit the various workflow tasks failed.
${msg_common}"
#
#-----------------------------------------------------------------------
#
# If the optional arguments "use_cron_to_relaunch" and "cron_relaunch_intvl_mnts"
# to this script have been specified (i.e. not emtpy), set the workflow
# variables USE_CRON_TO_RELAUNCH and CRON_RELAUNCH_INTVL_MNTS to these 
# values.  If not, ensure that the latter two have been specified (i.e.
# set to non-empty values) in the experiment configuration file.
#
#-----------------------------------------------------------------------
#
  USE_CRON_TO_RELAUNCH=${use_cron_to_relaunch:-"TRUE"}
  CRON_RELAUNCH_INTVL_MNTS=${cron_relaunch_intvl_mnts:-"02"}

  if [ "${USE_CRON_TO_RELAUNCH}" = "TRUE" ]; then

    { cat << EOM >> ${expt_config_fp}
#
#-----------------------------------------------------------------------
#
# Whether or not to (re)launch workflow using a cron job, and, if so, the
# frequency (in minutes) with which to relaunch.
#
#-----------------------------------------------------------------------
#
USE_CRON_TO_RELAUNCH="${USE_CRON_TO_RELAUNCH}"
CRON_RELAUNCH_INTVL_MNTS="${CRON_RELAUNCH_INTVL_MNTS}"
EOM
    } || print_err_msg_exit "\
Heredoc (cat) command to write to the workflow configuration file the 
parameter that specifies whether or not to (re)launch workflow using a 
cron job, and, if so, the frequency (in minutes) with which to relaunch
failed.
${msg_common}"

  fi
#
#-----------------------------------------------------------------------
#
# Append the 
#
#-----------------------------------------------------------------------
#
  printf "\
#
#-----------------------------------------------------------------------
#
# The following section is from the base configuration file of this WE2E
# test.
#
#-----------------------------------------------------------------------
#
" >> "${expt_config_fp}"
  cat "${baseline_config_fp}" >> "${expt_config_fp}"
#
#-----------------------------------------------------------------------
#
# Customize parameters that specify whether or not to run the preprocessing
# tasks and, if not, the locations and names of preexisting grid, orography,
# and/or surface climatology files.
#
#-----------------------------------------------------------------------
#
  set_params="FALSE"

  tests_list_pregen=( \
    "regional_006" \
  )

  is_element_of "tests_list_pregen" "${expt_name}" && { \

    set_params="TRUE" ;

    case "$machine" in
#
    "hera")
      pregen_basedir="/scratch2/BMC/det/FV3SAR_pregen"
      ;;
#
    "cheyenne")
      pregen_basedir="/glade/p/ral/jntp/UFS_CAM/FV3SAR_pregen"
      ;;
#
    esac ;

    RUN_TASK_MAKE_GRID="FALSE"
    GRID_DIR="${pregen_basedir}/grid/GSD_HRRR25km"             
    RUN_TASK_MAKE_OROG="FALSE"
    OROG_DIR="${pregen_basedir}/orog/GSD_HRRR25km"             
    RUN_TASK_MAKE_SFC_CLIMO="FALSE"
    SFC_CLIMO_DIR="${pregen_basedir}/sfc_climo/GSD_HRRR25km"   

  }


#  case "${expt_name}" in
##
#  "regional_006")
#    case "$machine" in
#    "hera")
#      pregen_basedir="/scratch2/BMC/det/FV3SAR_pregen"
#      set_params="TRUE"
#      RUN_TASK_MAKE_GRID="FALSE"
#      GRID_DIR="${pregen_basedir}/grid/GSD_HRRR25km"             
#      RUN_TASK_MAKE_OROG="FALSE"
#      OROG_DIR="${pregen_basedir}/orog/GSD_HRRR25km"             
#      RUN_TASK_MAKE_SFC_CLIMO="FALSE"
#      SFC_CLIMO_DIR="${pregen_basedir}/sfc_climo/GSD_HRRR25km"   
#      ;;
#    "cheyenne")
#      set_params="TRUE"
#      RUN_TASK_MAKE_GRID="FALSE"
#      GRID_DIR="/need/to/set"
#      RUN_TASK_MAKE_OROG="FALSE"
#      OROG_DIR="/need/to/set"
#      RUN_TASK_MAKE_SFC_CLIMO="FALSE"
#      SFC_CLIMO_DIR="/need/to/set"
#      ;;
#    esac
#    ;;
##
#  esac
#
# Add a section to the workflow configuration file that sets the parameters
# that specify the locations and names of user-staged external model files.
#
  if [ "${set_params}" = "TRUE" ]; then

    { cat << EOM >> ${expt_config_fp}
#
#-----------------------------------------------------------------------
#
# Flags that specify whether or not to each of the pre-processing tasks 
# and, if not, the directory(ies) in which to look for pre-existing grid, 
# orography, and/or surface climatology files.
#
#-----------------------------------------------------------------------
#
RUN_TASK_MAKE_GRID="${RUN_TASK_MAKE_GRID}"
GRID_DIR="${GRID_DIR}"
RUN_TASK_MAKE_OROG="${RUN_TASK_MAKE_OROG}"
OROG_DIR="${OROG_DIR}"
RUN_TASK_MAKE_SFC_CLIMO="${RUN_TASK_MAKE_SFC_CLIMO}"
SFC_CLIMO_DIR="${SFC_CLIMO_DIR}"
EOM
    } || print_err_msg_exit "\
Heredoc (cat) command to write to the workflow configuration file the 
parameters that specify whether or not to run the preprocessing tasks and, 
if not, the locations and names of preexisting grid, orography, and/or 
surface climatology files failed.
${msg_common}"

  fi
#
#-----------------------------------------------------------------------
#
# Customize machine-dependent parameters for tests that are in NCO mode
# (i.e. those for which RUN_ENVIR is set to "nco").
#
#-----------------------------------------------------------------------
#
  set_params="FALSE"

  tests_list_nco_mode=( \
    "nco_conus" \
    "nco_conus_c96" \
    "nco_ensemble" \
    "regional_009" \
  )

  is_element_of "tests_list_nco_mode" "${expt_name}" && { \

    set_params="TRUE" ;

    nco_basedir="${homerrfs%/*/*}/NCO_dirs"
    STMP="${nco_basedir}/stmp" ;
    PTMP="${nco_basedir}/ptmp" ;

    case "$machine" in
#
    "hera")
      COMINgfs="/scratch1/NCEPDEV/hwrf/noscrub/hafs-input/COMGFS"
      ;;
#
    "jet")
      COMINgfs="/lfs1/HFIP/hwrf-data/hafs-input/COMGFS"
      ;;
#
    "cheyenne")
      COMINgfs="/needs/to/be/set"
      ;;
#
    esac ;

  }
#
# Add a section to the workflow configuration file that specifies the 
# parameters set above.
#
  if [ "${set_params}" = "TRUE" ]; then

    { cat << EOM >> ${expt_config_fp}
#
#-----------------------------------------------------------------------
#                                                                        
# IMPORTANT NOTE:
# In NCO mode, the user must manually (e.g. after doing the build step)  
# create the symlink "\${FIXrrfs}/fix_sar" that points to EMC's FIXsar    
# directory on the machine.  For example, on hera, the symlink's target  
# needs to be                                                            
#                                                                        
#   /scratch2/NCEPDEV/fv3-cam/emc.campara/fix_fv3cam/fix_sar             
#                                                                        
# The experiment generation script will then set FIXsar to               
#                                                                        
#   FIXsar="\${FIXrrfs}/fix_sar/\${EMC_GRID_NAME}"                         
#                                                                        
# where EMC_GRID_NAME has the value set above.                           
#
# FIXam on hera:
#   /scratch1/NCEPDEV/global/glopara/fix/fix_am
#
# FIXam on cheyenne:
#   /glade/p/ral/jntp/UFS_CAM/fix/fix_am
#
#-----------------------------------------------------------------------
#                                                                        

#
#-----------------------------------------------------------------------
#
# In order to prevent simultaneous WE2E (Workflow End-to-End) tests that
# are running in NCO mode and which run the same cycles from interfering
# with each other, for each cycle, each such test must have a distinct
# path to the following two directories:
#
# 1) The directory in which the cycle-dependent model input files, symlinks
#    to cycle-independent input files, and raw (i.e. before post-processing)
#    forecast output files for a given cycle are stored.  The path to this
#    directory is
#
#      \$STMP/tmpnwprd/\$RUN/\$cdate
#
#    where cdate is the starting year (yyyy), month (mm), day (dd) and
#    hour of the cycle in the form yyyymmddhh.
#
# 2) The directory in which the output files from the post-processor (UPP)
#    for a given cycle are stored.  The path to this directory is
#
#      \$PTMP/com/\$NET/\$envir/\$RUN.\$yyyymmdd/\$hh
#
# Here, we make the first directory listed above unique to a WE2E test
# by setting RUN to the name of the current test.  This will also make
# the second directory unique because it also conains the variable RUN
# in its full path, but if this directory -- or set of directories since
# it involves a set of cycles and forecast hours -- already exists from
# a previous run of the same test, then it is much less confusing to the
# user to first move or delete this set of directories during the workflow
# generation step and then start the experiment (whether we move or delete
# depends on the setting of PREEXISTING_DIR_METHOD).  For this purpose,
# it is most convenient to put this set of directories under an umbrella
# directory that has the same name as the experiment.  This can be done
# by setting the variable envir to the name of the current test.  Since
# as mentiond above we will store this name in RUN, below we simply set
# envir to the same value as RUN (which is just EXPT_SUBDIR).  Then, for
# this test, the UPP output will be located in the directory
#
#   \$PTMP/com/\$NET/\$RUN/\$RUN.\$yyyymmdd/\$hh
#
#-----------------------------------------------------------------------
#
RUN="\${EXPT_SUBDIR}"
envir="\${EXPT_SUBDIR}"
#
#-----------------------------------------------------------------------
#
# Parameters needed in NCO mode to form various directories.
#
#-----------------------------------------------------------------------
#
COMINgfs="${COMINgfs}"
STMP="${STMP}"
PTMP="${PTMP}"
EOM
    } || print_err_msg_exit "\
Heredoc (cat) command to write to the workflow configuration file the 
parameters needed in NCO mode to form various directories failed.
${msg_common}"

  fi
#
#-----------------------------------------------------------------------
#
# Customize parameters that specify the locations and names of staged 
# external model files.
#
#-----------------------------------------------------------------------
#
  set_params="FALSE"

  tests_list_staged_extrn_mdl_files=( \
    "user_staged_extrn_mdl_files_FV3GFS" \
    "user_staged_extrn_mdl_files_GSMGFS" \
    "user_staged_extrn_mdl_files_RAPX" \
  )

  case "$machine" in
#
  "hera")
    is_element_of "tests_list_staged_extrn_mdl_files" "${expt_name}" && set_params="TRUE"
    ;;
#
  "cheyenne")
    set_params="TRUE"
    ;;
#
  esac
#
# Add a section to the workflow configuration file that sets the parameters
# that specify the locations and names of user-staged external model files.
#
  if [ "${set_params}" = "TRUE" ]; then

    get_WE2E_test_staged_extrn_mdl_dir_file_info \
      machine="$machine" \
      extrn_mdl_name_ics="${EXTRN_MDL_NAME_ICS}" \
      extrn_mdl_name_lbcs="${EXTRN_MDL_NAME_LBCS}" \
      lbc_spec_intvl_hrs="${LBC_SPEC_INTVL_HRS}" \
      fcst_len_hrs="${FCST_LEN_HRS}" \
      output_varname_extrn_mdl_source_dir_ics="EXTRN_MDL_SOURCE_DIR_ICS" \
      output_varname_extrn_mdl_files_ics="EXTRN_MDL_FILES_ICS" \
      output_varname_extrn_mdl_source_dir_lbcs="EXTRN_MDL_SOURCE_DIR_LBCS" \
      output_varname_extrn_mdl_files_lbcs="EXTRN_MDL_FILES_LBCS"

    { cat << EOM >> ${expt_config_fp}
#
#-----------------------------------------------------------------------
#
# Locations and names of staged external model files.
#
#-----------------------------------------------------------------------
#
EXTRN_MDL_SOURCE_DIR_ICS="${EXTRN_MDL_SOURCE_DIR_ICS}"
EXTRN_MDL_FILES_ICS=( $( printf '\"%s\" ' "${EXTRN_MDL_FILES_ICS[@]}" ))
EXTRN_MDL_SOURCE_DIR_LBCS="${EXTRN_MDL_SOURCE_DIR_LBCS}"
EXTRN_MDL_FILES_LBCS=( $( printf '\"%s\" ' "${EXTRN_MDL_FILES_LBCS[@]}" ))
EOM
    } || print_err_msg_exit "\
Heredoc (cat) command to write to the workflow configuration file the 
locations and names of user-staged external model files failed.
${msg_common}"

  fi
#
#-----------------------------------------------------------------------
#
# Set the values of those parameters in the experiment configuration file 
# that need to be adjusted from their baseline values (as specified in 
# the current line of the experiments list file) to obtain the configuration 
# file for the current experiment.
#
#-----------------------------------------------------------------------
#
  printf ""
  for (( j=0; j<${num_mod_vars}; j++ )); do
    set_bash_param "${expt_config_fp}" "${modvar_name[$j]}" "${modvar_value[$j]}"
  done
#
# Move the current experiment's configuration file into the directory in
# which the experiment generation script expects to find it, and in the 
# process rename the file to the name that the experiment generation script
# expects it to have.
#
  mv_vrfy -f "${expt_config_fp}" "$ushdir/config.sh"
#
#-----------------------------------------------------------------------
#
# Call the experiment/workflow generation script to generate an experi-
# ment directory and rocoto workflow XML for the current experiment.
#
#-----------------------------------------------------------------------
#
  $ushdir/generate_FV3SAR_wflow.sh || \
    print_err_msg_exit "\
Could not generate an experiment/workflow for the test specified by 
expt_name:
  expt_name = \"${expt_name}\""

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

