from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import SessionLocal
import models, schemas
from auth import get_current_user, ensure_school_access

router = APIRouter(prefix="/ogrenciler", tags=["Ogrenciler"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally: 
        db.close()

# ----------- ÖĞRENCİ OLUŞTURMA -----------
@router.post("/", response_model=schemas.OgrenciCreate)
def create_ogrenci(
    ogr: schemas.OgrenciCreate,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    sinif = db.query(models.Sinif).filter(models.Sinif.id == ogr.sinif_id).first()
    if not sinif:
        raise HTTPException(status_code=404, detail="Sınıf bulunamadı")

    ensure_school_access(current_user, sinif.okul_id)

    if current_user.rol not in ("admin", "mudur"):
        raise HTTPException(status_code=403, detail="Bu işlem için yetkin yok")

    yeni = models.Ogrenci(**ogr.model_dump())
    db.add(yeni)
    db.commit()
    db.refresh(yeni)
    return yeni

# ----------- ÖĞRENCİ LİSTELEME ------------
@router.get("/", response_model=List[schemas.OgrenciResponse])
def list_ogrenciler(
    sinif_id: int,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    # sinif -> okul_id bul
    sinif = db.query(models.Sinif).filter(models.Sinif.id == sinif_id).first()
    if not sinif:
        raise HTTPException(status_code=404, detail="Sınıf bulunamadı")

    # admin/müdür okul kontrolü
    ensure_school_access(current_user, sinif.okul_id)

    # veli bu endpointi kullanmasın
    if current_user.rol == "veli":
        raise HTTPException(status_code=403, detail="Veli sınıf listesini göremez")

    return db.query(models.Ogrenci).filter(models.Ogrenci.sinif_id == sinif_id).all()

# ----------- ÖĞRENCİ SİLME -----------
@router.delete("/{ogrenci_id}")
def delete_ogrenci(
    ogrenci_id: int,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    # Öğrenciyi bul
    ogrenci = db.query(models.Ogrenci).filter(models.Ogrenci.id == ogrenci_id).first()
    if not ogrenci:
        raise HTTPException(status_code=404, detail="Öğrenci bulunamadı")

    # Sınıf -> Okul kontrolü
    sinif = db.query(models.Sinif).filter(models.Sinif.id == ogrenci.sinif_id).first()
    if not sinif:
        raise HTTPException(status_code=404, detail="Sınıf bulunamadı")

    ensure_school_access(current_user, sinif.okul_id)

    if current_user.rol not in ("admin", "mudur"):
        raise HTTPException(status_code=403, detail="Bu işlem için yetkin yok")

    # Önce sınav sonuçlarını sil
    db.query(models.SinavSonucu).filter(models.SinavSonucu.ogrenci_id == ogrenci_id).delete()

    # Öğrenciyi sil
    db.delete(ogrenci)
    db.commit()

    return {"success": True, "message": f"'{ogrenci.ad} {ogrenci.soyad}' öğrencisi ve tüm sonuçları silindi"}

# ----------- ÖĞRENCİ GÜNCELLEME -----------
@router.put("/{ogrenci_id}", response_model=schemas.OgrenciResponse)
def update_ogrenci(
    ogrenci_id: int,
    ogrenci_data: schemas.OgrenciCreate,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    # Öğrenciyi bul
    ogrenci = db.query(models.Ogrenci).filter(models.Ogrenci.id == ogrenci_id).first()
    if not ogrenci:
        raise HTTPException(status_code=404, detail="Öğrenci bulunamadı")

    # Sınıf -> Okul kontrolü
    sinif = db.query(models.Sinif).filter(models.Sinif.id == ogrenci.sinif_id).first()
    if not sinif:
        raise HTTPException(status_code=404, detail="Sınıf bulunamadı")

    ensure_school_access(current_user, sinif.okul_id)

    if current_user.rol not in ("admin", "mudur"):
        raise HTTPException(status_code=403, detail="Bu işlem için yetkin yok")

    # Yeni sınıf kontrolü
    yeni_sinif = db.query(models.Sinif).filter(models.Sinif.id == ogrenci_data.sinif_id).first()
    if not yeni_sinif:
        raise HTTPException(status_code=404, detail="Yeni sınıf bulunamadı")

    # Güncelle
    ogrenci.ad = ogrenci_data.ad
    ogrenci.soyad = ogrenci_data.soyad
    ogrenci.numara = ogrenci_data.numara
    ogrenci.sinif_id = ogrenci_data.sinif_id

    db.commit()
    db.refresh(ogrenci)

    return ogrenci