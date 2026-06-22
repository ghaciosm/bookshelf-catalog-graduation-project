# Backend

Active backend flow:

```text
app.py -> book_detection_pipeline.py -> book_matcher.py
```

- `app.py`: Flask API server
- `book_detection_pipeline.py`: YOLO OBB detection and book-spine cropping pipeline
- `book_matcher.py`: CLIP embedding + OpenCV color histogram based matching
- `model/book_spine_detector.pt`: trained YOLO model
- `shelves/`: sample bookshelf data kept for testing
- `test_images/`: sample image for manual YOLO prediction
