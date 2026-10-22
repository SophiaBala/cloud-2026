import os
from flask import Flask
from my_project import db
from my_project.auth.domain import Shop, Products, ShopProducts
import time
from sqlalchemy.exc import OperationalError, DatabaseError

from my_project.auth.route.shop_route import shop_bp
from my_project.auth.route.products_route import products_bp
from my_project.auth.route.shop_products_route import shop_products_bp
from my_project.auth.route.categories_route import categories_bp
from my_project.auth.route.staff_route import staff_bp

app = Flask(__name__)

app.config["SQLALCHEMY_DATABASE_URI"] = (
    f"mysql+mysqlconnector://{os.environ['DB_USER']}:{os.environ['DB_PASSWORD']}"
    f"@{os.environ['DB_HOST']}:{os.environ.get('DB_PORT', '3306')}"
    f"/{os.environ['DB_NAME']}"
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db.init_app(app)

app.register_blueprint(shop_bp)
app.register_blueprint(products_bp)
app.register_blueprint(shop_products_bp)
app.register_blueprint(categories_bp)
app.register_blueprint(staff_bp)

with app.app_context():
    for attempt in range(20):
        try:
            db.create_all()
            break
        except (OperationalError, DatabaseError):
            print(f"DB not ready, retry {attempt + 1}/20", flush=True)
            time.sleep(3)
    else:
        raise RuntimeError("Database is unavailable")

@app.route("/health")
def health():
    return {"status": "ok"}, 200

@app.route("/")
def index():
    return {"service": "shop api", "status": "running"}, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)