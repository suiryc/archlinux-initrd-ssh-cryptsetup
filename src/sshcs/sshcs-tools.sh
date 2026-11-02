#!/usr/bin/ash

. /init_functions

# Set TERM if needed.
# Useful for some commands, like systemctl.
[ -z "${TERM:-}" ] && export TERM=linux

# HOME is / by default. Actual home is better, at least for interactive shells.
export HOME=/root

# Log debug message, if debug enabled.
# Also log as kmsg if enabled.
log_dbg() {
  [ ${sshcs_opt_debug} -eq 0 ] && return 0
  echo "$@"
  [ ${sshcs_opt_log_kmsg} -eq 0 ] && return 0
  echo "<31>sshcs: $@" > /dev/kmsg
}

# Log information message, even if quiet.
# Also log as kmsg if enabled.
log_msg() {
  echo "$@"
  [ ${sshcs_opt_log_kmsg} -eq 0 ] && return 0
  echo "<30>sshcs: $@" > /dev/kmsg
}

# Log error message (prefixed with "ERROR: " in console).
# Also log as kmsg if enabled.
log_err() {
  err "$@"
  [ ${sshcs_opt_log_kmsg} -eq 0 ] && return 0
  echo "<27>sshcs: $@" > /dev/kmsg
}

. /usr/local/bin/sshcs-env.sh

call_exists() {
  if type "$1" > /dev/null 2>&1; then
    "$@"
  else
    return 0
  fi
}

sshcs_net_device() {
  [ -n "${net_device:-}" ] && return 0

  # For systemd initramfs, get the 'ip' argument in kernel command line.
  if [ -z "${ip:-}" ] && [ -e /usr/bin/systemctl ]; then
    for arg in $(cat /proc/cmdline); do
      case "$arg" in
        ip=*)
          ip="${arg#ip=}"
          break
          ;;
      esac
    done
  fi

  # We must have an 'ip' setting, and a device in it.
  [ -z "${ip:-}" ] && [ -n "${nfsaddrs:-}" ] && ip="${nfsaddrs}"
  [ -z "${ip:-}" ] && {
    log_err 'No ip setting to set up network'
    return 1
  }

  net_device=$(echo "${ip}" | cut -d: -f6)
  [ -n "${net_device}" ] || {
    log_err "No network device to set up in ip=<${ip}>"
    return 1
  }
}

sshcs_net_wol_setup() {
  # Note: ethtool can access WoL settings before network is set up.
  if [ "${sshcs_opt_net_wol:-d}" != 'd' ]; then
    log_dbg "Setting network device=${net_device} wol=${sshcs_opt_net_wol}"
    ethtool -s "${net_device}" wol "${sshcs_opt_net_wol}"
  fi
}

sshcs_net_speed_reduce() {
  # Note: We cannot change the device settings, other than WoL, before the
  # device is ready.
  if [ ${sshcs_opt_net_speed} != 0 ] && ethtool "${net_device}" > /dev/null 2>&1; then
    log_dbg "Setting network device=${net_device} speed=${sshcs_opt_net_speed}"
    ethtool -s "${net_device}" speed "${sshcs_opt_net_speed}" duplex full autoneg off
  fi
}

sshcs_net_speed_restore() {
  # If we did change the network speed, time to reset it.
  # Note: "net_device" is known in console/systemd service, not in SSH session,
  # so that only the former does the network cleanup.
  if [ -n "${net_device}" ] && [ ${sshcs_opt_net_speed} != 0 ] && ethtool "${net_device}" > /dev/null 2>&1; then
    log_dbg "Restoring network device=${net_device} speed"
    ethtool -s "${net_device}" autoneg on
  fi
}

# Source non-systemd tools when applicable.
[ ! -e /usr/bin/systemctl ] && . /usr/local/bin/sshcs-tools-bb.sh
