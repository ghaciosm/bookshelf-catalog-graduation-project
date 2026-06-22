# BookShelf

BookShelf is a graduation project for detecting and comparing book spines in bookshelf images. The project contains a Flask backend and a Flutter mobile frontend.

The backend detects book spines with a trained YOLO OBB model, crops the detected book spines, and compares books using CLIP embeddings together with an OpenCV color histogram score.

## Project Structure

```text
BookShelf/
├── backend/
│   ├── app.py                       # Flask API
│   ├── book_detection_pipeline.py    # YOLO OBB detection + crop pipeline
│   ├── book_matcher.py               # Book matching logic
│   ├── model/book_spine_detector.pt             # Trained YOLO model
│   ├── shelves/                      # Sample bookshelf data for testing
│   ├── test_images/                  # Example image for manual YOLO test
│   └── requirements.txt
├── frontend/
│   ├── lib/                          # Flutter screens
│   ├── assets/
│   ├── android/ ios/ web/ ...
│   ├── pubspec.yaml
│   └── .env.example
└── README.md
```

## Backend Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip setuptools wheel
python -m pip install --default-timeout=1000 --retries=10 -r requirements.txt
python3 app.py
```

Windows PowerShell:

```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip setuptools wheel
python -m pip install --default-timeout=1000 --retries=10 -r requirements.txt
python app.py
```

The backend runs on port `5000` by default.

## Backend API Test

After starting the backend, open a second terminal from the `backend/` directory.

List sample bookshelves:

```bash
curl http://127.0.0.1:5000/list_shelves
```

Expected examples:

```json
{"shelves":["1","3","demo_1","demo_2"]}
```

Get one sample bookshelf:

```bash
curl http://127.0.0.1:5000/get_shelf/demo_1
```

Compare an existing sample shelf with another sample shelf image:

```bash
curl -X POST http://127.0.0.1:5000/update_shelf_preview \
  -F "shelf_name=demo_1" \
  -F "image=@shelves/demo_2/raf_1.jpg"
```

## Manual YOLO Test

You can test the trained YOLO model directly with Ultralytics:

```bash
yolo predict model="model/book_spine_detector.pt" source="test_images/single_shelf/sample_1.jpeg" conf=0.5 save=True project="results" name="single_shelf" show_labels=False show_conf=False
```

## Manual Pipeline + Matching Test

```bash
python3 book_detection_pipeline.py shelves/demo_1/raf_1.jpg shelves/demo_2/raf_1.jpg
python3 book_matcher.py
```

The pipeline creates `cropped_books_before/` and `cropped_books_after/`, then the matcher prints matched, missing, and added books.

## Frontend Setup

Create a local `.env` file:

```bash
cd frontend
cp .env.example .env
```

Edit `.env` according to your backend IP address:

```env
BACKEND_IP=127.0.0.1
BACKEND_PORT=5000
```

Then run:

```bash
flutter pub get
flutter run
```

If the backend runs inside WSL and the Flutter app runs on a phone, expose the WSL backend through Windows portproxy. Example:

```powershell
netsh interface portproxy add v4tov4 listenport=5000 listenaddress=<WINDOWS_IP> connectport=5000 connectaddress=<WSL_IP>
```

Then set this in `frontend/.env`:

```env
BACKEND_IP=<WINDOWS_IP>
BACKEND_PORT=5000
```

## Training Notes

The final trained model is stored as:

```text
backend/model/book_spine_detector.pt
```

A separate `training/README.md` file is included to document how training files can be added later. The original training dataset and annotation files are not included in this repository.

## Notes

- The active backend uses only `app.py`, `book_detection_pipeline.py`, and `book_matcher.py`.
- Sample bookshelves are intentionally kept in `backend/shelves/` so users can test the project after cloning.
- New local shelves created while testing are ignored by Git by default.
- Runtime outputs such as uploaded images, cropped temporary books, YOLO result folders, and local `.env` files are ignored by Git.
