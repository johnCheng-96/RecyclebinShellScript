#!/bin/bash

# check if the argument passing is valid
function filenameValidation() {

  # Error: No filename provided
  if [[ -z ${filename} ]]; then

    # display error message to user and write error message to stderr
    echo "restore: missing operand" >&2

    # exit code 2 for any invalid argument error
    exit 1

  # Error: File does not exist
  elif [[ -z "${matchingLine}" ]]; then

    # display error message to user and write error message to stderr
    echo "restore: cannot restore '${filename}': No such file or directory" >&2

    # exit code 2 for any invalid argument error
    exit 2

  fi
}

# create a variable path for file restoration
function fetchPath() {

  # get everything after the colon in a line of .store.info
  path=$(echo ${matchingLine} | cut -d':' -f2)
}

# check if a file with same name exist in the original location
function checkSameFilename() {
  fetchPath

  # if a file exist in the path, ask user to confirm overwrite
  if [[ -e ${path} ]]; then
    queryUser
  fi

}

# ask user to confirm when overwrite occurred
function queryUser() {

  # set to false first before asking user in case program went wrong and accidentally delete something
  confirmWrite=false;

  # query
  read -p "Do you want to overwrite? y/n " userConfirm

  # as long as user's input starts with y or Y, it is considered as a yes
  local patternMatch=$(echo ${userConfirm} | grep '^[y,Y]')
  if [[ -n ${patternMatch} ]]; then
    confirmWrite=true;
  else
    confirmWrite=false;
  fi

}

# main function of restoring process
function restoreFile() {

  # create directories for restoring recycled files to the original location
  createDir

  # if there was never a query or user confirmed the overwrite, restore file and delete log on .restore.info
  if ${confirmWrite}; then
    mv ~/recyclebin/${filename} "${path}"
    removeLineInRestoreFile
  else
    exit 3

  fi

}

# remove log of restored file from .store.info
function removeLineInRestoreFile() {

  # get the name of file while it was stored in the recyclebin
  local recycledName=$(echo ${matchingLine} | cut -d':' -f1)

  # remove the corresponding line by matching the name during "recycling"
  sed -i "/${recycledName}/d" ~/.restore.info
}

# loop to create path for restoring files
function createDir() {

  # get an absolute path without the filename on it
  newPath=$(echo ${HOME}${path#${HOME}} | rev | cut --complement -d'/' -f1 | rev)

  # hide error since it is safe that it does not overwrite anything
  mkdir -p ${newPath} 2> /dev/null
}

# fetch the matching line from .restore.info
function fetchMatchingLine() {

  # need to check if filename is empty here other wise the program will be stuck
  if [[ ! -z ${filename} ]]; then
    matchingLine=$(grep -w ${filename} ~/.restore.info)
  fi

}

########## M A I N ##########

#Major restore procedure here

# assign argument value to variable filename
filename="$1"

# this is on by default to ensure the program always run unless there is query
confirmWrite=true
fetchMatchingLine
filenameValidation
checkSameFilename
restoreFile



