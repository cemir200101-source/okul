# routers/veli.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

import models, schemas
from auth import get_db, get_current_veli

router = APIRouter(prefix="/veli", tags=["Veli"])

@router.get("/sonuclarim", response_model=List[schemas.VeliSonucOut])
def get_sonuclarim(
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_veli),
):
    ogrenci_id = current_user.ogrenci_id

    # Öğrenci var mı kontrol
    ogrenci = db.query(models.Ogrenci).filter(models.Ogrenci.id == ogrenci_id).first()
    if not ogrenci:
        raise HTTPException(status_code=404, detail="Öğrenci bulunamadı.")

    q = (
        db.query(models.SinavSonucu, models.Sinav, models.Ders)
        .join(models.Sinav, models.SinavSonucu.sinav_id == models.Sinav.id)
        .join(models.Ders, models.Sinav.ders_id == models.Ders.id)
        .filter(models.SinavSonucu.ogrenci_id == ogrenci_id)
        .order_by(models.Sinav.tarih.desc())
    )

    results: list[schemas.VeliSonucOut] = []

    for sonuc, sinav, ders in q.all():
        item = schemas.VeliSonucOut(
            sinav_id=sinav.id,
            sinav_adi=sinav.ad,
            tarih=sinav.tarih,
            ders_adi=ders.ad if ders else None,
            puan=getattr(sonuc, "puan", None),
            dogru=getattr(sonuc, "dogru", None),
            yanlis=getattr(sonuc, "yanlis", None),
            net=getattr(sonuc, "net", None),
        )
        results.append(item)

    return results
