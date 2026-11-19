"""${message}"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
${imports if imports else ''}

# Identificadores de esta revisión.
revision: str = ${repr(up_revision)}
down_revision: Union[str, None] = ${repr(down_revision)}
branch_labels: Union[str, Sequence[str], None] = ${repr(branch_labels)}
depends_on: Union[str, Sequence[str], None] = ${repr(depends_on)}


def upgrade() -> None:
    """Aplica los cambios de esta revisión."""
    ${upgrades if upgrades else 'pass'}


def downgrade() -> None:
    """Revierte los cambios de esta revisión."""
    ${downgrades if downgrades else 'pass'}
