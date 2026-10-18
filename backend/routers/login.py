# routers/auth.py

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

import models, schemas
from auth import (
    get_db,
    authenticate_user,
    create_access_token,
    get_password_hash,
    get_current_admin,
    get_current_user,
    ACCESS_TOKEN_EXPIRE_MINUTES,
)

router = APIRouter(prefix="/auth", tags=["Auth"])

# --- Get current user info ---
@router.get("/me")
def get_current_user_info(
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    """Mevcut kullanıcı bilgilerini getir"""
    okul_ids = None
    if current_user.rol == "mudur":
        okul_ids = [okul.id for okul in current_user.okullar]

    return {
        "id": current_user.id,
        "kullanici_adi": current_user.kullanici_adi,
        "email": current_user.email,
        "rol": current_user.rol,
        "okul_id": current_user.okul_id,
        "ogrenci_id": current_user.ogrenci_id,
        "okul_ids": okul_ids,
    }

# --- Update current user profile ---
@router.put("/me")
def update_current_user_profile(
    update_data: dict,
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_user),
):
    """Kendi profil bilgilerini güncelle"""
    # Email güncellemesi
    if "email" in update_data and update_data["email"]:
        # Email başka bir kullanıcıda var mı kontrol et
        existing = db.query(models.AdminUser).filter(
            models.AdminUser.email == update_data["email"],
            models.AdminUser.id != current_user.id
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail="Bu e-posta adresi zaten kullanılıyor")
        current_user.email = update_data["email"]

    # Şifre değiştirme
    if "current_password" in update_data and "new_password" in update_data:
        from auth import verify_password, get_password_hash

        # Mevcut şifreyi kontrol et
        if not verify_password(update_data["current_password"], current_user.sifre_hash):
            raise HTTPException(status_code=400, detail="Mevcut şifre hatalı")

        # Yeni şifreyi hash'le ve kaydet
        current_user.sifre_hash = get_password_hash(update_data["new_password"])

    db.commit()
    db.refresh(current_user)

    return {
        "message": "Profil başarıyla güncellendi",
        "kullanici_adi": current_user.kullanici_adi,
        "email": current_user.email,
    }

# --- Admin yeni kullanıcı açar ---
@router.post("/register")
def register_user(
    user_in: schemas.KullaniciCreate,
    db: Session = Depends(get_db),
    current_admin: models.AdminUser = Depends(get_current_admin),
):
    # aynı kullanıcı var mı?
    existing = (
        db.query(models.AdminUser)
        .filter(models.AdminUser.kullanici_adi == user_in.kullanici_adi)
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Bu kullanıcı adı zaten var.")

    hashed_pw = get_password_hash(user_in.sifre)

    yeni = models.AdminUser(
        kullanici_adi=user_in.kullanici_adi,
        sifre_hash=hashed_pw,
        email=user_in.email,
        rol=user_in.rol,                # "admin" / "mudur" / "ogretmen" / "veli"
        ogrenci_id=user_in.ogrenci_id,  # veli ise doldur
        okul_id=user_in.okul_id,        # ogretmen ise doldur
    )
    db.add(yeni)
    db.flush()  # ID'yi almak için flush

    # Müdür ise, okul_ids listesini many-to-many tabloya ekle
    if user_in.rol == "mudur" and hasattr(user_in, 'okul_ids') and user_in.okul_ids:
        for okul_id in user_in.okul_ids:
            okul = db.query(models.Okul).filter(models.Okul.id == okul_id).first()
            if okul:
                yeni.okullar.append(okul)

    db.commit()
    db.refresh(yeni)

    return {"id": yeni.id, "kullanici_adi": yeni.kullanici_adi, "rol": yeni.rol}

# --- Login ---
@router.post("/login", response_model=schemas.Token)
def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Hatalı kullanıcı adı veya şifre.",
        )

    # Müdür ise okul_ids listesini al
    okul_ids = None
    if user.rol == "mudur":
        okul_ids = [okul.id for okul in user.okullar]

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={
            "sub": user.kullanici_adi,
            "rol": user.rol,
            "ogrenci_id": user.ogrenci_id,
            "okul_id": user.okul_id,
            "okul_ids": okul_ids,
        },
        expires_delta=access_token_expires,
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "username": user.kullanici_adi,
        "role": user.rol,
        "ogrenci_id": user.ogrenci_id,
        "okul_id": user.okul_id,
        "okul_ids": okul_ids,
    }

# --- Kullanıcı Listesi (Admin) ---
@router.get("/users")
def list_users(
    db: Session = Depends(get_db),
    current_admin: models.AdminUser = Depends(get_current_admin),
):
    """Tüm kullanıcıları listele (sadece admin)"""
    users = db.query(models.AdminUser).all()
    return [
        {
            "id": u.id,
            "kullanici_adi": u.kullanici_adi,
            "email": u.email,
            "rol": u.rol,
            "okul_id": u.okul_id,
            "ogrenci_id": u.ogrenci_id,
            "okul_ids": [okul.id for okul in u.okullar] if u.rol == "mudur" else None,
        }
        for u in users
    ]

# --- Kullanıcı Güncelle (Admin) ---
@router.put("/users/{user_id}")
def update_user(
    user_id: int,
    update_data: dict,
    db: Session = Depends(get_db),
    current_admin: models.AdminUser = Depends(get_current_admin),
):
    """Kullanıcı bilgilerini güncelle (sadece admin)"""
    user = db.query(models.AdminUser).filter(models.AdminUser.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    # JSON body'den gelen verileri işle
    if "kullanici_adi" in update_data and update_data["kullanici_adi"]:
        user.kullanici_adi = update_data["kullanici_adi"]
    if "email" in update_data and update_data["email"]:
        user.email = update_data["email"]
    if "rol" in update_data and update_data["rol"]:
        user.rol = update_data["rol"]
    if "okul_id" in update_data:
        user.okul_id = update_data["okul_id"]

    # Müdür için okul_ids güncellemesi
    if "okul_ids" in update_data and user.rol == "mudur":
        # Mevcut okulları temizle
        user.okullar.clear()
        # Yeni okulları ekle
        if update_data["okul_ids"]:
            for okul_id in update_data["okul_ids"]:
                okul = db.query(models.Okul).filter(models.Okul.id == okul_id).first()
                if okul:
                    user.okullar.append(okul)

    db.commit()
    db.refresh(user)

    return {
        "id": user.id,
        "kullanici_adi": user.kullanici_adi,
        "email": user.email,
        "rol": user.rol,
        "okul_id": user.okul_id,
        "okul_ids": [okul.id for okul in user.okullar] if user.rol == "mudur" else None,
    }

# --- Kullanıcı Sil (Admin) ---
@router.delete("/users/{user_id}")
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_admin: models.AdminUser = Depends(get_current_admin),
):
    """Kullanıcıyı sil (sadece admin)"""
    user = db.query(models.AdminUser).filter(models.AdminUser.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    # Kendini silmeye çalışıyorsa engelle
    if user.id == current_admin.id:
        raise HTTPException(status_code=400, detail="Kendi hesabınızı silemezsiniz")

    db.delete(user)
    db.commit()

    return {"success": True, "message": "Kullanıcı silindi"}

# --- Dashboard İstatistikleri ---
@router.get("/dashboard/stats")
def get_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: models.AdminUser = Depends(get_current_admin),
):
    """Dashboard için genel istatistikler"""
    stats = {}

    # Admin için tüm istatistikler
    if current_user.rol == "admin":
        stats["total_schools"] = db.query(models.Okul).count()
        stats["total_users"] = db.query(models.AdminUser).count()
        stats["total_classes"] = db.query(models.Sinif).count()
        stats["total_students"] = db.query(models.Ogrenci).count()
        stats["total_exams"] = db.query(models.Sinav).count()

        # Rol bazında kullanıcı sayıları
        stats["users_by_role"] = {
            "admin": db.query(models.AdminUser).filter(models.AdminUser.rol == "admin").count(),
            "mudur": db.query(models.AdminUser).filter(models.AdminUser.rol == "mudur").count(),
            "ogretmen": db.query(models.AdminUser).filter(models.AdminUser.rol == "ogretmen").count(),
            "veli": db.query(models.AdminUser).filter(models.AdminUser.rol == "veli").count(),
        }

    # Müdür için kendi okullarının istatistikleri
    elif current_user.rol == "mudur":
        # Müdürün okul ID'leri
        okul_ids = [okul.id for okul in current_user.okullar]

        stats["my_schools_count"] = len(okul_ids)
        stats["total_classes"] = db.query(models.Sinif).filter(models.Sinif.okul_id.in_(okul_ids)).count()
        stats["total_students"] = db.query(models.Ogrenci).join(models.Sinif).filter(
            models.Sinif.okul_id.in_(okul_ids)
        ).count()
        stats["total_exams"] = db.query(models.Sinav).filter(models.Sinav.sinif_id.in_(
            db.query(models.Sinif.id).filter(models.Sinif.okul_id.in_(okul_ids))
        )).count()

        # Okulları listele
        stats["my_schools"] = [
            {"id": okul.id, "isim": okul.isim} for okul in current_user.okullar
        ]

    # Öğretmen için okul istatistikleri
    elif current_user.rol == "ogretmen":
        if current_user.okul_id:
            stats["school_id"] = current_user.okul_id
            okul = db.query(models.Okul).filter(models.Okul.id == current_user.okul_id).first()
            stats["school_name"] = okul.isim if okul else "Bilinmeyen"

            stats["total_classes"] = db.query(models.Sinif).filter(
                models.Sinif.okul_id == current_user.okul_id
            ).count()
            stats["total_students"] = db.query(models.Ogrenci).join(models.Sinif).filter(
                models.Sinif.okul_id == current_user.okul_id
            ).count()

    return stats
