import argparse
import os
import urllib.request
import zipfile
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from preprocessing.dataset_builder import CLASS_NAMES

def parse_args():
    parser = argparse.ArgumentParser(description="Download and organize dataset")
    parser.add_argument('--output_dir', type=str, default='dataset', help='Directory to store dataset')
    return parser.parse_args()

def create_directories(base_dir):
    for class_name in CLASS_NAMES:
        Path(os.path.join(base_dir, class_name)).mkdir(parents=True, exist_ok=True)

def create_readme(base_dir):
    readme_content = """# Shot Timer AI Dataset

This dataset is organized into 5 classes:
- gunshot
- background_noise
- voice
- other_loud_sound
- beep

## Manual Curation Instructions
1. Place `.wav` files into the corresponding class directories.
2. Ensure audio is relatively clean; the preprocessing pipeline will handle resampling and segmentation.
3. For gunshot sounds, prioritize real recorded shots over synthetic/movie sounds.

## Attribution
If you are using public datasets (e.g., ESC-50, UrbanSound8K), please ensure compliance with their respective licenses.
- ESC-50: https://github.com/karolpiczak/ESC-50 (CC BY-NC 3.0)
"""
    with open(os.path.join(base_dir, 'README.md'), 'w') as f:
        f.write(readme_content)

def main():
    args = parse_args()
    output_dir = args.output_dir
    
    print(f"Initializing dataset directory at {output_dir}")
    create_directories(output_dir)
    create_readme(output_dir)
    
    print("\nDirectory structure created successfully.")
    print("To download the ESC-50 dataset as a base:")
    print("1. Download from https://github.com/karolpiczak/ESC-50/archive/master.zip")
    print("2. Extract and move files to the appropriate folders.")
    print("   (e.g., category 'gunshot' (label 42) files go to dataset/gunshot/)")
    print("\nOr manually place your audio files into the created subdirectories.")

if __name__ == '__main__':
    main()
