from flask import Blueprint, request, jsonify
from my_project import cache
from my_project.auth.service.shop_service import ShopService
from my_project.auth.domain.staff import Staff

shop_bp = Blueprint('shop_bp', __name__)

DEFAULT_LIMIT = 50
MAX_LIMIT = 200

def _shop_json(s):
    return {"id": s.idshop, "address": s.address, "phone": s.phone, "city": s.city}

@shop_bp.route('/shop', methods=['GET'])
def get_shop():
    limit = max(1, min(request.args.get('limit', DEFAULT_LIMIT, type=int), MAX_LIMIT))
    key = f"shops:list:{limit}"

    data, status = cache.get_json(key)
    if data is None:
        data = [_shop_json(s) for s in ShopService.get_latest_shops(limit)]
        cache.set_json(key, data)

    resp = jsonify(data)
    resp.headers['X-Cache'] = status
    return resp

@shop_bp.route('/shop/<int:shop_id>', methods=['GET'])
def get_shop_by_id(shop_id):
    shop = ShopService.get_shop(shop_id)
    if not shop:
        return jsonify({"error": "Shop not found"}), 404
    return jsonify(_shop_json(shop))

@shop_bp.route('/shop/<int:shop_id>/staff', methods=['GET'])
def get_shop_staff(shop_id):
    staff = Staff.query.filter_by(shop_idshop=shop_id).all()
    return jsonify([s.to_dict() for s in staff])

@shop_bp.route('/shop', methods=['POST'])
def create_shop():
    data = request.get_json()
    if not data:
        return jsonify({"error": "No input data provided"}), 400
    
    try:
        new_shop = ShopService.create_shop(data)
        return jsonify(new_shop.to_dict()), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@shop_bp.route('/shop/<int:shop_id>', methods=['PUT'])
def update_shop(shop_id):
    data = request.get_json()
    shop = ShopService.update_shop(shop_id, data)
    if shop:
        return jsonify(_shop_json(shop))
    return jsonify({"error": "Shop not found"}), 404

@shop_bp.route('/shop/<int:shop_id>', methods=['DELETE'])
def delete_shop(shop_id):
    shop = ShopService.delete_shop(shop_id)
    if shop:
        return jsonify({"message": "Shop deleted"})
    return jsonify({"error": "Shop not found"}), 404
