# PCA MATLAB Project

## Structure

- `run_main.m`: unified app entry point
- `config/`: configuration helpers
- `ui/`: GUI construction and view updates
- `preprocess/`: image and camera preprocessing pipeline
- `ml/`: hand-written PCA and hand-written SVM training, prediction, evaluation
- `integration/`: orchestration between GUI and ML
- `data/`: dataset root
- `models/`: trained model artifacts
- `results/`: generated outputs and reports
- `docs/`: planning and collaboration documents

## Collaboration

- A owns `ui/`, `preprocess/`, `run_main.m`
- B owns `ml/`, `models/`, hand-written PCA/SVM algorithm outputs
- Shared contracts are documented in `docs/整体工程拆分与接口说明.md`

## Run

Open MATLAB with this folder as the current working directory, then run:

```matlab
run_main
```

## A-side GUI Demo Flow

1. Open `图像预处理`.
2. Click `输入图像` or `启动摄像头`.
3. Use `灰度化`, `均衡化`, `图像缩放`, `图像旋转`, `获取图像参数`, and `绘制灰度直方图`.
4. Click `人脸框选` to detect and crop the largest face.
5. Click `人脸校准` to convert the cropped face to grayscale and resize it to `112x92`.
6. Open `人脸识别` and use single, batch, realtime, average-face, and eigenface controls after the `ml/` interfaces are implemented.

Camera capture uses MATLAB `webcam`. Face detection uses `vision.CascadeObjectDetector` when Computer Vision Toolbox is available. If a dependency or B-side algorithm is missing, the GUI reports the status in the page instead of crashing.

## Dataset Paths

The GUI resolves the course data relative to the parent folder of this project:

- Raw face database: `../人脸识别`
- Preprocessed face images: `../final_result/final_result` when present, otherwise `../final_result`

The A-side integration uses the preprocessed face directory as the default train/test directory for B-side PCA/SVM calls.
