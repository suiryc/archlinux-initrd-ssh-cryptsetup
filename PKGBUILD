# Maintainer: Julien Coloos <julien.coloos [at] gmail [dot] com>
pkgname=initrd-ssh-cryptsetup
pkgver=0.9
pkgrel=2
pkgdesc="Allows for LUKS-encrypted devices to be unlocked remotely over SSH"
arch=('any')
url="https://github.com/suiryc/archlinux-$pkgname"
license=('GPL3')
depends=('dropbear' 'cryptsetup' 'mkinitcpio-nfs-utils' 'iproute2')
install=$pkgname.install
changelog='ChangeLog'
source=("http://julien.coloos.free.fr/archlinux/$pkgname-$pkgver.tar.xz" "$pkgname.install")
sha256sums=('c3fa91fc8ba2228b3492d3709231918c8015cc3da49f516c3eacea5c0217536c'
            'b84978b3c2ef32208c2b104ee2d3ce8aaec26da0bd4e9e1c83942f373bbf6285')

package() {
  install -Dm644 "$srcdir/src/install/ssh-cryptsetup" "$pkgdir/usr/lib/initcpio/install/ssh-cryptsetup"
  install -Dm644 "$srcdir/src/hooks/ssh-cryptsetup"   "$pkgdir/usr/lib/initcpio/hooks/ssh-cryptsetup"
}

