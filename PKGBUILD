# Maintainer: Julien Coloos <julien.coloos [at] gmail [dot] com>
pkgname=initrd-ssh-cryptsetup
pkgver=1.0
pkgrel=1
pkgdesc="Allows to remotely unlock LUKS-encrypted devices over SSH"
arch=('any')
url="https://github.com/suiryc/archlinux-$pkgname"
license=('GPL3')
depends=('dropbear' 'cryptsetup' 'mkinitcpio-nfs-utils' 'iproute2' 'ethtool')
install=$pkgname.install
changelog='ChangeLog'
source=("http://julien.coloos.free.fr/archlinux/$pkgname-$pkgver.tar.xz" "$pkgname.install")
sha256sums=('de6ef287ecfd57614835fec1fcaa01eb3a7f999d42a749e20b6747671320508f'
            'b84978b3c2ef32208c2b104ee2d3ce8aaec26da0bd4e9e1c83942f373bbf6285')

package() {
  install -Dm644 "$srcdir/src/install/ssh-cryptsetup"     "$pkgdir/usr/lib/initcpio/install/ssh-cryptsetup"
  install -Dm644 "$srcdir/src/hooks/ssh-cryptsetup"       "$pkgdir/usr/lib/initcpio/hooks/ssh-cryptsetup"
  install -Dm644 "$srcdir/src/hooks/ssh-cryptsetup-tools" "$pkgdir/usr/lib/initcpio/hooks/ssh-cryptsetup-tools"
}

