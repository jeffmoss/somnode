import numpy as np
import scipy
import sklearn.cluster

import librosa, librosa.display, sys

# Generate mfccs from a time series
if len(sys.argv) == 1:
   raise Exception('Specify at least 1 argument')

filename = sys.argv[1]
print(filename)

y, sr = librosa.load(filename)

tempo, beats = librosa.beat.beat_track(y=y, sr=sr, trim=False, bpm=200)
print('Tempo: %s' % tempo)
print('Beats: %s' % beats)
##############################################
# Next, we'll compute and plot a log-power CQT
BINS_PER_OCTAVE = 12 * 3
N_OCTAVES = 7
C = librosa.amplitude_to_db(librosa.cqt(y=y, sr=sr,
                                        bins_per_octave=BINS_PER_OCTAVE,
                                        n_bins=N_OCTAVES * BINS_PER_OCTAVE),
                            ref=np.max)

beat_times = librosa.frames_to_time(librosa.util.fix_frames(beats,
                                                            x_min=0,
                                                            x_max=C.shape[1]),
                                    sr=sr)

#print(librosa.feature.mfcc(y=y, sr=sr))
# array([[ -5.229e+02,  -4.944e+02, ...,  -5.229e+02,  -5.229e+02],
# [  7.105e-15,   3.787e+01, ...,  -7.105e-15,  -7.105e-15],
# ...,
# [  1.066e-14,  -7.500e+00, ...,   1.421e-14,   1.421e-14],
# [  3.109e-14,  -5.058e+00, ...,   2.931e-14,   2.931e-14]])

# Use a pre-computed log-power Mel spectrogram

S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=128,
                                   fmax=8000)
print(librosa.feature.mfcc(S=librosa.power_to_db(S)))
# array([[ -5.207e+02,  -4.898e+02, ...,  -5.207e+02,  -5.207e+02],
# [ -2.576e-14,   4.054e+01, ...,  -3.997e-14,  -3.997e-14],
# ...,
# [  7.105e-15,  -3.534e+00, ...,   0.000e+00,   0.000e+00],
# [  3.020e-14,  -2.613e+00, ...,   3.553e-14,   3.553e-14]])

# Get more components

mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=40)
Msync = librosa.util.sync(mfccs, beats)

chroma = librosa.feature.chroma_cqt(y=y, sr=sr)
chromaSync = librosa.util.sync(chroma, beats)

R_aff = librosa.segment.recurrence_matrix(chromaSync, mode='affinity', width=1, sym=True)
R = librosa.segment.recurrence_matrix(chromaSync, k=15)
#R_aff = librosa.segment.recurrence_matrix(Msync, mode='affinity', width=3, sym=True)
#R = librosa.segment.recurrence_matrix(Msync, k=15)

import matplotlib.pyplot as plt

# Visualize the MFCC series

#plt.figure(figsize=(10, 4))
#librosa.display.specshow(mfccs, x_axis='time')
#plt.colorbar()
#plt.title('MFCC')
#plt.tight_layout()
#plt.show()

# Visualize the Recurrence Matrix

plt.figure(figsize=(8, 4))
plt.subplot(1, 2, 1)
librosa.display.specshow(R, x_axis='time', y_axis='time', x_coords=beat_times, y_coords=beat_times)
plt.title('Binary recurrence (symmetric)')
plt.subplot(1, 2, 2)
librosa.display.specshow(R_aff, x_axis='time', y_axis='time', x_coords=beat_times, y_coords=beat_times,
                         cmap='magma_r')
plt.title('Affinity recurrence')

plt.tight_layout()
#plt.show()

# Enhance diagonals with a median filter (Equation 2)
df = librosa.segment.timelag_filter(scipy.ndimage.median_filter)
Rf = df(R_aff, size=(1, 7))

# Compute the normalized Laplacian
L = scipy.sparse.csgraph.laplacian(Rf, normed=True)
# and its spectral decomposition
evals, evecs = scipy.linalg.eigh(L)
evecs = scipy.ndimage.median_filter(evecs, size=(9, 1))

print(evecs)

# cumulative normalization is needed for symmetric normalize laplacian eigenvectors
Cnorm = np.cumsum(evecs**2, axis=1)**0.5

# split into k clusters
k = 10
print(Cnorm[:, k-1:k])
X = evecs[:, 2:k+2]# / Cnorm[:, k-1:k]

#############################################################
# Let's use these k components to cluster beats into segments
# (Algorithm 1)
KM = sklearn.cluster.KMeans(n_clusters=k)
seg_ids = KM.fit_predict(X)
colors = plt.get_cmap('Paired', k)

# Segment the MFCC view
chroma_bounds = librosa.segment.agglomerative(chroma, 9)
chroma_bound_times = librosa.frames_to_time(chroma_bounds, sr=sr)

plt.figure()
librosa.display.specshow(np.atleast_2d(seg_ids).T, cmap=colors)
plt.title('Estimated segments')
plt.colorbar(ticks=range(k))
plt.tight_layout()
plt.show()

# Locate segment boundaries from the label sequence
bound_beats = 1 + np.flatnonzero(seg_ids[:-1] != seg_ids[1:])

# Count beat 0 as a boundary
bound_beats = librosa.util.fix_frames(bound_beats, x_min=0)

# Compute the segment label for each boundary
bound_segs = list(seg_ids[bound_beats])

# Convert beat indices to frames
bound_frames = beats[bound_beats-1]

# Make sure we cover to the end of the track
bound_frames = librosa.util.fix_frames(bound_frames,
                                       x_min=None,
                                       x_max=C.shape[1]-1)

import matplotlib.patches as patches
plt.figure(figsize=(12, 4))

bound_times = librosa.frames_to_time(bound_frames)
freqs = librosa.cqt_frequencies(n_bins=C.shape[0],
                                fmin=librosa.note_to_hz('C1'),
                                bins_per_octave=BINS_PER_OCTAVE)

librosa.display.specshow(C, y_axis='cqt_hz', sr=sr,
                         bins_per_octave=BINS_PER_OCTAVE,
                         x_axis='time')
ax = plt.gca()

for interval, label in zip(zip(bound_times, bound_times[1:]), bound_segs):
    ax.add_patch(patches.Rectangle((interval[0], freqs[0]),
                                   interval[1] - interval[0],
                                   freqs[-1],
                                   facecolor=colors(label),
                                   alpha=0.50))

plt.tight_layout()
plt.show()

####### END

plt.figure()
plt.subplot(2,1,1)
librosa.display.specshow(chroma, y_axis='chroma', x_axis='time')
#librosa.display.specshow(chroma, y_axis='chrome', x_axis='time')
plt.vlines(chroma_bound_times, 0, chroma.shape[0], color='green', linestyle='--',
           linewidth=2, alpha=0.9, label='Breath Segment boundaries')
plt.axis('tight')
plt.legend(frameon=True, shadow=True)
plt.title('Chroma Power spectrogram')
plt.tight_layout()
plt.subplot(2,1,2)
librosa.display.specshow(X, y_axis='time', y_coords=beat_times)
plt.axis('tight')
plt.title('Eigenvectors')
plt.tight_layout()
#plt.show()
#plt.savefig('result.png')
