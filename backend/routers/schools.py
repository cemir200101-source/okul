from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import SessionLocal
import models, schemas
from auth import get_current_user

router = APIRouter(prefix="/okullar", tags=["Okullar"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ----------- OKUL -----------------
@router.post("/", response_model=schemas.OkulCreate)
def create_okul(
    okul: schemas.OkulCreate,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),  # ← BURASI ÖNEMLİ
):
    yeni_okul = models.Okul(
        isim=okul.isim,
        sehir=okul.sehir,
        ilce=okul.ilce
    )
    db.add(yeni_okul)
    db.commit()
    db.refresh(yeni_okul)
    return yeni_okul


@router.get("/", response_model=list[schemas.OkulResponse])
def list_okullar(
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    if current_user.rol == "admin":
        return db.query(models.Okul).all()

    if current_user.rol == "mudur":
        okul = db.query(models.Okul).filter(models.Okul.id == current_user.okul_id).first()
        return [okul] if okul else []

    # veli okullar listesini görmesin
    raise HTTPException(status_code=403, detail="Bu işlem için yetkin yok.")

# ----------- OKUL SİLME -----------
@router.delete("/{okul_id}")
def delete_okul(
    okul_id: int,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    # Sadece admin silebilir
    if current_user.rol != "admin":
        raise HTTPException(status_code=403, detail="Sadece admin okul silebilir")

    # Okulu bul
    okul = db.query(models.Okul).filter(models.Okul.id == okul_id).first()
    if not okul:
        raise HTTPException(status_code=404, detail="Okul bulunamadı")

    # Önce sınıfları, öğrencileri ve sınavları sil (cascade)
    siniflar = db.query(models.Sinif).filter(models.Sinif.okul_id == okul_id).all()
    for sinif in siniflar:
        # Sınıftaki öğrencileri bul
        ogrenciler = db.query(models.Ogrenci).filter(models.Ogrenci.sinif_id == sinif.id).all()
        for ogrenci in ogrenciler:
            # Öğrencinin sınav sonuçlarını sil
            db.query(models.SinavSonucu).filter(models.SinavSonucu.ogrenci_id == ogrenci.id).delete()
            db.delete(ogrenci)

        # Sınıfın sınavlarını sil
        sinavlar = db.query(models.Sinav).filter(models.Sinav.sinif_id == sinif.id).all()
        for sinav in sinavlar:
            db.query(models.SinavSonucu).filter(models.SinavSonucu.sinav_id == sinav.id).delete()
            db.delete(sinav)

        db.delete(sinif)

    # Okulu sil
    db.delete(okul)
    db.commit()

    return {"success": True, "message": f"'{okul.isim}' okulu ve tüm verileri silindi"}

# ----------- OKUL GÜNCELLEME -----------
@router.put("/{okul_id}", response_model=schemas.OkulResponse)
def update_okul(
    okul_id: int,
    okul_data: schemas.OkulCreate,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    # Sadece admin güncelleyebilir
    if current_user.rol != "admin":
        raise HTTPException(status_code=403, detail="Sadece admin okul güncelleyebilir")

    # Okulu bul
    okul = db.query(models.Okul).filter(models.Okul.id == okul_id).first()
    if not okul:
        raise HTTPException(status_code=404, detail="Okul bulunamadı")

    # Güncelle
    okul.isim = okul_data.isim
    okul.sehir = okul_data.sehir
    okul.ilce = okul_data.ilce

    db.commit()
    db.refresh(okul)

    return okul

# ----------- OKUL DETAY -----------