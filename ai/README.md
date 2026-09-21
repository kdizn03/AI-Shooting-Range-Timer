# Shot Timer AI - Machine Learning Pipeline

This directory contains the Python ML pipeline for training the audio classification model used in the Shot Timer AI mobile application.

## Overview

The model classifies 250ms audio segments into one of 5 categories:
- `gunshot`
- `background_noise`
- `voice`
- `other_loud_sound`
- `beep`

The architecture is a lightweight Custom CNN (< 500K parameters) designed specifically for real-time mobile inference via TensorFlow Lite.

## Directory Structure

- `dataset/`: Contains the raw audio files organized by class.
- `preprocessing/`: Audio feature extraction (Log-Mel Spectrograms) and dataset building.
- `training/`: PyTorch model definition and training loop.
- `evaluation/`: Scripts for evaluating model performance (accuracy, FPR/FNR).
- `models/`: Output directory for trained `.pth` and `.tflite` models.
- `inference/`: Standalone scripts for testing models in Python.
- `scripts/`: Utility scripts (data downloading, TFLite exporting, beep generation).

## Setup Instructions

1. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\\Scripts\\activate
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## How to Prepare Data

1. Run the dataset setup script:
   ```bash
   python scripts/download_dataset.py --output_dir dataset
   ```
2. Place `.wav` files into the corresponding class subdirectories in `dataset/`.
3. Generate the beep sound:
   ```bash
   python scripts/generate_beep.py
   ```

## How to Train

Run the training script:
```bash
python -m training.train --data_dir dataset --output_dir models --epochs 50
```
This will train the PyTorch model and save `best_model.pth` and training curves to `models/`.

## How to Evaluate

Run the evaluation script to generate a classification report and ROC curves:
```bash
python -m evaluation.evaluate --model_path models/best_model.pth --data_dir dataset --output_dir evaluation
```
*NOTE: The evaluate.py script runs actual evaluation without fabricating metrics.*

## How to Export for Mobile

Convert the trained PyTorch model to TensorFlow Lite with FP16 quantization:
```bash
python -m scripts.export_tflite --model_path models/best_model.pth --output_dir models
```
The resulting `shot_timer_model.tflite` can be integrated directly into the Flutter app.

## Performance Expectations

- **Size:** The TFLite model should be under 1MB.
- **Speed:** Inference on a 250ms segment should take < 20ms on a modern smartphone.
- **Accuracy:** Target > 95% accuracy for gunshots with < 1% False Positive Rate.
