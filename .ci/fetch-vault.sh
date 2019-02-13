#!/usr/bin/env bash
# This script downloads, verifies, and unzips Vault into the current working
# directory.
#
# Available options (via env vars):
# * VAULT_VERSION: The version of Vault to download.
# * VAULT_ARCH:    The architecture of Vault to download (default: linux_amd64).
set -ex

VAULT_VERSION="${VAULT_VERSION:-1.0.1}"
VAULT_ARCH="${VAULT_ARCH:-linux_amd64}"
VAULT_BASEURL='https://releases.hashicorp.com/vault'

VAULT_GPGKEY='91A6E7F85D05C65630BEF18951852D87348FFC4C'
VAULT_GPGKEY_URL='https://keybase.io/hashicorp/pgp_keys.asc'

# Fetch HashiCorp's PGP key
wget "$VAULT_GPGKEY_URL" -O hashicorp.asc

# Verify the key's fingerprint before importing it
[ "$(gpg --batch --with-colons --with-fingerprint hashicorp.asc 2> /dev/null \
	| awk -F: '/^fpr:/ { print $10 }')" = "$VAULT_GPGKEY" ]

export GNUPGHOME="$(mktemp -d)"
gpg --batch --import hashicorp.asc

VAULT_ZIPFILE="vault_${VAULT_VERSION}_${VAULT_ARCH}.zip"
VAULT_SHAFILE="vault_${VAULT_VERSION}_SHA256SUMS"

# Download all the release files
wget "$VAULT_BASEURL/$VAULT_VERSION/$VAULT_ZIPFILE"
wget "$VAULT_BASEURL/$VAULT_VERSION/$VAULT_SHAFILE"
wget "$VAULT_BASEURL/$VAULT_VERSION/$VAULT_SHAFILE.sig"

# Verify the SHA256SUMS file with the HashiCorp PGP key, then check zipfile SHA
gpg --batch --verify "$VAULT_SHAFILE.sig" "$VAULT_SHAFILE"
grep "$VAULT_ZIPFILE" "$VAULT_SHAFILE" | sha256sum -c

# Finally unzip the archive
unzip "${VAULT_ZIPFILE}"

# Clean up
rm hashicorp.asc "$VAULT_ZIPFILE" "$VAULT_SHAFILE" "$VAULT_SHAFILE.sig"
gpgconf --kill gpg-agent
rm -rf "$GNUPGHOME"
