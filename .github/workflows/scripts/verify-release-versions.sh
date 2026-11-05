#!/usr/bin/env bash
# Checks that a release tag matches every publishable package.
#
# Usage: verify-release-versions.sh vX.Y.Z
#
# The publishable packages are released in lockstep, so each one's `version:`
# must equal the tag, and a dependency on another publishable package must be
# `^X.Y.Z`. pub.dev rejects a tag that doesn't match the pubspec, but only
# after the tag is pushed — this catches the mismatch before that.
#
# A package is publishable when its pubspec sits at `packages/<name>/pubspec.yaml`
# and has no `publish_to: none`; examples live one level deeper, so the glob
# never reaches them. Run from the repository root.
set -euo pipefail

tag="${1:?usage: $0 vX.Y.Z}"
version="${tag#v}"

names=()
pubspecs=()
for pubspec in packages/*/pubspec.yaml; do
  if grep -qE "^publish_to: *[\"']?none" "$pubspec"; then
    continue
  fi
  names+=("$(sed -n 's/^name: *//p' "$pubspec")")
  pubspecs+=("$pubspec")
done

if [[ ${#pubspecs[@]} -eq 0 ]]; then
  echo "::error ::❌ No publishable package found under packages/."
  exit 1
fi

failed=0
for i in "${!pubspecs[@]}"; do
  pubspec="${pubspecs[$i]}"
  name="${names[$i]}"

  package_version=$(sed -n 's/^version: *//p' "$pubspec")
  if [[ "$package_version" != "$version" ]]; then
    echo "::error file=$pubspec::❌ Tag $tag does not match $name's pubspec version $package_version."
    failed=1
  else
    echo "✅ $name $package_version"
  fi

  for dep in "${names[@]}"; do
    # The constraint under `dependencies:` only; dev_dependencies aren't published.
    constraint=$(awk -v dep="$dep:" '
      /^[^ #]/ { in_deps = ($1 == "dependencies:") }
      in_deps && $1 == dep { print $2 }
    ' "$pubspec")
    if [[ -n "$constraint" && "$constraint" != "^$version" ]]; then
      echo "::error file=$pubspec::❌ $name depends on $dep $constraint; a lockstep release needs ^$version."
      failed=1
    fi
  done
done

exit "$failed"
