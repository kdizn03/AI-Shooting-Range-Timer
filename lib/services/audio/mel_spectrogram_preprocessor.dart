import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/constants.dart';
import '../../core/errors/failures.dart';
import 'audio_preprocessor.dart';

/// Pure Dart implementation of an [AudioPreprocessor] computing a 2D Log Mel Spectrogram.
///
/// Features computed:
/// - 40 Mel filter banks across 16 kHz audio
/// - 512-point Radix-2 FFT with Hanning windowing
/// - 160-sample hop length (~10ms) with center padding
/// - Generates a [40, 26] feature matrix (1,040 values) matching the Python ML pipeline
/// - Standard zero-mean, unit-variance feature normalization
class MelSpectrogramPreprocessor implements AudioPreprocessor {
  /// Creates a [MelSpectrogramPreprocessor] and pre-computes filterbank weights.
  MelSpectrogramPreprocessor() {
    _hanningWindow = _createHanningWindow(InferenceConstants.nFft);
    _melFilterbank = _createMelFilterbank(
      InferenceConstants.nMels,
      InferenceConstants.nFft,
      AudioConstants.sampleRate,
    );
  }

  late final List<List<double>> _melFilterbank;
  late final Float32List _hanningWindow;

  /// Expected number of time frames for a 250ms window at 16kHz with hop 160.
  static const int numFrames = 26;

  @override
  Float32List processAudioFrame(Uint8List pcmData) {
    try {
      final Float32List samples = pcmToFloat(pcmData);
      return computeLogMelSpectrogram(samples);
    } catch (e) {
      throw InvalidAudioFrameException('Failed to process audio frame: $e');
    }
  }

  @override
  Float32List pcmToFloat(Uint8List pcmData) {
    if (pcmData.length % 2 != 0) {
      throw const InvalidAudioFrameException('PCM data length must be even');
    }

    final int numSamples = pcmData.length ~/ 2;
    final Float32List floatSamples = Float32List(numSamples);
    final ByteData byteData = ByteData.sublistView(pcmData);

    for (int i = 0; i < numSamples; i++) {
      // PCM16 little-endian to [-1.0, 1.0]
      final int sample = byteData.getInt16(i * 2, Endian.little);
      floatSamples[i] = sample / 32768.0;
    }

    return floatSamples;
  }

  @override
  Float32List computeLogMelSpectrogram(Float32List samples) {
    const int nFft = InferenceConstants.nFft;
    const int hopLength = InferenceConstants.hopLength;
    const int nMels = InferenceConstants.nMels;
    const int pad = nFft ~/ 2;

    // Center-pad samples to match librosa default behavior
    final int paddedLength = samples.length + 2 * pad;
    final Float32List padded = Float32List(paddedLength);
    padded.setRange(pad, pad + samples.length, samples);

    // Calculate actual number of frames
    final int actualFrames = (paddedLength - nFft) ~/ hopLength + 1;
    final int framesToCompute = math.min(actualFrames, numFrames);

    // Output matrix: [nMels, framesToCompute] in row-major order (or flattened)
    final Float32List spectrogram = Float32List(nMels * numFrames);
    final Float32List frameWindowed = Float32List(nFft);

    for (int t = 0; t < framesToCompute; t++) {
      final int start = t * hopLength;

      // Apply Hanning window
      for (int i = 0; i < nFft; i++) {
        frameWindowed[i] = padded[start + i] * _hanningWindow[i];
      }

      // Compute power spectrum
      final Float32List powerSpec = _computePowerSpectrum(frameWindowed);

      // Apply Mel filterbank & log
      for (int m = 0; m < nMels; m++) {
        double energy = 0.0;
        final List<double> filter = _melFilterbank[m];
        for (int k = 0; k < powerSpec.length; k++) {
          energy += filter[k] * powerSpec[k];
        }
        // Log-Mel energy with small epsilon to avoid log(0)
        final double logMel = math.log(energy + 1e-6);
        spectrogram[m * numFrames + t] = logMel;
      }
    }

    // Zero-mean and unit-variance normalization (matches audio_features.py:normalize_features)
    double sum = 0.0;
    const int totalValues = nMels * numFrames;
    for (int i = 0; i < totalValues; i++) {
      sum += spectrogram[i];
    }
    final double mean = sum / totalValues;

    double sumSqDiff = 0.0;
    for (int i = 0; i < totalValues; i++) {
      final double diff = spectrogram[i] - mean;
      sumSqDiff += diff * diff;
    }
    final double std = math.sqrt(sumSqDiff / totalValues);

    if (std > 1e-6) {
      for (int i = 0; i < totalValues; i++) {
        spectrogram[i] = (spectrogram[i] - mean) / std;
      }
    }

    return spectrogram;
  }

  Float32List _createHanningWindow(int size) {
    final Float32List window = Float32List(size);
    for (int i = 0; i < size; i++) {
      window[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (size - 1)));
    }
    return window;
  }

  Float32List _computePowerSpectrum(Float32List windowed) {
    final int n = windowed.length;
    final Float32List real = Float32List.fromList(windowed);
    final Float32List imag = Float32List(n);

    _fft(real, imag);

    final int numBins = (n ~/ 2) + 1;
    final Float32List power = Float32List(numBins);

    for (int i = 0; i < numBins; i++) {
      power[i] = (real[i] * real[i] + imag[i] * imag[i]) / n;
    }

    return power;
  }

  void _fft(Float32List real, Float32List imag) {
    final int n = real.length;
    if (n <= 1) return;

    // Bit-reversal permutation
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        final double tempReal = real[i];
        final double tempImag = imag[i];
        real[i] = real[j];
        imag[i] = imag[j];
        real[j] = tempReal;
        imag[j] = tempImag;
      }
      int k = n ~/ 2;
      while (k <= j) {
        j -= k;
        k ~/= 2;
      }
      j += k;
    }

    // Cooley-Tukey Radix-2 decimation-in-time
    for (int size = 2; size <= n; size *= 2) {
      final int halfSize = size ~/ 2;
      final double angle = -2.0 * math.pi / size;
      final double wReal = math.cos(angle);
      final double wImag = math.sin(angle);

      for (int i = 0; i < n; i += size) {
        double uReal = 1.0;
        double uImag = 0.0;
        for (int k = 0; k < halfSize; k++) {
          final int evenIdx = i + k;
          final int oddIdx = i + k + halfSize;

          final double tempReal = uReal * real[oddIdx] - uImag * imag[oddIdx];
          final double tempImag = uReal * imag[oddIdx] + uImag * real[oddIdx];

          real[oddIdx] = real[evenIdx] - tempReal;
          imag[oddIdx] = imag[evenIdx] - tempImag;

          real[evenIdx] += tempReal;
          imag[evenIdx] += tempImag;

          final double nextUReal = uReal * wReal - uImag * wImag;
          final double nextUImag = uReal * wImag + uImag * wReal;
          uReal = nextUReal;
          uImag = nextUImag;
        }
      }
    }
  }

  List<List<double>> _createMelFilterbank(
      int numMels, int nFft, int sampleRate) {
    final double minMel = _hzToMel(0.0);
    final double maxMel = _hzToMel(sampleRate / 2.0);

    final List<double> melPoints = List.generate(
        numMels + 2, (i) => minMel + i * (maxMel - minMel) / (numMels + 1));
    final List<double> hzPoints = melPoints.map(_melToHz).toList();
    final List<int> binPoints =
        hzPoints.map((f) => (f * nFft / sampleRate).floor()).toList();

    final int numBins = (nFft ~/ 2) + 1;
    final List<List<double>> filterbank =
        List.generate(numMels, (_) => List.filled(numBins, 0.0));

    for (int i = 0; i < numMels; i++) {
      final int start = binPoints[i];
      final int center = binPoints[i + 1];
      final int end = binPoints[i + 2];

      for (int j = start; j < center; j++) {
        if (center > start) {
          filterbank[i][j] = (j - start) / (center - start);
        }
      }
      for (int j = center; j < end; j++) {
        if (end > center) {
          filterbank[i][j] = (end - j) / (end - center);
        }
      }
    }

    return filterbank;
  }

  double _hzToMel(double hz) =>
      2595.0 * math.log(1.0 + hz / 700.0) / math.ln10;

  double _melToHz(double mel) =>
      700.0 * (math.pow(10, mel / 2595.0) - 1.0);
}
