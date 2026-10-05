# gamestream – Steam + Sunshine + noVNC egy konténerben
# Headless Wayland desktop (labwc + LXQt) egyetlen AMD render node-on, PRIME és card node nélkül.
FROM archlinux:latest

ARG SUNSHINE_VERSION=2026.914.233613
ARG NOVNC_VERSION=v1.7.0
ARG WEBSOCKIFY_VERSION=v0.13.0
ARG ROMM_SYNC_REF=main

# pacman: teljes fájlkészlet (locale-ok miatt), multilib a 32 bites Steam-könyvtárakhoz
RUN sed -i '/^NoExtract/d' /etc/pacman.conf \
 && printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf \
 && pacman -Sy --noconfirm archlinux-keyring \
 && pacman -Su --noconfirm \
 && pacman -S --noconfirm glibc tzdata \
 && printf 'en_US.UTF-8 UTF-8\nhu_HU.UTF-8 UTF-8\n' > /etc/locale.gen \
 && locale-gen \
 && rm -rf /var/cache/pacman/pkg/*

# GPU-stack (64 + 32 bit) – a Steam ELŐTT, hogy a pacman ne válasszon más Vulkan-drivert
RUN pacman -S --noconfirm --needed \
      mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon \
      vulkan-icd-loader lib32-vulkan-icd-loader libva-utils vulkan-tools \
      ttf-liberation noto-fonts noto-fonts-emoji \
 && rm -rf /var/cache/pacman/pkg/*

# Desktop, hang, VNC, böngésző, folyamatfelügyelet, segédeszközök
RUN pacman -S --noconfirm --needed \
      labwc xorg-xwayland wlr-randr qt6-wayland \
      lxqt-panel lxqt-config lxqt-notificationd lxqt-qtplugin lxqt-themes \
      pcmanfm-qt qterminal breeze-icons \
      pipewire pipewire-pulse pipewire-alsa wireplumber lib32-libpulse \
      dbus gvfs wayvnc firefox xdg-utils \
      supervisor sudo git python python-numpy inetutils iproute2 openssh procps-ng which \
 && rm -rf /var/cache/pacman/pkg/*

# Teljesítményfigyelés: qps (feladatkezelő), amdgpu_top (GPU + kódoló + hőfok), MangoHud (játékon belüli overlay),
# lm_sensors (a panel CPU-hőmérséklet pluginjéhez)
RUN pacman -S --noconfirm --needed qps amdgpu_top mangohud lib32-mangohud lm_sensors \
 && rm -rf /var/cache/pacman/pkg/*

# Steam
RUN pacman -S --noconfirm --needed steam \
 && rm -rf /var/cache/pacman/pkg/*

# RetroArch (core-ok nélkül – azokat a felhasználó választja ki a Core Downloaderrel)
RUN pacman -S --noconfirm --needed retroarch retroarch-assets-ozone retroarch-assets-xmb libretro-core-info \
 && rm -rf /var/cache/pacman/pkg/*

# romm-retroarch-saves (RetroArch mentések <-> RomM szinkron)
RUN python -m venv /opt/romm-sync \
 && /opt/romm-sync/bin/pip install --no-cache-dir "git+https://github.com/csaki89/romm-retroarch-saves.git@${ROMM_SYNC_REF}" \
 && ln -s /opt/romm-sync/bin/romm-sync /usr/local/bin/romm-sync

# Sunshine – a LizardByte hivatalos Arch csomagja
RUN curl -fL -o /tmp/sunshine.pkg.tar.zst \
      "https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_VERSION}/sunshine-${SUNSHINE_VERSION}-1-x86_64.pkg.tar.zst" \
 && pacman -U --noconfirm /tmp/sunshine.pkg.tar.zst \
 && rm -f /tmp/sunshine.pkg.tar.zst \
 && rm -rf /var/cache/pacman/pkg/*

# noVNC + websockify (böngészős VNC)
RUN git clone --depth 1 --branch "$NOVNC_VERSION" https://github.com/novnc/noVNC.git /opt/noVNC \
 && git clone --depth 1 --branch "$WEBSOCKIFY_VERSION" https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify \
 && printf '<!DOCTYPE html><meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&resize=scale&reconnect=true">\n' > /opt/noVNC/index.html

# Saját fájlok: indítóscriptek, supervisord, PipeWire null-sink, első indításkori home-sablon
COPY rootfs/ /
RUN chmod +x /usr/local/bin/gs-* \
 && gs-retroarch-config skeleton \
 && echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel \
 && chmod 0440 /etc/sudoers.d/wheel

ENV LANG=en_US.UTF-8 TZ=Europe/Budapest
ENTRYPOINT ["/usr/local/bin/gs-entrypoint"]
