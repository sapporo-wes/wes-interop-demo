#!/bin/bash
#
# Cloud-init user-data for the WES interop demo instance.
# Runs once on first boot as root. Logs to /var/log/cloud-init-output.log.
#
# Installs: Sapporo (pip), Snakemake, bcftools, nginx (HTTP only), certbot.
# Triggers an async one-shot service to download + concat the 1000G GRCh38 VCFs.
#
set -euxo pipefail
exec > >(tee /var/log/wes-demo-provision.log) 2>&1

export DEBIAN_FRONTEND=noninteractive

# Wait for any cloud-init-spawned apt operations to finish before we run ours.
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "Waiting for dpkg lock..."
  sleep 3
done

apt-get update
apt-get install -y \
  python3 python3-venv python3-pip \
  nginx certbot python3-certbot-nginx \
  bcftools tabix \
  curl wget git jq \
  build-essential

# ---- Sapporo + Snakemake in a dedicated venv -------------------------------
python3 -m venv /opt/sapporo/venv
/opt/sapporo/venv/bin/pip install --upgrade pip wheel
# Pinned to the newest releases as of the original JPT-site build (2026-06-05).
/opt/sapporo/venv/bin/pip install "sapporo==2.2.5" "snakemake==9.22.0"
# rocrate 0.16.0 (2026-10-06) drops WORKFLOW_PROFILE, which breaks Sapporo's RO-Crate export.
/opt/sapporo/venv/bin/pip install "rocrate==0.15.0"

# ---- Conda (miniforge) for --use-conda Snakemake runs ----------------------
# The native executor (below) runs Snakemake on the host, so workflows that
# declare conda: envs need conda/mamba available on the service PATH.
curl -fsSL -o /tmp/miniforge.sh \
  https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash /tmp/miniforge.sh -b -p /opt/conda
ln -sf /opt/conda/bin/conda /usr/local/bin/conda
ln -sf /opt/conda/bin/mamba /usr/local/bin/mamba

# ---- Sapporo runtime user + dirs -------------------------------------------
useradd -r -d /var/lib/sapporo -s /usr/sbin/nologin sapporo || true
mkdir -p /var/lib/sapporo/runs /var/log/sapporo
# sapporo owns /opt/conda so --use-conda can build envs (pkg cache writable).
chown -R sapporo:sapporo /var/lib/sapporo /var/log/sapporo /opt/sapporo /opt/conda

# ---- Native (no-Docker) Sapporo executor -----------------------------------
# Sapporo's stock run.sh runs each engine via `docker run`. This box is not
# containerized, so patch run_snakemake to run Snakemake directly on the host:
# host data paths are visible and --use-conda uses the host conda. The unit
# below points Sapporo at this patched copy via --run-sh.
SAPPORO_RUNSH="$(/opt/sapporo/venv/bin/python -c 'import sapporo; from pathlib import Path; print(Path(sapporo.__file__).parent / "run.sh")')"
cat > /tmp/native_run_snakemake.sh <<'FUNC'
function run_snakemake() {
    local wf_url_local
    if [[ "${wf_url}" == http://* ]] || [[ "${wf_url}" == https://* ]]; then
        wf_url_local="${exe_dir}/$(basename "${wf_url}")"
        curl -fsSL -o "${wf_url_local}" "${wf_url}" || { executor_error $?; }
    elif [[ "${wf_url}" == /* ]]; then
        wf_url_local="${wf_url}"
    else
        # Tolerate an optional 'file:' scheme prefix on attachment names.
        wf_url_local="${exe_dir}/${wf_url#file:}"
    fi
    local -a cmd_arr=(snakemake --directory "${exe_dir}")
    _append_engine_params cmd_arr
    cmd_arr+=(--configfile "${wf_params}" --snakefile "${wf_url_local}")
    _write_and_run cmd_arr
    snakemake --directory "${exe_dir}" --configfile "${wf_params}" \
        --snakefile "${wf_url_local}" --summary 2>/dev/null \
        | tail -n +2 | cut -f 1 > "${exe_dir}/.snakemake_outputs" || true
    while read -r file_path; do
        if [[ -z "${file_path}" ]] || [[ "${file_path}" == *".."* ]] || [[ "${file_path}" == /* ]]; then
            continue
        fi
        local dir_path
        dir_path=$(dirname "${file_path}")
        mkdir -p "${outputs_dir}/${dir_path}"
        cp "${exe_dir}/${file_path}" "${outputs_dir}/${file_path}" 2>/dev/null || true
    done < "${exe_dir}/.snakemake_outputs"
    rm -f "${exe_dir}/.snakemake_outputs"
}
FUNC
awk '
  /^function run_snakemake\(\)/ {
     while ((getline line < "/tmp/native_run_snakemake.sh") > 0) print line
     close("/tmp/native_run_snakemake.sh")
     skip=1; next
  }
  skip==1 && /^}/ { skip=0; next }
  skip==1 { next }
  { print }
' "$SAPPORO_RUNSH" > /opt/sapporo/run.native.sh
chown sapporo:sapporo /opt/sapporo/run.native.sh
chmod 755 /opt/sapporo/run.native.sh
rm -f /tmp/native_run_snakemake.sh

# ---- systemd unit for Sapporo ----------------------------------------------
cat > /etc/systemd/system/sapporo.service <<'UNIT'
[Unit]
Description=Sapporo WES service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=sapporo
Group=sapporo
WorkingDirectory=/var/lib/sapporo
Environment=PATH=/opt/sapporo/venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/opt/sapporo/venv/bin/sapporo --host 127.0.0.1 --port 1122 --run-dir /var/lib/sapporo/runs --run-sh /opt/sapporo/run.native.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now sapporo.service

# ---- nginx reverse proxy (HTTP only; TLS added later by `wes-demo tls`) ----
cat > /etc/nginx/sites-available/wes-demo <<'NGINX'
server {
    listen 80;
    server_name _;
    client_max_body_size 100m;

    location / {
        proxy_pass http://127.0.0.1:1122;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX
ln -sf /etc/nginx/sites-available/wes-demo /etc/nginx/sites-enabled/wes-demo
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

# ---- Demo workflow repo ----------------------------------------------------
mkdir -p /opt/wes-interop-demo
git clone --branch v1.0.0 https://github.com/sapporo-wes/wes-interop-demo.git /opt/wes-interop-demo
chown -R ubuntu:ubuntu /opt/wes-interop-demo

# The dbSNP-corrected target SNPs now live in the repo (PR #1, merged), and the
# workflow normalizes BED contig naming to the VCF style, so no overlay is
# needed. (The 1000G GRCh38 VCFs use plain '12/2/15'; the BED uses 'chr*'.)

# ---- 1000G GRCh38 biallelic data prep (run async, can take ~10 min) --------
mkdir -p /data/1000g
chown -R ubuntu:ubuntu /data

cat > /usr/local/bin/wes-demo-data-prep.sh <<'PREP'
#!/usr/bin/env bash
set -euxo pipefail
exec > >(tee /var/log/wes-demo-data-prep.log) 2>&1

BASE=https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/release/20190312_biallelic_SNV_and_INDEL
PANEL=https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/integrated_call_samples_v3.20130502.ALL.panel
cd /data/1000g

for CHR in 2 12 15; do
  for EXT in vcf.gz vcf.gz.tbi; do
    F="ALL.chr${CHR}.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.${EXT}"
    [[ -s "$F" ]] || curl -fL -O "${BASE}/${F}"
  done
done

MERGED=ALL.chr2_12_15.GRCh38.phased.vcf.gz
if [[ ! -s "$MERGED" ]]; then
  # --threads parallelizes bgzip recompression. The previous single-threaded
  # --allow-overlaps was too slow on m5.large and hit the systemd start timeout.
  # (--naive is not usable: the per-chromosome files have incompatible headers.)
  bcftools concat --threads 2 \
    ALL.chr2.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.vcf.gz \
    ALL.chr12.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.vcf.gz \
    ALL.chr15.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.vcf.gz \
    --output-type z --output "$MERGED"
  tabix -p vcf "$MERGED"
fi

for POP in JPT CEU; do
  OUT="$(echo $POP | tr '[:upper:]' '[:lower:]')_samples.txt"
  [[ -s "$OUT" ]] || curl -fsSL "$PANEL" | awk -F'\t' -v p="$POP" '$2==p{print $1}' > "$OUT"
done

touch /data/1000g/.ready
PREP
chmod +x /usr/local/bin/wes-demo-data-prep.sh

cat > /etc/systemd/system/wes-demo-data-prep.service <<'UNIT'
[Unit]
Description=Download and prepare 1000G GRCh38 demo data
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/data/1000g/.ready

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wes-demo-data-prep.sh
User=ubuntu
Group=ubuntu
TimeoutStartSec=3600

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now wes-demo-data-prep.service

echo "WES demo provisioning complete."
echo "Data prep running in background: systemctl status wes-demo-data-prep.service"
