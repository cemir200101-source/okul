"""
Migration: Sınav sonuçlarına sıralama kolonları ekle

Bu script, sinav_sonuclari tablosuna sıralama bilgilerini ekler:
- sinif_sira (Sınıf sırası)
- okul_sira (Okul sırası)
- ilce_sira (İlçe sırası)
- il_sira (İl sırası)
- genel_sira (Genel sıra)

Kullanım:
    python migrations/add_ranking_columns.py
"""

import sys
import os

# Ana dizini sys.path'e ekle
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from database import SQLALCHEMY_DATABASE_URL

def run_migration():
    """Veritabanına sıralama kolonlarını ekler"""
    engine = create_engine(SQLALCHEMY_DATABASE_URL)

    with engine.connect() as conn:
        try:
            # SQLite için PRAGMA table_info kullan
            result = conn.execute(text("PRAGMA table_info(sinav_sonuclari)"))
            existing_columns = [row[1] for row in result]

            if all(col in existing_columns for col in ['sinif_sira', 'okul_sira', 'ilce_sira', 'il_sira', 'genel_sira']):
                print("OK - Tum siralama kolonlari zaten mevcut.")
                return

            print("Siralama kolonlari ekleniyor...")

            # Kolonları ekle
            columns_to_add = [
                ('sinif_sira', 'Sinif sirasi'),
                ('okul_sira', 'Okul sirasi'),
                ('ilce_sira', 'Ilce sirasi'),
                ('il_sira', 'Il sirasi'),
                ('genel_sira', 'Genel sira')
            ]

            for col_name, description in columns_to_add:
                if col_name not in existing_columns:
                    conn.execute(text(f"""
                        ALTER TABLE sinav_sonuclari
                        ADD COLUMN {col_name} INTEGER NULL
                    """))
                    conn.commit()
                    print(f"  OK - {col_name} kolonu eklendi ({description})")
                else:
                    print(f"  - {col_name} kolonu zaten mevcut")

            print("\nOK - Migration basariyla tamamlandi!")
            print("\nNot: Mevcut sinav sonuclari icin siralama bilgileri NULL olacak.")
            print("Yeni PDF yuklemelerinde siralama bilgileri otomatik olarak kaydedilecek.")

        except Exception as e:
            print(f"\nHATA: {e}")
            conn.rollback()
            raise

if __name__ == "__main__":
    print("=" * 60)
    print("SINAV SONUÇLARI SIRALAMA KOLONLARI MİGRATION")
    print("=" * 60)
    print()

    # Otomatik çalıştır
    run_migration()
