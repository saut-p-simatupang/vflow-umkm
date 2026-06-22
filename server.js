const express = require('express');
const cors = require('cors'); // <--- Tambahkan ini
const { Pool } = require('pg');

const app = express();
app.use(cors()); // <--- Tambahkan ini agar frontend diizinkan mengakses API
app.use(express.json());
app.use(express.static('public'));


// Konfigurasi Koneksi PostgreSQL
const pool = new Pool({
    user: 'postgres',         // Sesuaikan dengan user Anda
    host: 'localhost',
    database: 'umkm_db',    // Sesuaikan dengan nama DB Anda
    password: '12345678',     // Sesuaikan dengan password Anda
    port: 5432,
});

// ==========================================
// [vrule] ENJIN PERATURAN (Rules Engine)
// ==========================================
function evaluateVRule(tipePelanggan, subtotal) {
    let diskon = 0;
    let catatanRule = [];

    // Rule 1: Jika pelanggan adalah Member, dapat potongan 10%
    if (tipePelanggan === 'member') {
        diskon += subtotal * 0.10;
        catatanRule.push("Diskaun Member 10% Diterapkan");
    }

    // Rule 2: Jika belanja di atas RM100, tambahan potongan tetap RM5
    if (subtotal > 100) {
        diskon += 5;
        catatanRule.push("Bonus Belanja Besar Potongan RM5");
    }

    let totalAkhir = subtotal - diskon;
    if (totalAkhir < 0) totalAkhir = 0;

    return { diskon, totalAkhir, catatanRule };
}

// ==========================================
// [vflow & WORKFLOW] API UTAMA
// ==========================================

// 1. VFLOW: Ambil Senarai Produk Aktif untuk Juruwang
app.get('/api/produk', async (req, res) => {
    try {
        const result = await pool.query('SELECT id, nama, harga, stok FROM produk WHERE stok > 0');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 2. VFLOW & VRULE: Proses Pembuatan Pesanan Baru (Fasa Workflow: 'lunas')
app.post('/api/pesanan', async (req, res) => {
    const { pelanggan_id, tipe_pelanggan, kasir_id, items } = req.body;

    // Hitung subtotal awal berdasarkan item yang dikirim frontend
    let subtotal = 0;
    items.forEach(item => {
        subtotal += parseFloat(item.harga_satuan) * parseInt(item.jumlah);
    });

    // Jalankan vrule untuk mendapatkan nilai diskon dan total akhir
    const ruleResult = evaluateVRule(tipe_pelanggan, subtotal);

    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // Insert ke tabel `pesanan`
        const pesananQuery = `
            INSERT INTO pesanan (pelanggan_id, kasir_id, status, subtotal, diskon, total, catatan)
            VALUES ($1, $2, 'lunas', $3, $4, $5, $6)
            RETURNING id, status, total, diskon, catatan;
        `;
        const catatanString = ruleResult.catatanRule.join(', ') || 'Pesanan Reguler';
        const pesananRes = await client.query(pesananQuery, [
            pelanggan_id || null,
            kasir_id,
            subtotal,
            ruleResult.diskon,
            ruleResult.totalAkhir,
            catatanString
        ]);

        const newPesananId = pesananRes.rows[0].id;

        // Loop untuk masukkan ke `detail_pesanan` & Potong Stok Produk
        for (let item of items) {
            // Insert detail
            await client.query(`
                INSERT INTO detail_pesanan (pesanan_id, produk_id, jumlah, harga_satuan)
                VALUES ($1, $2, $3, $4)
            `, [newPesananId, item.produk_id, item.jumlah, item.harga_satuan]);

            // Potong stok di tabel produk
            await client.query(`
                UPDATE produk SET stok = stok - $1 WHERE id = $2
            `, [item.jumlah, item.produk_id]);
        }

        // AUTOMATION: Catat ke `audit_log` sebagai bukti VFlow berhasil memproses data
        const auditQuery = `
            INSERT INTO audit_log (pesanan_id, aktor_id, aktivitas_tipe, payload_log, waktu_kejadian)
            VALUES ($1, $2, $3, $4, NOW())
        `;
        const payload = {
            subtotal,
            diskon_diterapkan: ruleResult.diskon,
            total_akhir: ruleResult.totalAkhir,
            jumlah_item: items.length
        };
        await client.query(auditQuery, [newPesananId.toString(), kasir_id, 'BUAT_PESANAN_LUNAS', JSON.stringify(payload)]);

        await client.query('COMMIT');
        res.status(201).json(pesananRes.rows[0]);

    } catch (err) {
        await client.query('ROLLBACK');
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
});

// 3. WORKFLOW MONITOR DAPUR: Ambil semua pesanan bertatus 'lunas' untuk diproses masak
app.get('/api/workflow/dapur', async (req, res) => {
    try {
        const queryText = `
            SELECT p.id, p.catatan, p.status, array_to_json(array_agg(dp)) as detail
            FROM pesanan p
            JOIN (
                SELECT detail_pesanan.pesanan_id, pr.nama, detail_pesanan.jumlah 
                FROM detail_pesanan 
                JOIN produk pr ON detail_pesanan.produk_id = pr.id
            ) dp ON p.id = dp.pesanan_id
            WHERE p.status = 'lunas'
            GROUP BY p.id;
        `;
        const result = await pool.query(queryText);
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 4. WORKFLOW PERUBAHAN STATUS: Selesaikan makanan ('lunas' -> 'selesai')
app.patch('/api/workflow/pesanan/:id/selesai', async (req, res) => {
    const pesananId = req.params.id;
    try {
        await pool.query("UPDATE pesanan SET status = 'selesai', updated_at = NOW() WHERE id = $1", [pesananId]);

        // Catat perubahan fasa workflow ke audit_log
        await pool.query(`
            INSERT INTO audit_log (pesanan_id, aktor_id, aktivitas_tipe, payload_log, waktu_kejadian)
            VALUES ($1, 'Koki_Dapur', 'WORKFLOW_SELESAI_MASAK', '{"status_baru": "selesai"}', NOW())
        `, [pesananId]);

        res.json({ message: `Pesanan #${pesananId} selesai dimasak dan diserahkan ke pelanggan.` });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.listen(3000, () => console.log('Backend UMKM VFlow berjalan di port 3000'));