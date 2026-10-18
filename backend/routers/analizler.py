from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import SessionLocal
import models

router = APIRouter(prefix="/analizler", tags=["Analizler"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ----------- OKUL GENELİ SINAVLAR -----------
@router.get("/okul/{okul_id}/sinavlar")
def get_school_exams(okul_id: int, db: Session = Depends(get_db)):
    """Bir okulda yapılan tüm sınavları listeler"""
    # Okulun sınıflarını al
    sinif_ids = db.query(models.Sinif.id).filter(models.Sinif.okul_id == okul_id).all()
    sinif_ids = [sid[0] for sid in sinif_ids]

    if not sinif_ids:
        return []

    # Bu sınıflardaki öğrencilerin katıldığı sınavları bul
    q = (
        db.query(models.Sinav, models.Ders)
        .join(models.SinavSonucu, models.Sinav.id == models.SinavSonucu.sinav_id)
        .join(models.Ogrenci, models.SinavSonucu.ogrenci_id == models.Ogrenci.id)
        .outerjoin(models.Ders, models.Sinav.ders_id == models.Ders.id)
        .filter(models.Ogrenci.sinif_id.in_(sinif_ids))
        .distinct()
        .order_by(models.Sinav.tarih.desc())
    )

    results = []
    seen_ids = set()
    for sinav, ders in q.all():
        if sinav.id not in seen_ids:
            seen_ids.add(sinav.id)
            results.append({
                "id": sinav.id,
                "ad": sinav.ad,
                "tarih": str(sinav.tarih) if sinav.tarih else None,
                "ders_adi": ders.ad if ders else None,
            })

    return results

# ----------- OKUL GENELİ SINAV ANALİZİ -----------
@router.get("/okul/{okul_id}/sinav/{sinav_id}")
def get_school_exam_analysis(okul_id: int, sinav_id: int, db: Session = Depends(get_db)):
    """Bir okulun belirli bir sınavdaki genel analizi"""
    # Okulun sınıflarını al
    sinif_ids = db.query(models.Sinif.id).filter(models.Sinif.okul_id == okul_id).all()
    sinif_ids = [sid[0] for sid in sinif_ids]

    if not sinif_ids:
        raise HTTPException(status_code=404, detail="Bu okula ait sınıf bulunamadı.")

    # Bu sınıflardaki öğrencilerin sınav sonuçlarını al
    q = (
        db.query(models.SinavSonucu, models.Ogrenci)
        .join(models.Ogrenci, models.SinavSonucu.ogrenci_id == models.Ogrenci.id)
        .filter(
            models.SinavSonucu.sinav_id == sinav_id,
            models.Ogrenci.sinif_id.in_(sinif_ids)
        )
    )

    sonuclar = []
    for sonuc, ogrenci in q.all():
        sonuclar.append({
            "ogrenci_id": ogrenci.id,
            "ad": ogrenci.ad,
            "soyad": ogrenci.soyad,
            "puan": sonuc.puan or 0.0,
        })

    if not sonuclar:
        return {
            "ortalama": 0.0,
            "en_yuksek": 0.0,
            "en_dusuk": 0.0,
            "ogrenci_sayisi": 0,
            "siralamalar": []
        }

    puanlar = [s["puan"] for s in sonuclar]
    ortalama = sum(puanlar) / len(puanlar)
    en_yuksek = max(puanlar)
    en_dusuk = min(puanlar)

    # Sıralama
    sonuclar_sorted = sorted(sonuclar, key=lambda x: x["puan"], reverse=True)

    return {
        "ortalama": ortalama,
        "en_yuksek": en_yuksek,
        "en_dusuk": en_dusuk,
        "ogrenci_sayisi": len(sonuclar),
        "siralamalar": sonuclar_sorted
    }

# ----------- SINIF BAZLI SINAVLAR -----------
@router.get("/sinif/{sinif_id}/sinavlar")
def get_class_exams(sinif_id: int, db: Session = Depends(get_db)):
    """Bir sınıftaki öğrencilerin katıldığı sınavları listeler"""
    # Sınıfın öğrencilerini al
    ogrenci_ids = db.query(models.Ogrenci.id).filter(models.Ogrenci.sinif_id == sinif_id).all()
    ogrenci_ids = [oid[0] for oid in ogrenci_ids]

    if not ogrenci_ids:
        return []

    # Bu öğrencilerin katıldığı sınavları bul
    q = (
        db.query(models.Sinav, models.Ders)
        .join(models.SinavSonucu, models.Sinav.id == models.SinavSonucu.sinav_id)
        .outerjoin(models.Ders, models.Sinav.ders_id == models.Ders.id)
        .filter(models.SinavSonucu.ogrenci_id.in_(ogrenci_ids))
        .distinct()
        .order_by(models.Sinav.tarih.desc())
    )

    results = []
    seen_ids = set()
    for sinav, ders in q.all():
        if sinav.id not in seen_ids:
            seen_ids.add(sinav.id)
            results.append({
                "id": sinav.id,
                "ad": sinav.ad,
                "tarih": str(sinav.tarih) if sinav.tarih else None,
                "ders_adi": ders.ad if ders else None,
            })

    return results

# ----------- SINIF BAZLI SINAV ANALİZİ -----------
@router.get("/sinif/{sinif_id}/sinav/{sinav_id}")
def get_class_exam_analysis(sinif_id: int, sinav_id: int, db: Session = Depends(get_db)):
    """Bir sınıfın belirli bir sınavdaki analizi"""
    # Sınıfın öğrencilerini al
    ogrenci_ids = db.query(models.Ogrenci.id).filter(models.Ogrenci.sinif_id == sinif_id).all()
    ogrenci_ids = [oid[0] for oid in ogrenci_ids]

    if not ogrenci_ids:
        raise HTTPException(status_code=404, detail="Bu sınıfa ait öğrenci bulunamadı.")

    # Bu öğrencilerin sınav sonuçlarını al
    q = (
        db.query(models.SinavSonucu, models.Ogrenci)
        .join(models.Ogrenci, models.SinavSonucu.ogrenci_id == models.Ogrenci.id)
        .filter(
            models.SinavSonucu.sinav_id == sinav_id,
            models.Ogrenci.id.in_(ogrenci_ids)
        )
    )

    sonuclar = []
    for sonuc, ogrenci in q.all():
        sonuclar.append({
            "ogrenci_id": ogrenci.id,
            "ad": ogrenci.ad,
            "soyad": ogrenci.soyad,
            "puan": sonuc.puan or 0.0,
        })

    if not sonuclar:
        return {
            "ortalama": 0.0,
            "en_yuksek": 0.0,
            "en_dusuk": 0.0,
            "ogrenci_sayisi": 0,
            "siralamalar": []
        }

    puanlar = [s["puan"] for s in sonuclar]
    ortalama = sum(puanlar) / len(puanlar)
    en_yuksek = max(puanlar)
    en_dusuk = min(puanlar)

    # Sıralama
    sonuclar_sorted = sorted(sonuclar, key=lambda x: x["puan"], reverse=True)

    return {
        "ortalama": ortalama,
        "en_yuksek": en_yuksek,
        "en_dusuk": en_dusuk,
        "ogrenci_sayisi": len(sonuclar),
        "siralamalar": sonuclar_sorted
    }

# ----------- OKUL GENELİ SINIF KARŞILAŞTIRMASI -----------
@router.get("/okul/{okul_id}/sinav/{sinav_id}/sinif-karsilastirma")
def get_school_exam_class_comparison(okul_id: int, sinav_id: int, db: Session = Depends(get_db)):
    """Bir okulun belirli bir sınavında sınıfların karşılaştırmalı analizi"""
    # Okulun sınıflarını al
    siniflar = db.query(models.Sinif).filter(models.Sinif.okul_id == okul_id).all()

    if not siniflar:
        raise HTTPException(status_code=404, detail="Bu okula ait sınıf bulunamadı.")

    sinif_istatistikleri = []

    for sinif in siniflar:
        # Bu sınıftaki öğrencilerin sınav sonuçlarını al
        q = (
            db.query(models.SinavSonucu)
            .join(models.Ogrenci, models.SinavSonucu.ogrenci_id == models.Ogrenci.id)
            .filter(
                models.SinavSonucu.sinav_id == sinav_id,
                models.Ogrenci.sinif_id == sinif.id
            )
        )

        sonuclar = q.all()

        if sonuclar:
            puanlar = [s.puan or 0.0 for s in sonuclar]
            ortalama = sum(puanlar) / len(puanlar)
            en_yuksek = max(puanlar)
            en_dusuk = min(puanlar)

            sinif_istatistikleri.append({
                "sinif_id": sinif.id,
                "sinif_adi": sinif.ad,
                "ortalama": ortalama,
                "en_yuksek": en_yuksek,
                "en_dusuk": en_dusuk,
                "ogrenci_sayisi": len(puanlar)
            })

    # Ortalamaya göre sırala
    sinif_istatistikleri.sort(key=lambda x: x["ortalama"], reverse=True)

    return {
        "siniflar": sinif_istatistikleri
    }

# ----------- OKUL GENELİ İSTATİSTİKLER -----------
@router.get("/okul/{okul_id}/istatistikler")
def get_school_statistics(okul_id: int, db: Session = Depends(get_db)):
    """Bir okulun genel istatistikleri"""
    # Okulun sınıflarını al
    siniflar = db.query(models.Sinif).filter(models.Sinif.okul_id == okul_id).all()

    if not siniflar:
        return {
            "toplam_sinif": 0,
            "toplam_ogrenci": 0,
            "toplam_sinav": 0,
            "ortalama_basari": 0.0,
            "en_basarili_sinif": None,
            "son_sinavlar": []
        }

    sinif_ids = [s.id for s in siniflar]

    # Toplam öğrenci sayısı
    toplam_ogrenci = db.query(models.Ogrenci).filter(
        models.Ogrenci.sinif_id.in_(sinif_ids)
    ).count()

    # Toplam sınav sayısı
    ogrenci_ids = db.query(models.Ogrenci.id).filter(
        models.Ogrenci.sinif_id.in_(sinif_ids)
    ).all()
    ogrenci_ids = [o[0] for o in ogrenci_ids]

    toplam_sinav = db.query(models.Sinav.id).join(
        models.SinavSonucu, models.Sinav.id == models.SinavSonucu.sinav_id
    ).filter(models.SinavSonucu.ogrenci_id.in_(ogrenci_ids)).distinct().count()

    # Ortalama başarı (tüm sınavların ortalaması)
    ortalama_sonuc = db.query(func.avg(models.SinavSonucu.puan)).join(
        models.Ogrenci, models.SinavSonucu.ogrenci_id == models.Ogrenci.id
    ).filter(models.Ogrenci.sinif_id.in_(sinif_ids)).scalar()

    ortalama_basari = float(ortalama_sonuc) if ortalama_sonuc else 0.0

    # En başarılı sınıf
    sinif_ortalamalari = []
    for sinif in siniflar:
        sinif_ogrencileri = db.query(models.Ogrenci.id).filter(
            models.Ogrenci.sinif_id == sinif.id
        ).all()
        sinif_ogrenci_ids = [o[0] for o in sinif_ogrencileri]

        if sinif_ogrenci_ids:
            sinif_ort = db.query(func.avg(models.SinavSonucu.puan)).filter(
                models.SinavSonucu.ogrenci_id.in_(sinif_ogrenci_ids)
            ).scalar()

            if sinif_ort:
                sinif_ortalamalari.append({
                    "sinif_id": sinif.id,
                    "sinif_adi": sinif.ad,
                    "ortalama": float(sinif_ort)
                })

    en_basarili_sinif = None
    if sinif_ortalamalari:
        sinif_ortalamalari.sort(key=lambda x: x["ortalama"], reverse=True)
        en_basarili_sinif = sinif_ortalamalari[0]

    # Son 5 sınav
    son_sinavlar = db.query(models.Sinav, models.Ders).join(
        models.SinavSonucu, models.Sinav.id == models.SinavSonucu.sinav_id
    ).outerjoin(
        models.Ders, models.Sinav.ders_id == models.Ders.id
    ).join(
        models.Ogrenci, models.SinavSonucu.ogrenci_id == models.Ogrenci.id
    ).filter(
        models.Ogrenci.sinif_id.in_(sinif_ids)
    ).distinct().order_by(models.Sinav.tarih.desc()).limit(5).all()

    son_sinavlar_list = []
    seen_ids = set()
    for sinav, ders in son_sinavlar:
        if sinav.id not in seen_ids:
            seen_ids.add(sinav.id)
            son_sinavlar_list.append({
                "id": sinav.id,
                "ad": sinav.ad,
                "tarih": str(sinav.tarih) if sinav.tarih else None,
                "ders_adi": ders.ad if ders else None
            })

    return {
        "toplam_sinif": len(siniflar),
        "toplam_ogrenci": toplam_ogrenci,
        "toplam_sinav": toplam_sinav,
        "ortalama_basari": round(ortalama_basari, 2),
        "en_basarili_sinif": en_basarili_sinif,
        "son_sinavlar": son_sinavlar_list
    }

# ----------- ÖĞRENCİ DERS BAZLI PERFORMANS ANALİZİ -----------
@router.get("/ogrenci/{ogrenci_id}/ders-performans")
def get_student_subject_performance(ogrenci_id: int, db: Session = Depends(get_db)):
    """Bir öğrencinin ders bazında performans analizi"""
    # Öğrenciyi kontrol et
    ogrenci = db.query(models.Ogrenci).filter(models.Ogrenci.id == ogrenci_id).first()
    if not ogrenci:
        raise HTTPException(status_code=404, detail="Öğrenci bulunamadı.")

    # Öğrencinin tüm sınav sonuçlarını derslerine göre grupla
    q = (
        db.query(models.SinavSonucu, models.Sinav, models.Ders)
        .join(models.Sinav, models.SinavSonucu.sinav_id == models.Sinav.id)
        .outerjoin(models.Ders, models.Sinav.ders_id == models.Ders.id)
        .filter(models.SinavSonucu.ogrenci_id == ogrenci_id)
        .order_by(models.Sinav.tarih.desc())
    )

    # Ders bazında sonuçları grupla
    ders_performans = {}

    for sonuc, sinav, ders in q.all():
        ders_adi = ders.ad if ders else "Genel"

        if ders_adi not in ders_performans:
            ders_performans[ders_adi] = {
                "ders_id": ders.id if ders else None,
                "ders_adi": ders_adi,
                "sinav_sayisi": 0,
                "toplam_puan": 0.0,
                "ortalama": 0.0,
                "en_yuksek": 0.0,
                "en_dusuk": 100.0,
                "sinavlar": []
            }

        puan = sonuc.puan or 0.0
        ders_performans[ders_adi]["sinav_sayisi"] += 1
        ders_performans[ders_adi]["toplam_puan"] += puan
        ders_performans[ders_adi]["sinavlar"].append({
            "sinav_id": sinav.id,
            "sinav_adi": sinav.ad,
            "puan": puan,
            "tarih": str(sinav.tarih) if sinav.tarih else None
        })

        if puan > ders_performans[ders_adi]["en_yuksek"]:
            ders_performans[ders_adi]["en_yuksek"] = puan
        if puan < ders_performans[ders_adi]["en_dusuk"]:
            ders_performans[ders_adi]["en_dusuk"] = puan

    # Ortalamaları hesapla
    for ders_adi in ders_performans:
        sinav_sayisi = ders_performans[ders_adi]["sinav_sayisi"]
        if sinav_sayisi > 0:
            ders_performans[ders_adi]["ortalama"] = ders_performans[ders_adi]["toplam_puan"] / sinav_sayisi

    # Liste olarak döndür (ortalamaya göre sıralı)
    ders_listesi = list(ders_performans.values())
    ders_listesi.sort(key=lambda x: x["ortalama"], reverse=True)

    return {
        "ogrenci_id": ogrenci_id,
        "ogrenci_adi": f"{ogrenci.ad} {ogrenci.soyad}",
        "dersler": ders_listesi
    }

# ----------- SINIF ÖĞRENCİ BAŞARI TRENDLERİ -----------
@router.get("/sinif/{sinif_id}/basari-trendleri")
def get_class_success_trends(sinif_id: int, db: Session = Depends(get_db)):
    """Bir sınıftaki öğrencilerin başarı trendleri"""
    # Sınıfı kontrol et
    sinif = db.query(models.Sinif).filter(models.Sinif.id == sinif_id).first()
    if not sinif:
        raise HTTPException(status_code=404, detail="Sınıf bulunamadı.")

    # Sınıftaki öğrencileri al
    ogrenciler = db.query(models.Ogrenci).filter(
        models.Ogrenci.sinif_id == sinif_id
    ).all()

    if not ogrenciler:
        return {
            "sinif_id": sinif_id,
            "sinif_adi": sinif.ad,
            "ogrenciler": []
        }

    ogrenci_trendleri = []

    for ogrenci in ogrenciler:
        # Öğrencinin tüm sınav sonuçlarını tarihe göre sıralı al
        sonuclar = db.query(models.SinavSonucu, models.Sinav).join(
            models.Sinav, models.SinavSonucu.sinav_id == models.Sinav.id
        ).filter(
            models.SinavSonucu.ogrenci_id == ogrenci.id,
            models.SinavSonucu.puan != None
        ).order_by(models.Sinav.tarih.asc()).all()

        if len(sonuclar) >= 2:  # En az 2 sınav olmalı trend için
            sinavlar = []
            puanlar = []

            for sonuc, sinav in sonuclar:
                sinavlar.append({
                    "sinav_id": sinav.id,
                    "sinav_adi": sinav.ad,
                    "tarih": str(sinav.tarih) if sinav.tarih else None,
                    "puan": sonuc.puan
                })
                puanlar.append(sonuc.puan)

            # Trend hesaplama (basit lineer: son - ilk)
            ilk_puan = puanlar[0]
            son_puan = puanlar[-1]
            trend = son_puan - ilk_puan
            ortalama = sum(puanlar) / len(puanlar)

            # Trend durumu
            if trend > 10:
                trend_durumu = "Yükselen"
            elif trend < -10:
                trend_durumu = "Düşen"
            else:
                trend_durumu = "Stabil"

            ogrenci_trendleri.append({
                "ogrenci_id": ogrenci.id,
                "ad": ogrenci.ad,
                "soyad": ogrenci.soyad,
                "sinav_sayisi": len(sonuclar),
                "ortalama": round(ortalama, 2),
                "ilk_puan": ilk_puan,
                "son_puan": son_puan,
                "trend": round(trend, 2),
                "trend_durumu": trend_durumu,
                "sinavlar": sinavlar
            })

    # Trend değerine göre sırala (en çok iyileşen önce)
    ogrenci_trendleri.sort(key=lambda x: x["trend"], reverse=True)

    return {
        "sinif_id": sinif_id,
        "sinif_adi": sinif.ad,
        "ogrenciler": ogrenci_trendleri
    }
