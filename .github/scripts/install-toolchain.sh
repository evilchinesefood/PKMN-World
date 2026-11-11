#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
. /etc/os-release
mirror=
for candidate in https://archive.ubuntu.com/ubuntu https://mirrors.edge.kernel.org/ubuntu; do
  if curl --fail --silent --show-error --connect-timeout 5 --max-time 15 \
      "$candidate/dists/$VERSION_CODENAME/InRelease" --output /dev/null; then
    mirror="$candidate"
    break
  fi
done
if [[ -z "$mirror" ]]; then
  echo 'No Ubuntu package mirror is reachable.' >&2
  exit 1
fi
echo "Using Ubuntu package mirror: $mirror"

# Keep the runner's suites, components and signing keys; replace only the download host.
sudo find /etc/apt -maxdepth 2 -type f \( -name '*.sources' -o -name '*.list' \) \
  -exec sed -i -E \
    -e "s|mirror\\+file:/etc/apt/apt-mirrors(-security)?[.]txt|$mirror|g" \
    -e "s|https?://(azure[.])?(archive|security)[.]ubuntu[.]com/ubuntu|$mirror|g" {} +

apt_options=(-o Acquire::Retries=2 -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20)
for attempt in 1 2 3; do
  if sudo apt-get update --error-on=any "${apt_options[@]}" && \
     sudo apt-get install -y --no-install-recommends "${apt_options[@]}" \
       binutils-arm-none-eabi gcc-arm-none-eabi libnewlib-arm-none-eabi \
       libpng-dev libelf1 python3; then
    exit 0
  fi
  if [[ "$attempt" -lt 3 ]]; then
    echo "Toolchain installation failed (attempt $attempt/3); retrying." >&2
    sleep "$((attempt * 5))"
  fi
done
echo 'Toolchain installation failed after three attempts.' >&2
exit 1
