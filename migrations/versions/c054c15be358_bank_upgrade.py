"""bank upgrade

Revision ID: c054c15be358
Revises: 6c7161647ba8
Create Date: 2023-07-28 18:14:56.226391

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'c054c15be358'
down_revision = '6c7161647ba8'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table('external_token_receipt',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('token_address', sa.String(length=42), nullable=True),
    sa.Column('value', sa.Integer(), nullable=True),
    sa.Column('timestamp', sa.BigInteger(), nullable=True),
    sa.Column('bank_id', sa.Integer(), nullable=True),
    sa.Column('sender_address', sa.String(length=42), nullable=True),
    sa.ForeignKeyConstraint(['bank_id'], ['bank.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_table('external_token_transfer',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('token_address', sa.String(length=42), nullable=True),
    sa.Column('value', sa.Integer(), nullable=True),
    sa.Column('timestamp', sa.BigInteger(), nullable=True),
    sa.Column('bank_id', sa.Integer(), nullable=True),
    sa.Column('by_address', sa.String(length=42), nullable=True),
    sa.Column('recipient_address', sa.String(length=42), nullable=True),
    sa.ForeignKeyConstraint(['bank_id'], ['bank.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_table('internal_token_exchange',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('token_address', sa.String(length=42), nullable=True),
    sa.Column('value', sa.Integer(), nullable=True),
    sa.Column('timestamp', sa.BigInteger(), nullable=True),
    sa.Column('recipient_bank_id', sa.Integer(), nullable=True),
    sa.Column('sender_bank_id', sa.Integer(), nullable=True),
    sa.Column('by_address', sa.String(length=42), nullable=True),
    sa.ForeignKeyConstraint(['recipient_bank_id'], ['bank.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['sender_bank_id'], ['bank.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('dividend', schema=None) as batch_op:
        batch_op.add_column(sa.Column('residual', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('dissolved', sa.Boolean(), nullable=True))

    with op.batch_alter_table('idea', schema=None) as batch_op:
        batch_op.add_column(sa.Column('active', sa.Boolean(), nullable=True))
        batch_op.add_column(sa.Column('total_amount', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('events_last_updated_at', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('shards_last_updated_at', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('bank_exchanges_last_updated_at', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('dividend_claims_last_updated_at', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('referendum_votes_last_updated_at', sa.Integer(), nullable=True))
        batch_op.drop_column('timeline_last_updated_at')
        batch_op.drop_column('structure_last_updated_at')
        batch_op.drop_column('ownership_last_updated_at')

    with op.batch_alter_table('proposal', schema=None) as batch_op:
        batch_op.add_column(sa.Column('index', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('implemented', sa.Boolean(), nullable=True))

    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    with op.batch_alter_table('proposal', schema=None) as batch_op:
        batch_op.drop_column('implemented')
        batch_op.drop_column('index')

    with op.batch_alter_table('idea', schema=None) as batch_op:
        batch_op.add_column(sa.Column('ownership_last_updated_at', sa.INTEGER(), autoincrement=False, nullable=True))
        batch_op.add_column(sa.Column('structure_last_updated_at', sa.INTEGER(), autoincrement=False, nullable=True))
        batch_op.add_column(sa.Column('timeline_last_updated_at', sa.INTEGER(), autoincrement=False, nullable=True))
        batch_op.drop_column('referendum_votes_last_updated_at')
        batch_op.drop_column('dividend_claims_last_updated_at')
        batch_op.drop_column('bank_exchanges_last_updated_at')
        batch_op.drop_column('shards_last_updated_at')
        batch_op.drop_column('events_last_updated_at')
        batch_op.drop_column('total_amount')
        batch_op.drop_column('active')

    with op.batch_alter_table('dividend', schema=None) as batch_op:
        batch_op.drop_column('dissolved')
        batch_op.drop_column('residual')

    op.drop_table('internal_token_exchange')
    op.drop_table('external_token_transfer')
    op.drop_table('external_token_receipt')
    # ### end Alembic commands ###
