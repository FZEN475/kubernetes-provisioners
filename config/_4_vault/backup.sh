#!/usr/bin/env ash
mkdir -p /backup/vault
tar -zcf "/backup/vault/$(date '+%Y-%m-%d_%H-%M').tar" -C /vault-data .
(find /tmp/backup/vault/ -mindepth 1 -mmin +14400 | xargs rm) &>/dev/null || true