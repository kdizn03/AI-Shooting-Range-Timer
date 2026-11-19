// Thin bridge between the Flutter web app and MediaPipe's YAMNet audio
// classifier. Loaded on demand by lib/services/classifier/yamnet_classifier_web.dart.
//
// The MediaPipe runtime (audio_bundle.mjs + wasm/) is self-hosted, version
// pinned in ./package.json, so detection works without internet access.

import { AudioClassifier, FilesetResolver } from './audio_bundle.mjs';

/** Number of AudioSet classes YAMNet scores. */
export const CLASS_COUNT = 521;

let classifier = null;

/**
 * Loads the runtime and the model. [modelUrl] is resolved against the page.
 * Resolves to true, or rejects with the load error.
 */
export async function load(modelUrl) {
  if (classifier) return true;
  const wasmBase = new URL('./wasm', import.meta.url).href;
  const fileset = await FilesetResolver.forAudioTasks(wasmBase);
  classifier = await AudioClassifier.createFromOptions(fileset, {
    baseOptions: { modelAssetPath: new URL(modelUrl, document.baseURI).href },
    maxResults: -1,
  });
  return true;
}

/**
 * Classifies mono [samples] (Float32Array, -1..1) and returns a Float32Array
 * of CLASS_COUNT scores. When the clip yields several results, each class
 * keeps its highest score.
 */
export function classify(samples, sampleRate) {
  if (!classifier) throw new Error('YAMNet is not loaded');
  const scores = new Float32Array(CLASS_COUNT);
  const results = classifier.classify(samples, sampleRate);
  for (const result of results) {
    const head = result.classifications && result.classifications[0];
    if (!head) continue;
    for (const c of head.categories) {
      if (c.index >= 0 && c.index < CLASS_COUNT && c.score > scores[c.index]) {
        scores[c.index] = c.score;
      }
    }
  }
  return scores;
}

/** Releases the classifier. */
export function close() {
  if (classifier) classifier.close();
  classifier = null;
}
