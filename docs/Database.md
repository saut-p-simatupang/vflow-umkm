# Dokumentasi Database

## Tabel Produk

Digunakan untuk menyimpan data produk yang dijual.

| Kolom      | Tipe      | Keterangan      |
| ---------- | --------- | --------------- |
| id         | bigint    | Primary Key     |
| nama       | varchar   | Nama Produk     |
| harga      | numeric   | Harga Produk    |
| stok       | integer   | Stok Tersedia   |
| created_at | timestamp | Waktu Pembuatan |

---

## Tabel Pesanan

Menyimpan transaksi utama.

| Kolom            | Tipe      |
| ---------------- | --------- |
| id               | bigint    |
| pelanggan_id     | varchar   |
| kasir_id         | varchar   |
| status           | varchar   |
| subtotal         | numeric   |
| diskon           | numeric   |
| biaya_admin      | numeric   |
| biaya_pengiriman | numeric   |
| total_tagihan    | numeric   |
| created_at       | timestamp |

---

## Tabel Detail Pesanan

Menyimpan item yang dibeli.

| Kolom        | Tipe    |
| ------------ | ------- |
| id           | bigint  |
| pesanan_id   | bigint  |
| produk_id    | bigint  |
| jumlah       | integer |
| harga_satuan | numeric |

---

## Tabel Audit Log

Digunakan untuk pencatatan aktivitas sistem.

| Kolom          | Tipe      |
| -------------- | --------- |
| id             | bigint    |
| pesanan_id     | bigint    |
| aktor_id       | varchar   |
| aktivitas_tipe | varchar   |
| payload_log    | jsonb     |
| waktu_kejadian | timestamp |

---

## Relasi Tabel

```text
produk
   │
   │
   ▼
detail_pesanan
   ▲
   │
pesanan

pesanan
   │
   ▼
audit_log
```
