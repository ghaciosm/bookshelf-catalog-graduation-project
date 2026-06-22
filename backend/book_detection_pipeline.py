from ultralytics import YOLO
import json
import sys
import os
import cv2
import numpy as np
import shutil

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ======================================================
# 1) MODEL
# ======================================================
model = YOLO(os.path.join(BASE_DIR, "model", "book_spine_detector.pt"))

# ======================================================
# 2) OBB + SINGLE-BOOK HEURISTIC (DÜZELTİLDİ)
# ======================================================
def detect_books(image_path, tag):
    results = model(image_path)
    books = []

    img = cv2.imread(image_path)
    H, W = img.shape[:2]
    img_area = H * W
    aspect_ratio = H / max(W, 1)

    max_area_ratio = 0.0  #  EN BÜYÜK TEK OBB

    for r in results:
        for box in r.obb:
            pts = box.xyxyxyxy[0].tolist()
            conf = float(box.conf[0])
            cls = int(box.cls[0])

            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            area = (max(xs) - min(xs)) * (max(ys) - min(ys))
            area_ratio = area / img_area

            max_area_ratio = max(max_area_ratio, area_ratio)

            books.append({
                "class": cls,
                "confidence": conf,
                "points": pts,
                "area_ratio": area_ratio
            })

    #  DOĞRU SINGLE-BOOK KARARI
    is_single_book = (
        aspect_ratio > 3.0
        or max_area_ratio > 0.60
        or "cropped_books_" in image_path
    )

    if is_single_book:
        print(f"📕 {tag} → SINGLE BOOK MODE AKTİF")
        return books, True

    json_path = os.path.join(BASE_DIR, f"book_coordinates_{tag}.json")
    with open(json_path, "w") as f:
        json.dump(books, f, indent=4)

    print(f"📘 {tag} → kitap koordinatları kaydedildi: {json_path}")
    return books, False

# ======================================================
# 3) KIRPMA (TEK RAF VARSAYIMI)
# ======================================================
def crop_books(image_path, books, tag):
    output_dir = os.path.join(BASE_DIR, f"cropped_books_{tag}")

    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)

    for b in books:
        pts = b["points"]
        b["center_x"] = sum(p[0] for p in pts) / 4
        b["center_y"] = sum(p[1] for p in pts) / 4

    #  TEK RAF VARSAYIMI → ELEME YOK
    books = sorted(books, key=lambda x: x["center_x"])

    print(f"🔎 {tag} → tek raf varsayıldı ({len(books)} kitap)")

    img = cv2.imread(image_path)

    def crop_obb(image, points):
        pts = np.array(points, dtype=np.float32)
        rect = cv2.minAreaRect(pts)
        box = cv2.boxPoints(rect).astype(np.float32)

        w, h = int(rect[1][0]), int(rect[1][1])
        if w <= 0 or h <= 0:
            return None

        dst = np.array([
            [0, h - 1],
            [0, 0],
            [w - 1, 0],
            [w - 1, h - 1]
        ], dtype=np.float32)

        M = cv2.getPerspectiveTransform(box, dst)
        warped = cv2.warpPerspective(image, M, (w, h))

        if warped.shape[1] > warped.shape[0]:
            warped = cv2.rotate(warped, cv2.ROTATE_90_CLOCKWISE)

        top = warped[:warped.shape[0] // 2].mean()
        bottom = warped[warped.shape[0] // 2:].mean()
        if top < bottom:
            warped = cv2.rotate(warped, cv2.ROTATE_180)

        return warped

    for i, b in enumerate(books):
        cropped = crop_obb(img, b["points"])
        if cropped is not None:
            cv2.imwrite(os.path.join(output_dir, f"book_{i}.jpg"), cropped)

    print(f"🎉 {tag} kırpma tamamlandı\n")

# ======================================================
# 4) MAIN
# ======================================================
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("python run_pipeline.py before.jpg after.jpg")
        sys.exit(1)

    before_img = sys.argv[1]
    after_img = sys.argv[2]

    print("\n=== BEFORE İŞLENİYOR ===")
    books_before, single_before = detect_books(before_img, "before")

    if single_before:
        out = os.path.join(BASE_DIR, "cropped_books_before")
        shutil.rmtree(out, ignore_errors=True)
        os.makedirs(out)
        cv2.imwrite(os.path.join(out, "book_0.jpg"), cv2.imread(before_img))
    else:
        crop_books(before_img, books_before, "before")

    print("\n=== AFTER İŞLENİYOR ===")
    books_after, single_after = detect_books(after_img, "after")

    if single_after:
        out = os.path.join(BASE_DIR, "cropped_books_after")
        shutil.rmtree(out, ignore_errors=True)
        os.makedirs(out)
        cv2.imwrite(os.path.join(out, "book_0.jpg"), cv2.imread(after_img))
    else:
        crop_books(after_img, books_after, "after")

    print("\n✅ PIPELINE TAMAMLANDI")
