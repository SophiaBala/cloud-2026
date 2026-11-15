from my_project import db


class ProcessedJob(db.Model):
    __tablename__ = 'processed_jobs'
    job_id = db.Column(db.String(36), primary_key=True)
    shop_id = db.Column(db.Integer, nullable=False)
    processed_at = db.Column(db.DateTime, server_default=db.func.now(), nullable=False)
