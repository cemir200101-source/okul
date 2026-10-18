from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from sqlalchemy.orm import Session
from typing import List, Dict, Any, Optional
import pdfplumber
import re
import io
from datetime import date
import os

from database import SessionLocal
import models

router = APIRouter(prefix="/pdf", tags=["PDF Upload"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def parse_net_value(text):
    """Net değerini parse et (örn: '18,67' -> 18.67)"""
    if not text or text.strip() == '':
        return 0.0
    try:
        # Virgülü noktaya çevir ve float'a dönüştür
        return float(str(text).replace(',', '.'))
    except:
        return 0.0

def parse_integer(text):
    """Tam sayıyı parse et"""
    if not text or text.strip() == '':
        return 0
    try:
        return int(text)
    except:
        return 0

@router.post("/sinav-sonucu-yukle")
async def upload_exam_pdf(
    file: UploadFile = File(...),
    okul_id: int = 1,
    db: Session = Depends(get_db)
):
    """
    PDF formatındaki sınav sonuçlarını sisteme yükler.
    PDF'deki tablo yapısını okuyup veritabanına kaydeder.
    """

    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Sadece PDF dosyaları yüklenebilir.")

    try:
        # PDF dosyasını oku
        content = await file.read()
        pdf_file = io.BytesIO(content)

        results = []
        sinav_adi = None
        debug_info = []

        with pdfplumber.open(pdf_file) as pdf:
            for page_num, page in enumerate(pdf.pages):
                # Sayfadaki tüm metni de al (debug için)
                text = page.extract_text()
                debug_info.append(f"Sayfa {page_num + 1}: {len(text) if text else 0} karakter")

                # Tabloları çıkar
                tables = page.extract_tables()
                debug_info.append(f"Sayfa {page_num + 1}: {len(tables)} tablo bulundu")

                if not tables:
                    continue

                for table_idx, table in enumerate(tables):
                    debug_info.append(f"Tablo {table_idx + 1}: {len(table)} satır")

                    # İlk birkaç satırdan sınav adını bul
                    for row in table[:10]:
                        for cell in row:
                            if cell and isinstance(cell, str):
                                cell_upper = cell.upper()
                                if 'DENEME' in cell_upper or 'SINAV' in cell_upper or 'LGS' in cell_upper:
                                    # "7. SINIF LGS 2.DENEME" gibi
                                    if not sinav_adi and len(cell.strip()) > 5:
                                        sinav_adi = cell.strip()

                    # Öğrenci satırlarını bul
                    for row in table:
                        if not row or len(row) < 3:
                            continue

                        # Tüm hücreleri kontrol et
                        isim_cell = None
                        sinif_cell = None

                        for cell in row:
                            if not cell:
                                continue

                            cell_str = str(cell).strip()

                            # Sınıf bilgisi (7-A, 7-XX, 7-XA formatında)
                            if re.match(r'^\d+-[A-Z]{1,2}$', cell_str):
                                sinif_cell = cell_str

                            # İsim (BÜYÜK HARFLERLE yazılmış 2+ kelime)
                            # Örn: "UTKAN AĞAOĞLU", "ZEYNEP AKIN"
                            if re.match(r'^[A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜ\s]+$', cell_str) and ' ' in cell_str:
                                # En az 2 kelime olmalı
                                words = cell_str.split()
                                if len(words) >= 2 and all(len(w) >= 2 for w in words):
                                    isim_cell = cell_str

                        # İsim ve sınıf bulundu mu?
                        if isim_cell and sinif_cell:
                            parts = isim_cell.split()
                            ad = parts[0]
                            soyad = " ".join(parts[1:])

                            # Toplam puanı bul - en sağdaki büyük sayılardan biri
                            toplam_puan = 0.0
                            for cell in reversed(row):
                                if cell:
                                    try:
                                        # Sayıyı parse et
                                        val_str = str(cell).replace(',', '.').strip()
                                        val = float(val_str)
                                        # 200+ ise LGS puanı, 50-100 arası ise toplam puan olabilir
                                        if 50 <= val <= 500:
                                            toplam_puan = val
                                            break
                                    except:
                                        pass

                            results.append({
                                'ad': ad,
                                'soyad': soyad,
                                'sinif': sinif_cell,
                                'puan': toplam_puan
                            })
                            debug_info.append(f"✓ Öğrenci bulundu: {ad} {soyad} ({sinif_cell}) - {toplam_puan}")

        if not results:
            # Eğer hiç metin okunamadıysa, taranmış PDF olabilir
            total_chars = sum([int(d.split(':')[1].split()[0]) for d in debug_info if 'karakter' in d])
            if total_chars == 0:
                raise HTTPException(
                    status_code=400,
                    detail="Bu PDF taranmış bir belgedir (OCR gerekli). Lütfen Excel formatında yükleyin veya dijital PDF kullanın."
                )
            raise HTTPException(
                status_code=400,
                detail=f"PDF'den öğrenci verisi okunamadı. Debug: {'; '.join(debug_info[:10])}"
            )

        # Sınav adını belirle
        if not sinav_adi:
            sinav_adi = f"Yüklenen Sınav - {date.today()}"

        # Veritabanına kaydet
        # 1. Sınav oluştur veya bul
        sinav = db.query(models.Sinav).filter(models.Sinav.ad == sinav_adi).first()
        if not sinav:
            sinav = models.Sinav(
                ad=sinav_adi,
                tarih=date.today(),
                ders_id=None  # Genel sınav
            )
            db.add(sinav)
            db.commit()
            db.refresh(sinav)

        saved_count = 0
        errors = []

        for result in results:
            try:
                # Öğrenciyi bul
                ogrenci = db.query(models.Ogrenci).filter(
                    models.Ogrenci.ad == result['ad'],
                    models.Ogrenci.soyad == result['soyad']
                ).first()

                if not ogrenci:
                    # Sınıfı bul veya oluştur
                    sinif = db.query(models.Sinif).filter(
                        models.Sinif.ad == result['sinif'],
                        models.Sinif.okul_id == okul_id
                    ).first()

                    if not sinif:
                        # Sınıf seviyesini belirle (7-A -> 7)
                        seviye_match = re.match(r'^(\d+)', result['sinif'])
                        seviye = int(seviye_match.group(1)) if seviye_match else 7

                        sinif = models.Sinif(
                            okul_id=okul_id,
                            ad=result['sinif'],
                            seviye=seviye
                        )
                        db.add(sinif)
                        db.commit()
                        db.refresh(sinif)

                    # Öğrenci oluştur
                    ogrenci = models.Ogrenci(
                        sinif_id=sinif.id,
                        ad=result['ad'],
                        soyad=result['soyad'],
                        numara=0  # Numara yok
                    )
                    db.add(ogrenci)
                    db.commit()
                    db.refresh(ogrenci)

                # Sınav sonucu ekle veya güncelle
                sonuc = db.query(models.SinavSonucu).filter(
                    models.SinavSonucu.ogrenci_id == ogrenci.id,
                    models.SinavSonucu.sinav_id == sinav.id
                ).first()

                if sonuc:
                    # Güncelle
                    sonuc.puan = result['puan']
                else:
                    # Yeni sonuç ekle
                    sonuc = models.SinavSonucu(
                        ogrenci_id=ogrenci.id,
                        sinav_id=sinav.id,
                        puan=result['puan']
                    )
                    db.add(sonuc)

                db.commit()
                saved_count += 1

            except Exception as e:
                errors.append(f"{result['ad']} {result['soyad']}: {str(e)}")
                continue

        return {
            "success": True,
            "message": f"{saved_count} öğrenci sonucu kaydedildi.",
            "sinav_adi": sinav_adi,
            "sinav_id": sinav.id,
            "toplam_ogrenci": len(results),
            "kaydedilen": saved_count,
            "hatalar": errors if errors else None
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF işlenirken hata oluştu: {str(e)}")

@router.post("/sinav-tek-yukle")
async def upload_tek_exam(
    file: UploadFile = File(...),
    okul_id: int = 1,
    sinif_adi: str = Query(..., description="Sınıf adı (örn: 8-A)"),
    overwrite: bool = Query(False, description="Aynı isimli sınavın üzerine yaz"),
    db: Session = Depends(get_db)
):
    """TEK yayınları PDF formatını yükler"""
    from .pdf_tek_parser import parse_tek_pdf

    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Sadece PDF dosyaları yüklenebilir.")

    try:
        content = await file.read()
        parsed_data = parse_tek_pdf(content)

        sinav_adi = parsed_data['sinav_adi']
        ogrenciler = parsed_data['ogrenciler']

        if not ogrenciler:
            raise HTTPException(
                status_code=400,
                detail="PDF'den öğrenci verisi okunamadı."
            )

        # Aynı isimde sınav var mı kontrol et
        existing_sinav = db.query(models.Sinav).filter(
            models.Sinav.ad == sinav_adi
        ).first()

        if existing_sinav and not overwrite:
            # Aynı isimde sınav var ve overwrite false
            raise HTTPException(
                status_code=409,  # Conflict
                detail={
                    "error": "duplicate_exam",
                    "message": f"'{sinav_adi}' adında bir sınav zaten mevcut.",
                    "sinav_id": existing_sinav.id,
                    "sinav_adi": sinav_adi
                }
            )

        # Sınav oluştur veya mevcut sınavı kullan
        if existing_sinav and overwrite:
            # Eski sonuçları sil
            db.query(models.SinavSonucu).filter(
                models.SinavSonucu.sinav_id == existing_sinav.id
            ).delete(synchronize_session=False)
            sinav = existing_sinav
        else:
            sinav = models.Sinav(ad=sinav_adi, tarih=date.today())
            db.add(sinav)
            db.commit()
            db.refresh(sinav)

        # Sınıfı bul
        sinif = db.query(models.Sinif).filter(
            models.Sinif.okul_id == okul_id,
            models.Sinif.ad == sinif_adi
        ).first()

        if not sinif:
            raise HTTPException(status_code=404, detail=f"Sınıf bulunamadı: {sinif_adi}")

        matched = []
        unmatched_results = []
        unmatched_students = []

        # Sınıftaki öğrencileri al
        db_students = db.query(models.Ogrenci).filter(models.Ogrenci.sinif_id == sinif.id).all()

        for ogr_data in ogrenciler:
            # Numarayla eşleştir (öncelikli)
            found = False
            ogr_no = ogr_data.get('ogrenci_no', '0')

            # Önce numaraya göre eşleştirmeyi dene
            if ogr_no and ogr_no != '0':
                try:
                    ogr_no_int = int(ogr_no)
                    for db_ogr in db_students:
                        if db_ogr.numara == ogr_no_int:
                            # Numaraya göre eşleşti
                            sonuc = models.SinavSonucu(
                                ogrenci_id=db_ogr.id,
                                sinav_id=sinav.id,
                                puan=ogr_data['lgs_puan'],
                                sinif_sira=ogr_data.get('sinif_sira'),
                                okul_sira=ogr_data.get('okul_sira'),
                                ilce_sira=ogr_data.get('ilce_sira'),
                                il_sira=ogr_data.get('il_sira'),
                                genel_sira=ogr_data.get('genel_sira')
                            )
                            db.add(sonuc)
                            matched.append(ogr_data['isim'])
                            found = True
                            break
                except ValueError:
                    pass  # Numara parse edilemedi, isimle eşleştirmeyi dene

            # Numara ile eşleşmediyse, isimle eşleştir (fallback)
            if not found:
                for db_ogr in db_students:
                    if db_ogr.ad in ogr_data['isim'] and db_ogr.soyad in ogr_data['isim']:
                        # İsimle eşleşti
                        sonuc = models.SinavSonucu(
                            ogrenci_id=db_ogr.id,
                            sinav_id=sinav.id,
                            puan=ogr_data['lgs_puan'],
                            sinif_sira=ogr_data.get('sinif_sira'),
                            okul_sira=ogr_data.get('okul_sira'),
                            ilce_sira=ogr_data.get('ilce_sira'),
                            il_sira=ogr_data.get('il_sira'),
                            genel_sira=ogr_data.get('genel_sira')
                        )
                        db.add(sonuc)
                        matched.append(ogr_data['isim'])
                        found = True
                        break

            if not found:
                unmatched_results.append(ogr_data)

        # Sonucu olmayan öğrenciler
        matched_ids = [s.id for s in db_students for m in matched if s.ad in m and s.soyad in m]
        for db_ogr in db_students:
            if db_ogr.id not in matched_ids:
                unmatched_students.append({
                    'id': db_ogr.id,
                    'ad': db_ogr.ad,
                    'soyad': db_ogr.soyad,
                    'numara': db_ogr.numara
                })

        db.commit()

        return {
            "success": True,
            "sinav_adi": sinav_adi,
            "sinav_id": sinav.id,
            "toplam_sonuc": len(ogrenciler),
            "eslestirildi": len(matched),
            "eslestirilemedi": len(unmatched_results),
            "bosta_ogrenci": len(unmatched_students),
            "eslestirilemeyenler": unmatched_results[:10],  # İlk 10
            "bosta_ogrenciler": unmatched_students[:10]
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Hata: {str(e)}")


# ============ YENİ: PDF ÖNİZLEME VE EŞLEŞTİRME ============

@router.post("/onizleme")
async def preview_pdf_for_matching(
    file: UploadFile = File(...),
    okul_id: int = Query(...),
    db: Session = Depends(get_db)
):
    """
    PDF'i yüklemeden önce önizleme yapar ve öğrenci eşleştirmesini gösterir.
    Kullanıcı manuel eşleştirme yapabilir.
    """
    try:
        from .pdf_tek_parser import parse_tek_pdf_table, parse_tek_exam_name

        # PDF'i oku
        content = await file.read()
        pdf_file = io.BytesIO(content)

        with pdfplumber.open(pdf_file) as pdf:
            # İlk sayfadan sınav adını bul
            first_page_text = pdf.pages[0].extract_text() or ""
            sinav_adi = parse_tek_exam_name(first_page_text)

            # Tüm öğrencileri topla
            all_students = []
            for page in pdf.pages:
                table = page.extract_table()
                if table:
                    parsed = parse_tek_pdf_table(table)
                    all_students.extend(parsed)

        if not all_students:
            raise HTTPException(status_code=400, detail="PDF'de öğrenci bulunamadı")

        # Sınıf bilgisini ilk öğrenciden al
        sinif_adi = all_students[0].get('sinif', '')
        if not sinif_adi:
            raise HTTPException(status_code=400, detail="PDF'de sınıf bilgisi bulunamadı")

        # Veritabanındaki sınıfı bul
        sinif = db.query(models.Sinif).join(models.Okul).filter(
            models.Okul.id == okul_id,
            models.Sinif.ad == sinif_adi
        ).first()

        if not sinif:
            return {
                "success": False,
                "error": f"'{sinif_adi}' sınıfı bulunamadı",
                "sinav_adi": sinav_adi,
                "sinif_adi": sinif_adi,
                "pdf_students": all_students,
                "matched": [],
                "unmatched": all_students,
                "new_students": all_students
            }

        # Sınıftaki mevcut öğrencileri al
        db_students = db.query(models.Ogrenci).filter(
            models.Ogrenci.sinif_id == sinif.id
        ).all()

        # Eşleştirme yap (numara bazlı)
        matched = []
        unmatched = []
        new_students = []

        db_students_by_numara = {ogr.numara: ogr for ogr in db_students}

        for pdf_student in all_students:
            pdf_numara = pdf_student.get('numara')
            pdf_isim = pdf_student.get('isim', '')

            if pdf_numara and pdf_numara in db_students_by_numara:
                # Eşleşti - numara uyuştu
                db_student = db_students_by_numara[pdf_numara]
                matched.append({
                    "pdf_data": pdf_student,
                    "db_student": {
                        "id": db_student.id,
                        "ad": db_student.ad,
                        "soyad": db_student.soyad,
                        "numara": db_student.numara
                    },
                    "match_type": "exact",  # Numara tam eşleşme
                    "confidence": 1.0
                })
            else:
                # Eşleşmedi - yeni öğrenci olabilir
                # İsim benzerliği kontrolü (kullanıcı manuel eşleştirebilsin)
                similar_students = []
                for db_student in db_students:
                    if db_student.numara in [m["db_student"]["numara"] for m in matched]:
                        continue  # Zaten eşleşmiş

                    # Basit isim benzerliği (case-insensitive)
                    pdf_isim_lower = pdf_isim.lower()
                    db_isim_lower = f"{db_student.ad} {db_student.soyad}".lower()

                    if pdf_isim_lower in db_isim_lower or db_isim_lower in pdf_isim_lower:
                        similar_students.append({
                            "id": db_student.id,
                            "ad": db_student.ad,
                            "soyad": db_student.soyad,
                            "numara": db_student.numara,
                            "similarity": 0.7  # Orta benzerlik
                        })

                if similar_students:
                    # Benzer öğrenciler var - manuel eşleştirme gerekli
                    unmatched.append({
                        "pdf_data": pdf_student,
                        "similar_students": similar_students,
                        "match_type": "similar",
                        "requires_manual": True
                    })
                else:
                    # Hiç benzer yok - yeni öğrenci
                    new_students.append({
                        "pdf_data": pdf_student,
                        "match_type": "new",
                        "requires_manual": True
                    })

        return {
            "success": True,
            "sinav_adi": sinav_adi,
            "sinif_adi": sinif_adi,
            "sinif_id": sinif.id,
            "total_pdf_students": len(all_students),
            "matched_count": len(matched),
            "unmatched_count": len(unmatched),
            "new_students_count": len(new_students),
            "matched": matched,
            "unmatched": unmatched,
            "new_students": new_students
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Hata: {str(e)}")


@router.post("/onizleme-onayla")
async def confirm_and_save_exam(
    mappings: Dict[str, Any],
    db: Session = Depends(get_db)
):
    """
    Kullanıcı tarafından onaylanmış eşleştirmeleri kaydeder.
    mappings: {
        "sinav_adi": str,
        "sinif_id": int,
        "confirmed_matches": [
            {
                "pdf_data": {...},
                "ogrenci_id": int  # Manuel veya otomatik eşleşmiş öğrenci ID
            }
        ]
    }
    """
    try:
        sinav_adi = mappings.get("sinav_adi")
        sinif_id = mappings.get("sinif_id")
        confirmed_matches = mappings.get("confirmed_matches", [])

        if not sinav_adi or not sinif_id:
            raise HTTPException(status_code=400, detail="Sınav adı ve sınıf ID gerekli")

        # Sınıfı kontrol et
        sinif = db.query(models.Sinif).filter(models.Sinif.id == sinif_id).first()
        if not sinif:
            raise HTTPException(status_code=404, detail="Sınıf bulunamadı")

        # Sınav oluştur
        sinav = models.Sinav(
            ad=sinav_adi,
            tarih=date.today(),
            donem="Deneme",  # Varsayılan
            sinif_id=sinif_id,
            ders_id=1  # Varsayılan (LGS = genel)
        )
        db.add(sinav)
        db.flush()  # ID almak için

        # Sonuçları kaydet
        saved_count = 0
        for match in confirmed_matches:
            pdf_data = match.get("pdf_data", {})
            ogrenci_id = match.get("ogrenci_id")

            if not ogrenci_id:
                continue  # Eşleştirilmemiş, atla

            # Öğrenciyi kontrol et
            ogrenci = db.query(models.Ogrenci).filter(models.Ogrenci.id == ogrenci_id).first()
            if not ogrenci:
                continue

            # Sonucu kaydet
            sonuc = models.SinavSonucu(
                ogrenci_id=ogrenci_id,
                sinav_id=sinav.id,
                puan=pdf_data.get('lgs_puan', 0),
                sinif_sira=pdf_data.get('sinif_sira'),
                okul_sira=pdf_data.get('okul_sira'),
                ilce_sira=pdf_data.get('ilce_sira'),
                il_sira=pdf_data.get('il_sira'),
                genel_sira=pdf_data.get('genel_sira')
            )
            db.add(sonuc)
            saved_count += 1

        db.commit()

        return {
            "success": True,
            "sinav_id": sinav.id,
            "sinav_adi": sinav_adi,
            "saved_count": saved_count,
            "message": f"{saved_count} öğrencinin sonucu kaydedildi"
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Hata: {str(e)}")
