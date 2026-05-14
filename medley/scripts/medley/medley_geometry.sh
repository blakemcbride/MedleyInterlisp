#!only-to-be-sourced
# shellcheck shell=sh
# shellcheck disable=SC2154,SC2269
###############################################################################
#
#    medley_geometry.sh - script for computing the geometry and screensize
#                         parameters for a medley session
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2023-01-17 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################

if [ "${noscroll}" = false ];
then
  scroll=22
else
  scroll=0
fi
if [ -n "${geometry}" ] && [ -n "${screensize}" ]
then
  gw=$(expr "${geometry}" : "\([0-9]*\)x[0-9]*$")
  gh=$(expr "${geometry}" : "[0-9]*x\([0-9]*\)$")
  if [ -z "${gw}" ] || [ -z "${gh}" ]
  then
    err_msg="Error: Improperly formed -geometry or -dimension argument: ${geometry}"
    usage "${err_msg}"
  fi
  geometry="${geometry}"
  #
  sw=$(expr "${screensize}" : "\([0-9]*\)x[0-9]*$")
  sh=$(expr "${screensize}" : "[0-9]*x\([0-9]*\)$")
  if [ -z "${sw}" ] || [ -z "${sh}" ]
  then
    err_msg="Error: Improperly formed -screensize argument: ${screensize}"
    usage "${err_msg}"
  fi
  screensize="${screensize}"
elif [ -n "${geometry}" ]
then
  gw=$(expr "${geometry}" : "\([0-9]*\)x[0-9]*$")
  gh=$(expr "${geometry}" : "[0-9]*x\([0-9]*\)$")
  if [ -n "${gw}" ] && [ -n "${gh}" ]
  then
    sw=$(( (((31+gw)/32)*32)-scroll ))
    sh=$(( gh - scroll ))
    geometry="${gw}x${gh}"
    screensize="${sw}x${sh}"
  else
    err_msg="Error: Improperly formed -geometry or -dimension argument: ${geometry}"
    usage "${err_msg}"
  fi
elif [ -n "${screensize}" ]
then
  sw=$(expr "${screensize}" : "\([0-9]*\)x[0-9]*$")
  sh=$(expr "${screensize}" : "[0-9]*x\([0-9]*\)$")
  if [ -n "${sw}" ] && [ -n "${sh}" ]
  then
    sw=$(( (31+sw)/32*32 ))
    gw=$(( scroll+sw ))
    gh=$(( scroll+sh ))
    geometry="${gw}x${gh}"
    screensize="${sw}x${sh}"
  else
    err_msg="Error: Improperly formed -screensize argument: ${screensize}"
    usage "${err_msg}"
  fi
else
  # Default Lisp screen size.  Must match the loadup geometry in
  # medley/scripts/loadups/loadup-setup.sh so sdl_displaywidth (the
  # per-row bitmap stride) agrees between sysout-save and runtime;
  # otherwise C reads the bitmap at a different stride than Lisp
  # writes it and window-move operations show vertical-stripe
  # corruption.
  #
  # The product (1408*1488 = 2,094,304 pixels) sits just below the
  # architectural cap of 2,097,152 pixels imposed by the Lispworld
  # memory layout (DISPLAY region between DISPLAY_OFFSET and
  # IFPAGE_OFFSET in maiko/inc/lispmap.h is 0x40000 bytes).  Pushing
  # past it requires regenerating starter.sysout with a relocated
  # IFPAGE -- substantial engineering project, not in scope.
  screensize="1408x1488"
  if [ "${noscroll}" = false ];
  then
    geometry="1430x1510"
  else
    geometry="1408x1488"
  fi
fi
