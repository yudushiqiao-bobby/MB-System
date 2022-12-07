#!/usr/local/bin/bash

#########################################
# Name: trniolog-plot
#
# Summary: plot trniolog log data sets
#
# Description:
# trnio-plot is a front-end for qplot
# that generates plots using trnio log data.
# trnio-plot reads trnio log files to
# produce CSV input for qplot.
#
# qplot generates gnuplot scripts and PDF files
# that use gnuplot and ghostscript APIs.
# qplot uses configuration files to define
# one or more plot images or to combine a set of
# plot images into a PDF file.
#
# NOTE:
# Requires bash >=4.x, which implements associative arrays
# Typically, bash is located in /usr/bin.
# On OSX, default (/usr/bin) bash is 3.x,
# which does not implement associative arrays.
# Macports or Brew may be used to install
# bash v4.x, which has associative arrays.
#
# File Naming Conventions:
# qp-*.conf : qplot job configuration/job definitionos
# qu-*.conf : trnio configuration/job definitions
#
# Variable Naming Conventions:
# QU_ prefix for user environment prevents naming conflicts
# QP_ prefix denotes qplot environment/variables
# QX_ prefix denotes local environment/variables
#
# Author: k headley
#
# Copyright 2019 MBARI
#
#########################################

#########################################
# Script configuration defaults
# casual users should not need to change
# anything below this section
#########################################
 description="trnio log plot utility"

#################################
# Script variable initialization
#################################
VERBOSE="N"
unset DO_LIST
unset DO_HELP
QX_PLOTSET_INDEX=-1
QX_PLOTSET_KEY=""
QX_PLOTSET_DEF=""
QX_LOG_PATH="."
QX_SESSION_ID="-"
QX_DATA_SET_ID="undefined"
QX_JOB_DIR=${QX_JOB_DIR:-"jobs"}
QX_PLOTSET_COUNT=0
declare -a QX_LOG_PATHS
declare -a QX_SESSION_IDS
declare -a QX_DATA_SET_IDS

# set QPLOT_HOME at this scripts location
# (unless set externally)
QP_PLOT_HOME_DFL="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
QP_PLOT_HOME=${QP_PLOT_HOME:-${QP_PLOT_HOME_DFL}}

# source plotset definitions
source ${QP_PLOT_HOME}/qu-plotsets-conf.sh

# source shared definitions
source ${QP_PLOT_HOME}/qp-shared.conf.sh

#################################
# Function Definitions
#################################

#################################
# name: show_help
# description: print use message
# args: none
#################################
show_help(){
	echo ""
    echo " Description: $description"
    echo
    echo " Use: `basename $0` [options]"
    echo " Options:"
    echo "  -l         : list plotset keys"
    echo "  -f file    : use plotset config file   [1,2]"
	echo "  -j dir     : job output directory"
	echo "  -i n       : generate plotset by index [1]"
    echo "  -k s       : generate plotset by key   [1]"
	echo "  -s \"p,i,d\" : generate plotset using path,id,description [1]"
    echo "  -v         : verbose output"
    echo "  -h         : print use message"
    echo ""
    echo "  [1] may be used more than once"
	echo "  [2] applies to subsequent plotsets, until changed"
    echo ""
    echo ""
}

########################################
# name: vout
# description: print verbose message to stderr
# args:
#     msg: message
########################################
vout(){
    if [ "${VERBOSE}" == "Y" ] || [ "${VERBOSE}" == "TRUE" ]
    then
        echo "$1" >&2
    fi
}

########################################
# name: imsg
# description: echos with indent
# args:
#     msg: message
#  indent: indent level
########################################
imsg(){
    OIFS=$IFS
    IFS=""
    msg_pad="                                        "
    let "msg_indent=${1}"
    shift
    all="${@}"
    printf "%s%s\n" ${msg_pad:0:${msg_indent}} ${all}
    IFS=$OIFS
}

########################################
# name: msg
# description: echos with default indent
# args:
#     msg: message
########################################
msg(){
    imsg $MSG_INDENT "${*}"
}

########################################
# name: exitError
# description: print use message to stderr
# args:
#     msg:        error message
#     returnCode: exit status to return
########################################
exitError(){
    echo >&2
    echo "`basename $0`: error - $1" >&2
    echo >&2
    exit $2
}

########################################
# name: list_keys
# description: list plot set keys
# args: none
# returnCode: none
########################################
list_keys(){
    let "i=0";
	echo ""
    echo " index key"

    while [ ${i} -lt ${#QU_PLOTSET_KEYS[*]} ]
    do
        printf "%4d   %s\n" $i ${QU_PLOTSET_KEYS[$i]}
		key=${QU_PLOTSET_KEYS[$i]}
        vout "       LOG_PATH   : ${QU_LOG_PATHS[$key]}"
        vout "       SESSION_ID : ${QU_SESSION_IDS[$key]}"
        vout "       DATA_SET_ID: ${QU_DATA_SET_IDS[$key]}"
        vout ""
        let "i=$i+1"
    done
	echo ""
}

########################################
# name: parse_key
# description: use key to add job
# args:
#      key - plot set key (indexes QU_PLOTSET_KEYS in qu-plotsets-conf)
# returnCode: none
########################################
parse_key(){
    QX_LOG_PATHS[$QX_PLOTSET_COUNT]=${QU_LOG_PATHS[$key]}
    QX_SESSION_IDS[$QX_PLOTSET_COUNT]=${QU_SESSION_IDS[$key]}
    QX_DATA_SET_IDS[$QX_PLOTSET_COUNT]=${QU_DATA_SET_IDS[$key]}
    let "QX_PLOTSET_COUNT=$QX_PLOTSET_COUNT+1"
}

########################################
# name: process_cmdline
# description: do command line processsing
# args:
#     args:       positional paramters
# returnCode: none
########################################
process_cmdline(){
    OPTIND=1
    vout "`basename $0` all args[$*]"

while getopts hf:i:j:k:ls:v Option
    do
        vout "processing $Option[$OPTARG]"
        case $Option in
            f ) if [ -f $OPTARG ]
				then
                source $OPTARG
				else
				echo "WARN - could not source plotset config $OPTARG"
				fi
            ;;
            i ) QX_PLOTSET_INDEX=$OPTARG
				if [ $QX_PLOTSET_INDEX -lt ${#QU_PLOTSET_KEYS[*]} ]
				then
				key=${QU_PLOTSET_KEYS[$QX_PLOTSET_INDEX]}
				parse_key $key
				else
				echo "WARN - invalid index [$QX_PLOTSET_INDEX] - must be < ${#QU_PLOTSET_KEYS[*]}"
				fi
            ;;
            j ) QX_JOB_DIR=$OPTARG
            ;;
			k ) key=$OPTARG
             	key_valid=""
				let "z=0"
				while [ $z -lt ${#QU_PLOTSET_KEYS[*]} ]
				do
					if [ $key == ${QU_PLOTSET_KEYS[$z]} ]
					then
						parse_key $key
						key_valid=="Y"
						break;
					fi
					let "z=$z+1"
                done
				if [ -z $key_valid ]
				then
	                echo "WARN - invalid key [$key]"
				fi
			;;
            l ) DO_LIST="Y"
            ;;
            s ) QU_PLOTSET_DEF=$OPTARG
                IFSO=$IFS
                IFS=',' read -r lp sid dsid <<< ${QU_PLOTSET_DEF}
				IFS=$IFSO
                if [ ! -z "${lp}" ] && [ ! -z "${sid}" ] && [ ! -z "${dsid}" ]
                then
                    if [ -d ${lp} ]
                    then
                        QX_LOG_PATHS[$QX_PLOTSET_COUNT]=$lp
                        QX_SESSION_IDS[$QX_PLOTSET_COUNT]=$sid
                        QX_DATA_SET_IDS[$QX_PLOTSET_COUNT]=$dsid
                        let "QX_PLOTSET_COUNT=$QX_PLOTSET_COUNT+1"
					else
						echo "WARN - directory does not exist [$lp]"
                    fi
                fi
            ;;
            v ) VERBOSE="TRUE"
            ;;
            h) DO_HELP="Y"
            ;;
            *) exit 0 # getopts outputs error message
            ;;
        esac
    done
}

########################################
# name: plot_trno
# description: generate trno-dvl plot images
# args:
#     QU_LOG_PATH    - log file directory
#     QU_SESSION_ID  - log session id (yyyymmdd-hhmmss)
#     QU_DATA_SET_ID - data set ID (description)
# returnCode: none
########################################
plot_trno(){
    #####################
    # trno metrics
    #####################

    export TRNO_LOG="${QU_LOG_PATH}/trno-${QU_SESSION_ID}.csv"
    export QU_TRNO_CSV="trno-${QU_SESSION_ID}.csv"

    TRNO_QPCONF="qp-trno.conf.sh"

    vout " TRNO_LOG       - ${TRNO_LOG}"
    vout " QU_TRNO_CSV    - ${QU_TRNO_CSV}"

    if [ -f "${TRNO_LOG}" ] && [ -f "${QP_PLOT_HOME}/${TRNO_QPCONF}" ]
    then
        vout " processing ${TRNO_LOG}"
        cp ${TRNO_LOG} ${QP_PLOT_DATA_DIR}/${QU_TRNO_CSV}
        # use qplot to generate plot set
        ${QPLOT_CMD} -f ${QP_PLOT_HOME}/${TRNO_QPCONF}
    else
    	if [ ! -f "${TRNO_LOG}" ]
        then
	  echo "WARN - TRNO_LOG log not found ${TRNO_LOG}"
        fi
    	if [ ! -f "${QP_PLOT_HOME}/${TRNO_QPCONF}" ]
        then
	  echo "ERR - TRNO_QPCONF config not found ${QP_PLOT_HOME}/${TRNO_QPCONF}"
        fi
    fi
}

########################################
# name: plot_logs
# description: generate plots for
#              on one set of mbtrnpp logs
# args:
#     QU_LOG_PATH    - log file directory
#     QU_SESSION_ID  - log session id (yyyymmdd-hhmmss)
#     QU_DATA_SET_ID - data set ID (description)
# returnCode: none
########################################
plot_logs(){
    vout " QU_LOG_PATH    - ${QU_LOG_PATH}"
    vout " QU_SESSION_ID  - ${QU_SESSION_ID}"
    vout " QU_DATA_SET_ID - ${QU_DATA_SET_ID}"

    # generate plot CSV and images...

    # plot TRN replay data
    plot_trno

    # qplot PDF combiner job configuration
    COMB_QPCONF="qp-comb.conf.sh"

    # generate combined PDF plot set with qplot
    ${QPLOT_CMD} -f ${QP_PLOT_HOME}/${COMB_QPCONF}

} # end function

########################################
# name: run_jobs
# description: run jobs in queue
# args: none
# returnCode: none
########################################

run_jobs(){
    let "i=0"
    echo ""
    while [ $i -lt $QX_PLOTSET_COUNT ]
    do
        # set parameters for this job
        QU_LOG_PATH=${QX_LOG_PATHS[$i]}
        export QU_SESSION_ID=${QX_SESSION_IDS[$i]}
		export QU_DATA_SET_ID="${QX_DATA_SET_IDS[$i]}"

		QX_JOB_N_DIR="${QX_JOB_DIR}/job-${i}-$$"
		vout "running job : [$i]"
		vout "     output : [${QX_JOB_N_DIR}]"
		# generate plot data and plots
        plot_logs
        vout ""
        if [ ! -d "${QX_JOB_N_DIR}" ]
        then
            mkdir -p ${QX_JOB_N_DIR}
        fi

        if [ -d ${QX_JOB_N_DIR} ] && [ -d ${QP_OUTPUT_DIR} ]  && [ -d ${QP_PLOT_DATA_DIR} ]
        then
            mv ${QP_OUTPUT_DIR}/*png ${QX_JOB_N_DIR}
            mv ${QP_OUTPUT_DIR}/*pdf ${QX_JOB_N_DIR}
            mv ${QP_PLOT_DATA_DIR}/*csv ${QX_JOB_N_DIR}
            mv ${QP_OUTPUT_DIR}/*gp ${QX_JOB_N_DIR} &> /dev/null
            echo "QU_LOG_PATH    - $QU_LOG_PATH" > ${QX_JOB_N_DIR}/README
            echo "QU_SESSION_ID  - $QU_SESSION_ID" >> ${QX_JOB_N_DIR}/README
            echo "QU_DATA_SET_ID - $QU_DATA_SET_ID" >> ${QX_JOB_N_DIR}/README
        else
            echo "WARN - could not create directory [${QX_JOB_N_DIR}]"
        fi
        let "i=$i+1"
    done
}

##########################
# Script main entry point
##########################

# process command line options
if [ -t 0 ]
then
    if [ "$#" -eq 0 ];then
        show_help
        exit -1
    else
        # this ensures that quoted whitespace is preserved by getopts
        # note use of $@, in quotes

        # originally was process_cmdline $*
        process_cmdline "$@"
        let "i=$OPTIND-1"
        while [ "${i}" -gt 0  ]
        do
            shift
            let "i-=1"
        done
    fi
fi

# show plotset definitions
if [ ! -z $DO_LIST ]
then
	list_keys
fi

# show help and exit
if [ ! -z $DO_HELP ]
then
	show_help
	exit 0
fi

# create plot data directory if it doesn't exist
if [ ! -d "${QP_PLOT_DATA_DIR}" ]
then
	vout "creating plot data dir : ${QP_PLOT_DATA_DIR}"
    mkdir -p ${QP_PLOT_DATA_DIR}
    if [ ! -d "${QP_PLOT_DATA_DIR}" ]
    then
    echo "could not create plot data dir : ${QP_PLOT_DATA_DIR}"
    exit -1
    fi
fi
# create plot output directory if it doesn't exist
if [ ! -d "${QP_OUTPUT_DIR}" ]
then
	vout "creating plot data dir : ${QP_PLOT_DATA_DIR}"
	mkdir -p ${QP_OUTPUT_DIR}
fi
# create plot job output directory if it doesn't exist
if [ ! -d "${QX_JOB_DIR}" ]
then
	vout "creating job dir : ${QP_PLOT_DATA_DIR}"
	mkdir -p ${QX_JOB_DIR}
    if [ ! -d "${QX_JOB_DIR}" ]
    then
    echo "could not create job dir : ${QX_JOB_DIR}"
    exit -1
    fi
fi

# process jobs
run_jobs

vout ""

exit 0
