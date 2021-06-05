#!/bin/bash

# function of getting options which consist of 3 options, -i interactive, -v verbose and -r recursive
function optFunc() {
  interactiveFlag=false
  verboseFlag=false
  recursiveFlag=false

  # turn on flags if options are received
  while getopts :ivr opt
  do
    case ${opt} in
      i) interactiveFlag=true ;;
      v) verboseFlag=true ;;
      r) recursiveFlag=true ;;

      # display error message to user and write error message to stderr
      *) echo "recycle: invalid option -- '$OPTARG'" >&2

        # exit code 1 for any invalid option error
        exit 1 ;;
    esac
  done
}

# create recyclebin at home directory
function createRecyclebin() {
  mkdir ~/recyclebin 2> /dev/null
}

# function that makes sure arguments are valid, exit program if invalid argument is passed
function filenameValidation() {

  # this flag is for recursive recycle use, true if the current argument is a directory
  isDirectoryFlag=false

  #	Error: No filename provided
  if [[ -z ${filename} ]]; then

    # display error message to user and write error message to stderr
    echo "recycle: missing operand" >&2

    # exit code 2 for any invalid argument error
    exit 2

  # Error: File or directory does not exist
  elif [[ ! -e ${filename} ]]; then

    # display error message to user and write error message to stderr
    echo "recycle: cannot recycle '${filename}': No such file or directory" >&2

    # exit code 2 for any invalid argument error
    exit 2

  #	Error: If -r option is not provided and directory name provided
  elif [[ -d ${filename} ]]; then
    isDirectoryFlag=true

    # if no -r option passed
    if ! ${recursiveFlag}; then

      # display error message to user and write error message to stderr
      echo "recycle: cannot recycle '${filename}': Is a directory" >&2

      # exit code 2 for any invalid argument error
      exit 2
    fi

  # Error: If the recycle script is passed
  elif [ ${filename} == "recycle" ]; then

    # display error message to user and write error message to stderr
    echo "recycle: Attempting to delete recycle – operation aborted" >&2

    # exit code 2 for any invalid argument error
    exit 2
  fi

}

# rename file which will be recycled
function renameFile() {

  # absolute path including filename
  path=$(readlink -f ${filename})

  # a single inode number
  local inodeNum=$(ls -i ${filename} | cut -d' ' -f1)

  # make sure name does not contain any path, remove any path before the name
  pureName=$(echo ${filename} | rev | cut -d'/' -f1 | rev)

  # the filenames in the recyclebin, will be in the following format: fileName_inode
  mv ${filename} "${pureName}_${inodeNum}"
  recycledFilename="${pureName}_${inodeNum}"
}

# move file to recyclebin
function moveToRecyclebin() {
  mv ${recycledFilename} ~/recyclebin/
}

# prepare a line of text in format: f1_1234:/home/trainee1/f1
function restoreFileFormatting() {
  restoreLine="${recycledFilename}:${path}"
}

# write to .restore.info
function updateRestoreFile() {

  # prepare the line going to write into .restore.info
  restoreFileFormatting

  echo ${restoreLine} >> ~/.restore.info
}

# query for recycle confirmation when -i interactive mode is on
function queryUser() {

  # set to false first before asking user in case program went wrong and accidentally delete something
  confirmRecycleFlag=false;

  # query in rm command style
  read -p "recycle: recycle file '${filename}'? " userConfirm

  # as long as user's input starts with y or Y, it's consider as yes
  local patternMatch=$(echo ${userConfirm} | grep '^[y,Y]')
  if [[ -n ${patternMatch} ]]; then
    confirmRecycleFlag=true;
  else
    confirmRecycleFlag=false;
  fi

}

# recursion and loop function for recursive recycle when -r is passed
function recursiveLoop() {

  # prepare options for recursion
  if ${interactiveFlag}; then
    optI="i"
  else
    optI=""
  fi

  if ${verboseFlag}; then
    optV="v"
  else
    optV=""
  fi

  if ${recursiveFlag}; then
    optR="r"
  else
    optR=""
  fi

  # loop through the current directory
  for f in $1/*; do

    # if ${f} is a directory
    if [ -d "${f}" ]; then

      # start another loop to run through files or subdirectories inside this directory
      recursiveLoop ${f}

    # if ${f} is a file
    else
      bash recycle -${optV}${optI}${optR} $f
    fi

    isEmpty=$(ls -A $1)

    # if directory is empty
    if [[ -z ${isEmpty} ]]; then

      # remove the empty directory
      rmdir ./$1
      break
    fi
    done
}

# Display message for successful recycle
function recycleMessage() {
  echo "recycled '${filename}'"
}

# make filename null if the last parameters is options, which mean user did not input filename
function checkLastParameters() {

  # this is ok to ignore the error of grep since this function is used for after the recycle process
  isOption=$(grep ${filename} '^-' 2> /dev/null)

    # if the last parameter is option
    if [[ -n ${isOption} ]]; then
      filename=""
    fi
}

# need to separate this error function due to some logical bug
function noFileNameDetection() {

  if [[ -z ${filename} ]]; then

    # display error message to user and write error message to stderr
    echo "recycle: missing operand" >&2

    # exit code 2 for any invalid argument error
    exit 2
  fi
}

# create a flag to identify if a folder is empty
function isEmptyDirectory() {
  emptyDirectoryFlag=false
  
  if [[ -z "$(ls -A ./${filename})" ]]; then
      emptyDirectoryFlag=true
  fi
}

# Overall procedure of recycle
function recycleFunc() {

  # if not in interactive mode, just make it always true to ensure the program runs
  confirmRecycleFlag=true

  # argument will have different position if option is passed
  if ${interactiveFlag} || ${verboseFlag} || ${recursiveFlag}; then
    noFileNameDetection
    argPos=$((${OPTIND} - 1))
  else
    argPos=${OPTIND}
  fi

  # while loop to go through each argument
  while [ ${argPos} -le $# ]
  do

    # fetch new argument
    filename="$1"

    # just make sure .resotre.info is created, it won't overwrited the content if it existed
    touch ~/.restore.info

    filenameValidation

    # option i function
    if ${interactiveFlag}; then

      # ask to confirm the recycle
      queryUser
    fi

    # user confirmed to recycle
    if ${confirmRecycleFlag}; then

      # -r recursive function when current argument is a directory
      if ${recursiveFlag} && ${isDirectoryFlag}; then

        # check if current "filename" is a empty folder
        isEmptyDirectory

        # if true, just remove the folder
        if ${emptyDirectoryFlag}; then
          rmdir ./$1
          shift 1
          continue
        fi

        # start recursive loop through directory and subdirectories
        recursiveLoop ${filename}

      # if no -r option or current argument is not directory, go through normal procedure to recycle a single file
      else
        renameFile

        # Logging first for a safe approach, in case the program is interrupted, if file is moved without logging, this file cannot be restore forever
        updateRestoreFile

        moveToRecyclebin

        # option v function
        if ${verboseFlag}; then

          # show which file is recycled
          recycleMessage
        fi
      fi
    fi

    # process the next argument
    shift 1
  done

}

########## M A I N ##########

# Initiation

# take in options
optFunc $*

# move parameter position to the first argument
shift $((${OPTIND} - 1))

filename="$1"

noFileNameDetection

# make sure recyclebin folder is create at home directory before any recycle
createRecyclebin

# Main operation
recycleFunc $*




















