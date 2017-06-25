# Maintainer: Julien Coloos <julien.coloos [at] gmail [dot] com>
pkgname=initrd-ssh-cryptsetup
pkgver=0.5
pkgrel=1
pkgdesc="Allows for LUKS-encrypted devices to be unlocked remotely over SSH"
arch=('any')
url="https://github.com/suiryc/archlinux-$pkgname"
license=('GPL3')
depends=('dropbear' 'cryptsetup' 'mkinitcpio-nfs-utils' 'iproute2')
install=$pkgname.install
changelog='ChangeLog'
source=("http://julien.coloos.free.fr/archlinux/$pkgname-$pkgver.tar.xz" "$pkgname.install")
md5sums=('d87a35adbef55db89f32a89f4966a27a'
         'ac60109d80e7bb2af0d66e69aaf178a6')

package() {
  install -Dm644 "$srcdir/src/install/ssh-cryptsetup" "$pkgdir/usr/lib/initcpio/install/ssh-cryptsetup"
  install -Dm644 "$srcdir/src/hooks/ssh-cryptsetup"   "$pkgdir/usr/lib/initcpio/hooks/ssh-cryptsetup"
}

