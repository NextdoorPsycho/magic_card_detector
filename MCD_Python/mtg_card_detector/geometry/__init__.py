"""
Geometry-related functions for MTG card detector.
"""

from mtg_card_detector.geometry.transforms import (
    order_polygon_points,
    four_point_transform,
)

from mtg_card_detector.geometry.polygons import (
    line_intersection,
    simplify_polygon,
    generate_point_indices,
    generate_quad_corners,
    generate_quad_candidates,
    get_bounding_quad,
    quad_corner_diff,
    convex_hull_polygon,
    polygon_form_factor,
    characterize_card_contour,
)