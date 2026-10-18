from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from database import Base, engine, SessionLocal
import models
from routers import schools, classrooms, students, subjects, exams, results, stats, login, imports, veli, analizler, pdf_upload, publishers, exports
from starlette.middleware.base import BaseHTTPMiddleware

app = FastAPI(
    title="Okul Sınav Analiz API",
    description="Okul sınav verilerini analiz etmek için bir API",
    version="0.0.34"
)

# Ngrok middleware sınıfı (header eklemek için)
class NgrokMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["ngrok-skip-browser-warning"] = "true"
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "*"
        return response

# Middleware'ler - TERS SIRADA ÇALIŞIR (LIFO)
# İlk çalışacak olan EN SON eklenir
app.add_middleware(NgrokMiddleware)  # 2. çalışır (ngrok header ekler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Development: Tüm origin'lere izin
    allow_credentials=False,  # "*" ile True çalışmaz
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)  # 1. çalışır (CORS header ekler)

Base.metadata.create_all(bind=engine) #Tabloları veritabanında oluştur

app.include_router(schools.router)
app.include_router(classrooms.router)
app.include_router(students.router)
app.include_router(subjects.router)
app.include_router(exams.router)
app.include_router(results.router)
app.include_router(stats.router)
app.include_router(login.router)
app.include_router(imports.router)
app.include_router(veli.router)
app.include_router(analizler.router)
app.include_router(pdf_upload.router)
app.include_router(publishers.router)
app.include_router(exports.router)

#Her istek için DB session sağlayan helper fonksiyon
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def root():
    return {"message": "Okul Sınav Analiz API çalışıyor."}

@app.get("/health")
def health_check():
    return {"status": "ok"}

#Okulları listeleyecek endpoint taslağı
@app.get("/okullar")
def list_okullar(db: Session = Depends(get_db)): #fonksiyon çalıştırılırken veritabanı bağlantısının otomatik gelmesini sağlar.
    okullar = db.query(models.Okul).all() #SELECT * FROM okullar; ile aynı işlemi yapar (School tablosundaki tüm kayıtları getirir)
    return okullar