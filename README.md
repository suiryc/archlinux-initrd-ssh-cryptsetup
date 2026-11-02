Personal ArchLinux package combining SSH (*Dropbear*, *OpenSSH* or *TinySSH*) and *cryptsetup* in *initramfs* for unlocking LUKS-encrypted devices either locally (boot console) or remotely.  
The code was initially reworked from legacy `dropbear_initrd_encrypt` AUR package.  
Works whether *systemd* is used or not inside *initramfs*.


## Installation
Build files are in the `dist` subfolder.

After cloning the repo, installation is done as for an AUR package, e.g.:
```bash
makepkg -sri
```

To test local changes, set variable `LOCAL=1`:
```bash
LOCAL=1 makepkg -Cfsric
```

## SSH daemon
Either `dropbear`, `openssh` or `tinyssh` can be used as SSH daemon.  
The default is to use `dropbear`.  
*initramfs* building will ensure the wanted dependency is present.

> [!warning]
> The SSH server keys will be present unprotected in *initramfs*.  
> For security reasons, dedicated keys should be generated and used if the nominal ones - used after boot - are protected (e.g. stored on an encrypted disk).

### Dropbear
A dedicated (default) configuration is used inside the *initramfs*.

SSH server key(s) need to be generated for `dropbear`: `rsa`, `ecdsa`, and/or `ed25519`.  
Installation will, in order of preference:
- copy existing Dropbear keys (from `/etc/dropbear`)
- convert existing OpenSSH keys (from `/etc/ssh`)
- generate new ones in `/etc/dropbear`, and copy them

If needed, a new key can be generated with `dropbearkey`, e.g.:
```bash
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
```
Or an existing OpenSSH key can be converted with `dropbearconvert` (useful so that the server fingerprint is the same with both), e.g.:
```bash
dropbearconvert openssh dropbear /etc/ssh/ssh_host_ecdsa_key /etc/dropbear/dropbear_ecdsa_host_key
```
Notes:
   * `rsa` and `ed25519` types are also handled
   * OpenSSH keys must be in `PEM` format for `dropbearconvert` to properly work

If necessary an existing key file can be converted to `PEM` format using `ssh-keygen`:
```bash
ssh-keygen -A -p -m PEM -f /etc/ssh/ssh_host_ecdsa_key
```

### OpenSSH
A dedicated configuration is generated inside the *initramfs*.

Nominal keys (from `/etc/ssh`) are copied.

### TinySSH
Native keys (from `/etc/tinyssh/sshkeydir`) are copied if present.  
Otherwise, OpenSSH `/etc/ssh/ssh_host_ed25519_key` key is converted if present.

An existing OpenSSH key can be converted with `tinyssh-convert`:
```bash
tinyssh-convert "/etc/tinyssh/sshkeydir" < "/etc/ssh/ssh_host_ed25519_key"
```

There must be at least one *ed25519* authorized key.

## Configuration

### Setup
As explained upon installation, the following things need to be done:

1. Add the authorized SSH public key(s) to `/etc/initcpio/sshcs_authorized_keys`.  
   If no key is present, the hook will do nothing, neither during *initramfs* building, nor boot.

2. Add the `ip=` kernel command parameter to the bootloader configuration.  
   See [wiki](https://wiki.archlinux.org/title/Mkinitcpio#Using_net) and [`ipconfig` documentation](https://git.kernel.org/pub/scm/libs/klibc/klibc.git/tree/usr/kinit/ipconfig/README.ipconfig).  
   e.g. with `grub`: add `ip=:::::eth0:dhcp` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`.  
   After changing settings, *grub* configuration needs to be regenerated: `grub-mkconfig -o /boot/grub/grub.cfg`.

3. Add `ssh-cryptsetup` in the `HOOKS` section of `/etc/mkinitcpio.conf`.  
   The hook must be added before `filesystems`.  
   For *initramfs* without *systemd*, `ssh-cryptsetup` fully replaces the `encrypt` hook:
   ```
   HOOKS=(base udev ... ssh-cryptsetup filesystems fsck)
   ```
   For *initramfs* with *systemd*, `ssh-cryptsetup` complements the `sd-encrypt` hook:
   ```
   HOOKS=(base systemd ... ssh-cryptsetup sd-encrypt filesystems fsck)
   ```
   When using a non-standard keyboard layout, it is also useful to add the `keymap` hook before `ssh-cryptsetup`, and move `keyboard` before `keymap`.  
   After changing the configuration, *initramfs* must be rebuilt: `mkinitcpio -p linux`.

### `/etc/crypttab`
The LUKS-encrypted devices to unlock are derived from `/etc/crypttab`.

Only entries with the `x-initrd.attach` option will be unlocked during boot.  
If no entry has this option, the hook will do nothing, neither during *initramfs* building, nor boot.

Example:
```
volname UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx none luks,x-initrd.attach
```

### Hook options
Some options can be set in `/etc/initcpio/sshcs_env` (file is sourced in *initramfs*).

#### `sshcs_opt_log_kmsg`
Whether to log (debug, info, error) messages to *kmsg* too.

Many messages are only printed on console and are unaffected.  
By default (debug disabled), only useful messages are logged.

Default: `1`.  
Set `0` to disable.

#### `sshcs_opt_debug`
Whether to be more verbose about ongoing actions.

Default: `0`.  
Any non-zero value to enable.

#### `sshcs_opt_net_wol`
Wake-on-LAN option to set on network device.

Usually, WoL is disabled upon entering *initramfs*.  
This option is useful to re-enable WoL if computer is powered off before booting into OS: once fully booted, standard tools like *udev* are more easily accessible to tweak network device if needed.

Default: `g` (MagicPacket™).  
Set empty, or `d` (disabled), to not change network device WoL setting.

#### `sshcs_opt_net_speed`
Speed (Mbps) to set on network device during *initramfs*.

When powering off while WoL is enabled, the latest Arch/kernel tends to keep the current speed (e.g. 1000M when computer was fully booted) instead of downgrading to 10M as happened in previous versions.  
This noticeably increases the device power consumption in this case.

This option can change the network device speed, keeping full duplex enabled, but disabling auto-negotiation.  
It only applies to boot phase (*initramfs*): if devices are successfully unlocked, the network is reconfigured/restored before transitioning to the full OS.

Default: `10`.  
Set `0` to not change network device speed.

#### `sshcs_opt_timeout_ipconfig`
Time (in seconds) to configure IP.

Default: `10`.

#### `sshcs_opt_ssh_daemon`
SSH daemon to use.

Default: `dropbear`.  
Possible values: `dropbear`, `openssh`, `tinyssh`.

#### `sshcs_opt_listen`
SSH listening port.

Default: `22`.

#### `sshcs_opt_timeout_poweroff`
Time (in seconds) to unlock devices before automatic powering off.

If *initramfs* boot reached `ssh-cryptsetup`, but target devices are not unlocked before the configured timeout, the hook will power off the computer.  
This prevents keeping the computer powered on if remotely woken up (WoL) but remote access somehow fails to unlock devices (e.g. because network could not be properly set up in *initramfs*).

Default (and minimum value): `120` (2 minutes).  
Set `0` or a negative value to deactivate.

#### `sshcs_opt_use_shell`
Whether to start a full `ash` shell.  
When disabled (the default), a script to unlock devices is executed instead.

Default: `0`.  
Any non-zero value to enable.

#### Configuration example
```bash
sshcs_opt_timeout_ipconfig=30
sshcs_opt_listen=2222
sshcs_opt_timeout_poweroff=-1
sshcs_opt_use_shell=1
```

## Building notes
1. Modify the sources (features in `src`, and/or package building files)
2. If sources were modified
   * bump `pkgver`, or `pkgrel`, in `PKGBUILD`
   * archive the sources folder in `$pkgname-$pkgver-$pkgrel.tar.xz` file
     * e.g.: `tar -cJf initrd-ssh-cryptsetup-$(grep "^pkgver=" dist/PKGBUILD | cut -d'=' -f2)-$(grep "^pkgrel=" dist/PKGBUILD | cut -d'=' -f2).tar.xz README.md src`
   * upload the archive to the online repository (pointed to by `PKGBUILD`)
3. Update ChangeLog
4. Update `PKGBUILD`
   * bump `pkgrel` if only building files were modified
   * refresh `sha256sums` with `updpkgsums` if necessary
     - or manually, based on `sha256sum initrd-ssh-cryptsetup-*.tar.xz initrd-ssh-cryptsetup.install` output
5. Upload changes and tag the repository to match the package release: `$pkgver-$pkgrel`
6. Delete generated archive file if any
