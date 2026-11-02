#!/usr/bin/ash

# Pure BusyBox (without systemd) tools.
# Sourced from common sshcs-tools script.

# Notes:
# Ending an interactive shell can be triggered through SIGHUP signal.
#
# A few functions are only called from the "ssh-cryptsetup" hook, and could
# live there. However, some of them have counterparts that need to be here as
# they are called from scripts either running upon SSH connection or manually
# launched from interactive shells.
# So, for consistency and maintenance, have them here too:
#  - sshcs_net_start: alongside sshcs_net_done
#  - sshcs_ssh_run: alongside sshcs_ssh_stop
#  - sshcs_cryptpart_setup + sshcs_cryptpart_process
# The only exceptions: sshcs_timeout_start and sshcs_timeout_stop, to ensure
# they are/can be only called from the hook, and no other script.

# Signals like SIGCHLD tend to disrupt 'sleep', at least the one in initramfs.
# When we kill some other process, like SSH shells, right before 'sleep' is
# called in current shell, it may receive SIGCHLD, interrupting the underlying
# pausing mechanism to process the signal: 'sleep' then ends on the spot as if
# it cleanly ended (no error code).
# Workaround: call 'sleep' outside the current shell, e.g with 'env'.
alias sleep='env sleep'

sshd_process_name='dropbear'
if [ "${sshcs_opt_ssh_daemon}" == 'openssh' ]; then
  sshd_process_name='sshd-session'
elif [ "${sshcs_opt_ssh_daemon}" == 'tinyssh' ]; then
  sshd_process_name='tinysshd'
fi

# Create file indicating poweroff is ongoing.
sshcs_poweroff_trigger() {
  touch '/.sshcs_poweroff'
}

sshcs_poweroff_triggered() {
  [ -e '/.sshcs_poweroff' ]
}

# Create file indicating a SSH connection did happen.
sshcs_ssh_shell_trigger() {
  proc_is_console || touch '/.sshcs_ssh_shell'
}

sshcs_ssh_shell_triggered() {
  [ -e '/.sshcs_ssh_shell' ]
}

proc_parse_stat() {
  local unused

  pid=$1
  cmd=
  ppid=
  [ ! -e "/proc/${pid}/stat" ] && return 1
  read unused cmd unused ppid unused < "/proc/${pid}/stat"
}

proc_find_parent_cmd() {
  local pid=$1
  proc_parse_stat ${pid} || return 1
  while [ ${ppid} -gt 1 ]; do
    proc_parse_stat ${ppid} || return 1
    if [ "${cmd}" == "($2)" ]; then
      ppid=${pid}
      pid=$1
      return 0
    fi
    pid=${ppid}
  done

  return 1
}

proc_is_console() {
  if [ -z "${is_console:-}" ]; then
    # We are in console if we were not forked from SSH.
    is_console=1
    proc_find_parent_cmd $$ "${sshd_process_name}" && is_console=0
  fi

  [ "${is_console}" -eq 1 ]
}

sshcs_cryptpart_process() {
  local cryptdev_orig cryptopt cryptargs

  # ensure there is a device (handle 'UUID=' format)
  [ -z "${cryptdev}" ] && return 0
  [ "${cryptdev#UUID=}" != "${cryptdev}" ] && cryptdev="/dev/disk/by-uuid/${cryptdev#UUID=}"

  # get crypt options
  cryptargs=
  x_initrd_attach=0
  for cryptopt in ${cryptoptions//,/ }; do
    case ${cryptopt} in
      discard)
        cryptargs="${cryptargs} --allow-discards"
        ;;

      luks)
        ;;

      x-initrd.attach)
        x_initrd_attach=1
        ;;

      *)
        log_dbg "Device ${cryptdev} encryption option '${cryptopt}' not known, ignoring."
        ;;
    esac
  done

  # Only consider entries marked with 'x-initrd.attach'.
  if [ ${x_initrd_attach} -eq 0 ]; then
    log_dbg "Device ${cryptdev} ignored: no x-initrd.attach option for boot setup"
    return 0
  fi

  # ensure device is encrypted and handled
  cryptdev_orig=${cryptdev}
  if cryptdev=$(resolve_device "${cryptdev_orig}" ${rootdelay}); then
    if cryptsetup isLuks "${cryptdev}" >/dev/null 2>&1; then
      log_dbg "Adding crypt device=${cryptdev} type=${crypttype} name=${cryptname} args=<${cryptargs}> in setup script"

      # update script used to unlock device either in console or SSH
      [ -s "${sshcs_cryptsetup_script}" ] || cat <<'EOF' > "${sshcs_cryptsetup_script}"
#!/usr/bin/ash

. /usr/local/bin/sshcs-tools.sh

# Nominal behaviour is to check each device to unlock and call cryptsetup to
# unlock it.
# We loop until device is unlocked, then check next device, until all devices
# are unlocked.
# When failing to unlock one device, for each loop the user is given the choice
# to poweroff, reboot, or keep on trying to unlock the device.

# sshcs_unlocked_test: caller sets to 1 when we only need to check whether
# devices are unlocked, in which case we set sshcs_unlocked to 0 if at least one
# device was not unlocked.

cycle_or_retry() {
  local res

  read -n 1 -s -t 5 -p "Within 5s press 'P' to poweroff, 'R' to reboot or any other key to retry. " res
  echo ''
  [ "${res}" == 'P' ] && poweroff -f
  [ "${res}" == 'R' ] && reboot -f
}

try_unlock() {
EOF

      cat <<EOF >> "${sshcs_cryptsetup_script}"
  # loop until device is available
  while ! sshcs_poweroff_triggered && [ ! -e "/dev/mapper/${cryptname}" ]; do
    if [ \${sshcs_unlocked_test:-0} -eq 1 ]; then
      sshcs_unlocked=0
      return
    fi
    if cryptsetup open --type "${crypttype}" "${cryptdev}" "${cryptname}" ${cryptargs} "\${CSQUIET}"; then
      if poll_device "/dev/mapper/${cryptname}" ${rootdelay}; then
        killall cryptsetup > /dev/null 2>&1
        break
      fi
      log_err 'Device still not mapped! Please wait or retry.'
    elif ! sshcs_poweroff_triggered && [ ! -e "/dev/mapper/${cryptname}" ]; then
      log_err 'cryptsetup failed! Please retry.'
    else
      break
    fi

    cycle_or_retry
  done
EOF
    else
      log_err "Failed to manage encrypted device ${cryptdev_orig}: not a LUKS volume."
    fi
  fi
}

sshcs_cryptpart_setup() {
  local cryptdev crypttype cryptname cryptpass cryptoptions

  # Notes:
  # The script is built piece by piece to unlock each target device.
  # If there is no device to unlock, there is no script, and boot should simply
  # go on as usual.

  # check encrypted devices to handle
  cryptdev=
  crypttype=luks
  while read cryptname cryptdev cryptpass cryptoptions; do
    # skip comment lines
    [ "${cryptname:0:1}" = '#' ] && continue
    # skip devices with given password
    [ -n "${cryptpass}" ] && [ "${cryptpass}" != 'none' ] && [ "${cryptpass}" != '-' ] && continue

    sshcs_cryptpart_process
  done < "${etc_crypttab}"

  # Nothing else to do if there is no device we can unlock
  [ -s "${sshcs_cryptsetup_script}" ] || return 0

  # There were devices to unlock.
  # We can now finish the script.
  cat <<'EOF' >> "${sshcs_cryptsetup_script}"
  # No other device to unlock
}

if [ -c /dev/mapper/control ]; then
  CSQUIET=
  try_unlock

  [ ${sshcs_unlocked_test:-0} -eq 1 ] && return
  sshcs_check_done 0
else
  if [ \${sshcs_unlocked_test:-0} -eq 1 ]; then
    sshcs_unlocked=0
    return
  fi
  echo ''
  log_err 'Device resources missing! Please retry.'
fi
EOF
  chmod a+x "${sshcs_cryptsetup_script}"
}

sshcs_net_start() {
  local iparg net_address ipconfig_out net_netmask net_gateway net_dns0 net_dns1

  ! sshcs_net_device && return 1

  sshcs_net_wol_setup

  # Setup network and save some values
  # Note: some useful redirection means ('< <(...)' and '<<< "$(...)"') are
  # not supported in the available shell. So we have to write code in a
  # temporary file and 'source' it since '... | while read ...' spawns a
  # subshell from which outer variables cannot be altered.
  : > "${net_env}"

  echo ''
  echo "Configuring IP (timeout = ${sshcs_opt_timeout_ipconfig}s) ..."
  # ipconfig manual: https://git.kernel.org/pub/scm/libs/klibc/klibc.git/tree/usr/kinit/ipconfig/README.ipconfig
  ipconfig_out=$(ipconfig -t "${sshcs_opt_timeout_ipconfig}" "ip=${ip}")
  if [ $? -ne 0 ]; then
    log_err 'IP configuration timeout!'
    echo 'Devices probing:'
    ipconfig -n -t 5 -c none all
    sshcs_net_speed_reduce
    return 1
  fi

  echo -n "${ipconfig_out}" | while read line; do
    [ "${line#"IP-Config:"}" != "${line}" ] && continue

    line=$(echo "${line}" | sed -e 's/ :/:/g;s/: /=/g')

    for iparg in ${line}; do
      case "${iparg}" in
        address=*|netmask=*|gateway=*|dns0=*|dns1=*)
          echo "net_${iparg}" >> "${net_env}"
          ;;
      esac
    done
  done

  . "${net_env}"
  rm -f "${net_env}"

  log_msg "IP-Config: device=${net_device} ip=${net_address}/${net_netmask} gw=${net_gateway} dns0=${net_dns0} dns1=${net_dns1}"

  sshcs_net_speed_reduce

  # Ensure we have an address
  [ -n "${net_address}" ] || return 1
}

sshcs_net_done() {
  # We are done with the network.
  # Note: "net_device" is known in console, not in SSH session, so that only
  # the former does the network cleanup.
  if [ -n "${net_device}" ]; then
    log_dbg "Setting network device=${net_device} down"
    ip addr flush dev "${net_device}"
    ip link set dev "${net_device}" down
  fi
}

sshcs_ssh_run() {
  local dev_pts_mounted=0
  local listen=

  # ensure /dev/pts is present
  if [ ! -d /dev/pts ]; then
    log_dbg 'Mounting /dev/pts'
    mkdir -p /dev/pts
    mount -t devpts devpts /dev/pts
    dev_pts_mounted=1
  fi

  # SSH usually uses [/var]/run/utmp, and dropbear at least complains if not present.
  [ -e /var/run/utmp ] || touch /var/run/utmp

  if [ "${sshcs_opt_ssh_daemon}" == 'openssh' ]; then
    log_dbg 'Starting sshd ...'
    # Note: sshd requires execution with an absolute path
    /usr/bin/sshd ${sshcs_opt_listen}
  elif [ "${sshcs_opt_ssh_daemon}" == 'tinyssh' ]; then
    log_dbg 'Starting tinyssh ...'
    # Note: tcpsvd hijacks stdin/stdout/stderr, which messes up cryptsetup trying
    # to read the passphrase from the terminal if at least one SSH connection does
    # happen.
    # We need to redirect all these fds to fix this issue.
    busybox tcpsvd 0 ${sshcs_opt_port} tinysshd -l /etc/tinyssh/sshkeydir </dev/null >/dev/null 2>&1 &
    echo -n "$!" > "${path_sshd_pid}"
  else
    log_dbg 'Starting dropbear ...'
    dropbear -Esgjk -P "${path_sshd_pid}" ${sshcs_opt_listen}
  fi

  # Actual unlocking shell
  sshcs_shell_main
}

sshcs_ssh_stop() {
  local pgrep_output

  # Belt and suspenders: only main script in console handles this.
  ! proc_is_console && return

  # We are in the console.
  # It is time to properly end the processes we started and files we created.
  # When using a shell - instead of directly calling the unlocking script -
  # we also need to signal any SSH shell so that it is properly cleaned too.

  # cleanup SSH daemon
  if [ -f "${path_sshd_pid}" ]; then
    log_dbg 'Stopping SSH daemon ...'
    kill $(cat "${path_sshd_pid}")
    rm -f "${path_sshd_pid}"
  fi

  if sshcs_ssh_shell_triggered; then
    # Find and kill all shells spawned by SSH.
    # This is necessary to properly terminate both these shells and the spawned
    # SSH processes.
    # Reminder: "... | ..." does fork a subshell
    log_dbg 'Searching SSH shells ...'
    pgrep_output=$(pgrep /usr/bin/ash)
    pgrep_output=$(echo "${pgrep_output}" | grep -E -v "^(|1|$$)$")
    echo "${pgrep_output}" | while read pid; do
      # Handle empty response
      [ -z "${pid}" ] && continue
      proc_parse_stat ${pid} || continue
      proc_find_parent_cmd ${pid} "${sshd_process_name}" || continue
      log_dbg "Killing SSH shell pid=${pid}"
      kill -SIGHUP ${pid}
    done
  fi
}

sshcs_poweroff_soft() {
  # Be nice and kill cryptsetup then terminate SSH processes: otherwise the
  # SSH client may remain frozen for some time.
  killall cryptsetup > /dev/null 2>&1
  sshcs_ssh_stop
  # Wait a bit, so user may have the time to see message on console.
  sleep 2
  poweroff -f
}

sshcs_shell_main() {
  local sshcs_script=${sshcs_shell_script}
  if [ ${sshcs_opt_use_shell} -eq 0 ]; then
    # The cryptsetup script *is* the shell to run.
    sshcs_script=${sshcs_cryptsetup_script}
  fi
  local sshcs_script_fail=0

  proc_is_console && sshcs_timeout_start

  # Belt and suspenders: if the script does not exist, trying to source it
  # actually triggers a kernel panic (in console).
  if [ ! -e "${sshcs_script}" ]; then
    log_err "No script to run! ${sshcs_script} does not exist!"
    sshcs_script_fail=1
  elif ! ash -n "${sshcs_script}"; then
    log_err "Syntax error in ${sshcs_script}!"
    sshcs_script_fail=1
  else
    # actual script (shared with SSH login) with which we can unlock devices
    sshcs_unlocked_test=0
    log_dbg "Running ${sshcs_script}"
    . "${sshcs_script}"
  fi

  if [ ${sshcs_script_fail} -ne 0 ]; then
    # We failed to call the script.
    if proc_is_console; then
      # Allow local user to continue boot sequence by pressing a key.
      echo -n 'Press any key to continue boot, or computer will be powered off. '
      read -n 1 -s res
      echo ''
      # Properly stop timeout and SSH.
      call_exists sshcs_timeout_stop
      sshcs_ssh_stop
    else
      # Allow remote user to access an interactive shell.
      echo 'Giving shell access.'
      echo 'Reminder: poweroff upon timeout is running if enabled.'
      sshcs_ssh_shell_trigger
      ash -i +m
    fi
  fi
}

# Checks whether devices were unlocked, and act depending on situation.
# Expect one parameter indicating whether we are finalizing, that is caller
# will be done after this call.
#
# If poweroff was triggered, we block here until it is done.
#
# When called by script in console: if caller is finalizing, it means it will
# hand over control to boot sequence which will go on.
# This is a safety net, since main script is not supposed to end until devices
# are unlocked. So, if devices were not unlocked, we initiate poweroff here.
sshcs_check_done() {
  if sshcs_poweroff_triggered; then
    # When timeout is triggered (and we are powering off), it kills any pending
    # cryptsetup, and we end up here: block until poweroff shuts down the
    # computer.
    log_dbg 'Blocking sshcs_check_done: powering off'
    while true; do
      read -n 1 -s unused
    done
  fi

  # Whether we are called from the main script: that is whether the shell will
  # end when we return.
  local finalize=${1:-0}

  # If there is no interactive shell, we are called from the cryptsetup script,
  # right before it ends: force finalization in this case.
  [ ${sshcs_opt_use_shell} -eq 0 ] && finalize=1

  # Reset timeout when applicable: only possible from init script.
  call_exists sshcs_timeout_stop

  # Check devices are unlocked.
  sshcs_unlocked_test=1
  sshcs_unlocked=1
  . "${sshcs_cryptsetup_script}"
  if [ ${sshcs_unlocked} -ne 1 ]; then
    # Not all devices were unlocked.
    echo ''

    # When finalizing in console, power off
    if [ ${finalize} -eq 1 ] &&  proc_is_console; then
      log_err 'Devices are still locked! Powering off.'
      sshcs_poweroff_soft
    fi

    # When in shell or SSH, let user try again
    log_err 'Devices are still locked! Please retry.'
    return
  fi

  # Devices were unlocked.

  if [ ${finalize} -eq 0 ]; then
    # We end up here when called from the cryptsetup script inside an interactive
    # shell: we are running inside a subshell, and the parent shell running in
    # console or SSH is the one to do the cleanup.
    # Thus, we wish to end (logout) our parent interactive shell, to let the
    # script that launched it do finalization.
    proc_parse_stat $$
    kill -SIGHUP ${ppid}
    exit 0
  fi

  echo ''
  log_msg 'cryptsetup succeeded! Boot sequence should go on.'
  proc_is_console || echo 'Please wait and reconnect to nominal SSH service.'

  sshcs_cleanup
}

sshcs_cleanup() {
  local pgrep_output

  # Reminders:
  # We are called when devices have been unlocked.
  #
  # We are only called as part of the main shell (whether on console - the init
  # script - or through SSH - as the user login shell), and once we return, our
  # parent shell will end.
  #
  # The unlocking script does 'killall cryptsetup' after each successful unlock,
  # which is used to wake up any other running unlocking script.
  # Thus as long as all devices have been unlocked, we don't expect any script
  # to be stuck on 'cryptsetup' calls.

  sshcs_net_speed_restore

  if proc_is_console; then
    sshcs_ssh_stop

    # cleanup /dev/pts if necessary
    if [ ${dev_pts_mounted:-0} -ne 0 ]; then
      log_dbg 'Unmounting /dev/pts'
      umount /dev/pts
      rm -R /dev/pts
    fi

    # stop the network before going on in boot sequence
    sshcs_net_done
  elif [ ${sshcs_opt_use_shell} -eq 1 ]; then
    # We are in a SSH shell session.

    # Find and kill console shell.
    # This is necessary so that our script launched from the init process can
    # finally check that devices have been properly unlocked, properly end and
    # let the init process end booting.
    # Note: as a side effect, this will also kill the shell that was forked to
    # trigger a timeout, which is fine (we want to kill it, either from here or
    # from the init shell).
    log_dbg 'Searching console shells ...'
    pgrep_output=$(pgrep /usr/bin/ash)
    pgrep_output=$(echo "${pgrep_output}" | grep -E -v "^(|1|$$)$")
    echo "${pgrep_output}" | while read pid; do
      # Handle empty response
      [ -z "${pid}" ] && continue
      proc_find_parent_cmd ${pid} "${sshd_process_name}" && continue
      log_dbg "Killing console shell pid=${pid}"
      kill -SIGHUP ${pid}
    done
  fi
  # else: when in SSH shell script, we have nothing else to do other than exit.

  log_dbg 'All done'
}
