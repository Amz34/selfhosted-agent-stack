#!/bin/bash
# One-shot systemd user-service restart via cron.
#
# Why this exists: restarting a Hermes-family gateway from *inside* the gateway
# process is blocked (SIGTERM propagates to child processes and kills the
# command before it completes). Running the restart from the cron daemon —
# which lives outside the gateway's process tree — sidesteps that cleanly.
#
# Setup (one-shot):
#   chmod +x gateway_restart_cron.sh
#   crontab -e
#   # next minute, then self-removes:
#   * * * * * /path/to/gateway_restart_cron.sh SERVICE_NAME && crontab -l | grep -v gateway_restart_cron | crontab -
#
# Note: cron runs without the user session bus, so XDG_RUNTIME_DIR must be set
# for `systemctl --user` to reach the user manager.

SERVICE="${1:-hermes-gateway.service}"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

systemctl --user restart "$SERVICE"
sleep 15
systemctl --user is-active "$SERVICE"
