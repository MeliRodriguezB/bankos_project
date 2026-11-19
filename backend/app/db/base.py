from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """
    Clase base para todos los modelos ORM de SQLAlchemy.
    Permite el mapeo declarativo moderno (SQLAlchemy 2.0).
    Todos los modelos heredarán de esta clase para registrarse en el metadata de la BD.
    """
    pass
