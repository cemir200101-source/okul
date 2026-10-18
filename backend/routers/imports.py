from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status, Query
from sqlalchemy.orm import Session
import pandas as pd
from auth import get_current_mudur

from sqlalchemy.exc import IntegrityError

from database import SessionLocal
import models
from auth import get_current_admin   # admin kontrolü için

router = APIRouter(
    prefix="/import",
    tags=["İçe Aktarma"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/eokul/sinif", summary="e-Okul sınıf listesini Excel'den içe aktar")
def import_eokul_sinif(
    sinif_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_mudur),
):
    sinif = db.query(models.Sinif).filter(models.Sinif.id == sinif_id).first()
    if not sinif:
        raise HTTPException(status_code=404, detail="Sınıf bulunamadı.")
    
    if current_user.rol == "mudur" and sinif.okul_id != current_user.okul_id:
        raise HTTPException(status_code=403, detail="Bu sınıf sizin okulunuza ait değil.")
    
    # 1) Dosya tipi kontrolü
    if not file.filename.lower().endswith((".xls", ".xlsx")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Lütfen .xls veya .xlsx uzantılı bir Excel dosyası yükleyin.",
        )

    # 2) Dosyayı başlıksız (header=None) oku
    file.file.seek(0)
    df_raw = pd.read_excel(file.file, header=None)

    # 3) 'Öğrenci No' yazan satırı bul ve header olarak kullan
    header_row = None
    for i, row in df_raw.iterrows():
        if "Öğrenci No" in row.values:
            header_row = i
            break

    if header_row is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Excel içinde 'Öğrenci No' başlığını içeren satır bulunamadı.",
        )

    # 4) Aynı dosyayı doğru header satırı ile tekrar oku
    file.file.seek(0)
    df = pd.read_excel(file.file, header=header_row)

    # loglama
    print("KOLONLAR:", list(df.columns))

    # 5) Gerekli kolonları kontrol et
    gerekli_kolonlar = ["Öğrenci No", "Adı", "Soyadı", "Cinsiyeti"]
    eksik = [k for k in gerekli_kolonlar if k not in df.columns]
    if eksik:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Excel içinde şu sütunlar eksik: {eksik}. "
                   f"Mevcut sütunlar: {list(df.columns)}",
        )

    db.query(models.Ogrenci).filter(
        models.Ogrenci.sinif_id == sinif_id
    ).delete(synchronize_session=False)

    # 6) Satır satır öğrenci ekle
    eklenen_sayisi = 0
    for _, row in df.iterrows():
        ad = str(row["Adı"]).strip() if pd.notna(row["Adı"]) else ""
        soyad = str(row["Soyadı"]).strip() if pd.notna(row["Soyadı"]) else ""
        numara_raw = row["Öğrenci No"]

        # Boş satırları atla
        if not ad or not soyad:
            continue

        # Numara integer değilse atla
        try:
            numara = int(numara_raw)
        except (TypeError, ValueError):
            continue

        yeni_ogr = models.Ogrenci(
            ad=ad,
            soyad=soyad,
            numara=numara,
            sinif_id=sinif_id,
        )
        db.add(yeni_ogr)
        eklenen_sayisi += 1

    db.commit()

    return {
        "message": "İçe aktarma tamamlandı.",
        "sinif_id": sinif_id,
        "eklenen_ogrenci_sayisi": eklenen_sayisi,
    }


@router.post("/ogrenciler/excel", summary="Excel'den toplu öğrenci içe aktarma")
async def import_students_bulk(
    sinif_id: int = Query(..., description="Öğrencilerin ekleneceği sınıf ID"),
    replace: bool = Query(False, description="True ise mevcut öğrencileri sil, False ise ekle"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_mudur),
):
    """
    Excel dosyasından toplu öğrenci ekleme.

    Excel formatı:
    - Ad | Soyad | Numara (veya Öğrenci No)
    - İlk satır başlık satırı olmalı

    Örnek:
    Ad       | Soyad    | Numara
    Ahmet    | Yılmaz   | 101
    Mehmet   | Demir    | 102
    """
    # Sınıfı kontrol et
    sinif = db.query(models.Sinif).filter(models.Sinif.id == sinif_id).first()
    if not sinif:
        raise HTTPException(status_code=404, detail="Sınıf bulunamadı.")

    # Yetki kontrolü
    if current_user.rol == "mudur":
        # Müdür için okul kontrolü
        okul_ids = [okul.id for okul in current_user.okullar]
        if sinif.okul_id not in okul_ids:
            raise HTTPException(status_code=403, detail="Bu sınıfa öğrenci ekleyemezsiniz.")

    # Dosya tipi kontrolü
    if not file.filename.lower().endswith((".xls", ".xlsx", ".csv")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Lütfen .xls, .xlsx veya .csv uzantılı bir dosya yükleyin.",
        )

    try:
        # Dosyayı oku
        file.file.seek(0)
        if file.filename.lower().endswith(".csv"):
            df = pd.read_csv(file.file)
        else:
            df = pd.read_excel(file.file)

        # Sütun isimlerini normalize et (boşlukları ve büyük/küçük harf farklarını kaldır)
        df.columns = df.columns.str.strip().str.lower()

        # Gerekli kolonları kontrol et - birden fazla alternatif kabul et
        ad_col = None
        soyad_col = None
        numara_col = None

        for col in df.columns:
            if col in ['ad', 'adı', 'isim', 'adi']:
                ad_col = col
            elif col in ['soyad', 'soyadı', 'soyadi']:
                soyad_col = col
            elif col in ['numara', 'öğrenci no', 'ogrenci no', 'no', 'öğrenci numara', 'ogrenci numara']:
                numara_col = col

        if not ad_col or not soyad_col:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Excel'de 'Ad' ve 'Soyad' sütunları bulunmalıdır. Mevcut sütunlar: {list(df.columns)}",
            )

        # Mevcut öğrencileri sil (replace=True ise)
        if replace:
            db.query(models.Ogrenci).filter(
                models.Ogrenci.sinif_id == sinif_id
            ).delete(synchronize_session=False)

        # Öğrencileri ekle
        eklenen_sayisi = 0
        hatalar = []

        for idx, row in df.iterrows():
            try:
                ad = str(row[ad_col]).strip() if pd.notna(row[ad_col]) else ""
                soyad = str(row[soyad_col]).strip() if pd.notna(row[soyad_col]) else ""

                # Boş satırları atla
                if not ad or not soyad or ad.lower() == 'nan' or soyad.lower() == 'nan':
                    continue

                # Numara varsa al, yoksa None
                numara = None
                if numara_col and pd.notna(row[numara_col]):
                    try:
                        numara = int(row[numara_col])
                    except (TypeError, ValueError):
                        hatalar.append(f"Satır {idx+2}: Geçersiz numara '{row[numara_col]}' - öğrenci numarasız eklendi")

                # Öğrenci ekle
                yeni_ogr = models.Ogrenci(
                    ad=ad,
                    soyad=soyad,
                    numara=numara,
                    sinif_id=sinif_id,
                )
                db.add(yeni_ogr)
                eklenen_sayisi += 1

            except Exception as e:
                hatalar.append(f"Satır {idx+2}: {str(e)}")
                continue

        db.commit()

        return {
            "success": True,
            "message": f"{eklenen_sayisi} öğrenci başarıyla eklendi.",
            "sinif_id": sinif_id,
            "sinif_adi": sinif.ad,
            "eklenen_ogrenci_sayisi": eklenen_sayisi,
            "toplam_satir": len(df),
            "hatalar": hatalar if hatalar else None
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Dosya işlenirken hata: {str(e)}")


@router.post("/sinav-sonuclari/excel", summary="Excel'den toplu sınav sonucu içe aktarma")
async def import_exam_results_bulk(
    sinav_id: int = Query(..., description="Sınav ID"),
    replace: bool = Query(False, description="True ise mevcut sonuçları sil, False ise ekle"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_mudur),
):
    """
    Excel dosyasından toplu sınav sonucu ekleme.

    Excel formatı:
    - Numara (veya Öğrenci No) | Puan | Doğru | Yanlış | Net
    - İlk satır başlık satırı olmalı
    - Numara: Öğrenci numarası (zorunlu)
    - Puan: Toplam puan (opsiyonel)
    - Doğru, Yanlış, Net: Soru sayıları (opsiyonel)

    Örnek:
    Numara | Puan  | Doğru | Yanlış | Net
    101    | 85.5  | 17    | 3      | 15.5
    102    | 92.0  | 19    | 1      | 18.5
    """
    # Sınavı kontrol et
    sinav = db.query(models.Sinav).filter(models.Sinav.id == sinav_id).first()
    if not sinav:
        raise HTTPException(status_code=404, detail="Sınav bulunamadı.")

    # Sınıfı kontrol et
    sinif = db.query(models.Sinif).filter(models.Sinif.id == sinav.sinif_id).first()
    if not sinif:
        raise HTTPException(status_code=404, detail="Sınıf bulunamadı.")

    # Yetki kontrolü
    if current_user.rol == "mudur":
        # Müdür için okul kontrolü
        okul_ids = [okul.id for okul in current_user.okullar]
        if sinif.okul_id not in okul_ids:
            raise HTTPException(status_code=403, detail="Bu sınava sonuç ekleyemezsiniz.")

    # Dosya tipi kontrolü
    if not file.filename.lower().endswith((".xls", ".xlsx", ".csv")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Lütfen .xls, .xlsx veya .csv uzantılı bir dosya yükleyin.",
        )

    try:
        # Dosyayı oku
        file.file.seek(0)
        if file.filename.lower().endswith(".csv"):
            df = pd.read_csv(file.file)
        else:
            df = pd.read_excel(file.file)

        # Sütun isimlerini normalize et
        df.columns = df.columns.str.strip().str.lower()

        # Numara sütununu bul
        numara_col = None
        for col in df.columns:
            if col in ['numara', 'öğrenci no', 'ogrenci no', 'no', 'öğrenci numara', 'ogrenci numara']:
                numara_col = col
                break

        if not numara_col:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Excel'de 'Numara' veya 'Öğrenci No' sütunu bulunmalıdır. Mevcut sütunlar: {list(df.columns)}",
            )

        # Diğer sütunları bul
        puan_col = None
        dogru_col = None
        yanlis_col = None
        net_col = None

        for col in df.columns:
            if col in ['puan', 'toplam puan', 'toplampuan']:
                puan_col = col
            elif col in ['dogru', 'doğru', 'd']:
                dogru_col = col
            elif col in ['yanlis', 'yanlış', 'y']:
                yanlis_col = col
            elif col in ['net', 'n']:
                net_col = col

        # Mevcut sonuçları sil (replace=True ise)
        if replace:
            db.query(models.SinavSonucu).filter(
                models.SinavSonucu.sinav_id == sinav_id
            ).delete(synchronize_session=False)

        # Sınıftaki öğrencileri numara ile map et
        ogrenciler = db.query(models.Ogrenci).filter(
            models.Ogrenci.sinif_id == sinif.id
        ).all()
        ogrenci_map = {ogr.numara: ogr.id for ogr in ogrenciler if ogr.numara is not None}

        # Sonuçları ekle
        eklenen_sayisi = 0
        hatalar = []

        for idx, row in df.iterrows():
            try:
                # Öğrenci numarasını al
                if not pd.notna(row[numara_col]):
                    continue

                try:
                    numara = int(row[numara_col])
                except (TypeError, ValueError):
                    hatalar.append(f"Satır {idx+2}: Geçersiz numara '{row[numara_col]}'")
                    continue

                # Öğrenciyi bul
                if numara not in ogrenci_map:
                    hatalar.append(f"Satır {idx+2}: {numara} numaralı öğrenci bulunamadı")
                    continue

                ogrenci_id = ogrenci_map[numara]

                # Puan bilgilerini al
                puan = None
                dogru = None
                yanlis = None
                net = None

                if puan_col and pd.notna(row[puan_col]):
                    try:
                        puan = float(row[puan_col])
                    except (TypeError, ValueError):
                        hatalar.append(f"Satır {idx+2}: Geçersiz puan '{row[puan_col]}'")

                if dogru_col and pd.notna(row[dogru_col]):
                    try:
                        dogru = float(row[dogru_col])
                    except (TypeError, ValueError):
                        pass

                if yanlis_col and pd.notna(row[yanlis_col]):
                    try:
                        yanlis = float(row[yanlis_col])
                    except (TypeError, ValueError):
                        pass

                if net_col and pd.notna(row[net_col]):
                    try:
                        net = float(row[net_col])
                    except (TypeError, ValueError):
                        pass

                # Puan yoksa ama net varsa, net'i puan olarak kullan
                if puan is None and net is not None:
                    puan = net

                # Puan hala yoksa atla
                if puan is None:
                    hatalar.append(f"Satır {idx+2}: Numara {numara} için puan bilgisi bulunamadı")
                    continue

                # Mevcut sonuç var mı kontrol et (replace=False ise)
                if not replace:
                    existing = db.query(models.SinavSonucu).filter(
                        models.SinavSonucu.sinav_id == sinav_id,
                        models.SinavSonucu.ogrenci_id == ogrenci_id
                    ).first()
                    if existing:
                        hatalar.append(f"Satır {idx+2}: Numara {numara} için sonuç zaten mevcut")
                        continue

                # Sonuç ekle veya güncelle
                sonuc = models.SinavSonucu(
                    sinav_id=sinav_id,
                    ogrenci_id=ogrenci_id,
                    puan=puan,
                    dogru=dogru,
                    yanlis=yanlis,
                    net=net,
                )
                db.add(sonuc)
                eklenen_sayisi += 1

            except Exception as e:
                hatalar.append(f"Satır {idx+2}: {str(e)}")
                continue

        db.commit()

        return {
            "success": True,
            "message": f"{eklenen_sayisi} sınav sonucu başarıyla eklendi.",
            "sinav_id": sinav_id,
            "sinav_adi": sinav.ad,
            "eklenen_sonuc_sayisi": eklenen_sayisi,
            "toplam_satir": len(df),
            "hatalar": hatalar if hatalar else None
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Dosya işlenirken hata: {str(e)}")


@router.post("/pdf/ogrenciler", summary="PDF'den öğrenci bilgilerini içe aktar")
async def import_students_from_pdf(
    file: UploadFile = File(...),
    okul_id: int = Query(...),
    sinif_adi: str = Query(..., description="Sınıf adı (örn: 8-A)"),
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_mudur),
):
    """
    TEK yayınları PDF formatından öğrenci bilgilerini (isim, soyad, numara, sınıf) çıkarır ve ekler.
    Eğer sınıf yoksa oluşturur, varsa mevcut öğrencileri siler ve yeniden ekler.
    """
    from .pdf_tek_parser import parse_tek_pdf

    # Yetki kontrolü
    if current_user.rol == "mudur" and current_user.okul_id != okul_id:
        raise HTTPException(status_code=403, detail="Bu okula ait öğrenci ekleyemezsiniz.")

    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Sadece PDF dosyaları yüklenebilir.")

    try:
        # PDF'i parse et
        content = await file.read()
        parsed_data = parse_tek_pdf(content)

        ogrenciler = parsed_data['ogrenciler']

        if not ogrenciler:
            raise HTTPException(
                status_code=400,
                detail="PDF'den öğrenci verisi okunamadı."
            )

        # Sınıfı bul veya oluştur
        sinif = db.query(models.Sinif).filter(
            models.Sinif.okul_id == okul_id,
            models.Sinif.ad == sinif_adi
        ).first()

        if not sinif:
            # Sınıf seviyesini belirle (8-A -> 8)
            import re
            seviye_match = re.match(r'^(\d+)', sinif_adi)
            seviye = int(seviye_match.group(1)) if seviye_match else 7

            sinif = models.Sinif(
                okul_id=okul_id,
                ad=sinif_adi,
                seviye=seviye
            )
            db.add(sinif)
            db.commit()
            db.refresh(sinif)

        # Mevcut öğrencileri sil
        db.query(models.Ogrenci).filter(
            models.Ogrenci.sinif_id == sinif.id
        ).delete(synchronize_session=False)

        # Silme işlemini commit et (UNIQUE constraint için)
        db.commit()

        # Yeni öğrencileri ekle
        eklenen_sayisi = 0
        hatalar = []

        for ogr_data in ogrenciler:
            try:
                # İsmi parçala
                isim_parts = ogr_data['isim'].split()
                if len(isim_parts) < 2:
                    hatalar.append(f"Geçersiz isim formatı: {ogr_data['isim']}")
                    continue

                ad = isim_parts[0]
                soyad = ' '.join(isim_parts[1:])

                # Numara parse et
                try:
                    numara = int(ogr_data['ogrenci_no']) if ogr_data['ogrenci_no'] else 0
                except (ValueError, TypeError):
                    numara = 0

                # Öğrenci ekle
                yeni_ogr = models.Ogrenci(
                    ad=ad,
                    soyad=soyad,
                    numara=numara,
                    sinif_id=sinif.id
                )
                db.add(yeni_ogr)
                eklenen_sayisi += 1

            except Exception as e:
                hatalar.append(f"{ogr_data['isim']}: {str(e)}")
                continue

        db.commit()

        return {
            "success": True,
            "message": f"{eklenen_sayisi} öğrenci başarıyla eklendi.",
            "sinif_id": sinif.id,
            "sinif_adi": sinif.ad,
            "eklenen_ogrenci_sayisi": eklenen_sayisi,
            "toplam_pdf_ogrenci": len(ogrenciler),
            "hatalar": hatalar if hatalar else None
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF işlenirken hata: {str(e)}")
