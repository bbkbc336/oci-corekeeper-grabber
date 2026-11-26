"""Build ~/.oci/config from the OCI_CONFIG secret (pasted config preview) and OCI_KEY secret."""
import os
import re
from pathlib import Path

raw = os.environ["OCI_CONFIG"]
key = os.environ["OCI_KEY"].strip()

vals = {}
for field in ("user", "fingerprint", "tenancy", "region"):
    m = re.search(rf"\b{field}\s*=\s*(\S+)", raw)
    if not m:
        raise SystemExit(f"OCI_CONFIG secret is missing '{field}='")
    vals[field] = m.group(1)

home = Path.home() / ".oci"
home.mkdir(parents=True, exist_ok=True)
key_path = home / "key.pem"
key_path.write_text(key + "\n")
key_path.chmod(0o600)

cfg = home / "config"
cfg.write_text(
    "[DEFAULT]\n"
    + "".join(f"{k}={v}\n" for k, v in vals.items())
    + f"key_file={key_path}\n"
)
cfg.chmod(0o600)
print("region:", vals["region"])
