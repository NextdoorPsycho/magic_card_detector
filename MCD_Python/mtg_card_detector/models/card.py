"""
Classes for representing card candidates and recognized cards.
"""

import numpy as np
from dataclasses import dataclass
from shapely.geometry.polygon import Polygon


@dataclass
class CardCandidate:
    """
    Class representing a segment of the image that may be a recognizable card.
    """
    image: np.ndarray
    bounding_quad: Polygon
    image_area_fraction: float
    is_recognized: bool = False
    recognition_score: float = 0.
    is_fragment: bool = False
    name: str = 'unknown'

    def contains(self, other):
        """
        Returns whether the bounding polygon of the card candidate
        contains the bounding polygon of the other candidate.
        """
        return bool(other.bounding_quad.within(self.bounding_quad) and
                    other.name == self.name)