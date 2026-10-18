from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel

from database import SessionLocal
import models


router = APIRouter(prefix="/yayinevleri", tags=["Yayınevleri"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class YayineviCreate(BaseModel):
    ad: str
    kod: str = None


class YayineviResponse(BaseModel):
    id: int
    ad: str
    kod: str | None = None
    aktif: int

    class Config:
        from_attributes = True


@router.get("/", response_model=List[YayineviResponse])
def list_yayinevleri(db: Session = Depends(get_db)):
    """Tüm yayınevlerini listele (sadece aktif olanlar)"""
    yayinevleri = db.query(models.Yayinevi).filter(models.Yayinevi.aktif == 1).all()
    return yayinevleri


@router.post("/", response_model=YayineviResponse)
def create_yayinevi(yayinevi: YayineviCreate, db: Session = Depends(get_db)):
    """Yeni yayınevi ekle"""
    # Aynı isimde yayınevi var mı kontrol et
    existing = db.query(models.Yayinevi).filter(models.Yayinevi.ad == yayinevi.ad).first()
    if existing:
        raise HTTPException(status_code=400, detail="Bu yayınevi zaten mevcut")

    new_yayinevi = models.Yayinevi(
        ad=yayinevi.ad,
        kod=yayinevi.kod,
        aktif=1
    )
    db.add(new_yayinevi)
    db.commit()
    db.refresh(new_yayinevi)
    return new_yayinevi


@router.get("/{yayinevi_id}", response_model=YayineviResponse)
def get_yayinevi(yayinevi_id: int, db: Session = Depends(get_db)):
    """Belirli bir yayınevini getir"""
    yayinevi = db.query(models.Yayinevi).filter(models.Yayinevi.id == yayinevi_id).first()
    if not yayinevi:
        raise HTTPException(status_code=404, detail="Yayınevi bulunamadı")
    return yayinevi


@router.delete("/{yayinevi_id}")
def delete_yayinevi(yayinevi_id: int, db: Session = Depends(get_db)):
    """Yayınevini pasif yap (soft delete)"""
    yayinevi = db.query(models.Yayinevi).filter(models.Yayinevi.id == yayinevi_id).first()
    if not yayinevi:
        raise HTTPException(status_code=404, detail="Yayınevi bulunamadı")

    yayinevi.aktif = 0
    db.commit()
    return {"success": True, "message": "Yayınevi pasif yapıldı"}
