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
"expt_basedir" \
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
if [ -z "${expts_file}" ]; then
  print_err_msg_exit "\
An experiments list file (expts_file), a machine name (machine), and an
account name (account) must be specified as input arguments to this 
script.  One or more of these is currently set to an empty string:
  expts_file = \"${expts_file}\"
Use the following format to specify these in the argument list passed to
this script:
  ${scrfunc_fn}  \\
    expts_file=\"name_of_file_or_full_path_to_file\" \\
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
#
#
#-----------------------------------------------------------------------
#
expt_names=( $( printf "%s\n" "${expts_list[@]}" | sed -r -e "s/^([^${field_separator}]*).*/\1/" ) )

log_fn="log.launch_FV3SAR_wflow"
max_width_col1=0
max_width_col2=0

num_expts="${#expt_names[@]}"
for (( i=0; i<=$((num_expts-1)); i++ )); do
  test_name="${expt_names[$i]}"
  expt_fp="${expt_basedir}/${test_name}"
  cd_vrfy "${expt_fp}"
#
# The following command gets the status of the workflow for the current
# experiment.  Since a "Workflow status: ..." string is printed to the 
# log file of the workflow launch script every time the workflow is 
# relaunched, we need to obtain the last occurrence of it in the log file.  
# For this purpose, it is easier to first use the "tac" command to reverse 
# the order of the lines in the log file and then pipe the result through 
# a "sed" command that extracts the status of the workflow from only the 
# first occurrence of the "Workflow status: ..." string.  This is what we
# do below.
#
# Note that the syntax of the "sed" command below is only for the gnu 
# implementations of sed.  Thus, if we can't assume that all users have
# this implementation, we may have to switch to using "awk" instead.
#
  test_status[$i]=$( tac "${log_fn}" | sed -n -r -e '0,/^[ ]*Workflow status:[ ]*(.*)/ s//\1/p' )

  len=${#test_name}
  if [ $len -gt ${max_width_col1} ]; then
    max_width_col1=${len}
  fi

  len=${#test_status[$i]}
  if [ $len -gt ${max_width_col2} ]; then
    max_width_col2=${len}
  fi

done
#
#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
#
title_col1="Test Name"
len=${#title_col1}
if [ $len -gt ${max_width_col1} ]; then
  max_width_col1=${len}
fi
max_width_col1=$(( max_width_col1+4 ))

title_col2="Status"
len=${#title_col2}
if [ $len -gt ${max_width_col2} ]; then
  max_width_col2=${len}
fi

j=0
results_table[$j]=$( printf "%-${max_width_col1}s%-${max_width_col2}s" "${title_col1}" "${title_col2}" )
row_width=${#results_table[$j]}
j=$((j+1))
results_table[$j]=$( printf "=%.0s" $(seq 1 ${row_width}) )

num_header_rows=${#results_table[@]}
for (( i=0; i<=$((num_expts-1)); i++ )); do
  j=$((i+num_header_rows))
  test_name="${expt_names[$i]}"
  results_table[$j]=$( printf "%-${max_width_col1}s%-${max_width_col2}s" "${test_name}" "${test_status[$i]}" )
#echo "${results_table[$j]}"
done

echo
printf "%s \n" "${results_table[@]}"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

