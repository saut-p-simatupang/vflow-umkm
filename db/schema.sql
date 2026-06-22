-- =============================================================
-- Skema PostgreSQL — Sistem Manajemen Pesanan UMKM Berbasis VFlow
-- WF1: buka-keranjang         → INSERT pesanan (draft)
-- WF2: validasi-stok          → SELECT produk
-- WF3: kalkulasi-tagihan      → VRule + detached audit
-- WF4: konfirmasi-pembayaran  → UPDATE pesanan (lunas)
-- WF5: penyelesaian-pesanan   → UPDATE stok + UPDATE pesanan (selesai)
-- WF6: audit-log              → INSERT audit_log
-- =============================================================

CREATE TYPE tipe_pelanggan_enum    AS ENUM ('reguler', 'member');
CREATE TYPE status_pesanan_enum    AS ENUM ('draft', 'lunas', 'selesai', 'batal');
CREATE TYPE metode_pembayaran_enum AS ENUM ('tunai', 'transfer', 'qris', 'kartu');
CREATE TYPE metode_pengambilan_enum AS ENUM ('ditempat', 'delivery');

-- ----------------------------
-- produk
-- Dibaca WF2 (cek stok), dikurangi WF5 (update stok)
-- ----------------------------
CREATE TABLE IF NOT EXISTS produk (
    id          SERIAL          PRIMARY KEY,
    nama        VARCHAR(150)    NOT NULL,
    harga       NUMERIC(14,2)   NOT NULL CHECK (harga >= 0),
    stok        INTEGER         NOT NULL CHECK (stok >= 0),
    aktif       BOOLEAN         NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ----------------------------
-- pelanggan
-- Dirujuk WF1 (pelanggan_id), tipe_pelanggan dipakai VRule WF3
-- ----------------------------
CREATE TABLE IF NOT EXISTS pelanggan (
    id              SERIAL                  PRIMARY KEY,
    nama            VARCHAR(150)            NOT NULL,
    tipe_pelanggan  tipe_pelanggan_enum     NOT NULL DEFAULT 'reguler',
    kontak          VARCHAR(100),
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT now()
);

-- ----------------------------
-- pesanan
-- Dibuat WF1 (draft) → WF4 (lunas) → WF5 (selesai)
-- ----------------------------
CREATE TABLE IF NOT EXISTS pesanan (
    id                  SERIAL                  PRIMARY KEY,
    pelanggan_id        INTEGER                 REFERENCES pelanggan(id),
    kasir_id            VARCHAR(50)             NOT NULL,
    status              status_pesanan_enum      NOT NULL DEFAULT 'draft',
    subtotal            NUMERIC(14,2)           NOT NULL DEFAULT 0,
    diskon              NUMERIC(14,2)           NOT NULL DEFAULT 0,
    biaya_admin         NUMERIC(14,2)           NOT NULL DEFAULT 0,
    biaya_pengiriman    NUMERIC(14,2)           NOT NULL DEFAULT 0,
    total_tagihan       NUMERIC(14,2)           NOT NULL DEFAULT 0,
    metode_pembayaran   metode_pembayaran_enum,
    metode_pengambilan  metode_pengambilan_enum,
    created_at          TIMESTAMPTZ             NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ             NOT NULL DEFAULT now()
);

-- ----------------------------
-- detail_pesanan
-- Diisi setelah WF2 lolos; dibaca WF5 untuk loop update stok
-- ----------------------------
CREATE TABLE IF NOT EXISTS detail_pesanan (
    id              SERIAL          PRIMARY KEY,
    pesanan_id      INTEGER         NOT NULL REFERENCES pesanan(id) ON DELETE CASCADE,
    produk_id       INTEGER         NOT NULL REFERENCES produk(id),
    jumlah          INTEGER         NOT NULL CHECK (jumlah > 0),
    harga_satuan    NUMERIC(14,2)   NOT NULL
);

-- ----------------------------
-- audit_log
-- Ditulis WF6 (fire-and-forget dari WF1/3/4/5)
-- pesanan_id VARCHAR bukan FK karena WF3 bisa kirim "unknown"
-- ----------------------------
CREATE TABLE IF NOT EXISTS audit_log (
    id              BIGSERIAL       PRIMARY KEY,
    pesanan_id      VARCHAR(50)     NOT NULL,
    aktor_id        VARCHAR(50)     NOT NULL,
    aktivitas_tipe  VARCHAR(50)     NOT NULL,
    payload_log     JSONB           NOT NULL,
    waktu_kejadian  TIMESTAMPTZ     NOT NULL,
    recorded_at     TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ----------------------------
-- konfigurasi_harga
-- Nilai bisnis untuk VRule WF3 (diskon, biaya admin, batas ongkir)
-- ----------------------------
CREATE TABLE IF NOT EXISTS konfigurasi_harga (
    id              SERIAL          PRIMARY KEY,
    kode            VARCHAR(50)     NOT NULL UNIQUE,
    nilai           NUMERIC(14,2)   NOT NULL,
    keterangan      TEXT,
    aktif           BOOLEAN         NOT NULL DEFAULT true,
    berlaku_mulai   TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ----------------------------
-- INDEX
-- ----------------------------
CREATE INDEX IF NOT EXISTS idx_pesanan_status          ON pesanan(status);
CREATE INDEX IF NOT EXISTS idx_pesanan_kasir_id        ON pesanan(kasir_id);
CREATE INDEX IF NOT EXISTS idx_pesanan_pelanggan_id    ON pesanan(pelanggan_id) WHERE pelanggan_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_detail_pesanan_pesanan_id ON detail_pesanan(pesanan_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_pesanan_id    ON audit_log(pesanan_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_waktu         ON audit_log(waktu_kejadian DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_aktivitas     ON audit_log(aktivitas_tipe);
CREATE INDEX IF NOT EXISTS idx_produk_aktif            ON produk(id) WHERE aktif = true;

-- ----------------------------
-- TRIGGER: auto-update updated_at
-- ----------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_produk_updated_at
    BEFORE UPDATE ON produk
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE TRIGGER trg_pesanan_updated_at
    BEFORE UPDATE ON pesanan
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ----------------------------
-- SEED DATA
-- ----------------------------
INSERT INTO produk (nama, harga, stok) VALUES
    ('Kopi Susu Gula Aren',  18000, 50),
    ('Roti Bakar Coklat',    15000, 30),
    ('Es Teh Manis',          5000, 100),
    ('Nasi Goreng Spesial',  25000, 20),
    ('Mie Ayam Bakso',       22000, 25)
ON CONFLICT DO NOTHING;

INSERT INTO pelanggan (nama, tipe_pelanggan, kontak) VALUES
    ('Pelanggan Umum', 'reguler', '081200000000'),
    ('Budi (Member)',  'member',  '081211112222'),
    ('Sari (Member)',  'member',  '081233334444')
ON CONFLICT DO NOTHING;

INSERT INTO konfigurasi_harga (kode, nilai, keterangan) VALUES
    ('MIN_GRATIS_KIRIM',     50000, 'Minimum subtotal agar biaya pengiriman = 0'),
    ('BIAYA_KIRIM_DEFAULT',   5000, 'Biaya pengiriman jika subtotal < MIN_GRATIS_KIRIM'),
    ('BIAYA_ADMIN_QRIS',      1500, 'Biaya admin metode QRIS'),
    ('BIAYA_ADMIN_KARTU',     2000, 'Biaya admin metode kartu debit/kredit'),
    ('DISKON_MEMBER_PCT',        5, 'Persentase diskon untuk pelanggan tipe member')
ON CONFLICT (kode) DO NOTHING;
