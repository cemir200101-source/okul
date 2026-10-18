# auth.py

from datetime import datetime, timedelta
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session
import hashlib

from database import SessionLocal
import models

SECRET_KEY = "vBroUdudMqVHQrjIUOAhuh-w_sdtRvdl291tJTbTzfM"  # Generate new key with: python -c "import secrets; print(secrets.token_urlsafe(32))"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# ---- DB session ----
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ---- Şifre fonksiyonları ----
def get_password_hash(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

def verify_password(plain: str, hashed: str) -> bool:
    return get_password_hash(plain) == hashed

# ---- Kullanıcı bulma ----
def get_user_by_username(db: Session, username: str) -> Optional[models.AdminUser]:
    return (
        db.query(models.AdminUser)
        .filter(models.AdminUser.kullanici_adi == username)
        .first()
    )

def authenticate_user(db: Session, username: str, password: str) -> Optional[models.AdminUser]:
    user = get_user_by_username(db, username)
    if not user:
        return None
    if not verify_password(password, user.sifre_hash):
        return None
    return user

# ---- JWT oluşturma ----
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# ---- Giriş yapmış kullanıcıyı çöz ----
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> models.AdminUser:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik doğrulama başarısız.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str | None = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = get_user_by_username(db, username)
    if user is None:
        raise credentials_exception
    return user

# ---- Rol helper'ları ----
def get_current_admin(
    current_user: models.AdminUser = Depends(get_current_user),
) -> models.AdminUser:
    if current_user.rol != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu işlem için admin yetkisi gerekli.",
        )
    return current_user

def get_current_mudur(
    current_user: models.AdminUser = Depends(get_current_user),
) -> models.AdminUser:
    if current_user.rol not in ("mudur", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu işlem için müdür yetkisi gerekli.",
        )
    return current_user

def get_current_veli(
    current_user: models.AdminUser = Depends(get_current_user),
) -> models.AdminUser:
    if current_user.rol not in ("veli", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu işlem için veli yetkisi gerekli.",
        )
    if current_user.ogrenci_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu kullanıcıya bağlı öğrenci bulunamadı.",
        )
    return current_user

def ensure_school_access(current_user, requested_okul_id: int):
    # admin her şeyi görür
    if current_user.rol == "admin":
        return

    # müdür sadece kendi okulunu görür
    if current_user.rol == "mudur":
        if current_user.okul_id != requested_okul_id:
            raise HTTPException(status_code=403, detail="Bu okula erişim yok.")
        return

    # veli okul bazlı endpointlere giremez
    raise HTTPException(status_code=403, detail="Bu işlem için yetkin yok.")
