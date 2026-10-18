from pydantic import BaseModel
from datetime import date
from typing import Optional

# ====== OKUL ŞEMALARI ======
class OkulCreate(BaseModel):
    isim: str
    sehir: str | None = None
    ilce: str | None = None


class OkulResponse(BaseModel):
    id: int
    isim: str
    sehir: str | None = None
    ilce: str | None = None

    class Config:
        from_attributes = True # SQLAlchemy modellerinden otomatik dönüşüm için

# ====== SINIF ŞEMALARI ======
class SinifCreate(BaseModel):
    ad: str          # "7A", "8B" gibi
    seviye: int | None = None  # 7, 8, 9
    okul_id: int     # Hangi okula bağlı olduğunu bilmek için


class SinifResponse(BaseModel):
    id: int
    ad: str
    seviye: int | None = None
    okul_id: int

    class Config:
        from_attributes = True

# ====== ÖĞRENCİ ŞEMALARI ======
class OgrenciCreate(BaseModel):
    ad: str
    soyad: str
    numara: int | None = None
    sinif_id: int


class OgrenciResponse(BaseModel):
    id: int
    ad: str
    soyad: str
    numara: int | None = None
    sinif_id: int

    class Config:
        from_attributes = True

# ====== DERS ŞEMALARI ======
class DersCreate(BaseModel):
    ad: str                 #Örnek Matematik
    kod: str | None = None  #Örn Mat

class DersResponse(BaseModel):
    id: int
    ad:str
    kod: str | None = None

    class Config:
        from_attributes = True

# ====== SINAV ŞEMALARI ======
class SinavCreate(BaseModel):
    ad: str
    donem: str | None = None
    tarih: date | None = None
    ders_id: int
    sinif_id: int | None = None

class SinavResponse(BaseModel):
    id: int
    ad: str
    donem: str | None = None
    tarih: date | None = None
    ders_id: int
    sinif_id: int | None = None

    class Config:
        from_attributes = True

# ====== SINAV SONUCU ŞEMALARI ======
class SinavSonucuCreate(BaseModel):
    ogrenci_id: int
    sinav_id: int
    puan: float

class SinavSonucuResponse(BaseModel):
    id: int
    sinav_id: int
    ogrenci_id: int
    puan: float

    class Config:
        from_attributes = True

# ====== ISTATISTIK ŞEMALARI ======
class SinavOzetResponse(BaseModel):
    sinav_id: int
    sinav_adi: str
    sinif_adi: str | None = None
    ortalama: float | None = None
    en_yuksek: float | None = None
    en_dusuk: float | None = None
    ogrenci_sayisi: int

    class Config:
        from_attributes = True

# ====== KULLANICI ŞEMALARI ======
class KullaniciCreate(BaseModel):
    kullanici_adi: str
    email: str | None = None
    sifre: str
    rol: str   # "admin" / "mudur" / "ogretmen" / "veli"
    ogrenci_id: int | None = None
    okul_id: Optional[int] = None  # ogretmen için tek okul
    okul_ids: Optional[list[int]] = None  # mudur için birden fazla okul


class KullaniciResponse(BaseModel):
    id: int
    kullanici_adi: str
    email: str | None = None
    rol: str

    class Config:
        from_attributes = True

class VeliSonucOut(BaseModel):
    sinav_id: int
    sinav_adi: str
    tarih: date
    ders_adi: Optional[str] = None
    puan: Optional[float] = None
    dogru: Optional[float] = None
    yanlis: Optional[float] = None
    net: Optional[float] = None

    class Config:
        from_attributes = True


# ====== TOKEN ŞEMALARI ======
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    username: str
    role: str
    ogrenci_id: Optional[int] = None
    okul_id: Optional[int] = None
    okul_ids: Optional[list[int]] = None  # mudur için birden fazla okul


class TokenData(BaseModel):
    username: str | None = None
    rol: str | None = None


