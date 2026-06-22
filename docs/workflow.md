# Dokumentasi Workflow

## Workflow 01 – Buka Keranjang

File:

```text
01-buka-keranjang.yaml
```

Tujuan:

* Membuat pesanan baru
* Menetapkan status draft

Input:

```json
{
  "pelanggan_id": "1",
  "kasir_id": "kasir01"
}
```

Output:

```json
{
  "pesanan_id": 1,
  "status": "draft"
}
```

---

## Workflow 02 – Validasi Stok

File:

```text
02-validasi-stok.yaml
```

Tujuan:

* Memastikan stok tersedia
* Menghindari overselling

Output:

```json
{
  "tersedia": true,
  "stok_sisa": 45
}
```

---

## Workflow 03 – Kalkulasi Tagihan

File:

```text
03-kalkulasi-tagihan.yaml
```

Tujuan:

* Menjalankan Rule Engine
* Menghitung total tagihan

Rule yang digunakan:

* Diskon
* Biaya Admin
* Biaya Pengiriman

Workflow ini juga memanggil Workflow Audit Log secara asynchronous.

---

## Workflow 04 – Konfirmasi Pembayaran

File:

```text
04-konfirmasi-pembayaran.yaml
```

Tujuan:

* Memvalidasi pembayaran
* Menghitung kembalian

---

## Workflow 05 – Penyelesaian Pesanan

File:

```text
05-penyelesaian-pesanan.yaml
```

Tujuan:

* Mengurangi stok produk
* Menandai pesanan selesai

---

## Workflow 06 – Audit Log

File:

```text
06-audit-log.yaml
```

Tujuan:

* Menyimpan aktivitas sistem
* Menyediakan jejak audit transaksi
