from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import SessionLocal
import models
import schemas

router = APIRouter(prefix="/istatistik", tags=["Istatistik"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/sinav-ozet/{sinav_id}", response_model=schemas.SinavOzetResponse)
def sinav_ozet(sinav_id: int, db: Session = Depends(get_db)):
    # Önce sınavı bul
    sinav = db.query(models.Sinav).filter(models.Sinav.id == sinav_id).first()
    if not sinav:
        raise HTTPException(status_code=404, detail="Sınav bulunamadı")

    # Sinif adı varsa ala
    sinif_adi = None
    if sinav.sinif_id is not None:
        sinif = db.query(models.Sinif).filter(models.Sinif.id == sinav.sinif_id).first()
        if sinif:
            sinif_adi = sinif.ad

    # Bu sınavın sonuçlarından istatistik hesapla
    istatistik = (
        db.query(
            func.avg(models.SinavSonucu.puan).label("ortalama"),
            func.max(models.SinavSonucu.puan).label("en_yuksek"),
            func.min(models.SinavSonucu.puan).label("en_dusuk"),
            func.count(models.SinavSonucu.id).label("ogrenci_sayisi"),
        )
        .filter(models.SinavSonucu.sinav_id == sinav_id)
        .one()
    )
    # Eğer hiç öğrenci girmediyse
    if istatistik.ogrenci_sayisi == 0:
        return schemas.SinavOzetResponse(
            sinav_id=sinav.id,
            sinav_adi=sinav.ad,
            sinif_adi=sinif_adi,
            ortalama=None,
            en_yuksek=None,
            en_dusuk=None,
            ogrenci_sayisi=0,
        )

    # Normal durumda dolu özet döndür
    return schemas.SinavOzetResponse(
        sinav_id=sinav.id,
        sinav_adi=sinav.ad,
        sinif_adi=sinif_adi,
        ortalama=float(istatistik.ortalama),
        en_yuksek=float(istatistik.en_yuksek),
        en_dusuk=float(istatistik.en_dusuk),
        ogrenci_sayisi=istatistik.ogrenci_sayisi,
    )
