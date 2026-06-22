# Sistem Manajemen Pesanan UMKM Berbasis VFlow

Sistem Manajemen Pesanan UMKM merupakan implementasi workflow automation menggunakan **VFlow Workflow Engine**, **VDICL Rule Engine**, dan **PostgreSQL** untuk mengelola proses transaksi UMKM mulai dari pembuatan pesanan hingga penyelesaian pesanan secara otomatis.

---

## Deskripsi Proyek

Proyek ini dibuat untuk mendemonstrasikan penerapan konsep:

* Workflow Orchestration menggunakan VFlow
* Business Rule Engine menggunakan VDICL
* Database Integration menggunakan PostgreSQL
* Event-driven Processing
* Audit Logging otomatis
* Otomasi proses bisnis UMKM

Sistem terdiri dari enam workflow utama yang saling terintegrasi.

---

## Arsitektur Sistem

```text
Kasir / Client
      │
      ▼
 VFlow Server
      │
      ├── Workflow 1 : Buka Keranjang
      ├── Workflow 2 : Validasi Stok
      ├── Workflow 3 : Kalkulasi Tagihan
      ├── Workflow 4 : Konfirmasi Pembayaran
      ├── Workflow 5 : Penyelesaian Pesanan
      └── Workflow 6 : Audit Log
      │
      ▼
 PostgreSQL Database
```

---

## Workflow yang Diimplementasikan

### Workflow 1 — Buka Keranjang

Endpoint:

```http
POST /umkm/pesanan/buka
```

Fungsi:

* Membuat pesanan baru
* Status awal `draft`
* Menyimpan pelanggan dan kasir

---

### Workflow 2 — Validasi Stok

Endpoint:

```http
POST /umkm/produk/validasi-stok
```

Fungsi:

* Memeriksa ketersediaan stok
* Mengembalikan informasi stok tersisa
* Menolak pesanan jika stok tidak cukup

---

### Workflow 3 — Kalkulasi Tagihan

Endpoint:

```http
POST /umkm/pesanan/kalkulasi-tagihan
```

Fungsi:

* Menjalankan Rule Engine VDICL
* Menghitung diskon
* Menghitung biaya admin
* Menghitung biaya pengiriman
* Menghasilkan total tagihan

Workflow ini juga memanggil Audit Log secara asynchronous (detached edge).

---

### Workflow 4 — Konfirmasi Pembayaran

Endpoint:

```http
POST /umkm/pesanan/konfirmasi-pembayaran
```

Fungsi:

* Validasi nominal pembayaran
* Menghitung kembalian
* Menentukan status pembayaran

---

### Workflow 5 — Penyelesaian Pesanan

Endpoint:

```http
POST /umkm/pesanan/selesaikan
```

Fungsi:

* Mengurangi stok produk
* Mengubah status pesanan menjadi selesai

---

### Workflow 6 — Audit Log

Endpoint:

```http
POST /umkm/internal/audit-log
```

Fungsi:

* Mencatat seluruh aktivitas transaksi
* Mendukung monitoring dan audit sistem

---

## Rule Engine VDICL

Rule pack:

```text
aturan_harga_umkm_v1
```

Rule yang digunakan:

### Diskon

| Kondisi           | Diskon |
| ----------------- | ------ |
| Reguler           | 0%     |
| Member            | 5%     |
| Grosir (≥20 item) | 10%    |

### Biaya Admin

| Metode   | Biaya   |
| -------- | ------- |
| Tunai    | Rp0     |
| QRIS     | 0.7%    |
| E-Wallet | Rp1.500 |
| Kartu    | 1.5%    |

### Biaya Pengiriman

| Metode              | Biaya    |
| ------------------- | -------- |
| Ambil Sendiri       | Rp0      |
| Instant             | Rp15.000 |
| Reguler < Rp200.000 | Rp8.000  |
| Reguler ≥ Rp200.000 | Gratis   |

---

## Struktur Repository

```text
.
├── db/
│   └── schema.sql
│
├── workflows/
│   ├── 01-buka-keranjang.yaml
│   ├── 02-validasi-stok.yaml
│   ├── 03-kalkulasi-tagihan.yaml
│   ├── 04-konfirmasi-pembayaran.yaml
│   ├── 05-penyelesaian-pesanan.yaml
│   └── 06-audit-log.yaml
│
├── rules/
│   └── aturan_harga_umkm_v1.vdicl
│
├── schemas/
│   └── harga_fact_v1.yaml
│
├── scripts/
│   └── vflow-admin.sh
│
├── test/
│   └── smoke-test.sh
│
├── README.md
└── SETUP.md
```

---

## Teknologi yang Digunakan

| Teknologi         | Fungsi                   |
| ----------------- | ------------------------ |
| VFlow             | Workflow Engine          |
| VDICL             | Rule Engine              |
| PostgreSQL        | Database                 |
| Cloudflare Tunnel | Expose PostgreSQL ke AWS |
| Curl              | API Testing              |
| jq                | JSON Processing          |
| Bash              | Automation Script        |

---

## Quick Start

Lihat panduan lengkap instalasi pada:

```text
SETUP.md
```

---

## Testing

Testing dapat dilakukan secara:

### Manual

Menggunakan:

```bash
curl
psql
jq
```


## Endpoint Server

```text
http://3.84.212.7:7799
```

---

## Checklist Validasi

* Health server aktif
* Rule pack berhasil di-compile
* Enam workflow aktif
* Semua endpoint merespons sesuai spesifikasi
* Audit log tercatat otomatis
* Stok berkurang saat pesanan selesai


