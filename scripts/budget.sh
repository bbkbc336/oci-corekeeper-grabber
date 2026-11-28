#!/bin/bash
# Creates a US$1/month budget on the whole tenancy with email alerts:
#  - actual spend reaches $0.01 (any real charge)
#  - forecast spend reaches 100% of $1
# Public repo: the alert email is masked in logs.
set -euo pipefail
NAME=corekeeper-free-guard
C=$(grep '^tenancy' ~/.oci/config | cut -d= -f2)
U=$(grep '^user' ~/.oci/config | cut -d= -f2)

EMAIL=$(oci iam user get --user-id "$U" --query 'data.email' --raw-output 2>/dev/null || true)
if [ -z "$EMAIL" ] || [ "$EMAIL" = "null" ]; then
  EMAIL=$(oci iam user get --user-id "$U" --query 'data.name' --raw-output)
fi
echo "::add-mask::$EMAIL"
case "$EMAIL" in *@*) ;; *) echo "Could not find an email for the API user."; exit 1 ;; esac

B=$(oci budgets budget list -c "$C" --all --query "data[?\"display-name\"=='$NAME'] | [0].id" --raw-output 2>/dev/null || true)
if [ -z "$B" ] || [ "$B" = "null" ]; then
  B=$(oci budgets budget create -c "$C" --display-name "$NAME" --amount 1 --reset-period MONTHLY \
        --target-type COMPARTMENT --targets "[\"$C\"]" \
        --description "Alert on any charge (Always Free should stay at 0)" \
        --query 'data.id' --raw-output)
  echo "budget created"
else
  echo "budget already exists"
fi

existing=$(oci budgets alert-rule list --budget-id "$B" --all --query 'length(data)' --raw-output 2>/dev/null || echo 0)
if [ "${existing:-0}" -gt 0 ]; then
  echo "alert rules already exist ($existing) - nothing to do"
  exit 0
fi

oci budgets alert-rule create --budget-id "$B" --display-name actual-any-charge \
  --type ACTUAL --threshold-type ABSOLUTE --threshold 0.01 --recipients "$EMAIL" \
  --message "Oracle Cloud: a real charge appeared (Core Keeper account). Check Billing > Cost Analysis." >/dev/null
echo "alert rule 1 created (actual >= \$0.01)"

oci budgets alert-rule create --budget-id "$B" --display-name forecast-over-1usd \
  --type FORECAST --threshold-type PERCENTAGE --threshold 100 --recipients "$EMAIL" \
  --message "Oracle Cloud: this month is forecast to exceed \$1 (Core Keeper account)." >/dev/null
echo "alert rule 2 created (forecast >= \$1)"
