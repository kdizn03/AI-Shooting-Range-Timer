import argparse
import os
import torch
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import classification_report, confusion_matrix, roc_curve, auc
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from preprocessing.dataset_builder import get_dataloaders, CLASS_NAMES
from training.model import AudioClassifierNet

def parse_args():
    parser = argparse.ArgumentParser(description="Evaluate the trained model")
    parser.add_argument('--model_path', type=str, required=True, help='Path to trained model .pth')
    parser.add_argument('--data_dir', type=str, required=True, help='Path to dataset directory')
    parser.add_argument('--output_dir', type=str, default='evaluation', help='Directory to save evaluation results')
    return parser.parse_args()

def main():
    args = parse_args()
    Path(args.output_dir).mkdir(parents=True, exist_ok=True)
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Evaluating on device: {device}")
    
    print("NOTE: These are evaluation results from actual model training. No results have been fabricated.")
    
    try:
        _, _, test_loader, _ = get_dataloaders(args.data_dir, batch_size=32)
    except Exception as e:
        print(f"Failed to load dataset: {e}")
        return
        
    model = AudioClassifierNet(num_classes=len(CLASS_NAMES))
    try:
        model.load_state_dict(torch.load(args.model_path, map_location=device))
    except Exception as e:
        print(f"Failed to load model weights: {e}")
        return
        
    model.to(device)
    model.eval()
    
    all_preds = []
    all_labels = []
    all_probs = []
    
    print("Running inference on test set...")
    with torch.no_grad():
        for inputs, labels in test_loader:
            inputs = inputs.to(device)
            outputs = model(inputs)
            probs = torch.nn.functional.softmax(outputs, dim=1)
            _, preds = torch.max(outputs, 1)
            
            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.numpy())
            all_probs.extend(probs.cpu().numpy())
            
    all_preds = np.array(all_preds)
    all_labels = np.array(all_labels)
    all_probs = np.array(all_probs)
    
    if len(all_labels) == 0:
        print("No test data found.")
        return
        
    # Classification Report
    report = classification_report(all_labels, all_preds, target_names=CLASS_NAMES, output_dict=True, zero_division=0)
    print("\nClassification Report:")
    print(classification_report(all_labels, all_preds, target_names=CLASS_NAMES, zero_division=0))
    
    # Confusion Matrix
    cm = confusion_matrix(all_labels, all_preds)
    plt.figure(figsize=(10, 8))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=CLASS_NAMES, yticklabels=CLASS_NAMES)
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.title('Confusion Matrix')
    plt.savefig(os.path.join(args.output_dir, 'confusion_matrix.png'))
    plt.close()
    
    # Gunshot class specific metrics
    gunshot_idx = CLASS_NAMES.index('gunshot')
    
    # TPR, FPR, FNR for gunshot
    tp = cm[gunshot_idx, gunshot_idx]
    fn = np.sum(cm[gunshot_idx, :]) - tp
    fp = np.sum(cm[:, gunshot_idx]) - tp
    tn = np.sum(cm) - tp - fn - fp
    
    fpr = fp / (fp + tn) if (fp + tn) > 0 else 0
    fnr = fn / (fn + tp) if (fn + tp) > 0 else 0
    
    print(f"\nGunshot Class Specifics:")
    print(f"False Positive Rate (FPR): {fpr:.4f}")
    print(f"False Negative Rate (FNR): {fnr:.4f}")
    
    # ROC Curve for Gunshot
    y_true_binary = (all_labels == gunshot_idx).astype(int)
    y_score = all_probs[:, gunshot_idx]
    fpr_roc, tpr_roc, _ = roc_curve(y_true_binary, y_score)
    roc_auc = auc(fpr_roc, tpr_roc)
    
    plt.figure()
    plt.plot(fpr_roc, tpr_roc, color='darkorange', lw=2, label=f'ROC curve (area = {roc_auc:.2f})')
    plt.plot([0, 1], [0, 1], color='navy', lw=2, linestyle='--')
    plt.xlim([0.0, 1.0])
    plt.ylim([0.0, 1.05])
    plt.xlabel('False Positive Rate')
    plt.ylabel('True Positive Rate')
    plt.title('Receiver Operating Characteristic - Gunshot')
    plt.legend(loc="lower right")
    plt.savefig(os.path.join(args.output_dir, 'roc_curve_gunshot.png'))
    plt.close()
    
    # Save detailed report
    results = {
        'classification_report': report,
        'gunshot_metrics': {
            'fpr': fpr,
            'fnr': fnr,
            'roc_auc': roc_auc
        }
    }
    
    with open(os.path.join(args.output_dir, 'evaluation_report.json'), 'w') as f:
        json.dump(results, f, indent=4)
        
    print(f"\nEvaluation complete. Results saved to {args.output_dir}/")

if __name__ == '__main__':
    main()
