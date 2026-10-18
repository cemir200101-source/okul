from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import SessionLocal
import models
import schemas

router = APIRouter(prefix="/dersler", tags=["Dersler"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally: 
        db.close()

# ----------- DERS OLUŞTURMA -----------
@router.post("/", response_model=schemas.DersResponse)
def create_ders(ders: schemas.DersCreate, db: Session = Depends(get_db)):
    yeni_ders = models.Ders(
        ad=ders.ad,
        kod=ders.kod,
    )

    db.add(yeni_ders)
    db.commit()
    db.refresh(yeni_ders)
    return yeni_ders

# ----------- DERS LİSTELEME ------------
@router.get("/", response_model=list[schemas.DersResponse])
def list_dersler(db: Session = Depends(get_db)):
    dersler = db.query(models.Ders).all()
    return dersler