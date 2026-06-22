# Arsitektur Sistem

## Gambaran Umum

Sistem Manajemen Pesanan UMKM dibangun menggunakan pendekatan workflow orchestration dengan VFlow sebagai workflow engine utama dan VDICL sebagai rule engine untuk pengambilan keputusan bisnis.

## Komponen Sistem

### Client

Client merupakan pengguna sistem yang terdiri dari:

* Kasir
* Admin
* Operator UMKM

Client mengakses sistem melalui HTTP Request.

### VFlow Server

VFlow Server bertugas untuk:

* Menjalankan workflow
* Menangani webhook endpoint
* Menjalankan node workflow
* Mengelola state proses

### Rule Engine (VDICL)

Rule Engine digunakan untuk:

* Perhitungan diskon
* Perhitungan biaya admin
* Perhitungan biaya pengiriman
* Validasi subtotal

### PostgreSQL

Database digunakan untuk menyimpan:

* Produk
* Pesanan
* Detail Pesanan
* Audit Log

## Diagram Arsitektur

```text
┌────────────────────┐
│      Client        │
│  Kasir / Admin     │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│    VFlow Server    │
└─────────┬──────────┘
          │
 ┌────────┴────────┐
 ▼                 ▼
Workflow Engine  Rule Engine
(VFlow)          (VDICL)
        │
        ▼
┌────────────────────┐
│     PostgreSQL     │
└────────────────────┘
```

## Alur Sistem

1. Client mengirim request.
2. Workflow menerima request.
3. Workflow membaca atau menulis data ke PostgreSQL.
4. Workflow memanggil Rule Engine jika diperlukan.
5. Workflow menghasilkan response.
6. Audit Log dicatat secara otomatis.
