# Maintainer: Julien Coloos <julien.coloos [at] gmail [dot] com>
pkgname=initrd-ssh-cryptsetup
pkgver=1.1
pkgrel=2
pkgdesc="Allows to remotely unlock LUKS-encrypted devices over SSH"
arch=('any')
url="https://github.com/suiryc/archlinux-$pkgname"
license=('GPL3')
depends=('dropbear' 'cryptsetup' 'mkinitcpio-nfs-utils' 'iproute2' 'ethtool')
install=$pkgname.install
changelog='ChangeLog'
source=("http://julien.coloos.free.fr/archlinux/$pkgname-$pkgver-$pkgrel.tar.xz" "$pkgname.install")
sha256sums=('bfd3e55ef8d3dd9e0b24f5b6b708a41520ee426ed980366f7ffbd12e30b5230b'
            'b84978b3c2ef32208c2b104ee2d3ce8aaec26da0bd4e9e1c83942f373bbf6285')

package() {
  install -Dm644 "$srcdir/src/install/ssh-cryptsetup"     "$pkgdir/usr/lib/initcpio/install/ssh-cryptsetup"
  install -Dm644 "$srcdir/src/hooks/ssh-cryptsetup"       "$pkgdir/usr/lib/initcpio/hooks/ssh-cryptsetup"
  install -Dm644 "$srcdir/src/hooks/ssh-cryptsetup-tools" "$pkgdir/usr/lib/initcpio/hooks/ssh-cryptsetup-tools"
}

