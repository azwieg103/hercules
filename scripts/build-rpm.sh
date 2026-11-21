#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM="$ROOT/upstream"
WORK="$ROOT/work"
RPMBUILD="$ROOT/rpmbuild"
DIST="$ROOT/dist"
LOGDIR="$ROOT/build-logs"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/build-$(date -u +%Y%m%dT%H%M%SZ).log"
exec > >(tee -a "$LOG") 2>&1

for cmd in gcc make rpmbuild git tar; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing build command: $cmd" >&2; exit 1; }
done

if [[ ! -d "$UPSTREAM/.git" ]]; then
  rm -rf "$UPSTREAM"
  git clone --depth 1 https://github.com/SDL-Hercules-390/hyperion.git "$UPSTREAM"
else
  git -C "$UPSTREAM" fetch --depth 1 origin master
  git -C "$UPSTREAM" reset --hard FETCH_HEAD
fi

VERSION="$(python3 - "$UPSTREAM/configure.ac" <<'PY'
import re,sys
s=open(sys.argv[1],encoding="utf-8").read()
values=[]
for key in ("VERS_MAJ","VERS_INT","VERS_MIN"):
    m=re.search(r"^"+key+r"=(\d+)",s,re.M)
    if not m: raise SystemExit("Unable to read "+key+" from configure.ac")
    values.append(m.group(1))
m=re.search(r"^VERS_DEV=(\d+)",s,re.M)
if m and m.group(1)!="0": values.append("dev")
print(".".join(values))
PY
)"
RPM_VERSION="${RPM_VERSION:-$VERSION}"
RPM_RELEASE="${RPM_RELEASE:-ZWIEGNET.1.el10}"
[[ "$RPM_VERSION" =~ ^[0-9]+(\.[0-9]+){2}(\.dev)?$ ]] || { echo "Invalid RPM_VERSION: $RPM_VERSION"; exit 1; }
[[ "$RPM_RELEASE" =~ ^ZWIEGNET\.[1-9][0-9]*\.el10$ ]] || { echo "Invalid RPM_RELEASE: $RPM_RELEASE"; exit 1; }

echo "Upstream repository: https://github.com/SDL-Hercules-390/hyperion"
echo "Upstream commit: $(git -C "$UPSTREAM" rev-parse HEAD)"
echo "Upstream version: $VERSION"
echo "RPM version-release: $RPM_VERSION-$RPM_RELEASE"

rm -rf "$WORK" "$RPMBUILD" "$DIST"
mkdir -p "$WORK" "$RPMBUILD/BUILD" "$RPMBUILD/BUILDROOT" "$RPMBUILD/RPMS" \
  "$RPMBUILD/SOURCES" "$RPMBUILD/SPECS" "$RPMBUILD/SRPMS" "$DIST"
tar -czf "$RPMBUILD/SOURCES/hercules-$RPM_VERSION.tar.gz" \
  --exclude=.git -C "$UPSTREAM" .
cp "$ROOT/packaging/hercules.1" "$RPMBUILD/SOURCES/hercules.1"

rpmbuild -ba "$ROOT/packaging/hercules.spec" \
  --define "_topdir $RPMBUILD" \
  --define "hercules_version $RPM_VERSION" \
  --define "hercules_release $RPM_RELEASE"

find "$RPMBUILD/RPMS" "$RPMBUILD/SRPMS" -type f -name '*.rpm' -exec cp -v {} "$DIST/" \;
test -n "$(find "$DIST" -maxdepth 1 -type f -name '*.rpm' -print -quit)"
for rpm in "$DIST"/*.rpm; do rpm -K "$rpm"; done
echo "RPM build complete:"
find "$DIST" -maxdepth 1 -type f -printf '%f\n' | sort
