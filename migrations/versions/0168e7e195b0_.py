"""empty message

Revision ID: 0168e7e195b0
Revises: d3d011cf9717
Create Date: 2021-04-22 16:26:15.737705

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0168e7e195b0'
down_revision = 'd3d011cf9717'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table('allies',
    sa.Column('left_id', sa.Integer(), nullable=True),
    sa.Column('right_id', sa.Integer(), nullable=True),
    sa.ForeignKeyConstraint(['left_id'], ['user.id'], ),
    sa.ForeignKeyConstraint(['right_id'], ['user.id'], )
    )
    op.drop_table('connections')
    op.create_unique_constraint(None, 'club', ['id'])
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_constraint(None, 'club', type_='unique')
    op.create_table('connections',
    sa.Column('left_id', sa.INTEGER(), autoincrement=False, nullable=True),
    sa.Column('right_id', sa.INTEGER(), autoincrement=False, nullable=True),
    sa.ForeignKeyConstraint(['left_id'], ['user.id'], name='connections_left_id_fkey'),
    sa.ForeignKeyConstraint(['right_id'], ['user.id'], name='connections_right_id_fkey')
    )
    op.drop_table('allies')
    # ### end Alembic commands ###
