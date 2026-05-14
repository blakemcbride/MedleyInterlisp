#!to_be_sourced_only
# shellcheck shell=sh

MEDLEYDIR=$(cd "${LOADUP_SCRIPTDIR}/../.." || exit; pwd)
export MEDLEYDIR

# Workaround for Medley's UTF-8 detection in sources/UNICODE-FORMATS:
# SYSTEM-EXTERNALFORMAT does (STRPOS ".UTF-8" (UNIX-GETENV X)) on LC_CTYPE / LC_ALL / LANG
# and falls back to :THROUGH (no MCCS<->UTF-8 translation) if no match.
# Modern Linux distros set LANG to "*.utf8" (lowercase, no hyphen) which doesn't match.
# Without the right format, MTOSYSSTRING passes MCCS arrow chars (where Interlisp's reader
# stores `_`) through as raw 0xAC bytes, so e.g. UNIX-GETENV LOADUP_WORKDIR ends up
# asking the OS for "LOADUP\xACWORKDIR" and gets NIL, breaking MAKESYS.
# Normalize the LANG/LC_* values so Medley's regex matches.
case "${LC_ALL}${LC_CTYPE}${LANG}" in
  *.UTF-8*) ;; # already in matching form
  *.utf8*|*.UTF8*|*.utf-8*)
    if [ -n "${LC_ALL}" ];   then export LC_ALL=$(echo   "${LC_ALL}"   | sed 's/\.[uU][tT][fF]-\?8/.UTF-8/'); fi
    if [ -n "${LC_CTYPE}" ]; then export LC_CTYPE=$(echo "${LC_CTYPE}" | sed 's/\.[uU][tT][fF]-\?8/.UTF-8/'); fi
    if [ -n "${LANG}" ];     then export LANG=$(echo     "${LANG}"     | sed 's/\.[uU][tT][fF]-\?8/.UTF-8/'); fi
    ;;
esac

export LOADUP_CPV="${MEDLEYDIR}/scripts/cpv"

if [ -z "${LOADUP_SOURCEDIR}" ]
then
  LOADUP_SOURCEDIR="${MEDLEYDIR}/internal/loadups"
  export LOADUP_SOURCEDIR
fi

git_commit_info () {
  if [ -f "$(command -v git)" ] && [ -x "$(command -v git)" ]
  then
    if git -C "$1" rev-parse >/dev/null 2>/dev/null
    then
      # This does NOT indicate if there are any modified files!
      COMMIT_ID="$(git -C "$1" rev-parse --short HEAD)"
      BRANCH="$(git -C "$1" rev-parse --abbrev-ref HEAD)"
    fi
  fi
}

git_commit_info "${LOADUP_SOURCEDIR}"
export LOADUP_COMMIT_ID="${COMMIT_ID}"
export LOADUP_BRANCH="${BRANCH}"

if [ "${use_tag}" = "-" ]
then
  use_tag="${LOADUP_BRANCH}"
fi

slash_tag=""
if [ -n "${use_tag}" ]
then
  use_tag="$(printf %s "${use_tag}" | sed "s/[^a-zA-Z0-9_.-]/_/g")"
  slash_tag="/tagged/${use_tag}"
  # update dir structure for to use tag nomenclature rather than branch nomenclature
  # but keep compatibilty with branch nomenclature for now
  if [ -d "${MEDLEYDIR}/loadups/branches" ] && [ ! -h "${MEDLEYDIR}/loadups/branches" ]
  then
     mv "${MEDLEYDIR}/loadups/branches" "${MEDLEYDIR}/loadups/tagged"
     ln -s "${MEDLEYDIR}/loadups/tagged" "${MEDLEYDIR}/loadups/branches"
  fi
fi


if [ -z "${LOADUP_OUTDIR}" ]
then
    export LOADUP_OUTDIR="${MEDLEYDIR}/loadups${slash_tag}"
fi

if [ ! -d "${LOADUP_OUTDIR}" ]
then
  if [ ! -e "${LOADUP_OUTDIR}" ]
  then
    mkdir -p "${LOADUP_OUTDIR}"
  else
    echo "Error: ${LOADUP_OUTDIR} exists but is not a directory. Exiting."
    exit 1
  fi
fi

if [ -z "${LOADUP_WORKDIR}" ]
then
  LOADUP_WORKDIR="${LOADUP_OUTDIR}/build"
  export LOADUP_WORKDIR
fi

if [ ! -d "${LOADUP_WORKDIR}" ];
then
  if [ ! -e "${LOADUP_WORKDIR}" ];
  then
    mkdir -p "${LOADUP_WORKDIR}"
  else
    echo "Error: ${LOADUP_WORKDIR} exists but is not a directory. Exiting."
    exit 1
  fi
fi

if [ -z "${LOADUP_LOGINDIR}" ]
then
  LOADUP_LOGINDIR="${LOADUP_WORKDIR}/logindir"
  export LOADUP_LOGINDIR
fi

if [ ! -d "${LOADUP_LOGINDIR}" ];
then
  if [ ! -e "${LOADUP_LOGINDIR}" ];
  then
    mkdir -p "${LOADUP_LOGINDIR}"
  else
    echo "Error: ${LOADUP_LOGINDIR} exists but is not a directory. Exiting."
    exit 1
  fi
fi

# Loadup geometry.  Must match medley_geometry.sh's default screensize
# (computed for -sc, the only geometry flag SDL Maiko actually parses),
# otherwise:
#   - sdl_displaywidth at sysout-save (= Lisp's per-row bitmap stride)
#     differs from runtime, producing vertical-stripe corruption when
#     internal windows are moved.
#   - Lisp's saved SCREENWIDTH/SCREENHEIGHT cap where internal windows
#     can be dragged, leaving any larger outer SDL window with an
#     unreachable area.
#
# Maximum bitmap pixel count is capped at 65536*16*2 = 2,097,152 pixels
# (display_max in main.c / xinit.c / sdl.c / ldsout.c).  The cap is
# tied to the bitmap pages mmaped by the starter.sysout bootstrap;
# raising it without rebuilding starter.sysout segfaults (memory beyond
# the mapped range is unbacked).
#
# 1408x1488 = 2,094,304 pixels (< 2M cap, width is a multiple of 32 as
# required by init_SDL's alignment).  Trade-off vs the original
# 1024x768: smaller width than the medley.command default 1462, but
# nearly 2x the height -- which matters more on tall i3 tiles.  Must
# match the screensize default in
# medley/scripts/medley/medley_geometry.sh.
geometry=1408x1488

touch "${LOADUP_WORKDIR}"/loadup.timestamp

script_name=$(basename "$0" ".sh")
script_name_for_id=$(echo "${script_name}" | sed -e "s/-/_/g")
cmfile="${LOADUP_WORKDIR}/${script_name}.cm"
initfile="${LOADUP_WORKDIR}/${script_name}.init"


# Select whether we use NLSETQ or ERSETQ to wrap the loadup
# cm files depending on whether we want to allow breaks or not.
# shellcheck disable=SC2034
if [ -n "${LOADUP_NOBREAK}" ]
then
  HELPFLAG=NIL
  NL_ER_SETQ=IL:NLSETQ
else
  HELPFLAG="(QUOTE IL:BREAK!)"
  NL_ER_SETQ=IL:ERSETQ
fi

######################################################################

loadup_start () {
  touch "${LOADUP_WORKDIR}"/timestamp
  sleep 1
  echo ">>>>> START ${script_name}"
}

loadup_finish () {

  if [ ! "${cmfile}" = "-" ]; then rm -f "${cmfile}"; fi
  if [ ! "${initfile}" = "-" ]; then rm -f "${initfile}"; fi

  if [ "${exit_code}" -ne 0 ] || [ ! -f "${LOADUP_WORKDIR}/$1" ] \
     || [ ! "$( find "${LOADUP_WORKDIR}/$1" -newer "${LOADUP_WORKDIR}"/timestamp )" ]
  then
    output_error_msg "----- FAILURE ${script_name}-----"
    exit_code=1
  else
    echo "+++++ SUCCESS +++++"
    exit_code=0
  fi
  echo "..... files created ....."
  if [ -f "${LOADUP_WORKDIR}/$1" ]
  then
    shift;
    for f in "$@"
    do
      # shellcheck disable=SC2045,SC2086
      for ff in $(ls -1 "${LOADUP_WORKDIR}"/$f);
      do
        # shellcheck disable=SC2010
        if [ "$( find "${ff}" -newer "${LOADUP_WORKDIR}"/timestamp )" ]
        then
          ls -l "${ff}" 2>/dev/null | grep -v "^.*~[0-9]\+~$"
        fi
      done
    done
  fi
  echo "<<<<< END ${script_name}"
  echo ""

  exit ${exit_code}
}

run_medley () {
    # Use the lde dispatcher; it picks ldesdl by default (SDL3) and
    # falls back to ldex when only X11 is built or the user passes
    # -display X11.  Override with LOADUP_MAIKOPROG to force a
    # specific binary (e.g. ldesdl, ldex, ldeinit).
    : "${LOADUP_MAIKOPROG:=lde}"
    /bin/sh "${MEDLEYDIR}/scripts/medley/medley.command"         \
             --config -                                          \
             --id "${script_name_for_id}_+"                       \
             --geometry "${geometry}"                            \
             --noscroll                                          \
             --logindir "${LOADUP_LOGINDIR}"                     \
             --rem.cm "${cmfile}"                                \
             --greet "${initfile}"                               \
             --sysout "$1"                                       \
             --maikoprog "${LOADUP_MAIKOPROG}"                   \
             --vnc "${LOADUP_USE_VNC}"                           \
             --automation                                        \
             "$2" "$3" "$4" "$5" "$6" "$7"                       ;
    exit_code=$?
}

is_tput="$(command -v tput)"
if [ -z "${is_tput}" ]
then
  is_tput="$(command -v true)"
fi


EOL="
"

output_error_msg() {
  local_oem_file="${TMPDIR:-/tmp}"/oem_$$
  echo "$1" >"${local_oem_file}"
  while read -r line
  do
      echo "$(${is_tput} setab 1)$(${is_tput} setaf 7)${line}$(${is_tput} sgr0)"
  done <"${local_oem_file}"
  rm -f "${local_oem_file}"
}

output_warn_msg() {
  local_oem_file="${TMPDIR:-/tmp}"/oem_$$
  echo "$1" >"${local_oem_file}"
  while read -r line
  do
      echo "$(${is_tput} setab 3)$(${is_tput} setaf 4)${line}$(${is_tput} sgr0)"
  done <"${local_oem_file}"
  rm -f "${local_oem_file}"
}

exit_if_failure() {
  if [ "$1" -ne 0 ]
  then
    if [ ! "$2" = "true" ]
    then
      output_error_msg  "----- ${script_name}: FAILURE -----${EOL}"
    fi
    remove_run_lock
    exit 1
  fi
}

process_maikodir() {
        # process --maikodir argument.  Only use when --maikodir is only possible argument
        while [ "$#" -ne 0 ];
      	do
          case "$1" in
            -d | -maikodir | --maikodir)
              if [ -n "$2" ]
              then
                maikodir=$(cd "$2" 2>/dev/null && pwd)
                if [ -z "${maikodir}" ] || [ ! -d "${maikodir}" ]
                then
                  output_error_msg "Error: In --maikodir (-d) command line argument, \"$2\" is not an existing directory.${EOL}Exiting"
                  exit 1
                fi
              else
                output_error_msg "Error: Missing value for the --maikodir (-d) command line argument.${EOL}Exiting"
                exit 1
              fi
              export MAIKODIR="${maikodir}"
              shift
              ;;
            *)
              output_error_msg "Error: unknown flag: $1${EOL}Exiting"
              exit 1
              ;;
          esac
          shift
	done
}

export LOADUP_LOCKFILE="${LOADUP_WORKDIR}"/lock
LOADUP_LOCK=""
override_lock=false
ignore_lock=false

check_run_lock() {
  if [ "${ignore_lock}" = false ]
  then
    if [ -e "${LOADUP_LOCKFILE}" ]
    then
      output_warn_msg "Warning: Another loadup is already running with PID $(cat "${LOADUP_LOCKFILE}")"
      if [ "${override_lock}" = true ]
      then
	output_warn_msg "Overriding lock preventing simultaneous loadups due to command line argument --override${EOL}Continuing."
      else
        loop_done=false
        while [ "${loop_done}" = "false" ]
        do
          output_warn_msg "Do you want to override the lock guarding against simultaneous loadups?"
          output_warn_msg "Answer [y, Y, n or N, default n] followed by RETURN"
          read resp
          if [ -z "${resp}" ]; then resp=n; fi
          case "${resp}" in
            n* | N* )
              output_error_msg "Ok.  Exiting"
              exit 5
              ;;
            y* | Y* )
              output_warn_msg "Ok. Overriding lock and continuing"
              loop_done=true
              ;;
            * )
              output_warn_msg "Answer not one of Y, y, N, or n.  Retry."
              ;;
          esac
        done
      fi
    fi
    echo "$$" > "${LOADUP_LOCKFILE}"
    LOADUP_LOCK="$$"
  fi
}

remove_run_lock() {
  if [ -n "${LOADUP_LOCK}" ]
  then
    rm -f "${LOADUP_LOCKFILE}"
  fi
}


######################################################################


