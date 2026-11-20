from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, get_db, require_roles
from app.modules.tenants.models import Tenant
from app.modules.tenants.schemas import TenantConfigResponse, TenantConfigUpdate

router = APIRouter(prefix="/tenant", tags=["Tenant Configuration"])


@router.get("/config", response_model=TenantConfigResponse)
def get_tenant_config(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    tenant = db.query(Tenant).filter(
        Tenant.id == UUID(current_user["tenant_id"])
    ).first()
    if tenant is None:
        raise HTTPException(status_code=404, detail="Institución no encontrada.")
    return tenant


@router.patch("/config", response_model=TenantConfigResponse)
def update_tenant_config(
    payload: TenantConfigUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles("ADMIN")),
):
    tenant = db.query(Tenant).filter(
        Tenant.id == UUID(current_user["tenant_id"])
    ).with_for_update().first()
    if tenant is None:
        raise HTTPException(status_code=404, detail="Institución no encontrada.")

    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Debes enviar al menos un parámetro para actualizar.",
        )

    if "primary_currency" in changes:
        primary = changes["primary_currency"]
        supported = changes.get("supported_currencies", tenant.supported_currencies)
        if primary not in supported:
            raise HTTPException(
                status_code=422,
                detail="La moneda principal debe estar incluida en las monedas soportadas.",
            )

    if "supported_currencies" in changes:
        supported = changes["supported_currencies"]
        primary = changes.get("primary_currency", tenant.primary_currency)
        if primary not in supported:
            raise HTTPException(
                status_code=422,
                detail="No puedes excluir la moneda principal de las monedas soportadas.",
            )

    supported = changes.get("supported_currencies", tenant.supported_currencies)
    if "transfer_fees" in changes and any(
        currency not in supported for currency in changes["transfer_fees"]
    ):
        raise HTTPException(
            status_code=422,
            detail="Solo puedes configurar comisiones para monedas soportadas.",
        )
    if "exchange_rates" in changes and any(
        currency not in supported
        for pair in changes["exchange_rates"]
        for currency in pair.split("/")
    ):
        raise HTTPException(
            status_code=422,
            detail="Las tasas solo pueden utilizar monedas soportadas por la institución.",
        )

    if "webhook_url" in changes and changes["webhook_url"] is not None:
        changes["webhook_url"] = str(changes["webhook_url"])

    if "transfer_fees" in changes:
        changes["transfer_fees"] = {
            currency: str(amount) for currency, amount in changes["transfer_fees"].items()
        }
    if "exchange_rates" in changes:
        changes["exchange_rates"] = {
            pair: str(rate) for pair, rate in changes["exchange_rates"].items()
        }

    for field, value in changes.items():
        setattr(tenant, field, value)

    db.commit()
    db.refresh(tenant)
    return tenant
