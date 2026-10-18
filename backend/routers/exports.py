from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
import pandas as pd
from io import BytesIO
from datetime import datetime

from database import SessionLocal
import models
from auth import get_current_mudur

router = APIRouter(prefix="/exports", tags=["Exports"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/sinav-sonuclari/excel")
async def export_exam_results_excel(
    sinav_id: int = Query(..., description="Sınav ID"),
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_mudur),
):
    """
    Belirli bir sınavın sonuçlarını Excel formatında dışa aktarır.
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
        okul_ids = [okul.id for okul in current_user.okullar]
        if sinif.okul_id not in okul_ids:
            raise HTTPException(status_code=403, detail="Bu sınav sonuçlarını görüntüleme yetkiniz yok.")

    # Sınav sonuçlarını al
    q = (
        db.query(models.SinavSonucu, models.Ogrenci)
        .join(models.Ogrenci, models.SinavSonucu.ogrenci_id == models.Ogrenci.id)
        .filter(models.SinavSonucu.sinav_id == sinav_id)
        .order_by(models.SinavSonucu.puan.desc())
    )

    results = []
    for sonuc, ogrenci in q.all():
        results.append({
            "Numara": ogrenci.numara,
            "Ad": ogrenci.ad,
            "Soyad": ogrenci.soyad,
            "Puan": sonuc.puan,
            "Doğru": getattr(sonuc, "dogru", None),
            "Yanlış": getattr(sonuc, "yanlis", None),
            "Net": getattr(sonuc, "net", None),
        })

    if not results:
        raise HTTPException(status_code=404, detail="Bu sınav için sonuç bulunamadı.")

    # DataFrame oluştur
    df = pd.DataFrame(results)

    # Excel dosyasına yaz
    output = BytesIO()
    with pd.ExcelWriter(output, engine='openpyxl') as writer:
        df.to_excel(writer, index=False, sheet_name='Sonuçlar')

        # Worksheet'e erişim ve formatting
        worksheet = writer.sheets['Sonuçlar']

        # Sütun genişliklerini ayarla
        for column in worksheet.columns:
            max_length = 0
            column_letter = column[0].column_letter
            for cell in column:
                try:
                    if len(str(cell.value)) > max_length:
                        max_length = len(str(cell.value))
                except:
                    pass
            adjusted_width = min(max_length + 2, 50)
            worksheet.column_dimensions[column_letter].width = adjusted_width

    output.seek(0)

    # Dosya adını oluştur
    safe_sinav_adi = "".join(c if c.isalnum() or c in (' ', '-', '_') else '_' for c in sinav.ad)
    filename = f"{safe_sinav_adi}_Sonuclar_{datetime.now().strftime('%Y%m%d')}.xlsx"

    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@router.get("/sinif-analiz/excel")
async def export_class_analysis_excel(
    sinif_id: int = Query(..., description="Sınıf ID"),
    sinav_id: int = Query(..., description="Sınav ID"),
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_mudur),
):
    """
    Bir sınıfın belirli bir sınavdaki analizini Excel formatında dışa aktarır.
    """
    # Sınıfı kontrol et
    sinif = db.query(models.Sinif).filter(models.Sinif.id == sinif_id).first()
    if not sinif:
        raise HTTPException(status_code=404, detail="Sınıf bulunamadı.")

    # Yetki kontrolü
    if current_user.rol == "mudur":
        okul_ids = [okul.id for okul in current_user.okullar]
        if sinif.okul_id not in okul_ids:
            raise HTTPException(status_code=403, detail="Bu sınıf analizini görüntüleme yetkiniz yok.")

    # Sınavı kontrol et
    sinav = db.query(models.Sinav).filter(models.Sinav.id == sinav_id).first()
    if not sinav:
        raise HTTPException(status_code=404, detail="Sınav bulunamadı.")

    # Öğrencileri ve sonuçları al
    ogrenci_ids = db.query(models.Ogrenci.id).filter(models.Ogrenci.sinif_id == sinif_id).all()
    ogrenci_ids = [oid[0] for oid in ogrenci_ids]

    q = (
        db.query(models.SinavSonucu, models.Ogrenci)
        .join(models.Ogrenci, models.SinavSonucu.ogrenci_id == models.Ogrenci.id)
        .filter(
            models.SinavSonucu.sinav_id == sinav_id,
            models.Ogrenci.id.in_(ogrenci_ids)
        )
        .order_by(models.SinavSonucu.puan.desc())
    )

    sonuclar = []
    sira = 1
    for sonuc, ogrenci in q.all():
        sonuclar.append({
            "Sıra": sira,
            "Numara": ogrenci.numara,
            "Ad": ogrenci.ad,
            "Soyad": ogrenci.soyad,
            "Puan": sonuc.puan,
            "Doğru": getattr(sonuc, "dogru", None),
            "Yanlış": getattr(sonuc, "yanlis", None),
            "Net": getattr(sonuc, "net", None),
        })
        sira += 1

    if not sonuclar:
        raise HTTPException(status_code=404, detail="Bu sınav için sonuç bulunamadı.")

    # İstatistikleri hesapla
    puanlar = [s["Puan"] for s in sonuclar if s["Puan"] is not None]
    ortalama = sum(puanlar) / len(puanlar) if puanlar else 0
    en_yuksek = max(puanlar) if puanlar else 0
    en_dusuk = min(puanlar) if puanlar else 0

    # İstatistikler DataFrame'i
    stats_data = {
        "İstatistik": ["Ortalama", "En Yüksek", "En Düşük", "Öğrenci Sayısı"],
        "Değer": [
            round(ortalama, 2),
            round(en_yuksek, 2),
            round(en_dusuk, 2),
            len(puanlar)
        ]
    }
    stats_df = pd.DataFrame(stats_data)

    # Sonuçlar DataFrame'i
    results_df = pd.DataFrame(sonuclar)

    # Excel dosyasına yaz
    output = BytesIO()
    with pd.ExcelWriter(output, engine='openpyxl') as writer:
        # İstatistikler sayfası
        stats_df.to_excel(writer, index=False, sheet_name='İstatistikler')

        # Sonuçlar sayfası
        results_df.to_excel(writer, index=False, sheet_name='Sıralama')

        # Sütun genişliklerini ayarla
        for sheet_name in writer.sheets:
            worksheet = writer.sheets[sheet_name]
            for column in worksheet.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except:
                        pass
                adjusted_width = min(max_length + 2, 50)
                worksheet.column_dimensions[column_letter].width = adjusted_width

    output.seek(0)

    # Dosya adını oluştur
    safe_sinif_adi = "".join(c if c.isalnum() or c in (' ', '-', '_') else '_' for c in sinif.ad)
    safe_sinav_adi = "".join(c if c.isalnum() or c in (' ', '-', '_') else '_' for c in sinav.ad)
    filename = f"{safe_sinif_adi}_{safe_sinav_adi}_Analiz_{datetime.now().strftime('%Y%m%d')}.xlsx"

    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
