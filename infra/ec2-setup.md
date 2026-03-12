# EC2 Setup — Japanese Site (Sapporo)

## Instance

- **AMI**: Ubuntu 24.04 LTS
- **Type**: t3.large (2 vCPU, 8 GB RAM) or larger depending on data volume
- **Storage**: 100 GB gp3 (for VCF data + Docker images)
- **Security group**: inbound TCP 443 (HTTPS) or 1122 (if within VPN only)

## 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
newgrp docker
```

## 2. Deploy Sapporo

```bash
mkdir -p ~/sapporo && cd ~/sapporo

# Download compose file
curl -O https://raw.githubusercontent.com/sapporo-wes/sapporo-service/main/compose.yml

# Start
docker compose up -d

# Verify
curl localhost:1122/service-info | jq .workflow_engine_versions
```

## 3. Mount VCF data

The compose.yml mounts `${PWD}/runs` for workflow execution. VCF files must be accessible
at the paths specified in `params/jpt_params.json`. Recommended layout:

```
/data/
├── 1000g/
│   ├── ALL.chr2.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz
│   ├── ALL.chr2.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz.tbi
│   ├── ALL.chr12.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz
│   ├── ALL.chr12.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz.tbi
│   ├── ALL.chr15.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz
│   ├── ALL.chr15.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz.tbi
│   └── jpt_samples.txt
└── wes-interop-demo/
    └── data/
        └── target_snps.bed
```

Add the `/data` mount to `compose.yml`:

```yaml
volumes:
  - ${PWD}/runs:${PWD}/runs:rw
  - /var/run/docker.sock:/var/run/docker.sock
  - /data:/data:ro        # <-- add this line
```

## 4. Restrict executable workflows (data governance)

Create `executable_workflows.json` to allow only the reviewed workflow:

```json
{
  "workflows": [
    "https://raw.githubusercontent.com/sapporo-wes/wes-interop-demo/main/workflow/snp-freq.cwl"
  ]
}
```

Pass it to Sapporo:

```yaml
# in compose.yml environment:
- SAPPORO_EXECUTABLE_WORKFLOWS=/app/executable_workflows.json
```

```yaml
# in compose.yml volumes:
- ./executable_workflows.json:/app/executable_workflows.json:ro
```

## 5. HTTPS (optional, recommended for production)

Use nginx + Let's Encrypt to terminate TLS in front of Sapporo:

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo certbot --nginx -d wes-jp.example.org
```

Nginx config (`/etc/nginx/sites-available/sapporo`):

```nginx
server {
    listen 443 ssl;
    server_name wes-jp.example.org;

    location / {
        proxy_pass http://127.0.0.1:1122;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 300;
    }
}
```

## 6. Verify end-to-end

From your local machine:

```bash
export SAPPORO_ENDPOINT=https://wes-jp.example.org
curl -s $SAPPORO_ENDPOINT/service-info | jq .workflow_engine_versions
curl -s $SAPPORO_ENDPOINT/executable-workflows | jq .
```
