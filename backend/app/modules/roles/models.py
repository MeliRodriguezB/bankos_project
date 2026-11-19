from uuid import UUID

from sqlalchemy import (
    Boolean,
    Column,
    ForeignKey,
    ForeignKeyConstraint,
    String,
    Table,
    Text,
    UniqueConstraint,
    Uuid,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


# Relación muchos-a-muchos entre roles y permisos.
role_permissions = Table(
    "role_permissions",
    Base.metadata,
    Column("role_id", Uuid(as_uuid=True), ForeignKey("roles.id"), primary_key=True),
    Column(
        "permission_id",
        Uuid(as_uuid=True),
        ForeignKey("permissions.id"),
        primary_key=True,
    ),
)


# La clave compuesta obliga a que la membresía y el rol
# pertenezcan a la misma institución.
membership_roles = Table(
    "membership_roles",
    Base.metadata,
    Column("tenant_id", Uuid(as_uuid=True), nullable=False),
    Column("membership_id", Uuid(as_uuid=True), primary_key=True),
    Column("role_id", Uuid(as_uuid=True), primary_key=True),
    ForeignKeyConstraint(
        ["tenant_id", "membership_id"],
        ["tenant_memberships.tenant_id", "tenant_memberships.id"],
        name="fk_mr_membership",
    ),
    ForeignKeyConstraint(
        ["tenant_id", "role_id"],
        ["roles.tenant_id", "roles.id"],
        name="fk_mr_role",
    ),
)


class Role(Base):
    """Rol definido dentro de una institución."""

    __tablename__ = "roles"
    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_roles_tenant_code"),
        UniqueConstraint("tenant_id", "id", name="uq_roles_tenant_id"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    tenant_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    is_system: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("FALSE")
    )


class Permission(Base):
    """Acción que puede autorizarse mediante un rol."""

    __tablename__ = "permissions"

    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    code: Mapped[str] = mapped_column(String(80), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
