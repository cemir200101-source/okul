"""
Migration script: Müdürlerin birden fazla okula sahip olabilmesi için
mevcut okul_id verilerini yeni mudur_okul tablosuna taşır.
"""

import sqlite3
from pathlib import Path

def migrate():
    db_path = Path(__file__).parent / "school_analytics.db"

    if not db_path.exists():
        print("Veritabanı bulunamadı. İlk kez çalıştırılıyor, migration gerekli değil.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        # 1. mudur_okul tablosu var mı kontrol et
        cursor.execute("""
            SELECT name FROM sqlite_master
            WHERE type='table' AND name='mudur_okul'
        """)

        if cursor.fetchone() is None:
            print("mudur_okul tablosu oluşturuluyor...")

            # 2. mudur_okul tablosunu oluştur
            cursor.execute("""
                CREATE TABLE mudur_okul (
                    kullanici_id INTEGER NOT NULL,
                    okul_id INTEGER NOT NULL,
                    PRIMARY KEY (kullanici_id, okul_id),
                    FOREIGN KEY (kullanici_id) REFERENCES kullanicilar(id),
                    FOREIGN KEY (okul_id) REFERENCES okullar(id)
                )
            """)

            # 3. Mevcut müdürlerin okul_id verilerini mudur_okul tablosuna taşı
            cursor.execute("""
                INSERT INTO mudur_okul (kullanici_id, okul_id)
                SELECT id, okul_id
                FROM kullanicilar
                WHERE rol = 'mudur' AND okul_id IS NOT NULL
            """)

            rows_migrated = cursor.rowcount
            conn.commit()

            print(f"[OK] Migration basarili! {rows_migrated} mudur-okul iliskisi tasindi.")
        else:
            print("mudur_okul tablosu zaten mevcut. Migration atlanıyor.")

    except Exception as e:
        conn.rollback()
        print(f"[HATA] Migration hatasi: {e}")
        raise

    finally:
        conn.close()

if __name__ == "__main__":
    migrate()
