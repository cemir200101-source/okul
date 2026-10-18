from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import SessionLocal
import models
import schemas

router = APIRouter(prefix="/sonuclar", tags=["Sonuclar"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ----------- SONUÇ OLUŞTURMA ----------- 
@router.post("/", response_model=schemas.SinavSonucuResponse)
def create_sonuc(sonuc: schemas.SinavSonucuCreate, db: Session = Depends(get_db)):
    yeni_sonuc = models.SinavSonucu(
        ogrenci_id=sonuc.ogrenci_id,
        sinav_id=sonuc.sinav_id,
        puan=sonuc.puan
    )
    db.add(yeni_sonuc)
    db.commit()
    db.refresh(yeni_sonuc)
    return yeni_sonuc

# ----------- SONUÇ LİSTELEME -----------
@router.get("/", response_model=list[schemas.SinavSonucuResponse])
def list_sonuclar(db: Session = Depends(get_db)):
    sonuclar = db.query(models.SinavSonucu).all()
    return sonuclar

# ----------- ÖĞRENCİ SONUÇLARINI GÖRÜNTÜLEME -----------
@router.get("/ogrenci/{ogrenci_id}")
def get_student_results(ogrenci_id: int, db: Session = Depends(get_db)):
    # Öğrenci var mı kontrol
    ogrenci = db.query(models.Ogrenci).filter(models.Ogrenci.id == ogrenci_id).first()
    if not ogrenci:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Öğrenci bulunamadı.")

    q = (
        db.query(models.SinavSonucu, models.Sinav, models.Ders)
        .join(models.Sinav, models.SinavSonucu.sinav_id == models.Sinav.id)
        .outerjoin(models.Ders, models.Sinav.ders_id == models.Ders.id)
        .filter(models.SinavSonucu.ogrenci_id == ogrenci_id)
        .order_by(models.Sinav.tarih.desc())
    )

    results = []
    for sonuc, sinav, ders in q.all():
        results.append({
            "sinav_id": sinav.id,
            "sinav_adi": sinav.ad,
            "tarih": str(sinav.tarih) if sinav.tarih else None,
            "ders_adi": ders.ad if ders else None,
            "puan": sonuc.puan,
            "dogru": getattr(sonuc, "dogru", None),
            "yanlis": getattr(sonuc, "yanlis", None),
            "net": getattr(sonuc, "net", None),
            "sinif_sira": sonuc.sinif_sira,
            "okul_sira": sonuc.okul_sira,
            "ilce_sira": sonuc.ilce_sira,
            "il_sira": sonuc.il_sira,
            "genel_sira": sonuc.genel_sira,
        })

    return results
