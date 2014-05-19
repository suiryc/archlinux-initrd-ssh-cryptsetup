Personal ArchLinux package combining dropbear and cryptsetup in initrd for unlocking LUKS-encrypted devices either locally (boot console) or remotely over SSH.
The code was reworked from [dropbear_initrd_encrypt](https://aur.archlinux.org/packages/dropbear_initrd_encrypt/).


## Installation
After cloning the repo, installation is done as for an AUR package.


## Configuration
As explained upon installation, the following things need to be done:
  * add the SSH public key to `/etc/dropbear/initrd.authorized_keys`
  * add the `ip=` kernel command parameter to the bootloader configuration (see https://wiki.archlinux.org/index.php/Mkinitcpio#Using_net)
  * in the `HOOKS` section of `/etc/mkinitcpio.conf`, add `ssh-cryptsetup` before `filesystems`; then rebuild the initramfs: `mkinitcpio -p linux`

The LUKS-encrypted devices to unlock are derived from `/etc/crypttab`.

The SSH listening port (22 by default) can be changed by setting the `sshcs_opt_listen` option in `/etc/dropbear/initrd.env` (file is sourced in initrd shell).
For example:

    sshcs_opt_listen=2222

