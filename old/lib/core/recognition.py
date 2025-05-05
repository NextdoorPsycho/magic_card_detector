"""
Card recognition functionality for MTG card detector.
"""

import numpy as np
import imagehash
from PIL import Image as PILImage
import cv2
from scipy.ndimage import rotate


def phash_diff(reference_images, phash_im):
    """
    Calculates the phash difference between the given phash and
    each of the reference images.
    """
    diff = np.zeros(len(reference_images))
    for i, ref_im in enumerate(reference_images):
        diff[i] = phash_im - ref_im.phash
    return diff


def phash_compare(im_seg, reference_images, hash_separation_thr=4.0, verbose=False):
    """
    Runs perceptive hash comparison between given image and
    the (pre-hashed) reference set.
    """

    card_name = 'unknown'
    is_recognized = False
    recognition_score = 0.
    rotations = np.array([0., 90., 180., 270.])

    d_0_dist = np.zeros(len(rotations))
    d_0 = np.zeros((len(reference_images), len(rotations)))
    for j, rot in enumerate(rotations):
        if not -1.e-5 < rot < 1.e-5:
            phash_im = imagehash.phash(
                PILImage.fromarray(np.uint8(255 * cv2.cvtColor(
                    rotate(im_seg, rot), cv2.COLOR_BGR2RGB))),
                hash_size=32)
        else:
            phash_im = imagehash.phash(
                PILImage.fromarray(np.uint8(255 * cv2.cvtColor(
                    im_seg, cv2.COLOR_BGR2RGB))),
                hash_size=32)
        d_0[:, j] = phash_diff(reference_images, phash_im)
        d_0_ = d_0[d_0[:, j] > np.amin(d_0[:, j]), j]
        d_0_ave = np.average(d_0_)
        d_0_std = np.std(d_0_)
        d_0_dist[j] = (d_0_ave - np.amin(d_0[:, j])) / d_0_std
        if verbose:
            print('Phash statistical distance: ' + str(d_0_dist[j]))
        if (d_0_dist[j] > hash_separation_thr and
                np.argmax(d_0_dist) == j):
            card_name = reference_images[np.argmin(d_0[:, j])]\
                .name.split('.jpg')[0]
            is_recognized = True
            recognition_score = d_0_dist[j] / hash_separation_thr
            break
    return (is_recognized, recognition_score, card_name)