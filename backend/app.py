from flask import Flask, request, jsonify, send_from_directory
from book_matcher import find_book_logic
from flask_cors import CORS
import os
import uuid
import subprocess
import json
import shutil
import cv2
import sys

app = Flask(__name__)
CORS(app)

# =========================================================
# KLASÖRLER
# =========================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
SHELVES_FOLDER = os.path.join(BASE_DIR, "shelves")
PIPELINE_SCRIPT = os.path.join(BASE_DIR, "book_detection_pipeline.py")
CROPPED_BEFORE_DIR = os.path.join(BASE_DIR, "cropped_books_before")
CROPPED_AFTER_DIR = os.path.join(BASE_DIR, "cropped_books_after")

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(SHELVES_FOLDER, exist_ok=True)


# =========================================================
# YARDIMCI: İSİM NORMALİZASYONU
# =========================================================
def normalize_name(name):
    name = name.lower().replace(" ", "_")
    allowed = "abcdefghijklmnopqrstuvwxyz0123456789_"
    return "".join(c for c in name if c in allowed)


# =========================================================
# 1) KİTAPLIK OLUŞTURMA
# =========================================================
@app.post("/create_shelf")
def create_shelf():
    try:
        shelf_name = request.form.get("shelf_name")
        if not shelf_name:
            return jsonify({"error": "shelf_name is required"}), 400

        norm_name = normalize_name(shelf_name)
        shelf_path = os.path.join(SHELVES_FOLDER, norm_name)

        # Kitaplık klasörünü temizle
        if os.path.exists(shelf_path):
            shutil.rmtree(shelf_path)

        os.makedirs(shelf_path)
        os.makedirs(os.path.join(shelf_path, "images"))

        raf_fotograflari = request.files.getlist("raf_fotograflari")
        if not raf_fotograflari:
            return jsonify({"error": "no raf_fotograflari uploaded"}), 400

        raf_index = 1

        for raf in raf_fotograflari:
            raf_path = os.path.join(shelf_path, f"raf_{raf_index}.jpg")
            raf.save(raf_path)

            # TEK VE DOĞRU PIPELINE
            subprocess.run(
                [sys.executable, PIPELINE_SCRIPT, raf_path, raf_path],
                check=True,
                cwd=BASE_DIR
            )

            kirpilmis_dir = CROPPED_AFTER_DIR
            kitaplar = sorted(
                os.listdir(kirpilmis_dir),
                key=lambda x: int(x.split("_")[1].split(".")[0])
            )

            raf_json = []
            sira = 0

            for kitap in kitaplar:
                old_path = os.path.join(kirpilmis_dir, kitap)
                new_id = f"{norm_name}_{sira}"
                new_img_path = os.path.join(
                    shelf_path, "images", f"{new_id}.jpg"
                )

                shutil.copy(old_path, new_img_path)

                raf_json.append({
                    "id": new_id,
                    "image": f"images/{new_id}.jpg",
                    "sira": sira
                })

                sira += 1

            with open(os.path.join(shelf_path, f"raf_{raf_index}.json"), "w") as f:
                json.dump(raf_json, f, indent=4)

            raf_index += 1

        return jsonify({
            "status": "ok",
            "kitaplik": norm_name,
            "raf_sayisi": raf_index - 1
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.post("/find_book")
def find_book():
    try:
        book_id = request.form.get("book_id")
        if not book_id:
            return jsonify({"error": "book_id is required"}), 400

        if "image" not in request.files:
            return jsonify({"error": "image is required"}), 400

        # -------------------------------------------------
        # 1️ Fotoğrafı kaydet
        # -------------------------------------------------
        img_file = request.files["image"]
        filename = f"search_{uuid.uuid4().hex}.jpg"
        filepath = os.path.join(UPLOAD_FOLDER, filename)
        img_file.save(filepath)

        # -------------------------------------------------
        # 2️ Seçilen kitabın yolunu bul
        # -------------------------------------------------
        shelf_name, book_index = book_id.rsplit("_", 1)

        print(shelf_name)
        book_image_path = os.path.join(
            SHELVES_FOLDER,
            shelf_name,
            "images",
            f"{book_id}.jpg"
        )
        print(book_image_path)

        if not os.path.exists(book_image_path):
            return jsonify({"error": "book_image_not_found"}), 404

        # -------------------------------------------------
        #  PIPELINE (tek ve doğru)
        # -------------------------------------------------
        subprocess.run(
            [sys.executable, PIPELINE_SCRIPT, book_image_path, filepath],
            check=True,
            cwd=BASE_DIR
        )

        # -------------------------------------------------
        #  MATCH SONUCU
        # -------------------------------------------------
        result = find_book_logic(book_id, filepath)

        # -------------------------------------------------
        # 5️ MOD BELİRLEME (BURASI YENİ)
        # -------------------------------------------------
        before_count = len(os.listdir(CROPPED_BEFORE_DIR))
        after_count  = len(os.listdir(CROPPED_AFTER_DIR))

        single_book_mode = (before_count == 1 or after_count == 1)

        if single_book_mode:
            if len(result["matched"]) >= 1:
                response = {
                    "mode": "single",
                    "found": True,
                    "match": result["matched"][0]
                }
            else:
                response = {
                    "mode": "single",
                    "found": False
                }
        else:
            response = {
                "mode": "bulk",
                "matched": result["matched"],
                "missing": result["missing"],
                "added": result["added"]
            }

        return jsonify(response)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.post("/update_shelf_preview")
def update_shelf_preview():
    print(" UPDATE_SHELF_PREVIEW REGISTERED")
    try:
        shelf_name = request.form.get("shelf_name")
        if not shelf_name:
            return jsonify({"error": "shelf_name required"}), 400

        if "image" not in request.files:
            return jsonify({"error": "image required"}), 400

        shelf_path = os.path.join(SHELVES_FOLDER, shelf_name)
        if not os.path.exists(shelf_path):
            return jsonify({"error": "Shelf not found"}), 404

        # 1️ Yeni fotoğrafı kaydet
        img_file = request.files["image"]
        filename = f"update_{uuid.uuid4().hex}.jpg"
        new_img_path = os.path.join(UPLOAD_FOLDER, filename)
        img_file.save(new_img_path)



        # 2️Mevcut raf (örnek: raf_1.jpg)
        print(shelf_path)
        raf_path = os.path.join(shelf_path, "raf_1.jpg")

        if not os.path.exists(raf_path):
           return jsonify({"error": "raf_1.jpg not found"}), 404


        # 3️ PIPELINE
        subprocess.run(
            [sys.executable, PIPELINE_SCRIPT, raf_path, new_img_path],
            check=True,
            cwd=BASE_DIR
        )

        # 4️ Karşılaştırma
        result = find_book_logic("preview", new_img_path)

        return jsonify({
            "summary": {
                "added": len(result["added"]),
                "removed": len(result["missing"]),
                "matched": len(result["matched"])
            },
            "added_books": [
                {
                    "image": f"/preview/after/{after}",
                    "index": i
                }
                for i, after in enumerate(result["added"])
            ],
            "removed_books": [
                {
                    "image": f"/preview/before/{before}",
                    "index": i
                }
                for i, before in enumerate(result["missing"])
            ],
            "image_path": new_img_path
        })


    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
# @app.post("/delete_book")
# def delete_book():
#     print("DELETE BOOK CALLED")
#     print("form:", request.form)
#     print("json:", request.json)
#     try:
#         book_id = request.form.get("book_id")
#         if not book_id:
#             return jsonify({"error": "book_id required"}), 400

#         shelf_name = book_id.rsplit("_", 1)
#         shelf_path = os.path.join(SHELVES_FOLDER, shelf_name)
#         images_path = os.path.join(shelf_path, "images")
#         json_path = os.path.join(shelf_path, "raf_1.json")

#         if not os.path.exists(json_path):
#             return jsonify({"error": "raf_1.json not found"}), 404

#         # JSON'u oku
#         with open(json_path, "r") as f:
#             books = json.load(f)

#         # Silinecek kitabı bul
#         books = [b for b in books if b["id"] != book_id]

#         #  DOSYAYI SİL
#         img_file = os.path.join(images_path, f"{book_id}.jpg")
#         if os.path.exists(img_file):
#             os.remove(img_file)

#         #  KALANLARI YENİDEN NUMARALA
#         new_books = []
#         for i, b in enumerate(books):
#             old_id = b["id"]
#             new_id = f"{shelf_name}_{i}"

#             old_img = os.path.join(images_path, f"{old_id}.jpg")
#             new_img = os.path.join(images_path, f"{new_id}.jpg")

#             if old_img != new_img:
#                 os.rename(old_img, new_img)

#             new_books.append({
#                 "id": new_id,
#                 "image": f"images/{new_id}.jpg",
#                 "sira": i
#             })

#         # JSON'u geri yaz
#         with open(json_path, "w") as f:
#             json.dump(new_books, f, indent=4)

#         return jsonify({
#             "status": "deleted",
#             "remaining": len(new_books)
#         })

#     except Exception as e:
#         return jsonify({"error": str(e)}), 500

@app.route("/delete_book", methods=["POST"])
def delete_book():
    try:
        data = request.get_json(force=True, silent=True) or {}
        book_id = data.get("book_id")

        if not book_id:
            return jsonify({"error": "book_id required"}), 400

        shelf_name = book_id.rsplit("_", 1)[0]

        shelf_path = os.path.join(SHELVES_FOLDER, shelf_name)
        images_path = os.path.join(shelf_path, "images")
        json_path = os.path.join(shelf_path, "raf_1.json")

        if not os.path.exists(json_path):
            return jsonify({"error": "raf_1.json not found"}), 404

        with open(json_path, "r") as f:
            books = json.load(f)

        books = [b for b in books if b["id"] != book_id]

        img_file = os.path.join(images_path, f"{book_id}.jpg")
        if os.path.exists(img_file):
            os.remove(img_file)

        new_books = []
        for i, b in enumerate(books):
            old_id = b["id"]
            new_id = f"{shelf_name}_{i}"

            old_img = os.path.join(images_path, f"{old_id}.jpg")
            new_img = os.path.join(images_path, f"{new_id}.jpg")

            if old_img != new_img and os.path.exists(old_img):
                os.rename(old_img, new_img)

            new_books.append({
                "id": new_id,
                "image": f"images/{new_id}.jpg",
                "sira": i
            })

        with open(json_path, "w") as f:
            json.dump(new_books, f, indent=4)

        return jsonify({
            "status": "deleted",
            "remaining": len(new_books)
        })

    except Exception as e:
        print("DELETE ERROR:", e)
        return jsonify({"error": str(e)}), 500




# =========================================================
# 3) TÜM KİTAPLIKLARI LİSTELE
# =========================================================
@app.get("/list_shelves")
def list_shelves():
    shelves = [
        s for s in os.listdir(SHELVES_FOLDER)
        if os.path.isdir(os.path.join(SHELVES_FOLDER, s))
    ]
    return jsonify({"shelves": shelves})


# =========================================================
# 4) BELİRLİ KİTAPLIĞI GETİR
# =========================================================
@app.get("/get_shelf/<shelf_name>")
def get_shelf(shelf_name):

    shelf_path = os.path.join(SHELVES_FOLDER, shelf_name)
    if not os.path.exists(shelf_path):
        return jsonify({"error": "Shelf not found"}), 404

    raf_json_files = sorted(
        f for f in os.listdir(shelf_path) if f.endswith(".json")
    )

    all_books = []
    for rjson in raf_json_files:
        data = json.load(open(os.path.join(shelf_path, rjson)))
        all_books.extend(data)

    return jsonify({
        "shelf": shelf_name,
        "books": all_books
    })


# =========================================================
# 5) KİTAPLIK DOSYALARINI SERVE ET
# =========================================================
@app.route("/kitapliklar/<path:path>")
def serve_shelf_files(path):

    full_path = os.path.join(SHELVES_FOLDER, path)
    if not os.path.exists(full_path):
        return "File not found", 404

    directory = os.path.dirname(full_path)
    filename = os.path.basename(full_path)
    return send_from_directory(directory, filename)


# =========================================================
# 6) KİTAPLIK SİL
# =========================================================
@app.delete("/delete_shelf/<shelf_name>")
def delete_shelf(shelf_name):

    shelf_path = os.path.join(SHELVES_FOLDER, shelf_name)
    if not os.path.exists(shelf_path):
        return jsonify({"error": "Shelf not found"}), 404

    shutil.rmtree(shelf_path)
    return jsonify({"status": "deleted", "shelf": shelf_name})



# =========================================================
# 8) KİTAPLIK GÜNCELLE (KALICI)
# =========================================================
@app.post("/update_shelf_apply")
def update_shelf_apply():
    try:
        shelf_name = request.form.get("shelf_name")
        if not shelf_name:
            return jsonify({"error": "shelf_name required"}), 400

        image_path = request.form.get("image_path")
        if not image_path or not os.path.exists(image_path):
            return jsonify({"error": "image_path invalid"}), 400

        shelf_path = os.path.join(SHELVES_FOLDER, shelf_name)

        if not os.path.exists(shelf_path):
            return jsonify({"error": "Shelf not found"}), 404

        #  KLASÖRÜ SİL
        shutil.rmtree(shelf_path)

        #  YENİDEN OLUŞTUR
        os.makedirs(shelf_path)
        os.makedirs(os.path.join(shelf_path, "images"))

        shutil.copy(
            image_path,
            os.path.join(shelf_path, "raf_1.jpg")
        )

        #  PIPELINE
        subprocess.run(
            [sys.executable, PIPELINE_SCRIPT, image_path, image_path],
            check=True,
            cwd=BASE_DIR
        )

        kirpilmis_dir = CROPPED_AFTER_DIR
        kitaplar = sorted(
            os.listdir(kirpilmis_dir),
            key=lambda x: int(x.split("_")[1].split(".")[0])
        )

        raf_json = []
        for i, kitap in enumerate(kitaplar):
            src = os.path.join(kirpilmis_dir, kitap)
            dst = os.path.join(
                shelf_path, "images", f"{shelf_name}_{i}.jpg"
            )
            shutil.copy(src, dst)

            raf_json.append({
                "id": f"{shelf_name}_{i}",
                "image": f"images/{shelf_name}_{i}.jpg",
                "sira": i
            })

        with open(os.path.join(shelf_path, "raf_1.json"), "w") as f:
            json.dump(raf_json, f, indent=4)

        return jsonify({
            "status": "updated",
            "shelf": shelf_name,
            "book_count": len(raf_json)
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/preview/<path:filename>")
def serve_preview_files(filename):
    if filename.startswith("before/"):
        directory = CROPPED_BEFORE_DIR
        filename = filename.replace("before/", "")
    elif filename.startswith("after/"):
        directory = CROPPED_AFTER_DIR
        filename = filename.replace("after/", "")
    else:
        return "Invalid preview path", 404

    if not os.path.exists(os.path.join(directory, filename)):
        return "File not found", 404

    return send_from_directory(directory, filename)


# =========================================================
# 7) SUNUCUYU BAŞLAT
# =========================================================
# if __name__ == "__main__":
#     app.run(host="0.0.0.0", port=5000, debug=True) 

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True,
        use_reloader=False   #  KRİTİK
    )

