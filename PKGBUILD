# Maintainer: Julien Coloos <julien.coloos [at] gmail [dot] com>
pkgname=initrd-ssh-cryptsetup
pkgver=1.1
pkgrel=1
pkgdesc="Allows to remotely unlock LUKS-encrypted devices over SSH"
arch=('any')
url="https://github.com/suiryc/archlinux-$pkgname"
license=('GPL3')
depends=('dropbear' 'cryptsetup' 'mkinitcpio-nfs-utils' 'iproute2' 'ethtool')
install=$pkgname.install
changelog='ChangeLog'
source=("http://julien.coloos.free.fr/archlinux/$pkgname-$pkgver.tar.xz" "$pkgname.install")
sha256sums=('33295d11216cb96a5b30f035add123d136fac38decd393d677f1c02b9ad22379'
            'b84978b3c2ef32208c2b104ee2d3ce8aaec26da0bd4e9e1c83942f373bbf6285')

package() {
  install -Dm644 "$srcdir/src/install/ssh-cryptsetup"     "$pkgdir/usr/lib/initcpio/install/ssh-cryptsetup"
  install -Dm644 "$srcdir/src/hooks/ssh-cryptsetup"       "$pkgdir/usr/lib/initcpio/hooks/ssh-cryptsetup"
  install -Dm644 "$srcdir/src/hooks/ssh-cryptsetup-tools" "$pkgdir/usr/lib/initcpio/hooks/ssh-cryptsetup-tools"
}

