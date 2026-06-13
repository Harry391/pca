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
