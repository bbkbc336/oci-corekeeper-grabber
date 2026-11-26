#!/bin/bash
# Try to launch the Always Free A1 VM. Exits 0 always; writes "launched" to $GITHUB_OUTPUT on success.
set -u
NAME=corekeeper
C=$(grep '^tenancy' ~/.oci/config | cut -d= -f2)

EXIST=$(oci compute instance list -c "$C" --display-name "$NAME" \
  --query "length(data[?\"lifecycle-state\"!='TERMINATED'])" --raw-output 2>/dev/null || echo err)
[ -z "$EXIST" ] && EXIST=0
echo "existing instances: $EXIST"
if ! [[ "$EXIST" =~ ^[0-9]+$ ]]; then
  echo "Could not list instances - check OCI_CONFIG / OCI_KEY secrets."
  echo "status=error" >> "$GITHUB_OUTPUT"
  exit 1
fi
if [ "$EXIST" -gt 0 ]; then
  echo "Instance already exists - nothing to do."
  echo "status=exists" >> "$GITHUB_OUTPUT"
  exit 0
fi

AD=$(oci iam availability-domain list -c "$C" --query 'data[0].name' --raw-output)
IMG=$(oci compute image list -c "$C" --operating-system "Canonical Ubuntu" --operating-system-version "22.04" \
  --shape VM.Standard.A1.Flex --sort-by TIMECREATED --sort-order DESC --query 'data[0].id' --raw-output)
SUB=$(oci network subnet list -c "$C" --display-name ck-subnet --query 'data[0].id' --raw-output)
echo "AD=$AD"; echo "IMG=$IMG"; echo "SUB=$SUB"

ssh-keygen -t rsa -b 4096 -N "" -f ck_ssh -q

for cfg in "2 12" "1 6"; do
  set -- $cfg
  echo "Trying ${1} OCPU / ${2} GB ..."
  if oci compute instance launch -c "$C" --availability-domain "$AD" --shape VM.Standard.A1.Flex \
      --shape-config "{\"ocpus\":$1,\"memoryInGBs\":$2}" --image-id "$IMG" --subnet-id "$SUB" \
      --assign-public-ip true --display-name "$NAME" \
      --ssh-authorized-keys-file ck_ssh.pub --user-data-file scripts/cloud-init.sh \
      --query 'data.id' --raw-output > instance_id 2> err.txt; then
    echo "SUCCESS: ${1} OCPU / ${2} GB"
    echo "status=launched" >> "$GITHUB_OUTPUT"
    echo "shape=${1} OCPU / ${2} GB" >> "$GITHUB_OUTPUT"
    exit 0
  fi
  grep -o '"message": "[^"]*"' err.txt || cat err.txt
  sleep 20
done
echo "status=failed" >> "$GITHUB_OUTPUT"
exit 0
