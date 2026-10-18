from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import SessionLocal
import models
import schemas
from auth import get_current_user

router = APIRouter(prefix="/sinavlar", tags=["Sinavlar"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ----------- SINAV OLUŞTURMA -----------
@router.post("/", response_model=schemas.SinavResponse)

def create_sinav(
    sinav: schemas.SinavCreate,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    yeni_sinav = models.Sinav(
        ad=sinav.ad,
        donem=sinav.donem,
        tarih=sinav.tarih,
        ders_id=sinav.ders_id,
        sinif_id=sinav.sinif_id
    )
    db.add(yeni_sinav)
    db.commit()
    db.refresh(yeni_sinav)
    return yeni_sinav

# ----------- SINAV LİSTELEME -----------
@router.get("/", response_model=list[schemas.SinavResponse])
def list_sinavlar(db: Session = Depends(get_db)):
    sinavlar = db.query(models.Sinav).all()
    return sinavlar

# ----------- SINAV SİLME -----------
@router.delete("/{sinav_id}")
def delete_sinav(
    sinav_id: int,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    from fastapi import HTTPException

    # Sınavı bul
    sinav = db.query(models.Sinav).filter(models.Sinav.id == sinav_id).first()
    if not sinav:
        raise HTTPException(status_code=404, detail="Sınav bulunamadı")

    # Önce sınav sonuçlarını sil
    db.query(models.SinavSonucu).filter(models.SinavSonucu.sinav_id == sinav_id).delete()

    # Sınavı sil
    db.delete(sinav)
    db.commit()

    return {"success": True, "message": f"'{sinav.ad}' sınavı ve tüm sonuçları silindi"}

# ----------- SINAV GÜNCELLEME -----------
@router.put("/{sinav_id}", response_model=schemas.SinavResponse)
def update_sinav(
    sinav_id: int,
    sinav_data: schemas.SinavCreate,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    from fastapi import HTTPException

    # Sınavı bul
    sinav = db.query(models.Sinav).filter(models.Sinav.id == sinav_id).first()
    if not sinav:
        raise HTTPException(status_code=404, detail="Sınav bulunamadı")

    # Güncelle
    sinav.ad = sinav_data.ad
    sinav.tarih = sinav_data.tarih
    sinav.donem = sinav_data.donem
    sinav.ders_id = sinav_data.ders_id
    sinav.sinif_id = sinav_data.sinif_id

    db.commit()
    db.refresh(sinav)

    return sinav