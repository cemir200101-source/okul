from sqlalchemy import Column, Integer, String, ForeignKey, Float, Date, Table
from sqlalchemy.orm import relationship

from database import Base
import sqlalchemy as sa

# Müdür - Okul many-to-many ilişkisi için ara tablo
mudur_okul_association = Table(
    'mudur_okul',
    Base.metadata,
    Column('kullanici_id', Integer, ForeignKey('kullanicilar.id'), primary_key=True),
    Column('okul_id', Integer, ForeignKey('okullar.id'), primary_key=True)
)


class Okul(Base):
    __tablename__ = "okullar"

    id = Column(Integer, primary_key=True, index=True)
    isim = Column(String, nullable=False)
    sehir = Column(String, nullable=True)
    ilce = Column(String, nullable=True)

    siniflar = relationship("Sinif", back_populates="okul")
    kullanicilar = relationship("AdminUser", back_populates="okul")
    mudurler = relationship("AdminUser", secondary=mudur_okul_association, back_populates="okullar")


class Sinif(Base):
    __tablename__ = "siniflar"

    id = Column(Integer, primary_key=True, index=True)
    ad = Column(String, nullable=False)          # Örn: "7A"
    seviye = Column(Integer, nullable=True)      # Örn: 7
    okul_id = Column(Integer, ForeignKey("okullar.id"))

    okul = relationship("Okul", back_populates="siniflar")
    ogrenciler = relationship("Ogrenci", back_populates="sinif")
    sinavlar = relationship("Sinav", back_populates="sinif")


class Ogrenci(Base):
    __tablename__ = "ogrenciler"

    id = Column(Integer, primary_key=True, index=True)
    ad = Column(String, nullable=False)
    soyad = Column(String, nullable=False)
    numara = Column(Integer, nullable=False)

    sinif_id = Column(Integer, ForeignKey("siniflar.id"), nullable=False)
    sinif = relationship("Sinif", back_populates="ogrenciler")
    veliler = relationship("AdminUser", back_populates="ogrenci")

    sonuclar = relationship(
    "SinavSonucu",               
    back_populates="ogrenci",
    cascade="all, delete-orphan",
    )

    # >>> EK: Aynı sınıfta aynı numara bir kez olsun
    __table_args__ = (
        sa.UniqueConstraint("sinif_id", "numara", name="uix_sinif_ogrenci_numara"),
    )


class Yayinevi(Base):
    __tablename__ = "yayinevleri"

    id = Column(Integer, primary_key=True, index=True)
    ad = Column(String, nullable=False, unique=True)  # Örn: "TEK Yayınları", "Bilfen"
    kod = Column(String, nullable=True)  # Örn: "TEK", "BILFEN"
    aktif = Column(Integer, nullable=False, default=1)  # 1: aktif, 0: pasif


class Ders(Base):
    __tablename__ = "dersler"

    id = Column(Integer, primary_key=True, index=True)
    ad = Column(String, nullable=False)    # Örn: "Matematik"
    kod = Column(String, nullable=True)    # Örn: "MAT"

    sinavlar = relationship("Sinav", back_populates="ders")


class Sinav(Base):
    __tablename__ = "sinavlar"

    id = Column(Integer, primary_key=True, index=True)
    ad = Column(String, nullable=False)     # Örn: "1. Yazılı"
    tarih = Column(Date, nullable=True)
    donem = Column(String, nullable=True)   # Örn: "2024-2025 1. dönem"

    ders_id = Column(Integer, ForeignKey("dersler.id"))
    sinif_id = Column(Integer, ForeignKey("siniflar.id"), nullable=True)

    ders = relationship("Ders", back_populates="sinavlar")
    sinif = relationship("Sinif", back_populates="sinavlar")
    sonuclar = relationship("SinavSonucu", back_populates="sinav")


class SinavSonucu(Base):
    __tablename__ = "sinav_sonuclari"

    id = Column(Integer, primary_key=True, index=True)
    ogrenci_id = Column(Integer, ForeignKey("ogrenciler.id"))
    sinav_id = Column(Integer, ForeignKey("sinavlar.id"))
    puan = Column(Float, nullable=False)

    # Sıralama bilgileri
    sinif_sira = Column(Integer, nullable=True)
    okul_sira = Column(Integer, nullable=True)
    ilce_sira = Column(Integer, nullable=True)
    il_sira = Column(Integer, nullable=True)
    genel_sira = Column(Integer, nullable=True)

    ogrenci = relationship("Ogrenci", back_populates="sonuclar")
    sinav = relationship("Sinav", back_populates="sonuclar")


class AdminUser(Base):
    __tablename__ = "kullanicilar"

    id = Column(Integer, primary_key=True, index=True)
    kullanici_adi = Column(String, unique=True, index=True, nullable=False)
    sifre_hash = Column(String, nullable=False)

    email = Column(String, unique=True, index=True, nullable=True)

    # "admin", "mudur", "ogretmen", "veli"
    rol = Column(String, nullable=False, default="ogretmen")

    # Veli için: hangi öğrencinin velisi?
    ogrenci_id = Column(Integer, ForeignKey("ogrenciler.id"), nullable=True)
    ogrenci = relationship("Ogrenci", back_populates="veliler", lazy="joined")

    # Öğretmen için: hangi okul? (tek okul)
    okul_id = Column(Integer, ForeignKey("okullar.id"), nullable=True)
    okul = relationship("Okul", back_populates="kullanicilar", lazy="joined")

    # Müdür için: birden fazla okul (many-to-many)
    okullar = relationship("Okul", secondary=mudur_okul_association, back_populates="mudurler")