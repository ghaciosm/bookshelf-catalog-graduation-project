# Training Notes

This repository includes the final trained model used by the backend:

```text
backend/model/book_spine_detector.pt
```

The model is used for detecting book spines with YOLO OBB. The active backend pipeline loads this model in:

```text
backend/book_detection_pipeline.py
```

## What is included

- Final trained YOLO OBB model: `backend/model/book_spine_detector.pt`
- Sample bookshelf data for testing: `backend/shelves/`
- Manual YOLO prediction example in the main `README.md`

## What is not included

The original training dataset, annotation files, and training configuration are not included in this repository. They can be added later if the training process needs to be fully reproducible.

## Suggested future structure

If the training files are added later, a clean structure would be:

```text
training/
├── dataset/
│   ├── images/
│   └── labels/
├── data.yaml
├── train_command.md
└── README.md
```

## Example retraining command

The exact command may change depending on the dataset path and YOLO version, but a typical OBB training command would look like:

```bash
yolo obb train model=yolov8n-obb.pt data=training/data.yaml epochs=100 imgsz=640
```

After training, the selected final weight should be copied to:

```text
backend/model/book_spine_detector.pt
```
