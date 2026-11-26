<h1 align="center">
  <img src="./icon.svg" width="48" align="center" alt="Polo Tweaks icon">
  Polo Tweaks
</h1>

A settings program for [Polo](https://github.com/keremsoke/polo). 

![Polo Tweaks Window](./polo-tweaks.png)

## Build

Needs Vala, Meson and GTK 3 (`vala meson gtk3-devel` on Fedora). Polo's schemas must be installed.

```sh
meson setup build
ninja -C build
./build/src/polo-tweaks            # or: --page=cube  (general, wobbly, animations, expo, cube, shortcuts)
sudo ninja -C build install        # to install
```
