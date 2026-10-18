"""Yayinevlerini veritabanina ekle"""
from database import SessionLocal
import models

def seed_publishers():
    db = SessionLocal()
    try:
        # TEK Yayinlari ekle
        tek = db.query(models.Yayinevi).filter(models.Yayinevi.ad == "TEK Yayinlari").first()
        if not tek:
            tek = models.Yayinevi(ad="TEK Yayinlari", kod="TEK", aktif=1)
            db.add(tek)
            print("OK TEK Yayinlari eklendi")
        else:
            print("- TEK Yayinlari zaten mevcut")

        # Bilfen ekle
        bilfen = db.query(models.Yayinevi).filter(models.Yayinevi.ad == "Bilfen").first()
        if not bilfen:
            bilfen = models.Yayinevi(ad="Bilfen", kod="BILFEN", aktif=1)
            db.add(bilfen)
            print("OK Bilfen eklendi")
        else:
            print("- Bilfen zaten mevcut")

        # Diger ekle
        diger = db.query(models.Yayinevi).filter(models.Yayinevi.ad == "Diger").first()
        if not diger:
            diger = models.Yayinevi(ad="Diger", kod="DIGER", aktif=1)
            db.add(diger)
            print("OK Diger eklendi")
        else:
            print("- Diger zaten mevcut")

        db.commit()
        print("\nOK Yayinevleri basariyla eklendi!")

        # Listeyi goster
        all_publishers = db.query(models.Yayinevi).all()
        print(f"\nToplam {len(all_publishers)} yayinevi:")
        for p in all_publishers:
            print(f"  - {p.ad} ({p.kod})")

    except Exception as e:
        print(f"Hata: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_publishers()
