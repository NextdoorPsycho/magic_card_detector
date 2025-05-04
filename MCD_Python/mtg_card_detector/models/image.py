"""
Classes for representing reference and test images.
"""

import io
import numpy as np
import cv2
import matplotlib.pyplot as plt
from copy import deepcopy
from itertools import product
from PIL import Image as PILImage
from shapely.geometry.polygon import Polygon
import imagehash

from mtg_card_detector.models.card import CardCandidate


class ReferenceImage:
    """
    Container for a card image and the associated recognition data.
    """

    def __init__(self, name, original_image, clahe, phash=None):
        self.name = name
        self.original = original_image
        self.clahe = clahe
        self.adjusted = None
        self.phash = phash

        if self.original is not None:
            self.histogram_adjust()
            self.calculate_phash()

    def calculate_phash(self):
        """
        Calculates the perceptive hash for the image
        """
        self.phash = imagehash.phash(
            PILImage.fromarray(np.uint8(255 * cv2.cvtColor(
                self.adjusted, cv2.COLOR_BGR2RGB))),
            hash_size=32)

    def histogram_adjust(self):
        """
        Adjusts the image by contrast limited histogram adjustmend (clahe)
        """
        lab = cv2.cvtColor(self.original, cv2.COLOR_BGR2LAB)
        lightness, redness, yellowness = cv2.split(lab)
        corrected_lightness = self.clahe.apply(lightness)
        limg = cv2.merge((corrected_lightness, redness, yellowness))
        self.adjusted = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)


class TestImage:
    """
    Container for a card image and the associated recognition data.
    """

    def __init__(self, name, original_image, clahe):
        self.name = name
        self.original = original_image
        self.clahe = clahe
        self.adjusted = None
        self.phash = None
        self.visual = False
        self.histogram_adjust()
        # self.calculate_phash()

        self.candidate_list = []

    def histogram_adjust(self):
        """
        Adjusts the image by contrast limited histogram adjustmend (clahe)
        """
        lab = cv2.cvtColor(self.original, cv2.COLOR_BGR2LAB)
        lightness, redness, yellowness = cv2.split(lab)
        corrected_lightness = self.clahe.apply(lightness)
        limg = cv2.merge((corrected_lightness, redness, yellowness))
        self.adjusted = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)

    def mark_fragments(self):
        """
        Finds doubly (or multiply) segmented cards and marks all but one
        as a fragment (that is, an unnecessary duplicate)
        """
        for (candidate, other_candidate) in product(self.candidate_list,
                                                   repeat=2):
            if candidate.is_fragment or other_candidate.is_fragment:
                continue
            if ((candidate.is_recognized or other_candidate.is_recognized) and
                    candidate is not other_candidate):
                i_area = candidate.bounding_quad.intersection(
                    other_candidate.bounding_quad).area
                min_area = min(candidate.bounding_quad.area,
                               other_candidate.bounding_quad.area)
                if i_area > 0.5 * min_area:
                    if (candidate.is_recognized and
                            other_candidate.is_recognized):
                        if (candidate.recognition_score <
                                other_candidate.recognition_score):
                            candidate.is_fragment = True
                        else:
                            other_candidate.is_fragment = True
                    else:
                        if candidate.is_recognized:
                            other_candidate.is_fragment = True
                        else:
                            candidate.is_fragment = True

    def plot_image_with_recognized(self, output_path=None, visual=False):
        """
        Plots the recognized cards into the full image.
        """
        # Plotting
        plt.figure()
        plt.imshow(cv2.cvtColor(self.original, cv2.COLOR_BGR2RGB))
        plt.axis('off')
        for candidate in self.candidate_list:
            if not candidate.is_fragment:
                full_image = self.adjusted
                bquad_corners = np.empty((4, 2))
                bquad_corners[:, 0] = np.asarray(
                    candidate.bounding_quad.exterior.coords)[:-1, 0]
                bquad_corners[:, 1] = np.asarray(
                    candidate.bounding_quad.exterior.coords)[:-1, 1]

                plt.plot(np.append(bquad_corners[:, 0],
                                   bquad_corners[0, 0]),
                         np.append(bquad_corners[:, 1],
                                   bquad_corners[0, 1]), 'g-')
                bounding_poly = Polygon([[x, y] for (x, y) in
                                         zip(bquad_corners[:, 0],
                                             bquad_corners[:, 1])])
                fntsze = int(6 * bounding_poly.length / full_image.shape[1])
                bbox_color = 'white' if candidate.is_recognized else 'red'
                plt.text(np.average(bquad_corners[:, 0]),
                         np.average(bquad_corners[:, 1]),
                         candidate.name.capitalize(),
                         horizontalalignment='center',
                         fontsize=fntsze,
                         bbox=dict(facecolor=bbox_color,
                                   alpha=0.7))

        if output_path is not None:
            plt.savefig(output_path + '/MTG_card_recognition_results_' +
                        str(self.name.split('.jpg')[0]) +
                        '.jpg', dpi=600)
        if visual:
            plt.show()

        # Save figure to a bytes buffer
        buf = io.BytesIO()
        # Save as PNG for transparency support if needed, or JPG for size
        plt.savefig(buf, format='png', bbox_inches='tight', pad_inches=0)
        plt.close() # Close the plot figure to free memory
        buf.seek(0)
        img_bytes = buf.getvalue()
        buf.close()
        return img_bytes

    def print_recognized(self):
        """
        Prints out the recognized cards from the image.
        """
        recognized_list = self.return_recognized()
        print('Recognized cards (' +
              str(len(recognized_list)) +
              ' cards):')
        for card in recognized_list:
            print(card.name +
                  '  - with score ' +
                  str(card.recognition_score))

    def return_recognized(self):
        """
        Returns a list of recognized and non-fragment card candidates.
        """
        recognized_list = []
        for candidate in self.candidate_list:
            if candidate.is_recognized and not candidate.is_fragment:
                recognized_list.append(candidate)
        return recognized_list

    def discard_unrecognized_candidates(self):
        """
        Trims the candidate list to keep only the recognized ones
        """
        recognized_list = deepcopy(self.return_recognized())
        self.candidate_list.clear()
        self.candidate_list = recognized_list

    def may_contain_more_cards(self):
        """
        Simple area-based test to see if using a different segmentation
        algorithm may lead to finding more cards in the image.
        """
        recognized_list = self.return_recognized()
        if not recognized_list:
            return True
        tot_area = 0.
        min_area = 1.
        for card in recognized_list:
            tot_area += card.image_area_fraction
            if card.image_area_fraction < min_area:
                min_area = card.image_area_fraction
        return bool(tot_area + 1.5 * min_area < 1.)