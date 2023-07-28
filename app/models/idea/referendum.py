from app import db
import app.models as models
from app.models.base import Base
from sqlalchemy.ext.hybrid import hybrid_method, hybrid_property

class Referendum(db.Model, Base):
	id = db.Column(db.Integer, primary_key=True)
	entity_id = db.Column(db.Integer, db.ForeignKey('idea.id', ondelete='CASCADE'))
	clock = db.Column(db.Integer) # clock of issuance, used to identify
	status = db.Column(db.Integer,default=0) # status, #0: issued, #1 closed, #2 implemented
	
	viable_amount = db.Column(db.Integer) # total amount of possible eligible votes
	cast_amount = db.Column(db.Integer, default=0) # total amount of votes cast
	in_favor_amount = db.Column(db.Integer,default=0) # total amount of votes cast in favor

	votes = db.relationship(
        'Vote', lazy='dynamic',
        foreign_keys='Vote.referendum_id', passive_deletes=True)
	proposals = db.relationship(
        'Proposal', lazy='dynamic',
        foreign_keys='Proposal.referendum_id', passive_deletes=True)

	@hybrid_property
	def proposal_amount(self):
		return self.proposals.count()

	@hybrid_property
	def amount_implemented(self):
		return self.proposals.filter_by(implemented=True).count()
	
	def __repr__(self):
		return '<Referendum {}>'.format(self.clock)

class Proposal(db.Model, Base):
	id = db.Column(db.Integer, primary_key=True)
	referendum_id = db.Column(db.Integer, db.ForeignKey('referendum.id', ondelete='CASCADE'))
	index = db.Column(db.Integer) # Index as part of Referendum proposals
	func = db.Column(db.String) # Name of func to be called during implementation.
	args = db.Column(db.LargeBinary) # The encoded args passed to func call during implementation.
	implemented = db.Column(db.Boolean, default=False) # states if implemented yet or not
	def __repr__(self):
		return '<Proposal {}>'.format(self.func)

class Vote(db.Model, Base):
	id = db.Column(db.Integer, primary_key=True)
	referendum_id = db.Column(db.Integer, db.ForeignKey('referendum.id', ondelete='CASCADE'))
	shard_id = db.Column(db.Integer) 
	shard = db.relationship("Shard", foreign_keys=[shard_id]) # the shard used to claim dividend
	in_favor = db.Column(db.Boolean) # states if in favors or not

	def __repr__(self):
		return '<Vote {} {}>'.format(self.amount, "FAVOR" if self.in_favor else "AGAINST")

