import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
import numpy as np
import cv2
from PIL import Image
from sentence_transformers import SentenceTransformer, util
from scipy.optimize import linear_sum_assignment

# =====================================================
# 1) MODEL (lazy load)
# =====================================================

_model = None

def get_model():
    global _model
    if _model is None:
        print("📘 Loading CLIP model...")
        _model = SentenceTransformer("clip-ViT-B-32")
    return _model


# =====================================================
# 2) EMBEDDING + COLOR HISTOGRAM
# =====================================================

def get_embedding_and_color(path, model):
    img = Image.open(path).convert("RGB")
    emb = model.encode(
        img,
        convert_to_tensor=True,
        normalize_embeddings=True
    )

    img_cv = cv2.imread(path)
    hsv = cv2.cvtColor(img_cv, cv2.COLOR_BGR2HSV)
    hist = cv2.calcHist(
        [hsv], [0, 1, 2], None,
        [8, 8, 8], [0, 180, 0, 256, 0, 256]
    )
    hist = cv2.normalize(hist, hist).flatten()

    return emb, hist


# =====================================================
# 3) ANA LOGIC — FLASK İÇİN
# =====================================================

def find_book_logic(book_id, query_image_path):
    """
    book_id : aranacak kitap ID (string)
    query_image_path : yüklenen tek kitap fotoğrafı (path)
    """

    before_dir = os.path.join(BASE_DIR, "cropped_books_before")
    after_dir  = os.path.join(BASE_DIR, "cropped_books_after")

    before = sorted(os.listdir(before_dir))
    after  = sorted(os.listdir(after_dir))

    model = get_model()

    before_data = [
        get_embedding_and_color(os.path.join(before_dir, f), model)
        for f in before
    ]
    after_data = [
        get_embedding_and_color(os.path.join(after_dir, f), model)
        for f in after
    ]

    CLIP_WEIGHT  = 0.90
    COLOR_WEIGHT = 0.10

    sim = np.zeros((len(before), len(after)))

    for i, (b_emb, b_hist) in enumerate(before_data):
        for j, (a_emb, a_hist) in enumerate(after_data):
            clip_sim = util.cos_sim(b_emb, a_emb).item()
            color_sim = cv2.compareHist(
                b_hist.astype(np.float32),
                a_hist.astype(np.float32),
                cv2.HISTCMP_CORREL
            )
            color_sim = max(0.0, color_sim)

            sim[i, j] = (
                CLIP_WEIGHT * clip_sim +
                COLOR_WEIGHT * color_sim
            )

    cost = 1.0 - sim
    row_ind, col_ind = linear_sum_assignment(cost)

    ABSOLUTE_MIN_SIM = 0.83
    dynamic_threshold = np.median(sim) * 0.90
    threshold = max(dynamic_threshold, ABSOLUTE_MIN_SIM)

    matched = []
    matched_before_idx = set()
    matched_after_idx = set()

    for r, c in zip(row_ind, col_ind):
        score = sim[r, c]
        if score >= threshold:
            matched.append({
                "before": before[r],
                "after": after[c],
                "score": round(score, 3)
            })
            matched_before_idx.add(r)
            matched_after_idx.add(c)

    missing = [
        before[i] for i in range(len(before))
        if i not in matched_before_idx
    ]

    added = [
        after[j] for j in range(len(after))
        if j not in matched_after_idx
    ]

    return {
        "matched": matched,
        "missing": missing,
        "added": added,
        "threshold": round(threshold, 3)
    }


# =====================================================
# 4) SCRIPT OLARAK DA ÇALIŞABİLSİN
# =====================================================

if __name__ == "__main__":
    result = find_book_logic("debug", None)

    print("======================================")
    print("📘 KARŞILAŞTIRMA SONUCU (FINAL)")
    print("======================================\n")

    for m in result["matched"]:
        print(f'{m["before"]} ---> {m["after"]} ({m["score"]})')

    print("\n❌ Kaybolan kitaplar:")
    for x in result["missing"]:
        print(" -", x)

    print("\n➕ Yeni eklenen kitaplar:")
    for x in result["added"]:
        print(" +", x)
