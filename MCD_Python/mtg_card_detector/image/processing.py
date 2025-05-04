"""
Image processing functions for MTG card detector.
"""

import numpy as np
import cv2
from shapely.affinity import scale

from mtg_card_detector.geometry import four_point_transform, characterize_card_contour
from mtg_card_detector.models import CardCandidate


def contour_image_gray(full_image, thresholding='adaptive', visual=False, verbose=False):
    """
    Grayscale transform, thresholding, countouring and sorting by area.
    """
    gray = cv2.cvtColor(full_image, cv2.COLOR_BGR2GRAY)
    if thresholding == 'adaptive':
        fltr_size = 1 + 2 * (min(full_image.shape[0],
                               full_image.shape[1]) // 20)
        thresh = cv2.adaptiveThreshold(gray,
                                       255,
                                       cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                       cv2.THRESH_BINARY,
                                       fltr_size,
                                       10)
    else:
        _, thresh = cv2.threshold(gray,
                                  70,
                                  255,
                                  cv2.THRESH_BINARY)
    if visual and verbose:
        import matplotlib.pyplot as plt
        plt.imshow(thresh)
        plt.show()

    contours, _ = cv2.findContours(
        np.uint8(thresh), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    return contours


def contour_image_rgb(full_image, clahe, visual=False, verbose=False):
    """
    Grayscale transform, thresholding, countouring and sorting by area.
    """
    blue, green, red = cv2.split(full_image)
    blue = clahe.apply(blue)
    green = clahe.apply(green)
    red = clahe.apply(red)
    _, thr_b = cv2.threshold(blue, 110, 255, cv2.THRESH_BINARY)
    _, thr_g = cv2.threshold(green, 110, 255, cv2.THRESH_BINARY)
    _, thr_r = cv2.threshold(red, 110, 255, cv2.THRESH_BINARY)
    contours_b, _ = cv2.findContours(
        np.uint8(thr_b), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    contours_g, _ = cv2.findContours(
        np.uint8(thr_g), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    contours_r, _ = cv2.findContours(
        np.uint8(thr_r), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    contours = contours_b + contours_g + contours_r
    if visual and verbose:
        import matplotlib.pyplot as plt
        plt.imshow(thr_r)
        plt.show()
        plt.imshow(thr_g)
        plt.show()
        plt.imshow(thr_b)
        plt.show()
    return contours


def contour_image(full_image, mode='gray', clahe=None, visual=False, verbose=False):
    """
    Wrapper for selecting the contouring / thresholding algorithm
    """
    if mode == 'gray':
        contours = contour_image_gray(full_image,
                                    thresholding='simple',
                                    visual=visual,
                                    verbose=verbose)
    elif mode == 'adaptive':
        contours = contour_image_gray(full_image,
                                    thresholding='adaptive',
                                    visual=visual,
                                    verbose=verbose)
    elif mode == 'rgb':
        if clahe is None:
            raise ValueError("CLAHE object is required for RGB mode")
        contours = contour_image_rgb(full_image, 
                                   clahe,
                                   visual=visual,
                                   verbose=verbose)
    elif mode == 'all':
        contours = contour_image_gray(full_image,
                                    thresholding='simple',
                                    visual=visual,
                                    verbose=verbose)
        contours += contour_image_gray(full_image,
                                     thresholding='adaptive',
                                     visual=visual,
                                     verbose=verbose)
        if clahe is None:
            raise ValueError("CLAHE object is required for 'all' mode")
        contours += contour_image_rgb(full_image, 
                                    clahe,
                                    visual=visual,
                                    verbose=verbose)
    else:
        raise ValueError('Unknown segmentation mode.')
    contours_sorted = sorted(contours, key=cv2.contourArea, reverse=True)
    return contours_sorted


def segment_image(test_image, contouring_mode='gray', visual=False, verbose=False):
    """
    Segments the given image into card candidates, that is,
    regions of the image that have a high chance
    of containing a recognizable card.
    """
    full_image = test_image.adjusted.copy()
    image_area = full_image.shape[0] * full_image.shape[1]
    max_segment_area = 0.01  # largest card area

    contours = contour_image(full_image, 
                           mode=contouring_mode, 
                           clahe=test_image.clahe,
                           visual=visual,
                           verbose=verbose)
    for card_contour in contours:
        try:
            (continue_segmentation,
             is_card_candidate,
             bounding_poly,
             crop_factor) = characterize_card_contour(card_contour,
                                                     max_segment_area,
                                                     image_area)
        except NotImplementedError as nie:
            # this can occur in Shapely for some funny contour shapes
            # resolve by discarding the candidate
            print(nie)
            (continue_segmentation,
             is_card_candidate,
             bounding_poly,
             crop_factor) = (True, False, None, 1.)
        if not continue_segmentation:
            break
        if is_card_candidate:
            if max_segment_area < 0.1:
                max_segment_area = bounding_poly.area
            warped = four_point_transform(full_image,
                                         scale(bounding_poly,
                                               xfact=crop_factor,
                                               yfact=crop_factor,
                                               origin='centroid'))
            test_image.candidate_list.append(
                CardCandidate(warped,
                             bounding_poly,
                             bounding_poly.area / image_area))
            if verbose:
                print('Segmented ' +
                      str(len(test_image.candidate_list)) +
                      ' candidates.')