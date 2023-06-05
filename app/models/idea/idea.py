from app import db
from sqlalchemy.ext.hybrid import hybrid_method, hybrid_property
import app.models.idea.group
from app.models.static.photo import Photo
from app.models.base import Base
from app.models.locationBase import locationBase
from flask import url_for

class Idea(db.Model, Base, locationBase):
    id = db.Column(db.Integer, primary_key=True)
    address = db.Column(db.String(42)) # ETH address
    symbol = "$"
    group_id = db.Column(db.Integer, db.ForeignKey('group.id', ondelete="cascade"))
    group = db.relationship("Group", foreign_keys=[group_id])
    handle = db.Column(db.String, index=True, unique=True)
    name = db.Column(db.String)
    description = db.Column(db.String)
    public = db.Column(db.Boolean, default=False)

    photo_id = db.Column(db.Integer, db.ForeignKey('photo.id'))
    photo = db.relationship("Photo", foreign_keys=[photo_id])

    def __init__(self, **kwargs):
        super(Idea, self).__init__(**{k: kwargs[k] for k in kwargs if k != "members"})
        # do custom initialization here
        members = kwargs["members"]
        self.group = app.models.idea.group.Group(members=members)
        for user in members:
            self.add_member(user)
        self.photo = Photo(filename="photo", path=f"static/ideas/{self.handle}/photo/", replacement="/static/images/idea.jpg")

    def add_member(self, user):
        self.group.members.append(user)

    def remove_member(self, user):
        self.group.members.remove(user)

    def delete(self):
        for m in self.group.members:
            m.ideas.remove(self)
        if self.exists_in_db:
            db.session.delete(self.group)
            db.session.delete(self)

    @property
    def href(self):
        return url_for("idea", handle=self.handle)

    @hybrid_property
    def identifier(self):
        return self.handle

    def __repr__(self):
        return "<Idea €{}>".format(self.handle)
