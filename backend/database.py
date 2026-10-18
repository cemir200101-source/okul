from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

SQLALCHEMY_DATABASE_URL = "sqlite:///./school_analytics.db"


engine = create_engine( #Veritabanını açar
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False}  # SQLite için gerekli
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine) #Her istek için ayrı session kullanır

Base = declarative_base() #Bütün veritabanının temel sınıfı

Base.metadata.create_all(bind=engine)
