"""
TEK Yayınları sınav sonucu PDF parser
Format: Öğrenci No, İsim, Sınıf, Ders netleri, LGS puanı
"""
import re
from typing import List, Dict, Optional


def parse_tek_pdf_table(table: List[List]) -> List[Dict]:
    """
    TEK yayınları PDF tablosunu parse eder

    Beklenen sütunlar:
    Sıra | Ö.No | İsim | Sınıf | ... ders netleri ... | LGS Puanı | Sınıf | Okul | İlçe | İl | Genel

    Son 5 sütun sıralama bilgileri (Sınıf sırası, Okul sırası, İlçe sırası, İl sırası, Genel sıra)
    """
    results = []

    for row in table:
        if not row or len(row) < 10:
            continue

        # Satırı string olarak birleştir
        row_text = " ".join([str(cell) if cell else "" for cell in row])

        # Başlık satırlarını atla
        if any(keyword in row_text.upper() for keyword in ["SINIFI", "GENEL ORTALAMA", "OKUL ORTALAMA", "SIRA", "KATILIMLAR"]):
            continue

        # Öğrenci numarası var mı kontrol et (genelde 2. veya 3. sütun)
        ogrenci_no = None
        isim = None
        sinif = None
        lgs_puan = None
        sinif_sira = None
        okul_sira = None
        ilce_sira = None
        il_sira = None
        genel_sira = None

        for i, cell in enumerate(row):
            if not cell:
                continue

            cell_str = str(cell).strip()

            # Öğrenci numarası (3 veya 4 haneli sayı)
            if not ogrenci_no and cell_str.isdigit() and 2 <= len(cell_str) <= 4:
                # Sıra numarası değil, öğrenci numarası
                if i > 0:  # İlk sütun genelde sıra
                    ogrenci_no = cell_str

            # İsim (2+ kelime, büyük/küçük harf karışık olabilir)
            # Harf içeren, en az 2 kelimeli, rakam içermeyen
            if not isim and ' ' in cell_str:
                # Rakam içermemeli (öğrenci no, puan vs değil)
                if not any(char.isdigit() for char in cell_str):
                    # En az 2 kelime olmalı
                    words = cell_str.split()
                    if len(words) >= 2:
                        # Her kelime harf içermeli
                        if all(any(c.isalpha() for c in word) for word in words):
                            isim = cell_str.upper()  # Standardize edilmiş format

            # Sınıf (8-A, 8-B formatı)
            if not sinif and re.match(r'^\d+-[A-Z]{1,2}$', cell_str):
                sinif = cell_str

        # LGS puanını ve sıralamaları bul
        # Stratejı: Sağdan sola, LGS puanı 200-600 arasında ondalıklı sayı
        # Sıralamalar ise küçük tam sayılar (1-100 arası genelde)

        numeric_cells = []
        for i, cell in enumerate(row):
            if not cell:
                continue
            cell_str = str(cell).strip()
            try:
                # Virgülü noktaya çevir
                val_str = cell_str.replace(',', '.')
                val = float(val_str)
                is_integer = ',' not in str(cell) and '.' not in str(cell)
                numeric_cells.append({
                    'index': i,
                    'value': val,
                    'is_integer': is_integer,
                    'original': cell_str
                })
            except:
                pass

        # Sağdan sola sıralayıp analiz et
        numeric_cells.reverse()

        # LGS puanını bul (200-600 arası, ondalıklı olması tercih)
        lgs_candidates = []
        for nc in numeric_cells:
            if 200 <= nc['value'] <= 600:
                priority = nc['index'] * 10  # Sağdaki öncelikli
                if not nc['is_integer']:  # Ondalıklı
                    priority += 200
                if nc['value'] >= 250:
                    priority += 50
                lgs_candidates.append((nc, priority))

        if lgs_candidates:
            lgs_candidates.sort(key=lambda x: x[1], reverse=True)
            lgs_cell = lgs_candidates[0][0]
            lgs_puan = lgs_cell['value']
            lgs_index = lgs_cell['index']

            # LGS puanından sonraki 5 küçük sayı sıralamalar olabilir
            # Sıralama sırası (sağdan sola): Genel, İl, İlçe, Okul, Sınıf
            siralama_cells = [nc for nc in numeric_cells if nc['index'] > lgs_index and nc['is_integer'] and 1 <= nc['value'] <= 200]

            # İndekse göre sırala (büyükten küçüğe, yani sağdan sola)
            siralama_cells.sort(key=lambda x: x['index'], reverse=True)

            # İlk 5 sıralamayı al
            if len(siralama_cells) >= 5:
                genel_sira = int(siralama_cells[0]['value'])
                il_sira = int(siralama_cells[1]['value'])
                ilce_sira = int(siralama_cells[2]['value'])
                okul_sira = int(siralama_cells[3]['value'])
                sinif_sira = int(siralama_cells[4]['value'])
            elif len(siralama_cells) >= 1:
                # En azından sınıf sırası var
                sinif_sira = int(siralama_cells[-1]['value'])

        # Eğer öğrenci bilgileri bulunduysa ekle
        if isim and sinif:
            results.append({
                'ogrenci_no': ogrenci_no or "0",
                'isim': isim,
                'sinif': sinif,
                'lgs_puan': lgs_puan or 0.0,
                'sinif_sira': sinif_sira,
                'okul_sira': okul_sira,
                'ilce_sira': ilce_sira,
                'il_sira': il_sira,
                'genel_sira': genel_sira
            })

    return results


def parse_tek_exam_name(text: str) -> Optional[str]:
    """PDF'den sınav adını çıkarır"""
    # "8. SINIF 2.DENEME" gibi
    patterns = [
        r'(\d+\.\s*SINIF.*?DENEME)',
        r'(DENEME\s*SINAV[IİĐ]*\s*-?\s*\d+)',
        r'(\d+\.\s*DENEME)',
    ]

    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1).strip()

    return None


def parse_tek_pdf(pdf_bytes: bytes) -> Dict:
    """
    TEK yayınları PDF'ini parse eder

    Returns:
        {
            'sinav_adi': str,
            'ogrenciler': [
                {
                    'ogrenci_no': str,
                    'isim': str,
                    'sinif': str,
                    'lgs_puan': float
                }
            ]
        }
    """
    import pdfplumber
    import io

    pdf_file = io.BytesIO(pdf_bytes)

    sinav_adi = None
    all_results = []

    with pdfplumber.open(pdf_file) as pdf:
        for page in pdf.pages:
            # Metin çıkar
            text = page.extract_text()

            # Sınav adını bul
            if not sinav_adi and text:
                sinav_adi = parse_tek_exam_name(text)

            # Tabloları çıkar
            tables = page.extract_tables()

            for table in tables:
                results = parse_tek_pdf_table(table)
                all_results.extend(results)

    return {
        'sinav_adi': sinav_adi or "Sınav",
        'ogrenciler': all_results
    }
