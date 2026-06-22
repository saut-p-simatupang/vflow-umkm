# Setup dan Pengujian Sistem UMKM VFlow

Dokumen ini menjelaskan langkah lengkap instalasi, konfigurasi, provisioning workflow, dan pengujian Sistem Manajemen Pesanan UMKM berbasis VFlow.

---

# Prasyarat

Pastikan perangkat telah memiliki:

| Software    | Keterangan                 |
| ----------- | -------------------------- |
| PostgreSQL  | Database utama             |
| Node.js     | Menjalankan utilitas VFlow |
| Cloudflared | Tunnel database ke AWS     |
| Git         | Version Control            |
| Curl        | Pengujian API              |
| jq          | Parsing JSON               |

Verifikasi instalasi:

```bash
node -v
psql --version
curl --version
jq --version
cloudflared --version
```

---

# 1. Persiapan Database PostgreSQL

## 1.1 Login PostgreSQL

```bash
psql -U postgres
```

## 1.2 Membuat Database

```sql
CREATE DATABASE umkm_db;
```

Keluar dari PostgreSQL:

```sql
\q
```

## 1.3 Import Schema

```bash
psql "postgresql://postgres:PASSWORD@127.0.0.1:5432/umkm_db" -f db/schema.sql
```

## 1.4 Verifikasi Data Produk

```bash
psql "postgresql://postgres:PASSWORD@127.0.0.1:5432/umkm_db" \
-c "select id,nama,stok from produk;"
```

Output yang diharapkan:

```text
1 | Kopi Susu Gula Aren | 50
2 | Roti Bakar Coklat   | 30
3 | Es Teh Manis        | 100
```

---

# 2. Setup Cloudflare Tunnel

Cloudflare Tunnel digunakan agar PostgreSQL lokal dapat diakses oleh VFlow Server yang berjalan di AWS.

## 2.1 Login Cloudflare

```bash
cloudflared tunnel login
```

Browser akan terbuka untuk autentikasi.

---

## 2.2 Membuat Tunnel

```bash
cloudflared tunnel create vflow-kelompok3
```

Contoh output:

```text
Created tunnel vflow-kelompok3
with id 4226573c-ba64-4e49-b369-79c75eb5a647
```

Catat Tunnel ID tersebut.

---

## 2.3 Daftarkan DNS

```bash
cloudflared tunnel route dns \
vflow-kelompok3 \
workflow-db.kelompok3.vflow.domainanda.com
```

---

## 2.4 Buat File Konfigurasi

File:

```text
~/.cloudflared/vflow-kelompok3.yml
```

Isi:

```yaml
tunnel: TUNNEL_ID

credentials-file: ~/.cloudflared/TUNNEL_ID.json

ingress:
  - hostname: workflow-db.kelompok3.vflow.domainanda.com
    service: tcp://127.0.0.1:5432

  - service: http_status:404
```

---

## 2.5 Jalankan Tunnel

```bash
cloudflared tunnel \
--config ~/.cloudflared/vflow-kelompok3.yml \
run vflow-kelompok3
```

Jika berhasil:

```text
Connection 1 registered
Connection 2 registered
Connection 3 registered
Connection 4 registered
Environment is healthy
```

Jangan tutup terminal ini.

---

# 3. Konfigurasi VFlow Server

Masuk ke repository:

```bash
cd vflow-test-main
```

Set environment:

```bash
export VFLOW_BASE_URL="http://3.84.212.7:7799"
export VFLOW_TENANT="_default"
```

---

## 3.1 Health Check

```bash
curl -sS "$VFLOW_BASE_URL/health"
```

Output:

```json
{
  "status":"healthy"
}
```

---

## 3.2 Cek Overview

```bash
curl -sS "$VFLOW_BASE_URL/_vflow/api/overview"
```

---

# 4. Compile Rule Pack

Pastikan file tersedia:

```bash
rules/aturan_harga_umkm_v1.vdicl

schemas/harga_fact_v1.yaml
```

Compile:

```bash
jq -n \
  --rawfile r rules/aturan_harga_umkm_v1.vdicl \
  --rawfile s schemas/harga_fact_v1.yaml \
  '{
      rule_set_id:"aturan_harga_umkm_v1",
      rules_yaml:$r,
      schema_yaml:$s
   }' \
| curl -sS \
  -X POST \
  -H "Content-Type: application/json" \
  -d @- \
  "$VFLOW_BASE_URL/api/admin/vrule/compile"
```

Output:

```json
{
  "rule_set_id":"aturan_harga_umkm_v1",
  "loaded_at":1782108608885
}
```

---

## Verifikasi Rule

```bash
curl -sS "$VFLOW_BASE_URL/api/admin/vrules"
```

Pastikan terdapat:

```text
aturan_harga_umkm_v1
```

---

# 5. Provision Workflow

Upload seluruh workflow:

```bash
for f in workflows/*.yaml
do
  echo "Uploading $f"

  curl -sS \
    -X POST \
    -H "Content-Type: application/yaml" \
    -H "X-Tenant-Id: _default" \
    --data-binary @"$f" \
    "$VFLOW_BASE_URL/api/admin/workflow/upload"

  echo ""
done
```

---

## Verifikasi Workflow

```bash
curl -sS \
"$VFLOW_BASE_URL/_vflow/api/workflows?tenant=_default"
```

Harus muncul:

```text
count : 6
active : true
```

untuk seluruh workflow.

---

# 6. Pengujian Workflow

## Workflow 1 – Buka Keranjang

```bash
curl -X POST \
"$VFLOW_BASE_URL/umkm/pesanan/buka" \
-H "Content-Type: application/json" \
-d '{
      "pelanggan_id":"1",
      "kasir_id":"kasir01"
    }'
```

---

## Workflow 2 – Validasi Stok

```bash
curl -X POST \
"$VFLOW_BASE_URL/umkm/produk/validasi-stok" \
-H "Content-Type: application/json" \
-d '{
      "pesanan_id":"1",
      "produk_id":"1",
      "jumlah":5
    }'
```

---

## Workflow 3 – Kalkulasi Tagihan

```bash
curl -X POST \
"$VFLOW_BASE_URL/umkm/pesanan/kalkulasi-tagihan" \
-H "Content-Type: application/json" \
-d '{
      "subtotal":100000,
      "total_item":3,
      "tipe_pelanggan":"member",
      "metode_pembayaran":"qris",
      "metode_pengambilan":"ambil_sendiri"
    }'
```

---

## Workflow 4 – Konfirmasi Pembayaran

```bash
curl -X POST \
"$VFLOW_BASE_URL/umkm/pesanan/konfirmasi-pembayaran" \
-H "Content-Type: application/json" \
-d '{
      "pesanan_id":"1",
      "total_tagihan":95700,
      "nominal_dibayar":100000
    }'
```

---

## Workflow 5 – Penyelesaian Pesanan

```bash
curl -X POST \
"$VFLOW_BASE_URL/umkm/pesanan/selesaikan" \
-H "Content-Type: application/json" \
-d '{
      "pesanan_id":"1"
    }'
```

---

## Workflow 6 – Audit Log

```bash
curl -X POST \
"$VFLOW_BASE_URL/umkm/internal/audit-log" \
-H "Content-Type: application/json" \
-d '{
      "pesanan_id":"1",
      "aktor_id":"kasir01",
      "aktivitas_tipe":"TEST_MANUAL"
    }'
```

---

# 7. Smoke Test

Jalankan pengujian otomatis:

```bash
export VFLOW_BASE_URL="http://3.84.212.7:7799"

export DSN="postgresql://postgres:PASSWORD@127.0.0.1:5432/umkm_db"

bash test/smoke-test.sh
```

Output:

```text
PASS
PASS
PASS
PASS
PASS
```

---

# 8. Troubleshooting

## Password PostgreSQL Salah

Masuk ke PostgreSQL:

```bash
psql -U postgres
```

Ubah password:

```sql
ALTER USER postgres
WITH PASSWORD '12345678';
```

---

## Workflow Tidak Ditemukan

Pastikan workflow sudah di-upload:

```bash
curl "$VFLOW_BASE_URL/_vflow/api/workflows"
```

---

## Rule Pack Tidak Ditemukan

Periksa daftar rule:

```bash
curl "$VFLOW_BASE_URL/api/admin/vrules"
```

---

## Error Database

Pastikan schema sudah diimport:

```bash
psql \
"postgresql://postgres:PASSWORD@127.0.0.1:5432/umkm_db"
```

Lalu cek:

```sql
SELECT * FROM produk;
```

---

# 9. Checklist Sebelum Demo

* [ ] PostgreSQL berjalan
* [ ] Cloudflare Tunnel aktif
* [ ] Health Check berhasil
* [ ] Rule Pack berhasil di-compile
* [ ] Enam workflow aktif
* [ ] Workflow 1–6 berhasil diuji
* [ ] Audit Log tersimpan
* [ ] Stok produk berkurang setelah pesanan selesai
* [ ] Smoke Test PASS seluruhnya

Jika seluruh checklist terpenuhi, sistem siap digunakan dan dipresentasikan.
