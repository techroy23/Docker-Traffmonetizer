#!/bin/bash
set -e

BIN_SDK="/app/traffmonetizerCLI"
IP_CHECKER_URL="https://raw.githubusercontent.com/techroy23/IP-Checker/refs/heads/main/app.sh"
ENABLE_IP_CHECKER="${ENABLE_IP_CHECKER:-false}"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

if [ -z "${TOKEN:-}" ]; then
  log " >>> An2Kin >>> ERROR: TOKEN environment variable is not set."
  exit 1
fi

if [ -z "${DEVNAME:-}" ]; then
  if [ -n "${HOSTNAME:-}" ]; then
    log " >>> An2Kin >>> DEVNAME not set, using HOSTNAME=$HOSTNAME"
    DEVNAME="$HOSTNAME"
  else
    log " >>> An2Kin >>> ERROR: Neither DEVNAME nor HOSTNAME is set."
    exit 1
  fi
fi

setup_iptables() {
  log " >>> An2Kin >>> Setting up iptables and redsocks..."
  if ! iptables -t nat -L REDSOCKS -n >/dev/null 2>&1; then
    iptables -t nat -N REDSOCKS
  else
    iptables -t nat -F REDSOCKS
  fi
  iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
  iptables -t nat -A REDSOCKS -d $host -j RETURN
  iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345

  if ! iptables -t nat -C OUTPUT -p tcp -j REDSOCKS 2>/dev/null; then
    iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
  fi
}

cleanup() {
  log " >>> An2Kin >>> "
  log " >>> An2Kin >>> Cleaning up iptables and redsocks..."
  iptables -t nat -F REDSOCKS 2>/dev/null || true
  iptables -t nat -D OUTPUT -p tcp -j REDSOCKS 2>/dev/null || true
  iptables -t nat -X REDSOCKS 2>/dev/null || true
  kill $REDSOCKS_PID 2>/dev/null || true
}
trap cleanup EXIT

# Parse the PROXY environment variable into host, port, proxy_user and proxy_pass.
# Accepts two formats:
#   1) host:port                       e.g. 123.456.789.012:34567
#   2) user:password@host:port         e.g. myuser:mypassword@123.456.789.012:34567
#
# On any malformed or out-of-range value the script logs a specific error and
# exits 1 so the caller sees exactly what is wrong instead of a vague failure.
parse_proxy_value() {
  local proxy_value="$PROXY"
  local credentials="" has_credentials=0

  # 1. Trim surrounding whitespace (e.g. from Docker env definitions).
  proxy_value="${proxy_value#"${proxy_value%%[![:space:]]*}"}"
  proxy_value="${proxy_value%"${proxy_value##*[![:space:]]}"}"

  # 2. Strip any scheme prefix the user may have pasted by mistake.
  case "$proxy_value" in
    socks5h://*) proxy_value="${proxy_value#socks5h://}" ;;
    socks5://*)  proxy_value="${proxy_value#socks5://}" ;;
    socks://*)   proxy_value="${proxy_value#socks://}" ;;
    http://*)    proxy_value="${proxy_value#http://}" ;;
    https://*)   proxy_value="${proxy_value#https://}" ;;
  esac

  # 3. Split credentials from the host:port part at the LAST '@' so that
  #    passwords containing an '@' character still parse correctly. Track a
  #    flag so an empty credential part (e.g. '@host:port') is still treated
  #    as an authentication error instead of a plain proxy.
  if [[ "$proxy_value" == *@* ]]; then
    has_credentials=1
    credentials="${proxy_value%@*}"
    proxy_value="${proxy_value##*@}"
  fi

  # 4. Split the remaining host:port part on the FIRST ':'.
  if [[ "$proxy_value" == *:* ]]; then
    host="${proxy_value%%:*}"
    port="${proxy_value#*:}"
  else
    host="$proxy_value"
    port=""
  fi

  # 5. Split the credentials part on the FIRST ':' so that passwords
  #    containing ':' characters still parse correctly. A credential part with
  #    no ':' at all is a username with no password (the whole string is the
  #    username).
  proxy_user=""
  proxy_pass=""
  if [ "$has_credentials" -eq 1 ]; then
    if [[ "$credentials" == *:* ]]; then
      proxy_user="${credentials%%:*}"
      proxy_pass="${credentials#*:}"
    else
      proxy_user="$credentials"
    fi
  fi

  # 6. Validate with specific, actionable error messages.
  if [ -z "$host" ]; then
    log " >>> An2Kin >>> ERROR: PROXY '$PROXY' is missing a host. Use host:port or user:password@host:port (e.g. 123.456.789.012:34567)."
    exit 1
  fi

  # IPv4 only: reject anything that looks like an IPv6 / bracketed address.
  # A ':' left in the port position is almost always a pasted unbracketed IPv6.
  if [[ "$host" == *:* ]] || [[ "$host" == \[* ]] || [[ "$port" == *:* ]]; then
    log " >>> An2Kin >>> ERROR: PROXY '$PROXY' looks like an IPv6 address. Only IPv4 hosts are supported (e.g. 123.456.789.012:34567)."
    exit 1
  fi

  if [ -z "$port" ]; then
    log " >>> An2Kin >>> ERROR: PROXY '$PROXY' is missing a port. Use host:PORT (e.g. ${host}:34567)."
    exit 1
  fi

  if ! [[ "$port" =~ ^[0-9]{1,5}$ ]]; then
    log " >>> An2Kin >>> ERROR: PROXY port '$port' must be a number (1-65535). Got '$PROXY'."
    exit 1
  fi

  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    log " >>> An2Kin >>> ERROR: PROXY port '$port' is out of range (1-65535). Got '$PROXY'."
    exit 1
  fi

  # If credentials were supplied, both username and password must be present.
  if [ "$has_credentials" -eq 1 ]; then
    if [ -z "$proxy_user" ]; then
      log " >>> An2Kin >>> ERROR: PROXY '$PROXY' has credentials but no username. Use user:password@host:port."
      exit 1
    fi
    if [ -z "$proxy_pass" ]; then
      log " >>> An2Kin >>> ERROR: PROXY '$PROXY' has a username but no password. Use user:password@host:port."
      exit 1
    fi
  fi
}

setup_proxy() {
  if [ -n "$PROXY" ]; then
    parse_proxy_value

    if [ -n "$proxy_user" ]; then
      log " >>> An2Kin >>> External routing via authenticated proxy: $host:$port (user: $proxy_user)"
    else
      log " >>> An2Kin >>> External routing via proxy: $host:$port"
    fi

    cat >/etc/redsocks.conf <<EOF
base {
  log_debug = off;
  log_info = off;
  log = "stderr";
  daemon = off;
  redirector = iptables;
}

redsocks {
  local_ip = 0.0.0.0;
  local_port = 12345;
  ip = $host;
  port = $port;
  type = socks5;
EOF

    if [ -n "$proxy_user" ]; then
      # Append credential lines with printf so special characters in the
      # username or password (e.g. $ or backticks) are written literally
      # instead of being interpreted by the shell.
      printf '  login = "%s";\n  password = "%s";\n' "$proxy_user" "$proxy_pass" >>/etc/redsocks.conf
    fi

    printf '}\n' >>/etc/redsocks.conf

    redsocks -c /etc/redsocks.conf >/dev/null 2>&1 &
    REDSOCKS_PID=$!

    setup_iptables
  else
    log " >>> An2Kin >>> Proxy not set, proceeding with direct connection"
  fi
}

check_ip() {
  if [ "$ENABLE_IP_CHECKER" = "true" ]; then
    log " >>> An2Kin >>> Checking current public IP..."
    if curl -fsSL "$IP_CHECKER_URL" | sh; then
      log " >>> An2Kin >>> IP checker script ran successfully"
    else
      log " >>> An2Kin >>> WARNING: Could not fetch or execute IP checker script"
    fi
  else
    log " >>> An2Kin >>> IP checker disabled (ENABLE_IP_CHECKER=$ENABLE_IP_CHECKER)"
  fi
}

main() {
  while true; do
      setup_proxy
      check_ip
      log " >>> An2Kin >>> Starting binary..."
      "$BIN_SDK" start accept --token "$TOKEN" --device-name "$DEVNAME" status statistics &
      PID=$!
      log " >>> An2Kin >>> APP PID is $PID"
      wait $PID
      log " >>> An2Kin >>> Process exited, restarting..."
      sleep 5
  done
}

main
