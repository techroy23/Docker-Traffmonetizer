#!/bin/bash
# Comprehensive test suite for Docker-Traffmonetizer PROXY parsing.
# Covers: happy paths, nasty-password edge cases, and every validation error.
# The harness copies entrypoint.sh, strips the `main` invocation, redirects the
# redsocks config path to /tmp, and stubs redsocks/iptables side effects.

SCRIPT="entrypoint.sh"

# Strip trailing main call AND redirect the config path so no root is needed.
sed -e '/^main$/d' -e 's|/etc/redsocks.conf|/tmp/redsocks-test.conf|g' "$SCRIPT" > /tmp/tm-harness.sh

redsocks() { echo "  [FAKE redsocks launched]"; }
iptables()  { echo "  [FAKE iptables: $*]"; }
setup_iptables() { :; }

# Satisfy entrypoint.sh's top-of-script TOKEN/DEVNAME guards while sourcing.
export TOKEN=sometoken DEVNAME=testdev

# shellcheck disable=SC1091
source /tmp/tm-harness.sh

# The entrypoint sets -e; disable it so failing parse cases don't kill the harness.
set +e

PASS=0
FAIL=0

# Substring-based check so the trailing "Use host:port..." hint doesn't break
# exact-match comparisons on error messages.
check() {
  local label="$1"; local expected="$2"; local actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    PASS=$((PASS+1))
    echo "PASS: $label"
  else
    FAIL=$((FAIL+1))
    echo "FAIL: $label"
    echo "      expected substring: $expected"
    echo "      actual:            $actual"
  fi
}

# parse-only test: prints "host|port|user|pass" on success, or the ERROR line.
parse() {
  local output
  output=$( PROXY="$1"; parse_proxy_value; echo "$host|$port|$proxy_user|$proxy_pass" 2>&1 )
  echo "$output" | sed -E 's/^[0-9-]+ [0-9:]+ +>>> An2Kin >>> //'
}

echo "==================== HAPPY PATHS ===================="
check "plain host:port" "123.456.789.012|34567||" "$(parse '123.456.789.012:34567')"
check "auth host:port" "123.456.789.012|34567|myuser|mypassword" "$(parse 'myuser:mypassword@123.456.789.012:34567')"
check "socks5:// prefix" "123.456.789.012|34567|myuser|mypassword" "$(parse 'socks5://myuser:mypassword@123.456.789.012:34567')"
check "socks5h:// prefix" "123.456.789.012|34567||" "$(parse 'socks5h://123.456.789.012:34567')"
check "socks:// prefix" "123.456.789.012|34567||" "$(parse 'socks://123.456.789.012:34567')"
check "whitespace padding" "123.456.789.012|34567||" "$(parse '  123.456.789.012:34567  ')"

echo "==================== NASTY PASSWORD EDGE CASES ===================="
check "password with @ inside" "1.2.3.4|1080|user|p@ssw@rd" "$(parse 'user:p@ssw@rd@1.2.3.4:1080')"
check "password with : inside" "1.2.3.4|1080|user|pa:ss" "$(parse 'user:pa:ss@1.2.3.4:1080')"
check "password with backtick+dollar" '1.2.3.4|1080|user|p`ass`$' "$(parse 'user:p`ass`$@1.2.3.4:1080')"

echo "==================== ERROR CASES (must exit 1 with clear message) ===================="
check "missing host" "ERROR: PROXY ':34567' is missing a host" "$(parse ':34567')"
check "missing port" "ERROR: PROXY '123.456.789.012' is missing a port" "$(parse '123.456.789.012')"
check "non-numeric port" "ERROR: PROXY port 'port' must be a number" "$(parse '123.456.789.012:port')"
check "port too high" "ERROR: PROXY port '99999' is out of range" "$(parse '123.456.789.012:99999')"
check "port zero" "ERROR: PROXY port '0' is out of range" "$(parse '123.456.789.012:0')"
check "IPv6 bracketed" "looks like an IPv6 address" "$(parse '[2001:db8::1]:1080')"
check "IPv6 unbracketed" "looks like an IPv6 address" "$(parse '2001:db8::1:1080')"
check "creds no username" "has credentials but no username" "$(parse '@1.2.3.4:1080')"
check "creds no password" "has a username but no password" "$(parse 'user@1.2.3.4:1080')"
check "trailing garbage port" "looks like an IPv6 address" "$(parse '1.2.3.4:1080:extra')"
check "empty string" "is missing a host" "$(parse '')"

echo ""
echo "==================== CONFIG GENERATION ===================="
PROXY="123.456.789.012:34567"
setup_proxy
if grep -q 'login' /tmp/redsocks-test.conf; then
  FAIL=$((FAIL+1)); echo "FAIL: plain proxy config should NOT contain credentials"
else
  PASS=$((PASS+1)); echo "PASS: plain proxy config has no credentials"
fi
grep -q 'ip = 123.456.789.012;' /tmp/redsocks-test.conf && { PASS=$((PASS+1)); echo "PASS: plain config has host"; } || { FAIL=$((FAIL+1)); echo "FAIL: plain config missing host"; }

PROXY="myuser:mypassword@123.456.789.012:34567"
setup_proxy
grep -q 'login = "myuser";' /tmp/redsocks-test.conf && { PASS=$((PASS+1)); echo "PASS: auth config has login line"; } || { FAIL=$((FAIL+1)); echo "FAIL: auth config missing login"; }
grep -q 'password = "mypassword";' /tmp/redsocks-test.conf && { PASS=$((PASS+1)); echo "PASS: auth config has password line"; } || { FAIL=$((FAIL+1)); echo "FAIL: auth config missing password"; }
grep -q 'type = socks5;' /tmp/redsocks-test.conf && { PASS=$((PASS+1)); echo "PASS: auth config has socks5 type"; } || { FAIL=$((FAIL+1)); echo "FAIL: auth config missing type"; }

echo ""
echo "==================== SUMMARY ===================="
echo "PASS: $PASS  FAIL: $FAIL"
rm -f /tmp/tm-harness.sh /tmp/redsocks-test.conf
exit $FAIL