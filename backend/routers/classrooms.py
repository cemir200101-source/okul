from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import SessionLocal
import models
import schemas
from auth import get_current_user, ensure_school_access

router = APIRouter(prefix="/siniflar", tags=["Siniflar"])


# DB bağlantısı
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ----------- SINIF OLUŞTURMA -----------
@router.post("/", response_model=schemas.SinifResponse)
def create_sinif(
    sinif: schemas.SinifCreate, 
    db: Session = Depends(get_db), 
    current_user: models.AdminUser = Depends(get_current_user)
):
    # Burada gelen JSON -> SinifCreate -> models.Sinif'e çevriliyor
    yeni_sinif = models.Sinif(
        ad=sinif.ad,
        seviye=sinif.seviye,
        okul_id=sinif.okul_id,
    )

    db.add(yeni_sinif)    # Veritabanına eklenmek üzere işaretle
    db.commit()           # Kaydet
    db.refresh(yeni_sinif)  # Güncelle
    return yeni_sinif      # JSON olarak geri dön


# ----------- SINIF LİSTELEME -----------
@router.get("/", response_model=list[schemas.SinifResponse])
def list_siniflar(okul_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    ensure_school_access(current_user, okul_id)
    return db.query(models.Sinif).filter(models.Sinif.okul_id == okul_id).all()

# ----------- SINIF DETAY -----------