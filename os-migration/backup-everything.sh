#!/usr/bin/env bash
# Full system backup -> single compressed tar archive on the Storage drive.
#
# WHY tar (not a plain file copy): the destination (sdb1 / "Storage") is NTFS,
# which cannot store Unix permissions, ownership, or symlinks. A raw rsync there
# would be a broken backup. Tar preserves everything INSIDE the archive; NTFS
# just holds one .tar.zst file. Restore with the companion command at the bottom.
#
# Captures the whole btrfs root+home. Excludes only transient data and the VMs.
# Usage: ./backup-everything.sh              (defaults to the Storage drive)
#        ./backup-everything.sh /some/other/dir
set -euo pipefail

DEST_DIR="${1:-/run/media/joe/Storage}"
[ -d "$DEST_DIR" ] || { echo "Destination not found: $DEST_DIR"; exit 1; }
STAMP=$(date +%Y-%m-%d)
OUT="$DEST_DIR/omarchy-fullbackup-$STAMP.tar.zst"

echo "Source:      /  (btrfs root + home, ~357G)"
echo "Destination: $OUT"
echo "Excluding:   pseudo-fs, caches, trash, VM images, the destination itself."
echo

sudo tar \
  --create \
  --file - \
  --xattrs --xattrs-include='*' \
  --acls \
  --numeric-owner \
  --sparse \
  --exclude='./dev' \
  --exclude='./proc' \
  --exclude='./sys' \
  --exclude='./run' \
  --exclude='./tmp' \
  --exclude='./mnt' \
  --exclude='./media' \
  --exclude='./efi' \
  --exclude='./var/lib/libvirt/images' \
  --exclude='./var/cache' \
  --exclude='./var/tmp/*' \
  --exclude='./home/*/.cache' \
  --exclude='./home/*/.local/share/Trash' \
  --exclude='./swapfile' \
  --exclude='./lost+found' \
  --directory / \
  . \
  | zstd -T0 -3 -v -o "$OUT"

echo
echo "Done. Backup written to: $OUT"
echo "Size: $(du -h "$OUT" | cut -f1)"
echo
echo "--- To restore a single file later (no full extract needed) ---"
echo "  zstd -dc \"$OUT\" | sudo tar -xf - -C /destination ./etc/fstab"
echo "--- To list contents ---"
echo "  zstd -dc \"$OUT\" | tar -tvf - | less"
