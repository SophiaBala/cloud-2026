import os
from flask import Flask
from my_project import db
from my_project.auth.domain import Shop, Products, ShopProducts

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
    db.create_all()


@app.route("/health")
def health():
    return {"status": "ok"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)