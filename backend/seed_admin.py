from database import SessionLocal, engine, Base
import models
from auth import get_password_hash

# Önce tabloları oluştur
Base.metadata.create_all(bind=engine)

db = SessionLocal()

# Admin kullanıcı kontrolü
var_mi = db.query(models.AdminUser).filter(models.AdminUser.rol=="admin").first()
if not var_mi:
    db.add(models.AdminUser(
        kullanici_adi="admin",
        sifre_hash=get_password_hash("1234"),
        rol="admin"
    ))

# Okul kontrolü
okul_var_mi = db.query(models.Okul).first()
if not okul_var_mi:
    db.add(models.Okul(
        isim="Sakarya Ortaokulu",
        sehir="Niğde",
        ilce="Merkez",
    ))

db.commit()
print("Seed tamamlandı: Admin ve okul eklendi")
db.close()
