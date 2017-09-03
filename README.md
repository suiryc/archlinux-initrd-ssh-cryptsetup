Personal ArchLinux package combining dropbear and cryptsetup in initrd for unlocking LUKS-encrypted devices either locally (boot console) or remotely over SSH.  
The code was reworked from legacy dropbear_initrd_encrypt AUR package.


## Installation
After cloning the repo, installation is done as for an AUR package, e.g.:

    makepkg -sri


## Dropbear
SSH server key need to be generated for `dropbear`.  
Either a new key can be generated with `dropbearkey`, e.g.:

    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
Or an existing OpenSSH key can be converted with `dropbearconvert` (useful so that the server fingerprint is the same with both), e.g.:

    dropbearconvert openssh dropbear /etc/ssh/ssh_host_ecdsa_key /etc/dropbear/dropbear_ecdsa_host_key
Note: `rsa` and `dss` (`dsa` in OpenSSH) types are also handled.


## Configuration
As explained upon installation, the following things need to be done:
   * add the authorized SSH public key to `/etc/dropbear/initrd.authorized_keys`
   * add the `ip=` kernel command parameter to the bootloader configuration (see https://wiki.archlinux.org/index.php/Mkinitcpio#Using_net)
      - e.g. with `grub`: add `ip=:::::eth0:dhcp` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, and re-generate the configuration with `grub-mkconfig -o /boot/grub/grub.cfg`
   * in the `HOOKS` section of `/etc/mkinitcpio.conf`, add `ssh-cryptsetup` before `filesystems`; then rebuild the initramfs: `mkinitcpio -p linux`
      - when using a non-standard keyboard layout, it is also useful to add the `keymap` hook before `ssh-cryptsetup`, and also move `keyboard` before `keymap`

The LUKS-encrypted devices to unlock are derived from `/etc/crypttab`.


Some options can be set in `/etc/initcpio/sshcs_env` (file is sourced in initrd shell):
   * `sshcs_opt_debug`: whether to be more verbose about ongoing actions
      - default: 0
      - any non-zero value to enable
   * `sshcs_opt_timeout_ipconfig`: time (in seconds) to configure IP
      - default: 10 seconds
   * `sshcs_opt_listen`: SSH listening port
      - default: 22
   * `sshcs_opt_timeout_poweroff`: time (in seconds) to unlock devices before automatic powering off
      - default (and minimum value): 2 minutes
      - negative value to deactivate

For example:

    sshcs_opt_timeout_ipconfig=30
    sshcs_opt_listen=2222
    sshcs_opt_timeout_poweroff=-1


## Building notes
1. Modify the sources (features in `src`, and/or package building files)
2. If `src` was modified
   * archive the `src` folder in `$pkgname-$pkgver.tar.xz` file; e.g.: `tar -cJf initrd-ssh-cryptsetup-0.4.tar.xz src`
   * upload the archive on the online repository (pointed by `PKGBUILD`)
3. Update `PKGBUILD`
   * bump `pkgver` if `src` was modified, or `pkgrel` if building files were modified
   * refresh `md5sums` if necessary (based on `md5sum initrd-ssh-cryptsetup-*.tar.xz initrd-ssh-cryptsetup.install` output)
4. Delete generated archive file if any
